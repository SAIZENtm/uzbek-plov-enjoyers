# Руководство по устранению проблем с уведомлениями

## 🔍 Текущие проблемы

1. **Уведомления не отображаются в приложении**
   - Причина: Несовпадение userId в уведомлениях
   - Решение: Использование множественных идентификаторов

2. **Push-уведомления не приходят**
   - Причина: Неправильная настройка FCM
   - Решение: Проверка токенов и Cloud Functions

## 📋 Чек-лист исправлений

### 1. Проверка Firebase Configuration

```bash
# В корне проекта Flutter
cat android/app/google-services.json | grep project_id
# Должно быть: "project_id": "newport-23a19"

# В админ-панели
cat NewportAdmin/client/src/lib/firebase.ts | grep projectId
# Должно быть: projectId: "newport-23a19"
```

### 2. Проверка FCM токена

В Flutter приложении добавьте в `main.dart`:

```dart
// После инициализации Firebase
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');
```

### 3. Тестирование уведомлений

#### A. Через тестовую страницу:
1. Откройте `test_notification.html` в браузере
2. Введите userId (паспорт или телефон пользователя)
3. Создайте тестовое уведомление

#### B. Через Firebase Console:
1. Firebase Console → Cloud Messaging → Compose notification
2. Добавьте заголовок и текст
3. В Additional options → Custom data добавьте:
   - `type`: `admin_response`
   - `requestId`: `test123`
4. Отправьте по токену (из п.2)

### 4. Проверка Firestore правил

```javascript
// firestore.rules должны содержать:
match /notifications/{notificationId} {
  allow read: if true; // Временно для отладки
  allow create: if request.auth != null;
}
```

### 5. Исправление поиска уведомлений

В `lib/core/services/notification_service.dart`:
- Уже добавлена поддержка поиска по паспорту и телефону (с/без +)
- Проверьте логи: `loggingService.info('Starting Firestore query for identifiers: $userIdentifiers');`

### 6. Проверка Cloud Functions

```bash
# Проверка логов функций
firebase functions:log --project newport-23a19

# Перезапуск функций (если на Blaze)
firebase deploy --only functions
```

## 🛠️ Постоянные решения

### 1. Унификация userId

В `NewportAdmin/client/src/lib/notificationService.ts`:

```typescript
async sendNotification(notificationData: NotificationData): Promise<Notification> {
  // Всегда используем паспорт как основной userId
  const primaryUserId = await this.getPrimaryUserId(notificationData.userId);
  
  const notification = {
    ...notificationData,
    userId: primaryUserId,
    // Добавляем альтернативные идентификаторы
    alternateIds: [notificationData.userId, phoneWithoutPlus]
  };
}
```

### 2. Исправление FCM для Android 13+

В `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

В Flutter:

```dart
// Запрос разрешений для Android 13+
if (Platform.isAndroid) {
  final androidImplementation = 
    FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  
  final granted = await androidImplementation?.requestNotificationsPermission();
}
```

### 3. Отладка FCM сообщений

```dart
// В main.dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('=== FOREGROUND MESSAGE ===');
  print('Message ID: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
  print('========================');
});
```

## 📱 Тестирование на устройстве

### Android:
1. Убедитесь, что приложение НЕ в режиме экономии батареи
2. Проверьте настройки уведомлений: Настройки → Приложения → Newport → Уведомления
3. Для Xiaomi/Huawei: дайте разрешение на автозапуск

### iOS:
1. Убедитесь, что в Xcode включены Push Notifications capabilities
2. Проверьте APNs сертификаты в Firebase Console
3. Тестируйте на реальном устройстве (не симуляторе)

## 🚀 Финальная проверка

1. **Создайте заявку из приложения**
2. **В админ-панели ответьте на заявку**
3. **Проверьте:**
   - [ ] Уведомление появилось во вкладке "Уведомления"
   - [ ] Push-уведомление пришло на устройство
   - [ ] При нажатии на push открывается приложение

## 🆘 Если ничего не помогает

1. **Проверьте проект Firebase:**
   ```bash
   firebase projects:list
   firebase use newport-23a19
   ```

2. **Пересоздайте google-services.json:**
   - Firebase Console → Project Settings → Your apps → Android app
   - Скачайте google-services.json
   - Замените в `android/app/`

3. **Очистите кеш:**
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install
   flutter run --verbose
   ```

4. **Включите отладку FCM:**
   ```dart
   FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
     alert: true,
     badge: true,
     sound: true,
   );
   ```

## 📞 Контакты поддержки

- Firebase Support: https://firebase.google.com/support
- Flutter GitHub: https://github.com/flutter/flutter/issues
- Stack Overflow: тег `flutter-fcm` 