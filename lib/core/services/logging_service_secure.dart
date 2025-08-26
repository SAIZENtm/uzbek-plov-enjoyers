import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Безопасный сервис логирования с фильтрацией PII
class LoggingService {
  static const String _logTag = 'NewportApp';
  
  // Регулярные выражения для обнаружения PII
  static final RegExp _phoneRegex = RegExp(r'\+?\d{10,15}');
  static final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
  static final RegExp _passportRegex = RegExp(r'[A-Z]{2}\d{7}');
  static final RegExp _cardNumberRegex = RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b');
  // static final RegExp _cvvRegex = RegExp(r'\b\d{3,4}\b'); // Не используется пока
  static final RegExp _ipRegex = RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b');
  
  // Поля, которые нужно маскировать
  static const Set<String> _sensitiveFields = {
    'phone', 'phoneNumber', 'passport', 'passportNumber', 
    'password', 'token', 'accessToken', 'refreshToken',
    'email', 'fullName', 'name', 'cardNumber', 'cvv',
    'clientId', 'clientSecret', 'apiKey', 'privateKey',
    'fcmToken', 'deviceToken', 'sessionId', 'userId',
  };
  
  final bool _enableDebugLogging;
  final bool _enableCrashlytics;
  
  LoggingService({
    bool enableDebugLogging = kDebugMode,
    bool enableCrashlytics = !kDebugMode,
  }) : _enableDebugLogging = enableDebugLogging,
       _enableCrashlytics = enableCrashlytics;
  
  /// Логирование информационных сообщений
  void info(String message, [dynamic errorOrData, StackTrace? stackTrace]) {
    if (errorOrData is Map<String, dynamic>) {
      _log('INFO', message, errorOrData);
    } else {
      _log('INFO', message, {}, errorOrData, stackTrace);
    }
  }
  
  /// Логирование предупреждений
  void warning(String message, [dynamic errorOrData, StackTrace? stackTrace]) {
    if (errorOrData is Map<String, dynamic>) {
      _log('WARNING', message, errorOrData);
    } else {
      _log('WARNING', message, {}, errorOrData, stackTrace);
    }
  }
  
