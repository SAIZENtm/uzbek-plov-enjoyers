# Payment Security Migration Guide

## Изменения в безопасности платежей

### Что было удалено:
1. ❌ Сбор PAN/CVV карт в приложении
2. ❌ Mock платежная форма
3. ❌ Прямая интеграция с платежным шлюзом
4. ❌ Хранение платежных данных

### Что добавлено:
1. ✅ Серверная интеграция с Payme
2. ✅ Идемпотентность транзакций
3. ✅ Webhook для подтверждения платежей
4. ✅ Безопасный Checkout через браузер/приложение Payme

## Настройка Payme

### 1. Регистрация в Payme Business

1. Зарегистрируйтесь на https://business.payme.uz
2. Получите Merchant ID
3. Сгенерируйте ключ для API

### 2. Настройка Firebase Functions

```bash
# Установка конфигурации
firebase functions:config:set \
  payme.merchant_id="YOUR_MERCHANT_ID" \
  payme.key="YOUR_API_KEY"

# Проверка
firebase functions:config:get
```

### 3. Настройка Webhook URL в Payme

В личном кабинете Payme укажите:
```
https://us-central1-YOUR_PROJECT.cloudfunctions.net/paymeWebhook
```

## Обновление кода

### 1. Замена PaymentService

```dart
// service_locator.dart
// Старый
import 'package:your_app/core/services/payment_service.dart';

// Новый
import 'package:your_app/core/services/payment_service_secure.dart';

getIt.registerLazySingleton<PaymentService>(
  () => PaymentService(
    authService: getIt<AuthService>(),
    loggingService: getIt<LoggingService>(),
  ),
);
```

### 2. Обновление UI

```dart
// Старый код (небезопасный)
TextField(
  decoration: InputDecoration(labelText: 'Номер карты'),
  keyboardType: TextInputType.number,
  onChanged: (value) => cardNumber = value,
)

// Новый код (безопасный)
BlueButton(
  text: 'Оплатить через Payme',
  onPressed: () async {
    final result = await paymentService.createPayment(
      amount: selectedAmount,
    );
    
    if (result.success) {
      await paymentService.openPaymentCheckout(
        result.checkoutUrl!,
      );
    }
  },
)
```

## Обработка платежей

### 1. Создание платежа

```dart
// В приложении
Future<void> initiatePayment(double amount) async {
  try {
    // Создаем платеж на сервере
    final result = await paymentService.createPayment(
      amount: amount,
      description: 'Оплата коммунальных услуг',
    );
    
    if (result.success && result.checkoutUrl != null) {
      // Открываем Payme
      await launchUrl(Uri.parse(result.checkoutUrl));
    }
  } catch (e) {
    // Обработка ошибок
  }
}
```

### 2. Webhook обработка

```javascript
// Cloud Function автоматически обрабатывает:
// - CheckPerformTransaction
// - CreateTransaction
// - PerformTransaction
// - CancelTransaction
// - CheckTransaction
// - GetStatement
```

### 3. Проверка статуса после возврата

```dart
// При возврате из Payme
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && _pendingPaymentId != null) {
    _checkPaymentStatus(_pendingPaymentId!);
  }
}
```

## Идемпотентность

### Как работает:
1. Генерируется уникальный ключ на основе userId + amount + date
2. Проверяется существование платежа с таким ключом
3. Если существует - возвращается существующий платеж

```javascript
function generateIdempotencyKey(userId, amount, purpose) {
  const data = `${userId}:${amount}:${purpose}:${new Date().toDateString()}`;
  return crypto.createHash('sha256').update(data).digest('hex');
}
```

## Тестирование

### 1. Тестовый режим Payme

Используйте тестовый URL:
```javascript
const PAYME_CONFIG = {
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://checkout.paycom.uz' 
    : 'https://checkout.test.paycom.uz',
};
```

### 2. Тестовые карты

```
Успешная оплата: 8600 0000 0000 0001
Недостаточно средств: 8600 0000 0000 0002
Отклонено банком: 8600 0000 0000 0003
```

### 3. Integration тесты

```dart
void main() {
  group('Payment Service', () {
    test('Should create payment with idempotency', () async {
      final payment1 = await service.createPayment(amount: 100000);
      final payment2 = await service.createPayment(amount: 100000);
      
      expect(payment1.paymentId, equals(payment2.paymentId));
    });
  });
}
```

## Мониторинг

### 1. Логирование транзакций

```javascript
// Все транзакции логируются в коллекцию
db.collection('paymeTransactions')
db.collection('payments')
```

### 2. Алерты при ошибках

```javascript
exports.monitorPaymentFailures = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async () => {
    const failedPayments = await db.collection('payments')
      .where('status', '==', 'failed')
      .where('createdAt', '>', oneHourAgo)
      .get();
    
    if (failedPayments.size > 5) {
      // Отправить алерт
    }
  });
```

## Compliance и PCI DSS

### Что мы делаем:
1. ✅ Не храним карточные данные
2. ✅ Не передаем карточные данные через наш сервер
3. ✅ Используем сертифицированный платежный шлюз
4. ✅ Все платежи проходят через HTTPS

### Что НЕ делаем:
1. ❌ Не собираем PAN/CVV
2. ❌ Не логируем платежные данные
3. ❌ Не сохраняем карты без токенизации

## Rollback план

1. Сохраните старые файлы payment_service.dart
2. В случае проблем верните старую версию
3. НО: Старая версия небезопасна и не должна использоваться в production!

## Checklist безопасности

- [ ] Удален весь код сбора карточных данных
- [ ] Настроена серверная интеграция с Payme
- [ ] Webhook URL добавлен в Payme личный кабинет
- [ ] Идемпотентность работает корректно
- [ ] Тесты проходят успешно
- [ ] Логирование настроено
- [ ] Документация обновлена
- [ ] PCI DSS compliance проверен
