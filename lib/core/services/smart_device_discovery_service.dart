import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/smart_home_device_model.dart';
import 'logging_service_secure.dart';

/// Сервис для автоматического обнаружения умных устройств в WiFi сети
class SmartDeviceDiscoveryService {
  final LoggingService _loggingService;
  
  SmartDeviceDiscoveryService({
    required LoggingService loggingService,
  }) : _loggingService = loggingService;

  /// Автоматическое сканирование умных устройств в сети
  Future<List<DiscoveredDevice>> scanForSmartDevices() async {
    try {
      _loggingService.info('🔍 Starting smart device discovery...');
      
      final devices = <DiscoveredDevice>[];
      
      // Получаем информацию о WiFi сети
      final networkInfo = NetworkInfo();
      final wifiName = await networkInfo.getWifiName();
      final wifiIP = await networkInfo.getWifiIP();
      
      _loggingService.info('📶 Scanning network: $wifiName (IP: $wifiIP)');
      
      // Сканируем популярные умные устройства
      devices.addAll(await _scanForXiaomiDevices());
      devices.addAll(await _scanForTuyaDevices());
      devices.addAll(await _scanForPhilipsHueDevices());
      devices.addAll(await _scanForTPlinkDevices());
      devices.addAll(await _scanForSamsungDevices());
      devices.addAll(await _scanForLGDevices());
      devices.addAll(await _scanForGenericDevices());
      
      _loggingService.info('✅ Found ${devices.length} smart devices');
      return devices;
    } catch (e, stackTrace) {
      _loggingService.error('❌ Failed to scan for devices', e, stackTrace);
      return [];
    }
  }

