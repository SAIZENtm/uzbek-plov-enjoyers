# 🚀 Развертывание Cloud Functions для Newport

## 📋 Предварительные требования

1. **Node.js** версии 18 или выше
2. **Firebase CLI** установлен глобально
3. **Проект Firebase** настроен

## ⚙️ Установка Firebase CLI

```bash
npm install -g firebase-tools
```

## 🔐 Аутентификация

```bash
firebase login
```

## 📁 Инициализация проекта (если еще не сделано)

```bash
firebase init functions
```

## 🔧 Установка зависимостей

```bash
cd functions
npm install
```

## 🚀 Развертывание функций

### Развертывание всех функций:
```bash
firebase deploy --only functions
```

### Развертывание конкретной функции:
```bash
firebase deploy --only functions:testPushNotification
```

## 📝 Список функций в проекте

1. **`testPushNotification`** - HTTP функция для тестирования push уведомлений
2. **`sendPushNotification`** - Callable функция для отправки push из админ панели
3. **`onNotificationCreate`** - Trigger функция при создании уведомления
4. **`onServiceRequestUpdate`** - Trigger функция при обновлении заявки
5. **`createNotification`** - HTTP функция для создания уведомлений
6. **`createTestNotification`** - HTTP функция для создания тестовых уведомлений

## 🔍 Проверка развертывания

После развертывания проверьте функции в Firebase Console:
1. Перейдите в Firebase Console
2. Выберите ваш проект (newport-23a19)
3. Перейдите в раздел "Functions"
4. Убедитесь, что все функции развернуты

## 🧪 Тестирование

### Тестирование push уведомлений:
1. Откройте `test_push.html` в браузере
2. Вставьте FCM токен из Flutter приложения
3. Введите заголовок и сообщение
4. Нажмите "Отправить"

### Тестирование создания уведомлений:
1. Откройте `test_notification_system.html` в браузере
2. Используйте различные функции для тестирования

## ⚠️ Устранение неполадок

### Ошибка CORS:
- Убедитесь, что функция `testPushNotification` развернута
- Проверьте URL функции в `test_push.html`

### Ошибка аутентификации:
```bash
firebase login --reauth
```

### Ошибка развертывания:
```bash
# Проверьте логи
firebase functions:log

# Очистите кэш
npm run clean
firebase deploy --only functions --force
```

## 📊 Мониторинг

### Просмотр логов:
```bash
firebase functions:log
```

### Мониторинг в реальном времени:
```bash
firebase functions:log --only testPushNotification
```

## 🔄 Обновление функций

После изменения кода функций:

1. Сохраните изменения
2. Развернуте обновленные функции:
   ```bash
   firebase deploy --only functions
   ```
3. Протестируйте изменения

## 📞 URL функций

После развертывания ваши функции будут доступны по адресам:

- **testPushNotification**: `https://us-central1-newport-23a19.cloudfunctions.net/testPushNotification`
- **createNotification**: `https://us-central1-newport-23a19.cloudfunctions.net/createNotification`
- **createTestNotification**: `https://us-central1-newport-23a19.cloudfunctions.net/createTestNotification`

## 🎯 Следующие шаги

1. Разверните функции командой `firebase deploy --only functions`
2. Протестируйте push уведомления в `test_push.html`
3. Убедитесь, что уведомления приходят в мобильное приложение
4. Настройте автоматические уведомления в админ панели 