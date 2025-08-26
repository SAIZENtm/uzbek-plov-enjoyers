import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _analytics.setAnalyticsCollectionEnabled(!kDebugMode);
    _initialized = true;
  }

  // User Properties
  Future<void> setUserProperties({
    required String userId,
    required String apartmentNumber,
    String? buildingNumber,
  }) async {
    await _analytics.setUserId(id: userId);
    await _analytics.setUserProperty(
      name: 'apartment_number',
      value: apartmentNumber,
    );
    if (buildingNumber != null) {
      await _analytics.setUserProperty(
        name: 'building_number',
        value: buildingNumber,
      );
    }
  }

  // Screen Tracking
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('Failed to log screen view: $e');
    }
  }

  // Authentication Events
  Future<void> logLogin({
    required String method,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('Failed to log login: $e');
    }
  }

  Future<void> logSignUp({
    required String method,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e) {
      debugPrint('Failed to log sign up: $e');
    }
  }

  // Service Request Events
  Future<void> logServiceRequest({
    required String type,
    required String priority,
    bool hasPhoto = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'service_request',
        parameters: {
          'type': type,
          'priority': priority,
          'has_photo': hasPhoto,
        },
      );
    } catch (e) {
      debugPrint('Failed to log service request: $e');
    }
  }

  // Payment Events
  Future<void> logPayment({
    required String paymentType,
    required double amount,
    required String currency,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment',
        parameters: {
          'payment_type': paymentType,
          'amount': amount,
          'currency': currency,
        },
      );
    } catch (e) {
      debugPrint('Failed to log payment: $e');
    }
  }

  // Feature Usage Events
  Future<void> logFeatureUse({
    required String featureName,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: 'feature_use',
      parameters: {
        'feature_name': featureName,
        if (parameters != null) ...parameters.cast<String, Object>(),
      },
    );
  }

  // Error Events
  Future<void> logError({
    required String errorCode,
    required String errorMessage,
    StackTrace? stackTrace,
  }) async {
    await _analytics.logEvent(
      name: 'app_error',
      parameters: {
        'error_code': errorCode,
        'error_message': errorMessage,
        if (stackTrace != null) 'stack_trace': stackTrace.toString(),
      },
    );
  }

  // Performance Events
  Future<void> logPerformanceEvent({
    required String eventName,
    required int durationMillis,
    Map<String, dynamic>? additionalParams,
  }) async {
    await _analytics.logEvent(
      name: 'performance_event',
      parameters: {
        'event_name': eventName,
        'duration_ms': durationMillis,
        if (additionalParams != null) ...additionalParams.cast<String, Object>(),
      },
    );
  }

  // Custom Events
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    await _analytics.logEvent(
      name: eventName,
      parameters: parameters?.cast<String, Object>(),
    );
  }

  // Session Management
  Future<void> startSession() async {
    await _analytics.logEvent(name: 'session_start');
  }

  Future<void> endSession() async {
    await _analytics.logEvent(name: 'session_end');
  }

  // Debug Events (only in debug mode)
  Future<void> logDebugEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    if (kDebugMode) {
      await _analytics.logEvent(
        name: 'debug_$eventName',
        parameters: parameters?.cast<String, Object>(),
      );
    }
  }

  Future<void> logUtilityReading({
    required String meterType,
    required double reading,
    bool hasPhoto = false,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'utility_reading',
        parameters: {
          'meter_type': meterType,
          'reading': reading,
          'has_photo': hasPhoto,
        },
      );
    } catch (e) {
      debugPrint('Failed to log utility reading: $e');
    }
  }

  NavigatorObserver getAnalyticsObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }
} 