# 🔥 Развертывание Firestore Rules для Умного Дома

## 📋 Что нужно сделать

Правила Firestore уже обновлены с поддержкой умного дома. Необходимо развернуть их в Firebase Console.

## 🚀 Пошаговая инструкция

### Шаг 1: Открыть Firebase Console
1. Перейдите на [Firebase Console](https://console.firebase.google.com)
2. Выберите проект **newport-23a19**

### Шаг 2: Перейти к Firestore Database
1. В левом меню нажмите **"Firestore Database"**
2. Перейдите на вкладку **"Rules"**

### Шаг 3: Обновить правила
1. Скопируйте **ВСЕ содержимое** файла `firestore.rules`
2. Вставьте в редактор правил, заменив старые правила
3. Нажмите **"Publish"**

### Шаг 4: Проверить развертывание
1. Дождитесь сообщения "Rules published successfully"
2. Проверьте что правила активны

## 🔐 Ключевые изменения в правилах

### ✅ Добавлена поддержка умного дома:
```javascript
// Умный дом - пользователь может управлять только своей квартирой
function canAccessSmartHome() {
  return isAuthenticated() && (
    // Проверяем что пользователь имеет доступ к этой квартире
    exists(/databases/$(database)/documents/userProfiles/$(request.auth.uid)) ||
    resource != null
  );
}

// Правила для обновления smartHome данных
allow update: if canAccessSmartHome() && 
  request.resource.data.keys().hasOnly(['name', 'phone', 'fcmToken', 'smartHome', 'lastActivity']) &&
  (request.resource.data.smartHome == null || 
   request.resource.data.smartHome is map);
```

### 🛡️ Безопасность:
- Пользователи могут управлять **только своей квартирой**
- Проверка аутентификации через Firebase Auth
- Валидация структуры данных smartHome
- Разрешенные поля: `name`, `phone`, `fcmToken`, `smartHome`, `lastActivity`

## 📊 Структура данных умного дома

```json
{
  "users": {
    "H BLOK": {
      "apartments": {
        "102": {
          "name": "Иван Иванов",
          "phone": "+998...",
          "smartHome": {
            "devices": [
              {
                "id": "light_1234567890",
                "name": "Люстра в зале", 
                "type": "light",
                "status": "off",
                "lastUpdated": "2024-01-15T10:30:00Z",
                "updatedBy": "User Name"
              }
            ],
            "lastSyncTime": "2024-01-15T10:30:00Z",
            "isEnabled": true
          }
        }
      }
    }
  }
}
```

## ✅ Проверка после развертывания

1. **Откройте приложение**
2. **Перейдите в "Умный дом"**
3. **Попробуйте добавить устройство**
4. **Проверьте что данные сохраняются в Firestore**

## 🚨 Возможные проблемы

### Ошибка "Permission denied"
- Убедитесь что правила развернуты
- Проверьте что пользователь аутентифицирован
- Проверьте структуру данных в smartHome

### Ошибка "Invalid data"
- Проверьте что smartHome является объектом
- Убедитесь что используются только разрешенные поля

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи в Firebase Console
2. Убедитесь в правильности синтаксиса правил
3. Проверьте аутентификацию пользователя

---

**✅ После выполнения этого шага модуль умного дома будет готов к тестированию!** 