# Secure Logging Guide

## Проблемы с текущим логированием

### Что было обнаружено:
1. ❌ Использование print() с PII данными
2. ❌ Логирование паролей, токенов, телефонов
3. ❌ Отсутствие структурированного логирования
4. ❌ Нет фильтрации чувствительных данных

## Новый подход к логированию

### LoggingService возможности:
1. ✅ Автоматическая фильтрация PII
2. ✅ Структурированное логирование
3. ✅ Интеграция с Crashlytics
4. ✅ Маскирование чувствительных данных

## Использование LoggingService

### 1. Базовое использование

```dart
class MyService {
  final LoggingService _loggingService = GetIt.instance<LoggingService>();
  
  void doSomething() {
    // Информационное сообщение
    _loggingService.info('Starting operation');
    
    // Предупреждение
    _loggingService.warning('Low memory detected');
    
    // Ошибка
    _loggingService.error('Operation failed', exception, stackTrace);
    
    // Отладка (только в debug mode)
    _loggingService.debug('Debug info', {'userId': userId});
  }
}
```

### 2. Логирование с данными

```dart
// ❌ Плохо - PII в сообщении
print('User +998901234567 logged in');

// ✅ Хорошо - PII автоматически маскируется
_loggingService.info('User logged in', {
  'phone': '+998901234567', // Будет замаскировано: +99***67
  'timestamp': DateTime.now(),
});
```

### 3. Логирование сетевых запросов

```dart
// Автоматически скрывает токены и чувствительные данные
_loggingService.logNetworkRequest(
  method: 'POST',
  url: 'https://api.example.com/auth/login',
  headers: {
    'Authorization': 'Bearer secret_token', // Будет <redacted>
  },
  body: {
    'phone': '+998901234567', // Будет замаскировано
    'password': '12345', // Будет ***
  },
  statusCode: 200,
  duration: Duration(milliseconds: 250),
);
```

## Автоматическое маскирование

### Что маскируется автоматически:

| Тип данных | Пример | После маскирования |
|------------|--------|-------------------|
| Телефон | +998901234567 | +99***67 |
| Email | user@example.com | us***@example.com |
| Паспорт | AA1234567 | AA***** |
| Карта | 1234 5678 9012 3456 | ****-****-****-**** |
| IP адрес | 192.168.1.1 | ***.***.*.* |
| Токены | abc123def456 | ab***56 |

### Чувствительные поля:

Любые поля с названиями, содержащими:
- phone, phoneNumber
- passport, passportNumber
- password
- token, accessToken, refreshToken
- email
- fullName, name
- cardNumber, cvv
- clientId, clientSecret
- apiKey, privateKey
- fcmToken, deviceToken
- sessionId, userId

## Миграция существующего кода

### 1. Автоматическая замена

```bash
# Сухой прогон (показать что будет изменено)
dart scripts/replace_print_statements.dart --dry-run

# Применить изменения
dart scripts/replace_print_statements.dart

# С подробным выводом
dart scripts/replace_print_statements.dart --verbose
```

### 2. Ручная проверка

После автоматической замены проверьте:

```dart
// Было
print('Error: ${error.message}, user: ${user.phone}');

// Стало (автоматически)
_loggingService.error('Error: ${error.message}, user: ${user.phone}');

// Лучше переписать вручную
_loggingService.error('Authentication failed', error, stackTrace, {
  'userId': user.id, // ID безопасен для логирования
  // phone НЕ добавляем
});
```

## Best Practices

### 1. НЕ логируйте PII в сообщениях

```dart
// ❌ Плохо
_loggingService.info('User ${user.phone} performed action');

// ✅ Хорошо
_loggingService.info('User performed action', {
  'action': 'payment',
  'amount': 1000,
  // Не добавляем персональные данные
});
```

### 2. Используйте структурированные данные

```dart
// ❌ Плохо
_loggingService.info('Payment: amount=$amount, status=$status, user=$userId');

// ✅ Хорошо
_loggingService.info('Payment processed', {
  'amount': amount,
  'status': status,
  'userId': userId.hashCode, // Хешируем для приватности
});
```

### 3. Правильная обработка ошибок

```dart
try {
  await someOperation();
} catch (e, stackTrace) {
  // Логируем с контекстом
  _loggingService.error(
    'Operation failed',
    e,
    stackTrace,
    {
      'operation': 'someOperation',
      'context': 'payment_flow',
    },
  );
  
  // Добавляем хлебные крошки для Crashlytics
  _loggingService.addBreadcrumb('Before operation', {
    'state': 'initialized',
  });
}
```

### 4. Условное логирование

```dart
// Отладочная информация только в debug режиме
_loggingService.debug('Detailed state', {
  'widgets': widgetCount,
  'memory': memoryUsage,
});

// Важная информация всегда
_loggingService.info('App started', {
  'version': packageInfo.version,
  'platform': Platform.operatingSystem,
});
```

## Настройка Crashlytics

### 1. Инициализация

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Настройка Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Настройка LoggingService
  GetIt.instance.registerSingleton<LoggingService>(
    LoggingService(
      enableDebugLogging: kDebugMode,
      enableCrashlytics: !kDebugMode,
    ),
  );
  
  runApp(MyApp());
}
```

### 2. Установка идентификатора пользователя

```dart
// При входе пользователя
void onUserLogin(String userId) {
  // Хешируем для приватности
  _loggingService.setUserIdentifier(userId);
}
```

## Мониторинг и анализ

### 1. Firebase Console

- Просмотр крашей с контекстом
- Анализ частых ошибок
- Фильтрация по версиям приложения

### 2. Локальная отладка

```dart
// В debug режиме все логи выводятся в консоль
// Используйте фильтры в IDE:
// - Android Studio: Logcat filter "NewportApp"
// - VS Code: Debug Console filter
```

### 3. Производственный мониторинг

```javascript
// Cloud Function для анализа ошибок
exports.monitorAppErrors = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    // Анализ частых ошибок в Crashlytics
    // Отправка алертов при критических ошибках
  });
```

## Compliance

### GDPR / Privacy соответствие:

1. ✅ PII автоматически маскируется
2. ✅ Логи не содержат персональных данных
3. ✅ User ID хешируется
4. ✅ Чувствительные поля фильтруются

### Что НЕ логируется:

- Пароли в любом виде
- Полные номера телефонов
- Email адреса (только домен)
- Паспортные данные
- Платежная информация
- Точные геолокации
- IP адреса пользователей

## Checklist внедрения

- [ ] Заменить все print() на LoggingService
- [ ] Проверить логирование сетевых запросов
- [ ] Убедиться что PII не логируется
- [ ] Настроить Crashlytics
- [ ] Обновить документацию для команды
- [ ] Провести код-ревью изменений
- [ ] Протестировать в debug и release режимах
