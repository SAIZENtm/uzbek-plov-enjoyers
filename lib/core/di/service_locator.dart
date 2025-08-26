import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/analytics_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
import '../services/encryption_service.dart';
import '../services/error_service.dart';
import '../services/logging_service_secure.dart';
import '../services/map_service.dart';
import '../services/monitoring_service.dart';
import '../services/offline_service.dart';
import '../services/service_request_service.dart';
import '../services/apartment_service.dart';
import '../services/client_service.dart';
import '../services/theme_service.dart';
import '../services/news_service.dart';
import '../services/notification_service.dart';
import '../services/fcm_service.dart';
import '../services/unread_tracker.dart';
import '../services/profile_service.dart';
import '../services/connectivity_service.dart';
import '../services/family_request_service.dart';
import '../services/invite_service.dart';
import '../services/image_upload_service.dart';
import '../services/smart_home_service.dart';
import '../services/iot_device_service.dart';
// Replaced with secure proxy-based service
import '../services/tuya_cloud_service_secure.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  try {
    // Core Services
    final sharedPreferences = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(sharedPreferences);

    // Firebase instances
    getIt.registerSingleton<FirebaseAuth>(FirebaseAuth.instance);
    getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);

    // Register base services (secure)
    getIt.registerSingleton<LoggingService>(LoggingService());
    getIt.registerSingleton<EncryptionService>(EncryptionService());
    getIt.registerSingleton<CacheService>(CacheService(sharedPreferences: sharedPreferences));
    getIt.registerSingleton<ConnectivityService>(ConnectivityService(loggingService: getIt<LoggingService>()));

    // Register services with dependencies
    getIt.registerSingleton<ErrorService>(
      ErrorService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    getIt.registerSingleton<ApiService>(
      ApiService(
        errorService: getIt<ErrorService>(),
        encryptionService: getIt<EncryptionService>(),
      ),
    );

    getIt.registerSingleton<MonitoringService>(
      MonitoringService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register AnalyticsService lazily to ensure Firebase is initialized first
    getIt.registerLazySingleton<AnalyticsService>(() => AnalyticsService());
    getIt.registerSingleton<MapService>(MapService());

    // Register new services BEFORE AuthService since AuthService depends on them
    getIt.registerSingleton<ApartmentService>(
      ApartmentService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    getIt.registerSingleton<ClientService>(
      ClientService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    getIt.registerSingleton<NewsService>(
      NewsService(
        apiService: getIt<ApiService>(),
        cacheService: getIt<CacheService>(),
        loggingService: getIt<LoggingService>(),
        connectivityService: getIt<ConnectivityService>(),
      ),
    );

    getIt.registerSingleton<NotificationService>(
      NotificationService(
        loggingService: getIt<LoggingService>(),
        cacheService: getIt<CacheService>(),
      ),
    );

    // Register FamilyRequestService
    getIt.registerSingleton<FamilyRequestService>(
      FamilyRequestService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register InviteService
    getIt.registerSingleton<InviteService>(
      InviteService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register FCM and UnreadTracker services
    getIt.registerSingleton<FCMService>(
      FCMService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    getIt.registerSingleton<UnreadTracker>(
      UnreadTracker(
        loggingService: getIt<LoggingService>(),
        cacheService: getIt<CacheService>(),
      ),
    );

    // Register profile service
    getIt.registerSingleton<ProfileService>(ProfileService());

    // Register image upload service
    getIt.registerSingleton<ImageUploadService>(
      ImageUploadService(
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register theme service
    getIt.registerSingleton<ThemeService>(ThemeService());

    // Register feature services that depend on the new services
    getIt.registerSingleton<AuthService>(
      AuthService(
        apiService: getIt<ApiService>(),
        cacheService: getIt<CacheService>(),
        encryptionService: getIt<EncryptionService>(),
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register IoT device service for Arduino hardware connection
    getIt.registerSingleton<IoTDeviceService>(
      IoTDeviceService(
        authService: getIt<AuthService>(),
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register Tuya Cloud service (secure, proxy-based)
    getIt.registerSingleton<TuyaCloudService>(
      TuyaCloudService(
        authService: getIt<AuthService>(),
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Register smart home service (after all IoT services)
    getIt.registerSingleton<SmartHomeService>(
      SmartHomeService(
        authService: getIt<AuthService>(),
        loggingService: getIt<LoggingService>(),
        iotDeviceService: getIt<IoTDeviceService>(),
        tuyaCloudService: getIt<TuyaCloudService>(),
      ),
    );

    getIt.registerSingleton<OfflineService>(
      OfflineService(
        apiService: getIt<ApiService>(),
        cacheService: getIt<CacheService>(),
        loggingService: getIt<LoggingService>(),
        authService: getIt<AuthService>(),
      ),
    );

    getIt.registerSingleton<ServiceRequestService>(
      ServiceRequestService(
        apiService: getIt<ApiService>(),
        cacheService: getIt<CacheService>(),
        loggingService: getIt<LoggingService>(),
      ),
    );

    // Initialize services
    await getIt<AnalyticsService>().initialize();
    
    // Initialize FCM service with error handling
    try {
      await getIt<FCMService>().initialize();
      await getIt<FCMService>().setupNotificationChannels();
    } catch (e) {
      getIt<LoggingService>().error('FCM service initialization failed: $e');
      getIt<LoggingService>()
          .warning('App will continue without push notifications');
    }

    getIt<LoggingService>().info('Service locator setup complete');
  } catch (e, stackTrace) {
    getIt<LoggingService>().fatal('Error setting up service locator: $e', e, stackTrace);
    rethrow;
  }
} 