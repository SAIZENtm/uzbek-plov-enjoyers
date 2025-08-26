import 'dart:async';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/smart_home_device_model.dart';
import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'fcm_service.dart';

/// Безопасный сервис для работы с Tuya Cloud через серверный прокси
/// Не содержит никаких секретов или прямых вызовов к Tuya API
class TuyaCloudService {
  final AuthService authService;
  final LoggingService loggingService;
  final FCMService? fcmService;
  
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  // Кэш устройств
  List<SmartHomeDevice> _cachedDevices = [];
  // DateTime? _lastDeviceSync; // Не используется пока
  Timer? _deviceSyncTimer;
  
  // Состояние сервиса
  bool _isInitialized = false;
  StreamController<List<SmartHomeDevice>>? _devicesStreamController;
  
  TuyaCloudService({
    required this.authService,
    required this.loggingService,
    this.fcmService,
  });
  
  /// Проверка инициализации
  bool get isConfigured => _isInitialized;
  
  /// Поток устройств
  Stream<List<SmartHomeDevice>> get devicesStream {
    _devicesStreamController ??= StreamController<List<SmartHomeDevice>>.broadcast();
    return _devicesStreamController!.stream;
  }
  
  /// Инициализация сервиса
  Future<void> initialize() async {
    try {
      loggingService.info('🏠 Initializing secure Tuya Cloud Service...');
      
      // Проверяем аутентификацию
      if (!authService.isAuthenticated || authService.verifiedApartment == null) {
        loggingService.warning('❌ User not authenticated or no apartment selected');
        return;
      }
      
      // Загружаем кэшированные устройства
      await _loadCachedDevices();
      
      // Запускаем синхронизацию
      await syncDevices();
      
      // Запускаем периодическую синхронизацию
      _startDeviceSyncTimer();
      
      _isInitialized = true;
      loggingService.info('✅ Tuya Cloud Service initialized successfully');
    } catch (e) {
      loggingService.error('❌ Failed to initialize Tuya Cloud Service', e);
      _isInitialized = false;
    }
  }
  
  /// Получение списка устройств умного дома
  Future<List<SmartHomeDevice>> fetchUserDevices() async {
    try {
      loggingService.info('📱 Fetching smart home devices...');
      
      final apartment = authService.verifiedApartment;
      if (apartment == null) {
        throw Exception('No apartment selected');
      }
      
      // Вызываем защищенную Cloud Function
      final callable = _functions.httpsCallable('getSmartHomeDevices');
      final result = await callable.call({
        'apartmentId': apartment.id,
      });
      
      if (result.data['success'] == true) {
        final List<dynamic> devicesData = result.data['devices'] ?? [];
        
        // Преобразуем в модели
        final devices = devicesData
            .map((data) => _parseDeviceFromServer(data))
            .where((device) => device != null)
            .cast<SmartHomeDevice>()
            .toList();
        
        loggingService.info('✅ Fetched ${devices.length} devices');
        
        // Обновляем кэш
        _cachedDevices = devices;
        // last sync time can be stored in preferences if needed
        await _saveCachedDevices();
        
        // Уведомляем слушателей
        _devicesStreamController?.add(devices);
        
        return devices;
      } else {
        throw Exception('Failed to fetch devices');
      }
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      return _cachedDevices; // Возвращаем кэш при ошибке
    } catch (e) {
      loggingService.error('❌ Error fetching devices', e);
      return _cachedDevices;
    }
  }

  /// Совместимость с прежним API: конвертация устройств в SmartHomeDevice
  /// Принимает список динамических объектов (Map/SmartHomeDevice) и возвращает SmartHomeDevice
  List<SmartHomeDevice> convertToSmartHomeDevices(List<dynamic> devicesData) {
    final result = <SmartHomeDevice>[];
    for (final item in devicesData) {
      if (item is SmartHomeDevice) {
        result.add(item);
      } else if (item is Map<String, dynamic>) {
        final parsed = _parseDeviceFromServer(item);
        if (parsed != null) result.add(parsed);
      }
    }
    return result;
  }
  
  /// Управление устройством
  Future<bool> controlDevice(String deviceId, String command, dynamic value) async {
    try {
      loggingService.info('🎛️ Controlling device $deviceId: $command = $value');
      
      final apartment = authService.verifiedApartment;
      if (apartment == null) {
        throw Exception('No apartment selected');
      }
      
      // Вызываем защищенную Cloud Function
      final callable = _functions.httpsCallable('controlSmartHomeDevice');
      final result = await callable.call({
        'apartmentId': apartment.id,
        'deviceId': deviceId,
        'command': command,
        'value': value,
      });
      
      if (result.data['success'] == true) {
        loggingService.info('✅ Device control successful');
        
        // Обновляем локальное состояние устройства
        _updateLocalDeviceState(deviceId, command, value);
        
        // Запускаем синхронизацию через небольшую задержку
        Timer(const Duration(seconds: 2), () => syncDevices());
        
        return true;
      } else {
        throw Exception('Control command failed');
      }
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      return false;
    } catch (e) {
      loggingService.error('❌ Error controlling device', e);
      return false;
    }
  }
  
