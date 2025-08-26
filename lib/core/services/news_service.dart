import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';

import '../../core/models/news_article_model.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

/// Service responsible for retrieving community news.
/// Integrates with Firestore for real-time news updates with offline caching.
class NewsService {
  static const String _cacheKey = 'latest_news';
  static const Duration _cacheDuration = Duration(minutes: 30);


  final ApiService apiService;
  final CacheService cacheService;
  final LoggingService loggingService;
  final ConnectivityService connectivityService;
  late final FirebaseFirestore _firestore;
  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      return null;
    }
  }

  NewsService({
    required this.apiService,
    required this.cacheService,
    required this.loggingService,
    required this.connectivityService,
  }) {
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  /// Returns the most recent list of news, using cache when possible.
  Future<List<NewsArticle>> fetchLatestNews({bool forceRefresh = false}) async {
    try {
      // First try to return cached data if available and not forced to refresh
      if (!forceRefresh) {
        try {
          final cachedJson = await cacheService.get<List<dynamic>>(_cacheKey);
          if (cachedJson != null) {
            loggingService.info('Returning cached news data');
            return cachedJson.map((e) {
              if (e is Map) {
                return NewsArticle.fromJson(Map<String, dynamic>.from(e));
              }
              throw ArgumentError('Invalid cached news item format');
            }).toList();
          }
        } catch (cacheError) {
          // Clear corrupted cache and continue to fetch fresh data
          loggingService.error('Cache error, clearing and fetching fresh data', cacheError);
          await cacheService.remove(_cacheKey);
        }
      }

      // Check connectivity before attempting network request
      if (!connectivityService.isConnected) {
        loggingService.warning('No internet connection, trying cached data');
        final cachedJson = await cacheService.get<List<dynamic>>(_cacheKey);
        if (cachedJson != null) {
          return cachedJson.map((e) {
            if (e is Map) {
              return NewsArticle.fromJson(Map<String, dynamic>.from(e));
            }
            throw ArgumentError('Invalid cached news item format');
          }).toList();
        }
        throw Exception('No internet connection and no cached data available');
      }

      // Use connectivity service with retry logic
      final news = await connectivityService.executeWithRetry<List<NewsArticle>>(
        operation: () => _fetchFromFirestore(),
        maxRetries: 3,
      );

      // Cache raw maps for offline use
      await cacheService.set(
        _cacheKey,
        news.map((e) => e.toJson()).toList(),
        expiration: _cacheDuration,
      );
      
      loggingService.info('Successfully fetched ${news.length} news articles');
      return news;
    } catch (e, st) {
      loggingService.error('NewsService.fetchLatestNews failed', e, st);
      
      // Try to return cached data as a fallback
      try {
        final cachedJson = await cacheService.get<List<dynamic>>(_cacheKey);
        if (cachedJson != null) {
          loggingService.info('Returning cached data as fallback');
          return cachedJson.map((e) {
            if (e is Map) {
              return NewsArticle.fromJson(Map<String, dynamic>.from(e));
            }
            throw ArgumentError('Invalid cached news item format');
          }).toList();
        }
      } catch (cacheError) {
        loggingService.error('Failed to get cached data as fallback', cacheError);
      }
      
      // As a last resort, return mock data for development
      return await _getMockNewsForDevelopment();
    }
  }

  /// Fetch news with pagination support
  Future<List<NewsArticle>> fetchNewsWithPagination({
    DocumentSnapshot? startAfterDocument,
    int limit = 20,
  }) async {
    try {
      return await _fetchFromFirestore(
        startAfterDocument: startAfterDocument,
        limit: limit,
      );
    } catch (e, st) {
      loggingService.error('NewsService.fetchNewsWithPagination failed', e, st);
      return [];
    }
  }

  /// Get single news article by id (search cached list first, then remote).
  Future<NewsArticle?> fetchNewsById(String id) async {
    // First try to find in cached list
    final all = await fetchLatestNews();
    try {
      final localMatch = all.firstWhere((element) => element.id == id);
      return localMatch;
    } catch (e) {
      // If not found in cache, try to fetch directly from Firestore
      return await _fetchNewsFromFirestoreById(id);
    }
  }

  /// Get a stream of news updates for real-time UI
  Stream<List<NewsArticle>> getNewsStream({int limit = 20}) {
    try {
      final userBlockId = _authService?.userData?['blockId'];
      
      Query query = _firestore.collection('news')
          .where('status', isEqualTo: 'published')
          .where('publishedAt', isLessThanOrEqualTo: Timestamp.now())
          .orderBy('publishedAt', descending: true)
          .limit(limit);

      // Filter by user's block if authenticated
      if (userBlockId != null) {
        query = query.where('targetBlocks', arrayContainsAny: [userBlockId, 'all']);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return NewsArticle.fromJson(data);
        }).toList();
      });
    } catch (e, st) {
      loggingService.error('NewsService.getNewsStream failed', e, st);
      return Stream.value([]);
  }
  }

  /// Get news stream (alias for getNewsStream)
  Stream<List<NewsArticle>> get newsStream => getNewsStream();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Fetch news from Firestore with optional pagination
  Future<List<NewsArticle>> _fetchFromFirestore({
    DocumentSnapshot? startAfterDocument,
    int limit = 20,
  }) async {
    try {
      final userBlockId = _authService?.userData?['blockId'];
      
      Query query = _firestore.collection('news')
          .where('status', isEqualTo: 'published')
          .where('publishedAt', isLessThanOrEqualTo: Timestamp.now())
          .orderBy('publishedAt', descending: true);

      // Filter by user's block if authenticated
      if (userBlockId != null) {
        query = query.where('targetBlocks', arrayContainsAny: [userBlockId, 'all']);
      }

      // Add pagination
      if (startAfterDocument != null) {
        query = query.startAfterDocument(startAfterDocument);
      }
      
      query = query.limit(limit);

      final snapshot = await query.get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return NewsArticle.fromJson(data);
      }).toList();
    } catch (e, st) {
      loggingService.error('_fetchFromFirestore failed', e, st);
      rethrow;
    }
  }

  /// Fetch single news article by ID from Firestore
  Future<NewsArticle?> _fetchNewsFromFirestoreById(String id) async {
    try {
      final doc = await _firestore.collection('news').doc(id).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return NewsArticle.fromJson(data);
    } catch (e, st) {
      loggingService.error('_fetchNewsFromFirestoreById failed', e, st);
      return null;
    }
  }

  /// Fallback mock data for development when Firestore is not available
  Future<List<NewsArticle>> _getMockNewsForDevelopment() async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));

    final now = DateTime.now();
    return [
      NewsArticle(
        id: 'mock-1',
        title: 'Плановое отключение воды',
        preview: '15 декабря с 10:00 до 16:00 будет отключена вода...',
        content:
            'Уважаемые жители! В связи с плановыми работами по обслуживанию водоснабжения 15 декабря с 10:00 до 16:00 будет временно отключена подача воды во всём комплексе.',
        imageUrl: null,
        publishedAt: now.subtract(const Duration(hours: 2)),
        isImportant: true,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        ctaLabels: ['Подробнее', 'Контакты'],
        ctaLinks: ['/service-request?type=water', 'tel:+998901234567'],
        ctaType: 'internal',
      ),
      NewsArticle(
        id: 'mock-2',
        title: 'Новогодние мероприятия',
        preview: 'Приглашаем всех жителей на новогодний праздник...',
        content:
            'С нетерпением ждём вас 24 декабря на площади перед блоком C. Обещаем тёплую атмосферу, угощения и праздник для детей!',
        imageUrl: null,
        publishedAt: now.subtract(const Duration(days: 1)),
        isImportant: false,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
        ctaLabels: ['Записаться'],
        ctaLinks: ['https://newport.uz/events/new-year'],
        ctaType: 'external',
      ),
      NewsArticle(
        id: 'mock-3',
        title: 'Обновление приложения',
        preview: 'Мы выпустили новую версию приложения с поддержкой новостей!',
        content:
            'Спасибо, что пользуетесь Newport Resident. В версии 1.2 добавлен раздел «Новости», улучшена производительность и исправлены ошибки.',
        imageUrl: null,
        publishedAt: now.subtract(const Duration(days: 2)),
        isImportant: false,
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
  }
} 