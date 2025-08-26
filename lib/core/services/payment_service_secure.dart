import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';


import 'auth_service.dart';
import 'logging_service_secure.dart';

/// Безопасный сервис для работы с платежами через серверный API
/// НЕ собирает карточные данные, работает только через Payme Checkout
class PaymentService {
  final AuthService authService;
  final LoggingService loggingService;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  PaymentService({
    required this.authService,
    required this.loggingService,
  });
  
  /// Создание платежа
  Future<PaymentResult> createPayment({
    required double amount,
    String? description,
  }) async {
    try {
      loggingService.info('Creating payment: amount=$amount');
      
      // Проверка авторизации и выбранной квартиры
      if (!authService.isAuthenticated) {
        throw PaymentException('Требуется авторизация');
      }
      
      final apartment = authService.verifiedApartment;
      if (apartment == null) {
        throw PaymentException('Не выбрана квартира для оплаты');
      }
      
      // Валидация суммы на клиенте
      if (amount < 1000) {
        throw PaymentException('Минимальная сумма платежа: 1000 сум');
      }
      
      if (amount > 10000000) {
        throw PaymentException('Максимальная сумма платежа: 10 000 000 сум');
      }
      
      // Вызов защищенной Cloud Function
      final callable = _functions.httpsCallable('createPayment');
      final result = await callable.call({
        'amount': amount,
        'description': description ?? 'Оплата коммунальных услуг',
        'apartmentId': apartment.id,
      });
      
      if (result.data['success'] == true) {
        loggingService.info('Payment created successfully: ${result.data['paymentId']}');
        
        return PaymentResult(
          success: true,
          paymentId: result.data['paymentId'],
          checkoutUrl: result.data['checkoutUrl'],
          message: result.data['message'],
        );
      } else {
        throw PaymentException('Не удалось создать платеж');
      }
      
    } on FirebaseFunctionsException catch (e) {
      loggingService.error('Payment creation failed', e);
      
      switch (e.code) {
        case 'unauthenticated':
          throw PaymentException('Требуется повторная авторизация');
        case 'permission-denied':
          throw PaymentException('У вас нет прав для оплаты по этой квартире');
        case 'invalid-argument':
          throw PaymentException(e.message ?? 'Неверные данные платежа');
        default:
          throw PaymentException('Ошибка создания платежа: ${e.message}');
      }
    } catch (e) {
      loggingService.error('Unexpected payment error', e);
      throw PaymentException('Произошла ошибка. Попробуйте позже.');
    }
  }
  
  /// Открытие страницы оплаты в Payme
  Future<bool> openPaymentCheckout(String checkoutUrl) async {
    try {
      final uri = Uri.parse(checkoutUrl);
      
      // Проверка что это действительно Payme URL
      if (!uri.host.contains('paycom.uz') && !uri.host.contains('payme.uz')) {
        loggingService.warning('Invalid checkout URL: $checkoutUrl');
        throw PaymentException('Неверная ссылка для оплаты');
      }
      
      // Открываем в браузере или приложении Payme
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        throw PaymentException('Не удалось открыть страницу оплаты');
      }
    } catch (e) {
      loggingService.error('Failed to open checkout', e);
      return false;
    }
  }
  
  /// Получение истории платежей
  Future<List<PaymentHistory>> getPaymentHistory({
    String? apartmentId,
    int limit = 20,
  }) async {
    try {
      final callable = _functions.httpsCallable('getPaymentHistory');
      final result = await callable.call({
        'apartmentId': apartmentId,
        'limit': limit,
      });
      
      if (result.data['success'] == true) {
        final List<dynamic> paymentsData = result.data['payments'] ?? [];
        
        return paymentsData
            .map((data) => PaymentHistory.fromJson(data))
            .toList();
      }
      
      return [];
    } on FirebaseFunctionsException catch (e) {
      loggingService.error('Failed to get payment history', e);
      return [];
    }
  }
  
  /// Получение текущей задолженности
  Future<DebtInfo?> getCurrentDebt() async {
    try {
      final apartment = authService.verifiedApartment;
      if (apartment == null) return null;
      
      // В реальном приложении это должно приходить с сервера
      // Сейчас возвращаем моковые данные
      return DebtInfo(
        currentDebt: 850000,
        overdueAmount: 0,
        services: [
          ServiceDebt(name: 'Коммунальные услуги', amount: 650000),
          ServiceDebt(name: 'Интернет', amount: 100000),
          ServiceDebt(name: 'Охрана', amount: 100000),
        ],
        dueDate: DateTime.now().add(const Duration(days: 7)),
        isOverdue: false,
      );
    } catch (e) {
      loggingService.error('Failed to get current debt', e);
      return null;
    }
  }
  
  /// Проверка статуса платежа (для обновления UI после возврата из Payme)
  Future<PaymentStatus?> checkPaymentStatus(String paymentId) async {
    try {
      // В реальном приложении нужно вызвать серверную функцию
      // для проверки статуса через Payme API
      
      // Пока возвращаем заглушку
      await Future.delayed(const Duration(seconds: 2));
      
      return PaymentStatus(
        paymentId: paymentId,
        status: 'completed',
        amount: 850000,
        completedAt: DateTime.now(),
      );
    } catch (e) {
      loggingService.error('Failed to check payment status', e);
      return null;
    }
  }
}

/// Результат создания платежа
class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? checkoutUrl;
  final String? message;
  
  PaymentResult({
    required this.success,
    this.paymentId,
    this.checkoutUrl,
    this.message,
  });
}

/// История платежей
class PaymentHistory {
  final String paymentId;
  final double amount;
  final String description;
  final String status;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? apartmentNumber;
  final String? blockId;
  
  PaymentHistory({
    required this.paymentId,
    required this.amount,
    required this.description,
    required this.status,
    this.createdAt,
    this.completedAt,
    this.apartmentNumber,
    this.blockId,
  });
  
  factory PaymentHistory.fromJson(Map<String, dynamic> json) {
    return PaymentHistory(
      paymentId: json['paymentId'],
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] ?? '',
      status: json['status'] ?? 'unknown',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      apartmentNumber: json['apartmentNumber'],
      blockId: json['blockId'],
    );
  }
  
  String get statusText {
    switch (status) {
      case 'pending':
        return 'Ожидает оплаты';
      case 'processing':
        return 'Обрабатывается';
      case 'completed':
        return 'Оплачено';
      case 'cancelled':
        return 'Отменено';
      default:
        return 'Неизвестно';
    }
  }
  
  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Информация о задолженности
class DebtInfo {
  final double currentDebt;
  final double overdueAmount;
  final List<ServiceDebt> services;
  final DateTime dueDate;
  final bool isOverdue;
  
  DebtInfo({
    required this.currentDebt,
    required this.overdueAmount,
    required this.services,
    required this.dueDate,
    required this.isOverdue,
  });
}

/// Задолженность по услуге
class ServiceDebt {
  final String name;
  final double amount;
  
  ServiceDebt({
    required this.name,
    required this.amount,
  });
}

/// Статус платежа
class PaymentStatus {
  final String paymentId;
  final String status;
  final double amount;
  final DateTime? completedAt;
  
  PaymentStatus({
    required this.paymentId,
    required this.status,
    required this.amount,
    this.completedAt,
  });
}

/// Исключение платежа
class PaymentException implements Exception {
  final String message;
  
  PaymentException(this.message);
  
  @override
  String toString() => message;
}
