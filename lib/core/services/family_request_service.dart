import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../models/family_request_model.dart';
import '../models/family_member_model.dart';
import '../models/apartment_model.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';
import 'fcm_service.dart';


class FamilyRequestService {
  final LoggingService loggingService;
  late final FirebaseFirestore _firestore;
  // Get FCMService lazily to avoid circular dependency
  FCMService? get _fcmService {
    try {
      return GetIt.instance<FCMService>();
    } catch (e) {
      return null;
    }
  }

  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      return null;
    }
  }

  StreamSubscription<QuerySnapshot>? _requestSubscription;
  final StreamController<List<FamilyRequestModel>> _requestsController = 
      StreamController<List<FamilyRequestModel>>.broadcast();

  List<FamilyRequestModel> _requests = [];

  FamilyRequestService({
    required this.loggingService,
  }) {
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  // Getters
  Stream<List<FamilyRequestModel>> get requestsStream => _requestsController.stream;
  List<FamilyRequestModel> get requests => _requests;

  /// Инициализация сервиса - слушает запросы для текущего пользователя
  Future<void> initialize() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        loggingService.warning('User not authenticated, skipping family requests initialization');
        return;
      }

      await _startListeningToRequests();
    } catch (e) {
      loggingService.error('Failed to initialize family request service', e);
    }
  }

  /// Отправка запроса на присоединение к семье
  Future<bool> submitFamilyRequest({
    required String name,
    required String role,
    required String blockId,
    required String apartmentNumber,
    required String ownerPhone,
    required String applicantPhone, // Добавляем телефон заявителя
  }) async {
    try {
      loggingService.info('Submitting family request: $name ($applicantPhone), $role, $blockId-$apartmentNumber, owner: $ownerPhone');

      // Ищем квартиру по блоку, номеру и телефону владельца
      final apartment = await _findApartment(blockId, apartmentNumber, ownerPhone);
      if (apartment == null) {
        loggingService.warning('Apartment not found: $blockId-$apartmentNumber');
        return false;
      }

      // Проверяем, что у квартиры есть владелец (более гибкая проверка)
      final hasOwner = apartment.fullName != null && apartment.fullName!.isNotEmpty ||
                      apartment.phone != null && apartment.phone!.isNotEmpty ||
                      apartment.passportNumber != null && apartment.passportNumber!.isNotEmpty;
      
      if (!hasOwner) {
        loggingService.warning('Apartment has no owner data: ${apartment.id}');
        return false;
      }
      
      loggingService.info('Apartment validation passed - owner: ${apartment.fullName}, phone: ${apartment.phone}');

      // Проверяем лимит членов семьи (более гибкая проверка)
      final currentFamilyCount = apartment.familyMembers.length;
      if (currentFamilyCount >= 10) {
        loggingService.warning('Family member limit reached for apartment: ${apartment.id} (current: $currentFamilyCount)');
        return false;
      }
      
      loggingService.info('Family member check passed - current members: $currentFamilyCount/10');

      // Получаем FCM токен для уведомлений
      String? fcmToken;
      try {
        final fcmService = _fcmService;
        if (fcmService != null) {
          fcmToken = await fcmService.getToken();
          loggingService.info('FCM token obtained for notifications');
        }
      } catch (e) {
        loggingService.info('FCM token not available (non-critical): $e');
      }

      // Создаем семейный запрос
      final requestData = {
        'name': name,
        'role': role,
        'blockId': blockId,
        'apartmentNumber': apartmentNumber,
        'apartmentId': apartment.id,
        'applicantPhone': applicantPhone, // Сохраняем телефон заявителя
        'ownerPhone': ownerPhone,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        if (fcmToken != null) 'fcmToken': fcmToken,
      };

      // Сохраняем в Firestore
      await _firestore.collection('familyRequests').add(requestData);
      
      loggingService.info('Family request submitted successfully');
      return true;
    } catch (e) {
      loggingService.error('Failed to submit family request', e);
      return false;
    }
  }

  /// Поиск квартиры по блоку, номеру и телефону владельца с улучшенной обработкой различных структур данных
  Future<ApartmentModel?> _findApartment(String blockId, String apartmentNumber, String ownerPhone) async {
    try {
      loggingService.info('Finding apartment: block=$blockId, number=$apartmentNumber, phone=$ownerPhone');
      
      // Подготавливаем варианты полей для поиска
      final blockVariants = [blockId, '$blockId BLOK', 'BLOK $blockId', 'Block $blockId'];
      
      // СТРАТЕГИЯ 1: Поиск в коллекции apartments (если она существует)
      try {
        final apartmentQuery = await _firestore
            .collection('apartments')
            .where('phone', isEqualTo: ownerPhone)
            .get();

        for (var doc in apartmentQuery.docs) {
          final data = doc.data();
          final docBlock = data['blockId'] ?? data['block_name'] ?? data['block_number'] ?? '';
          final docApartment = data['apartment_number']?.toString() ?? data['apartmentNumber']?.toString() ?? '';
          
          if (blockVariants.contains(docBlock) && docApartment == apartmentNumber) {
            final apartment = ApartmentModel.fromFirestore(doc);
            loggingService.info('Found apartment in apartments collection: ${apartment.id}');
            return apartment;
          }
        }
      } catch (e) {
        loggingService.info('Apartments collection search failed: $e');
      }

      // СТРАТЕГИЯ 2: Поиск через collection group с обработкой различных форматов полей
      try {
        loggingService.info('Trying collection group query...');
        final groupQuery = await _firestore
            .collectionGroup('apartments')
            .where('phone', isEqualTo: ownerPhone)
            .get();

        for (var doc in groupQuery.docs) {
          final data = doc.data();
          final docBlock = data['block_name'] ?? data['block_number'] ?? data['blockId'] ?? '';
          final docApartment = data['apartment_number']?.toString() ?? data['apartmentNumber']?.toString() ?? '';
          
          loggingService.info('Checking document: block="$docBlock", apartment="$docApartment"');
          
          if (blockVariants.contains(docBlock) && docApartment == apartmentNumber) {
            final apartment = ApartmentModel.fromFirestore(doc);
            loggingService.info('Found apartment by collection group: ${apartment.id}');
            return apartment;
          }
        }
      } catch (indexError) {
        loggingService.warning('Collection group query failed (likely missing index): $indexError');
      }
      
      // СТРАТЕГИЯ 3: Поиск в users коллекции напрямую
      try {
        loggingService.info('Trying users collection query...');
        final usersQuery = await _firestore
            .collection('users')
            .where('phone', isEqualTo: ownerPhone)
            .get();

        for (var doc in usersQuery.docs) {
          final data = doc.data();
          final docBlock = data['block_name'] ?? data['block_number'] ?? data['blockId'] ?? '';
          final docApartment = data['apartment_number']?.toString() ?? data['apartmentNumber']?.toString() ?? '';
          
          loggingService.info('Checking users doc: block="$docBlock", apartment="$docApartment"');
          
          if (blockVariants.contains(docBlock) && docApartment == apartmentNumber) {
            final apartmentData = Map<String, dynamic>.from(data);
            apartmentData['document_id'] = doc.id;
            final apartment = ApartmentModel.fromJson(apartmentData);
            loggingService.info('Found apartment in users collection: ${apartment.id}');
            return apartment;
          }
        }
      } catch (e) {
        loggingService.warning('Users collection search failed: $e');
      }

      // СТРАТЕГИЯ 4: Поиск по блокам в users коллекции
      final knownBlocks = [
        blockId, '$blockId BLOK', 'BLOK $blockId', 'Block $blockId',
        'D', 'D BLOK', 'BLOK D', 'Block D',
        'E', 'E BLOK', 'BLOK E', 'Block E',
        'F', 'F BLOK', 'BLOK F', 'Block F',
        'A', 'A BLOK', 'BLOK A', 'Block A',
        'B', 'B BLOK', 'BLOK B', 'Block B',
        'C', 'C BLOK', 'BLOK C', 'Block C',
      ];
      
      for (var blockVariant in knownBlocks) {
        try {
          final blockQuery = await _firestore
              .collection('users')
              .doc(blockVariant)
              .collection('apartments')
              .where('phone', isEqualTo: ownerPhone)
              .get();

          for (var doc in blockQuery.docs) {
            final data = doc.data();
            final docApartment = data['apartment_number']?.toString() ?? data['apartmentNumber']?.toString() ?? '';
            
            if (docApartment == apartmentNumber) {
              final apartmentData = Map<String, dynamic>.from(data);
              apartmentData['document_id'] = doc.id;
              apartmentData['block_name'] = blockVariant;
              final apartment = ApartmentModel.fromJson(apartmentData);
              loggingService.info('Found apartment in block subcollection $blockVariant: ${apartment.id}');
              return apartment;
            }
          }
        } catch (e) {
          // Блок не существует, продолжаем
        }
      }

      // СТРАТЕГИЯ 5: Широкий поиск по всей базе по телефону
      try {
        loggingService.info('Trying broad phone search for debugging...');
        final phoneQuery = await _firestore
            .collectionGroup('apartments')
            .where('phone', isEqualTo: ownerPhone)
            .limit(10)
            .get();

        loggingService.info('Found ${phoneQuery.docs.length} documents with this phone number');
        for (var doc in phoneQuery.docs) {
          final data = doc.data();
          loggingService.info('Debug - Document data: ${data.toString()}');
        }
      } catch (e) {
        loggingService.warning('Debug phone search failed: $e');
      }

      loggingService.warning('Apartment not found with criteria: block=$blockId, number=$apartmentNumber, phone=$ownerPhone');
      return null;
    } catch (e) {
      loggingService.error('Error finding apartment', e);
      return null;
    }
  }

  /// Отклик владельца на семейный запрос
  Future<bool> respondToFamilyRequest({
    required String requestId,
    required bool approved,
    String? rejectionReason,
  }) async {
    try {
      loggingService.info('Responding to family request: $requestId, approved: $approved');

      final requestRef = _firestore.collection('familyRequests').doc(requestId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        loggingService.warning('Family request not found: $requestId');
        return false;
      }

      final request = FamilyRequestModel.fromFirestore(requestDoc);

      // Обновляем статус запроса
      await requestRef.update({
        'status': approved ? 'approved' : 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });

      if (approved) {
        // Добавляем члена семьи в квартиру (пока без userId)
        await _addPendingFamilyMember(request);
      }

      // Отправляем уведомление заявителю
      await _sendResponseNotification(request, approved, rejectionReason);

      loggingService.info('Family request response completed successfully');
      return true;
    } catch (e) {
      loggingService.error('Failed to respond to family request', e);
      return false;
    }
  }

  /// Добавление ожидающего члена семьи в квартиру
  Future<void> _addPendingFamilyMember(FamilyRequestModel request) async {
    try {
      if (request.apartmentId == null) {
        loggingService.warning('Cannot add family member: no apartmentId in request');
        return;
      }

      loggingService.info('🔍 Adding family member to apartment: ${request.apartmentId}');
      loggingService.info('   Name: ${request.name}');
      loggingService.info('   Role: ${request.role}');
      loggingService.info('   Phone: ${request.applicantPhone}');

      final newMember = FamilyMemberModel(
        memberId: null, // Будет обновлен после регистрации
        name: request.name,
        role: request.role,
        phone: request.applicantPhone, // Сохраняем телефон заявителя!
        isApproved: true, // Уже одобрен владельцем, может входить по телефону
        createdAt: DateTime.now(),
        approvedAt: DateTime.now(), // Устанавливаем время одобрения
      );

      loggingService.info('📝 Created family member object:');
      loggingService.info('   ${newMember.toJson()}');

      // Сначала проверяем, существует ли документ квартиры
      loggingService.info('🔍 Checking if apartment document exists...');
      final apartmentDoc = await _firestore.collection('apartments').doc(request.apartmentId).get();
      
      if (!apartmentDoc.exists) {
        loggingService.warning('❌ Apartment document does not exist in apartments collection: ${request.apartmentId}');
        
        // Пробуем найти квартиру через collection group
        loggingService.info('🔍 Trying to find apartment in collection groups...');
        final collectionGroupQuery = await _firestore
            .collectionGroup('apartments')
            .where(FieldPath.documentId, isEqualTo: request.apartmentId)
            .get();
        
        if (collectionGroupQuery.docs.isNotEmpty) {
          final foundDoc = collectionGroupQuery.docs.first;
          loggingService.info('✅ Found apartment in collection group: ${foundDoc.reference.path}');
          
          // Обновляем по правильному пути
          await foundDoc.reference.update({
            'familyMembers': FieldValue.arrayUnion([newMember.toJson()]),
          });
          
          loggingService.info('✅ Family member added via collection group path');
          
        } else {
          loggingService.error('❌ Apartment document not found anywhere: ${request.apartmentId}');
          
          // Пробуем создать семейного участника через users коллекцию
          loggingService.info('🔄 Trying alternative: creating user document directly');
          await _createStandaloneFamilyMemberUser(request, newMember);
          return;
        }
      } else {
        loggingService.info('✅ Apartment document exists, updating...');
        
        // Обновляем документ квартиры
        await _firestore.collection('apartments').doc(request.apartmentId).update({
          'familyMembers': FieldValue.arrayUnion([newMember.toJson()]),
        });
        
        loggingService.info('✅ Family member added to apartment: ${request.apartmentId} with phone: ${request.applicantPhone}');
      }
      
      // Проверяем, что данные действительно сохранились
      final updatedDoc = await _firestore.collection('apartments').doc(request.apartmentId).get();
      if (updatedDoc.exists) {
        final data = updatedDoc.data();
        final familyMembers = data?['familyMembers'] as List? ?? [];
        loggingService.info('🔍 Verification: Apartment now has ${familyMembers.length} family members');
        
        // Ищем нашего нового члена семьи
        final ourMember = familyMembers.firstWhere(
          (member) => member['phone'] == request.applicantPhone && member['name'] == request.name,
          orElse: () => null,
        );
        
        if (ourMember != null) {
          loggingService.info('✅ Verification successful: Family member found in database');
          loggingService.info('   Saved data: $ourMember');
        } else {
          loggingService.error('❌ Verification failed: Family member not found in database');
        }
      }
      
    } catch (e) {
      loggingService.error('Failed to add pending family member', e);
    }
  }

  /// Создает семейного участника как отдельного пользователя если квартира не найдена
  Future<void> _createStandaloneFamilyMemberUser(FamilyRequestModel request, FamilyMemberModel member) async {
    try {
      loggingService.info('🔄 Creating standalone family member user');
      
      // Создаем документ пользователя с данными семейного участника
      final userId = 'family_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('userProfiles').doc(userId).set({
        'fullName': request.name,
        'name': request.name,
        'phone': request.applicantPhone,
        'role': 'familyMember',
        'familyRole': request.role,
        'apartmentNumber': request.apartmentNumber,
        'apartment_number': request.apartmentNumber,
        'blockId': request.blockId,
        'block_number': request.blockId,
        'block_name': '${request.blockId} BLOK',
        'apartmentId': request.apartmentId,
        'ownerPhone': request.ownerPhone,
        'isApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': FieldValue.serverTimestamp(),
        'familyMembers': [member.toJson()], // Добавляем себя как семейного участника
        'requestId': request.id,
        'source': 'family_request_fallback',
        'dataSource': 'family_request_service',
      });
      
      loggingService.info('✅ Standalone family member user created: $userId');
      
    } catch (e) {
      loggingService.error('Failed to create standalone family member user', e);
    }
  }

  /// Отправка уведомления о решении владельца
  Future<void> _sendResponseNotification(
    FamilyRequestModel request,
    bool approved,
    String? rejectionReason,
  ) async {
    try {
      // Отправляем push-уведомление
      if (request.fcmToken != null) {
        // FCM уведомления обрабатываются через Cloud Functions
        loggingService.info('FCM token available for notification: ${request.fcmToken}');
      }

      loggingService.info('Response notification sent for request: ${request.id}');
    } catch (e) {
      loggingService.error('Failed to send response notification', e);
    }
  }

  /// Завершение регистрации члена семьи
  Future<bool> completeFamilyRegistration({
    required String requestId,
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      loggingService.info('Completing family registration: $requestId, userId: $userId');

      final requestRef = _firestore.collection('familyRequests').doc(requestId);
      final requestDoc = await requestRef.get();

      if (!requestDoc.exists) {
        loggingService.warning('Family request not found: $requestId');
        return false;
      }

      final request = FamilyRequestModel.fromFirestore(requestDoc);

      if (request.apartmentId == null) {
        loggingService.warning('No apartment ID in request: $requestId');
        return false;
      }

      // Обновляем запрос с данными пользователя
      await requestRef.update({
        'applicantId': userId,
        'phone': phoneNumber,
      });

      // Обновляем информацию о члене семьи в квартире
      await _updateFamilyMemberInfo(request.apartmentId!, request.name, userId, phoneNumber);

      // Создаем профиль пользователя
      await _createUserProfile(userId, request, phoneNumber);

      loggingService.info('Family registration completed successfully');
      return true;
    } catch (e) {
      loggingService.error('Failed to complete family registration', e);
      return false;
    }
  }

  /// Обновление информации о члене семьи в квартире
  Future<void> _updateFamilyMemberInfo(
    String apartmentId,
    String memberName,
    String userId,
    String phoneNumber,
  ) async {
    try {
      // Получаем документ квартиры
      final apartmentDoc = await _firestore.collection('apartments').doc(apartmentId).get();
      if (!apartmentDoc.exists) return;

      final apartment = ApartmentModel.fromFirestore(apartmentDoc);
      
      // Находим и обновляем члена семьи
      final updatedMembers = apartment.familyMembers.map((member) {
        if (member.name == memberName && member.memberId == null) {
          return member.copyWith(
            memberId: userId,
            phone: phoneNumber,
            isApproved: true,
            approvedAt: DateTime.now(),
          );
        }
        return member;
      }).toList();

      // Обновляем документ
      await _firestore.collection('apartments').doc(apartmentId).update({
        'familyMembers': updatedMembers.map((m) => m.toJson()).toList(),
      });

      loggingService.info('Family member info updated in apartment: $apartmentId');
    } catch (e) {
      loggingService.error('Failed to update family member info', e);
    }
  }

  /// Создание профиля пользователя для члена семьи
  Future<void> _createUserProfile(
    String userId,
    FamilyRequestModel request,
    String phoneNumber,
  ) async {
    try {
      await _firestore.collection('userProfiles').doc(userId).set({
        'name': request.name,
        'role': 'familyMember',
        'familyRole': request.role,
        'apartmentId': request.apartmentId,
        'blockId': request.blockId,
        'apartmentNumber': request.apartmentNumber,
        'phone': phoneNumber,
        'isApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
        'dataSource': 'family_request_service',
      });

      loggingService.info('User profile created for family member in userProfiles: $userId');
    } catch (e) {
      loggingService.error('Failed to create user profile in userProfiles', e);
    }
  }

  /// Удаление члена семьи (только для владельца)
  Future<bool> removeFamilyMember({
    required String apartmentId,
    required String memberId,
  }) async {
    try {
      loggingService.info('Removing family member: $memberId from apartment: $apartmentId');

      // Проверяем права (должен быть владелец)
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        return false;
      }

      // Получаем квартиру
      final apartmentDoc = await _firestore.collection('apartments').doc(apartmentId).get();
      if (!apartmentDoc.exists) return false;

      final apartment = ApartmentModel.fromFirestore(apartmentDoc);

      // Проверяем, что текущий пользователь - владелец
      final currentUserId = authService.userData?['passport_number'] ?? 
                            authService.verifiedApartment?.passportNumber;
      
      if (apartment.ownerId != currentUserId) {
        loggingService.warning('User is not apartment owner: $currentUserId');
        return false;
      }

      // Удаляем члена семьи из списка
      final updatedMembers = apartment.familyMembers
          .where((member) => member.memberId != memberId)
          .toList();

      // Обновляем документ квартиры
      await _firestore.collection('apartments').doc(apartmentId).update({
        'familyMembers': updatedMembers.map((m) => m.toJson()).toList(),
      });

      // Удаляем профиль пользователя (опционально)
      await _firestore.collection('userProfiles').doc(memberId).delete();

      loggingService.info('Family member removed successfully');
      return true;
    } catch (e) {
      loggingService.error('Failed to remove family member', e);
      return false;
    }
  }

  /// Начать слушать запросы для текущего пользователя
  Future<void> _startListeningToRequests() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        return;
      }

      final apartment = authService.verifiedApartment;
      if (apartment == null) return;

      // Слушаем запросы для данной квартиры
      _requestSubscription?.cancel();
      _requestSubscription = _firestore
          .collection('familyRequests')
          .where('apartmentId', isEqualTo: apartment.id)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(_onRequestsUpdate);

      loggingService.info('Started listening to family requests for apartment: ${apartment.id}');
    } catch (e) {
      loggingService.error('Failed to start listening to requests', e);
    }
  }

  void _onRequestsUpdate(QuerySnapshot snapshot) {
    try {
      final requests = snapshot.docs
          .map((doc) => FamilyRequestModel.fromFirestore(doc))
          .toList();

      _requests = requests;
      _requestsController.add(_requests);

      loggingService.info('Processed ${requests.length} family requests');
    } catch (e) {
      loggingService.error('Error processing family requests update', e);
    }
  }

  /// Получить список членов семьи для квартиры
  Future<List<FamilyMemberModel>> getFamilyMembers(String apartmentId) async {
    try {
      final apartmentDoc = await _firestore.collection('apartments').doc(apartmentId).get();
      if (!apartmentDoc.exists) return [];

      final apartment = ApartmentModel.fromFirestore(apartmentDoc);
      return apartment.approvedFamilyMembers;
    } catch (e) {
      loggingService.error('Failed to get family members', e);
      return [];
    }
  }

  /// Получить семейные запросы для квартиры владельца
  Future<List<FamilyRequestModel>> getFamilyRequestsForApartment(String apartmentId) async {
    try {
      loggingService.info('Loading family requests for apartment: $apartmentId');
      
      final querySnapshot = await _firestore
          .collection('familyRequests')
          .where('apartmentId', isEqualTo: apartmentId)
          .get();

      final requests = querySnapshot.docs
          .map((doc) => FamilyRequestModel.fromFirestore(doc))
          .toList();

      // Сортируем на клиенте
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      loggingService.info('Found ${requests.length} family requests for apartment: $apartmentId');
      return requests;
    } catch (e) {
      loggingService.error('Failed to get family requests for apartment', e);
      return [];
    }
  }

  /// Получить семейные запросы по блоку и номеру квартиры (альтернативный метод)
  Future<List<FamilyRequestModel>> getFamilyRequestsByAddress(String blockId, String apartmentNumber) async {
    try {
      loggingService.info('Loading family requests for: $blockId-$apartmentNumber');
      
      final querySnapshot = await _firestore
          .collection('familyRequests')
          .where('blockId', isEqualTo: blockId)
          .where('apartmentNumber', isEqualTo: apartmentNumber)
          .get();

      final requests = querySnapshot.docs
          .map((doc) => FamilyRequestModel.fromFirestore(doc))
          .toList();

      // Сортируем на клиенте
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      loggingService.info('Found ${requests.length} family requests for $blockId-$apartmentNumber');
      return requests;
    } catch (e) {
      loggingService.error('Failed to get family requests by address', e);
      return [];
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _requestSubscription?.cancel();
    _requestsController.close();
  }
} 