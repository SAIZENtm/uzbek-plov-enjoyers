import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'offline_queue_service.dart';
// import 'notification_service.dart';
import 'package:flutter/material.dart';

// Временные определения типов
enum ServiceRequestType {
  emergency,
  waterLeak,
  electricalIssue,
  repair,
  plumbing,
  cleaning,
  other,
}

enum ServiceContactMethod {
  phone,
  email,
  inApp,
}

class ServiceRequest {
  final String id;
  final String description;
  final ServiceRequestType type;
  final String status;
  final DateTime createdAt;
  
  ServiceRequest({
    required this.id,
    required this.description,
    required this.type,
    required this.status,
    required this.createdAt,
  });
  
  static ServiceRequest fromFirestore(Map<String, dynamic> data, String id) {
    return ServiceRequest(
      id: id,
      description: data['description'] ?? '',
      type: ServiceRequestType.values.firstWhere(
        (e) => e.toString().split('.').last == data['requestType'],
        orElse: () => ServiceRequestType.other,
      ),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Сервис для работы с заявками на обслуживание с поддержкой offline
class ServiceRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  final LoggingService _loggingService;
  final OfflineQueueService _offlineQueue;
  // final NotificationService _notificationService; // Не используется пока
  final Uuid _uuid = const Uuid();

  ServiceRequestService({
    required AuthService authService,
    required LoggingService loggingService,
    required OfflineQueueService offlineQueue,
    // required NotificationService notificationService, // Не используется пока
  }) : _authService = authService,
       _loggingService = loggingService,
       _offlineQueue = offlineQueue;

  /// Создание новой заявки (с поддержкой offline)
  Future<ServiceRequestResult> createServiceRequest({
    required ServiceRequestType type,
    required String description,
    required String preferredDate,
    required String preferredTime,
    required ServiceContactMethod contactMethod,
    String? phoneNumber,
    List<File>? attachments,
  }) async {
    try {
      _loggingService.info('Creating service request', {
        'type': type.toString(),
        'hasAttachments': attachments?.isNotEmpty ?? false,
      });

      // Проверка авторизации
      final userData = _authService.userData;
      if (userData == null || !_authService.isAuthenticated) {
        throw ServiceRequestException('Требуется авторизация');
      }

      // Проверка выбранной квартиры
      final apartment = _authService.verifiedApartment;
      if (apartment == null) {
        throw ServiceRequestException('Не выбрана квартира');
      }

      // Генерируем ID заявки
      final requestId = 'SR_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}';

      // Загружаем вложения если есть (пока заглушка)
      List<String>? attachmentUrls;
      if (attachments != null && attachments.isNotEmpty) {
        attachmentUrls = attachments.map((f) => 'uploaded_${f.path}').toList();
      }

      // Подготавливаем данные заявки
      final requestData = {
        'requestId': requestId,
        'userId': userData['uid'] ?? userData['id'] ?? 'unknown',
        'apartmentId': apartment.id,
        'apartmentNumber': apartment.apartmentNumber,
        'blockId': apartment.blockId,
        'requestType': type.toString().split('.').last,
        'description': description,
        'preferredDate': preferredDate,
        'preferredTime': preferredTime,
        'contactMethod': contactMethod.toString().split('.').last,
        'contactPhone': phoneNumber ?? apartment.phone,
        'status': 'pending',
        'priority': _calculatePriority(type),
        'attachments': attachmentUrls ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'metadata': {
          'platform': Platform.operatingSystem,
          'appVersion': '1.0.0', // Получить из package info
          'locale': 'ru',
        },
      };

      // Пытаемся создать напрямую
      try {
        await _firestore
            .collection('serviceRequests')
            .doc(requestId)
            .set(requestData);

        _loggingService.info('Service request created online', {
          'requestId': requestId,
        });

        // Отправляем уведомление (заглушка)
        _loggingService.info('Would notify admin about new request', {'requestId': requestId});

        return ServiceRequestResult(
          success: true,
          requestId: requestId,
          message: 'Заявка успешно создана',
        );

      } catch (e) {
        // Если не удалось создать онлайн, добавляем в offline очередь
        _loggingService.warning('Failed to create request online, queueing offline', {
          'error': e.toString(),
        });

        final operationId = await _offlineQueue.enqueue(
          OfflineOperation(
            type: OperationType.createServiceRequest,
            method: 'POST',
            endpoint: '/serviceRequests/$requestId',
            data: requestData,
          ),
        );

        return ServiceRequestResult(
          success: true,
          requestId: requestId,
          operationId: operationId,
          isOffline: true,
          message: 'Заявка сохранена и будет отправлена при подключении',
        );
      }
    } catch (e) {
      _loggingService.error('Failed to create service request', e);
      throw ServiceRequestException('Не удалось создать заявку: ${e.toString()}');
    }
  }

  /// Получение списка заявок пользователя
  Stream<List<ServiceRequest>> getUserRequests() {
    final userData = _authService.userData;
    final userId = userData?['uid'] ?? userData?['id'];
    if (userId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('serviceRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ServiceRequest.fromFirestore(data, doc.id);
      }).toList();
    });
  }

