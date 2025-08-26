# 🔧 Исправление Push-уведомлений для Newport

## 📋 Что было исправленоеу

### 1. **FCMService (Flutter App)**
Обновлен метод сохранения FCM токенов для соответствия правильной структуре Firestore:
- ❌ Было: `fcm_tokens/{phoneNumber}` и `users/{passportNumber}`
- ✅ Стало: `users/{blockId}/apartments/{apartmentNumber}/fcmTokens`

### 2. **Cloud Functions**
Обновлена логика поиска FCM токенов:
- Основной поиск через `collectionGroup('apartments')`
- Поддержка поиска по `passport_number` и `phone`
- Запасные варианты для обратной совместимости

### 3. **Admin Panel (fcmService.ts)**
Обновлен поиск токенов для отправки уведомлений:
- Поиск по всем блокам в структуре `users/{blockId}/apartments`
- Запасные варианты через `fcm_tokens` и `users`

## 🚀 Как протестировать

### 1. Откройте мобильное приложение
1. Войдите в приложение
2. В консоли появится FCM токен:
```
════════════════════════════════════════════════════════════
FCM TOKEN (скопируйте для тестирования):
fYKhJ7TqRp6...
════════════════════════════════════════════════════════════
```
3. Скопируйте этот токен

### 2. Используйте тестовую страницу
1. Откройте файл `test_push_notifications.html` в браузере
2. Выберите блок и введите номер квартиры пользователя
3. Вставьте FCM токен и нажмите "Сохранить"
4. Введите passport number или телефон в поле userId
5. Нажмите "Отправить уведомление"

### 3. Проверьте Firebase Console
1. Откройте Firebase Console → Functions → Logs
2. Найдите функцию `onNotificationCreate`
3. Проверьте логи на наличие ошибок

## 📊 Структура данных в Firestore

```
users/
  └── {blockId}/ (например, "D")
      └── apartments/
          └── {apartmentNumber}/ (например, "01-222")
              ├── full_name: "Иван Иванов"
              ├── phone: "+998901234567"
              ├── passport_number: "AC3077863"
              ├── fcmTokens: ["token1", "token2"] // FCM токены
              └── lastTokenUpdate: timestamp
```

## 🔍 Частые проблемы и решения

### Проблема: "No FCM tokens found"
**Причина**: FCM токен не сохранен для пользователя
**Решение**: 
1. Убедитесь, что пользователь вошел в мобильное приложение
2. Проверьте, что FCM токен сохранился в правильном месте
3. Используйте тестовую страницу для ручного сохранения токена

### Проблема: "User not found"
**Причина**: Неправильный userId в уведомлении
**Решение**: 
1. Используйте passport_number как userId (например: "AC3077863")
2. Или используйте телефон с + (например: "+998901234567")

### Проблема: Push не приходит на устройство
**Причина**: Невалидный FCM токен или проблемы с разрешениями
**Решение**:
1. Проверьте разрешения на уведомления в настройках телефона
2. Переустановите приложение и получите новый токен
3. Проверьте логи Cloud Functions на наличие ошибок

## 📝 Команды для отладки

### Проверка Cloud Functions
```bash
firebase functions:log --only onNotificationCreate
```

### Деплой обновленных функций
```bash
cd functions
npm install
firebase deploy --only functions
```

## 🔗 Полезные ссылки

- [Firebase Console](https://console.firebase.google.com/project/newport-23a19)
- [Cloud Functions Logs](https://console.firebase.google.com/project/newport-23a19/functions/logs)
- [Firestore Data](https://console.firebase.google.com/project/newport-23a19/firestore)

## ✅ Чек-лист для проверки

- [ ] FCM токен генерируется при входе в приложение
- [ ] Токен сохраняется в `users/{blockId}/apartments/{apartmentNumber}/fcmTokens`
- [ ] Cloud Function `onNotificationCreate` запускается при создании уведомления
- [ ] Push-уведомление приходит на устройство
- [ ] Статус доставки обновляется в документе уведомления

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи в Firebase Console
2. Используйте тестовую страницу для диагностики
3. Убедитесь, что все Cloud Functions задеплоены
4. Проверьте правильность структуры данных в Firestore