  /// Получение статуса устройства
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    try {
      final apartment = authService.verifiedApartment;
      if (apartment == null) return null;
      
      final callable = _functions.httpsCallable('getDeviceStatus');
      final result = await callable.call({
        'apartmentId': apartment.id,
        'deviceId': deviceId,
      });
      
      if (result.data['success'] == true) {
        return result.data['status'] as Map<String, dynamic>;
      }
      
      return null;
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      return null;
    } catch (e) {
      loggingService.error('Error getting device status', e);
      return null;
    }
  }

  /// Получение доступных сцен (через Cloud Function)
  Future<List<TuyaScene>> fetchUserScenes() async {
    try {
      final apartment = authService.verifiedApartment;
      if (apartment == null) return [];
      final callable = _functions.httpsCallable('getSmartHomeScenes');
      final result = await callable.call({'apartmentId': apartment.id});
      final List<dynamic> scenes = result.data['scenes'] ?? [];
      return scenes
          .map((s) => TuyaScene.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      return [];
    } catch (e) {
      loggingService.error('Error fetching scenes', e);
      return [];
    }
  }

  /// Выполнение сцены (через Cloud Function)
  Future<bool> executeScene(String sceneId) async {
    try {
      final apartment = authService.verifiedApartment;
      if (apartment == null) return false;
      final callable = _functions.httpsCallable('executeSmartHomeScene');
      final result = await callable.call({'apartmentId': apartment.id, 'sceneId': sceneId});
      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      return false;
    } catch (e) {
      loggingService.error('Error executing scene', e);
      return false;
    }
  }
  
  /// Синхронизация устройств
  Future<void> syncDevices() async {
    try {
      await fetchUserDevices();
    } catch (e) {
      loggingService.error('Error syncing devices', e);
    }
  }
  
  /// Включение/выключение устройства
  Future<bool> toggleDevice(String deviceId, bool turnOn) async {
    // Определяем команду в зависимости от типа устройства
    final device = _cachedDevices.firstWhere(
      (d) => d.id == deviceId,
      orElse: () => throw Exception('Device not found'),
    );
    
    String command;
    switch (device.type) {
      case SmartDeviceType.light:
        command = 'switch_led';
        break;
      case SmartDeviceType.ac:
      case SmartDeviceType.heater:
        command = 'switch';
        break;
      case SmartDeviceType.door:
        command = 'lock';
        break;
      default:
        command = 'switch_1';
    }
    
    return controlDevice(deviceId, command, turnOn);
  }
  
  /// Установка температуры
  Future<bool> setTemperature(String deviceId, double temperature) async {
    return controlDevice(deviceId, 'temp_set', temperature.round());
  }
  
  /// Установка яркости света
  Future<bool> setBrightness(String deviceId, int brightness) async {
    // Tuya использует диапазон 10-1000 для яркости
    final tuyaBrightness = (brightness * 10).clamp(10, 1000);
    return controlDevice(deviceId, 'bright_value_v2', tuyaBrightness);
  }
  
  /// Парсинг устройства из ответа сервера
  SmartHomeDevice? _parseDeviceFromServer(Map<String, dynamic> data) {
    try {
      final String id = data['id'];
      final String name = data['name'] ?? 'Устройство';
      final String category = data['category'] ?? 'unknown';
      final bool online = data['online'] ?? false;
      final Map<String, dynamic> status = Map<String, dynamic>.from(data['status'] ?? {});
      
      // Определяем тип устройства
      final type = _categoryToDeviceType(category);
      
      // Определяем состояние устройства
      bool isOn = false;
      if (status.containsKey('switch_led')) {
        isOn = status['switch_led'] == true;
      } else if (status.containsKey('switch')) {
        isOn = status['switch'] == true;
      } else if (status.containsKey('switch_1')) {
        isOn = status['switch_1'] == true;
      }
      
      // Получаем температуру если есть
      double? temperature;
      if (status.containsKey('temp_current')) {
        temperature = (status['temp_current'] as num?)?.toDouble();
      } else if (status.containsKey('temp_set')) {
        temperature = (status['temp_set'] as num?)?.toDouble();
      }
      
      // Получаем яркость если есть
      int? brightness;
      if (status.containsKey('bright_value_v2')) {
        brightness = ((status['bright_value_v2'] as num?) ?? 0) ~/ 10;
      }
      
              return SmartHomeDevice(
          id: id,
          name: name,
          type: type,
          status: isOn,
          temperature: temperature,
          additionalData: {
            'online': online,
            'brightness': brightness,
            'icon': _getDeviceIcon(type),
            'rawData': data,
          },
        );
    } catch (e) {
      loggingService.error('Error parsing device: ${data['id']}', e);
      return null;
    }
  }
  
  /// Преобразование категории Tuya в тип устройства
  SmartDeviceType _categoryToDeviceType(String category) {
    switch (category.toLowerCase()) {
      case 'dj': // Light
      case 'light':
      case 'lamp':
        return SmartDeviceType.light;
      case 'kt': // Air conditioner
      case 'ac':
      case 'aircon':
        return SmartDeviceType.ac;
      case 'qn': // Heater
      case 'heater':
      case 'heating':
        return SmartDeviceType.heater;
      case 'ms': // Door sensor
      case 'door':
      case 'lock':
      case 'cl': // Curtain (используем door для штор)
        return SmartDeviceType.door;
      case 'camera':
      case 'security_camera':
      case 'sp': // Smart camera
        return SmartDeviceType.camera;
      default:
        return SmartDeviceType.light; // По умолчанию
    }
  }
  
  /// Получение иконки для типа устройства
  String _getDeviceIcon(SmartDeviceType type) {
    switch (type) {
      case SmartDeviceType.light:
        return '💡';
      case SmartDeviceType.ac:
        return '❄️';
      case SmartDeviceType.heater:
        return '🔥';
      case SmartDeviceType.door:
        return '🚪';
      case SmartDeviceType.camera:
        return '📷';
    }
  }

    /// Обновление локального состояния устройства
  void _updateLocalDeviceState(String deviceId, String command, dynamic value) {
    final deviceIndex = _cachedDevices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex == -1) return;
    
    final device = _cachedDevices[deviceIndex];
    SmartHomeDevice updatedDevice;
    
    switch (command) {
      case 'switch':
      case 'switch_led':
      case 'switch_1':
        updatedDevice = device.copyWith(status: value as bool);
        break;
      case 'temp_set':
        updatedDevice = device.copyWith(temperature: (value as num).toDouble());
        break;
      case 'bright_value_v2':
        final newAdditionalData = Map<String, dynamic>.from(device.additionalData ?? {});
        newAdditionalData['brightness'] = ((value as num) / 10).round();
        updatedDevice = device.copyWith(additionalData: newAdditionalData);
        break;
      default:
        return;
    }
    
    _cachedDevices[deviceIndex] = updatedDevice;
    _devicesStreamController?.add(_cachedDevices);
  }
  
  /// Обработка ошибок Cloud Functions
  void _handleFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        loggingService.error('Not authenticated for smart home access');
        break;
      case 'permission-denied':
        loggingService.error('No permission to access smart home');
        break;
      case 'invalid-argument':
        loggingService.error('Invalid request data: ${e.message}');
        break;
      default:
        loggingService.error('Smart home error: ${e.code} - ${e.message}');
    }
  }
  
  /// Загрузка кэшированных устройств
  Future<void> _loadCachedDevices() async {
    try {
      final cachedJson = await _secureStorage.read(key: 'smart_home_devices_cache');
      if (cachedJson != null) {
        final List<dynamic> devicesList = jsonDecode(cachedJson);
        _cachedDevices = devicesList
            .map((data) => SmartHomeDevice.fromJson(Map<String, dynamic>.from(data)))
            .toList();
        
        _devicesStreamController?.add(_cachedDevices);
        loggingService.info('Loaded ${_cachedDevices.length} cached devices');
      }
    } catch (e) {
      loggingService.error('Failed to load cached devices', e);
    }
  }
  
  /// Сохранение устройств в кэш
  Future<void> _saveCachedDevices() async {
    try {
      final devicesJson = _cachedDevices.map((d) => d.toJson()).toList();
      await _secureStorage.write(
        key: 'smart_home_devices_cache',
        value: jsonEncode(devicesJson),
      );
    } catch (e) {
      loggingService.error('Failed to save devices cache', e);
    }
  }
  
  /// Запуск таймера синхронизации устройств
  void _startDeviceSyncTimer() {
    _deviceSyncTimer?.cancel();
    _deviceSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isInitialized) {
        syncDevices();
      }
    });
  }
  
  /// Освобождение ресурсов
  void dispose() {
    _deviceSyncTimer?.cancel();
    _devicesStreamController?.close();
    _isInitialized = false;
  }
}

/// Модель сцены Tuya (минимально необходимая для UI)
class TuyaScene {
  final String id;
  final String name;
  final String icon;
  final bool enabled;

  TuyaScene({
    required this.id,
    required this.name,
    required this.icon,
    required this.enabled,
  });

  factory TuyaScene.fromJson(Map<String, dynamic> json) {
    return TuyaScene(
      id: json['scene_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Scene',
      icon: json['icon']?.toString() ?? '',
      enabled: (json['enabled'] as bool?) ?? true,
    );
  }
}
