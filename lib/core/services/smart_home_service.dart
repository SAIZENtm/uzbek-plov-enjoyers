import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/smart_home_device_model.dart';
import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'iot_device_service.dart';
import 'tuya_cloud_service_secure.dart';
import 'package:firebase_database/firebase_database.dart';

class SmartHomeService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final LoggingService _loggingService;
  final IoTDeviceService _iotDeviceService;
  final TuyaCloudService _tuyaCloudService;

  // Приоритет интеграций: Tuya > IoT (Arduino)
  IoTIntegrationType _activeIntegration = IoTIntegrationType.auto;

  SmartHomeService({
    FirebaseFirestore? firestore,
    required AuthService authService,
    required LoggingService loggingService,
    required IoTDeviceService iotDeviceService,
    required TuyaCloudService tuyaCloudService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authService = authService,
       _loggingService = loggingService,
       _iotDeviceService = iotDeviceService,
       _tuyaCloudService = tuyaCloudService;

  /// Инициализация сервиса умного дома
  Future<void> initialize() async {
    try {
      _loggingService.info('🏠 Initializing Smart Home Service...');
      
      // Инициализируем IoT сервисы для подключения к реальным устройствам
      await Future.wait([
        _tuyaCloudService.initialize(),
        _iotDeviceService.initialize(),
      ]);
      
      // Определяем активную интеграцию
      _activeIntegration = await _detectActiveIntegration();
      
      _loggingService.info('✅ Smart Home Service initialized with ${_activeIntegration.name} integration');
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to initialize Smart Home Service', e, stackTrace);
    }
  }

  /// Определение активной интеграции на основе доступных устройств
  Future<IoTIntegrationType> _detectActiveIntegration() async {
    try {
      // Проверяем Tuya Cloud
      final tuyaDevices = await _tuyaCloudService.fetchUserDevices();
      if (tuyaDevices.isNotEmpty) {
        _loggingService.info('🔌 Found ${tuyaDevices.length} Tuya devices - using Tuya integration');
        return IoTIntegrationType.tuya;
      }
      
      // Проверяем Arduino IoT устройства
      final iotDevices = await _iotDeviceService.scanForDevices();
      if (iotDevices.isNotEmpty) {
        _loggingService.info('⚡ Found ${iotDevices.length} IoT devices - using Arduino integration');
        return IoTIntegrationType.arduino;
      }
      
      // Если ничего не найдено, используем демо режим
      _loggingService.warning('⚠️ No real devices found - using demo mode');
      return IoTIntegrationType.demo;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to detect integration type', e, stackTrace);
      return IoTIntegrationType.demo;
    }
  }

  /// Стрим конфигурации умного дома для текущего пользователя
  Stream<SmartHomeConfiguration> getSmartHomeConfigurationStream() {
    final apartment = _authService.verifiedApartment;
    if (apartment == null) {
      _loggingService.warning('No verified apartment for smart home');
      return Stream.value(SmartHomeConfiguration.empty);
    }

    final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
    _loggingService.info('Setting up smart home stream for: $docPath');

    return _firestore
        .doc(docPath)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            _loggingService.info('Apartment document does not exist');
            return SmartHomeConfiguration.empty;
          }

          final data = snapshot.data();
          if (data == null || !data.containsKey('smartHome')) {
            _loggingService.info('No smartHome data found');
            return SmartHomeConfiguration.empty;
          }

          try {
            final smartHomeData = data['smartHome'] as Map<String, dynamic>;
            return SmartHomeConfiguration.fromJson(smartHomeData);
          } catch (e, stackTrace) {
            _loggingService.error('Failed to parse smart home configuration', e, stackTrace);
            return SmartHomeConfiguration.empty;
          }
        })
        .handleError((error) {
          _loggingService.error('Smart home stream error', error);
          return SmartHomeConfiguration.empty;
        });
  }

  /// Получение текущей конфигурации умного дома
  Future<SmartHomeConfiguration> getSmartHomeConfiguration() async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.warning('No verified apartment for smart home');
        return SmartHomeConfiguration.empty;
      }

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final snapshot = await _firestore.doc(docPath).get();

      if (!snapshot.exists) {
        _loggingService.info('Apartment document does not exist, scanning for real devices');
        await _scanAndInitializeRealDevices();
        return SmartHomeConfiguration.empty;
      }

      final data = snapshot.data();
      if (data == null || !data.containsKey('smartHome')) {
        _loggingService.info('No smartHome data found, scanning for real devices');
        await _scanAndInitializeRealDevices();
        return SmartHomeConfiguration.empty;
      }

      final smartHomeData = data['smartHome'] as Map<String, dynamic>;
      return SmartHomeConfiguration.fromJson(smartHomeData);
    } catch (e, stackTrace) {
      _loggingService.error('Failed to get smart home configuration', e, stackTrace);
      return SmartHomeConfiguration.empty;
    }
  }

  /// Сканирование и инициализация реальных IoT устройств из всех интеграций
  Future<void> _scanAndInitializeRealDevices() async {
    try {
      _loggingService.info('🔍 Scanning for real IoT devices from all integrations...');
      
      final apartment = _authService.verifiedApartment;
      if (apartment == null) return;

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final devices = <SmartHomeDevice>[];
      String deviceSource = 'demo_mode';
      
      // Сканируем устройства в зависимости от активной интеграции
      switch (_activeIntegration) {
        case IoTIntegrationType.tuya:
          final tuyaDevices = await _tuyaCloudService.fetchUserDevices();
          devices.addAll(_tuyaCloudService.convertToSmartHomeDevices(tuyaDevices));
          deviceSource = 'tuya_cloud';
          _loggingService.info('📱 Loaded ${devices.length} devices from Tuya Cloud');
          break;
          
        case IoTIntegrationType.arduino:
          final iotDevices = await _iotDeviceService.scanForDevices();
          for (final iotDevice in iotDevices) {
            final device = SmartHomeDevice(
              id: iotDevice.id,
              name: iotDevice.name,
              type: iotDevice.type,
              status: iotDevice.isOnline,
              updatedBy: 'Arduino Scanner',
              lastUpdated: DateTime.now(),
            );
            devices.add(device);
            await _iotDeviceService.connectToDevice(iotDevice.id);
          }
          deviceSource = 'arduino_iot';
          _loggingService.info('⚡ Loaded ${devices.length} devices from Arduino IoT');
          break;
          
        case IoTIntegrationType.demo:
        case IoTIntegrationType.auto:
          await _createDemoSetup();
          return;
      }

      if (devices.isEmpty) {
        _loggingService.warning('⚠️ No real devices found. Creating demo setup.');
        await _createDemoSetup();
        return;
      }

      final initialConfig = SmartHomeConfiguration(
        devices: devices,
        lastSyncTime: DateTime.now(),
        isEnabled: true,
      );

      // Создаем документ квартиры с реальными устройствами
      await _firestore.doc(docPath).set({
        'name': apartment.fullName,
        'phone': apartment.phone,
        'smartHome': initialConfig.toJson(),
        'lastActivity': DateTime.now().toIso8601String(),
        'deviceSource': deviceSource,
        'integrationStatus': _activeIntegration.name,
      }, SetOptions(merge: true));

      _loggingService.info('✅ Initialized ${devices.length} real devices from ${_activeIntegration.name}');
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to scan real devices, falling back to demo', e, stackTrace);
      await _createDemoSetup();
    }
  }

  /// Создание демо настройки для тестирования
  Future<void> _createDemoSetup() async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) return;

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      
      // Создаем демо-устройства (только если нет реальных)
      final demoDevices = [
        SmartHomeDevice(
          id: 'demo_light1',
          name: 'Люстра в зале (ДЕМО)',
          type: SmartDeviceType.light,
          status: false,
          updatedBy: 'Demo System',
          lastUpdated: DateTime.now(),
        ),
        SmartHomeDevice(
          id: 'demo_ac1',
          name: 'Кондиционер (ДЕМО)',
          type: SmartDeviceType.ac,
          status: false,
          temperature: 23.0,
          updatedBy: 'Demo System',
          lastUpdated: DateTime.now(),
        ),
      ];

      final initialConfig = SmartHomeConfiguration(
        devices: demoDevices,
        lastSyncTime: DateTime.now(),
        isEnabled: true,
      );

      await _firestore.doc(docPath).set({
        'name': apartment.fullName,
        'phone': apartment.phone,
        'smartHome': initialConfig.toJson(),
        'lastActivity': DateTime.now().toIso8601String(),
        'deviceSource': 'demo_mode', // Помечаем что это демо режим
      }, SetOptions(merge: true));

      _loggingService.warning('⚠️ Created DEMO smart home setup');
    } catch (e, stackTrace) {
      _loggingService.error('Failed to create demo setup', e, stackTrace);
    }
  }

  /// Обновление статуса устройства (для реальных IoT устройств)
  Future<bool> updateDeviceStatus(String deviceId, bool status) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.error('No verified apartment for device update');
        return false;
      }

      // Отправляем команду через соответствующую интеграцию
      bool remoteSuccess = true;
      if (!deviceId.startsWith('demo_')) {
        switch (_activeIntegration) {
          case IoTIntegrationType.tuya:
            remoteSuccess = await _tuyaCloudService.controlDevice(deviceId, 'switch_1', status);
            break;
          case IoTIntegrationType.arduino:
            remoteSuccess = await _iotDeviceService.controlDevice(deviceId, status);
            break;
          default:
            // Для демо режима не отправляем реальные команды
            break;
        }
        
        if (!remoteSuccess) {
          _loggingService.warning('Failed to control real device, updating Firestore only');
        }
      }

      // Обновляем состояние в Firestore
      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final currentConfig = await getSmartHomeConfiguration();
      final device = currentConfig.getDevice(deviceId);
      
      if (device == null) {
        _loggingService.error('Device not found: $deviceId');
        return false;
      }

      final updatedDevice = device.copyWith(
        status: status,
        updatedBy: _authService.userData?['fullName'] ?? 'User',
        lastUpdated: DateTime.now(),
      );

      final updatedConfig = currentConfig.updateDevice(updatedDevice).copyWith(
        lastSyncTime: DateTime.now(),
      );

      await _firestore.doc(docPath).set({
        'smartHome': updatedConfig.toJson(),
      }, SetOptions(merge: true));

      _loggingService.info('Device $deviceId status updated to $status');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('Failed to update device status', e, stackTrace);
      return false;
    }
  }

  /// Обновление температуры устройства (для реальных IoT устройств)
  Future<bool> updateDeviceTemperature(String deviceId, double temperature) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.error('No verified apartment for temperature update');
        return false;
      }

      // Отправляем команду установки температуры через соответствующую интеграцию
      bool remoteSuccess = true;
      if (!deviceId.startsWith('demo_')) {
        switch (_activeIntegration) {
          case IoTIntegrationType.tuya:
            remoteSuccess = await _tuyaCloudService.controlDevice(deviceId, 'temp_set', temperature);
            break;
          case IoTIntegrationType.arduino:
            remoteSuccess = await _iotDeviceService.setTemperature(deviceId, temperature);
            break;
          default:
            // Для демо режима не отправляем реальные команды
            break;
        }
        
        if (!remoteSuccess) {
          _loggingService.warning('Failed to set temperature on real device');
        }
      }

      // Обновляем в Firestore
      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final currentConfig = await getSmartHomeConfiguration();
      final device = currentConfig.getDevice(deviceId);
      
      if (device == null || !device.hasTemperatureControl) {
        _loggingService.error('Device not found or does not support temperature: $deviceId');
        return false;
      }

      final updatedDevice = device.copyWith(
        temperature: temperature,
        updatedBy: _authService.userData?['fullName'] ?? 'User',
        lastUpdated: DateTime.now(),
      );

      final updatedConfig = currentConfig.updateDevice(updatedDevice).copyWith(
        lastSyncTime: DateTime.now(),
      );

      await _firestore.doc(docPath).set({
        'smartHome': updatedConfig.toJson(),
      }, SetOptions(merge: true));

      _loggingService.info('Device $deviceId temperature updated to $temperature');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('Failed to update device temperature', e, stackTrace);
      return false;
    }
  }

  /// Добавление нового устройства (с поддержкой реальных IoT устройств)
  Future<bool> addDevice(SmartHomeDevice device) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.error('No verified apartment for adding device');
        return false;
      }

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final currentConfig = await getSmartHomeConfiguration();
      
      // Проверяем, что устройство с таким ID не существует
      if (currentConfig.getDevice(device.id) != null) {
        _loggingService.error('Device with ID ${device.id} already exists');
        return false;
      }

      final deviceWithMetadata = device.copyWith(
        updatedBy: _authService.userData?['fullName'] ?? 'User',
        lastUpdated: DateTime.now(),
      );

      final updatedConfig = currentConfig.addDevice(deviceWithMetadata).copyWith(
        lastSyncTime: DateTime.now(),
      );

      await _firestore.doc(docPath).set({
        'smartHome': updatedConfig.toJson(),
      }, SetOptions(merge: true));

      // Если это не демо устройство, подключаемся к реальному IoT
      if (!device.id.startsWith('demo_')) {
        await _iotDeviceService.connectToDevice(device.id);
      }

      _loggingService.info('Device ${device.id} added successfully');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('Failed to add device', e, stackTrace);
      return false;
    }
  }

  /// Удаление устройства
  Future<bool> removeDevice(String deviceId) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.error('No verified apartment for removing device');
        return false;
      }

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final currentConfig = await getSmartHomeConfiguration();
      
      if (currentConfig.getDevice(deviceId) == null) {
        _loggingService.error('Device not found: $deviceId');
        return false;
      }

      final updatedConfig = currentConfig.removeDevice(deviceId).copyWith(
        lastSyncTime: DateTime.now(),
      );

      await _firestore.doc(docPath).set({
        'smartHome': updatedConfig.toJson(),
      }, SetOptions(merge: true));

      _loggingService.info('Device $deviceId removed successfully');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('Failed to remove device', e, stackTrace);
      return false;
    }
  }

  /// Переименование устройства
  Future<bool> updateDeviceName(String deviceId, String newName) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        _loggingService.error('No verified apartment for renaming device');
        return false;
      }

      final docPath = 'users/${apartment.blockId}/apartments/${apartment.apartmentNumber}';
      final currentConfig = await getSmartHomeConfiguration();
      final device = currentConfig.getDevice(deviceId);
      
      if (device == null) {
        _loggingService.error('Device not found: $deviceId');
        return false;
      }

      final updatedDevice = device.copyWith(
        name: newName,
        updatedBy: _authService.userData?['fullName'] ?? 'User',
        lastUpdated: DateTime.now(),
      );

      final updatedConfig = currentConfig.updateDevice(updatedDevice).copyWith(
        lastSyncTime: DateTime.now(),
      );

      await _firestore.doc(docPath).set({
        'smartHome': updatedConfig.toJson(),
      }, SetOptions(merge: true));

      _loggingService.info('Device $deviceId renamed to $newName');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('Failed to rename device', e, stackTrace);
      return false;
    }
  }

  /// Сканирование доступных IoT устройств в сети
  Future<List<IoTDeviceInfo>> scanForIoTDevices() async {
    return await _iotDeviceService.scanForDevices();
  }

  /// Проверка соединения с устройством
  Future<bool> pingDevice(String deviceId) async {
    if (deviceId.startsWith('demo_')) {
      // Для демо устройств всегда возвращаем true
      return true;
    }
    return await _iotDeviceService.pingDevice(deviceId);
  }

  /// Получение стрима изменений от реального IoT устройства  
  Stream<SmartHomeDevice>? getRealDeviceStream(String deviceId) {
    if (deviceId.startsWith('demo_')) return null;
    return _iotDeviceService.getDeviceStream(deviceId);
  }

  /// Создание нового устройства с уникальным ID
  SmartHomeDevice createNewDevice({
    required String name,
    required SmartDeviceType type,
    bool status = false,
    double? temperature,
  }) {
    final deviceId = '${type.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    return SmartHomeDevice(
      id: deviceId,
      name: name,
      type: type,
      status: status,
      temperature: temperature,
      updatedBy: _authService.userData?['fullName'] ?? 'User',
      lastUpdated: DateTime.now(),
    );
  }

  /// Регистрация реального IoT устройства в системе
  Future<bool> registerIoTDevice(IoTDeviceInfo deviceInfo) async {
    try {
      _loggingService.info('🔗 Registering IoT device: ${deviceInfo.name}');
      
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        throw Exception('No verified apartment');
      }

      // Определяем тип устройства на основе capabilities
      SmartDeviceType deviceType = SmartDeviceType.light; // По умолчанию
      
      if (deviceInfo.type == SmartDeviceType.ac) {
        deviceType = SmartDeviceType.ac;
      } else if (deviceInfo.type.id == 'multi_sensor') {
        deviceType = SmartDeviceType.light; // Мульти-сенсор с освещением
      }

      // Создаем устройство для системы умного дома
      final smartDevice = SmartHomeDevice(
        id: deviceInfo.id,
        name: deviceInfo.name,
        type: deviceType,
        status: false, // Начальное состояние
        temperature: deviceType == SmartDeviceType.ac ? 23.0 : null,
        updatedBy: _authService.userData?['fullName'] ?? 'System',
        lastUpdated: DateTime.now(),
        additionalData: {
          'isReal': true, // Отмечаем как реальное устройство
          'ipAddress': deviceInfo.ipAddress,
          'macAddress': deviceInfo.macAddress,
          'firmwareVersion': deviceInfo.firmwareVersion,
        },
      );

      // Добавляем в конфигурацию умного дома
      final success = await addDevice(smartDevice);
      
      if (success) {
        // Регистрируем устройство в Firebase для связи с Arduino
        await _registerDeviceInFirebase(deviceInfo);
        
        _loggingService.info('✅ IoT device registered successfully');
        return true;
      }
      
      return false;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to register IoT device', e, stackTrace);
      return false;
    }
  }

  /// Регистрация устройства в Firebase для связи с Arduino
  Future<void> _registerDeviceInFirebase(IoTDeviceInfo deviceInfo) async {
    try {
      final apartment = _authService.verifiedApartment;
      if (apartment == null) return;

      // Путь для регистрации устройства
      final registrationPath = 'device_registrations/${deviceInfo.id}';
      
      // Данные для регистрации
      final registrationData = {
        'deviceId': deviceInfo.id,
        'name': deviceInfo.name,
        'type': deviceInfo.type.id,
        'blockId': apartment.blockId,
        'apartmentNumber': apartment.apartmentNumber,
        'userId': _authService.userData?['uid'] ?? '',
        'userEmail': _authService.userData?['email'] ?? '',
        'registeredAt': DateTime.now().toIso8601String(),
        'status': 'registered',
        'ipAddress': deviceInfo.ipAddress,
        'macAddress': deviceInfo.macAddress,
      };

      // Сохраняем в Firebase Realtime Database
      await FirebaseDatabase.instance
          .ref(registrationPath)
          .set(registrationData);

      _loggingService.info('📝 Device registration saved to Firebase');
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to save device registration', e, stackTrace);
    }
  }

  /// Проверка доступности умного дома для текущего пользователя
  bool get isSmartHomeAvailable {
    return _authService.verifiedApartment != null;
  }

  /// Получение статистики устройств
  Future<Map<String, dynamic>> getDeviceStatistics() async {
    try {
      final config = await getSmartHomeConfiguration();
      
      final totalDevices = config.devices.length;
      final activeDevices = config.activeDevicesCount;
      final devicesByType = config.devicesByType;
      
      // Подсчитаем реальные vs демо устройства
      int realDevices = 0;
      int demoDevices = 0;
      for (final device in config.devices) {
        if (device.id.startsWith('demo_')) {
          demoDevices++;
        } else {
          realDevices++;
        }
      }
      
      return {
        'totalDevices': totalDevices,
        'activeDevices': activeDevices,
        'offlineDevices': totalDevices - activeDevices,
        'realDevices': realDevices,
        'demoDevices': demoDevices,
        'devicesByType': devicesByType.map(
          (type, devices) => MapEntry(type.displayName, devices.length),
        ),
        'lastUpdate': config.lastSyncTime?.toIso8601String(),
      };
    } catch (e, stackTrace) {
      _loggingService.error('Failed to get device statistics', e, stackTrace);
      return {
        'totalDevices': 0,
        'activeDevices': 0,
        'offlineDevices': 0,
        'realDevices': 0,
        'demoDevices': 0,
        'devicesByType': <String, int>{},
      };
    }
  }

  /// Переключение активной интеграции
  Future<bool> switchIntegration(IoTIntegrationType newIntegration) async {
    try {
      _loggingService.info('🔄 Switching to ${newIntegration.name} integration...');
      
      _activeIntegration = newIntegration;
      
      // Перезагружаем устройства с новой интеграции
      await _scanAndInitializeRealDevices();
      
      _loggingService.info('✅ Successfully switched to ${newIntegration.name}');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to switch integration', e, stackTrace);
      return false;
    }
  }

  /// Получение информации об активной интеграции
  Map<String, dynamic> getIntegrationStatus() {
    return {
      'activeIntegration': _activeIntegration.name,
      'availableIntegrations': IoTIntegrationType.values.map((e) => e.name).toList(),
      'tuyaConfigured': _tuyaCloudService.isConfigured,
    };
  }

  /// Настройка Tuya Cloud интеграции
  Future<bool> setupTuyaIntegration(String clientId, String clientSecret) async {
    // В реальном приложении здесь должна быть настройка OAuth
    _loggingService.info('⚙️ Tuya integration setup - use Tuya IoT Platform');
    return false; // Требует ручной настройки в Tuya Developer Console
  }

  /// Настройка Home Assistant интеграции
  Future<bool> setupHomeAssistantIntegration(String baseUrl, String accessToken) async {
    // This method is no longer used as HomeAssistantService is removed.
    // Keeping it for now, but it will always return false.
    _loggingService.warning('setupHomeAssistantIntegration is deprecated as HomeAssistantService is removed.');
    return false;
  }

  /// Активация сценария (поддерживается Tuya и Home Assistant)
  Future<bool> activateScene(String sceneId) async {
    try {
      switch (_activeIntegration) {
        case IoTIntegrationType.tuya:
          return await _tuyaCloudService.executeScene(sceneId);
        case IoTIntegrationType.arduino:
          // Scenes are not directly supported by Arduino IoT devices in this service.
          // This method will always return false for Arduino.
          _loggingService.warning('Scenes not supported for ${_activeIntegration.name}');
          return false;
        default:
          _loggingService.warning('Scenes not supported for ${_activeIntegration.name}');
          return false;
      }
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to activate scene', e, stackTrace);
      return false;
    }
  }

  /// Получение доступных сценариев
  Future<List<Map<String, dynamic>>> getAvailableScenes() async {
    try {
      switch (_activeIntegration) {
        case IoTIntegrationType.tuya:
          final scenes = await _tuyaCloudService.fetchUserScenes();
          return scenes.map((s) => {
            'id': s.id,
            'name': s.name,
            'icon': s.icon,
            'enabled': s.enabled,
            'source': 'tuya',
          }).toList();
          
        case IoTIntegrationType.arduino:
          // Scenes are not directly supported by Arduino IoT devices in this service.
          return [];
          
        default:
          return [];
      }
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to get scenes', e, stackTrace);
      return [];
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _iotDeviceService.dispose();
    _tuyaCloudService.dispose();
  }
}

/// Типы IoT интеграций поддерживаемые Newport Smart Home
enum IoTIntegrationType {
  auto('Автоматическое определение'),
  tuya('Tuya Cloud API'),
  arduino('Arduino IoT'),
  demo('Демо режим');

  const IoTIntegrationType(this.displayName);
  
  final String displayName;
} 