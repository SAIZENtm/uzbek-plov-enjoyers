import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'logging_service_secure.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  LoggingService? _loggingService;

  Future<void> initialize(LoggingService loggingService) async {
    _loggingService = loggingService;
    
    await AwesomeNotifications().initialize(
      null, // null для использования иконки приложения по умолчанию
      [
        NotificationChannel(
          channelGroupKey: 'service_requests_group',
          channelKey: 'admin_responses',
          channelName: 'Ответы администратора',
          channelDescription: 'Уведомления об ответах администратора на ваши заявки',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelGroupKey: 'basic_channel_group',
          channelKey: 'general',
          channelName: 'Общие уведомления',
          channelDescription: 'Общие уведомления приложения',
          defaultColor: Colors.grey,
          ledColor: Colors.grey,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
      ],
      channelGroups: [
        NotificationChannelGroup(
          channelGroupKey: 'service_requests_group',
          channelGroupName: 'Заявки на обслуживание',
        ),
        NotificationChannelGroup(
          channelGroupKey: 'basic_channel_group',
          channelGroupName: 'Основные уведомления',
        ),
      ],
      debug: true,
    );

    await _requestPermissions();
    
    _loggingService?.info('LocalNotificationService initialized');
  }

  Future<void> _requestPermissions() async {
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  Future<void> showAdminResponseNotification({
    required String requestId,
    required String adminResponse,
    String? requestType,
  }) async {
    try {
      // Создаем уникальный ID из requestId
      final id = int.parse(requestId.substring(0, 8), radix: 16) % 2147483647;
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'admin_responses',
          title: 'Ответ на заявку #${requestId.substring(0, 8)}',
          body: adminResponse,
          notificationLayout: NotificationLayout.Default,
          payload: {'request_id': requestId},
        ),
      );

      _loggingService?.info('Showed local notification for request: $requestId');
    } catch (e) {
      _loggingService?.error('Failed to show local notification', e);
    }
  }

  static Future<void> setupNotificationActionListeners() async {
    // Обработка нажатия на уведомление
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceivedMethod,
    );
  }

  // Обработчик действий с уведомлениями
  @pragma('vm:entry-point')
  static Future<void> _onActionReceivedMethod(ReceivedAction receivedAction) async {
    if (receivedAction.payload != null && receivedAction.payload!.containsKey('request_id')) {
      // TODO: Навигация к экрану заявки
      // final requestId = receivedAction.payload!['request_id'];
      // Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: requestId)));
    }
  }
} 