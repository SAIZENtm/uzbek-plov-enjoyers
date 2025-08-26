import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'cache_service.dart';
import '../models/news_article_model.dart';

class UnreadTracker extends ChangeNotifier {
  final LoggingService loggingService;
  final CacheService cacheService;
  late final FirebaseFirestore _firestore;
  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      return null;
    }
  }

  Set<String> _readNewsIds = {};
  int _unreadCount = 0;

  UnreadTracker({
    required this.loggingService,
    required this.cacheService,
  }) {
    _firestore = GetIt.instance<FirebaseFirestore>();
    // Don't load immediately, wait for initialization
  }

  // Getters
  Set<String> get readNewsIds => _readNewsIds;
  int get unreadCount => _unreadCount;
  bool isRead(String newsId) => _readNewsIds.contains(newsId);
  bool isUnread(String newsId) => !_readNewsIds.contains(newsId);

  /// Check if specific news article is unread as a stream
  Stream<bool> isUnreadStream(String newsId) {
    return Stream.value(isUnread(newsId));
  }

  /// Initialize UnreadTracker for authenticated user
  Future<void> initializeForUser() async {
    try {
      await _loadReadNewsIds();
      loggingService.info('UnreadTracker initialized for user');
    } catch (e) {
      loggingService.error('Failed to initialize UnreadTracker', e);
    }
  }

  /// Load read news IDs from cache and Firestore
  Future<void> _loadReadNewsIds() async {
    try {
      // Load from cache first (with null check)
      try {
        final cachedIds = await cacheService.get<List<dynamic>>('read_news_ids');
        if (cachedIds != null) {
          _readNewsIds = Set<String>.from(cachedIds);
          notifyListeners();
        }
      } catch (e) {
        loggingService.warning('Cache not available, skipping cache load: $e');
      }

      // Then sync with Firestore
      await _syncWithFirestore();
    } catch (e) {
      loggingService.error('Failed to load read news IDs', e);
    }
  }

  /// Sync read news IDs with Firestore
  Future<void> _syncWithFirestore() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        return;
      }

      final userId = authService.userData?['passportNumber'] ?? 
                     authService.userData?['passport_number'];
      if (userId == null) return;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        final readNewsIds = data?['metadata']?['readNewsIds'] as List<dynamic>?;
        if (readNewsIds != null) {
          _readNewsIds = Set<String>.from(readNewsIds);
          
          // Cache locally (with error handling)
          try {
            await cacheService.set('read_news_ids', _readNewsIds.toList());
          } catch (e) {
            loggingService.warning('Failed to cache read news IDs: $e');
          }
          notifyListeners();
        }
      }
    } catch (e) {
      loggingService.error('Failed to sync with Firestore', e);
    }
  }

  /// Mark news as read
  Future<void> markAsRead(String newsId) async {
    try {
      if (_readNewsIds.contains(newsId)) return;

      _readNewsIds.add(newsId);
      _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      
      // Update cache (with error handling)
      try {
        await cacheService.set('read_news_ids', _readNewsIds.toList());
      } catch (e) {
        loggingService.warning('Failed to update cache: $e');
      }
      
      // Update Firestore
      await _updateFirestore();
      
      notifyListeners();
    } catch (e) {
      loggingService.error('Failed to mark news as read', e);
    }
  }

  /// Update unread count based on news list
  Future<void> updateUnreadCount(List<NewsArticle> allNews) async {
    try {
      final unreadNews = allNews.where((news) => !_readNewsIds.contains(news.id)).toList();
      _unreadCount = unreadNews.length;
      notifyListeners();
    } catch (e) {
      loggingService.error('Failed to update unread count', e);
    }
  }

  /// Update Firestore with current read news IDs
  Future<void> _updateFirestore() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        return;
      }

      final userId = authService.userData?['passportNumber'] ?? 
                     authService.userData?['passport_number'];
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).set({
        'metadata': {
          'readNewsIds': _readNewsIds.toList(),
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      loggingService.error('Failed to update Firestore', e);
    }
  }

  /// Clear all read news (for testing)
  Future<void> clearAllRead() async {
    try {
      _readNewsIds.clear();
      _unreadCount = 0;
      
      try {
        await cacheService.remove('read_news_ids');
      } catch (e) {
        loggingService.warning('Failed to clear cache: $e');
      }
      await _updateFirestore();
      
      notifyListeners();
    } catch (e) {
      loggingService.error('Failed to clear read news', e);
    }
  }

  /// Get unread news from a list
  List<NewsArticle> getUnreadNews(List<NewsArticle> newsList) {
    return newsList.where((news) => !_readNewsIds.contains(news.id)).toList();
  }

  /// Get read news from a list
  List<NewsArticle> getReadNews(List<NewsArticle> newsList) {
    return newsList.where((news) => _readNewsIds.contains(news.id)).toList();
  }

  /// Mark news as read with read timestamp
  Future<NewsArticle> markNewsAsReadWithTimestamp(NewsArticle news) async {
    await markAsRead(news.id);
    
    return news.copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );
  }

  /// Get read statistics
  Map<String, dynamic> getReadStatistics(List<NewsArticle> newsList) {
    final totalNews = newsList.length;
    final readNews = newsList.where((news) => _readNewsIds.contains(news.id)).length;
    final unreadNews = totalNews - readNews;
    final readPercentage = totalNews > 0 ? (readNews / totalNews * 100).round() : 0;

    return {
      'total': totalNews,
      'read': readNews,
      'unread': unreadNews,
      'readPercentage': readPercentage,
    };
  }
} 