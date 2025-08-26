# 📱 Интеграция с мобильным приложением - Руководство для веб-разработчика

## 🎯 Цель интеграции

Мобильное приложение **Newport Resident** автоматически отправляет заявки на обслуживание на ваш веб-сайт через HTTP webhook. **Фотографии загружаются в Firebase Storage** и передаются как URL-ссылки.

## 📊 Структура данных заявки

### Формат JSON запроса

```json
{
  "requestSource": "mobile_app",
  "userName": "OTABEK USKENBAYEV SAIDAXMAD O'G'LI",
  "userPhone": "+998999357706",
  "userId": "AB1234567",
  "apartmentNumber": "203",
  "block": "F",
  "requestType": "plumbing",
  "description": "Протекает кран в ванной комнате",
  "priority": "High",
  "contactMethod": "phone",
  "preferredTime": "2025-07-09T14:00:00+05:00",
  "photos": [
    "https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123...",
    "https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_2_1752172461965.jpg?alt=media&token=def456..."
  ],
  "status": "new",
  "createdAt": "2025-07-09T10:38:00+05:00",
  "updatedAt": "2025-07-09T10:38:00+05:00",
  "additionalData": {
    "requestSource": "mobile_app",
    "userPhone": "+998999357706",
    "userName": "OTABEK USKENBAYEV SAIDAXMAD O'G'LI"
  }
}
```

## 🔑 Ключевые поля для идентификации пользователя

### 1. **userId** - Уникальный идентификатор пользователя
- **Источник**: Номер паспорта пользователя или ID квартиры
- **Пример**: `"AB1234567"` или `"apartment_123"`
- **Важно**: Это основной идентификатор для связи заявки с пользователем

### 2. **userPhone** - Номер телефона
- **Источник**: Телефон из профиля пользователя или квартиры
- **Пример**: `"+998999357706"`
- **Использование**: Для связи с пользователем

### 3. **userName** - Полное имя
- **Источник**: Имя из профиля пользователя или квартиры
- **Пример**: `"OTABEK USKENBAYEV SAIDAXMAD O'G'LI"`

## 📸 Система фотографий

### Структура URL фотографий

```
https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests/{requestId}/images/{imageName}?alt=media&token={token}
```

### Компоненты URL:
- **requestId**: Уникальный ID заявки (timestamp)
- **imageName**: Имя файла (например: `image_1_1752172461965.jpg`)
- **token**: Токен доступа Firebase Storage

### Примеры URL:
```
https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123...
```

## 🗄️ Структура базы данных

### Таблица `service_requests`

```sql
CREATE TABLE service_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mobile_request_id VARCHAR(255) UNIQUE, -- ID из мобильного приложения
    user_id VARCHAR(255) NOT NULL,         -- userId из мобильного приложения
    user_name VARCHAR(255),
    user_phone VARCHAR(50),
    apartment_number VARCHAR(50),
    block VARCHAR(50),
    request_type VARCHAR(100),
    description TEXT,
    priority VARCHAR(50),
    contact_method VARCHAR(50),
    preferred_time DATETIME,
    photos JSON,                           -- Массив URL фотографий
    status VARCHAR(50) DEFAULT 'new',
    created_at DATETIME,
    updated_at DATETIME,
    request_source VARCHAR(50) DEFAULT 'mobile_app',
    additional_data JSON,
    INDEX idx_user_id (user_id),
    INDEX idx_mobile_request_id (mobile_request_id),
    INDEX idx_status (status)
);
```

## 🔧 Реализация webhook

### PHP (Laravel/CodeIgniter)

```php
<?php
// api/service-requests.php

header('Content-Type: application/json');

// Проверка API ключа
$apiKey = $_SERVER['HTTP_X_API_KEY'] ?? '';
if ($apiKey !== 'your-secret-api-key') {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

// Получение данных
$input = json_decode(file_get_contents('php://input'), true);

// Валидация обязательных полей
$requiredFields = ['userId', 'apartmentNumber', 'block', 'requestType', 'description'];
foreach ($requiredFields as $field) {
    if (empty($input[$field])) {
        http_response_code(400);
        echo json_encode(['error' => "Missing required field: $field"]);
        exit;
    }
}

try {
    $pdo = new PDO("mysql:host=localhost;dbname=your_database", $username, $password);
    
    // Проверяем, не существует ли уже заявка с таким mobile_request_id
    $stmt = $pdo->prepare("SELECT id FROM service_requests WHERE mobile_request_id = ?");
    $stmt->execute([$input['id'] ?? null]);
    
    if ($stmt->fetch()) {
        // Заявка уже существует - обновляем
        $stmt = $pdo->prepare("
            UPDATE service_requests SET
                user_name = ?, user_phone = ?, apartment_number = ?, block = ?,
                request_type = ?, description = ?, priority = ?, contact_method = ?,
                preferred_time = ?, photos = ?, status = ?, updated_at = NOW(),
                additional_data = ?
            WHERE mobile_request_id = ?
        ");
        
        $stmt->execute([
            $input['userName'],
            $input['userPhone'],
            $input['apartmentNumber'],
            $input['block'],
            $input['requestType'],
            $input['description'],
            $input['priority'],
            $input['contactMethod'],
            $input['preferredTime'],
            json_encode($input['photos'] ?? []),
            $input['status'],
            json_encode($input['additionalData'] ?? []),
            $input['id']
        ]);
        
        echo json_encode(['success' => true, 'action' => 'updated']);
    } else {
        // Создаем новую заявку
        $stmt = $pdo->prepare("
            INSERT INTO service_requests 
            (mobile_request_id, user_id, user_name, user_phone, apartment_number, 
             block, request_type, description, priority, contact_method, 
             preferred_time, photos, status, created_at, updated_at, 
             request_source, additional_data)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        
        $stmt->execute([
            $input['id'],
            $input['userId'],
            $input['userName'],
            $input['userPhone'],
            $input['apartmentNumber'],
            $input['block'],
            $input['requestType'],
            $input['description'],
            $input['priority'],
            $input['contactMethod'],
            $input['preferredTime'],
            json_encode($input['photos'] ?? []),
            $input['status'] ?? 'new',
            $input['createdAt'],
            $input['updatedAt'],
            'mobile_app',
            json_encode($input['additionalData'] ?? [])
        ]);
        
        echo json_encode(['success' => true, 'id' => $pdo->lastInsertId()]);
    }
    
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['error' => 'Database error: ' . $e->getMessage()]);
}
?>
```

