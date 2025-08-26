import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smart_home_device_model.dart';
import 'auth_service.dart';
import 'logging_service.dart';

/// РЕАЛЬНАЯ интеграция с Tuya Cloud API для управления коммерческими умными устройствами
/// Поддерживает: лампы Xiaomi/Tuya, розетки, кондиционеры, шторы и т.д.
class TuyaCloudService {
  final LoggingService _loggingService;
  // ignore: unused_field
  final AuthService _authService; // Зарезервировано для будущих OAuth интеграций
  
  // Tuya Cloud API Configuration
  static const String _baseUrl = 'https://openapi.tuyacn.com';  // US: tuyaus.com, EU: tuyaeu.com, CN: tuyacn.com
  static const String _clientId = 'YOUR_TUYA_CLIENT_ID';         // Получить на developer.tuya.com
  static const String _clientSecret = 'YOUR_TUYA_CLIENT_SECRET'; // Получить на developer.tuya.com
  
  // Access Token Management
  String? _accessToken;
  DateTime? _tokenExpiry;
  Timer? _tokenRefreshTimer;
  
  // Device Cache
  List<TuyaDevice> _cachedDevices = [];
  Timer? _deviceSyncTimer;
  
  TuyaCloudService({
    required LoggingService loggingService,
    required AuthService authService,
  }) : _loggingService = loggingService,
       _authService = authService;

  /// Проверка настроен ли Tuya Cloud API
  bool get isConfigured => _accessToken != null;

  /// Инициализация Tuya Cloud Service
  Future<void> initialize() async {
    try {
      _loggingService.info('🔌 Initializing Tuya Cloud Service...');
      
      // Попытаемся загрузить сохраненный токен
      await _loadSavedToken();
      
      // Если токена нет или он истек - получаем новый
      if (_accessToken == null || _isTokenExpired()) {
        await _authenticateWithTuya();
      }
      
      // Запускаем периодическое обновление токена
      _startTokenRefreshTimer();
      
      // Запускаем синхронизацию устройств
      _startDeviceSyncTimer();
      
      _loggingService.info('✅ Tuya Cloud Service initialized successfully');
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to initialize Tuya Cloud Service', e, stackTrace);
    }
  }

  /// Авторизация в Tuya Cloud API
  Future<bool> _authenticateWithTuya() async {
    try {
      _loggingService.info('🔐 Authenticating with Tuya Cloud...');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final nonce = _generateNonce();
      final signStr = '$_clientId$timestamp$nonce';
      final signature = _generateSignature(signStr, _clientSecret);
      
      final headers = {
        'client_id': _clientId,
        't': timestamp,
        'sign_method': 'HMAC-SHA256',
        'sign': signature,
        'nonce': nonce,
        'Content-Type': 'application/json',
      };
      
      final body = json.encode({
        'grant_type': 'client_credentials',
      });
      
      final response = await http.post(
        Uri.parse('$_baseUrl/v1.0/token'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final result = data['result'];
          _accessToken = result['access_token'];
          final expiresIn = result['expire_time'] as int; // seconds
          _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300)); // Refresh 5 min early
          
          // Сохраняем токен
          await _saveToken();
          
          _loggingService.info('✅ Tuya authentication successful');
          return true;
        }
      }
      
