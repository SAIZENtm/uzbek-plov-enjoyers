import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:wifi_scan/wifi_scan.dart';
import '../models/smart_home_device_model.dart';
import 'auth_service.dart';
import 'logging_service_secure.dart';

/// Реальный сервис для подключения к физическим IoT устройствам
/// Использует Firebase Realtime Database для связи с Arduino ESP8266
class IoTDeviceService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final AuthService _authService;
  final LoggingService _loggingService;
  
  // Контроллеры для стримов устройств
  final Map<String, StreamController<SmartHomeDevice>> _deviceControllers = {};
  final Map<String, DatabaseReference> _deviceRefs = {};
  
  IoTDeviceService({
    required AuthService authService,
    required LoggingService loggingService,
  }) : _authService = authService,
       _loggingService = loggingService;

  /// Инициализация соединения с Firebase Realtime Database
  Future<void> initialize() async {
    try {
      _loggingService.info('🔗 Initializing IoT Device Service...');
      
      // Настройка Firebase Realtime Database
      _database.setPersistenceEnabled(true);
      
      _loggingService.info('✅ IoT Device Service initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to initialize IoT Device Service', e, stackTrace);
    }
  }

  /// Поиск доступных IoT устройств в сети
  Future<List<IoTDeviceInfo>> scanForDevices() async {
    try {
      _loggingService.info('🔍 Scanning for IoT devices...');
      
      final devices = <IoTDeviceInfo>[];
      
      // Получение информации о текущей WiFi сети
      final networkInfo = NetworkInfo();
      final wifiName = await networkInfo.getWifiName();
      final wifiIP = await networkInfo.getWifiIP();
      
      _loggingService.info('📶 Current WiFi: $wifiName (IP: $wifiIP)');
      
      // Сканируем устройства в Firebase по пути /apartments/{blockId}/{apartmentNumber}/devices
      final apartment = _authService.verifiedApartment;
      if (apartment != null) {
        final devicesRef = _database.ref('apartments/${apartment.blockId}/${apartment.apartmentNumber}/devices');
        final snapshot = await devicesRef.get();
        
        if (snapshot.exists) {
          final devicesData = Map<String, dynamic>.from(snapshot.value as Map);
          
          for (final entry in devicesData.entries) {
            try {
              final deviceData = Map<String, dynamic>.from(entry.value as Map);
              final device = IoTDeviceInfo.fromMap(entry.key, deviceData);
              devices.add(device);
              _loggingService.info('🔌 Found device: ${device.name} (${device.type})');
            } catch (e) {
              _loggingService.warning('⚠️ Failed to parse device: ${entry.key}');
            }
          }
        }
      }
      
      _loggingService.info('✅ Found ${devices.length} IoT devices');
      return devices;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to scan for devices', e, stackTrace);
      return [];
    }
  }

  /// Подключение к физическому устройству
  Future<bool> connectToDevice(String deviceId) async {
    try {
      _loggingService.info('🔗 Connecting to device: $deviceId');
      
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        throw Exception('No verified apartment');
      }
      
      // Создаем путь к устройству в Firebase
      final devicePath = 'apartments/${apartment.blockId}/${apartment.apartmentNumber}/devices/$deviceId';
      final deviceRef = _database.ref(devicePath);
      
      // Проверяем существование устройства
      final snapshot = await deviceRef.get();
      if (!snapshot.exists) {
        throw Exception('Device not found: $deviceId');
      }
      
      // Сохраняем ссылку на устройство
      _deviceRefs[deviceId] = deviceRef;
      
      // Создаем стрим для получения изменений от устройства
      final controller = StreamController<SmartHomeDevice>.broadcast();
      _deviceControllers[deviceId] = controller;
      
      // Подписываемся на изменения устройства
      deviceRef.onValue.listen((event) {
        if (event.snapshot.exists) {
          try {
            final deviceData = Map<String, dynamic>.from(event.snapshot.value as Map);
            final device = SmartHomeDevice.fromJson({
              'id': deviceId,
              ...deviceData,
            });
            controller.add(device);
          } catch (e) {
            _loggingService.error('Failed to parse device update: $deviceId', e);
          }
        }
      });
      
      _loggingService.info('✅ Connected to device: $deviceId');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to connect to device: $deviceId', e, stackTrace);
      return false;
    }
  }

  /// Получение стрима изменений устройства
  Stream<SmartHomeDevice>? getDeviceStream(String deviceId) {
    return _deviceControllers[deviceId]?.stream;
  }

  /// Управление устройством - включение/выключение
  Future<bool> controlDevice(String deviceId, bool status) async {
    try {
      _loggingService.info('🎛️ Controlling device $deviceId: ${status ? 'ON' : 'OFF'}');
      
      final deviceRef = _deviceRefs[deviceId];
      if (deviceRef == null) {
        throw Exception('Device not connected: $deviceId');
      }
      
      // Отправляем команду на устройство через Firebase
      await deviceRef.update({
        'status': status ? 'on' : 'off',
        'lastCommand': DateTime.now().toIso8601String(),
        'commandedBy': _authService.userData?['fullName'] ?? 'User',
      });
      
      _loggingService.info('✅ Device command sent: $deviceId');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to control device: $deviceId', e, stackTrace);
      return false;
    }
  }

  /// Установка температуры для устройств с климат-контролем
  Future<bool> setTemperature(String deviceId, double temperature) async {
    try {
      _loggingService.info('🌡️ Setting temperature for $deviceId: $temperature°C');
      
      final deviceRef = _deviceRefs[deviceId];
      if (deviceRef == null) {
        throw Exception('Device not connected: $deviceId');
      }
      
      await deviceRef.update({
        'temperature': temperature,
        'lastCommand': DateTime.now().toIso8601String(),
        'commandedBy': _authService.userData?['fullName'] ?? 'User',
      });
      
      _loggingService.info('✅ Temperature set: $deviceId');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to set temperature: $deviceId', e, stackTrace);
      return false;
    }
  }

  /// Добавление нового физического устройства
  Future<bool> addPhysicalDevice(IoTDeviceInfo deviceInfo) async {
    try {
      _loggingService.info('➕ Adding physical device: ${deviceInfo.name}');
      
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        throw Exception('No verified apartment');
      }
      
      final devicePath = 'apartments/${apartment.blockId}/${apartment.apartmentNumber}/devices/${deviceInfo.id}';
      final deviceRef = _database.ref(devicePath);
      
      await deviceRef.set({
        'name': deviceInfo.name,
        'type': deviceInfo.type.id,
        'status': 'off',
        'ipAddress': deviceInfo.ipAddress,
        'macAddress': deviceInfo.macAddress,
        'firmwareVersion': deviceInfo.firmwareVersion,
        'isOnline': true,
        'addedAt': DateTime.now().toIso8601String(),
        'addedBy': _authService.userData?['fullName'] ?? 'User',
      });
      
      _loggingService.info('✅ Physical device added: ${deviceInfo.name}');
      return true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to add physical device', e, stackTrace);
      return false;
    }
  }

  /// Сканирование WiFi сетей для настройки устройств
  Future<List<WiFiAccessPoint>> scanWiFiNetworks() async {
    try {
      _loggingService.info('📶 Scanning WiFi networks...');
      
      // Проверяем права доступа
      final can = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (can != CanStartScan.yes) {
        throw Exception('Cannot scan WiFi: $can');
      }
      
      // Запускаем сканирование
      final result = await WiFiScan.instance.startScan();
      if (!result) {
        throw Exception('Failed to start WiFi scan');
      }
      
      // Получаем результаты
      final networks = await WiFiScan.instance.getScannedResults();
      
      _loggingService.info('✅ Found ${networks.length} WiFi networks');
      return networks;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to scan WiFi networks', e, stackTrace);
      return [];
    }
  }

  /// Проверка статуса соединения с устройством
  Future<bool> pingDevice(String deviceId) async {
    try {
      final deviceRef = _deviceRefs[deviceId];
      if (deviceRef == null) return false;
      
      // Отправляем ping команду
      await deviceRef.child('ping').set({
        'timestamp': DateTime.now().toIso8601String(),
        'from': 'mobile_app',
      });
      
      // Ждем ответа в течение 5 секунд
      final completer = Completer<bool>();
      Timer(const Duration(seconds: 5), () {
        if (!completer.isCompleted) completer.complete(false);
      });
      
      deviceRef.child('pong').onValue.take(1).listen((event) {
        if (!completer.isCompleted) completer.complete(true);
      });
      
      return await completer.future;
    } catch (e) {
      return false;
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _loggingService.info('🧹 Disposing IoT Device Service...');
    
    for (final controller in _deviceControllers.values) {
      controller.close();
    }
    _deviceControllers.clear();
    _deviceRefs.clear();
  }
}

