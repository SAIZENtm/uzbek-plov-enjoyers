import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';

import 'logging_service_secure.dart';
import 'auth_service.dart';
import 'api_service.dart';

/// Безопасный сервис для управления offline очередью с идемпотентностью
class OfflineQueueService {
  static const String _storageKey = 'offline_queue';
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);
  static const Duration _maxRetryDelay = Duration(minutes: 5);
  static const int _maxQueueSize = 1000;
  // static const Duration _operationTimeout = Duration(minutes: 2); // Не используется пока
  
  final LoggingService _loggingService;
  final AuthService _authService;
  final ApiService _apiService;
  final FlutterSecureStorage _secureStorage;
  final Connectivity _connectivity;
  final Uuid _uuid = const Uuid();
  
  // Очередь операций
  final List<QueuedOperation> _queue = [];
  
  // Активные операции (для предотвращения дублирования)
  final Set<String> _processingIds = {};
  
  // Подписки
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  Timer? _retryTimer;
  
  // Состояние
  bool _isProcessing = false;
  bool _isOnline = true;
  
  // Статистика
  int _successCount = 0;
  int _failureCount = 0;
  int _duplicateCount = 0;
  
  OfflineQueueService({
    required LoggingService loggingService,
    required AuthService authService,
    required ApiService apiService,
    FlutterSecureStorage? secureStorage,
    Connectivity? connectivity,
  }) : _loggingService = loggingService,
       _authService = authService,
       _apiService = apiService,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _connectivity = connectivity ?? Connectivity();
  
  /// Инициализация сервиса
  Future<void> initialize() async {
    _loggingService.info('Initializing OfflineQueueService');
    
    // Загружаем сохраненную очередь
    await _loadQueue();
    
    // Проверяем начальное состояние подключения
    final connectivityResult = await _connectivity.checkConnectivity();
    _isOnline = connectivityResult != ConnectivityResult.none;
    
    // Подписываемся на изменения подключения
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    // Запускаем обработку если онлайн
    if (_isOnline) {
      _scheduleProcessing();
    }
    
    _loggingService.info('OfflineQueueService initialized', {
      'queueSize': _queue.length,
      'isOnline': _isOnline,
    });
  }
  
  /// Добавление операции в очередь
  Future<String> enqueue(OfflineOperation operation) async {
    // Генерируем идемпотентный ключ
    final idempotencyKey = _generateIdempotencyKey(operation);
    
    // Проверяем дубликаты
    final existingOperation = _queue.firstWhereOrNull(
      (op) => op.idempotencyKey == idempotencyKey,
    );
    
    if (existingOperation != null) {
      _duplicateCount++;
      _loggingService.debug('Duplicate operation detected', {
        'operationId': existingOperation.id,
        'type': existingOperation.operation.type.toString(),
      });
      return existingOperation.id;
    }
    
    // Проверяем размер очереди
    if (_queue.length >= _maxQueueSize) {
      // Удаляем самые старые неудачные операции
      _queue.removeWhere((op) => 
        op.status == OperationStatus.failed && 
        op.retryCount >= _maxRetries
      );
      
      if (_queue.length >= _maxQueueSize) {
        throw OfflineQueueException('Queue is full');
      }
    }
    
    // Создаем операцию
    final queuedOperation = QueuedOperation(
      id: _uuid.v4(),
      operation: operation,
      idempotencyKey: idempotencyKey,
      userId: _authService.userData?['uid'] ?? _authService.userData?['id'] ?? 'anonymous',
      createdAt: DateTime.now(),
      status: OperationStatus.pending,
      retryCount: 0,
    );
    
    // Добавляем в очередь
    _queue.add(queuedOperation);
    
    // Сохраняем очередь
    await _saveQueue();
    
    _loggingService.info('Operation enqueued', {
      'operationId': queuedOperation.id,
      'type': operation.type.toString(),
      'queueSize': _queue.length,
    });
    
    // Пытаемся обработать сразу если онлайн
    if (_isOnline && !_isProcessing) {
      _processQueue();
    }
    
    return queuedOperation.id;
  }
  
  /// Получение статуса операции
  OperationStatus? getOperationStatus(String operationId) {
    final operation = _queue.firstWhereOrNull((op) => op.id == operationId);
    return operation?.status;
  }
  
  /// Отмена операции
  Future<bool> cancelOperation(String operationId) async {
    final index = _queue.indexWhere((op) => op.id == operationId);
    
    if (index == -1) {
      return false;
    }
    
    final operation = _queue[index];
    
    // Нельзя отменить обрабатываемую операцию
    if (_processingIds.contains(operation.id)) {
      _loggingService.warning('Cannot cancel processing operation', {
        'operationId': operationId,
      });
      return false;
    }
    
    // Удаляем из очереди
    _queue.removeAt(index);
    await _saveQueue();
    
    _loggingService.info('Operation cancelled', {
      'operationId': operationId,
    });
    
    return true;
  }
  
  /// Получение статистики
  Map<String, dynamic> getStatistics() {
    final pendingCount = _queue.where((op) => 
      op.status == OperationStatus.pending
    ).length;
    
    final processingCount = _queue.where((op) => 
      op.status == OperationStatus.processing
    ).length;
    
    final failedCount = _queue.where((op) => 
      op.status == OperationStatus.failed
    ).length;
    
    return {
      'queueSize': _queue.length,
      'pending': pendingCount,
      'processing': processingCount,
      'failed': failedCount,
      'successTotal': _successCount,
      'failureTotal': _failureCount,
      'duplicatesBlocked': _duplicateCount,
      'isOnline': _isOnline,
      'isProcessing': _isProcessing,
    };
  }
  
  /// Генерация идемпотентного ключа
  String _generateIdempotencyKey(OfflineOperation operation) {
    // Создаем ключ на основе типа операции и данных
    final keyData = {
      'type': operation.type.toString(),
      'endpoint': operation.endpoint,
      'method': operation.method,
      'userId': _authService.userData?['uid'] ?? _authService.userData?['id'],
      // Для некоторых операций включаем данные
      if (operation.type == OperationType.createServiceRequest)
        'data': _extractKeyData(operation.data ?? {}),
    };
    
    final keyString = jsonEncode(keyData);
    // Используем простой hash для ключа
    return keyString.hashCode.toString();
  }
  
  /// Извлечение ключевых данных для идемпотентности
  Map<String, dynamic> _extractKeyData(Map<String, dynamic> data) {
    // Извлекаем только ключевые поля, игнорируя timestamps
    final keyFields = [
      'apartmentId',
      'requestType',
      'description',
      'amount',
      'meterId',
      'reading',
    ];
    
    final keyData = <String, dynamic>{};
    for (final field in keyFields) {
      if (data.containsKey(field)) {
        keyData[field] = data[field];
      }
    }
    
    return keyData;
  }
  
  /// Обработка изменения подключения
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;
    
    _loggingService.info('Connectivity changed', {
      'isOnline': _isOnline,
      'result': result.toString(),
    });
    
    if (!wasOnline && _isOnline) {
      // Пришли в онлайн - начинаем обработку
      _scheduleProcessing();
    } else if (wasOnline && !_isOnline) {
      // Ушли в офлайн - останавливаем обработку
      _cancelProcessing();
    }
  }
  
  /// Планирование обработки очереди
  void _scheduleProcessing() {
    if (_isProcessing || _queue.isEmpty) return;
    
    // Запускаем немедленно
    _processQueue();
    
    // Планируем периодическую обработку
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _processQueue(),
    );
  }
  
  /// Отмена обработки
  void _cancelProcessing() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }
  
  /// Обработка очереди
  Future<void> _processQueue() async {
    if (_isProcessing || !_isOnline || _queue.isEmpty) return;
    
    _isProcessing = true;
    
    try {
      // Получаем операции для обработки
      final pendingOperations = _queue
          .where((op) => 
            op.status == OperationStatus.pending ||
            (op.status == OperationStatus.failed && 
             op.retryCount < _maxRetries &&
             _shouldRetry(op)))
          .toList();
      
      if (pendingOperations.isEmpty) return;
      
      _loggingService.info('Processing offline queue', {
        'operationsCount': pendingOperations.length,
      });
      
      // Обрабатываем операции последовательно
      for (final operation in pendingOperations) {
        if (!_isOnline) break; // Прерываем если ушли в офлайн
        
        await _processOperation(operation);
        
        // Небольшая задержка между операциями
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Сохраняем обновленную очередь
      await _saveQueue();
      
    } catch (e) {
      _loggingService.error('Error processing queue', e);
    } finally {
      _isProcessing = false;
    }
  }
  
  /// Обработка одной операции
  Future<void> _processOperation(QueuedOperation operation) async {
    // Проверяем что не обрабатывается
    if (_processingIds.contains(operation.id)) {
      _loggingService.warning('Operation already processing', {
        'operationId': operation.id,
      });
      return;
    }
    
    _processingIds.add(operation.id);
    operation.status = OperationStatus.processing;
    
    try {
      _loggingService.info('Processing operation', {
        'operationId': operation.id,
        'type': operation.operation.type.toString(),
        'retryCount': operation.retryCount,
      });
      
      // Добавляем заголовки идемпотентности
      final headers = Map<String, String>.from(operation.operation.headers ?? {});
      headers['X-Idempotency-Key'] = operation.idempotencyKey;
      headers['X-Operation-Id'] = operation.id;
      headers['X-Retry-Count'] = operation.retryCount.toString();
      
      // Выполняем операцию с таймаутом
      Response response;
      switch (operation.operation.method.toUpperCase()) {
        case 'GET':
          response = Response(requestOptions: RequestOptions(path: ''), data: await _apiService.get(operation.operation.endpoint));
          response.statusCode = 200;
          break;
        case 'POST':
          response = Response(requestOptions: RequestOptions(path: ''), data: await _apiService.post(operation.operation.endpoint, data: operation.operation.data));
          response.statusCode = 200;
          break;
        case 'PUT':
          response = Response(requestOptions: RequestOptions(path: ''), data: await _apiService.put(operation.operation.endpoint, data: operation.operation.data));
          response.statusCode = 200;
          break;
        default:
          throw Exception('Unsupported method: ${operation.operation.method}');
      }
      // Таймаут можно добавить отдельно
      
      // Проверяем успешность
      if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        operation.status = OperationStatus.completed;
        operation.completedAt = DateTime.now();
        operation.response = response.data;
        _successCount++;
        
        _loggingService.info('Operation completed successfully', {
          'operationId': operation.id,
          'statusCode': response.statusCode,
        });
        
        // Удаляем успешную операцию из очереди
        _queue.removeWhere((op) => op.id == operation.id);
        
      } else if ((response.statusCode ?? 0) == 409) {
        // Конфликт - операция уже выполнена
        operation.status = OperationStatus.completed;
        operation.completedAt = DateTime.now();
        operation.response = {'duplicate': true};
        _duplicateCount++;
        
        _loggingService.info('Operation already processed on server', {
          'operationId': operation.id,
        });
        
        _queue.removeWhere((op) => op.id == operation.id);
        
      } else {
        // Ошибка
        throw ApiException(
          'Operation failed',
          statusCode: response.statusCode ?? 0,
          response: response.data,
        );
      }
      
    } on TimeoutException {
      _handleOperationError(operation, 'Operation timeout');
      
    } on ApiException catch (e) {
      if ((e.statusCode ?? 0) == 401) {
        // Ошибка авторизации - не ретраим
        operation.status = OperationStatus.failed;
        operation.error = 'Authentication required';
        operation.retryCount = _maxRetries; // Не будем ретраить
        _failureCount++;
        
        _loggingService.error('Operation failed: auth required', e);
        
      } else if ((e.statusCode ?? 0) >= 400 && (e.statusCode ?? 0) < 500) {
        // Клиентская ошибка - не ретраим
        operation.status = OperationStatus.failed;
        operation.error = e.message;
        operation.retryCount = _maxRetries; // Не будем ретраить
        _failureCount++;
        
        _loggingService.error('Operation failed: client error', e);
        
      } else {
        // Серверная ошибка - будем ретраить
        _handleOperationError(operation, e.message);
      }
      
    } catch (e) {
      _handleOperationError(operation, e.toString());
      
    } finally {
      _processingIds.remove(operation.id);
    }
  }
  
  /// Обработка ошибки операции
  void _handleOperationError(QueuedOperation operation, String error) {
    operation.status = OperationStatus.failed;
    operation.error = error;
    operation.retryCount++;
    operation.lastRetryAt = DateTime.now();
    
    if (operation.retryCount >= _maxRetries) {
      _failureCount++;
      _loggingService.error('Operation failed after max retries', error);
    } else {
      _loggingService.warning('Operation failed, will retry. OpID: ${operation.id}, retry: ${operation.retryCount}');
    }
  }
  
  /// Проверка нужно ли ретраить операцию
  bool _shouldRetry(QueuedOperation operation) {
    if (operation.lastRetryAt == null) return true;
    
    // Экспоненциальный backoff
    final retryDelay = _calculateRetryDelay(operation.retryCount);
    final nextRetryTime = operation.lastRetryAt!.add(retryDelay);
    
    return DateTime.now().isAfter(nextRetryTime);
  }
  
  /// Расчет задержки для ретрая
  Duration _calculateRetryDelay(int retryCount) {
    // Экспоненциальный backoff с jitter
    final exponentialDelay = _baseRetryDelay * pow(2, retryCount - 1);
    final jitter = Random().nextDouble() * 0.3; // ±30% jitter
    final delayMs = exponentialDelay.inMilliseconds * (1 + jitter - 0.15);
    
    return Duration(
      milliseconds: min(delayMs.round(), _maxRetryDelay.inMilliseconds),
    );
  }
  
  /// Загрузка очереди из хранилища
  Future<void> _loadQueue() async {
    try {
      final queueJson = await _secureStorage.read(key: _storageKey);
      
      if (queueJson != null) {
        final queueData = jsonDecode(queueJson) as List;
        
        _queue.clear();
        for (final item in queueData) {
          try {
            _queue.add(QueuedOperation.fromJson(item));
          } catch (e) {
            _loggingService.error('Failed to load queue item', e);
          }
        }
        
        _loggingService.info('Queue loaded from storage', {
          'itemsCount': _queue.length,
        });
        
        // Очищаем старые операции
        _cleanupOldOperations();
      }
    } catch (e) {
      _loggingService.error('Failed to load queue', e);
    }
  }
  
  /// Сохранение очереди в хранилище
  Future<void> _saveQueue() async {
    try {
      final queueData = _queue.map((op) => op.toJson()).toList();
      final queueJson = jsonEncode(queueData);
      
      await _secureStorage.write(
        key: _storageKey,
        value: queueJson,
      );
      
      _loggingService.debug('Queue saved to storage', {
        'itemsCount': _queue.length,
      });
    } catch (e) {
      _loggingService.error('Failed to save queue', e);
    }
  }
  
  /// Очистка старых операций
  void _cleanupOldOperations() {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    
    final int oldSize = _queue.length;
    _queue.removeWhere((op) =>
      op.status == OperationStatus.failed &&
      op.retryCount >= _maxRetries &&
      op.createdAt.isBefore(cutoffDate)
    );
    final int removedCount = oldSize - _queue.length;
    
    if (removedCount > 0) {
      _loggingService.info('Cleaned up old operations', {
        'removedCount': removedCount,
      });
    }
  }
  
  /// Освобождение ресурсов
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _saveQueue(); // Сохраняем перед закрытием
  }
}

