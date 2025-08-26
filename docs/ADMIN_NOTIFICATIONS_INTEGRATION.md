# Интеграция уведомлений администратора

## Обзор

Система автоматически отслеживает изменения в коллекции `serviceRequests` и создает уведомления когда:
1. Администратор добавляет ответ в поле `adminResponse`
2. Изменяется статус заявки

## Структура заявки в Firestore

Заявки сохраняются в коллекции `serviceRequests` со следующей структурой:

```json
{
  "id": "1752172461965",
  "userId": "unknown",
  "userName": "OTABEK USKENBAYEV SAIDAXMAD O'G'LI",
  "userPhone": "+998999357706",
  "apartmentNumber": "123",
  "block": "F",
  "requestType": "plumbing",
  "description": "frg",
  "priority": "Medium",
  "contactMethod": "notification",
  "preferredTime": "2025-07-11T09:45:00.000",
  "status": "in-progress",
  "adminResponse": "хорошо",
  "photos": [
    "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=400&h=300&fit=crop"
  ],
  "createdAt": "2025-07-10T23:34:21.965921",
  "updatedAt": "July 10, 2025 at 11:55:00 PM UTC+5",
  "requestSource": "mobile_app",
  "additionalData": {}
}
```

## Автоматические уведомления

### 1. Ответ администратора

Когда администратор добавляет или изменяет поле `adminResponse`, автоматически создается уведомление:

```json
{
  "id": "admin_response_1752172461965_1673123456789",
  "userId": "AB1234567", // passport_number пользователя
  "title": "Ответ на заявку #17521724",
  "message": "хорошо", // содержимое поля adminResponse
  "type": "admin_response",
  "createdAt": "2025-01-15T10:30:00Z",
  "readAt": null,
  "isRead": false,
  "data": {
    "requestId": "1752172461965",
    "requestType": "plumbing",
    "priority": "Medium",
    "apartmentNumber": "123",
    "block": "F",
    "status": "in-progress"
  },
  "relatedRequestId": "1752172461965",
  "adminName": "Администратор",
  "imageUrl": null
}
```

### 2. Изменение статуса

При изменении статуса заявки создается системное уведомление:

```json
{
  "id": "status_update_1752172461965_1673123456789",
  "userId": "AB1234567",
  "title": "Обновление статуса заявки",
  "message": "Ваша заявка принята в работу",
  "type": "service_update",
  "createdAt": "2025-01-15T10:30:00Z",
  "readAt": null,
  "isRead": false,
  "data": {
    "requestId": "1752172461965",
    "requestType": "plumbing",
    "priority": "Medium",
    "apartmentNumber": "123",
    "block": "F",
    "oldStatus": "pending",
    "newStatus": "in-progress"
  },
  "relatedRequestId": "1752172461965",
  "adminName": "Система управления",
  "imageUrl": null
}
```

## Cloud Functions

### Основная функция отслеживания

```javascript
exports.onServiceRequestUpdate = functions.firestore
  .document('serviceRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const requestId = context.params.requestId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Проверяем изменения в adminResponse
    const adminResponseAdded = !beforeData.adminResponse && afterData.adminResponse;
    const adminResponseUpdated = beforeData.adminResponse !== afterData.adminResponse && afterData.adminResponse;
    
    // Проверяем изменение статуса
    const statusChanged = beforeData.status !== afterData.status;

    if (adminResponseAdded || adminResponseUpdated) {
      await createNotificationForAdminResponse(requestId, afterData);
    }

    if (statusChanged) {
      await createNotificationForStatusChange(requestId, afterData, beforeData.status);
    }
  });
```

### Определение userId

Функция автоматически определяет `userId` (passport_number) пользователя:

1. Если `userId` в заявке не пустой и не "unknown" - использует его
2. Иначе ищет пользователя по номеру телефона в коллекции `users` -> `apartments`
3. Если не найден - использует номер телефона как fallback

```javascript
async function findUserIdByPhone(phoneNumber) {
  const blocksSnapshot = await db.collection('users').get();
  
  for (const blockDoc of blocksSnapshot.docs) {
    const apartmentsSnapshot = await blockDoc.ref.collection('apartments').get();
    
    for (const apartmentDoc of apartmentsSnapshot.docs) {
      const apartmentData = apartmentDoc.data();
      if (apartmentData.phone === phoneNumber) {
        return apartmentData.passport_number || apartmentData.passportNumber;
      }
    }
  }
  
  return null;
}
```

## Интеграция с сайтом администратора

### Простое обновление через Firestore

Администратор может добавить ответ прямо в Firestore:

