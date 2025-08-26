# Offline Queue & Idempotency Guide

## Проблемы с текущей реализацией

### Что было обнаружено:
1. ❌ Дублирование операций при повторных попытках
2. ❌ Потеря данных при сбоях приложения
3. ❌ Race conditions при синхронизации
4. ❌ Отсутствие идемпотентности

## Решение: OfflineQueueService

### Ключевые возможности:
1. ✅ Идемпотентные операции с уникальными ключами
2. ✅ Персистентное хранение очереди
3. ✅ Экспоненциальный backoff для ретраев
4. ✅ Автоматическая синхронизация при подключении
5. ✅ Дедупликация на клиенте и сервере

## Архитектура

### 1. Идемпотентность

```dart
// Каждая операция получает уникальный ключ на основе:
// - Тип операции
// - Ключевые данные (без timestamps)
// - ID пользователя

String idempotencyKey = generateIdempotencyKey({
  'type': 'createServiceRequest',
  'apartmentId': 'apt123',
  'requestType': 'repair',
  'description': 'Сломан кран',
});

// Сервер проверяет ключ и возвращает 409 если операция уже выполнена
```

### 2. Структура операции

```dart
class OfflineOperation {
  final OperationType type;      // Тип для идемпотентности
  final String method;           // HTTP метод
  final String endpoint;         // API endpoint
  final Map<String, dynamic>? data;
  final Map<String, String>? headers;
}

class QueuedOperation {
  final String id;               // UUID операции
  final String idempotencyKey;   // Ключ идемпотентности
  final OfflineOperation operation;
  final OperationStatus status;
  final int retryCount;
  final DateTime? lastRetryAt;
}
```

## Использование

### 1. Создание операции с offline поддержкой

```dart
class ServiceRequestService {
  final OfflineQueueService _offlineQueue;
  
  Future<ServiceRequestResult> createServiceRequest({
    required ServiceRequestType type,
    required String description,
  }) async {
    try {
      // Пытаемся создать онлайн
      final result = await _api.createRequest(data);
      
      return ServiceRequestResult(
        success: true,
        requestId: result.id,
      );
      
    } catch (e) {
      // Если офлайн - добавляем в очередь
      final operationId = await _offlineQueue.enqueue(
        OfflineOperation(
          type: OperationType.createServiceRequest,
          method: 'POST',
          endpoint: '/serviceRequests',
          data: data,
        ),
      );
      
      return ServiceRequestResult(
        success: true,
        operationId: operationId,
        isOffline: true,
        message: 'Заявка будет отправлена при подключении',
      );
    }
  }
}
```

### 2. Отображение статуса в UI

```dart
class ServiceRequestCard extends StatelessWidget {
  final ServiceRequest request;
  final String? offlineOperationId;
  
  @override
  Widget build(BuildContext context) {
    if (offlineOperationId != null) {
      return StreamBuilder<OperationStatus?>(
        stream: _getOperationStatusStream(offlineOperationId!),
        builder: (context, snapshot) {
          final status = snapshot.data;
          
          return ListTile(
            title: Text(request.description),
            subtitle: Text(_getStatusText(status)),
            trailing: _getStatusIcon(status),
          );
        },
      );
    }
    
    return ListTile(
      title: Text(request.description),
      subtitle: Text('Отправлено'),
      trailing: Icon(Icons.check, color: Colors.green),
    );
  }
  
  String _getStatusText(OperationStatus? status) {
    switch (status) {
      case OperationStatus.pending:
        return 'Ожидает подключения к интернету';
      case OperationStatus.processing:
        return 'Отправляется...';
      case OperationStatus.completed:
        return 'Успешно отправлено';
      case OperationStatus.failed:
        return 'Ошибка отправки (повтор через несколько минут)';
      default:
        return 'В очереди';
    }
  }
}
```

### 3. Статистика и мониторинг

```dart
// Получение статистики очереди
final stats = offlineQueue.getStatistics();

print('В очереди: ${stats['queueSize']}');
print('Ожидают: ${stats['pending']}');
print('Неудачных: ${stats['failed']}');
print('Дубликатов заблокировано: ${stats['duplicatesBlocked']}');

// Отображение в UI
Card(
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      children: [
        Text('Offline очередь', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8),
        if (stats['queueSize'] > 0) ...[
          LinearProgressIndicator(
            value: stats['processing'] / stats['queueSize'],
          ),
          SizedBox(height: 8),
          Text('${stats['pending']} операций ожидают отправки'),
        ] else
          Text('Все операции синхронизированы'),
      ],
    ),
  ),
)
```

## Серверная интеграция

### 1. Обработка идемпотентности в Cloud Functions

```javascript
exports.createServiceRequest = functions.https.onCall(async (data, context) => {
  const idempotencyKey = context.rawRequest.headers['x-idempotency-key'];
  
  if (idempotencyKey) {
    // Проверяем существующую операцию
    const existing = await db.collection('idempotentOperations')
      .doc(idempotencyKey)
      .get();
    
    if (existing.exists) {
      // Операция уже выполнена
      return {
        success: true,
        duplicate: true,
        result: existing.data().result,
      };
    }
  }
  
  // Выполняем операцию
  const result = await performOperation(data);
  
  // Сохраняем результат для идемпотентности
  if (idempotencyKey) {
    await db.collection('idempotentOperations')
      .doc(idempotencyKey)
      .set({
        operationId: context.rawRequest.headers['x-operation-id'],
        result: result,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(
          new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // 7 дней
        ),
      });
  }
  
  return result;
});
```

