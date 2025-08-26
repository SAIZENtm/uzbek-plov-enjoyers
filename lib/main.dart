  import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/service_locator.dart';
import 'core/services/auth_service.dart';
import 'core/services/monitoring_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/service_request_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/logging_service_secure.dart';
import 'core/services/offline_service.dart';
import 'core/services/family_request_service.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/theme_service.dart';
import 'package:app_links/app_links.dart';

final getIt = GetIt.instance;

// Background message handler for FCM vfdvdf alish pipiskag defwefwes shluha pidor pidor срудут ygygyukgky
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  if (kDebugMode) {
    print('Handling background message: ${message.messageId}');
    print('Message data: ${message.data}');
  }
}

@pragma('vm:entry-point')
Future<void> initializeApp() async {
  try {
    // Инициализируем Firebase первым
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        // Firebase уже инициализирован, продолжаем
        debugPrint('Firebase already initialized');
      } else {
        rethrow;
      }
    }

    // Устанавливаем background message handler
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Failed to set up FCM background handler: $e');
    }

    // Затем инициализируем сервисы
    await setupServiceLocator();
    
    // Инициализируем мониторинг последним
    final monitoringService = getIt<MonitoringService>();
    await monitoringService.initialize();
    
    // Инициализируем NotificationService
    final notificationService = getIt<NotificationService>();
    await notificationService.initialize();
    
    // Инициализируем LocalNotificationService
    final localNotificationService = LocalNotificationService();
    final loggingService = getIt<LoggingService>();
    await localNotificationService.initialize(loggingService);
    
    // Инициализируем OfflineService
    final offlineService = getIt<OfflineService>();
    await offlineService.initialize();
    
    // Инициализируем FamilyRequestService
    final familyRequestService = getIt<FamilyRequestService>();
    await familyRequestService.initialize();
    
    // Запускаем отслеживание заявок
    final serviceRequestService = getIt<ServiceRequestService>();
    await serviceRequestService.startTrackingUserRequests();
    
    // Настраиваем обработку deep links
    await _setupDeepLinks();
    
  } catch (e, stackTrace) {
    debugPrint('App initialization error: $e\n$stackTrace');
    rethrow;
  }
}

Future<void> _setupDeepLinks() async {
  try {
    final appLinks = AppLinks();
    
    // Обработка ссылок при запуске приложения
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      _handleDeepLink(initialLink.toString());
    }

    // Обработка ссылок когда приложение уже запущено
    appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri.toString());
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  } catch (e) {
    debugPrint('Failed to setup deep links: $e');
  }
}

void _handleDeepLink(String link) {
  try {
    debugPrint('Handling deep link: $link');
    
    // Парсим инвайт из ссылки
    if (link.contains('newport://invite/')) {
      final uri = Uri.parse(link);
      final inviteId = uri.pathSegments.last;

      if (inviteId.isNotEmpty) {
        // Сохраняем инвайт для обработки после инициализации
        _savePendingInvite(inviteId);
      }
    }
  } catch (e) {
    debugPrint('Error handling deep link: $e');
  }
}

void _savePendingInvite(String inviteId) async {
  try {
    // Сохраняем инвайт в SharedPreferences для обработки позже
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_invite_id', inviteId);
    debugPrint('Saved pending invite: $inviteId');
  } catch (e) {
    debugPrint('Error saving pending invite: $e');
  }
}

@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeApp();
    await initializeDateFormatting('ru', null);
    
    // Настраиваем обработчики действий уведомлений
    await LocalNotificationService.setupNotificationActionListeners();
    
    runApp(const MyApp());
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize app: $e\n$stackTrace');
    runApp(const ErrorApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: getIt<AuthService>()),
        ChangeNotifierProvider<ProfileProvider>(create: (_) => ProfileProvider()),
        ChangeNotifierProvider<ThemeService>.value(value: getIt<ThemeService>()),
      ],
      child: Sizer(
        builder: (context, orientation, deviceType) {
          return MaterialApp.router(
            title: 'Newport Resident',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: AppRouter.router,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'),
              Locale('en', 'US'),
            ],
            locale: const Locale('ru', 'RU'),
          );
        },
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
              const SizedBox(height: 16),
              const Text(
                'Ошибка инициализации приложения',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пожалуйста, перезапустите приложение',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