  /// Сканирование устройств Xiaomi (Mi Home)
  Future<List<DiscoveredDevice>> _scanForXiaomiDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // Xiaomi устройства обычно используют порты 54321, 4321
      final commonPorts = [54321, 4321];
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        for (final port in commonPorts) {
          try {
            final socket = await Socket.connect(ip, port, timeout: const Duration(milliseconds: 100));
            
            // Пытаемся определить тип устройства по порту и ответу
            final device = DiscoveredDevice(
              id: 'xiaomi_${ip.replaceAll('.', '_')}',
              name: 'Xiaomi Smart Device',
              brand: 'Xiaomi',
              type: _guessDeviceType(port),
              ipAddress: ip,
              port: port,
              isOnline: true,
              protocol: 'miio',
            );
            
            devices.add(device);
            socket.destroy();
            break;
          } catch (e) {
            // Устройство не найдено на этом IP:порт
          }
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ Xiaomi scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование устройств Tuya/Smart Life
  Future<List<DiscoveredDevice>> _scanForTuyaDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // Tuya устройства используют порт 6668
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        try {
          final socket = await Socket.connect(ip, 6668, timeout: const Duration(milliseconds: 100));
          
          final device = DiscoveredDevice(
            id: 'tuya_${ip.replaceAll('.', '_')}',
            name: 'Smart Life Device',
            brand: 'Tuya',
            type: SmartDeviceType.light, // По умолчанию
            ipAddress: ip,
            port: 6668,
            isOnline: true,
            protocol: 'tuya',
          );
          
          devices.add(device);
          socket.destroy();
        } catch (e) {
          // Устройство не найдено
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ Tuya scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование Philips Hue
  Future<List<DiscoveredDevice>> _scanForPhilipsHueDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // Hue Bridge использует порт 80
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        try {
          final client = HttpClient();
          final request = await client.get(ip, 80, '/api/config');
          request.headers.add('User-Agent', 'Newport Smart Home');
          
          final response = await request.close().timeout(const Duration(milliseconds: 500));
          
          if (response.statusCode == 200) {
            final device = DiscoveredDevice(
              id: 'hue_bridge_${ip.replaceAll('.', '_')}',
              name: 'Philips Hue Bridge',
              brand: 'Philips',
              type: SmartDeviceType.light,
              ipAddress: ip,
              port: 80,
              isOnline: true,
              protocol: 'hue',
            );
            
            devices.add(device);
          }
          
          client.close();
        } catch (e) {
          // Устройство не найдено
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ Hue scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование TP-Link Kasa устройств
  Future<List<DiscoveredDevice>> _scanForTPlinkDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // TP-Link Kasa использует порт 9999
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        try {
          final socket = await Socket.connect(ip, 9999, timeout: const Duration(milliseconds: 100));
          
          final device = DiscoveredDevice(
            id: 'tplink_${ip.replaceAll('.', '_')}',
            name: 'TP-Link Kasa Device',
            brand: 'TP-Link',
            type: SmartDeviceType.light,
            ipAddress: ip,
            port: 9999,
            isOnline: true,
            protocol: 'kasa',
          );
          
          devices.add(device);
          socket.destroy();
        } catch (e) {
          // Устройство не найдено
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ TP-Link scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование Samsung SmartThings
  Future<List<DiscoveredDevice>> _scanForSamsungDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // Samsung устройства часто используют UPnP (порт 1900)
      final subnet = await _getSubnet();
      
      // Поиск Samsung кондиционеров и телевизоров
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        try {
          final client = HttpClient();
          final request = await client.get(ip, 8080, '/');
          
          final response = await request.close().timeout(const Duration(milliseconds: 300));
          
          if (response.statusCode == 200) {
            // Проверяем заголовки на наличие Samsung
            final server = response.headers.value('server') ?? '';
            if (server.toLowerCase().contains('samsung')) {
              final device = DiscoveredDevice(
                id: 'samsung_${ip.replaceAll('.', '_')}',
                name: 'Samsung Smart Device',
                brand: 'Samsung',
                type: SmartDeviceType.ac, // Скорее всего кондиционер
                ipAddress: ip,
                port: 8080,
                isOnline: true,
                protocol: 'samsung',
              );
              
              devices.add(device);
            }
          }
          
          client.close();
        } catch (e) {
          // Устройство не найдено
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ Samsung scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование LG ThinQ
  Future<List<DiscoveredDevice>> _scanForLGDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        try {
          final client = HttpClient();
          final request = await client.get(ip, 8080, '/');
          
          final response = await request.close().timeout(const Duration(milliseconds: 300));
          
          if (response.statusCode == 200) {
            final server = response.headers.value('server') ?? '';
            if (server.toLowerCase().contains('lg')) {
              final device = DiscoveredDevice(
                id: 'lg_${ip.replaceAll('.', '_')}',
                name: 'LG ThinQ Device',
                brand: 'LG',
                type: SmartDeviceType.ac,
                ipAddress: ip,
                port: 8080,
                isOnline: true,
                protocol: 'lg',
              );
              
              devices.add(device);
            }
          }
          
          client.close();
        } catch (e) {
          // Устройство не найдено
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ LG scan failed: $e');
    }
    
    return devices;
  }

  /// Сканирование общих устройств
  Future<List<DiscoveredDevice>> _scanForGenericDevices() async {
    final devices = <DiscoveredDevice>[];
    
    try {
      // Сканируем общие порты умных устройств
      final commonPorts = [80, 8080, 8081, 8888, 10000];
      final subnet = await _getSubnet();
      
      for (int i = 1; i < 255; i++) {
        final ip = '$subnet.$i';
        
        for (final port in commonPorts) {
          try {
            final client = HttpClient();
            final request = await client.get(ip, port, '/');
            
            final response = await request.close().timeout(const Duration(milliseconds: 200));
            
            if (response.statusCode == 200) {
              // Проверяем заголовки на наличие умных устройств
              final server = response.headers.value('server') ?? '';
              final contentType = response.headers.value('content-type') ?? '';
              
              if (_isSmartDevice(server, contentType)) {
                final device = DiscoveredDevice(
                  id: 'generic_${ip.replaceAll('.', '_')}_$port',
                  name: 'Smart Device',
                  brand: 'Unknown',
                  type: SmartDeviceType.light,
                  ipAddress: ip,
                  port: port,
                  isOnline: true,
                  protocol: 'http',
                );
                
                devices.add(device);
                break; // Найдено устройство на этом IP
              }
            }
            
            client.close();
          } catch (e) {
            // Устройство не найдено на этом порту
          }
        }
      }
    } catch (e) {
      _loggingService.warning('⚠️ Generic scan failed: $e');
    }
    
    return devices;
  }

  /// Получение подсети
  Future<String> _getSubnet() async {
    final networkInfo = NetworkInfo();
    final wifiIP = await networkInfo.getWifiIP() ?? '192.168.1.100';
    final parts = wifiIP.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  /// Определение типа устройства по порту
  SmartDeviceType _guessDeviceType(int port) {
    switch (port) {
      case 54321:
      case 4321:
        return SmartDeviceType.ac; // Xiaomi кондиционеры
      case 6668:
        return SmartDeviceType.light; // Tuya лампы/розетки
      case 80:
      case 8080:
        return SmartDeviceType.light; // HTTP устройства
      default:
        return SmartDeviceType.light;
    }
  }

  /// Проверка является ли устройство умным
  bool _isSmartDevice(String server, String contentType) {
    final smartKeywords = [
      'smart', 'iot', 'esp', 'arduino', 'tasmota', 'esphome',
      'shelly', 'sonoff', 'wemo', 'lifx', 'nanoleaf'
    ];
    
    final combined = '$server $contentType'.toLowerCase();
    return smartKeywords.any((keyword) => combined.contains(keyword));
  }
}

/// Информация об обнаруженном устройстве
class DiscoveredDevice {
  final String id;
  final String name;
  final String brand;
  final SmartDeviceType type;
  final String ipAddress;
  final int port;
  final bool isOnline;
  final String protocol;
  final Map<String, dynamic>? additionalInfo;

  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.brand,
    required this.type,
    required this.ipAddress,
    required this.port,
    required this.isOnline,
    required this.protocol,
    this.additionalInfo,
  });

  /// Конвертация в SmartHomeDevice
  SmartHomeDevice toSmartHomeDevice() {
    return SmartHomeDevice(
      id: id,
      name: name,
      type: type,
      status: false,
      temperature: type == SmartDeviceType.ac ? 23.0 : null,
      additionalData: {
        'brand': brand,
        'ipAddress': ipAddress,
        'port': port,
        'protocol': protocol,
        'isReal': true,
        if (additionalInfo != null) ...additionalInfo!,
      },
      lastUpdated: DateTime.now(),
      updatedBy: 'Auto-Discovery',
    );
  }
} 