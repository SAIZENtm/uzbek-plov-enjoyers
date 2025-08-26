# Push уведомления - Интеграция админ панели с Flutter приложением

## 🚀 Как это работает

### Автоматическая отправка push уведомлений

Когда админ создает уведомление в админ панели, происходит следующее:

1. **Создание записи в Firestore** - уведомление сохраняется в коллекцию `notifications`
2. **Cloud Function триггер** - автоматически запускается функция `onNotificationCreate`
3. **Получение FCM токенов** - из документа пользователя в коллекции `users`
4. **Отправка push** - через Firebase Cloud Messaging на все устройства пользователя
5. **Показ в приложении** - Flutter приложение показывает уведомление

## 📱 Типы уведомлений

### 1. Ответ администратора на заявку
```javascript
// Автоматически отправляется при ответе на заявку
{
  type: 'admin_response',
  title: 'Ответ администратора',
  body: 'Ваша заявка рассмотрена...',
  data: {
    requestId: 'ID_заявки',
    action: 'open_request'
  }
}
```

### 2. Изменение статуса заявки
```javascript
// Автоматически при изменении статуса
{
  type: 'service_update',
  title: 'Обновление по заявке',
  body: 'Ваша заявка принята в работу',
  data: {
    requestId: 'ID_заявки',
    status: 'in_progress'
  }
}
```

### 3. Новости с push уведомлениями
```javascript
// При публикации новости с включенным push
{
  type: 'news',
  title: 'Заголовок новости',
  body: 'Краткое описание...',
  data: {
    newsId: 'ID_новости',
    action: 'open_news'
  }
}
```

## 🔧 Настройка

### 1. Деплой Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Проверка FCM токенов

FCM токены автоматически сохраняются при входе пользователя в приложение:
- Коллекция: `users`
- Документ: passport_number пользователя
- Поле: `fcmTokens` (массив токенов)

### 3. Тестирование

В Firebase Console перейдите в Functions и проверьте логи:
- `onNotificationCreate` - срабатывает при создании уведомления
- `sendPushNotification` - вызывается для отправки push

## 📊 Мониторинг

### Статус доставки в Firestore

Каждое уведомление обновляется с информацией о доставке:
```javascript
{
  pushSent: true,                    // Отправлено ли push
  pushSentAt: Timestamp,             // Время отправки
  pushSuccessCount: 1,               // Успешно доставлено
  pushFailureCount: 0                // Не доставлено
}
```

### Логи в Firebase Console

1. Откройте Firebase Console → Functions → Logs
2. Фильтруйте по функциям:
   - `onNotificationCreate` - автоматическая отправка
   - `sendPushNotification` - ручная отправка
   - `cleanupFCMTokens` - очистка невалидных токенов

## 🛠️ Troubleshooting

### Push не приходят

1. **Проверьте FCM токены**
   ```javascript
   // В Firestore Console
   users/{passport_number}/fcmTokens
   ```

2. **Проверьте логи Cloud Functions**
   - "No FCM tokens for user" - нет токенов
   - "User not found" - пользователь не найден

3. **Проверьте разрешения в приложении**
   - Пользователь должен разрешить уведомления
   - iOS требует специальную настройку

### Очистка невалидных токенов

Cloud Function `cleanupFCMTokens` автоматически запускается каждые 24 часа и удаляет невалидные токены.

## 📝 Примеры использования

### Отправка уведомления из кода админ панели

```javascript
// Простое уведомление (автоматически отправит push)
await notificationService.sendNotification({
  userId: 'AC3077863',
  title: 'Важное сообщение',
  message: 'Текст сообщения',
  type: 'system'
});

// Ответ на заявку (с push)
await notificationService.sendAdminResponse(
  userId,
  requestId,
  'Ваша заявка принята',
  'Имя админа'
);

// Новость с push для всех
await notificationService.sendNewsNotification(
  'Заголовок новости',
  'Описание',
  newsId,
  ['all'] // или ['A', 'B'] для конкретных блоков
);
```

### Прямая отправка push (без создания уведомления)

```javascript
// Одному пользователю
await fcmService.sendToUser('AC3077863', {
  title: 'Срочное уведомление',
  body: 'Текст',
  data: { custom: 'data' }
});

// Всем в блоке
await fcmService.sendToBlocks(['A', 'B'], {
  title: 'Уведомление для блоков A и B',
  body: 'Текст'
});
```

## 🔐 Безопасность

1. **Cloud Functions** проверяют аутентификацию
2. **Firestore Rules** ограничивают доступ к уведомлениям
3. **FCM токены** хранятся только для авторизованных пользователей

## 📱 Обработка в Flutter приложении

Приложение автоматически:
1. Получает push уведомления через FCM
2. Показывает их пользователю
3. При нажатии открывает нужный раздел:
   - `action: 'open_request'` → Детали заявки
   - `action: 'open_news'` → Новость
   - По умолчанию → Список уведомлений

## ✅ Готово к использованию!

Теперь все уведомления из админ панели автоматически отправляются как push в мобильное приложение! 