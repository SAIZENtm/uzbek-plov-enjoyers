# Интеграция с внешним сайтом (Webhook)

## Обзор

Приложение Newport Resident автоматически отправляет заявки на обслуживание на внешний сайт управляющей компании через HTTP webhook.

## Процесс интеграции

Когда пользователь подает заявку в приложении:

1. **Сохранение в Firebase** - Заявка сохраняется в Firestore
2. **Отправка на внешний сайт** - Данные отправляются HTTP POST запросом
3. **Локальное сохранение** - Заявка сохраняется локально для офлайн режима

## Настройка webhook URL

### 1. Обновите URL в коде

В файле `lib/core/services/service_request_service.dart`:

```dart
static const String _webhookUrl = 'https://your-website.com/api/service-requests';
```

Замените на URL вашего сайта.

### 2. Настройте API ключ

В том же файле:

```dart
'X-API-Key': 'your-api-key', // Замените на ваш API ключ
```

## Формат данных

Приложение отправляет следующие данные в JSON формате:

```json
{
  "userId": "AB1234567",
  "apartmentNumber": "203",
  "block": "F BLOK",
  "requestType": "Electrical",
  "description": "The light in the kitchen stopped working.",
  "priority": "High",
  "contactMethod": "Phone",
  "preferredTime": "2025-07-09T14:00:00+05:00",
  "photos": [
    "https://firebasestorage.googleapis.com/v0/b/projectid/o/images%2Freq1234.jpg"
  ],
  "status": "new",
  "createdAt": "2025-07-09T10:38:00+05:00",
  "updatedAt": "2025-07-09T10:38:00+05:00"
}
```

## Поля данных

| Поле | Тип | Описание |
|------|-----|----------|
| `userId` | string | ID пользователя (номер паспорта) |
| `apartmentNumber` | string | Номер квартиры |
| `block` | string | Блок (A, B, C, D, E, F) |
| `requestType` | string | Тип заявки (Electrical, Plumbing, HVAC, General) |
| `description` | string | Описание проблемы |
| `priority` | string | Приоритет (Low, Medium, High, Emergency) |
| `contactMethod` | string | Способ связи (Phone, Email, Message) |
| `preferredTime` | string | Предпочтительное время обслуживания (ISO 8601) |
| `photos` | array | Массив URL фотографий |
| `status` | string | Статус заявки (всегда "new" при создании) |
| `createdAt` | string | Время создания (ISO 8601) |
| `updatedAt` | string | Время последнего обновления (ISO 8601) |

## Требования к серверу

### HTTP метод
- **POST** запрос

### Заголовки
- `Content-Type: application/json`
- `X-API-Key: your-api-key`

### Ответ сервера
- **200 OK** или **201 Created** - заявка успешно получена
- **400 Bad Request** - неверный формат данных
- **401 Unauthorized** - неверный API ключ
- **500 Internal Server Error** - ошибка сервера

## Пример серверного кода

### PHP
```php
<?php
header('Content-Type: application/json');

// Проверка API ключа
$api_key = $_SERVER['HTTP_X_API_KEY'] ?? '';
if ($api_key !== 'your-api-key') {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Получение данных
$input = json_decode(file_get_contents('php://input'), true);

// Валидация данных
$required_fields = ['userId', 'apartmentNumber', 'block', 'requestType', 'description'];
foreach ($required_fields as $field) {
    if (!isset($input[$field]) || empty($input[$field])) {
        http_response_code(400);
        echo json_encode(['error' => "Missing required field: $field"]);
        exit;
    }
}

// Сохранение в базу данных
try {
    $pdo = new PDO("mysql:host=localhost;dbname=newport", $username, $password);
    
    $stmt = $pdo->prepare("
        INSERT INTO service_requests 
        (user_id, apartment_number, block, request_type, description, priority, contact_method, preferred_time, photos, status, created_at, updated_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    
    $stmt->execute([
        $input['userId'],
        $input['apartmentNumber'],
        $input['block'],
        $input['requestType'],
        $input['description'],
        $input['priority'],
        $input['contactMethod'],
        $input['preferredTime'],
        json_encode($input['photos']),
        $input['status'],
        $input['createdAt'],
        $input['updatedAt']
    ]);
    
    http_response_code(201);
    echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?>
```

### Node.js (Express)
```javascript
const express = require('express');
const mysql = require('mysql2');
const app = express();

app.use(express.json());

// Проверка API ключа
const checkApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== 'your-api-key') {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};

// Обработка заявок
app.post('/api/service-requests', checkApiKey, (req, res) => {
    const requiredFields = ['userId', 'apartmentNumber', 'block', 'requestType', 'description'];
    
    for (const field of requiredFields) {
        if (!req.body[field]) {
            return res.status(400).json({ error: `Missing required field: ${field}` });
        }
    }
    
    const connection = mysql.createConnection({
        host: 'localhost',
        user: 'username',
        password: 'password',
        database: 'newport'
    });
    
    const query = `
        INSERT INTO service_requests 
        (user_id, apartment_number, block, request_type, description, priority, contact_method, preferred_time, photos, status, created_at, updated_at) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;
    
    connection.execute(query, [
        req.body.userId,
        req.body.apartmentNumber,
        req.body.block,
        req.body.requestType,
        req.body.description,
        req.body.priority,
        req.body.contactMethod,
        req.body.preferredTime,
        JSON.stringify(req.body.photos),
        req.body.status,
        req.body.createdAt,
        req.body.updatedAt
    ], (err, results) => {
        if (err) {
            return res.status(500).json({ error: 'Database error: ' + err.message });
        }
        
        res.status(201).json({ success: true, id: results.insertId });
    });
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

## Обработка ошибок

### В приложении
- Если внешний сайт недоступен, заявка все равно сохраняется в Firebase
- Реализована система повторных попыток
- Пользователь увидит уведомление о успешной отправке

### На сервере
- Возвращайте корректные HTTP коды ошибок
- Логируйте все запросы для отладки
- Уведомляйте администратора о проблемах

## Тестирование

### Проверка webhook
```bash
curl -X POST https://your-website.com/api/service-requests \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d '{
    "userId": "test123",
    "apartmentNumber": "101",
    "block": "F BLOK",
    "requestType": "Electrical",
    "description": "Test request",
    "priority": "Low",
    "contactMethod": "Phone",
    "preferredTime": "2025-07-09T14:00:00+05:00",
    "photos": [],
    "status": "new",
    "createdAt": "2025-07-09T10:38:00+05:00",
    "updatedAt": "2025-07-09T10:38:00+05:00"
  }'
```

### Логи для отладки
В файле `lib/core/services/service_request_service.dart` включены подробные логи:
- Успешная отправка в Firebase
- Успешная отправка на внешний сайт
- Ошибки при отправке

## Безопасность

1. **Используйте HTTPS** для всех webhook URL
2. **Проверяйте API ключи** на сервере
3. **Валидируйте данные** перед сохранением
4. **Логируйте все запросы** для аудита
5. **Ограничьте доступ** к API по IP адресам если возможно

## Мониторинг

Рекомендуется настроить мониторинг:
- Количество успешных/неуспешных заявок
- Время ответа webhook
- Ошибки интеграции
- Уведомления администратора 