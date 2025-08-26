# 🚀 Быстрая интеграция с мобильным приложением

## 📸 Как работают фотографии

### 1. **Загрузка фотографий**
- Фотографии загружаются в **Firebase Storage**
- Путь: `service_requests/{requestId}/images/{imageName}`
- Возвращается **URL для доступа**

### 2. **Структура URL**
```
https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123...
```

### 3. **В БД сохраняется массив URL**
```json
{
  "photos": [
    "https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123...",
    "https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_2_1752172461965.jpg?alt=media&token=def456..."
  ]
}
```

## 🔑 Идентификация пользователя

### Основные поля:
- **`userId`** - номер паспорта или ID квартиры (главный идентификатор)
- **`userPhone`** - номер телефона для связи
- **`userName`** - полное имя пользователя

### Поиск заявок пользователя:
```sql
-- По userId (рекомендуется)
SELECT * FROM service_requests WHERE user_id = 'AB1234567';

-- По телефону
SELECT * FROM service_requests WHERE user_phone = '+998999357706';

-- По квартире
SELECT * FROM service_requests WHERE apartment_number = '203' AND block = 'F';
```

## 📊 Формат данных заявки

```json
{
  "id": "1752172461965",
  "userId": "AB1234567",
  "userName": "OTABEK USKENBAYEV SAIDAXMAD O'G'LI",
  "userPhone": "+998999357706",
  "apartmentNumber": "203",
  "block": "F",
  "requestType": "plumbing",
  "description": "Протекает кран в ванной",
  "priority": "High",
  "contactMethod": "phone",
  "preferredTime": "2025-07-09T14:00:00+05:00",
  "photos": [
    "https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123..."
  ],
  "status": "new",
  "createdAt": "2025-07-09T10:38:00+05:00",
  "updatedAt": "2025-07-09T10:38:00+05:00",
  "requestSource": "mobile_app"
}
```

## 🗄️ Структура БД

```sql
CREATE TABLE service_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    mobile_request_id VARCHAR(255) UNIQUE,  -- ID из мобильного приложения
    user_id VARCHAR(255) NOT NULL,          -- userId из мобильного приложения
    user_name VARCHAR(255),
    user_phone VARCHAR(50),
    apartment_number VARCHAR(50),
    block VARCHAR(50),
    request_type VARCHAR(100),
    description TEXT,
    priority VARCHAR(50),
    contact_method VARCHAR(50),
    preferred_time DATETIME,
    photos JSON,                            -- Массив URL фотографий
    status VARCHAR(50) DEFAULT 'new',
    created_at DATETIME,
    updated_at DATETIME,
    request_source VARCHAR(50) DEFAULT 'mobile_app',
    additional_data JSON,
    INDEX idx_user_id (user_id),
    INDEX idx_mobile_request_id (mobile_request_id)
);
```

## 🔧 Webhook endpoint

### URL: `POST /api/service-requests`
### Headers: `X-API-Key: your-secret-api-key`

### Простая обработка (PHP):
```php
<?php
// Проверка API ключа
$apiKey = $_SERVER['HTTP_X_API_KEY'] ?? '';
if ($apiKey !== 'your-secret-api-key') {
    http_response_code(401);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);

// Сохранение в БД
$stmt = $pdo->prepare("
    INSERT INTO service_requests 
    (mobile_request_id, user_id, user_name, user_phone, apartment_number, 
     block, request_type, description, priority, contact_method, 
     preferred_time, photos, status, created_at, updated_at, request_source)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    'mobile_app'
]);

echo json_encode(['success' => true]);
?>
```

## ⚡ Быстрый старт

1. **Создайте таблицу** `service_requests` с указанной структурой
2. **Создайте endpoint** `/api/service-requests` для приема POST запросов
3. **Добавьте проверку API ключа** в заголовке `X-API-Key`
4. **Сохраняйте данные** в БД, включая массив URL фотографий
5. **Настройте в мобильном приложении** URL вашего webhook

## 🔍 Отображение фотографий

Фотографии доступны по URL из Firebase Storage. Просто используйте URL из поля `photos` в HTML:

```html
<img src="https://firebasestorage.googleapis.com/v0/b/newport-23a19.appspot.com/o/service_requests%2F1752172461965%2Fimages%2Fimage_1_1752172461965.jpg?alt=media&token=abc123..." alt="Фото заявки">
```

---

**Готово!** Теперь ваши заявки от мобильного приложения будут автоматически сохраняться в БД с фотографиями. 