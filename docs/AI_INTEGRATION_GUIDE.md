# Инструкция для ИИ: Добавление функции отправки уведомлений в админ панель

## Краткое описание задачи
Нужно добавить к существующей админ панели функцию отправки уведомлений в мобильное приложение через Firebase Firestore.

## Что уже готово
- ✅ Мобильное приложение уже настроено и читает уведомления
- ✅ Firebase Firestore уже настроен 
- ✅ Правила безопасности уже обновлены
- ✅ Структура данных уже определена

## Что нужно добавить

### 1. Подключение к Firebase (если еще не подключено)

```html
<!-- Добавить в <head> админ панели -->
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-firestore-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.0.0/firebase-auth-compat.js"></script>
```

### 2. Конфигурация Firebase

```javascript
// Добавить в начало JS файла админ панели
const firebaseConfig = {
  apiKey: "AIzaSyDxVpK8_your_api_key",
  authDomain: "newport-23a19.firebaseapp.com",
  projectId: "newport-23a19",
  storageBucket: "newport-23a19.appspot.com",
  messagingSenderId: "your_sender_id",
  appId: "your_app_id"
};

// Инициализация Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();
```

### 3. Основная функция отправки уведомлений

```javascript
// Добавить эту функцию в JS файл админ панели
async function sendNotification(userId, title, message, type = 'system', options = {}) {
  try {
    // Генерируем уникальный ID
    const notificationId = Date.now().toString(36) + Math.random().toString(36).substr(2);
    
    const notification = {
      id: notificationId,
      userId: userId,
      title: title,
      message: message,
      type: type, // 'system', 'admin_response', 'service_update'
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: options.data || {},
      relatedRequestId: options.relatedRequestId || null,
      adminName: options.adminName || getCurrentAdminName(),
      imageUrl: options.imageUrl || null
    };

    // Сохраняем в Firestore
    await db.collection('notifications').doc(notificationId).set(notification);
    
    return { success: true, id: notificationId };
  } catch (error) {
    console.error('Error sending notification:', error);
    return { success: false, error: error.message };
  }
}

// Вспомогательная функция для получения имени текущего админа
function getCurrentAdminName() {
  // Замените на реальную логику получения имени админа
  return 'Администратор'; // или получите из сессии/localStorage
}
```

### 4. HTML форма для отправки уведомлений

```html
<!-- Добавить в админ панель -->
<div class="notification-panel">
  <h3>Отправить уведомление</h3>
  
  <form id="notificationForm">
    <div class="form-group">
      <label>ID пользователя (номер паспорта):</label>
      <input type="text" id="userId" required placeholder="AC3077863">
    </div>
    
    <div class="form-group">
      <label>Заголовок:</label>
      <input type="text" id="title" required placeholder="Заголовок уведомления">
    </div>
    
    <div class="form-group">
      <label>Сообщение:</label>
      <textarea id="message" required placeholder="Текст уведомления"></textarea>
    </div>
    
    <div class="form-group">
      <label>Тип уведомления:</label>
      <select id="type">
        <option value="system">Системное</option>
        <option value="admin_response">Ответ администратора</option>
        <option value="service_update">Обновление услуги</option>
      </select>
    </div>
    
    <div class="form-group">
      <label>ID заявки (опционально):</label>
      <input type="text" id="relatedRequestId" placeholder="Если связано с заявкой">
    </div>
    
    <button type="submit">Отправить уведомление</button>
  </form>
  
  <div id="notificationResult"></div>
</div>
```

### 5. CSS стили (опционально)

```css
.notification-panel {
  background: #f9f9f9;
  padding: 20px;
  border-radius: 8px;
  margin: 20px 0;
}

.form-group {
  margin-bottom: 15px;
}

.form-group label {
  display: block;
  margin-bottom: 5px;
  font-weight: bold;
}

.form-group input,
.form-group textarea,
.form-group select {
  width: 100%;
  padding: 8px;
  border: 1px solid #ddd;
  border-radius: 4px;
}

.form-group textarea {
  height: 80px;
  resize: vertical;
}

button {
  background: #007cba;
  color: white;
  padding: 10px 20px;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}

button:hover {
  background: #005a8b;
}

#notificationResult {
  margin-top: 15px;
  padding: 10px;
  border-radius: 4px;
}

.success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}
```

### 6. Обработчик формы

```javascript
// Добавить обработчик события для формы
document.getElementById('notificationForm').addEventListener('submit', async function(e) {
  e.preventDefault();
  
  const resultDiv = document.getElementById('notificationResult');
  resultDiv.innerHTML = 'Отправка...';
  resultDiv.className = '';
  
  const formData = {
    userId: document.getElementById('userId').value,
    title: document.getElementById('title').value,
    message: document.getElementById('message').value,
    type: document.getElementById('type').value,
    relatedRequestId: document.getElementById('relatedRequestId').value || null
  };
  
  try {
    const result = await sendNotification(
      formData.userId,
      formData.title,
      formData.message,
      formData.type,
      { relatedRequestId: formData.relatedRequestId }
    );
    
    if (result.success) {
      resultDiv.innerHTML = `✅ Уведомление отправлено успешно! ID: ${result.id}`;
      resultDiv.className = 'success';
      document.getElementById('notificationForm').reset();
    } else {
      resultDiv.innerHTML = `❌ Ошибка: ${result.error}`;
      resultDiv.className = 'error';
    }
  } catch (error) {
    resultDiv.innerHTML = `❌ Ошибка: ${error.message}`;
    resultDiv.className = 'error';
  }
});
```

### 7. Дополнительные функции (опционально)

```javascript
// Функция для отправки уведомления всем пользователям
async function sendBulkNotification(title, message, type = 'system') {
  try {
    const usersSnapshot = await db.collection('users').get();
    const promises = [];
    
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const userId = userData.passport_number || userData.passportNumber;
      if (userId) {
        promises.push(sendNotification(userId, title, message, type));
      }
    });
    
    await Promise.all(promises);
    return { success: true, count: promises.length };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Функция для получения списка пользователей
async function getUsersList() {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      const userId = userData.passport_number || userData.passportNumber;
      if (userId) {
        users.push({
          id: userId,
          name: userData.full_name || userData.fullName || 'Неизвестно',
          email: userData.email || 'Нет email'
        });
      }
    });
    
    return users;
  } catch (error) {
    console.error('Error getting users:', error);
    return [];
  }
}
```

## Быстрый тест

После добавления кода, можно протестировать через консоль браузера:

```javascript
// Тест отправки уведомления
sendNotification('AC3077863', 'Тест', 'Это тестовое уведомление', 'system');

// Получить список пользователей
getUsersList().then(users => console.log('Users:', users));
```

## Важные моменты

1. **Замените конфигурацию Firebase** на реальные данные вашего проекта
2. **Убедитесь, что админ аутентифицирован** в Firebase (для правил безопасности)
3. **ID пользователя** должен быть номером паспорта (как в мобильном приложении)
4. **Типы уведомлений**: `system`, `admin_response`, `service_update`

## Структура данных в Firestore

Уведомления сохраняются в коллекцию `notifications` с такой структурой:
- `id` - уникальный идентификатор
- `userId` - номер паспорта пользователя
- `title` - заголовок уведомления  
- `message` - текст уведомления
- `type` - тип уведомления
- `createdAt` - время создания (ISO string)
- `isRead` - прочитано ли (false по умолчанию)
- `adminName` - имя отправившего админа
- `relatedRequestId` - ID связанной заявки (опционально)

После добавления этого кода в админ панель, уведомления будут автоматически появляться в мобильном приложении! 