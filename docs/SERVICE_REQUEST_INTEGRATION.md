# 🚀 Новая система заявок на обслуживание

## ✅ Что изменилось

Теперь когда пользователь подает заявку в приложении:

1. **Сохраняется в Firebase Firestore** - для хранения и синхронизации
2. **Отправляется на внешний сайт** - через HTTP webhook
3. **Сохраняется локально** - для работы офлайн

## 🔧 Настройка

### 1. Обновите URL webhook

В файле `lib/core/services/service_request_service.dart`:

```dart
static const String _webhookUrl = 'https://your-website.com/api/service-requests';
```

### 2. Настройте API ключ

В том же файле:

```dart
'X-API-Key': 'your-api-key',
```

### 3. Обновите правила Firestore

Запустите команду для обновления правил:

```bash
firebase deploy --only firestore:rules
```

## 📊 Формат данных

Приложение отправляет данные в формате, который вы показали:

```json
{
  "userId": "abc123",
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

## 🛠️ Для разработчиков

### Новые функции в ServiceRequestService:

- `createServiceRequest()` - создает заявку с полными данными
- `syncOfflineRequests()` - синхронизирует офлайн заявки
- `_saveToFirestore()` - сохраняет в Firebase
- `_sendToExternalWebsite()` - отправляет на внешний сайт

### Обновленные модели:

- `ServiceRequest` - теперь поддерживает все поля включая `userId`, `block`, `priority`, `contactMethod`, `preferredTime`
- Добавлены методы `fromFirestore()` для работы с Firebase

## 🧪 Тестирование

### 1. Проверьте Firebase подключение

```bash
dart run scripts/check_firestore_data.dart
```

### 2. Тестируйте заявки в приложении

- Откройте экран "New Request"
- Заполните все поля
- Отправьте заявку
- Проверьте логи в консоли

### 3. Проверьте webhook

```bash
curl -X POST https://your-website.com/api/service-requests \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-api-key" \
  -d @test_request.json
```

## 📋 Структура базы данных

### Firestore коллекции:

```
serviceRequests/{requestId}
├── id: string
├── userId: string
├── apartmentNumber: string
├── block: string
├── requestType: string
├── description: string
├── priority: string
├── contactMethod: string
├── preferredTime: string
├── photos: array
├── status: string
├── createdAt: string
├── updatedAt: string
└── additionalData: object
```

## 🔒 Безопасность

- Пользователи могут создавать только свои заявки
- Webhook защищен API ключом
- Данные шифруются при передаче
- Логируются все операции

## 🚨 Обработка ошибок

### Если Firebase недоступен:
- Заявка сохраняется локально
- Синхронизируется при восстановлении связи

### Если внешний сайт недоступен:
- Заявка сохраняется в Firebase
- Webhook не прерывает основной процесс
- Логируется ошибка

## 📈 Мониторинг

Проверяйте логи для:
- Успешных отправок в Firebase
- Успешных отправок на внешний сайт
- Ошибок интеграции
- Офлайн синхронизации

## 🔗 Дополнительно

- [Подробная документация по webhook](WEBHOOK_INTEGRATION.md)
- [Структура Firestore](FIRESTORE_STRUCTURE.md)
- [Руководство по тестированию](TESTING_GUIDE.md) 