import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import './error_service.dart';
import './encryption_service.dart';

class ApiService {
  static const String baseUrl = 'https://api.newport-resident.com/v1';
  static const int maxRequestsPerMinute = 60;
  
  final ErrorService errorService;
  final EncryptionService encryptionService;
  final _storage = const FlutterSecureStorage();
  final _dio = Dio();
  final _requestQueue = <DateTime>[];

  ApiService({
    required this.errorService,
    required this.encryptionService,
  }) {
    _initializeInterceptors();
  }

  void _initializeInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Rate limiting
        _enforceRateLimit();

        // Add auth token
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Add API key
        final apiKey = await encryptionService.secureRetrieve('api_key');
        if (apiKey != null) {
          options.headers['X-API-Key'] = apiKey;
        }

        // Add version header
        options.headers['X-App-Version'] = '1.0.0';

        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Handle token refresh
          await _refreshToken();
          // Retry the request
          return handler.resolve(await _retry(e.requestOptions));
        }
        return handler.next(e);
      },
    ));
  }

  void _enforceRateLimit() {
    final now = DateTime.now();
    _requestQueue.add(now);
    
    // Remove requests older than 1 minute
    _requestQueue.removeWhere(
      (time) => now.difference(time) > const Duration(minutes: 1)
    );
    
    if (_requestQueue.length > maxRequestsPerMinute) {
      throw RateLimitExceededException();
    }
  }

  Future<Response<T>> _retry<T>(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    
    return _dio.request<T>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  Future<void> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) throw AuthenticationError();

      final response = await _dio.post(
        '$baseUrl/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        await _storage.write(
          key: 'auth_token',
          value: response.data['access_token'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: response.data['refresh_token'],
        );
      } else {
        throw AuthenticationError();
      }
    } catch (e) {
      errorService.handleError(e);
      throw AuthenticationError();
    }
  }

  // API Methods
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl$endpoint',
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    dynamic data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl$endpoint',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    dynamic data,
    bool requiresAuth = true,
  }) async {
    try {
      final response = await _dio.put(
        '$baseUrl$endpoint',
        data: data,
      );
      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<void> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    try {
      await _dio.delete('$baseUrl$endpoint');
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  void _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw NetworkError('Timeout error occurred');
    }

    if (e.response != null) {
      switch (e.response!.statusCode) {
        case 400:
          throw ValidationError(e.response?.data['message'] ?? 'Validation error');
        case 401:
          throw AuthenticationError('Authentication required');
        case 403:
          throw AuthenticationError('Access denied');
        case 404:
          throw NetworkError('Resource not found');
        case 429:
          throw RateLimitExceededException();
        default:
          throw NetworkError('Network error occurred');
      }
    }

    throw NetworkError('Network error occurred');
  }
}

class RateLimitExceededException implements Exception {
  final String message;
  RateLimitExceededException([this.message = 'Rate limit exceeded']);
} 