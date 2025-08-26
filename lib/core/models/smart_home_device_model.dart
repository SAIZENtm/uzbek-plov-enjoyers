import 'package:cloud_firestore/cloud_firestore.dart';

/// Типы устройств умного дома
enum SmartDeviceType {
  light('light', 'Освещение', '💡'),
  ac('ac', 'Кондиционер', '❄️'),
  heater('heater', 'Отопление', '🔥'),
  door('door', 'Дверной замок', '🚪'),
  camera('camera', 'Камера', '📹');

  const SmartDeviceType(this.id, this.displayName, this.emoji);
  
  final String id;
  final String displayName;
  final String emoji;
  
  static SmartDeviceType fromString(String type) {
    return SmartDeviceType.values.firstWhere(
      (e) => e.id == type,
      orElse: () => SmartDeviceType.light,
    );
  }
}

/// Модель устройства умного дома
class SmartHomeDevice {
  final String id;
  final String name;
  final SmartDeviceType type;
  final bool status; // включено/выключено
  final double? temperature; // для кондиционера/отопления
  final Map<String, dynamic>? additionalData; // дополнительные параметры
  final DateTime? lastUpdated;
  final String? updatedBy;

  const SmartHomeDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    this.temperature,
    this.additionalData,
    this.lastUpdated,
    this.updatedBy,
  });

  /// Создание из JSON/Firestore
  factory SmartHomeDevice.fromJson(Map<String, dynamic> json) {
    return SmartHomeDevice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: SmartDeviceType.fromString(json['type'] ?? 'light'),
      status: json['status'] == 'on' || json['status'] == true,
      temperature: json['temperature']?.toDouble(),
      additionalData: json['additionalData'] as Map<String, dynamic>?,
      lastUpdated: json['lastUpdated'] is Timestamp
          ? (json['lastUpdated'] as Timestamp).toDate()
          : json['lastUpdated'] != null
              ? DateTime.parse(json['lastUpdated'])
              : null,
      updatedBy: json['updatedBy'],
    );
  }

  /// Конвертация в JSON для Firestore
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.id,
      'status': status ? 'on' : 'off',
      if (temperature != null) 'temperature': temperature,
      if (additionalData != null) 'additionalData': additionalData,
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
    };
  }

  /// Копирование с изменениями
  SmartHomeDevice copyWith({
    String? id,
    String? name,
    SmartDeviceType? type,
    bool? status,
    double? temperature,
    Map<String, dynamic>? additionalData,
    DateTime? lastUpdated,
    String? updatedBy,
  }) {
    return SmartHomeDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      temperature: temperature ?? this.temperature,
      additionalData: additionalData ?? this.additionalData,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Получение иконки устройства
  String get icon => type.emoji;

  /// Получение статуса как строки
  String get statusText => status ? 'Включено' : 'Выключено';

  /// Проверка поддержки температуры
  bool get hasTemperatureControl => 
      type == SmartDeviceType.ac || type == SmartDeviceType.heater;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartHomeDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SmartHomeDevice{id: $id, name: $name, type: $type, status: $status, temperature: $temperature}';
  }
}

/// Модель конфигурации умного дома для квартиры
class SmartHomeConfiguration {
  final List<SmartHomeDevice> devices;
  final DateTime? lastSyncTime;
  final bool isEnabled;

  const SmartHomeConfiguration({
    required this.devices,
    this.lastSyncTime,
    this.isEnabled = true,
  });

  factory SmartHomeConfiguration.fromJson(Map<String, dynamic> json) {
    final devicesJson = json['devices'] as List<dynamic>? ?? [];
    final devices = devicesJson
        .map((deviceJson) => SmartHomeDevice.fromJson(deviceJson as Map<String, dynamic>))
        .toList();

    return SmartHomeConfiguration(
      devices: devices,
      lastSyncTime: json['lastSyncTime'] is Timestamp
          ? (json['lastSyncTime'] as Timestamp).toDate()
          : json['lastSyncTime'] != null
              ? DateTime.parse(json['lastSyncTime'])
              : null,
      isEnabled: json['isEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'devices': devices.map((device) => device.toJson()).toList(),
      if (lastSyncTime != null) 'lastSyncTime': lastSyncTime!.toIso8601String(),
      'isEnabled': isEnabled,
    };
  }

  SmartHomeConfiguration copyWith({
    List<SmartHomeDevice>? devices,
    DateTime? lastSyncTime,
    bool? isEnabled,
  }) {
    return SmartHomeConfiguration(
      devices: devices ?? this.devices,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  /// Получение устройства по ID
  SmartHomeDevice? getDevice(String deviceId) {
    try {
      return devices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }

  /// Обновление устройства
  SmartHomeConfiguration updateDevice(SmartHomeDevice updatedDevice) {
    final updatedDevices = devices.map((device) {
      return device.id == updatedDevice.id ? updatedDevice : device;
    }).toList();

    return copyWith(devices: updatedDevices);
  }

  /// Добавление нового устройства
  SmartHomeConfiguration addDevice(SmartHomeDevice newDevice) {
    return copyWith(devices: [...devices, newDevice]);
  }

  /// Удаление устройства
  SmartHomeConfiguration removeDevice(String deviceId) {
    final filteredDevices = devices.where((device) => device.id != deviceId).toList();
    return copyWith(devices: filteredDevices);
  }

  /// Группировка устройств по типу
  Map<SmartDeviceType, List<SmartHomeDevice>> get devicesByType {
    final Map<SmartDeviceType, List<SmartHomeDevice>> grouped = {};
    
    for (final device in devices) {
      grouped.putIfAbsent(device.type, () => []).add(device);
    }
    
    return grouped;
  }

  /// Количество включенных устройств
  int get activeDevicesCount => devices.where((device) => device.status).length;

  /// Пустая конфигурация
  static const SmartHomeConfiguration empty = SmartHomeConfiguration(devices: []);
} 