### 2. Очистка старых ключей

```javascript
exports.cleanupIdempotentKeys = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const expiredKeys = await db.collection('idempotentOperations')
      .where('expiresAt', '<', admin.firestore.Timestamp.now())
      .get();
    
    const batch = db.batch();
    expiredKeys.forEach(doc => batch.delete(doc.ref));
    
    await batch.commit();
    
    console.log(`Cleaned up ${expiredKeys.size} expired idempotent keys`);
  });
```

## Обработка ошибок

### 1. Стратегия ретраев

```
Попытка 1: Немедленно
Попытка 2: 2 сек (+ jitter)
Попытка 3: 4 сек (+ jitter)
Попытка 4: 8 сек (+ jitter)
Попытка 5: 16 сек (+ jitter)
Максимум: 5 минут между попытками
```

### 2. Типы ошибок

| Код ошибки | Действие | Ретрай |
|------------|----------|--------|
| 401 | Требуется реавторизация | ❌ |
| 409 | Операция уже выполнена | ✅ Успех |
| 400-499 | Ошибка данных | ❌ |
| 500-599 | Серверная ошибка | ✅ |
| Timeout | Таймаут запроса | ✅ |
| Network | Нет сети | ✅ |

### 3. Обработка в UI

```dart
// Показываем ошибку с возможностью повтора
if (status == OperationStatus.failed && retryCount >= maxRetries) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Не удалось отправить'),
      content: Text('Заявка не может быть отправлена. Проверьте данные.'),
      actions: [
        TextButton(
          onPressed: () => _cancelOperation(operationId),
          child: Text('Отменить'),
        ),
        ElevatedButton(
          onPressed: () => _retryOperation(operationId),
          child: Text('Повторить'),
        ),
      ],
    ),
  );
}
```

## Best Practices

### 1. Дизайн операций

```dart
// ✅ ХОРОШО - идемпотентная операция
OfflineOperation(
  type: OperationType.createServiceRequest,
  method: 'POST',
  endpoint: '/serviceRequests',
  data: {
    'apartmentId': apartment.id,
    'type': 'repair',
    'description': 'Сломан кран',
    // createdAt добавится на сервере
  },
);

// ❌ ПЛОХО - не идемпотентная
OfflineOperation(
  type: OperationType.custom,
  method: 'POST',
  endpoint: '/increment-counter', // Изменяет состояние
  data: {'increment': 1},
);
```

### 2. Размер очереди

```dart
// Ограничиваем размер очереди
const int maxQueueSize = 1000;

// Приоритизируем важные операции
enum OperationPriority {
  high,    // Критичные операции (SOS, аварии)
  normal,  // Обычные заявки
  low,     // Фоновая синхронизация
}
```

### 3. Безопасность данных

```dart
// Используем SecureStorage для очереди
final secureStorage = FlutterSecureStorage();

// Шифруем чувствительные данные
final encryptedQueue = await encryptQueue(queue);
await secureStorage.write(key: 'offline_queue', value: encryptedQueue);
```

## Тестирование

### 1. Unit тесты

```dart
test('Prevents duplicate operations', () async {
  final queue = OfflineQueueService(...);
  
  final operation = OfflineOperation(
    type: OperationType.createServiceRequest,
    method: 'POST',
    endpoint: '/test',
    data: {'key': 'value'},
  );
  
  final id1 = await queue.enqueue(operation);
  final id2 = await queue.enqueue(operation); // Тот же ключ
  
  expect(id1, equals(id2)); // Должен вернуть тот же ID
  expect(queue.getStatistics()['queueSize'], equals(1));
});
```

### 2. Integration тесты

```dart
test('Syncs when coming online', () async {
  // Симулируем offline
  when(connectivity.checkConnectivity())
    .thenAnswer((_) async => ConnectivityResult.none);
  
  // Добавляем операцию
  await queue.enqueue(operation);
  
  // Симулируем online
  connectivityController.add(ConnectivityResult.wifi);
  
  // Ждем синхронизации
  await Future.delayed(Duration(seconds: 2));
  
  // Проверяем что очередь пуста
  expect(queue.getStatistics()['queueSize'], equals(0));
});
```

## Мониторинг

### 1. Метрики для отслеживания

- Размер очереди
- Количество неудачных операций
- Время в очереди
- Количество дубликатов
- Процент успешных синхронизаций

### 2. Алерты

```dart
// Проверка здоровья очереди
Timer.periodic(Duration(minutes: 5), (_) {
  final stats = offlineQueue.getStatistics();
  
  if (stats['failed'] > 10) {
    // Отправить алерт
    crashlytics.log('High offline queue failure rate');
  }
  
  if (stats['queueSize'] > 500) {
    // Предупредить пользователя
    showWarning('Много несинхронизированных данных');
  }
});
```

## Checklist внедрения

- [ ] Реализован OfflineQueueService
- [ ] Добавлена идемпотентность на сервере
- [ ] Критичные операции используют offline queue
- [ ] UI показывает статус offline операций
- [ ] Настроен экспоненциальный backoff
- [ ] Добавлены тесты идемпотентности
- [ ] Настроен мониторинг очереди
- [ ] Документация обновлена
