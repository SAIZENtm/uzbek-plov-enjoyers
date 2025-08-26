# Настройка отправки уведомлений из админ панели

## Структура уведомления в Firestore

Уведомления должны сохраняться в коллекцию `notifications` в Firestore со следующей структурой:

```json
{
  "id": "unique_notification_id",
  "userId": "AC3077863", // Номер паспорта пользователя
  "title": "Заголовок уведомления",
  "message": "Текст уведомления",
  "type": "admin_response", // Тип: admin_response, system, service_update
  "createdAt": "2024-01-15T10:30:00.000Z", // ISO 8601 формат
  "readAt": null, // null пока не прочитано
  "isRead": false,
  "data": {}, // Дополнительные данные
  "relatedRequestId": "request_id_123", // ID связанной заявки (опционально)
  "adminName": "Иван Петров", // Имя администратора (опционально)
  "imageUrl": null // URL изображения (опционально)
}
```

## Типы уведомлений

1. **admin_response** - Ответ администратора на заявку
2. **system** - Системные уведомления
3. **service_update** - Обновления по услугам
4. **news** - Новости (если используется)

## API для админ панели

### 1. Создание уведомления

```javascript
// Функция для отправки уведомления
async function sendNotification(notificationData) {
  try {
    const notification = {
      id: generateUniqueId(), // Генерируем уникальный ID
      userId: notificationData.userId, // Номер паспорта пользователя
      title: notificationData.title,
      message: notificationData.message,
      type: notificationData.type || 'system',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: notificationData.data || {},
      relatedRequestId: notificationData.relatedRequestId || null,
      adminName: notificationData.adminName || null,
      imageUrl: notificationData.imageUrl || null
    };

    // Сохраняем в Firestore
    await db.collection('notifications').doc(notification.id).set(notification);
    
    console.log('Notification sent successfully:', notification.id);
    return notification;
  } catch (error) {
    console.error('Error sending notification:', error);
    throw error;
  }
}
```

### 2. Отправка уведомления конкретному пользователю

```javascript
// Пример отправки ответа администратора
async function sendAdminResponse(userId, requestId, message, adminName) {
  return await sendNotification({
    userId: userId,
    title: 'Ответ администратора',
    message: message,
    type: 'admin_response',
    relatedRequestId: requestId,
    adminName: adminName
  });
}
```

### 3. Массовая отправка уведомлений

```javascript
// Отправка системного уведомления всем пользователям
async function sendSystemNotificationToAll(title, message) {
  try {
    // Получаем всех пользователей
    const usersSnapshot = await db.collection('users').get();
    
    const promises = usersSnapshot.docs.map(userDoc => {
      const userData = userDoc.data();
      const userId = userData.passport_number || userData.passportNumber;
      
      if (userId) {
        return sendNotification({
          userId: userId,
          title: title,
          message: message,
          type: 'system'
        });
      }
    });
    
    await Promise.all(promises);
    console.log('System notification sent to all users');
  } catch (error) {
    console.error('Error sending system notification:', error);
    throw error;
  }
}
```

## Настройка Firebase Functions (опционально)

Если вы хотите использовать Firebase Functions для автоматической отправки уведомлений:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Функция для отправки уведомления при создании заявки
exports.onServiceRequestCreate = functions.firestore
  .document('service_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = context.params.requestId;
    
    // Отправляем уведомление пользователю
    await admin.firestore().collection('notifications').add({
      id: admin.firestore().collection('notifications').doc().id,
      userId: requestData.userId,
      title: 'Заявка принята',
      message: `Ваша заявка #${requestId.substring(0, 8)} принята в обработку`,
      type: 'service_update',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {},
      relatedRequestId: requestId,
      adminName: null,
      imageUrl: null
    });
  });
```

## Настройка правил безопасности Firestore

Убедитесь, что в `firestore.rules` есть правила для уведомлений:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Правила для уведомлений
    match /notifications/{notificationId} {
      // Пользователи могут читать только свои уведомления
      allow read: if request.auth != null && 
                     resource.data.userId == request.auth.token.passport_number;
      
      // Только админы могут создавать уведомления
      allow create: if request.auth != null && 
                       request.auth.token.admin == true;
      
      // Пользователи могут обновлять только статус прочтения
      allow update: if request.auth != null && 
                       resource.data.userId == request.auth.token.passport_number &&
                       request.resource.data.keys().hasOnly(['isRead', 'readAt']);
    }
  }
}
```

## Тестирование

### 1. Создание тестового уведомления

```javascript
// Тест в консоли браузера или Node.js
const testNotification = {
  userId: 'AC3077863', // Замените на реальный ID пользователя
  title: 'Тестовое уведомление',
  message: 'Это тестовое уведомление для проверки системы',
  type: 'system',
  adminName: 'Тест Админ'
};

sendNotification(testNotification);
```

### 2. Проверка в приложении

После отправки уведомления:
1. Откройте приложение
2. Перейдите в раздел "Уведомления"
3. Уведомление должно появиться в списке
4. Проверьте, что оно корректно отображается

## Интеграция с существующей админ панелью

Если у вас уже есть админ панель, добавьте следующие функции:

### 1. Форма для отправки уведомлений

```html
<form id="notificationForm">
  <input type="text" id="userId" placeholder="ID пользователя" required>
  <input type="text" id="title" placeholder="Заголовок" required>
  <textarea id="message" placeholder="Сообщение" required></textarea>
  <select id="type">
    <option value="system">Системное</option>
    <option value="admin_response">Ответ админа</option>
    <option value="service_update">Обновление услуги</option>
  </select>
  <input type="text" id="relatedRequestId" placeholder="ID заявки (опционально)">
  <button type="submit">Отправить</button>
</form>
```

### 2. JavaScript для отправки

```javascript
document.getElementById('notificationForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const formData = new FormData(e.target);
  const notificationData = {
    userId: formData.get('userId'),
    title: formData.get('title'),
    message: formData.get('message'),
    type: formData.get('type'),
    relatedRequestId: formData.get('relatedRequestId') || null,
    adminName: getCurrentAdminName() // Функция для получения имени текущего админа
  };
  
  try {
    await sendNotification(notificationData);
    alert('Уведомление отправлено успешно!');
    e.target.reset();
  } catch (error) {
    alert('Ошибка при отправке уведомления: ' + error.message);
  }
});
```

## Мониторинг и логирование

Рекомендуется добавить логирование для отслеживания отправленных уведомлений:

```javascript
// Функция логирования
async function logNotification(notification, status) {
  await db.collection('notification_logs').add({
    notificationId: notification.id,
    userId: notification.userId,
    title: notification.title,
    type: notification.type,
    status: status, // 'sent', 'failed', 'read'
    timestamp: new Date().toISOString(),
    adminName: notification.adminName
  });
}
```

Эта документация поможет настроить отправку уведомлений из вашей админ панели в мобильное приложение. 