/// Информация о физическом IoT устройстве
class IoTDeviceInfo {
  final String id;
  final String name;
  final SmartDeviceType type;
  final String ipAddress;
  final String macAddress;
  final String firmwareVersion;
  final bool isOnline;
  final Map<String, dynamic>? capabilities;

  IoTDeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.ipAddress,
    required this.macAddress,
    required this.firmwareVersion,
    required this.isOnline,
    this.capabilities,
  });

  factory IoTDeviceInfo.fromMap(String id, Map<String, dynamic> data) {
    return IoTDeviceInfo(
      id: id,
      name: data['name'] ?? 'Unknown Device',
      type: SmartDeviceType.values.firstWhere(
        (t) => t.id == data['type'],
        orElse: () => SmartDeviceType.light,
      ),
      ipAddress: data['ipAddress'] ?? '',
      macAddress: data['macAddress'] ?? '',
      firmwareVersion: data['firmwareVersion'] ?? '1.0.0',
      isOnline: data['isOnline'] ?? false,
      capabilities: data['capabilities'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.id,
      'ipAddress': ipAddress,
      'macAddress': macAddress,
      'firmwareVersion': firmwareVersion,
      'isOnline': isOnline,
      if (capabilities != null) 'capabilities': capabilities,
    };
  }
} 