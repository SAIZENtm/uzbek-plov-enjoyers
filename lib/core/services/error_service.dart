import 'package:flutter/material.dart';
import 'logging_service_secure.dart';

class ErrorService {
  final LoggingService loggingService;

  ErrorService({required this.loggingService});

  void handleError(dynamic error, [StackTrace? stackTrace]) {
    loggingService.error('An error occurred', error, stackTrace);
  }

  Future<T> wrapFuture<T>({
    required Future<T> Function() future,
    required BuildContext context,
    String? loadingMessage,
    String? errorMessage,
  }) async {
    try {
      if (loadingMessage != null) {
        showLoadingDialog(context, loadingMessage);
      }
      
      final result = await future();
      
      if (loadingMessage != null) {
        if (!context.mounted) return result;
        Navigator.of(context).pop(); // Remove loading dialog
      }
      
      return result;
    } catch (e, stackTrace) {
      if (loadingMessage != null) {
        if (!context.mounted) rethrow;
        Navigator.of(context).pop(); // Remove loading dialog
      }
      
      handleError(e, stackTrace);
      
      if (!context.mounted) rethrow;
      showErrorDialog(
        context,
        errorMessage ?? 'Произошла ошибка. Пожалуйста, попробуйте позже.',
      );
      
      rethrow;
    }
  }

  void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String getErrorMessage(dynamic error) {
    if (error is NetworkError) {
      return 'Ошибка сети. Проверьте подключение к интернету.';
    } else if (error is AuthenticationError) {
      return 'Ошибка авторизации. Пожалуйста, войдите снова.';
    } else if (error is ValidationError) {
      return error.message;
    } else {
      return 'Произошла ошибка. Пожалуйста, попробуйте позже.';
    }
  }

  Future<void> showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    showErrorDialog(context, message);
  }

  Future<void> showWarning(BuildContext context, String message) async {
    if (!context.mounted) return;
    // ... existing code ...
  }

  Future<void> showSuccess(BuildContext context, String message) async {
    if (!context.mounted) return;
    // ... existing code ...
  }
}

class NetworkError implements Exception {
  final String message;
  NetworkError([this.message = 'Network error occurred']);
}

class AuthenticationError implements Exception {
  final String message;
  AuthenticationError([this.message = 'Authentication error occurred']);
}

class ValidationError implements Exception {
  final String message;
  ValidationError(this.message);
} 