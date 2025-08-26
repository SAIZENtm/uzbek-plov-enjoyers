# Tuya Service Migration Guide

## Безопасность изменения

### Что было удалено из клиента:
1. ❌ Client ID и Client Secret
2. ❌ HMAC подпись в приложении
3. ❌ Access Token в SharedPreferences
4. ❌ Прямые вызовы к Tuya API

### Что добавлено:
1. ✅ Серверный прокси через Cloud Functions
2. ✅ Проверка прав доступа к квартире
3. ✅ Логирование действий
4. ✅ Безопасное кэширование в SecureStorage

## Настройка серверной части

### 1. Установка секретов Tuya в Firebase Functions

```bash
# Установка конфигурации
firebase functions:config:set \
  tuya.client_id="YOUR_TUYA_CLIENT_ID" \
  tuya.client_secret="YOUR_TUYA_CLIENT_SECRET"

# Проверка конфигурации
firebase functions:config:get

# Деплой функций
firebase deploy --only functions
```

### 2. Альтернатива через переменные окружения

Создайте файл `.env` в папке `functions/`:
```env
TUYA_CLIENT_ID=your_client_id
TUYA_CLIENT_SECRET=your_client_secret
```

## Обновление кода приложения

### 1. Замена сервиса в service_locator.dart

```dart
// Старый код
import 'package:your_app/core/services/tuya_cloud_service.dart';

getIt.registerLazySingleton<TuyaCloudService>(
  () => TuyaCloudService(
    authService: getIt<AuthService>(),
    loggingService: getIt<LoggingService>(),
  ),
);

// Новый код
import 'package:your_app/core/services/tuya_cloud_service_secure.dart';

getIt.registerLazySingleton<TuyaCloudService>(
  () => TuyaCloudService(
    authService: getIt<AuthService>(),
    loggingService: getIt<LoggingService>(),
    fcmService: getIt<FCMService>(),
  ),
);
```

### 2. Обновление SmartHomeService

```dart
// Изменений в интерфейсе нет, только внутренняя реализация
// SmartHomeService продолжает использовать TuyaCloudService как обычно
```

### 3. Обработка ошибок в UI

```dart
class SmartHomeScreen extends StatefulWidget {
  // ...
  
  void _handleDeviceControl(String deviceId, bool value) async {
    try {
      setState(() => _isLoading = true);
      
      final success = await _smartHomeService.toggleDevice(deviceId, value);
      
      if (!success) {
        _showErrorMessage('Не удалось управлять устройством');
      }
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          _showErrorMessage('У вас нет доступа к этому устройству');
          break;
        case 'unauthenticated':
          _showErrorMessage('Требуется повторный вход');
          // Перенаправить на экран входа
          break;
        default:
          _showErrorMessage('Ошибка: ${e.message}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
```

## Миграция данных

### 1. Очистка старых токенов

```dart
// Добавить в процесс обновления приложения
Future<void> cleanupOldTuyaData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Удаляем старые небезопасные данные
  await prefs.remove('tuya_access_token');
  await prefs.remove('tuya_token_expiry');
  await prefs.remove('tuya_device_cache');
  
  print('Old Tuya data cleaned up');
}
```

### 2. Миграция прав доступа

```javascript
// Cloud Function для миграции прав
exports.migrateTuyaPermissions = functions.https.onCall(async (data, context) => {
  if (!isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  
  // Обновляем все квартиры с умным домом
  const batch = db.batch();
  
  const apartments = await db.collection('apartments')
    .where('hasTuyaDevices', '==', true)
    .get();
  
  apartments.forEach(doc => {
    batch.update(doc.ref, {
      smartHomeEnabled: true,
      smartHomeDevices: [],
      lastSmartHomeSync: null,
    });
  });
  
  await batch.commit();
  
  return { success: true, migrated: apartments.size };
});
```

## Тестирование

### 1. Unit тесты для Cloud Functions

```javascript
const test = require('firebase-functions-test')();
const admin = require('firebase-admin');

describe('Tuya Proxy Functions', () => {
  let myFunctions;
  
  before(() => {
    // Мокаем Tuya API
    jest.mock('axios');
    myFunctions = require('../tuya-proxy.js');
  });
  
  describe('getSmartHomeDevices', () => {
    it('should require authentication', async () => {
      const wrapped = test.wrap(myFunctions.getSmartHomeDevices);
      
      await expect(wrapped({
        apartmentId: 'apt123'
      }, {
        auth: null
      })).to.be.rejectedWith('unauthenticated');
    });
    
    it('should check apartment access', async () => {
      const wrapped = test.wrap(myFunctions.getSmartHomeDevices);
      
      // Мокаем проверку доступа
      // ...
      
      await expect(wrapped({
        apartmentId: 'other-apartment'
      }, {
        auth: { uid: 'user123' }
      })).to.be.rejectedWith('permission-denied');
    });
  });
});
```

### 2. Integration тесты

```dart
void main() {
  group('Secure Tuya Service', () {
    late TuyaCloudService service;
    
    setUp(() async {
      // Настройка тестового окружения
      await Firebase.initializeApp();
      FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      
      service = TuyaCloudService(
        authService: MockAuthService(),
        loggingService: MockLoggingService(),
      );
    });
    
    test('Should handle permission errors gracefully', () async {
      // Тест на обработку ошибок доступа
      final devices = await service.fetchUserDevices();
      
      expect(devices, isEmpty);
    });
  });
}
```

## Мониторинг и логирование

### 1. Настройка алертов

```javascript
// В Cloud Function
exports.monitorTuyaUsage = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  
  // Проверяем количество запросов
  const activityLogs = await db.collection('smartHomeActivityLog')
    .where('timestamp', '>', oneHourAgo)
    .get();
  
  const stats = {
    totalRequests: activityLogs.size,
    failedRequests: activityLogs.docs.filter(doc => !doc.data().success).length,
    uniqueUsers: new Set(activityLogs.docs.map(doc => doc.data().userId)).size,
  };
  
  // Отправляем алерт если много ошибок
  if (stats.failedRequests > 10) {
    // Отправить уведомление админу
    console.error('High failure rate in Tuya requests:', stats);
  }
  
  return null;
});
```

### 2. Просмотр логов

```bash
# Просмотр логов Cloud Functions
firebase functions:log --only getSmartHomeDevices

# Фильтрация по ошибкам
firebase functions:log --only getSmartHomeDevices | grep ERROR
```

## Rollback план

Если нужно откатиться:

1. Верните старый `tuya_cloud_service.dart`
2. Обновите `service_locator.dart`
3. Выпустите hotfix версию приложения
4. НО: Смените Tuya Client Secret после утечки!

## Checklist безопасности

- [ ] Удалены все секреты из клиентского кода
- [ ] Cloud Functions настроены с правильными секретами
- [ ] Добавлена проверка прав доступа
- [ ] Настроено логирование действий
- [ ] Обновлена обработка ошибок в UI
- [ ] Протестирована работа с эмулятором
- [ ] Очищены старые данные из SharedPreferences
- [ ] Настроен мониторинг
- [ ] Документация обновлена
