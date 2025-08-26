import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import './logging_service_secure.dart';

class MonitoringService {
  final LoggingService loggingService;
  FirebaseCrashlytics? _crashlytics;
  FirebasePerformance? _performance;
  final Map<String, Trace> _activeTraces = {};
  bool _isInitialized = false;

  MonitoringService({required this.loggingService});

  Future<void> initialize() async {
    if (_isInitialized) {
      loggingService.warning('MonitoringService already initialized');
      return;
    }

    try {
      _crashlytics = FirebaseCrashlytics.instance;
      _performance = FirebasePerformance.instance;

      if (_crashlytics != null) {
        await _crashlytics!.setCrashlyticsCollectionEnabled(!kDebugMode);
      }
      
      if (_performance != null) {
        await _performance!.setPerformanceCollectionEnabled(!kDebugMode);
      }
      
      _isInitialized = true;
      loggingService.info('MonitoringService initialized successfully');
    } catch (e, stackTrace) {
      loggingService.error(
        'Failed to initialize MonitoringService',
        e,
        stackTrace,
      );
      // Don't rethrow the error, just log it
      // This allows the app to continue even if monitoring fails
    }
  }

  // Crash Reporting
  void recordError(dynamic error, StackTrace stackTrace, {String? reason}) {
    try {
      _crashlytics?.recordError(
        error,
        stackTrace,
        reason: reason,
      );
    } catch (e) {
      loggingService.error('Failed to record error', e);
    }
  }

  Future<void> setUserIdentifier(String identifier) async {
    try {
      await _crashlytics?.setUserIdentifier(identifier);
    } catch (e) {
      loggingService.error('Failed to set user identifier', e);
    }
  }

  void setCustomKey(String key, dynamic value) {
    try {
      _crashlytics?.setCustomKey(key, value);
    } catch (e) {
      loggingService.error('Failed to set custom key', e);
    }
  }

  void log(String message) {
    try {
      _crashlytics?.log(message);
    } catch (e) {
      loggingService.error('Failed to log message', e);
    }
  }

  // Performance Monitoring
  Future<void> startTrace(String name) async {
    try {
      if (_activeTraces.containsKey(name)) {
        loggingService.warning('Trace $name already exists');
        return;
      }
      if (_performance != null) {
        final trace = _performance!.newTrace(name);
        await trace.start();
        _activeTraces[name] = trace;
      }
    } catch (e) {
      loggingService.error('Failed to start trace', e);
    }
  }

  Future<void> stopTrace(String name) async {
    try {
      final trace = _activeTraces[name];
      if (trace == null) {
        loggingService.warning('No active trace found for $name');
        return;
      }
      await trace.stop();
      _activeTraces.remove(name);
    } catch (e) {
      loggingService.error('Failed to stop trace', e);
    }
  }

  Future<void> addTraceAttribute(String traceName, String attribute, String value) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        loggingService.warning('No active trace found for $traceName');
        return;
      }
      trace.putAttribute(attribute, value);
    } catch (e) {
      loggingService.error('Failed to add trace attribute', e);
    }
  }

  Future<void> incrementTraceMetric(String traceName, String metricName, int incrementBy) async {
    try {
      final trace = _activeTraces[traceName];
      if (trace == null) {
        loggingService.warning('No active trace found for $traceName');
        return;
      }
      trace.incrementMetric(metricName, incrementBy);
    } catch (e) {
      loggingService.error('Failed to increment trace metric', e);
    }
  }

  // Network Performance Monitoring
  HttpMetric? _activeHttpMetric;

  Future<void> startHttpMetric(String url, String httpMethod) async {
    try {
      if (_activeHttpMetric != null) {
        loggingService.warning('HTTP metric already active');
        return;
      }
      if (_performance != null) {
        _activeHttpMetric = _performance!.newHttpMetric(url, _getHttpMethod(httpMethod));
        await _activeHttpMetric?.start();
      }
    } catch (e) {
      loggingService.error('Failed to start HTTP metric', e);
    }
  }

  Future<void> stopHttpMetric({int? responseCode, int? requestPayloadSize, int? responsePayloadSize}) async {
    try {
      if (_activeHttpMetric == null) {
        loggingService.warning('No active HTTP metric');
        return;
      }
      if (responseCode != null) {
        _activeHttpMetric?.httpResponseCode = responseCode;
      }
      if (requestPayloadSize != null) {
        _activeHttpMetric?.requestPayloadSize = requestPayloadSize;
      }
      if (responsePayloadSize != null) {
        _activeHttpMetric?.responsePayloadSize = responsePayloadSize;
      }
      await _activeHttpMetric?.stop();
      _activeHttpMetric = null;
    } catch (e) {
      loggingService.error('Failed to stop HTTP metric', e);
    }
  }

  HttpMethod _getHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.Get;
      case 'POST':
        return HttpMethod.Post;
      case 'PUT':
        return HttpMethod.Put;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'PATCH':
        return HttpMethod.Patch;
      case 'OPTIONS':
        return HttpMethod.Options;
      default:
        return HttpMethod.Get;
    }
  }

  // App State Monitoring
  Future<void> logAppState({
    required String state,
    Map<String, dynamic>? additionalData,
  }) async {
    await _crashlytics?.log('App State: $state ${additionalData ?? ''}');
  }

  // Memory Monitoring
  void startMemoryMonitoring() {
    if (!kDebugMode) return;

    // Log memory usage every minute
    Future.doWhile(() async {
      final memoryInfo = await _getMemoryInfo();
      loggingService.debug('Memory Usage: $memoryInfo MB');
      await Future.delayed(const Duration(minutes: 1));
      return true;
    });
  }

  Future<double> _getMemoryInfo() async {
    // This is a placeholder. In a real app, you'd use platform-specific code
    // to get actual memory usage
    return 0.0;
  }

  // Battery Monitoring
  void startBatteryMonitoring() {
    if (!kDebugMode) return;

    // Log battery status every 5 minutes
    Future.doWhile(() async {
      final batteryLevel = await _getBatteryLevel();
      loggingService.debug('Battery Level: $batteryLevel%');
      await Future.delayed(const Duration(minutes: 5));
      return true;
    });
  }

  Future<int> _getBatteryLevel() async {
    // This is a placeholder. In a real app, you'd use platform-specific code
    // to get actual battery level
    return 100;
  }
} 