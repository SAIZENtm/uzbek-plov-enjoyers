import 'dart:async';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'logging_service_secure.dart';

class ConnectivityService extends ChangeNotifier {
  final LoggingService _loggingService;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  ConnectivityResult _connectionStatus = ConnectivityResult.none;
  bool _isConnected = false;
  Timer? _retryTimer;
  
  // Retry configuration
  static const int _maxRetries = 5;
  static const int _baseDelayMs = 1000;
  
  ConnectivityService({required LoggingService loggingService}) 
      : _loggingService = loggingService {
    _initializeConnectivity();
  }
  
  // Getters
  bool get isConnected => _isConnected;
  ConnectivityResult get connectionStatus => _connectionStatus;
  String get connectionType => _getConnectionTypeString(_connectionStatus);
  bool get hasInternetConnection => _isConnected && _connectionStatus != ConnectivityResult.none;
  
  Future<void> _initializeConnectivity() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _isConnected = _connectionStatus != ConnectivityResult.none;
      
      _loggingService.info('Initial connectivity status: ${_getConnectionTypeString(_connectionStatus)}');
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          _loggingService.error('Connectivity subscription error: $error');
        },
      );
      
      notifyListeners();
    } catch (e) {
      _loggingService.error('Failed to initialize connectivity: $e');
    }
  }
  
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasConnected = _isConnected;
    _connectionStatus = result;
    _isConnected = result != ConnectivityResult.none;
    
    _loggingService.info('Connectivity changed: ${_getConnectionTypeString(result)}');
    
         // Reset retry counter on successful connection
     if (_isConnected && !wasConnected) {
       _retryTimer?.cancel();
       _loggingService.info('Connection restored');
     }
    
    // Log connection loss
    if (!_isConnected && wasConnected) {
      _loggingService.info('Connection lost');
    }
    
    notifyListeners();
  }
  
  String _getConnectionTypeString(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.none:
        return 'No Connection';
      default:
        return 'Unknown';
    }
  }
  
  /// Execute a network operation with retry logic
  Future<T> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = _maxRetries,
    Duration baseDelay = const Duration(milliseconds: _baseDelayMs),
  }) async {
    int attempt = 0;
    
    while (attempt < maxRetries) {
      try {
        // Check connectivity before attempting
        if (!_isConnected) {
          throw Exception('No internet connection');
        }
        
        final result = await operation();
        
        // Reset retry counter on success
        if (attempt > 0) {
          _loggingService.info('Network operation succeeded after $attempt retries');
        }
        
        return result;
      } catch (e) {
        attempt++;
        
        _loggingService.error('Network operation failed (attempt $attempt/$maxRetries): $e');
        
        if (attempt >= maxRetries) {
          _loggingService.error('Max retries reached, giving up');
          rethrow;
        }
        
        // Exponential backoff with jitter
        final delayMs = (baseDelay.inMilliseconds * pow(2, attempt - 1)).toInt();
        final jitter = Random().nextInt(1000);
        final totalDelay = Duration(milliseconds: delayMs + jitter);
        
        _loggingService.info('Retrying in ${totalDelay.inMilliseconds}ms');
        await Future.delayed(totalDelay);
      }
    }
    
    throw Exception('Network operation failed after $maxRetries attempts');
  }
  
  /// Check if we have a working internet connection
  Future<bool> hasWorkingConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      _loggingService.error('Failed to check connectivity: $e');
      return false;
    }
  }
  
  /// Force refresh connectivity status
  Future<void> refreshConnectivity() async {
    try {
      _connectionStatus = await _connectivity.checkConnectivity();
      _isConnected = _connectionStatus != ConnectivityResult.none;
      
      _loggingService.info('Connectivity refreshed: ${_getConnectionTypeString(_connectionStatus)}');
      notifyListeners();
    } catch (e) {
      _loggingService.error('Failed to refresh connectivity: $e');
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
} 