import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:newport_resident/core/services/news_service.dart';
import 'package:newport_resident/core/services/api_service.dart';
import 'package:newport_resident/core/services/cache_service.dart';
import 'package:newport_resident/core/services/logging_service_secure.dart';
import 'package:newport_resident/core/services/connectivity_service.dart';


// Generate mocks
@GenerateMocks([ApiService, CacheService, LoggingService, ConnectivityService])
import 'news_service_test.mocks.dart';

void main() {
  group('NewsService', () {
    late NewsService newsService;
    late MockApiService mockApiService;
    late MockCacheService mockCacheService;
    late MockLoggingService mockLoggingService;
    late MockConnectivityService mockConnectivityService;

    setUp(() {
      mockApiService = MockApiService();
      mockCacheService = MockCacheService();
      mockLoggingService = MockLoggingService();
      mockConnectivityService = MockConnectivityService();
      
      // Set up default connectivity behavior
      when(mockConnectivityService.isConnected).thenReturn(true);
      when(mockConnectivityService.executeWithRetry<List<dynamic>>(
        operation: anyNamed('operation'),
        maxRetries: anyNamed('maxRetries'),
      )).thenAnswer((invocation) async {
        final operation = invocation.namedArguments[#operation] as Future<List<dynamic>> Function();
        return await operation();
      });
      
      newsService = NewsService(
        apiService: mockApiService,
        cacheService: mockCacheService,
        loggingService: mockLoggingService,
        connectivityService: mockConnectivityService,
      );
    });

    group('fetchLatestNews', () {
      test('should return cached news when available and not force refresh', () async {
        // Arrange
        final cachedData = [
          {
            'id': '1',
            'title': 'Test News',
            'preview': 'Test preview',
            'content': 'Test content',
            'publishedAt': DateTime.now().toIso8601String(),
            'isImportant': false,
          }
        ];
        
        when(mockCacheService.get<List<dynamic>>('latest_news'))
            .thenAnswer((_) async => cachedData);

        // Act
        final result = await newsService.fetchLatestNews();

        // Assert
        expect(result, hasLength(1));
        expect(result.first.title, 'Test News');
        verify(mockCacheService.get<List<dynamic>>('latest_news')).called(1);
        verifyNever(mockCacheService.set(any, any, expiration: anyNamed('expiration')));
      });

      test('should fetch from remote when cache is empty', () async {
        // Arrange
        when(mockCacheService.get<List<dynamic>>('latest_news'))
            .thenAnswer((_) async => null);
        when(mockCacheService.set(any, any, expiration: anyNamed('expiration')))
            .thenAnswer((_) async {});

        // Act
        final result = await newsService.fetchLatestNews();

        // Assert
        expect(result, hasLength(3)); // Mock data has 3 items
        expect(result.first.title, 'Плановое отключение воды');
        verify(mockCacheService.get<List<dynamic>>('latest_news')).called(1);
        verify(mockCacheService.set(any, any, expiration: anyNamed('expiration'))).called(1);
      });

      test('should force refresh when forceRefresh is true', () async {
        // Arrange
        when(mockCacheService.set(any, any, expiration: anyNamed('expiration')))
            .thenAnswer((_) async {});

        // Act
        final result = await newsService.fetchLatestNews(forceRefresh: true);

        // Assert
        expect(result, hasLength(3));
        verifyNever(mockCacheService.get<List<dynamic>>('latest_news'));
        verify(mockCacheService.set(any, any, expiration: anyNamed('expiration'))).called(1);
      });

      test('should return empty list and log error when fetch fails', () async {
        // Arrange
        when(mockCacheService.get<List<dynamic>>('latest_news'))
            .thenThrow(Exception('Cache error'));

        // Act
        final result = await newsService.fetchLatestNews();

        // Assert
        expect(result, isEmpty);
        verify(mockLoggingService.error(any, any, any)).called(1);
      });
    });

    group('fetchNewsById', () {
      test('should return news article when found', () async {
        // Arrange
        when(mockCacheService.get<List<dynamic>>('latest_news'))
            .thenAnswer((_) async => null);
        when(mockCacheService.set(any, any, expiration: anyNamed('expiration')))
            .thenAnswer((_) async {});

        // Act
        final result = await newsService.fetchNewsById('1');

        // Assert
        expect(result, isNotNull);
        expect(result!.id, '1');
        expect(result.title, 'Плановое отключение воды');
      });

      test('should return null when news not found', () async {
        // Arrange
        when(mockCacheService.get<List<dynamic>>('latest_news'))
            .thenAnswer((_) async => null);
        when(mockCacheService.set(any, any, expiration: anyNamed('expiration')))
            .thenAnswer((_) async {});

        // Act
        final result = await newsService.fetchNewsById('999');

        // Assert
        expect(result, isNull);
      });
    });
  });
} 