### Node.js (Express)

```javascript
const express = require('express');
const mysql = require('mysql2/promise');
const app = express();

app.use(express.json());

// Middleware для проверки API ключа
const checkApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (apiKey !== 'your-secret-api-key') {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};

// Обработка заявок от мобильного приложения
app.post('/api/service-requests', checkApiKey, async (req, res) => {
    try {
        const input = req.body;
        
        // Валидация обязательных полей
        const requiredFields = ['userId', 'apartmentNumber', 'block', 'requestType', 'description'];
        for (const field of requiredFields) {
            if (!input[field]) {
                return res.status(400).json({ error: `Missing required field: ${field}` });
            }
        }
        
        // Подключение к базе данных
        const connection = await mysql.createConnection({
            host: 'localhost',
            user: 'username',
            password: 'password',
            database: 'your_database'
        });
        
        // Проверяем существование заявки
        const [existing] = await connection.execute(
            'SELECT id FROM service_requests WHERE mobile_request_id = ?',
            [input.id]
        );
        
        if (existing.length > 0) {
            // Обновляем существующую заявку
            await connection.execute(`
                UPDATE service_requests SET
                    user_name = ?, user_phone = ?, apartment_number = ?, block = ?,
                    request_type = ?, description = ?, priority = ?, contact_method = ?,
                    preferred_time = ?, photos = ?, status = ?, updated_at = NOW(),
                    additional_data = ?
                WHERE mobile_request_id = ?
            `, [
                input.userName,
                input.userPhone,
                input.apartmentNumber,
                input.block,
                input.requestType,
                input.description,
                input.priority,
                input.contactMethod,
                input.preferredTime,
                JSON.stringify(input.photos || []),
                input.status,
                JSON.stringify(input.additionalData || {}),
                input.id
            ]);
            
            res.json({ success: true, action: 'updated' });
        } else {
            // Создаем новую заявку
            const [result] = await connection.execute(`
                INSERT INTO service_requests 
                (mobile_request_id, user_id, user_name, user_phone, apartment_number, 
                 block, request_type, description, priority, contact_method, 
                 preferred_time, photos, status, created_at, updated_at, 
                 request_source, additional_data)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [
                input.id,
                input.userId,
                input.userName,
                input.userPhone,
                input.apartmentNumber,
                input.block,
                input.requestType,
                input.description,
                input.priority,
                input.contactMethod,
                input.preferredTime,
                JSON.stringify(input.photos || []),
                input.status || 'new',
                input.createdAt,
                input.updatedAt,
                'mobile_app',
                JSON.stringify(input.additionalData || {})
            ]);
            
            res.json({ success: true, id: result.insertId });
        }
        
        await connection.end();
        
    } catch (error) {
        console.error('Error processing service request:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

app.listen(3000, () => {
    console.log('Server running on port 3000');
});
```

## 🔍 Поиск заявок по пользователю

### По userId (рекомендуется)

```sql
SELECT * FROM service_requests 
WHERE user_id = 'AB1234567' 
ORDER BY created_at DESC;
```

### По номеру телефона

```sql
SELECT * FROM service_requests 
WHERE user_phone = '+998999357706' 
ORDER BY created_at DESC;
```

### По номеру квартиры и блоку

```sql
SELECT * FROM service_requests 
WHERE apartment_number = '203' AND block = 'F' 
ORDER BY created_at DESC;
```

## 📱 Настройка в мобильном приложении

### 1. Обновите webhook URL

В файле `lib/core/services/service_request_service.dart`:

```dart
static const String _webhookUrl = 'https://your-website.com/api/service-requests';
```

### 2. Установите API ключ

```dart
'X-API-Key': 'your-secret-api-key',
```

## 🛡️ Безопасность

### 1. API ключ
- Используйте сложный API ключ
- Храните его в переменных окружения
- Регулярно обновляйте

### 2. Валидация данных
- Проверяйте все обязательные поля
- Валидируйте формат URL фотографий
- Ограничивайте размер запросов

### 3. Обработка ошибок
- Логируйте все ошибки
- Возвращайте понятные сообщения об ошибках
- Не раскрывайте внутреннюю структуру БД

## 📊 Мониторинг

### Логи для отслеживания

```php
// Логирование входящих запросов
error_log("Mobile app request: " . json_encode($input));
```

### Метрики для отслеживания

- Количество заявок от мобильного приложения
- Время обработки запросов
- Количество ошибок
- Популярные типы заявок

## 🔄 Обратная связь

### Отправка статуса заявки обратно в приложение

Для отправки обновлений статуса обратно в мобильное приложение используйте Firebase Cloud Functions или HTTP webhook.

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи сервера
2. Убедитесь в правильности API ключа
3. Проверьте формат данных
4. Убедитесь в доступности Firebase Storage URL

---

**Важно**: Все фотографии загружаются в Firebase Storage и доступны по URL. Убедитесь, что ваш сервер может обращаться к этим URL для отображения изображений. 