      _loggingService.error('❌ Tuya authentication failed: ${response.body}');
      return false;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Tuya authentication error', e, stackTrace);
      return false;
    }
  }

  /// Получение списка устройств пользователя из Tuya Cloud
  Future<List<TuyaDevice>> fetchUserDevices() async {
    try {
      _loggingService.info('📱 Fetching user devices from Tuya Cloud...');
      
      if (!await _ensureValidToken()) {
        throw Exception('Failed to authenticate with Tuya');
      }
      
      // В реальном приложении здесь должен быть Home ID пользователя
      // Для демонстрации используем общий запрос устройств
      final response = await _makeAuthenticatedRequest(
        'GET',
        '/v1.0/users/devices',
        queryParams: {
          'page_size': '50',
          'page_no': '1',
        },
      );
      
      if (response['success'] == true) {
        final devices = <TuyaDevice>[];
        final deviceList = response['result']['list'] as List?;
        
        if (deviceList != null) {
          for (final deviceData in deviceList) {
            try {
              final device = TuyaDevice.fromJson(deviceData as Map<String, dynamic>);
              devices.add(device);
              _loggingService.info('🔌 Found device: ${device.name} (${device.category})');
            } catch (e) {
              _loggingService.warning('⚠️ Failed to parse device: $deviceData');
            }
          }
        }
        
        _cachedDevices = devices;
        _loggingService.info('✅ Loaded ${devices.length} devices from Tuya Cloud');
        return devices;
      } else {
        throw Exception('Failed to fetch devices: ${response['msg']}');
      }
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to fetch Tuya devices', e, stackTrace);
      return _cachedDevices; // Возвращаем кешированные устройства при ошибке
    }
  }

  /// Управление устройством (включение/выключение)
  Future<bool> controlDevice(String deviceId, String command, dynamic value) async {
    try {
      _loggingService.info('🎛️ Controlling Tuya device $deviceId: $command = $value');
      
      if (!await _ensureValidToken()) {
        throw Exception('Failed to authenticate with Tuya');
      }
      
      final commandData = {
        'commands': [
          {
            'code': command, // 'switch_1', 'bright_value', 'temp_value', etc.
            'value': value,  // true/false, 0-1000, etc.
          }
        ]
      };
      
      final response = await _makeAuthenticatedRequest(
        'POST',
        '/v1.0/devices/$deviceId/commands',
        body: commandData,
      );
      
      if (response['success'] == true) {
        _loggingService.info('✅ Device $deviceId controlled successfully');
        
        // Обновляем кешированное состояние устройства
        _updateCachedDevice(deviceId, command, value);
        
        return true;
      } else {
        throw Exception('Control failed: ${response['msg']}');
      }
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to control device $deviceId', e, stackTrace);
      return false;
    }
  }

  /// Получение текущего состояния устройства
  Future<Map<String, dynamic>?> getDeviceStatus(String deviceId) async {
    try {
      if (!await _ensureValidToken()) {
        return null;
      }
      
      final response = await _makeAuthenticatedRequest(
        'GET',
        '/v1.0/devices/$deviceId/status',
      );
      
      if (response['success'] == true) {
        final statusList = response['result'] as List?;
        if (statusList != null) {
          final statusMap = <String, dynamic>{};
          for (final status in statusList) {
            statusMap[status['code']] = status['value'];
          }
          return statusMap;
        }
      }
      
      return null;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to get device status: $deviceId', e, stackTrace);
      return null;
    }
  }

  /// Конвертация Tuya устройств в SmartHomeDevice для Newport UI
  List<SmartHomeDevice> convertToSmartHomeDevices(List<TuyaDevice> tuyaDevices) {
    final devices = <SmartHomeDevice>[];
    
    for (final tuyaDevice in tuyaDevices) {
      try {
        final device = SmartHomeDevice(
          id: tuyaDevice.id,
          name: tuyaDevice.name,
          type: _mapTuyaCategoryToDeviceType(tuyaDevice.category),
          status: tuyaDevice.online,
          additionalData: {
            'tuya_category': tuyaDevice.category,
            'tuya_product_id': tuyaDevice.productId,
            'tuya_icon': tuyaDevice.icon,
          },
          updatedBy: 'Tuya Cloud',
          lastUpdated: DateTime.now(),
        );
        devices.add(device);
      } catch (e) {
        _loggingService.warning('⚠️ Failed to convert Tuya device: ${tuyaDevice.name}');
      }
    }
    
    return devices;
  }

  /// Получение сценариев автоматизации
  Future<List<TuyaScene>> fetchUserScenes() async {
    try {
      if (!await _ensureValidToken()) {
        return [];
      }
      
      final response = await _makeAuthenticatedRequest(
        'GET',
        '/v1.0/users/scenes',
      );
      
      if (response['success'] == true) {
        final scenes = <TuyaScene>[];
        final sceneList = response['result']['list'] as List?;
        
        if (sceneList != null) {
          for (final sceneData in sceneList) {
            scenes.add(TuyaScene.fromJson(sceneData as Map<String, dynamic>));
          }
        }
        
        return scenes;
      }
      
      return [];
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to fetch Tuya scenes', e, stackTrace);
      return [];
    }
  }

  /// Активация сценария
  Future<bool> executeScene(String sceneId) async {
    try {
      if (!await _ensureValidToken()) {
        return false;
      }
      
      final response = await _makeAuthenticatedRequest(
        'POST',
        '/v1.0/scenes/$sceneId/trigger',
      );
      
      return response['success'] == true;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to execute scene $sceneId', e, stackTrace);
      return false;
    }
  }

  // ==================== ПРИВАТНЫЕ МЕТОДЫ ====================

  /// Выполнение аутентифицированного запроса к Tuya API
  Future<Map<String, dynamic>> _makeAuthenticatedRequest(
    String method,
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, dynamic>? body,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();
    
    // Построение URL
    var url = '$_baseUrl$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
      url += '?$query';
    }
    
    // Создание подписи
    final bodyStr = body != null ? json.encode(body) : '';
    final signStr = '$_clientId$_accessToken$timestamp$nonce$method\n\n$bodyStr\n$endpoint';
    final signature = _generateSignature(signStr, _clientSecret);
    
    final headers = {
      'client_id': _clientId,
      'access_token': _accessToken!,
      't': timestamp,
      'sign_method': 'HMAC-SHA256',
      'sign': signature,
      'nonce': nonce,
      'Content-Type': 'application/json',
    };
    
    http.Response response;
    
    switch (method) {
      case 'GET':
        response = await http.get(Uri.parse(url), headers: headers);
        break;
      case 'POST':
        response = await http.post(Uri.parse(url), headers: headers, body: bodyStr);
        break;
      case 'PUT':
        response = await http.put(Uri.parse(url), headers: headers, body: bodyStr);
        break;
      case 'DELETE':
        response = await http.delete(Uri.parse(url), headers: headers);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }
    
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Генерация подписи для Tuya API
  String _generateSignature(String signStr, String secret) {
    final bytes = utf8.encode(signStr);
    final secretBytes = utf8.encode(secret);
    final hmacSha256 = Hmac(sha256, secretBytes);
    final digest = hmacSha256.convert(bytes);
    return digest.toString().toUpperCase();
  }

  /// Генерация nonce для запросов
  String _generateNonce() {
    final random = Random();
    return random.nextInt(1000000000).toString().padLeft(9, '0');
  }

  /// Проверка валидности токена
  bool _isTokenExpired() {
    return _tokenExpiry == null || DateTime.now().isAfter(_tokenExpiry!);
  }

  /// Обеспечение валидного токена
  Future<bool> _ensureValidToken() async {
    if (_isTokenExpired()) {
      return await _authenticateWithTuya();
    }
    return _accessToken != null;
  }

  /// Сохранение токена в SharedPreferences
  Future<void> _saveToken() async {
    if (_accessToken != null && _tokenExpiry != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tuya_access_token', _accessToken!);
      await prefs.setInt('tuya_token_expiry', _tokenExpiry!.millisecondsSinceEpoch);
    }
  }

  /// Загрузка токена из SharedPreferences
  Future<void> _loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('tuya_access_token');
      final expiry = prefs.getInt('tuya_token_expiry');
      if (expiry != null) {
        _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiry);
      }
    } catch (e) {
      // Игнорируем ошибки загрузки токена
    }
  }

  /// Запуск таймера обновления токена
  void _startTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    
    if (_tokenExpiry != null) {
      final refreshTime = _tokenExpiry!.subtract(const Duration(minutes: 10));
      final delay = refreshTime.difference(DateTime.now());
      
      if (delay.isNegative) {
        _authenticateWithTuya(); // Токен уже истек
      } else {
        _tokenRefreshTimer = Timer(delay, () => _authenticateWithTuya());
      }
    }
  }

  /// Запуск таймера синхронизации устройств
  void _startDeviceSyncTimer() {
    _deviceSyncTimer?.cancel();
    _deviceSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      fetchUserDevices(); // Синхронизируем устройства каждые 5 минут
    });
  }

  /// Обновление кешированного устройства
  void _updateCachedDevice(String deviceId, String command, dynamic value) {
    final index = _cachedDevices.indexWhere((d) => d.id == deviceId);
    if (index != -1) {
      // Обновляем состояние в кеше
      // В реальности здесь нужна более сложная логика обновления
    }
  }

  /// Маппинг категорий Tuya в типы устройств Newport
  SmartDeviceType _mapTuyaCategoryToDeviceType(String category) {
    switch (category.toLowerCase()) {
      case 'light':
      case 'lamp':
      case 'ceiling_light':
      case 'string_light':
        return SmartDeviceType.light;
      case 'air_conditioner':
      case 'ac':
      case 'climate':
        return SmartDeviceType.ac;
      case 'heater':
      case 'heating':
        return SmartDeviceType.heater;
      case 'curtain':
      case 'blind':
      case 'shade':
        return SmartDeviceType.door; // Используем door для штор
      case 'camera':
      case 'security_camera':
        return SmartDeviceType.camera;
      default:
        return SmartDeviceType.light; // По умолчанию
    }
  }

  /// Освобождение ресурсов
  void dispose() {
    _tokenRefreshTimer?.cancel();
    _deviceSyncTimer?.cancel();
  }
}

/// Модель устройства Tuya
class TuyaDevice {
  final String id;
  final String name;
  final String category;
  final String productId;
  final String icon;
  final bool online;
  final Map<String, dynamic> status;

  TuyaDevice({
    required this.id,
    required this.name,
    required this.category,
    required this.productId,
    required this.icon,
    required this.online,
    required this.status,
  });

  factory TuyaDevice.fromJson(Map<String, dynamic> json) {
    return TuyaDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown Device',
      category: json['category'] ?? 'unknown',
      productId: json['product_id'] ?? '',
      icon: json['icon'] ?? '',
      online: json['online'] ?? false,
      status: json['status'] ?? <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'product_id': productId,
      'icon': icon,
      'online': online,
      'status': status,
    };
  }
}

/// Модель сценария Tuya
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
      id: json['scene_id'] ?? '',
      name: json['name'] ?? 'Unknown Scene',
      icon: json['icon'] ?? '',
      enabled: json['enabled'] ?? false,
    );
  }
} 