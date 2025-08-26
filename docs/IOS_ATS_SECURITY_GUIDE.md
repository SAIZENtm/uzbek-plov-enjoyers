# iOS App Transport Security (ATS) Guide

## Проблема с текущей конфигурацией

### Что обнаружено:
```xml
<key>NSAllowsArbitraryLoads</key>
<true/>
```

Это **КРИТИЧЕСКАЯ** уязвимость:
- ❌ Разрешает любые HTTP соединения
- ❌ Отключает проверку SSL сертификатов
- ❌ Подвержено MITM атакам
- ❌ Apple может отклонить приложение

## Правильная конфигурация ATS

### 1. Базовая безопасная конфигурация

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <!-- Запрещаем произвольные HTTP соединения -->
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    
    <!-- Разрешаем только для локальной разработки -->
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

### 2. Добавление исключений (только если необходимо)

```xml
<key>NSExceptionDomains</key>
<dict>
    <!-- Пример: Legacy API без HTTPS -->
    <key>legacy-api.example.com</key>
    <dict>
        <!-- Минимальные разрешения -->
        <key>NSExceptionAllowsInsecureHTTPLoads</key>
        <true/>
        
        <!-- Не включаем поддомены -->
        <key>NSIncludesSubdomains</key>
        <false/>
        
        <!-- Требуем современную криптографию где возможно -->
        <key>NSExceptionRequiresForwardSecrecy</key>
        <true/>
        
        <!-- Минимальная версия TLS -->
        <key>NSExceptionMinimumTLSVersion</key>
        <string>TLSv1.2</string>
    </dict>
</dict>
```

## Миграция на HTTPS

### 1. Проверка HTTP использования

```bash
# Найти все HTTP URL в коде
dart scripts/check_http_usage.dart

# Автоматически заменить где возможно
dart scripts/check_http_usage.dart --fix

# Подробный вывод
dart scripts/check_http_usage.dart --verbose
```

### 2. Обновление API endpoints

```dart
// ❌ Плохо
class ApiConfig {
  static const baseUrl = 'http://api.example.com';
}

// ✅ Хорошо
class ApiConfig {
  static const baseUrl = kReleaseMode 
    ? 'https://api.example.com'  // Production
    : 'http://localhost:8080';   // Development only
}
```

### 3. Использование переменных окружения

```dart
// lib/config/environment.dart
class Environment {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.example.com',
  );
  
  static const bool useHttps = bool.fromEnvironment(
    'USE_HTTPS',
    defaultValue: true,
  );
}

// Запуск с разными конфигурациями
// Development: flutter run --dart-define=API_URL=http://localhost:8080
// Production: flutter run --dart-define=API_URL=https://api.example.com
```

## Обработка сертификатов

### 1. Пиннинг сертификатов (для критичных API)

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio_certificate_pinning/dio_certificate_pinning.dart';

class SecureApiClient {
  late final Dio dio;
  
  SecureApiClient() {
    dio = Dio();
    
    // Добавляем пиннинг сертификата
    dio.interceptors.add(
      CertificatePinningInterceptor(
        allowedSHAFingerprints: [
          'SHA256:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
        ],
      ),
    );
  }
}
```

### 2. Проверка сертификатов в production

```dart
class ApiService {
  final Dio _dio;
  
  ApiService() : _dio = Dio() {
    if (kReleaseMode) {
      // В production строго проверяем сертификаты
      (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) => false;
        return client;
      };
    }
  }
}
```

## Тестирование ATS

### 1. Проверка конфигурации

```bash
# Проверить Info.plist
plutil -lint ios/Runner/Info.plist

# Проверить ATS логи
xcrun simctl spawn booted log stream --level debug | grep "App Transport Security"
```

### 2. Тестирование в Simulator

```swift
// Добавить в AppDelegate.swift для отладки
#if DEBUG
if let atsSettings = Bundle.main.object(forInfoDictionaryKey: "NSAppTransportSecurity") {
    print("ATS Settings: \(atsSettings)")
}
#endif
```

### 3. Проверка перед релизом

Checklist:
- [ ] Все API используют HTTPS в production
- [ ] NSAllowsArbitraryLoads = false
- [ ] Минимальные исключения документированы
- [ ] Сертификаты валидны и не истекают

## Специфичные случаи

### 1. WebView контент

```dart
// Для WebView проверяйте URL перед загрузкой
class SecureWebView extends StatelessWidget {
  final String url;
  
  @override
  Widget build(BuildContext context) {
    // Проверка HTTPS
    if (!url.startsWith('https://') && kReleaseMode) {
      return ErrorWidget('Небезопасное соединение');
    }
    
    return WebView(
      initialUrl: url,
      javascriptMode: JavascriptMode.unrestricted,
    );
  }
}
```

### 2. Загрузка изображений

```dart
// Используйте CachedNetworkImage с проверкой
CachedNetworkImage(
  imageUrl: imageUrl,
  errorWidget: (context, url, error) {
    if (error is HandshakeException) {
      // Ошибка SSL
      return Icon(Icons.error);
    }
    return Icon(Icons.image_not_supported);
  },
);
```

### 3. File downloads

```dart
Future<void> downloadFile(String url) async {
  // Проверка протокола
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' && kReleaseMode) {
    throw SecurityException('Insecure download blocked');
  }
  
  // Продолжить загрузку...
}
```

## Обход для разработки

### 1. Условная конфигурация

```dart
// Только для debug builds
class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) {
        // Разрешаем самоподписанные сертификаты только для localhost
        return host == 'localhost' || host == '127.0.0.1';
      };
  }
}

void main() {
  if (kDebugMode) {
    HttpOverrides.global = DevHttpOverrides();
  }
  runApp(MyApp());
}
```

### 2. Эмулятор Firebase

```dart
// Для Firebase emulator
if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

## Мониторинг

### 1. Логирование небезопасных соединений

```dart
class SecurityMonitor {
  static void logInsecureConnection(String url) {
    if (!url.startsWith('https://')) {
      FirebaseCrashlytics.instance.log(
        'Insecure connection attempted: ${Uri.parse(url).host}'
      );
    }
  }
}
```

### 2. Аналитика использования HTTP

```dart
// Отслеживание в аналитике
FirebaseAnalytics.instance.logEvent(
  name: 'insecure_connection',
  parameters: {
    'host': Uri.parse(url).host,
    'timestamp': DateTime.now().toIso8601String(),
  },
);
```

## App Store Guidelines

### Apple требует:
1. Обоснование для каждого HTTP исключения
2. План миграции на HTTPS
3. Минимальные привилегии

### При отправке в App Store:
```
App Transport Security:
- Мы используем HTTPS для всех соединений
- Исключения только для localhost в dev режиме
- Все production API защищены TLS 1.2+
```

## Итоговый checklist

- [ ] Заменить NSAllowsArbitraryLoads на false
- [ ] Обновить все HTTP URL на HTTPS
- [ ] Добавить минимальные исключения если необходимо
- [ ] Проверить работу в release режиме
- [ ] Документировать все исключения
- [ ] Настроить мониторинг небезопасных соединений
- [ ] Подготовить ответы для App Store Review
