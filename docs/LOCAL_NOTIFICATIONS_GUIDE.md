# Руководство по локальным уведомлениям

## Обзор

В приложении реализована система локальных push-уведомлений, которая автоматически уведомляет пользователей о получении ответов от администратора на их заявки.

## Как это работает

### 1. Отслеживание изменений в Firestore

При запуске приложения автоматически запускается слушатель изменений в коллекции `serviceRequests`:

```dart
// В ServiceRequestService
_firestore
    .collection('serviceRequests')
    .where('userId', isEqualTo: userId)
    .snapshots()
    .listen(_onServiceRequestsUpdate);
```

### 2. Проверка на наличие ответа администратора

При каждом изменении документа проверяется поле `adminResponse`:

```dart
void _checkForAdminResponse(String requestId, Map<String, dynamic> requestData) {
  final adminResponse = requestData['adminResponse'];
  if (adminResponse != null && adminResponse.toString().trim().isNotEmpty) {
    // Создаем уведомление
  }
}
```

### 3. Создание уведомления в Firestore

Создается документ в коллекции `notifications` с типом `admin_response`:

```dart
final notification = NotificationModel(
  id: 'admin_response_$requestId',
  userId: userId,
  title: 'Ответ на заявку #${requestId.substring(0, 8)}',
  message: adminResponse,
  type: 'admin_response',
  // ... другие поля
);
```

### 4. Показ локального push-уведомления

Параллельно показывается локальное push-уведомление через `flutter_local_notifications`:

```dart
await localNotificationService.showAdminResponseNotification(
  requestId: requestId,
  adminResponse: adminResponse,
  requestType: requestData['requestType'],
);
```

## Установка и настройка

### 1. Зависимости

В `pubspec.yaml` уже добавлена зависимость:

```yaml
dependencies:
  flutter_local_notifications: ^17.0.0
```

### 2. Разрешения Android

В `android/app/src/main/AndroidManifest.xml` добавлены разрешения:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### 3. Инициализация

Сервис инициализируется в `main.dart`:

```dart
// В функции initializeApp()
final localNotificationService = LocalNotificationService();
final loggingService = getIt<LoggingService>();
await localNotificationService.initialize(loggingService);
```

## Использование

### Просмотр списка заявок

1. На главном экране нажмите кнопку "Мои заявки"
2. Откроется экран со списком всех ваших заявок
3. Заявки с ответом администратора выделены синей рамкой
4. Ответ администратора отображается прямо в карточке заявки

### Получение уведомлений

1. Когда администратор добавит ответ в вашу заявку, вы получите push-уведомление
2. Уведомление появится даже если приложение свернуто (но не закрыто полностью)
3. При нажатии на уведомление откроется приложение (навигация к заявке будет добавлена позже)

## Тестирование

### Как протестировать уведомления

1. Создайте новую заявку через приложение
2. В Firestore найдите документ заявки в коллекции `serviceRequests`
3. Добавьте поле `adminResponse` с текстом ответа
4. Через несколько секунд должно появиться уведомление

### Пример структуры документа в Firestore

```json
{
  "id": "1234567890",
  "userId": "user_passport_number",
  "requestType": "plumbing",
  "description": "Течет кран",
  "status": "in-progress",
  "adminResponse": "Мастер придет завтра в 14:00",
  // ... другие поля
}
```

## Будущие улучшения (FCM)

Для получения уведомлений когда приложение полностью закрыто, потребуется настроить Firebase Cloud Messaging (FCM):

### 1. Добавить зависимость

```yaml
dependencies:
  firebase_messaging: ^14.7.0
```

### 2. Настроить FCM в Firebase Console

1. Включить Cloud Messaging в настройках проекта
2. Получить Server Key для отправки уведомлений
3. Настроить APNs для iOS

### 3. Обновить код

```dart
// Инициализация FCM
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();

// Получение токена
final token = await messaging.getToken();
// Сохранить токен в Firestore для пользователя

// Обработка уведомлений
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  // Показать локальное уведомление
});
```

### 4. Серверная часть

На сервере (Cloud Functions или ваш backend) при добавлении `adminResponse`:

```javascript
// Cloud Function
exports.sendAdminResponseNotification = functions.firestore
  .document('serviceRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    
    if (after.adminResponse && !before.adminResponse) {
      // Получить FCM токен пользователя
      // Отправить push через FCM
      await admin.messaging().send({
        token: userToken,
        notification: {
          title: 'Ответ на заявку',
          body: after.adminResponse
        }
      });
    }
  });
```

## Решение проблем

### Уведомления не появляются

1. Проверьте разрешения в настройках устройства
2. Убедитесь, что приложение не в режиме "Не беспокоить"
3. Проверьте логи через `adb logcat` для Android

### Ошибки инициализации

1. Убедитесь, что `flutter pub get` выполнен после добавления зависимости
2. Пересоберите приложение полностью (`flutter clean && flutter build`)

## Контакты

При возникновении вопросов обращайтесь к команде разработки. 