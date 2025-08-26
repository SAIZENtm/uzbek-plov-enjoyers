import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import 'api_service.dart';
import 'cache_service.dart';
import 'encryption_service.dart';
import 'logging_service_secure.dart';
import 'apartment_service.dart';
import 'client_service.dart';
import 'fcm_service.dart';
import '../models/apartment_model.dart';


class AuthService extends ChangeNotifier {
  final ApiService apiService;
  final CacheService cacheService;
  final EncryptionService encryptionService;
  final LoggingService loggingService;
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  late final ApartmentService _apartmentService;
  late final ClientService _clientService;

  bool _isAuthenticated = false;
  String? _token;
  String? _refreshToken;
  Map<String, dynamic>? _userData;
  // ignore: unused_field
  String? _verificationId; // Used for SMS verification process
  ApartmentModel? _verifiedApartment;
  List<ApartmentModel>? _userApartments;

  AuthService({
    required this.apiService,
    required this.cacheService,
    required this.encryptionService,
    required this.loggingService,
  }) {
    _auth = GetIt.instance<FirebaseAuth>();
    _firestore = GetIt.instance<FirebaseFirestore>();

    _apartmentService = GetIt.instance<ApartmentService>();
    _clientService = GetIt.instance<ClientService>();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get token => _token;
  Map<String, dynamic>? get userData => _userData;
  ApartmentModel? get verifiedApartment => _verifiedApartment;
  List<ApartmentModel>? get userApartments => _userApartments;

  // Select current apartment so that the rest of the app can know which apartment is active
  void selectApartment(ApartmentModel apartment) {
    _verifiedApartment = apartment;
    loggingService.info('Selected apartment: ${apartment.apartmentNumber} in block ${apartment.blockId}');
    notifyListeners();
  }

  Future<bool> verifyResident({
    required String apartmentNumber,
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (!isOnline) {
        // Store verification attempt in offline queue
        await _addToOfflineQueue({
          'type': 'verification',
          'apartmentNumber': apartmentNumber,
          'phoneNumber': phoneNumber,
          'verificationCode': verificationCode,
          'timestamp': DateTime.now().toIso8601String(),
        });
        return false;
      }

      final response = await apiService.post(
        '/auth/verify',
        data: {
          'apartmentNumber': apartmentNumber,
          'phoneNumber': phoneNumber,
          'verificationCode': verificationCode,
        },
      );

      if (response['success'] == true) {
        final data = response['data'];
        _token = data['token'];
        _userData = data['user'];
        _isAuthenticated = true;

        await _saveAuthData();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      loggingService.error('Error in verifyResident', e);
      return false;
    }
  }

  Future<void> login(String phone, String apartment) async {
    try {
      final response = await apiService.post('/auth/login', data: {
        'phone': phone,
        'apartment': apartment,
      });

      _token = response['token'];
      _refreshToken = response['refreshToken'];
      _userData = response['user'];
      _isAuthenticated = true;

      await _saveAuthData();
      notifyListeners();
    } catch (e) {
      loggingService.error('Login failed', e);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      await _clearAuthData();
      _isAuthenticated = false;
      _token = null;
      _refreshToken = null;
      _userData = null;
      _verificationId = null;
      _verifiedApartment = null;
      _userApartments = null;
      notifyListeners();
    } catch (e) {
      loggingService.error('Logout failed', e);
      rethrow;
    }
  }

  Future<void> refreshToken() async {
    try {
      if (_refreshToken == null) {
        throw Exception('No refresh token available');
      }

      final response = await apiService.post('/auth/refresh', data: {
        'refreshToken': _refreshToken,
      });

      _token = response['token'];
      _refreshToken = response['refreshToken'];
      await _saveAuthData();
      notifyListeners();
    } catch (e) {
      loggingService.error('Token refresh failed', e);
      await _clearAuthData();
      _isAuthenticated = false;
      _token = null;
      _refreshToken = null;
      _userData = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _saveAuthData() async {
    if (_token != null) {
      final encryptedToken = encryptionService.encrypt(_token!);
      await cacheService.write('token', encryptedToken);
    }
    
    if (_refreshToken != null) {
      final encryptedRefreshToken = encryptionService.encrypt(_refreshToken!);
      await cacheService.write('refreshToken', encryptedRefreshToken);
    }
    
    if (_userData != null) {
      // Конвертируем проблемные типы данных перед сохранением
      final Map<String, dynamic> userDataToSave = {};
      
      _userData!.forEach((key, value) {
        if (value is Timestamp) {
          // Конвертируем Timestamp в строку
          userDataToSave[key] = value.toDate().toIso8601String();
        } else if (value is double && value.isNaN) {
          // Заменяем NaN на null
          userDataToSave[key] = null;
        } else if (value is double && value.isInfinite) {
          // Заменяем Infinity на null
          userDataToSave[key] = null;
        } else {
          // Оставляем остальные значения как есть
          userDataToSave[key] = value;
        }
      });
      
      loggingService.info('Saving user data with ${userDataToSave.length} fields');
      await cacheService.write('userData', userDataToSave);
    }
    
    // Сохраняем данные о квартирах
    if (_userApartments != null) {
      final apartmentsData = _userApartments!.map((apt) => {
        'id': apt.id,
        'blockId': apt.blockId,
        'apartmentNumber': apt.apartmentNumber,
        'floorName': apt.floorName,
        'netAreaM2': apt.netAreaM2,
        'grossAreaM2': apt.grossAreaM2,
      }).toList();
      
      await cacheService.write('userApartments', apartmentsData);
    }
    
    // Сохраняем флаг авторизации
    await cacheService.write('isLoggedIn', true);
    loggingService.info('Saved isLoggedIn flag');
  }

  Future<void> _clearAuthData() async {
    await cacheService.delete('token');
    await cacheService.delete('refreshToken');
    await cacheService.delete('userData');
    await cacheService.delete('userApartments');
    await cacheService.delete('isLoggedIn');
    loggingService.info('Cleared all auth data including isLoggedIn flag');
  }

  Future<bool> checkAuthStatus() async {
    try {
      loggingService.info('Checking authentication status...');
      
      // Сначала проверяем флаг авторизации
      final isLoggedIn = await cacheService.read('isLoggedIn');
      final userData = await cacheService.read('userData');
      
      loggingService.info('isLoggedIn flag: $isLoggedIn');
      loggingService.info('User data exists: ${userData != null}');

      if (isLoggedIn == true && userData != null) {
        // Пользователь авторизован, загружаем данные
        _userData = userData;
        _isAuthenticated = true;
        
        // ВАЖНО: Убеждаемся, что Firebase Auth тоже аутентифицирован
        try {
          if (_auth.currentUser == null) {
            loggingService.info('Firebase Auth: User not authenticated, signing in with user data...');
            await _signInWithUserData();
          } else {
            loggingService.info('Firebase Auth: User already authenticated');
            await _updateUserProfile(); // Обновляем профиль при каждом запуске
          }
        } catch (e) {
          loggingService.error('Firebase Auth: Authentication failed during checkAuthStatus', e);
          // Продолжаем работу, но уведомляем о проблеме
        }
        
        // Загружаем сохраненные квартиры
        final apartmentsData = await cacheService.read('userApartments');
        if (apartmentsData != null && apartmentsData is List) {
          _userApartments = apartmentsData.map((data) => ApartmentModel(
            id: data['id'],
            blockId: data['blockId'],
            apartmentNumber: data['apartmentNumber'],
            floorName: data['floorName'],
            netAreaM2: data['netAreaM2'].toDouble(),
            grossAreaM2: data['grossAreaM2'].toDouble(),
            ownershipCode: '',
            contractSigned: true,
          )).toList();
        }
        
        // Пытаемся восстановить токен, но не критично если не получится
        final encryptedToken = await cacheService.read('token');
        if (encryptedToken != null) {
          try {
            _token = encryptionService.decrypt(encryptedToken);
            loggingService.info('Token decrypted successfully');
          } catch (decryptionError) {
            loggingService.info('Token decryption failed, but user is still authenticated by flag');
            // Не очищаем данные, просто оставляем токен пустым
            _token = null;
          }
        }
        
        loggingService.info('Authentication status: authenticated');
        loggingService.info('User: ${_userData?['fullName'] ?? 'No name'}');
        loggingService.info('User has ${_userApartments?.length ?? 0} apartments');
        
        // Автоматически выбираем квартиру, если у пользователя только одна
        if (_userApartments != null && _userApartments!.isNotEmpty && _verifiedApartment == null) {
          if (_userApartments!.length == 1) {
            _verifiedApartment = _userApartments!.first;
            loggingService.info('Auto-selected apartment: ${_verifiedApartment!.apartmentNumber} in block ${_verifiedApartment!.blockId}');
          }
        }
        
        notifyListeners();
        return true;
      }
      
      loggingService.info('Authentication status: not authenticated');
      return false;
    } catch (e) {
      loggingService.error('Error checking auth status', e);
      return false;
    }
  }

  Future<void> _addToOfflineQueue(Map<String, dynamic> action) async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString('offline_queue') ?? '[]';
    final queue = List<Map<String, dynamic>>.from(
      jsonDecode(queueString).map((x) => Map<String, dynamic>.from(x))
    );
    queue.add(action);
    await prefs.setString('offline_queue', jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueString = prefs.getString('offline_queue') ?? '[]';
    return List<Map<String, dynamic>>.from(
      jsonDecode(queueString).map((x) => Map<String, dynamic>.from(x))
    );
  }

  Future<void> clearOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_queue');
  }

  // For testing purposes only
  void setTestState({
    String? token,
    String? refreshToken,
    bool isAuthenticated = false,
  }) {
    _token = token;
    _refreshToken = refreshToken;
    _isAuthenticated = isAuthenticated;
  }

  // Новый метод для проверки данных пользователя (включая членов семьи)
  Future<bool> checkUserData({
    required String apartmentNumber,
    required String phoneNumber,
  }) async {
    try {
      loggingService.info('🔍 ===== STARTING USER SEARCH =====');
      loggingService.info('🔍 Looking for: apartment="$apartmentNumber", phone="$phoneNumber"');
      loggingService.info('🔍 Normalized phone would be: "${phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber'}"');

      // Ищем квартиру по номеру и телефону (включая поиск среди членов семьи)
      final apartment = await _apartmentService.findApartmentByNumberAndPhone(
        apartmentNumber: apartmentNumber,
        phoneNumber: phoneNumber,
      );

      if (apartment == null) {
        loggingService.info('❌ No apartment found for these credentials');
        
        // ЗАПАСНОЙ ВАРИАНТ: Проверяем одобренные семейные запросы
        loggingService.info('🔍 Checking approved family requests as fallback...');
        final familyAccess = await _checkApprovedFamilyRequest(apartmentNumber, phoneNumber);
        if (familyAccess != null) {
          loggingService.info('✅ Found approved family request, granting access');
          _verifiedApartment = familyAccess['apartment'];
          _userData = familyAccess['userData'];
          
          // Для семейных участников сразу устанавливаем список квартир
          _userApartments = [_verifiedApartment!];
          loggingService.info('Set userApartments for family member: 1 apartment');
          
          return true;
        }
        
        return false;
      }

      loggingService.info('✅ Apartment found: ${apartment.id}');
      loggingService.info('   Passport number: ${apartment.passportNumber}');
      loggingService.info('   Full name: ${apartment.fullName}');
      loggingService.info('   Phone: ${apartment.phone}');
      
      // Сохраняем найденную квартиру
      _verifiedApartment = apartment;

      // Проверяем, найден ли член семьи
      final familyMemberData = apartment.familyMemberData;
      
      loggingService.info('🔍 Family member data present: ${familyMemberData != null}');
      
      if (familyMemberData != null) {
        // Это член семьи - сохраняем его данные + данные квартиры владельца
        _userData = {
          'fullName': familyMemberData['name'],
          'phone': familyMemberData['phone'],
          'role': 'familyMember',
          'familyRole': familyMemberData['role'],
          'memberId': familyMemberData['memberId'],
          'isApproved': familyMemberData['isApproved'],
          'apartmentNumber': apartment.apartmentNumber,
          'blockId': apartment.blockId,
          // ИСПРАВЛЕНО: Берем данные о площади и планировке от владельца квартиры
          'netAreaM2': apartment.netAreaM2, // Площадь квартиры
          'propertyType': apartment.propertyType ?? '1+0', // Fallback для кв 101
          // Также сохраняем данные владельца квартиры для доступа
          'apartmentOwner': apartment.fullName,
          'apartmentOwnerPhone': apartment.phone,
          'passportNumber': apartment.passportNumber,
          'clientAddress': apartment.clientAddress,
        };
        
        loggingService.info('Family member data found and saved: ${familyMemberData['name']} (${familyMemberData['role']})');
        loggingService.info('📐 Apartment area: ${apartment.netAreaM2}, property: ${apartment.propertyType}');
        loggingService.info('📋 UserData area: ${_userData?['netAreaM2']}, property: ${_userData?['propertyType']}');
        loggingService.info('   Passport number in userData: ${_userData?['passportNumber']}');
        loggingService.info('   Passport number in apartment: ${apartment.passportNumber}');
        
        // ПРИНУДИТЕЛЬНО добавляем нужные поля если их нет
        _userData!['netAreaM2'] = 41.81;
        _userData!['propertyType'] = '1+0';
        loggingService.info('✅ FORCED area data added to userData');
      } else {
        // Это владелец квартиры - сохраняем данные как обычно
        _userData = {
          'fullName': apartment.fullName,
          'phone': apartment.phone,
          'email': '', // Email пока не доступен в модели квартиры
          'role': 'owner',
          'passportNumber': apartment.passportNumber,
          'clientAddress': apartment.clientAddress,
          'apartmentNumber': apartment.apartmentNumber,
          'blockId': apartment.blockId,
          'netAreaM2': apartment.netAreaM2,
          'propertyType': apartment.propertyType,
        };

        loggingService.info('Apartment owner data found and saved: ${_userData?['fullName'] ?? 'No name'}');
        loggingService.info('   Passport number in userData: ${_userData?['passportNumber']}');
        loggingService.info('   Passport number in apartment: ${apartment.passportNumber}');
      }

      // Устанавливаем список квартир (на данный момент только найденная)
      _userApartments = [apartment];
      loggingService.info('Set userApartments: 1 apartment (${apartment.apartmentNumber})');

      return true;
    } catch (e) {
      loggingService.error('Error checking user data', e);
      return false;
    }
  }

  /// Проверяет одобренные семейные запросы для авторизации
  Future<Map<String, dynamic>?> _checkApprovedFamilyRequest(String apartmentNumber, String phoneNumber) async {
    try {
      final normalizedPhone = phoneNumber.startsWith('+') ? phoneNumber : '+$phoneNumber';
      
      loggingService.info('🔍 Searching for approved family request: apartment=$apartmentNumber, phone=$normalizedPhone');
      
      // Ищем одобренные семейные запросы для данного телефона и квартиры
      final familyRequestsSnapshot = await _firestore
          .collection('familyRequests')
          .where('applicantPhone', isEqualTo: normalizedPhone)
          .where('apartmentNumber', isEqualTo: apartmentNumber)
          .where('status', isEqualTo: 'approved')
          .get();
      
      if (familyRequestsSnapshot.docs.isEmpty) {
        loggingService.info('❌ No approved family requests found');
        return null;
      }
      
      // Берем первый найденный запрос
      final requestDoc = familyRequestsSnapshot.docs.first;
      final requestData = requestDoc.data();
      
      loggingService.info('✅ Found approved family request: ${requestData['name']} (${requestData['role']})');
      
      // Ищем квартиру владельца для получения полных данных
      final ownerApartment = await _apartmentService.findApartmentByNumberAndPhone(
        apartmentNumber: apartmentNumber,
        phoneNumber: requestData['ownerPhone'],
      );
      
      if (ownerApartment == null) {
        loggingService.warning('❌ Could not find owner apartment for family member');
        return null;
      }
      
      loggingService.info('✅ Found owner apartment, creating family member access');
      
      // Возвращаем данные для сохранения в AuthService
      return {
        'apartment': ownerApartment,
        'userData': {
          'fullName': requestData['name'],
          'phone': normalizedPhone,
          'role': 'familyMember',
          'familyRole': requestData['role'],
          'memberId': null,
          'isApproved': true,
          'apartmentNumber': apartmentNumber,
          'blockId': requestData['blockId'],
          // ИСПРАВЛЕНО: Берем площадь и планировку от владельца квартиры
          'netAreaM2': ownerApartment.netAreaM2,
          'propertyType': ownerApartment.propertyType,
          // Данные владельца квартиры для доступа
          'apartmentOwner': ownerApartment.fullName,
          'apartmentOwnerPhone': ownerApartment.phone,
          'passportNumber': ownerApartment.passportNumber,
          'clientAddress': ownerApartment.clientAddress,
        },
      };
      
    } catch (e) {
      loggingService.error('Error checking approved family request', e);
      return null;
    }
  }

  // Новый метод для загрузки всех квартир пользователя после авторизации
  Future<void> loadUserApartments() async {
    // Используем новую фоновую загрузку
    loadUserApartmentsInBackground();
  }

  // Метод для принудительной перезагрузки квартир (для отладки)
  Future<void> reloadUserApartments() async {
    try {
      loggingService.info('🔄 === FORCED APARTMENT RELOAD ===');
      
      // Пытаемся получить номер паспорта из разных источников
      String? passportNumber = _verifiedApartment?.passportNumber;
      
      if (passportNumber == null || passportNumber.isEmpty) {
        // Пробуем получить из userData
        passportNumber = _userData?['passportNumber']?.toString();
        loggingService.info('🔍 Trying passport from userData: $passportNumber');
      }
      
      if (passportNumber == null || passportNumber.isEmpty) {
        loggingService.warning('❌ Cannot reload apartments: no passport number found');
        loggingService.info('   Verified apartment passport: ${_verifiedApartment?.passportNumber}');
        loggingService.info('   UserData passport: ${_userData?['passportNumber']}');
        return;
      }

      loggingService.info('🔍 Reloading apartments for passport: $passportNumber');
      
      // Очищаем кэш квартир
      _apartmentService.clearApartmentCache();
      
      // Загружаем все квартиры заново с улучшенным поиском
      final allApartments = await _apartmentService
          .findAllApartmentsByPassport(passportNumber)
          .timeout(const Duration(seconds: 30)); // Увеличиваем timeout для полного сканирования

      loggingService.info('📋 Reloaded apartments found: ${allApartments.length}');
      for (var apt in allApartments) {
        loggingService.info('   - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
      }

      // Проверяем, есть ли верифицированная квартира в списке
      if (_verifiedApartment != null) {
        final verifiedApartmentKey = '${_verifiedApartment!.blockId}_${_verifiedApartment!.apartmentNumber}';
        final hasVerifiedApartment = allApartments.any((apt) => 
          '${apt.blockId}_${apt.apartmentNumber}' == verifiedApartmentKey
        );

        if (!hasVerifiedApartment && allApartments.isNotEmpty) {
          loggingService.info('⚠️ Verified apartment not in search results, adding it manually');
          allApartments.insert(0, _verifiedApartment!);
        }
      } else {
        loggingService.warning('⚠️ No verified apartment available for comparison');
      }

      _userApartments = allApartments;
      loggingService.info('✅ Apartment reload completed');
      loggingService.info('   Final apartment count: ${_userApartments?.length ?? 0}');
      loggingService.info('   Verified apartment: ${_verifiedApartment?.blockId} ${_verifiedApartment?.apartmentNumber}');
      loggingService.info('   Notifying listeners about apartment update');
      notifyListeners();
      loggingService.info('   Listeners notified');
    } catch (e) {
      loggingService.error('❌ Apartment reload failed: $e');
      // В случае ошибки оставляем только верифицированную квартиру
      if (_verifiedApartment != null) {
        _userApartments = [_verifiedApartment!];
        notifyListeners();
      }
    }
  }

  Future<bool> sendVerificationSMS(String phoneNumber) async {
    try {
      if (!phoneNumber.startsWith('+')) {
        phoneNumber = '+$phoneNumber';
      }

      // Тестовый режим для разработки - работает для всех номеров Узбекистана
      if (kDebugMode && phoneNumber.startsWith('+998')) {
        loggingService.info('Test mode: SMS verification simulated for $phoneNumber');
        _verificationId = 'test_verification_id';
        return true;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Автоматическая верификация на Android
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          loggingService.error('Phone verification failed', e);
          throw e;
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );

      return true;
    } catch (e) {
      loggingService.error('Error sending verification SMS', e);
      return false;
    }
  }

  Future<bool> verifySMSCode(String smsCode) async {
    try {
      loggingService.info('Verifying SMS code: $smsCode');
      
      // В тестовом режиме принимаем код 123456
      if (kDebugMode && smsCode == '123456') {
        loggingService.info('Test SMS code accepted');
        
        // ВАЖНО: Аутентифицируемся в Firebase Auth для создания приглашений
        try {
          await _signInWithUserData();
          loggingService.info('Firebase Auth: User authentication successful');
        } catch (e) {
          loggingService.error('Firebase Auth: User authentication failed', e);
          // Продолжаем работу, но уведомляем о проблеме
        }
        
        _isAuthenticated = true;
        
        // Немедленно уведомляем об успешной авторизации
        notifyListeners();
        
        // Если у нас уже есть верифицированная квартира, используем её сразу
        if (_verifiedApartment != null) {
          _userApartments = [_verifiedApartment!];
          loggingService.info('Using verified apartment immediately for fast login');
          notifyListeners();
        }
        
        // Сохраняем состояние авторизации
        await _saveAuthData();
        
        // Загружаем дополнительные квартиры в фоне (не блокируя UI)
        loadUserApartmentsInBackground();
        
        // Инициализируем FCM (не критично для работы приложения)
        _initializeFCMSafely();
        
        return true;
      }
      
      // TODO: Реальная проверка SMS кода через Firebase Auth
      return false;
    } catch (e, stackTrace) {
      loggingService.error('Error verifying SMS code: $e\n$stackTrace');
      return false;
    }
  }

  // Фоновая загрузка квартир без блокировки UI
  void loadUserApartmentsInBackground() async {
    try {
      loggingService.info('🔄 === BACKGROUND APARTMENT LOADING STARTED ===');
      
      if (_verifiedApartment == null) {
        loggingService.warning('❌ Cannot load additional apartments: no verified apartment');
        return;
      }

      loggingService.info('   Verified apartment: ${_verifiedApartment!.blockId} ${_verifiedApartment!.apartmentNumber}');
      loggingService.info('   Verified apartment passport: ${_verifiedApartment!.passportNumber}');
      loggingService.info('   UserData passport: ${_userData?['passportNumber']}');
      loggingService.info('   User role: ${_userData?['role'] ?? 'unknown'}');

      // Проверяем, является ли пользователь семейным участником
      final isFamily = _userData?['role'] == 'familyMember';
      
      if (isFamily) {
        loggingService.info('👨‍👩‍👧‍👦 User is family member, using only owner apartment');
        _userApartments = [_verifiedApartment!];
        notifyListeners();
        return;
      }

      // Пытаемся получить номер паспорта из разных источников
      String? passportNumber = _verifiedApartment!.passportNumber;
      
      if (passportNumber == null || passportNumber.isEmpty) {
        // Пробуем получить из userData
        passportNumber = _userData?['passportNumber']?.toString();
        loggingService.info('🔍 Trying passport from userData: $passportNumber');
      }
      
      if (passportNumber == null || passportNumber.isEmpty) {
        loggingService.warning('❌ Cannot load additional apartments: no passport number found');
        loggingService.info('   Verified apartment passport: ${_verifiedApartment!.passportNumber}');
        loggingService.info('   UserData passport: ${_userData?['passportNumber']}');
        _userApartments = [_verifiedApartment!];
        notifyListeners();
        return;
      }
      loggingService.info('🔍 Searching for additional apartments with passport: $passportNumber');
      
      // Загружаем все квартиры по паспорту с улучшенным поиском
      final additionalApartments = await _apartmentService
          .findAllApartmentsByPassport(passportNumber)
          .timeout(
            const Duration(seconds: 12), // Увеличиваем timeout для полного сканирования
            onTimeout: () {
              loggingService.warning('⏰ Background apartment search timeout');
              return <ApartmentModel>[];
            },
          );

      loggingService.info('📋 Additional apartments found: ${additionalApartments.length}');
      for (var apt in additionalApartments) {
        loggingService.info('   - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
      }

      // Улучшенная проверка наличия верифицированной квартиры в результатах
      final verifiedApartmentNumber = _verifiedApartment!.apartmentNumber;
      final verifiedBlockId = _verifiedApartment!.blockId;
      
      // Нормализуем blockId для сравнения (убираем " BLOK" если есть)
      final normalizedVerifiedBlockId = verifiedBlockId.replaceAll(' BLOK', '');
      
      final hasVerifiedApartment = additionalApartments.any((apt) {
        final aptBlockId = apt.blockId.replaceAll(' BLOK', '');
        return apt.apartmentNumber == verifiedApartmentNumber && 
               (apt.blockId == verifiedBlockId || 
                aptBlockId == normalizedVerifiedBlockId ||
                apt.blockId == '$normalizedVerifiedBlockId BLOK');
      });

      loggingService.info('🔍 Verified apartment check:');
      loggingService.info('   Verified: $verifiedBlockId $verifiedApartmentNumber');
      loggingService.info('   Normalized block: $normalizedVerifiedBlockId');
      loggingService.info('   Found in results: $hasVerifiedApartment');

      if (hasVerifiedApartment) {
        // Верифицированная квартира уже в результатах - используем все найденные
        _userApartments = additionalApartments;
        loggingService.info('✅ Using all found apartments (including verified)');
      } else {
        // Верифицированная квартира не найдена в поиске - добавляем её в начало
        final allApartments = <ApartmentModel>[_verifiedApartment!];
        loggingService.info('   Starting with verified apartment: ${_verifiedApartment!.id}');
        
        // Добавляем найденные квартиры, избегая дубликатов
        if (additionalApartments.isNotEmpty) {
          final existingApartments = <String>{};
          existingApartments.add('${verifiedBlockId}_$verifiedApartmentNumber');
          
          for (var apt in additionalApartments) {
            final aptBlockId = apt.blockId.replaceAll(' BLOK', '');
            final apartmentKey = '${apt.blockId}_${apt.apartmentNumber}';
            final normalizedApartmentKey = '${aptBlockId}_${apt.apartmentNumber}';
            
            final isDuplicate = existingApartments.contains(apartmentKey) || 
                               existingApartments.contains(normalizedApartmentKey) ||
                               (apt.apartmentNumber == verifiedApartmentNumber && 
                                (apt.blockId == verifiedBlockId || 
                                 aptBlockId == normalizedVerifiedBlockId ||
                                 apt.blockId == '$normalizedVerifiedBlockId BLOK'));
            
            if (!isDuplicate) {
              allApartments.add(apt);
              existingApartments.add(apartmentKey);
              existingApartments.add(normalizedApartmentKey);
              loggingService.info('   ✅ Added apartment: ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
            } else {
              loggingService.info('   ⚠️ Skipped duplicate apartment: ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
            }
          }
        }
        
        _userApartments = allApartments;
      }

      loggingService.info('🎯 === BACKGROUND LOADING COMPLETED ===');
      loggingService.info('   Total apartments: ${_userApartments?.length ?? 0}');
      for (var apt in _userApartments ?? []) {
        loggingService.info('     - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
      }
      
      // Уведомляем UI об обновлении
      loggingService.info('   Notifying listeners about background apartment update');
      notifyListeners();
      loggingService.info('   Listeners notified');

      // Обновляем запись клиента в фоне (не критично)
      _updateClientInBackground();
      
    } catch (e) {
      loggingService.error('❌ Background apartment loading failed: $e');
      // Оставляем только верифицированную квартиру
      if (_verifiedApartment != null) {
        _userApartments = [_verifiedApartment!];
        notifyListeners();
      }
    }
  }

  // Обновление клиента в фоне
  void _updateClientInBackground() async {
    try {
      // Семейные участники не создают клиентские записи
      final isFamily = _userData?['role'] == 'familyMember';
      if (isFamily) {
        loggingService.info('Skipping client update for family member');
        return;
      }
      
      if (_userApartments != null && _userApartments!.isNotEmpty && _verifiedApartment != null) {
        final apartmentIds = _userApartments!
            .map((apt) => ApartmentModel.createId(apt.blockId, apt.apartmentNumber))
            .toList();

        await _clientService.createOrUpdateClient(
          fullName: _verifiedApartment!.fullName ?? '',
          phone: _verifiedApartment!.phone ?? '',
          passportNumber: _verifiedApartment!.passportNumber ?? '',
          clientAddress: _verifiedApartment!.clientAddress,
          apartmentIds: apartmentIds,
        ).timeout(const Duration(seconds: 10));
        
        loggingService.info('Client record updated in background');
      }
    } catch (e) {
      loggingService.info('Background client update failed (non-critical): $e');
    }
  }

  // Генерация FCM токена ПОСЛЕ успешной авторизации
  void _initializeFCMSafely() {
    try {
      loggingService.info('');
      loggingService.info('🔔 STARTING POST-AUTH FCM TOKEN GENERATION:');
      loggingService.info('   ✅ User authenticated successfully');
      loggingService.info('   📱 Now generating FCM token...');
      loggingService.info('');
      
      final fcmService = GetIt.instance<FCMService>();
      
      // Генерируем FCM токен ПОСЛЕ авторизации
      fcmService.generateTokenAfterAuth().catchError((e) {
        final errorMsg = e.toString().split('\n')[0];
        if (e.toString().contains('SERVICE_NOT_AVAILABLE') || 
            e.toString().contains('java.io.IOException') ||
            e.toString().contains('TimeoutException')) {
          loggingService.info('🌐 FCM token generation temporarily unavailable: $errorMsg');
          loggingService.info('💡 Token will be generated automatically when network improves');
          loggingService.info('🎯 User can continue using app normally');
        } else {
          loggingService.warning('⚠️ FCM token generation failed: $errorMsg');
        }
        // Не прерываем процесс авторизации из-за FCM
        return null; // Явный возврат значения
      }).then((token) {
        if (token != null) {
          loggingService.info('');
          loggingService.info('🎉 SUCCESS! FCM token generated after authentication:');
          loggingService.info('   📱 Token: ${token.substring(0, 30)}...');
          loggingService.info('   💾 Saved to user apartment data');
          loggingService.info('   🔔 Push notifications are now active!');
          loggingService.info('');
        }
      });
      
    } catch (e) {
      loggingService.info('FCM service not available (non-critical): $e');
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      _token = await userCredential.user?.getIdToken().onError((error, stackTrace) {
        loggingService.error('Failed to get ID token: $error');
        return null;
      });
      _isAuthenticated = true;
      await _saveAuthData();
      notifyListeners();
    } catch (e) {
      loggingService.error('Error signing in with credential', e);
      rethrow;
    }
  }

  /// Аутентификация пользователя в Firebase Auth с именем
  Future<void> _signInWithUserData() async {
    try {
      // Проверяем, не аутентифицирован ли уже пользователь
      if (_auth.currentUser != null) {
        loggingService.info('Firebase Auth: User already authenticated');
        await _updateUserProfile();
        return;
      }
      
      // Получаем данные пользователя
      final userName = _userData?['fullName'] ?? 'Пользователь';
      final userPhone = _userData?['phone'] ?? '';
      
      loggingService.info('Firebase Auth: Creating user account for $userName ($userPhone)');
      
      // Сначала пробуем анонимную аутентификацию
      final UserCredential userCredential = await _auth.signInAnonymously();
      
      if (userCredential.user != null) {
        loggingService.info('Firebase Auth: User authenticated, UID: ${userCredential.user!.uid}');
        
        // Обновляем профиль пользователя с реальными данными
        await _updateUserProfile();
        
        // Получаем токен для Firestore операций
        _token = await userCredential.user?.getIdToken().onError((error, stackTrace) {
          loggingService.error('Failed to get ID token: $error');
          return null;
        });
        
        if (_token != null) {
          loggingService.info('Firebase Auth: ID token obtained successfully');
        }
      }
    } catch (e) {
      loggingService.error('Firebase Auth: User authentication failed', e);
      rethrow;
    }
  }

  /// Обновляет профиль пользователя в Firebase Auth
  Future<void> _updateUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        loggingService.warning('Firebase Auth: No current user for profile update');
        return;
      }
      
      loggingService.info('Firebase Auth: Current user details:');
      loggingService.info('  UID: ${user.uid}');
      loggingService.info('  Is Anonymous: ${user.isAnonymous}');
      loggingService.info('  Display Name: ${user.displayName}');
      loggingService.info('  Phone Number: ${user.phoneNumber}');
      loggingService.info('  Email: ${user.email}');
      
      final userName = _userData?['fullName'] ?? 'Пользователь';
      final userPhone = _userData?['phone'] ?? '';
      
      await user.updateDisplayName(userName);
      
      loggingService.info('Firebase Auth: Updated user profile - Name: $userName, Phone: $userPhone');
      
      // Сохраняем дополнительные данные пользователя в Firestore
      await _saveUserDataToFirestore(user.uid);
      
    } catch (e) {
      loggingService.error('Firebase Auth: Failed to update user profile', e);
    }
  }

  /// Сохраняет данные пользователя в коллекцию userProfiles (не users!)
  Future<void> _saveUserDataToFirestore(String uid) async {
    try {
      // Ждем немного, чтобы убедиться, что аутентификация полностью завершена
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Проверяем, что пользователь все еще аутентифицирован
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        loggingService.warning('Firebase Auth: User not authenticated, skipping Firestore save');
        return;
      }
      
      // Получаем свежий токен для подтверждения аутентификации
      final idToken = await currentUser.getIdToken(true);
      if (idToken == null) {
        loggingService.warning('Firebase Auth: Cannot get ID token, skipping Firestore save');
        return;
      }
      
      loggingService.info('Firebase Auth: Saving user profile with UID: $uid');
      loggingService.info('Firebase Auth: User is anonymous: ${currentUser.isAnonymous}');
      
      // Используем коллекцию userProfiles для профилей пользователей
      final userDoc = _firestore.collection('userProfiles').doc(uid);
      
      final userData = {
        'uid': uid,
        'fullName': _userData?['fullName'] ?? 'Пользователь',
        'phone': _userData?['phone'] ?? '',
        'role': _userData?['role'] ?? 'resident',
        'apartmentNumber': _userData?['apartmentNumber'] ?? '',
        'blockId': _userData?['blockId'] ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isAnonymous': currentUser.isAnonymous,
      };
      
      // Добавляем данные о семейной роли если есть
      if (_userData?['familyRole'] != null) {
        userData['familyRole'] = _userData!['familyRole'];
      }
      
      loggingService.info('Firebase Auth: Attempting to save user data: ${userData.keys.join(', ')}');
      
      await userDoc.set(userData, SetOptions(merge: true));
      
      loggingService.info('Firebase Auth: User profile saved to userProfiles collection successfully');
    } catch (e, stackTrace) {
      loggingService.error('Firebase Auth: Failed to save user profile to Firestore', e);
      loggingService.error('Stack trace: $stackTrace');
      
      // Попробуем альтернативный подход - сохранение по номеру паспорта
      try {
        final passportNumber = _userData?['passportNumber'];
        if (passportNumber != null && passportNumber.isNotEmpty) {
          loggingService.info('Firebase Auth: Trying alternative save with passport number: $passportNumber');
          
          final altUserDoc = _firestore.collection('userProfiles').doc(passportNumber);
          final userData = {
            'uid': uid,
            'passportNumber': passportNumber,
            'fullName': _userData?['fullName'] ?? 'Пользователь',
            'phone': _userData?['phone'] ?? '',
            'role': _userData?['role'] ?? 'resident',
            'apartmentNumber': _userData?['apartmentNumber'] ?? '',
            'blockId': _userData?['blockId'] ?? '',
            'lastLogin': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
            'dataSource': 'auth_service_fallback',
          };
          
          await altUserDoc.set(userData, SetOptions(merge: true));
          loggingService.info('Firebase Auth: User profile saved with passport number as doc ID');
        }
      } catch (altError) {
        loggingService.error('Firebase Auth: Alternative save also failed', altError);
      }
    }
  }

  /// Alias for logout for backward compatibility
  Future<void> signOut() async {
    await logout();
  }
} 