/// Типы операций
enum OperationType {
  createServiceRequest,
  updateProfile,
  submitMeterReading,
  sendFeedback,
  custom,
}

/// Статус операции
enum OperationStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Offline операция
class OfflineOperation {
  final OperationType type;
  final String method;
  final String endpoint;
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
  
  OfflineOperation({
    required this.type,
    required this.method,
    required this.endpoint,
    this.data,
    this.headers,
  });
  
  Map<String, dynamic> toJson() => {
    'type': type.toString(),
    'method': method,
    'endpoint': endpoint,
    'data': data,
    'headers': headers,
  };
  
  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      type: OperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => OperationType.custom,
      ),
      method: json['method'],
      endpoint: json['endpoint'],
      data: json['data'],
      headers: Map<String, String>.from(json['headers'] ?? {}),
    );
  }
}

/// Операция в очереди
class QueuedOperation {
  final String id;
  final OfflineOperation operation;
  final String idempotencyKey;
  final String userId;
  final DateTime createdAt;
  OperationStatus status;
  int retryCount;
  DateTime? lastRetryAt;
  DateTime? completedAt;
  String? error;
  dynamic response;
  
  QueuedOperation({
    required this.id,
    required this.operation,
    required this.idempotencyKey,
    required this.userId,
    required this.createdAt,
    required this.status,
    required this.retryCount,
    this.lastRetryAt,
    this.completedAt,
    this.error,
    this.response,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'operation': operation.toJson(),
    'idempotencyKey': idempotencyKey,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
    'status': status.toString(),
    'retryCount': retryCount,
    'lastRetryAt': lastRetryAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'error': error,
    'response': response,
  };
  
  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'],
      operation: OfflineOperation.fromJson(json['operation']),
      idempotencyKey: json['idempotencyKey'],
      userId: json['userId'],
      createdAt: DateTime.parse(json['createdAt']),
      status: OperationStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
      ),
      retryCount: json['retryCount'],
      lastRetryAt: json['lastRetryAt'] != null 
          ? DateTime.parse(json['lastRetryAt']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      error: json['error'],
      response: json['response'],
    );
  }
}

/// Исключение для offline queue
class OfflineQueueException implements Exception {
  final String message;
  
  OfflineQueueException(this.message);
  
  @override
  String toString() => 'OfflineQueueException: $message';
}

/// Исключение API
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;
  
  ApiException(this.message, {this.statusCode, this.response});
  
  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}
