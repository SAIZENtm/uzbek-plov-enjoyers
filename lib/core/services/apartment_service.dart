import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import '../models/apartment_model.dart';
import '../models/block_model.dart';
import 'logging_service_secure.dart';

class ApartmentService {
  late final FirebaseFirestore _firestore;
  final LoggingService loggingService;
  
  // Простой кэш для избежания повторных поисков
  final Map<String, List<ApartmentModel>> _apartmentCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  ApartmentService({required this.loggingService}) {
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  // Поиск квартиры по номеру и телефону
  Future<ApartmentModel?> findApartmentByNumberAndPhone({
    required String apartmentNumber,
    required String phoneNumber,
  }) async {
    try {
      loggingService.info('Searching for apartment: $apartmentNumber with phone: $phoneNumber');

      // Нормализуем телефонный номер (добавляем + если нужно)
      final normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
      loggingService.info('Normalized phone: $normalizedPhone');

      // СТРАТЕГИЯ 1: Ищем во ВСЕХ блоках через collectionGroup('apartments')
      loggingService.info('Strategy 1: Using collectionGroup("apartments") to search across all blocks');
      final querySnapshot = await _firestore
          .collectionGroup('apartments')
          .where('apartment_number', isEqualTo: apartmentNumber)
          .get();

      loggingService.info('Found ${querySnapshot.docs.length} potential matches by apartment_number in collectionGroup');

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        
        // Проверяем телефон владельца
        final docPhone = data['phone']?.toString() ?? '';
        if (docPhone == normalizedPhone || docPhone == phoneNumber) {
          final blockId = doc.reference.parent.parent?.id ?? 'Unknown';
          loggingService.info('Found matching apartment owner in block $blockId via collectionGroup');

          // Дополняем данными, чтобы модель знала блок и id документа
          final apartmentData = Map<String, dynamic>.from(data);
          apartmentData['block_name'] = '$blockId BLOK';
          apartmentData['document_id'] = doc.id;
          apartmentData['block_number'] = blockId;

          return ApartmentModel.fromJson(apartmentData);
        }

        // НОВОЕ: Проверяем телефоны членов семьи
        final familyMembers = data['familyMembers'] as List? ?? [];
        loggingService.info('🔍 DEBUG: Checking ${familyMembers.length} family members in apartment ${data['apartment_number']}');
        
        for (var memberData in familyMembers) {
          final memberPhone = memberData['phone']?.toString() ?? '';
          final memberName = memberData['name']?.toString() ?? 'Unknown';
          final isApproved = memberData['isApproved'] as bool? ?? false;
          
          loggingService.info('🔍 DEBUG: Family member: $memberName, phone: "$memberPhone", approved: $isApproved');
          loggingService.info('🔍 DEBUG: Comparing with input phone: "$normalizedPhone" and "$phoneNumber"');
          
          if (isApproved && (memberPhone == normalizedPhone || memberPhone == phoneNumber)) {
            final blockId = doc.reference.parent.parent?.id ?? 'Unknown';
            loggingService.info('✅ SUCCESS: Found matching family member in block $blockId: $memberName');

            // Дополняем данными
            final apartmentData = Map<String, dynamic>.from(data);
            apartmentData['block_name'] = '$blockId BLOK';
            apartmentData['document_id'] = doc.id;
            apartmentData['block_number'] = blockId;
            
            // Помечаем, что это член семьи
            apartmentData['_isFamilyMember'] = true;
            apartmentData['_familyMemberData'] = memberData;

            return ApartmentModel.fromJson(apartmentData);
          } else {
            loggingService.info('❌ No match: phone mismatch or not approved');
          }
        }
      }

      // СТРАТЕГИЯ 2: Ищем в коллекции users напрямую (квартиры как документы)
      loggingService.info('Strategy 2: Searching in users collection directly');
      final usersSnapshot = await _firestore
          .collection('users')
          .where('apartment_number', isEqualTo: apartmentNumber)
          .get();

      loggingService.info('Found ${usersSnapshot.docs.length} potential matches by apartment_number in users collection');

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        
        // Проверяем телефон владельца
        final docPhone = data['phone']?.toString() ?? '';
        if (docPhone == normalizedPhone || docPhone == phoneNumber) {
          loggingService.info('Found matching apartment owner in users collection');

          // Дополняем данными
          final apartmentData = Map<String, dynamic>.from(data);
          apartmentData['document_id'] = doc.id;
          
          // Если нет block_name, попробуем извлечь из block_number
          if (!apartmentData.containsKey('block_name') && apartmentData.containsKey('block_number')) {
            apartmentData['block_name'] = '${apartmentData['block_number']} BLOK';
          }

          return ApartmentModel.fromJson(apartmentData);
        }

        // НОВОЕ: Проверяем телефоны членов семьи
        final familyMembers = data['familyMembers'] as List? ?? [];
        for (var memberData in familyMembers) {
          final memberPhone = memberData['phone']?.toString() ?? '';
          final isApproved = memberData['isApproved'] as bool? ?? false;
          
          if (isApproved && (memberPhone == normalizedPhone || memberPhone == phoneNumber)) {
            loggingService.info('Found matching family member in users collection: ${memberData['name']}');

            // Дополняем данными
            final apartmentData = Map<String, dynamic>.from(data);
            apartmentData['document_id'] = doc.id;
            
            // Если нет block_name, попробуем извлечь из block_number
            if (!apartmentData.containsKey('block_name') && apartmentData.containsKey('block_number')) {
              apartmentData['block_name'] = '${apartmentData['block_number']} BLOK';
            }
            
            // Помечаем, что это член семьи
            apartmentData['_isFamilyMember'] = true;
            apartmentData['_familyMemberData'] = memberData;

            return ApartmentModel.fromJson(apartmentData);
          }
        }
      }

      // СТРАТЕГИЯ 3: Ищем по известным блокам (ОБНОВЛЕННЫЙ СПИСОК)
      loggingService.info('Strategy 3: Searching by known block names');
      final knownBlocks = [
        'D BLOK', 'E BLOK', 'F BLOK', 'G BLOK', 'H BLOK', 'I BLOK', 'J BLOK',
        'O3', 'O5',
        'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
        'A BLOK', 'B BLOK', 'C BLOK', 'BLOK A', 'BLOK B', 'BLOK C', 'BLOK D', 'BLOK E', 'BLOK F',
        'Block A', 'Block B', 'Block C', 'Block D', 'Block E', 'Block F'
      ];
      
      for (var blockId in knownBlocks) {
        try {
          final blockApartmentsSnapshot = await _firestore
              .collection('users')
              .doc(blockId)
              .collection('apartments')
              .where('apartment_number', isEqualTo: apartmentNumber)
              .get();

          loggingService.info('Block $blockId: Found ${blockApartmentsSnapshot.docs.length} apartments');

          for (var doc in blockApartmentsSnapshot.docs) {
            final data = doc.data();
            final docPhone = data['phone']?.toString() ?? '';

            if (docPhone == normalizedPhone || docPhone == phoneNumber) {
              loggingService.info('Found matching apartment in block $blockId subcollection');

              final apartmentData = Map<String, dynamic>.from(data);
              apartmentData['block_name'] = '$blockId BLOK';
              apartmentData['document_id'] = doc.id;
              apartmentData['block_number'] = blockId;

              return ApartmentModel.fromJson(apartmentData);
            }
          }
        } catch (e) {
          // Блок не существует, продолжаем
          loggingService.info('Block $blockId does not exist or has no apartments subcollection');
        }
      }

      loggingService.info('No apartment matched by phone across all strategies');
      return null;
    } catch (e, st) {
      loggingService.error('Error finding apartment: $e\n$st');
      return null;
    }
  }

  // Поиск всех квартир владельца по паспорту
  Future<List<ApartmentModel>> findAllApartmentsByPassport(String passportNumber) async {
    try {
      loggingService.info('🔍 === STARTING ENHANCED APARTMENT SEARCH BY PASSPORT ===');
      loggingService.info('   Passport Number: $passportNumber');
      
      // ВРЕМЕННО: Отключаем кэш для отладки
      loggingService.info('🔄 Fresh search (cache disabled for debugging)');
      
      loggingService.info('🔄 Fresh enhanced search for passport: $passportNumber');
      final allApartments = <ApartmentModel>[];

            // СТРАТЕГИЯ 1: Поиск через collectionGroup('apartments') - САМАЯ НАДЕЖНАЯ И БЫСТРАЯ
      loggingService.info('📋 Strategy 1: CollectionGroup search (FASTEST & MOST RELIABLE)');
      try {
        final querySnapshot = await _firestore
            .collectionGroup('apartments')
            .where('passport_number', isEqualTo: passportNumber)
            .get();

        loggingService.info('   Found ${querySnapshot.docs.length} apartments via collectionGroup');
        
        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          final blockId = doc.reference.parent.parent?.id ?? 'Unknown';
          final apartmentData = Map<String, dynamic>.from(data);
          apartmentData['block_name'] = '$blockId BLOK';
          apartmentData['document_id'] = doc.id;
          apartmentData['block_number'] = blockId;

          final apartment = ApartmentModel.fromJson(apartmentData);
          allApartments.add(apartment);
          loggingService.info('     ✅ Added: ${apartment.blockId} ${apartment.apartmentNumber} (${apartment.id})');
          loggingService.info('        Path: ${doc.reference.path}');
        }
        
        // Если нашли квартиры через collectionGroup, возвращаем результат сразу
        if (allApartments.isNotEmpty) {
          loggingService.info('🎯 === FAST SEARCH COMPLETED ===');
          loggingService.info('   Total apartments found: ${allApartments.length}');
          for (var apt in allApartments) {
            loggingService.info('     - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
          }
          return allApartments;
        }
      } catch (e) {
        loggingService.error('   ❌ CollectionGroup search failed: $e');
      }

      // СТРАТЕГИЯ 2: Поиск в коллекции users напрямую (если collectionGroup не сработал)
      if (allApartments.isEmpty) {
        loggingService.info('📋 Strategy 2: Users collection search (FALLBACK)');
        try {
          final usersSnapshot = await _firestore
              .collection('users')
              .where('passport_number', isEqualTo: passportNumber)
              .get();

          loggingService.info('   Found ${usersSnapshot.docs.length} apartments in users collection');

          for (var doc in usersSnapshot.docs) {
            final data = doc.data();
            final apartmentData = Map<String, dynamic>.from(data);
            apartmentData['document_id'] = doc.id;
            
            // Если нет block_name, попробуем извлечь из block_number
            if (!apartmentData.containsKey('block_name') && apartmentData.containsKey('block_number')) {
              apartmentData['block_name'] = '${apartmentData['block_number']} BLOK';
            }

            final apartment = ApartmentModel.fromJson(apartmentData);
            allApartments.add(apartment);
            loggingService.info('     ✅ Added: ${apartment.blockId} ${apartment.apartmentNumber} (${apartment.id})');
            loggingService.info('        Path: ${doc.reference.path}');
          }
        } catch (e) {
          loggingService.error('   ❌ Users collection search failed: $e');
        }
      }

      // СТРАТЕГИЯ 3: Быстрый поиск по основным блокам (если collectionGroup не сработал)
      if (allApartments.isEmpty) {
        loggingService.info('📋 Strategy 3: Quick main blocks search');
        final mainBlocks = ['D BLOK', 'E BLOK', 'F BLOK', 'G BLOK', 'H BLOK'];
        
        for (var blockId in mainBlocks) {
          try {
            final blockApartmentsSnapshot = await _firestore
                .collection('users')
                .doc(blockId)
                .collection('apartments')
                .where('passport_number', isEqualTo: passportNumber)
                .get();

            if (blockApartmentsSnapshot.docs.isNotEmpty) {
              loggingService.info('   Block $blockId: Found ${blockApartmentsSnapshot.docs.length} apartments');

              for (var doc in blockApartmentsSnapshot.docs) {
                final data = doc.data();
                final apartmentData = Map<String, dynamic>.from(data);
                apartmentData['block_name'] = '$blockId BLOK';
                apartmentData['document_id'] = doc.id;
                apartmentData['block_number'] = blockId;

                final apartment = ApartmentModel.fromJson(apartmentData);
                allApartments.add(apartment);
                loggingService.info('     ✅ Added: ${apartment.blockId} ${apartment.apartmentNumber} (${apartment.id})');
                loggingService.info('        Path: ${doc.reference.path}');
              }
            }
          } catch (e) {
            // Блок не существует, продолжаем
            loggingService.info('   Block $blockId: Does not exist or search failed: $e');
          }
        }
      }

      // СТРАТЕГИЯ 4: Быстрый поиск по известным блокам (только если collectionGroup не сработал)
      if (allApartments.isEmpty) {
        loggingService.info('📋 Strategy 4: Quick known blocks search (FALLBACK)');
        final quickBlocks = ['D BLOK', 'E BLOK', 'F BLOK', 'G BLOK', 'H BLOK']; // Только основные блоки
        
        for (var blockId in quickBlocks) {
          try {
            final blockApartmentsSnapshot = await _firestore
                .collection('users')
                .doc(blockId)
                .collection('apartments')
                .where('passport_number', isEqualTo: passportNumber)
                .get();

            if (blockApartmentsSnapshot.docs.isNotEmpty) {
              loggingService.info('   Block $blockId: Found ${blockApartmentsSnapshot.docs.length} apartments');

              for (var doc in blockApartmentsSnapshot.docs) {
                final data = doc.data();
                final apartmentData = Map<String, dynamic>.from(data);
                apartmentData['block_name'] = '$blockId BLOK';
                apartmentData['document_id'] = doc.id;
                apartmentData['block_number'] = blockId;

                final apartment = ApartmentModel.fromJson(apartmentData);
                allApartments.add(apartment);
                loggingService.info('     ✅ Added: ${apartment.blockId} ${apartment.apartmentNumber} (${apartment.id})');
                loggingService.info('        Path: ${doc.reference.path}');
              }
            }
          } catch (e) {
            // Блок не существует, продолжаем
            loggingService.info('   Block $blockId: Does not exist or search failed: $e');
          }
        }
      }

      // ВРЕМЕННО: Отключаем сохранение в кэш для отладки
      // _apartmentCache[cacheKey] = allApartments;
      // _cacheTimestamps[cacheKey] = now;

      loggingService.info('🎯 === ENHANCED APARTMENT SEARCH COMPLETED ===');
      loggingService.info('   Total apartments found: ${allApartments.length}');
      for (var apt in allApartments) {
        loggingService.info('     - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
      }
      loggingService.info('   Cache updated for passport: $passportNumber');
      
      return allApartments;
    } catch (e, st) {
      loggingService.error('❌ Error finding apartments by passport: $e\n$st');
      return [];
    }
  }

  // Получить квартиру по ID
  Future<ApartmentModel?> getApartmentById(String apartmentId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(apartmentId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final blockNumber = data['block_number']?.toString() ?? '';
        
        // Добавляем дополнительную информацию
        final apartmentData = Map<String, dynamic>.from(data);
        apartmentData['block_name'] = blockNumber.isNotEmpty ? '$blockNumber BLOK' : 'Unknown Block';
        apartmentData['document_id'] = doc.id;
        
        return ApartmentModel.fromJson(apartmentData);
      }
      return null;
    } catch (e) {
      loggingService.error('Error getting apartment by ID', e);
      return null;
    }
  }

  // Обновить данные квартиры
  Future<bool> updateApartment(String apartmentId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(apartmentId)
          .update({
        ...data,
        'updated_at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      loggingService.error('Error updating apartment', e);
      return false;
    }
  }

  // Получить все блоки (список документов в коллекции blocks)
  Future<List<BlockModel>> getAllBlocks() async {
    try {
      final snapshot = await _firestore.collection('blocks').get();
      loggingService.info('Found ${snapshot.docs.length} blocks');
      return snapshot.docs.map((doc) {
        return BlockModel(
          id: doc.id,
          name: '${doc.id} BLOK',
          address: 'Newport, ${doc.id} BLOK',
          totalFloors: 20,
          totalApartments: 0,
          status: 'active',
        );
      }).toList();
    } catch (e, st) {
      loggingService.error('Error getting blocks: $e\n$st');
      return [];
    }
  }

  // Проверить, есть ли у владельца другие квартиры
  Future<int> getOwnerApartmentCount(String passportNumber) async {
    try {
      final apartments = await findAllApartmentsByPassport(passportNumber);
      return apartments.length;
    } catch (e) {
      loggingService.error('Error counting owner apartments', e);
      return 0;
    }
  }

  // Очистить кэш квартир (для отладки)
  void clearApartmentCache() {
    _apartmentCache.clear();
    _cacheTimestamps.clear();
    loggingService.info('🗑️ Apartment cache cleared');
  }
} 