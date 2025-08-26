import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import 'dart:convert';

import '../models/notification_model.dart';
import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'cache_service.dart';

class NotificationService {
  static const String _notificationsKey = 'local_notifications';
  static const String _lastSyncKey = 'last_notification_sync';
  
  final LoggingService loggingService;
  final CacheService cacheService;
  late final FirebaseFirestore _firestore;
  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      // AuthService might not be registered yet during app initialization
      return null;
    }
  }
  
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final StreamController<List<NotificationModel>> _notificationsController = 
      StreamController<List<NotificationModel>>.broadcast();
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  NotificationService({
    required this.loggingService,
    required this.cacheService,
  }) {
    _firestore = GetIt.instance<FirebaseFirestore>();
    
    // Immediately push empty state to prevent infinite loading
    _notifications = [];
    _updateUnreadCount();
    _notificationsController.add(_notifications);
    
    _initializeNotifications();
  }

  // Getters
  Stream<List<NotificationModel>> get notificationsStream {
    // Ensure stream always starts with current data
    if (!_notificationsController.hasListener) {
      _notificationsController.add(_notifications);
    }
    return _notificationsController.stream.asBroadcastStream();
  }
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> initialize() async {
    try {
      // Load cached notifications first
      await _loadCachedNotifications();
      
      // Start listening to real-time updates if authenticated
      final authService = _authService;
      if (authService != null && authService.isAuthenticated) {
        await _startListeningToNotifications();
      } else {
        loggingService.info('User not authenticated, showing empty notifications');
        // Ensure we push empty list if not authenticated
        _notifications = [];
        _updateUnreadCount();
        _notificationsController.add(_notifications);
      }
    } catch (e) {
      loggingService.error('Failed to initialize notifications', e);
      // Always provide fallback empty state
      _notifications = [];
      _updateUnreadCount();
      _notificationsController.add(_notifications);
    }
  }

  Future<void> _initializeNotifications() async {
    await initialize();
  }

  Future<void> _loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_notificationsKey);
      
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        _notifications = jsonList
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }

      // Always update unread count and push current list (even if empty)
      _updateUnreadCount();
      _notificationsController.add(_notifications);
    } catch (e) {
      loggingService.error('Failed to load cached notifications', e);
    }
  }

  Future<void> _startListeningToNotifications() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        loggingService.warning('AuthService not available or user not authenticated');
        // Push empty list so UI stops loading
        _notifications = [];
        _updateUnreadCount();
        _notificationsController.add(_notifications);
        return;
      }
      
      // Получаем все возможные идентификаторы пользователя
      final passport = authService.userData?['passport_number'] ?? 
                      authService.userData?['passportNumber'] ?? 
                      authService.verifiedApartment?.passportNumber;
      final phone = authService.userData?['phone'] ?? 
                    authService.verifiedApartment?.phone;

      String? phoneWithoutPlus;
      if (phone != null && phone is String && phone.startsWith('+')) {
        phoneWithoutPlus = phone.substring(1);
      }

      final List<String> userIdentifiers = [
        if (passport != null && (passport as String).isNotEmpty) passport,
        if (phone != null && (phone as String).isNotEmpty) phone,
        if (phoneWithoutPlus != null && phoneWithoutPlus.isNotEmpty) phoneWithoutPlus,
      ];
      
      // Получаем данные выбранной квартиры для фильтрации
      final selectedApartment = authService.verifiedApartment;
      final selectedApartmentNumber = selectedApartment?.apartmentNumber;
      final selectedBlockId = selectedApartment?.blockId;
      
      loggingService.info('Notification search identifiers: $userIdentifiers');
      loggingService.info('Selected apartment: $selectedBlockId - $selectedApartmentNumber');

      if (userIdentifiers.isEmpty) {
        loggingService.warning('Cannot start notification listener: no valid user identifiers');
        // Push empty list so UI stops loading
        _notifications = [];
        _updateUnreadCount();
        _notificationsController.add(_notifications);
        return;
      }

      // Cancel existing subscription
      await _notificationSubscription?.cancel();

      loggingService.info('Starting Firestore query for identifiers: $userIdentifiers');

      Query collectionQuery = _firestore.collection('notifications');
      if (userIdentifiers.length == 1) {
        collectionQuery = collectionQuery.where('userId', isEqualTo: userIdentifiers.first);
      } else {
        collectionQuery = collectionQuery.where('userId', whereIn: userIdentifiers);
      }

      // Listen to real-time updates for the constructed query
      _notificationSubscription = collectionQuery
          .limit(50)
          .snapshots()
          .listen(
            _onNotificationsUpdate,
            onError: (error) {
              loggingService.error('Notification stream error', error);
              _notifications = [];
              _updateUnreadCount();
              _notificationsController.add(_notifications);

              Future.delayed(const Duration(seconds: 5), () {
                _startListeningToNotifications();
              });
            },
          );

      loggingService.info('Started listening to notifications identifiers: $userIdentifiers');
    } catch (e) {
      loggingService.error('Failed to start notification listener', e);
      // Push empty list on error so UI stops loading
      _notifications = [];
      _updateUnreadCount();
      _notificationsController.add(_notifications);
    }
  }

  void _onNotificationsUpdate(QuerySnapshot snapshot) {
    try {
      loggingService.info('Notification update received: ${snapshot.docs.length} documents');
      
      // Получаем данные выбранной квартиры для фильтрации
      final authService = _authService;
      final selectedApartment = authService?.verifiedApartment;
      final selectedApartmentNumber = selectedApartment?.apartmentNumber;
      final selectedBlockId = selectedApartment?.blockId;
      
      final notifications = snapshot.docs
                  .map((doc) {
          try {
            return NotificationModel.fromFirestore(doc.data() as Map<String, dynamic>, docId: doc.id);
          } catch (e) {
            loggingService.error('Error parsing notification document ${doc.id}', e);
            return null;
          }
        })
          .where((notification) => notification != null)
          .cast<NotificationModel>()
          .where((notification) {
            // Фильтруем уведомления по выбранной квартире
            if (selectedApartmentNumber != null && selectedBlockId != null) {
              final notificationData = notification.data;
              final notificationApartment = notificationData['apartmentNumber'] ?? notificationData['apartment_number'];
              final notificationBlock = notificationData['blockId'] ?? notificationData['block'] ?? notificationData['block_id'];
              
              // Если в уведомлении указана квартира, проверяем совпадение
              if (notificationApartment != null && notificationBlock != null) {
                return notificationApartment.toString() == selectedApartmentNumber && 
                       notificationBlock.toString() == selectedBlockId;
              }
            }
            // Если квартира не указана в уведомлении, показываем его
            return true;
          })
          .toList();

      // Sort manually after fetching
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _notifications = notifications;
      _updateUnreadCount();
      _cacheNotifications();
      _notificationsController.add(_notifications);

      loggingService.info('Processed ${notifications.length} notifications (after filtering), $_unreadCount unread');
    } catch (e) {
      loggingService.error('Error processing notification update', e);
      // Push empty list on error so UI stops loading
      _notifications = [];
      _updateUnreadCount();
      _notificationsController.add(_notifications);
    }
  }

  void _updateUnreadCount() {
    _unreadCount = _notifications.where((n) => !n.isRead).length;
  }

  Future<void> _cacheNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _notifications.map((n) => n.toJson()).toList();
      await prefs.setString(_notificationsKey, jsonEncode(jsonList));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      loggingService.error('Failed to cache notifications', e);
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      // Validate notification ID
      if (notificationId.isEmpty) {
        loggingService.error('Cannot mark notification as read: empty notification ID');
        return;
      }

      final notificationIndex = _notifications.indexWhere((n) => n.id == notificationId);
      if (notificationIndex == -1) return;

      final notification = _notifications[notificationIndex];
      if (notification.isRead) return;

      // Update in Firestore - use set with merge to handle missing documents
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .set({
        'isRead': true,
        'readAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Update locally
      _notifications[notificationIndex] = notification.copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      
      _updateUnreadCount();
      _cacheNotifications();
      _notificationsController.add(_notifications);

      loggingService.info('Marked notification as read: $notificationId');
    } catch (e) {
      loggingService.error('Failed to mark notification as read', e);
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final unreadNotifications = _notifications.where((n) => !n.isRead).toList();
      if (unreadNotifications.isEmpty) return;

      // Update in Firestore (batch operation)
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final notification in unreadNotifications) {
        final docRef = _firestore.collection('notifications').doc(notification.id);
        // Use set with merge to handle cases where document might not exist
        batch.set(docRef, {
          'isRead': true,
          'readAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      }
      
      await batch.commit();

      // Update locally
      _notifications = _notifications.map((n) => 
        n.isRead ? n : n.copyWith(isRead: true, readAt: now)
      ).toList();
      
      _updateUnreadCount();
      _cacheNotifications();
      _notificationsController.add(_notifications);

      loggingService.info('Marked all notifications as read');
    } catch (e) {
      loggingService.error('Failed to mark all notifications as read', e);
    }
  }

  // Get notifications by type
  List<NotificationModel> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get admin responses
  List<NotificationModel> getAdminResponses() {
    return getNotificationsByType('admin_response');
  }

  // Delete notification (soft delete - mark as deleted)
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Remove from Firestore (or mark as deleted)
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .delete();

      // Remove locally
      _notifications.removeWhere((n) => n.id == notificationId);
      _updateUnreadCount();
      _cacheNotifications();
      _notificationsController.add(_notifications);

      loggingService.info('Deleted notification: $notificationId');
    } catch (e) {
      loggingService.error('Failed to delete notification', e);
    }
  }

  // Refresh notifications manually
  Future<void> refreshNotifications() async {
    try {
      loggingService.info('=== Starting refreshNotifications ===');
      
      // Immediately emit current data to prevent UI loading
      _notificationsController.add(_notifications);
      
      final authService = _authService;
      loggingService.info('Got authService: ${authService != null}');
      
      if (authService == null || !authService.isAuthenticated) {
        loggingService.warning('Cannot refresh notifications: user not authenticated');
        // Push empty list so UI stops loading
        _notifications = [];
        _updateUnreadCount();
        _notificationsController.add(_notifications);
        return;
      }

      loggingService.info('User is authenticated');

      // Получаем все возможные идентификаторы пользователя
      final passport = authService.userData?['passport_number'] ?? 
                      authService.userData?['passportNumber'] ?? 
                      authService.verifiedApartment?.passportNumber;
      final phone = authService.userData?['phone'] ?? 
                    authService.verifiedApartment?.phone;

      String? phoneWithoutPlus;
      if (phone != null && phone is String && phone.startsWith('+')) {
        phoneWithoutPlus = phone.substring(1);
      }

      final List<String> userIdentifiers = [
        if (passport != null && (passport as String).isNotEmpty) passport,
        if (phone != null && (phone as String).isNotEmpty) phone,
        if (phoneWithoutPlus != null && phoneWithoutPlus.isNotEmpty) phoneWithoutPlus,
      ];
      
      loggingService.info('Refresh notification search identifiers: $userIdentifiers');

      if (userIdentifiers.isEmpty) {
        loggingService.warning('Cannot refresh notifications: no valid user identifiers');
        _notifications = [];
        _updateUnreadCount();
        _notificationsController.add(_notifications);
        return;
      }

      loggingService.info('Starting Firestore query for identifiers: $userIdentifiers');

      Query query = _firestore.collection('notifications');
      if (userIdentifiers.length == 1) {
        query = query.where('userId', isEqualTo: userIdentifiers.first);
      } else {
        query = query.where('userId', whereIn: userIdentifiers);
      }

      final snapshot = await query.get();

      loggingService.info('Firestore query completed. Found ${snapshot.docs.length} documents');
      
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc.data() as Map<String, dynamic>, docId: doc.id))
          .toList();

      // Sort manually after fetching
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _notifications = notifications;
      _updateUnreadCount();
      _cacheNotifications();
      _notificationsController.add(_notifications);

      loggingService.info('=== Completed refreshNotifications with ${notifications.length} notifications ===');
    } catch (e) {
      loggingService.error('Failed to refresh notifications', e);
      // Push empty list on error so UI stops loading
      _notifications = [];
      _updateUnreadCount();
      _notificationsController.add(_notifications);
    }
  }

  // Start listening when user logs in
  Future<void> startListening() async {
    await _startListeningToNotifications();
  }

  // Stop listening when user logs out
  Future<void> stopListening() async {
    await _notificationSubscription?.cancel();
    _notificationSubscription = null;
    _notifications.clear();
    _unreadCount = 0;
    _notificationsController.add(_notifications);
    
    // Clear cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    await prefs.remove(_lastSyncKey);
  }

  // Create a test notification (for development)
  Future<void> createTestNotification() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;
      
      final userId = authService.userData?['passport_number'];
      if (userId == null) return;

      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: 'Тестовое уведомление',
        message: 'Это тестовое уведомление для проверки системы.',
        type: 'system',
        createdAt: DateTime.now(),
        data: {'test': true},
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      loggingService.info('Created test notification');
    } catch (e) {
      loggingService.error('Failed to create test notification', e);
    }
  }

  // Create admin response test notification
  Future<void> createAdminResponseNotification() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;
      
      final userId = authService.userData?['passport_number'];
      if (userId == null) return;

      final notification = NotificationModel(
        id: 'admin_response_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: 'Ответ на заявку #1752172461965',
        message: 'хорошо с',
        type: 'admin_response',
        createdAt: DateTime.now(),
        data: {
          'requestId': '1752172461965',
          'requestType': 'plumbing',
          'priority': 'Medium',
          'apartmentNumber': '123',
          'block': 'F',
          'status': 'in-progress'
        },
        relatedRequestId: '1752172461965',
        adminName: 'Администратор',
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      loggingService.info('Created admin response notification');
    } catch (e) {
      loggingService.error('Failed to create admin response notification', e);
    }
  }

  // Create service update test notification
  Future<void> createServiceUpdateNotification() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;
      
      final userId = authService.userData?['passport_number'];
      if (userId == null) return;

      final notification = NotificationModel(
        id: 'service_update_${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        title: 'Обновление статуса заявки',
        message: 'Ваша заявка принята в работу',
        type: 'service_update',
        createdAt: DateTime.now(),
        data: {
          'requestId': '1752172461965',
          'requestType': 'plumbing',
          'priority': 'Medium',
          'apartmentNumber': '123',
          'block': 'F',
          'oldStatus': 'pending',
          'newStatus': 'in-progress'
        },
        relatedRequestId: '1752172461965',
        adminName: 'Система управления',
      );

      await _firestore
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toJson());

      loggingService.info('Created service update notification');
    } catch (e) {
      loggingService.error('Failed to create service update notification', e);
    }
  }

  void dispose() {
    _notificationSubscription?.cancel();
    _notificationsController.close();
  }
} 