  /// Логирование ошибок
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message, {}, error, stackTrace);
    
    // Отправка в Crashlytics
    if (_enableCrashlytics && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: message,
        information: {},
      );
    }
  }
  
  /// Логирование отладочной информации
  void debug(String message, [dynamic errorOrData, StackTrace? stackTrace]) {
    if (_enableDebugLogging) {
      if (errorOrData is Map<String, dynamic>) {
        _log('DEBUG', message, errorOrData);
      } else {
        _log('DEBUG', message, {}, errorOrData, stackTrace);
      }
    }
  }
  
  /// Логирование критических ошибок (совместимость с обычным LoggingService)
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('FATAL', message, {}, error, stackTrace);
    
    // Отправка в Crashlytics как критическая ошибка
    if (_enableCrashlytics) {
      FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace,
        reason: 'FATAL: $message',
        fatal: true,
      );
    }
  }
  
  /// Логирование трассировки (совместимость с обычным LoggingService)
  void trace(String message, [dynamic error, StackTrace? stackTrace]) {
    if (_enableDebugLogging) {
      _log('TRACE', message, {}, error, stackTrace);
    }
  }
  
  /// Логирование сетевых запросов (без чувствительных данных)
  void logNetworkRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
    int? statusCode,
    dynamic response,
    Duration? duration,
  }) {
    final sanitizedUrl = _sanitizeUrl(url);
    final sanitizedHeaders = _sanitizeHeaders(headers ?? {});
    final sanitizedBody = _sanitizeData(body ?? {});
    final sanitizedResponse = _sanitizeData(response ?? {});
    
    final logData = {
      'method': method,
      'url': sanitizedUrl,
      'statusCode': statusCode,
      'duration': duration?.inMilliseconds,
      'headers': sanitizedHeaders,
      'body': sanitizedBody,
      'response': sanitizedResponse,
    };
    
    if (statusCode != null && statusCode >= 400) {
      warning('Network request failed', logData);
    } else {
      debug('Network request', logData);
    }
  }
  
  /// Логирование событий аналитики (без PII)
  void logAnalyticsEvent(String eventName, [Map<String, dynamic>? parameters]) {
    final sanitizedParams = _sanitizeData(parameters ?? {});
    debug('Analytics: $eventName', sanitizedParams);
  }
  
  /// Основной метод логирования
  void _log(
    String level,
    String message,
    Map<String, dynamic>? data, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    // Санитизация сообщения
    final sanitizedMessage = _sanitizeString(message);
    final sanitizedData = _sanitizeData(data ?? {});
    
    // Форматирование времени
    final timestamp = DateTime.now().toIso8601String();
    
    // Создание лог записи
    final logEntry = {
      'timestamp': timestamp,
      'level': level,
      'message': sanitizedMessage,
      if (sanitizedData.isNotEmpty) 'data': sanitizedData,
      if (error != null) 'error': error.toString(),
    };
    
    // Вывод в консоль для отладки
    if (_enableDebugLogging) {
      final logString = _formatLogEntry(logEntry);
      
      switch (level) {
        case 'FATAL':
          developer.log(
            logString,
            name: _logTag,
            error: error,
            stackTrace: stackTrace,
            level: 1200,
          );
          break;
        case 'ERROR':
          developer.log(
            logString,
            name: _logTag,
            error: error,
            stackTrace: stackTrace,
            level: 1000,
          );
          break;
        case 'WARNING':
          developer.log(logString, name: _logTag, level: 900);
          break;
        case 'INFO':
          developer.log(logString, name: _logTag, level: 800);
          break;
        case 'DEBUG':
          developer.log(logString, name: _logTag, level: 700);
          break;
        case 'TRACE':
          developer.log(logString, name: _logTag, level: 600);
          break;
      }
    }
  }
  
  /// Форматирование лог записи для вывода
  String _formatLogEntry(Map<String, dynamic> entry) {
    final buffer = StringBuffer();
    buffer.write('[${entry['timestamp']}] ');
    buffer.write('[${entry['level']}] ');
    buffer.write(entry['message']);
    
    if (entry.containsKey('data')) {
      buffer.write(' | Data: ${_jsonEncode(entry['data'])}');
    }
    
    if (entry.containsKey('error')) {
      buffer.write(' | Error: ${entry['error']}');
    }
    
    return buffer.toString();
  }
  
  /// Безопасное кодирование JSON
  String _jsonEncode(dynamic data) {
    try {
      // Простое представление для логов
      if (data is Map) {
        return data.entries
            .map((e) => '${e.key}: ${e.value}')
            .join(', ');
      }
      return data.toString();
    } catch (e) {
      return '<encoding error>';
    }
  }
  
  /// Санитизация строки от PII
  String _sanitizeString(String input) {
    String result = input;
    
    // Маскирование телефонов
    result = result.replaceAllMapped(_phoneRegex, (match) {
      final phone = match.group(0)!;
      if (phone.length > 6) {
        return '${phone.substring(0, 3)}***${phone.substring(phone.length - 2)}';
      }
      return '***';
    });
    
    // Маскирование email
    result = result.replaceAllMapped(_emailRegex, (match) {
      final email = match.group(0)!;
      final parts = email.split('@');
      if (parts.length == 2) {
        final name = parts[0];
        final maskedName = name.length > 2 
            ? '${name.substring(0, 2)}***' 
            : '***';
        return '$maskedName@${parts[1]}';
      }
      return '***@***';
    });
    
    // Маскирование паспортов
    result = result.replaceAllMapped(_passportRegex, (match) {
      final passport = match.group(0)!;
      return '${passport.substring(0, 2)}*****';
    });
    
    // Маскирование номеров карт
    result = result.replaceAllMapped(_cardNumberRegex, (match) {
      return '****-****-****-****';
    });
    
    // Маскирование IP адресов
    result = result.replaceAllMapped(_ipRegex, (match) {
      return '***.***.***.***';
    });
    
    return result;
  }
  
  /// Санитизация данных (Map/List)
  dynamic _sanitizeData(dynamic data) {
    if (data == null) return null;
    
    if (data is String) {
      return _sanitizeString(data);
    }
    
    if (data is Map) {
      final sanitized = <String, dynamic>{};
      
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        
        // Проверка чувствительных полей
        if (_isSensitiveField(key)) {
          sanitized[key] = _maskValue(value);
        } else {
          sanitized[key] = _sanitizeData(value);
        }
      }
      
      return sanitized;
    }
    
    if (data is List) {
      return data.map((item) => _sanitizeData(item)).toList();
    }
    
    // Для других типов возвращаем как есть
    return data;
  }
  
  /// Проверка является ли поле чувствительным
  bool _isSensitiveField(String fieldName) {
    final lowerField = fieldName.toLowerCase();
    return _sensitiveFields.any((sensitive) => 
      lowerField.contains(sensitive.toLowerCase()));
  }
  
  /// Маскирование значения
  String _maskValue(dynamic value) {
    if (value == null) return '<null>';
    
    final stringValue = value.toString();
    if (stringValue.isEmpty) return '<empty>';
    
    // Для коротких значений
    if (stringValue.length <= 4) {
      return '*' * stringValue.length;
    }
    
    // Для длинных значений показываем начало и конец
    final visibleChars = stringValue.length > 10 ? 2 : 1;
    final start = stringValue.substring(0, visibleChars);
    final end = stringValue.substring(stringValue.length - visibleChars);
    
    return '$start***$end';
  }
  
  /// Санитизация URL
  String _sanitizeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final params = Map<String, dynamic>.from(uri.queryParameters);
      final sanitizedParams = _sanitizeData(params);
      
      // Пересобираем URL с санитизированными параметрами
      final newUri = uri.replace(
        queryParameters: sanitizedParams.map((k, v) => MapEntry(k, v.toString())),
      );
      
      return newUri.toString();
    } catch (e) {
      // Если не удалось распарсить, санитизируем как строку
      return _sanitizeString(url);
    }
  }
  
  /// Санитизация заголовков
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = <String, dynamic>{};
    
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      
      // Скрываем токены авторизации
      if (key.contains('authorization') || 
          key.contains('x-api-key') ||
          key.contains('x-auth-token')) {
        sanitized[entry.key] = '<redacted>';
      } else {
        sanitized[entry.key] = _sanitizeData(entry.value);
      }
    }
    
    return sanitized;
  }
  
  /// Установка пользовательских атрибутов для Crashlytics
  void setUserIdentifier(String identifier) {
    if (_enableCrashlytics) {
      // Хешируем идентификатор для приватности
      final hashedId = identifier.hashCode.toString();
      FirebaseCrashlytics.instance.setUserIdentifier(hashedId);
    }
  }
  
  /// Добавление хлебных крошек для отладки
  void addBreadcrumb(String message, [Map<String, dynamic>? data]) {
    if (_enableCrashlytics) {
      final sanitizedData = _sanitizeData(data ?? {});
      FirebaseCrashlytics.instance.log(
        '$message${sanitizedData.isNotEmpty ? ' | ${_jsonEncode(sanitizedData)}' : ''}'
      );
    }
  }
}