  /// Отмена заявки
  Future<bool> cancelRequest(String requestId) async {
    try {
      // Проверяем можно ли отменить
      final doc = await _firestore
          .collection('serviceRequests')
          .doc(requestId)
          .get();

      if (!doc.exists) {
        throw ServiceRequestException('Заявка не найдена');
      }

      final data = doc.data()!;
      
      // Проверка владельца
      final userData = _authService.userData;
      final currentUserId = userData?['uid'] ?? userData?['id'];
      if (data['userId'] != currentUserId) {
        throw ServiceRequestException('Нет прав для отмены этой заявки');
      }

      // Проверка статуса
      if (data['status'] != 'pending') {
        throw ServiceRequestException('Можно отменить только ожидающие заявки');
      }

      // Отмена
      await _firestore
          .collection('serviceRequests')
          .doc(requestId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': 'Отменено пользователем',
      });

      _loggingService.info('Service request cancelled', {
        'requestId': requestId,
      });

      return true;

    } catch (e) {
      _loggingService.error('Failed to cancel request', e);
      
      if (e is ServiceRequestException) {
        rethrow;
      }
      
      throw ServiceRequestException('Не удалось отменить заявку');
    }
  }



  /// Расчет приоритета заявки
  String _calculatePriority(ServiceRequestType type) {
    switch (type) {
      case ServiceRequestType.emergency:
      case ServiceRequestType.waterLeak:
      case ServiceRequestType.electricalIssue:
        return 'high';
      case ServiceRequestType.repair:
      case ServiceRequestType.plumbing:
        return 'medium';
      case ServiceRequestType.cleaning:
      case ServiceRequestType.other:
        return 'low';
    }
  }

  /// Проверка статуса offline операции
  Future<OperationStatus?> checkOfflineStatus(String operationId) async {
    return _offlineQueue.getOperationStatus(operationId);
  }

  /// Повторная отправка заявки
  Future<void> retryOfflineRequest(String operationId) async {
    // Offline queue автоматически обработает при подключении
    _loggingService.info('Retry requested for offline operation', {
      'operationId': operationId,
    });
  }

  /// Получение статистики offline очереди
  Map<String, dynamic> getOfflineStatistics() {
    return _offlineQueue.getStatistics();
  }
}

/// Результат создания заявки
class ServiceRequestResult {
  final bool success;
  final String? requestId;
  final String? operationId;
  final bool isOffline;
  final String message;

  ServiceRequestResult({
    required this.success,
    this.requestId,
    this.operationId,
    this.isOffline = false,
    required this.message,
  });
}

/// Исключение сервиса заявок
class ServiceRequestException implements Exception {
  final String message;

  ServiceRequestException(this.message);

  @override
  String toString() => message;
}

/// Расширение для отображения статуса offline операции
extension OperationStatusExtension on OperationStatus {
  String get displayText {
    switch (this) {
      case OperationStatus.pending:
        return 'Ожидает отправки';
      case OperationStatus.processing:
        return 'Отправляется...';
      case OperationStatus.completed:
        return 'Отправлено';
      case OperationStatus.failed:
        return 'Ошибка отправки';
    }
  }

  Color get displayColor {
    switch (this) {
      case OperationStatus.pending:
        return Colors.orange;
      case OperationStatus.processing:
        return Colors.blue;
      case OperationStatus.completed:
        return Colors.green;
      case OperationStatus.failed:
        return Colors.red;
    }
  }
}
