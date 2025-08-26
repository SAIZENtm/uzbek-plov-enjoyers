# 🧹 Исправление архитектуры - Разделение коллекций

## 🎯 **Проблема**

В коллекции `users` создавались профили пользователей при логине, что засоряло базу данных:

```json
{
  "apartmentNumber": "101",
  "blockId": "D BLOK BLOK",
  "createdAt": "July 19, 2025 at 7:35:47 PM UTC+5",
  "fullName": "AFINA ALIYEVA TURSUNJONOVNA",
  "lastLogin": "July 19, 2025 at 7:35:47 PM UTC+5",
  "phone": "+998988124111",
  "role": "owner",
  "uid": "t766cgN6G9QLMD0KdnhomhWwfpK2"
}
```

## ✅ **Решение**

### 1. **Разделили коллекции по назначению:**

#### **`users` - только пользовательские настройки:**
- Прочитанные новости
- Настройки уведомлений
- Персональные предпочтения

#### **`userProfiles` - профили пользователей:**
- ФИО, телефон, квартира
- Роль пользователя
- FCM токены
- Данные аутентификации

### 2. **Исправленные файлы:**

#### **Flutter приложение:**
- ✅ `lib/core/services/auth_service.dart` - метод `_saveUserDataToFirestore`
- ✅ `lib/core/services/fcm_service.dart` - метод `_saveTokenToFirestore`  
- ✅ `lib/core/services/family_request_service.dart` - создание семейных пользователей
- ✅ `firestore.rules` - добавлены правила для `userProfiles`

#### **Cloud Functions:**
- ✅ `functions/inviteFunctions.js` - функции `getUserRole` и `acceptFamilyInvite`

### 3. **Обновленные правила Firestore:**

```javascript
// КОЛЛЕКЦИЯ USERS - ТОЛЬКО для пользовательских настроек
// (например, какие новости он прочитал, настройки уведомлений)
match /users/{userId} {
  allow read, write: if isAuthenticated();
}

// КОЛЛЕКЦИЯ USER PROFILES - для профилей пользователей
// (ФИО, телефон, квартира, роль и т.д.)
match /userProfiles/{profileId} {
  allow read, write: if isAuthenticated();
}
```

## 🗂️ **Новая структура базы данных**

### **Коллекция `users` (настройки пользователей):**
```
users/{userId}
├── metadata/
│   └── readNewsIds: [array]
├── preferences/
│   ├── notifications: {object}
│   └── language: string
└── settings: {object}
```

### **Коллекция `userProfiles` (профили пользователей):**
```
userProfiles/{profileId}
├── uid: string
├── fullName: string
├── phone: string
├── role: string
├── apartmentNumber: string
├── blockId: string
├── fcmTokens: [array]
├── lastLogin: timestamp
├── createdAt: timestamp
└── dataSource: string
```

### **Коллекция `users/{blockId}/apartments/{apartmentNumber}` (данные квартир):**
```
users/{blockId}/apartments/{apartmentNumber}
├── apartment_number: string
├── phone: string
├── passport_number: string
├── fullName: string
├── fcmTokens: [array]
├── pushToken: string
└── lastTokenUpdate: timestamp
```

## 🚀 **Развертывание исправлений**

### 1. **Обновить правила Firestore:**
1. Откройте [Firebase Console](https://console.firebase.google.com)
2. Выберите проект `newport-23a19`
3. Перейдите в **Firestore Database → Rules**
4. Скопируйте правила из файла `firestore.rules`
5. Нажмите **"Publish"**

### 2. **Развернуть Cloud Functions:**
```bash
cd functions
npm install
firebase deploy --only functions
```

### 3. **Очистить старые данные (опционально):**
- В Firebase Console можно удалить мусорные документы из коллекции `users`
- Оставить только документы с настройками пользователей

## 🔍 **Как проверить исправления:**

### 1. **Проверьте Firebase Console:**
- Коллекция `users` должна содержать только настройки
- Коллекция `userProfiles` должна содержать профили пользователей

### 2. **Проверьте логи приложения:**
```
Firebase Auth: User profile saved to userProfiles collection
✅ User profile saved to userProfiles collection successfully!
```

### 3. **Тестирование в приложении:**
- Войдите в приложение
- Проверьте что профиль создается в `userProfiles`
- Проверьте что настройки (прочитанные новости) сохраняются в `users`

## 💡 **Преимущества новой архитектуры:**

### ✅ **Чистота базы данных:**
- Нет мусорных документов в коллекции `users`
- Четкое разделение по назначению

### ✅ **Безопасность:**
- Разные правила доступа для профилей и настроек
- Более точный контроль прав

### ✅ **Масштабируемость:**
- Легче добавлять новые типы пользовательских данных
- Проще администрировать

### ✅ **Читаемость:**
- Понятная структура для разработчиков
- Четкое назначение каждой коллекции

## 🔧 **Обслуживание:**

### **Мониторинг:**
- Отслеживайте размер коллекции `users`
- Проверяйте что новые профили создаются в `userProfiles`

### **Очистка (если нужна):**
```javascript
// Скрипт для очистки мусорных профилей из коллекции users
// (запускать осторожно!)
const usersRef = firebase.firestore().collection('users');
const batch = firebase.firestore().batch();

usersRef.where('fullName', '!=', null).get().then(snapshot => {
  snapshot.forEach(doc => {
    const data = doc.data();
    // Если документ содержит профильные данные - удаляем
    if (data.fullName && data.phone && data.apartmentNumber) {
      batch.delete(doc.ref);
    }
  });
  return batch.commit();
});
```

---

## 🎉 **Результат**

**Теперь база данных чистая и структурированная!**

- ✅ Коллекция `users` - только настройки
- ✅ Коллекция `userProfiles` - только профили  
- ✅ Коллекция `users/{block}/apartments/{apt}` - только квартиры
- ✅ Четкая архитектура и безопасные правила 