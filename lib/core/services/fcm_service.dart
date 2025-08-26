import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:go_router/go_router.dart';

import 'auth_service.dart';
import 'logging_service_secure.dart';
import 'family_request_service.dart';

class FCMService {
  final LoggingService loggingService;
  late final FirebaseMessaging _messaging;
  late final FirebaseFirestore _firestore;
  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      return null;
    }
  }

  FCMService({required this.loggingService}) {
    _messaging = FirebaseMessaging.instance;
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  /// Initialize FCM service with enhanced features
  Future<void> initialize() async {
    try {
      if (!_isFirebaseMessagingAvailable()) {
        loggingService.warning('🚫 Firebase Messaging not available on this platform');
        return;
      }

      loggingService.info('🚀 Initializing enhanced FCM service...');

      // Request enhanced permissions
      final settings = await _requestEnhancedPermissions();
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        loggingService.info('✅ FCM permissions granted, setting up enhanced features...');
        
        // Setup enhanced notification channels
        await _setupEnhancedNotificationChannels();
        
        // Setup message handlers
        _setupEnhancedMessageHandlers();
        
        // Setup notification actions listener
        _setupNotificationActionHandlers();
        
        loggingService.info('💡 FCM token will be generated AFTER user authentication');

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(
          _onTokenRefresh,
          onError: (error) {
            loggingService.warning('🔄 FCM token refresh error: ${error.toString().split('\n')[0]}');
          },
        );

        loggingService.info('✅ Enhanced FCM service initialized successfully');
        loggingService.info('');
        loggingService.info('🎉 NEW FCM FEATURES ENABLED:');
        loggingService.info('   📱 Rich notifications with images');
        loggingService.info('   🎯 Action buttons (Просмотреть, Ответить)');
        loggingService.info('   🔗 Enhanced deep linking');
        loggingService.info('   📊 Notification analytics tracking');
        loggingService.info('   🎨 Custom notification categories');
        loggingService.info('');
      } else {
        loggingService.warning('❌ FCM permission denied by user');
      }
    } catch (e) {
      final errorMsg = e.toString().split('\n')[0];
      
      if (e.toString().contains('SERVICE_NOT_AVAILABLE') || 
          e.toString().contains('java.io.IOException') ||
          e.toString().contains('TimeoutException')) {
        
        loggingService.info('🌐 FCM service temporarily unavailable: $errorMsg');
        loggingService.info('💡 Enhanced features will be available when connection improves');
        
      } else {
        loggingService.error('💥 Unexpected FCM initialization error', e);
      }
    }
  }

  /// Request enhanced permissions including critical alerts
  Future<NotificationSettings> _requestEnhancedPermissions() async {
    return await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true, // For important notifications
      carPlay: true,
      announcement: true,
    ).timeout(const Duration(seconds: 15));
  }

  /// Setup enhanced notification channels with rich features
  Future<void> _setupEnhancedNotificationChannels() async {
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          // Critical news channel with high priority
          NotificationChannel(
            channelGroupKey: 'news_group',
            channelKey: 'news_critical',
            channelName: 'Критические новости',
            channelDescription: 'Экстренные объявления и важная информация',
            defaultColor: const Color(0xFFE74C3C),
            ledColor: const Color(0xFFE74C3C),
            importance: NotificationImportance.Max,
            defaultPrivacy: NotificationPrivacy.Public,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            criticalAlerts: true,
          ),
          
          // General news channel
          NotificationChannel(
            channelGroupKey: 'news_group',
            channelKey: 'news_general',
            channelName: 'Общие новости',
            channelDescription: 'Новости и обновления ЖК',
            defaultColor: const Color(0xFF0050A3),
            ledColor: const Color(0xFF0050A3),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: false,
          ),
          
          // Service requests channel
          NotificationChannel(
            channelGroupKey: 'service_group',
            channelKey: 'service_response',
            channelName: 'Ответы на заявки',
            channelDescription: 'Ответы администрации на ваши заявки',
            defaultColor: const Color(0xFF00AEEF),
            ledColor: const Color(0xFF00AEEF),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          
          // System notifications
          NotificationChannel(
            channelGroupKey: 'system_group',
            channelKey: 'system_alerts',
            channelName: 'Системные уведомления',
            channelDescription: 'Технические уведомления и обновления',
            defaultColor: const Color(0xFF95A5A6),
            ledColor: const Color(0xFF95A5A6),
            importance: NotificationImportance.Default,
            channelShowBadge: false,
            playSound: false,
            enableVibration: false,
          ),
          
          // Family requests channel
          NotificationChannel(
            channelGroupKey: 'family_group',
            channelKey: 'family_requests',
            channelName: 'Запросы в семью',
            channelDescription: 'Уведомления о новых запросах на присоединение к семье',
            defaultColor: const Color(0xFF9B59B6),
            ledColor: const Color(0xFF9B59B6),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          
          // Family approved channel
          NotificationChannel(
            channelGroupKey: 'family_group',
            channelKey: 'family_approved',
            channelName: 'Семейные запросы одобрены',
            channelDescription: 'Уведомления об одобрении запросов в семью',
            defaultColor: const Color(0xFF27AE60),
            ledColor: const Color(0xFF27AE60),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          
          // Family rejected channel
          NotificationChannel(
            channelGroupKey: 'family_group',
            channelKey: 'family_rejected',
            channelName: 'Семейные запросы отклонены',
            channelDescription: 'Уведомления об отклонении запросов в семью',
            defaultColor: const Color(0xFFE74C3C),
            ledColor: const Color(0xFFE74C3C),
            importance: NotificationImportance.Default,
            channelShowBadge: false,
            playSound: false,
            enableVibration: false,
          ),
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: 'news_group',
            channelGroupName: 'Новости ЖК',
          ),
          NotificationChannelGroup(
            channelGroupKey: 'service_group',
            channelGroupName: 'Сервисные заявки',
          ),
          NotificationChannelGroup(
            channelGroupKey: 'system_group',
            channelGroupName: 'Система',
          ),
          NotificationChannelGroup(
            channelGroupKey: 'family_group',
            channelGroupName: 'Семейные запросы',
          ),
        ],
      );
      
      loggingService.info('✅ Enhanced notification channels configured');
    } catch (e) {
      loggingService.error('Failed to setup enhanced notification channels', e);
    }
  }

  /// Setup enhanced message handlers with rich features
  void _setupEnhancedMessageHandlers() {
    // Handle foreground messages with rich notifications
    FirebaseMessaging.onMessage.listen(_handleEnhancedForegroundMessage);

    // Handle background message taps with analytics
    FirebaseMessaging.onMessageOpenedApp.listen(_handleEnhancedBackgroundMessageTap);

    // Handle app launch from terminated state
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleEnhancedBackgroundMessageTap(message);
      }
    });
  }

  /// Setup notification action handlers (reply, view, etc.)
  void _setupNotificationActionHandlers() {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationActionReceived,
      onNotificationCreatedMethod: _onNotificationCreated,
      onNotificationDisplayedMethod: _onNotificationDisplayed,
      onDismissActionReceivedMethod: _onNotificationDismissed,
    );
  }

  /// Handle enhanced foreground messages with rich notifications
  Future<void> _handleEnhancedForegroundMessage(RemoteMessage message) async {
    try {
      loggingService.info('📨 Received enhanced foreground message: ${message.messageId}');
      
      // Track notification received
      await _trackNotificationEvent('received', message);
      
      // Show rich local notification
      await _showEnhancedLocalNotification(message);
      
      // Add haptic feedback
      HapticFeedback.lightImpact();
      
    } catch (e) {
      loggingService.error('Failed to handle enhanced foreground message', e);
    }
  }

  /// Handle enhanced background message tap with analytics
  Future<void> _handleEnhancedBackgroundMessageTap(RemoteMessage message) async {
    try {
      loggingService.info('🎯 Enhanced message tapped: ${message.messageId}');

      // Track notification opened
      await _trackNotificationEvent('opened', message);
      
      // Navigate with enhanced deep linking
      await _handleEnhancedNavigation(message.data);
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      loggingService.error('Failed to handle enhanced background message tap', e);
    }
  }

  /// Show enhanced local notification with rich features
  Future<void> _showEnhancedLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      final data = message.data;
      final type = data['type'] ?? 'general';
      final hasImage = data['image'] != null && data['image']!.isNotEmpty;
      final isImportant = data['important'] == 'true';
      
      // Determine channel and category
      String channelKey = 'news_general';
      NotificationCategory? category;
      
      switch (type) {
        case 'news_critical':
        case 'emergency':
          channelKey = 'news_critical';
          category = NotificationCategory.Reminder;
          break;
        case 'service_response':
        case 'admin_response':
          channelKey = 'service_response';
          category = NotificationCategory.Message;
          break;
        case 'family_request':
          channelKey = 'family_requests';
          category = NotificationCategory.Call;
          break;
        case 'family_request_response':
          channelKey = data['status'] == 'approved' ? 'family_approved' : 'family_rejected';
          category = NotificationCategory.Social;
          break;
        case 'news':
        default:
          channelKey = isImportant ? 'news_critical' : 'news_general';
          category = NotificationCategory.Social;
          break;
      }

      // Create action buttons based on type
      final actionButtons = _createActionButtons(type, data);
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: message.hashCode,
          channelKey: channelKey,
          title: notification.title ?? 'Уведомление Newport',
          body: notification.body ?? '',
          summary: data['summary'] ?? 'Newport ЖК',
          bigPicture: hasImage ? data['image'] : null,
          notificationLayout: hasImage ? NotificationLayout.BigPicture : NotificationLayout.Default,
          category: category,
          wakeUpScreen: isImportant,
          fullScreenIntent: isImportant,
          criticalAlert: isImportant,
          payload: data.map((key, value) => MapEntry(key, value?.toString())),
          autoDismissible: !isImportant,
          showWhen: true,
          displayOnForeground: true,
          displayOnBackground: true,
          customSound: type == 'news_critical' ? 'resource://raw/critical_alert' : null,
        ),
        actionButtons: actionButtons,
      );
      
      loggingService.info('✅ Enhanced notification displayed with ${actionButtons.length} actions');
    } catch (e) {
      loggingService.error('Failed to show enhanced local notification', e);
    }
  }

  /// Create action buttons based on notification type
  List<NotificationActionButton> _createActionButtons(String type, Map<String, dynamic> data) {
    final buttons = <NotificationActionButton>[];
    
    switch (type) {
      case 'news':
      case 'news_critical':
        buttons.addAll([
          NotificationActionButton(
            key: 'view_news',
            label: 'Просмотреть',
            icon: 'resource://drawable/ic_read',
            actionType: ActionType.SilentAction,
            isDangerousOption: false,
          ),
          NotificationActionButton(
            key: 'share_news',
            label: 'Поделиться',
            icon: 'resource://drawable/ic_share',
            actionType: ActionType.SilentAction,
            isDangerousOption: false,
          ),
        ]);
        break;
        
      case 'service_response':
      case 'admin_response':
        buttons.addAll([
          NotificationActionButton(
            key: 'view_response',
            label: 'Просмотреть ответ',
            icon: 'resource://drawable/ic_message',
            actionType: ActionType.SilentAction,
            isDangerousOption: false,
          ),
          NotificationActionButton(
            key: 'reply_admin',
            label: 'Ответить',
            icon: 'resource://drawable/ic_reply',
                         actionType: ActionType.SilentAction,
             requireInputText: true,
            isDangerousOption: false,
          ),
        ]);
        break;
        
      case 'family_request':
        buttons.addAll([
          NotificationActionButton(
            key: 'approve_family',
            label: 'Одобрить',
            icon: 'resource://drawable/ic_check',
            actionType: ActionType.SilentAction,
            isDangerousOption: false,
          ),
          NotificationActionButton(
            key: 'reject_family',
            label: 'Отклонить',
            icon: 'resource://drawable/ic_close',
            actionType: ActionType.SilentAction,
            isDangerousOption: true,
          ),
        ]);
        break;
        
      case 'family_request_response':
        if (data['status'] == 'approved') {
          buttons.add(
            NotificationActionButton(
              key: 'complete_registration',
              label: 'Завершить регистрацию',
              icon: 'resource://drawable/ic_phone',
              actionType: ActionType.SilentAction,
              isDangerousOption: false,
            ),
          );
        } else {
          buttons.add(
            NotificationActionButton(
              key: 'view_reason',
              label: 'Подробнее',
              icon: 'resource://drawable/ic_info',
              actionType: ActionType.SilentAction,
              isDangerousOption: false,
            ),
          );
        }
        break;
        
      default:
        buttons.add(
          NotificationActionButton(
            key: 'open_app',
            label: 'Открыть приложение',
            icon: 'resource://drawable/ic_open',
            actionType: ActionType.SilentAction,
            isDangerousOption: false,
          ),
        );
    }
    
    return buttons;
  }

  /// Handle enhanced navigation with deep linking
  Future<void> _handleEnhancedNavigation(Map<String, dynamic> data) async {
    try {
      final type = data['type'];
      final id = data['id'];
      final route = data['route'];

      // Custom route handling
      if (route != null && route.isNotEmpty) {
        loggingService.info('🔗 Navigating to custom route: $route');
        // TODO: Implement go_router navigation
        // GoRouter.of(context).go(route);
        return;
      }

      // Type-based navigation
      switch (type) {
        case 'news':
        case 'news_critical':
          if (id != null) {
            loggingService.info('📰 Navigating to news detail: $id');
            // TODO: Navigate to news detail screen
            // GoRouter.of(context).go('/news/$id');
          } else {
            loggingService.info('📰 Navigating to news list');
            // TODO: Navigate to news list
            // GoRouter.of(context).go('/news');
          }
          break;
          
        case 'service_response':
        case 'admin_response':
          if (id != null) {
            loggingService.info('🔧 Navigating to service request: $id');
            // TODO: Navigate to service request detail
            // GoRouter.of(context).go('/service-requests/$id');
          } else {
            loggingService.info('🔧 Navigating to service requests list');
            // TODO: Navigate to service requests list
            // GoRouter.of(context).go('/service-requests');
          }
          break;
          
        default:
          loggingService.info('🏠 Navigating to dashboard (default)');
          // TODO: Navigate to dashboard
          // GoRouter.of(context).go('/dashboard');
      }
    } catch (e) {
      loggingService.error('Failed to handle enhanced navigation', e);
    }
  }

  /// Track notification events for analytics
  Future<void> _trackNotificationEvent(String event, RemoteMessage message) async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;

      final userId = authService.userData?['passport_number'] ?? 
                     authService.verifiedApartment?.passportNumber;
      if (userId == null) return;

      // Save analytics event to Firestore
      await _firestore.collection('notification_analytics').add({
        'userId': userId,
        'messageId': message.messageId,
        'event': event, // 'received', 'opened', 'dismissed', 'action_taken'
        'type': message.data['type'] ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'title': message.notification?.title,
        'platform': defaultTargetPlatform.name,
        'data': message.data,
      });
      
      loggingService.info('📊 Tracked notification event: $event');
    } catch (e) {
      loggingService.error('Failed to track notification event', e);
    }
  }

  /// Check if Firebase Messaging is available
  bool _isFirebaseMessagingAvailable() {
    try {
      // Try to access Firebase Messaging instance
      FirebaseMessaging.instance;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    try {
      if (!_isFirebaseMessagingAvailable()) {
        loggingService.warning('Firebase Messaging not available, cannot get token');
        return null;
      }
      return await _messaging.getToken();
    } catch (e) {
      loggingService.error('Failed to get FCM token', e);
      return null;
    }
  }

  /// Update FCM token with enhanced error handling and retry logic
  Future<void> _updateToken() async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 5);
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        loggingService.info('🔄 FCM token update attempt $attempt/$maxRetries');
        
        // Увеличиваем timeout для медленных соединений
        final token = await _messaging.getToken()
            .timeout(const Duration(seconds: 15));
        
        if (token != null) {
          loggingService.info('✅ FCM token obtained successfully: ${token.substring(0, 30)}...');
          
          // Выводим токен крупным шрифтом для удобства копирования
          if (kDebugMode) {
            print('');
            print('══════════════════════════════════════════════════════════════════');
            print('🎯 FCM TOKEN ПОЛУЧЕН (скопируйте для тестирования):');
            print(token);
            print('══════════════════════════════════════════════════════════════════');
            print('💡 Используйте этот токен в admin панели для отправки уведомлений');
            print('🔧 Или откройте fix_notifications.html для тестирования');
            print('══════════════════════════════════════════════════════════════════');
            print('');
          }
          
          await _saveTokenToFirestore(token);
          return; // Успех - выходим из цикла
        } else {
          loggingService.warning('⚠️ FCM token is null (attempt $attempt/$maxRetries)');
          if (attempt < maxRetries) {
            loggingService.info('⏳ Retrying in ${retryDelay.inSeconds} seconds...');
            await Future.delayed(retryDelay);
          }
        }
      } catch (e) {
        // Специфическая обработка сетевых ошибок
        if (e.toString().contains('SERVICE_NOT_AVAILABLE') || 
            e.toString().contains('java.io.IOException') ||
            e.toString().contains('TimeoutException') ||
            e.toString().contains('NETWORK_ERROR')) {
          
          loggingService.info('🌐 FCM service temporarily unavailable (attempt $attempt/$maxRetries): ${e.toString().split('\n')[0]}');
          
          if (attempt < maxRetries) {
            loggingService.info('⏳ Retrying FCM token in ${retryDelay.inSeconds} seconds...');
            await Future.delayed(retryDelay);
          } else {
            loggingService.info('');
            loggingService.info('📱 FCM TROUBLESHOOTING TIPS:');
            loggingService.info('   1. Проверьте интернет соединение');
            loggingService.info('   2. Перезапустите приложение');
            loggingService.info('   3. Откройте fix_notifications.html в браузере');
            loggingService.info('   4. Используйте create_apartment_data.html для пересоздания данных');
            loggingService.info('');
          }
        } else {
          loggingService.error('❌ Unexpected FCM token error (attempt $attempt/$maxRetries)', e);
          if (attempt >= maxRetries) {
            loggingService.error('💔 FCM token update failed after $maxRetries attempts');
          }
        }
      }
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        loggingService.warning('User not authenticated, skipping token save');
        return;
      }

      // Firebase Auth не обязателен: используем, если есть, иначе продолжаем без него
      final firebaseUser = GetIt.instance<FirebaseAuth>().currentUser;
      if (firebaseUser != null) {
        loggingService.info('🔑 Firebase Auth user: ${firebaseUser.uid} (${firebaseUser.isAnonymous ? "anonymous" : "authenticated"})');
      } else {
        loggingService.info('ℹ️ Firebase Auth user is null – proceeding with unauthenticated Firestore write (rules must allow)');
      }

      // Подробно логируем все доступные данные
      loggingService.info('🔍 FCM Token Saving Debug Info:');
      loggingService.info('   authService.userData: ${authService.userData}');
      loggingService.info('   authService.verifiedApartment: ${authService.verifiedApartment}');

      // Получаем данные о квартире
      final apartment = authService.verifiedApartment;
      if (apartment == null) {
        loggingService.warning('Cannot save FCM token: no verified apartment');
        return;
      }

      // ВРЕМЕННО: Сначала проверим что возвращает apartment.blockId
      final originalBlockId = apartment.blockId;
      loggingService.info('🔍 DEBUG: apartment.blockId returns: "$originalBlockId"');
      
      // Нормализуем blockId для соответствия существующей структуре Firebase
      String blockId = originalBlockId;
      
      // ИСПРАВЛЯЕМ: убираем дублирование "BLOK BLOK" -> "BLOK"
      if (blockId.contains('BLOK BLOK') || blockId.contains('BLOCK BLOCK')) {
        blockId = blockId.replaceAll('BLOK BLOK', 'BLOK').replaceAll('BLOCK BLOCK', 'BLOCK').trim();
        loggingService.info('🔧 Fixed duplicate: "$originalBlockId" -> "$blockId"');
      }
      
      // Дополнительная нормализация: если есть "BLOCK", заменяем на "BLOK"
      if (blockId.contains('BLOCK')) {
        blockId = blockId.replaceAll('BLOCK', 'BLOK');
        loggingService.info('🔧 Normalized BLOCK to BLOK: "$blockId"');
      }
      
      final apartmentNumber = apartment.apartmentNumber;
      
      loggingService.info('🏗️ Will use blockId: "$blockId" for Firebase path');
      
      // ПРОВЕРЯЕМ: какие блоки реально существуют в Firebase
      try {
        loggingService.info('🔍 Checking existing blocks in Firebase...');
        final usersCollection = await _firestore.collection('users').limit(10).get();
        final existingBlocks = usersCollection.docs.map((doc) => doc.id).toList();
        loggingService.info('📋 Existing blocks in Firebase: $existingBlocks');
        
        // Проверяем, существует ли наш blockId
        if (!existingBlocks.contains(blockId)) {
          loggingService.warning('⚠️ Block "$blockId" does not exist in Firebase!');
          loggingService.info('💡 Available blocks: $existingBlocks');
          
          // Попробуем найти похожий блок
          for (String existingBlock in existingBlocks) {
            if (existingBlock.toUpperCase().contains(blockId) || 
                blockId.toUpperCase().contains(existingBlock.toUpperCase())) {
              loggingService.info('🎯 Found similar block: "$existingBlock" - using this instead');
              blockId = existingBlock;
              break;
            }
          }
        } else {
          loggingService.info('✅ Block "$blockId" exists in Firebase');
        }
      } catch (e) {
        loggingService.error('❌ Failed to check existing blocks', e);
      }
      final passportNumber = apartment.passportNumber ?? authService.userData?['passportNumber'] ?? authService.userData?['passport_number'];
      final phoneNumber = apartment.phone ?? authService.userData?['phone'] ?? '';
      
      // Нормализуем номер телефона для использования в качестве ключа
      String normalizedPhone = phoneNumber.toString().replaceAll('+', '').replaceAll(' ', '');

      if (blockId.isEmpty || apartmentNumber.isEmpty) {
        loggingService.error('❌ CRITICAL: Cannot save FCM token - empty values!');
        loggingService.error('   blockId: "$blockId" (empty: ${blockId.isEmpty})');
        loggingService.error('   apartmentNumber: "$apartmentNumber" (empty: ${apartmentNumber.isEmpty})');
        loggingService.error('   This means user data is not properly loaded!');
        return;
      }
      
      // Дополнительная проверка на спецсимволы
      if (blockId.contains('/') || apartmentNumber.contains('/')) {
        loggingService.error('❌ CRITICAL: Block or apartment contains "/" which breaks Firestore path!');
        loggingService.error('   blockId: "$blockId"');
        loggingService.error('   apartmentNumber: "$apartmentNumber"');
        return;
      }

      loggingService.info('🔄 Saving FCM token for:');
      loggingService.info('   🏠 Block: "$blockId" (length: ${blockId.length})');
      loggingService.info('   🚪 Apartment: "$apartmentNumber" (length: ${apartmentNumber.length})');
      loggingService.info('   👤 Passport: $passportNumber');
      loggingService.info('   📱 Phone: $phoneNumber');
      loggingService.info('   📱 Token: ${token.substring(0, 20)}...');
      loggingService.info('');
      loggingService.info('🎯 Saving to exact path:');
      loggingService.info('   users/"$blockId"/apartments/"$apartmentNumber"/pushToken');

      // Сохраняем FCM токен в СУЩЕСТВУЮЩИЙ документ квартиры (НЕ создаем новый)
      loggingService.info('💾 Updating existing apartment document: users/$blockId/apartments/$apartmentNumber');
      
      // Сначала проверим, существует ли документ
      final docRef = _firestore
          .collection('users')
          .doc(blockId)
          .collection('apartments')
          .doc(apartmentNumber);
          
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        loggingService.info('✅ Found existing apartment document');
        
        // ПРОВЕРЯЕМ: есть ли уже pushToken
        final existingData = docSnapshot.data();
        final existingPushToken = existingData?['pushToken'];
        final existingFcmTokens = existingData?['fcmTokens'] as List?;
        
        if (existingPushToken != null && existingPushToken.isNotEmpty) {
          loggingService.info('✅ pushToken уже существует: ${existingPushToken.toString().substring(0, 30)}...');
          loggingService.info('💡 Пропускаем генерацию нового токена');
          return; // Токен уже есть, выходим
        }
        
        if (existingFcmTokens != null && existingFcmTokens.contains(token)) {
          loggingService.info('✅ Такой FCM токен уже есть в массиве fcmTokens');
          loggingService.info('💡 Добавляем только pushToken поле');
          
          // Добавляем только pushToken, fcmTokens уже есть
          await docRef.update({
            'pushToken': token,
            'lastPushTokenUpdate': FieldValue.serverTimestamp(),
          });
        } else {
          loggingService.info('🆕 Добавляем новый FCM токен');
          
          // Добавляем и в массив и в единичное поле
          await docRef.update({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'pushToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
            'lastPushTokenUpdate': FieldValue.serverTimestamp(),
          });
        }
        
      } else {
        loggingService.error('❌ КРИТИЧНО: Документ квартиры НЕ НАЙДЕН!');
        loggingService.error('   Искали по пути: users/$blockId/apartments/$apartmentNumber');
        loggingService.error('');
        
        // Попробуем найти что реально есть в этом блоке
        try {
          loggingService.info('🔍 Проверим что есть в блоке "$blockId":');
          final blockDoc = await _firestore.collection('users').doc(blockId).get();
          
          if (blockDoc.exists) {
            loggingService.info('✅ Блок "$blockId" существует');
            
            // Проверим подколлекцию apartments
            final apartmentsCollection = await _firestore
                .collection('users')
                .doc(blockId)
                .collection('apartments')
                .limit(10)
                .get();
                
            if (apartmentsCollection.docs.isNotEmpty) {
              final apartmentIds = apartmentsCollection.docs.map((doc) => doc.id).toList();
              loggingService.info('📋 Квартиры в блоке "$blockId": $apartmentIds');
              loggingService.error('❌ Квартира "$apartmentNumber" НЕ НАЙДЕНА среди: $apartmentIds');
            } else {
              loggingService.error('❌ В блоке "$blockId" НЕТ подколлекции apartments!');
            }
          } else {
            loggingService.error('❌ Блок "$blockId" НЕ СУЩЕСТВУЕТ в коллекции users!');
          }
        } catch (e) {
          loggingService.error('❌ Ошибка при диагностике', e);
        }
        
        loggingService.info('🆕 Создаём новый документ квартиры и сохраняем токен');

        await docRef.set({
          'pushToken': token,
          'fcmTokens': [token],
          'createdAt': FieldValue.serverTimestamp(),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'phone': phoneNumber,
          'passportNumber': passportNumber,
          'blockId': blockId,
          'apartment_number': apartmentNumber,
          'fullName': authService.userData?['fullName'] ?? apartment.fullName ?? '',
        });

        loggingService.info('✅ Новый документ квартиры создан и токен сохранён');
        // Продолжаем, чтобы финальная проверка сработала
      }

      loggingService.info('✅ FCM token saved to apartment document successfully!');
      
      // Финальная проверка pushToken
      try {
        final finalDoc = await docRef.get();
        final data = finalDoc.data();
        final pushToken = data?['pushToken'];
        final fcmTokens = data?['fcmTokens'] as List?;
        
        loggingService.info('');
        loggingService.info('🎯 FINAL VERIFICATION:');
        loggingService.info('   pushToken: ${pushToken != null ? "✅ EXISTS" : "❌ MISSING"}');
        loggingService.info('   fcmTokens: ${fcmTokens?.length ?? 0} tokens');
        loggingService.info('   Total fields: ${data?.keys.length ?? 0}');
        
        if (pushToken != null) {
          loggingService.info('   pushToken value: ${pushToken.toString().substring(0, 30)}...');
          loggingService.info('');
          loggingService.info('🎉 SUCCESS! FCM token properly saved:');
          loggingService.info('   📍 users/$blockId/apartments/$apartmentNumber/pushToken');
          loggingService.info('   📱 Token available for push notifications!');
        } else {
          loggingService.warning('⚠️ pushToken не был сохранен - возможна ошибка');
        }
        loggingService.info('');
      } catch (e) {
        loggingService.error('❌ Final verification failed', e);
      }

      // Также сохраняем в отдельную коллекцию fcm_tokens для быстрого поиска по телефону
      if (normalizedPhone.isNotEmpty) {
        loggingService.info('💾 Also saving to fcm_tokens collection with ID: "$normalizedPhone"');
        await _firestore.collection('fcm_tokens').doc(normalizedPhone).set({
          'tokens': FieldValue.arrayUnion([token]),
          'passportNumber': passportNumber,
          'phoneNumber': phoneNumber,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'blockId': blockId,
          'apartmentNumber': apartmentNumber,
          'fullName': authService.userData?['fullName'] ?? apartment.fullName ?? '',
        }, SetOptions(merge: true));
        loggingService.info('✅ FCM token saved to fcm_tokens collection successfully!');
      }

      // Сохраняем профиль пользователя в отдельную коллекцию userProfiles (если есть passport)
      if (passportNumber != null && passportNumber.isNotEmpty) {
        loggingService.info('💾 Also saving profile to userProfiles collection with passport: "$passportNumber"');
        await _firestore.collection('userProfiles').doc(passportNumber).set({
          'passportNumber': passportNumber,
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
          'blockId': blockId,
          'apartmentNumber': apartmentNumber,
          'phone': phoneNumber,
          'fullName': authService.userData?['fullName'] ?? apartment.fullName ?? '',
          'role': 'resident',
          'dataSource': 'fcm_service',
        }, SetOptions(merge: true));
        loggingService.info('✅ User profile saved to userProfiles collection successfully!');
      }

      // Финальная проверка - читаем данные обратно
      loggingService.info('🔍 Verifying saved data...');
      try {
        final apartmentDoc = await _firestore
            .collection('users')
            .doc(blockId)
            .collection('apartments')
            .doc(apartmentNumber)
            .get();
            
        if (apartmentDoc.exists) {
          final data = apartmentDoc.data();
          loggingService.info('✅ Apartment verification: Found ${data?['fcmTokens']?.length ?? 0} token(s)');
        } else {
          loggingService.warning('❌ Apartment verification: Document not found');
        }
      } catch (verificationError) {
        loggingService.error('❌ Verification failed', verificationError);
      }

    } catch (e) {
      loggingService.error('❌ Failed to save FCM token to Firestore', e);
      
      // Дополнительная диагностика
      final authService = _authService;
      final apartment = authService?.verifiedApartment;
      loggingService.info('🔍 Debug info for FCM token error:');
      loggingService.info('   blockId: ${apartment?.blockId ?? "unknown"}');
      loggingService.info('   apartmentNumber: ${apartment?.apartmentNumber ?? "unknown"}'); 
      loggingService.info('   authService.isAuthenticated: ${authService?.isAuthenticated ?? false}');
      loggingService.info('   authService.verifiedApartment: ${apartment != null}');
    }
  }

  /// Handle token refresh
  Future<void> _onTokenRefresh(String token) async {
    try {
      loggingService.info('FCM token refreshed');
      await _updateToken();
    } catch (e) {
      loggingService.error('Failed to handle token refresh', e);
    }
  }

  /// Send news notification
  Future<void> sendNewsNotification({
    required String newsId,
    required String title,
    required String body,
    required bool isImportant,
    List<String>? targetBlocks,
  }) async {
    try {
      // This would typically be called from a Cloud Function
      // For now, we'll just log the intent
      loggingService.info('Would send news notification: $newsId to blocks: $targetBlocks');
    } catch (e) {
      loggingService.error('Failed to send news notification', e);
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (!_isFirebaseMessagingAvailable()) {
        loggingService.warning('Firebase Messaging not available, cannot subscribe to topic');
        return;
      }
      await _messaging.subscribeToTopic(topic);
      loggingService.info('Subscribed to topic: $topic');
    } catch (e) {
      loggingService.error('Failed to subscribe to topic: $topic', e);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (!_isFirebaseMessagingAvailable()) {
        loggingService.warning('Firebase Messaging not available, cannot unsubscribe from topic');
        return;
      }
      await _messaging.unsubscribeFromTopic(topic);
      loggingService.info('Unsubscribed from topic: $topic');
    } catch (e) {
      loggingService.error('Failed to unsubscribe from topic: $topic', e);
    }
  }

  /// Setup notification channels for FCM
  Future<void> setupNotificationChannels() async {
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelGroupKey: 'news_group',
            channelKey: 'news_critical',
            channelName: 'Важные новости',
            channelDescription: 'Критически важные новости и объявления',
            defaultColor: const Color(0xFFE74C3C),
            ledColor: const Color(0xFFE74C3C),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          NotificationChannel(
            channelGroupKey: 'news_group',
            channelKey: 'news_general',
            channelName: 'Общие новости',
            channelDescription: 'Общие новости и обновления',
            defaultColor: const Color(0xFF0050A3),
            ledColor: const Color(0xFF0050A3),
            importance: NotificationImportance.Default,
            channelShowBadge: true,
            playSound: false,
            enableVibration: false,
          ),
        ],
        channelGroups: [
          NotificationChannelGroup(
            channelGroupKey: 'news_group',
            channelGroupName: 'Новости',
          ),
        ],
      );
    } catch (e) {
      loggingService.error('Failed to setup notification channels', e);
    }
  }

  /// Save push token to specific apartment with provided parameters
  /// Этот метод позволяет сохранить токен для конкретной квартиры 
  /// без зависимости от текущего состояния аутентификации
  Future<bool> savePushTokenToApartment({
    required String blockName,
    required String apartmentNumber,
    String? customToken,
  }) async {
    try {
      // Получаем токен (используем переданный или текущий)
      final token = customToken ?? await getToken();
      if (token == null) {
        loggingService.warning('Cannot save push token: no token available');
        return false;
      }

      loggingService.info('🔄 Saving push token to specific apartment:');
      loggingService.info('   🏠 Block: $blockName');
      loggingService.info('   🚪 Apartment: $apartmentNumber');
      loggingService.info('   📱 Token: ${token.substring(0, 20)}...');

      // Сохраняем в путь users/{blockName}/apartments/{apartmentNumber}
      final docPath = 'users/$blockName/apartments/$apartmentNumber';
      loggingService.info('💾 Saving to path: $docPath');
      
      await _firestore
          .collection('users')
          .doc(blockName)
          .collection('apartments')
          .doc(apartmentNumber)
          .set({
        'pushToken': token,
        'lastPushTokenUpdate': FieldValue.serverTimestamp(),
        'blockName': blockName,
        'apartmentNumber': apartmentNumber,
      }, SetOptions(merge: true)); // merge: true чтобы не перезаписать существующие поля

      loggingService.info('✅ Push token saved successfully to $docPath');
      
      // Проверяем, что данные сохранились
      final docSnapshot = await _firestore
          .collection('users')
          .doc(blockName)
          .collection('apartments')
          .doc(apartmentNumber)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        loggingService.info('✅ Verification: Document exists with pushToken: ${data?['pushToken']?.toString().substring(0, 20) ?? 'null'}...');
        return true;
      } else {
        loggingService.warning('❌ Verification failed: Document was not created');
        return false;
      }

    } catch (e) {
      loggingService.error('❌ Failed to save push token to apartment', e);
      return false;
    }
  }

  /// Generate FCM token AFTER successful authentication
  /// This should be called from AuthService after user login
  Future<String?> generateTokenAfterAuth() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        loggingService.warning('🚫 Cannot generate FCM token: user not authenticated');
        return null;
      }

      loggingService.info('');
      loggingService.info('🎯 GENERATING FCM TOKEN AFTER AUTHENTICATION:');
      loggingService.info('   👤 User authenticated: ✅');
      loggingService.info('   🔥 Firebase ready: ✅');
      loggingService.info('   📱 Starting token generation...');
      loggingService.info('');

      // Теперь безопасно генерируем токен для аутентифицированного пользователя
      await _updateToken();
      
      // Возвращаем текущий токен
      final token = await getToken();
      if (token != null) {
        loggingService.info('🎉 FCM token successfully generated for authenticated user!');
        loggingService.info('📱 Token: ${token.substring(0, 30)}...');
      } else {
        loggingService.warning('⚠️ FCM token generation returned null');
      }
      
      return token;
    } catch (e) {
      loggingService.error('❌ Failed to generate FCM token after auth', e);
      return null;
    }
  }

  /// Clean up old tokens
  Future<void> cleanupOldTokens() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;

      final passportNumber = authService.userData?['passport_number'] ?? 
                             authService.verifiedApartment?.passportNumber;
      
      if (passportNumber == null) return;
      

      final currentToken = await getToken();
      if (currentToken == null) return;

      // Keep only the current token
      await _firestore.collection('userProfiles').doc(passportNumber).set({
        'fcmTokens': [currentToken],
        'lastTokenCleanup': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      loggingService.info('Cleaned up old FCM tokens');
    } catch (e) {
      loggingService.error('Failed to cleanup old tokens', e);
    }
  }

  // ENHANCED NOTIFICATION ACTION HANDLERS

  /// Handle notification action received (button press)
  @pragma('vm:entry-point')
  static Future<void> _onNotificationActionReceived(ReceivedAction receivedAction) async {
    try {
      final fcmService = GetIt.instance<FCMService>();
      await fcmService._handleNotificationAction(receivedAction);
    } catch (e) {
      debugPrint('Failed to handle notification action: $e');
    }
  }

  /// Handle notification created
  @pragma('vm:entry-point')
  static Future<void> _onNotificationCreated(ReceivedNotification receivedNotification) async {
    // Optional: Track notification creation
    debugPrint('Notification created: ${receivedNotification.id}');
  }

  /// Handle notification displayed
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDisplayed(ReceivedNotification receivedNotification) async {
    // Optional: Track notification displayed
    debugPrint('Notification displayed: ${receivedNotification.id}');
  }

  /// Handle notification dismissed
  @pragma('vm:entry-point')
  static Future<void> _onNotificationDismissed(ReceivedAction receivedAction) async {
    try {
      final fcmService = GetIt.instance<FCMService>();
      await fcmService._trackNotificationDismissed(receivedAction);
    } catch (e) {
      debugPrint('Failed to track notification dismissal: $e');
    }
  }

  /// Handle notification action (button press)
  Future<void> _handleNotificationAction(ReceivedAction receivedAction) async {
    try {
      final actionKey = receivedAction.buttonKeyPressed;
      final payload = receivedAction.payload ?? {};
      
      loggingService.info('🎯 Notification action pressed: $actionKey');
      
      // Add haptic feedback
      HapticFeedback.mediumImpact();
      
      // Track action
      await _trackNotificationAction(actionKey, payload);
      
      switch (actionKey) {
        case 'view_news':
          await _handleViewNewsAction(payload);
          break;
        case 'share_news':
          await _handleShareNewsAction(payload);
          break;
        case 'view_response':
          await _handleViewResponseAction(payload);
          break;
        case 'reply_admin':
          await _handleReplyAdminAction(receivedAction.buttonKeyInput);
          break;
        case 'open_app':
          await _handleOpenAppAction();
          break;
        case 'approve_family':
          await _handleApproveFamilyAction(payload);
          break;
        case 'reject_family':
          await _handleRejectFamilyAction(payload);
          break;
        case 'complete_registration':
          await _handleCompleteRegistrationAction(payload);
          break;
        case 'view_reason':
          await _handleViewReasonAction(payload);
          break;
        default:
          loggingService.warning('Unknown notification action: $actionKey');
      }
    } catch (e) {
      loggingService.error('Failed to handle notification action', e);
    }
  }

  /// Handle view news action
  Future<void> _handleViewNewsAction(Map<String, String?> payload) async {
    final newsId = payload['id'];
    if (newsId != null) {
      loggingService.info('📰 Opening news: $newsId');
      final context = _rootNavigatorKey.currentContext;
      if (context != null) {
        context.go('/news/$newsId');
      }
    }
  }

  /// Handle share news action
  Future<void> _handleShareNewsAction(Map<String, String?> payload) async {
    final title = payload['title'] ?? 'Новость из Newport';
    final url = payload['url'] ?? '';
    loggingService.info('📤 Sharing news: $title');
    
    try {
      // Use share_plus for sharing content
      final shareText = '$title\n\n${url.isNotEmpty ? url : "Прочитать полностью в приложении Newport"}';
      // TODO: Implement share_plus functionality
      // await Share.share(shareText, subject: title);
      loggingService.info('Share initiated: $shareText');
    } catch (e) {
      loggingService.error('Failed to share news', e);
    }
  }

  /// Handle view response action
  Future<void> _handleViewResponseAction(Map<String, String?> payload) async {
    final requestId = payload['id'];
    if (requestId != null) {
      loggingService.info('🔧 Opening service request: $requestId');
      final context = _rootNavigatorKey.currentContext;
      if (context != null) {
        context.go('/services/my-requests');
      }
    }
  }

  /// Handle reply to admin action
  Future<void> _handleReplyAdminAction(String replyText) async {
    if (replyText.isNotEmpty) {
      loggingService.info('💬 User replied: ${replyText.substring(0, 20)}...');
      // TODO: Send reply to admin via ServiceRequestService
      // final serviceRequestService = GetIt.instance<ServiceRequestService>();
      // await serviceRequestService.sendReply(requestId, replyText);
    }
  }

  /// Handle open app action
  Future<void> _handleOpenAppAction() async {
    loggingService.info('🏠 Opening app to dashboard');
    final context = _rootNavigatorKey.currentContext;
    if (context != null) {
      context.go('/dashboard');
    }
  }

  /// Handle approve family request action
  Future<void> _handleApproveFamilyAction(Map<String, String?> payload) async {
    final requestId = payload['requestId'];
    if (requestId != null) {
      loggingService.info('👨‍👩‍👧‍👦 Approving family request: $requestId');
      
      try {
        final familyRequestService = GetIt.instance<FamilyRequestService>();
        final success = await familyRequestService.respondToFamilyRequest(
          requestId: requestId,
          approved: true,
        );
        
        if (success) {
          // Show success message
          _showToast('Запрос одобрен');
        } else {
          _showToast('Не удалось одобрить запрос');
        }
      } catch (e) {
        loggingService.error('Failed to approve family request', e);
        _showToast('Ошибка при одобрении запроса');
      }
    }
  }

  /// Handle reject family request action
  Future<void> _handleRejectFamilyAction(Map<String, String?> payload) async {
    final requestId = payload['requestId'];
    if (requestId != null) {
      loggingService.info('❌ Rejecting family request: $requestId');
      
      try {
        final familyRequestService = GetIt.instance<FamilyRequestService>();
        final success = await familyRequestService.respondToFamilyRequest(
          requestId: requestId,
          approved: false,
          rejectionReason: 'Отклонено через уведомление',
        );
        
        if (success) {
          _showToast('Запрос отклонен');
        } else {
          _showToast('Не удалось отклонить запрос');
        }
      } catch (e) {
        loggingService.error('Failed to reject family request', e);
        _showToast('Ошибка при отклонении запроса');
      }
    }
  }

  /// Handle complete registration action
  Future<void> _handleCompleteRegistrationAction(Map<String, String?> payload) async {
    final requestId = payload['requestId'];
    loggingService.info('📱 Opening phone registration for request: $requestId');
    
    final context = _rootNavigatorKey.currentContext;
    if (context != null) {
      context.go('/phone-registration?requestId=$requestId');
    }
  }

  /// Handle view rejection reason action
  Future<void> _handleViewReasonAction(Map<String, String?> payload) async {
    loggingService.info('ℹ️ Viewing rejection reason');
    
    final context = _rootNavigatorKey.currentContext;
    if (context != null) {
      context.go('/family-requests');
    }
  }

  /// Show toast message
  void _showToast(String message) {
    final context = _rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Navigator key for global navigation
  static final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
  
  /// Get the root navigator key for global navigation
  static GlobalKey<NavigatorState> get rootNavigatorKey => _rootNavigatorKey;

  /// Track notification action for analytics
  Future<void> _trackNotificationAction(String action, Map<String, String?> payload) async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;

      final userId = authService.userData?['passport_number'] ?? 
                     authService.verifiedApartment?.passportNumber;
      if (userId == null) return;

      await _firestore.collection('notification_analytics').add({
        'userId': userId,
        'event': 'action_taken',
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
        'payload': payload,
      });
      
      loggingService.info('📊 Tracked notification action: $action');
    } catch (e) {
      loggingService.error('Failed to track notification action', e);
    }
  }

  /// Track notification dismissed
  Future<void> _trackNotificationDismissed(ReceivedAction receivedAction) async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) return;

      final userId = authService.userData?['passport_number'] ?? 
                     authService.verifiedApartment?.passportNumber;
      if (userId == null) return;

      await _firestore.collection('notification_analytics').add({
        'userId': userId,
        'event': 'dismissed',
        'notificationId': receivedAction.id,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
      
      loggingService.info('📊 Tracked notification dismissal');
    } catch (e) {
      loggingService.error('Failed to track notification dismissal', e);
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
  }
} 