```javascript
// Обновление заявки с ответом администратора
await db.collection('serviceRequests')
  .doc('1752172461965')
  .update({
    adminResponse: 'Мастер приедет завтра в 14:00. Подготовьте доступ к сантехнике.',
    status: 'in-progress',
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

// Уведомление создастся автоматически!
```

### Через веб-интерфейс

```html
<!-- Форма для ответа администратора -->
<form id="adminResponseForm">
  <input type="hidden" id="requestId" value="1752172461965">
  
  <div class="form-group">
    <label for="adminResponse">Ответ администратора:</label>
    <textarea id="adminResponse" rows="4" cols="50" 
              placeholder="Введите ваш ответ..."></textarea>
  </div>
  
  <div class="form-group">
    <label for="status">Статус заявки:</label>
    <select id="status">
      <option value="pending">Ожидает</option>
      <option value="in-progress">В работе</option>
      <option value="completed">Выполнено</option>
      <option value="cancelled">Отменено</option>
    </select>
  </div>
  
  <button type="submit">Отправить ответ</button>
</form>

<script>
document.getElementById('adminResponseForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  
  const requestId = document.getElementById('requestId').value;
  const adminResponse = document.getElementById('adminResponse').value;
  const status = document.getElementById('status').value;
  
  try {
    // Обновляем заявку в Firestore
    await db.collection('serviceRequests').doc(requestId).update({
      adminResponse: adminResponse,
      status: status,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    alert('Ответ отправлен! Уведомление создано автоматически.');
  } catch (error) {
    console.error('Ошибка:', error);
    alert('Произошла ошибка при отправке ответа.');
  }
});
</script>
```

## Типы статусов и сообщений

```javascript
const statusMessages = {
  'pending': 'Ваша заявка получена и ожидает обработки',
  'in-progress': 'Ваша заявка принята в работу',
  'completed': 'Ваша заявка выполнена',
  'cancelled': 'Ваша заявка отменена',
  'on-hold': 'Ваша заявка приостановлена'
};
```

## Развертывание Cloud Functions

```bash
# Установка зависимостей
cd functions
npm install

# Развертывание функций
firebase deploy --only functions

# Просмотр логов
firebase functions:log
```

## Тестирование

### 1. Тестирование через Firestore Console

1. Откройте Firebase Console
2. Перейдите в Firestore Database
3. Найдите коллекцию `serviceRequests`
4. Выберите любую заявку
5. Добавьте или измените поле `adminResponse`
6. Сохраните изменения
7. Проверьте, что уведомление появилось в коллекции `notifications`

### 2. Тестирование в приложении

1. Откройте мобильное приложение
2. Войдите под пользователем, у которого есть заявки
3. Измените `adminResponse` в Firestore Console
4. Проверьте, что на иконке уведомлений появился красный кружок
5. Откройте экран уведомлений
6. Убедитесь, что новое уведомление отображается

### 3. Создание тестового уведомления

```bash
# Через Cloud Function
curl -X GET "https://your-project.cloudfunctions.net/createTestNotification?userId=AB1234567"
```

## Мониторинг и логи

### Просмотр логов Cloud Functions

```bash
# Все логи
firebase functions:log

# Логи конкретной функции
firebase functions:log --only onServiceRequestUpdate

# Логи в реальном времени
firebase functions:log --follow
```

### Типичные логи

```
INFO: Service request 1752172461965 updated
INFO: Admin response detected for request 1752172461965: хорошо
INFO: Admin response notification created: admin_response_1752172461965_1673123456789 for user: AB1234567
```

## Безопасность

1. **Правила Firestore**: Только аутентифицированные пользователи могут читать свои уведомления
2. **Cloud Functions**: Автоматически выполняются с правами администратора
3. **Логирование**: Все операции записываются в логи для аудита

## Troubleshooting

### Уведомления не создаются

1. **Проверьте логи Cloud Functions**:
   ```bash
   firebase functions:log --only onServiceRequestUpdate
   ```

2. **Убедитесь, что поле изменилось**:
   - `adminResponse` должно быть добавлено или изменено
   - `status` должен измениться на новое значение

3. **Проверьте userId**:
   - Если `userId` = "unknown", функция ищет пользователя по телефону
   - Убедитесь, что телефон есть в базе данных

### Приложение не показывает уведомления

1. **Проверьте аутентификацию**: Пользователь должен быть залогинен
2. **Проверьте userId**: Должен совпадать с тем, что в уведомлении
3. **Перезапустите приложение**: Иногда помогает перезапуск

## Планы развития

1. **Push-уведомления**: Интеграция с Firebase Cloud Messaging
2. **Email уведомления**: Дублирование на почту
3. **SMS уведомления**: Для критически важных сообщений
4. **Богатые уведомления**: С изображениями и кнопками действий 