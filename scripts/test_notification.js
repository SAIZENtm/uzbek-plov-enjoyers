// Тестовый скрипт для отправки уведомлений
// Используйте этот скрипт в консоли браузера на странице с Firebase

// Конфигурация Firebase (замените на ваши данные)
const firebaseConfig = {
  apiKey: "your-api-key",
  authDomain: "newport-23a19.firebaseapp.com",
  projectId: "newport-23a19",
  storageBucket: "newport-23a19.appspot.com",
  messagingSenderId: "your-sender-id",
  appId: "your-app-id"
};

// Инициализация Firebase (если еще не инициализирован)
// firebase.initializeApp(firebaseConfig);
// const db = firebase.firestore();

// Функция для генерации уникального ID
function generateUniqueId() {
  return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

// Основная функция для отправки уведомления
async function sendNotification(notificationData) {
  try {
    const notification = {
      id: generateUniqueId(),
      userId: notificationData.userId,
      title: notificationData.title,
      message: notificationData.message,
      type: notificationData.type || 'system',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: notificationData.data || {},
      relatedRequestId: notificationData.relatedRequestId || null,
      adminName: notificationData.adminName || null,
      imageUrl: notificationData.imageUrl || null
    };

    // Сохраняем в Firestore
    await db.collection('notifications').doc(notification.id).set(notification);
    
    console.log('✅ Notification sent successfully:', notification.id);
    console.log('📱 Notification data:', notification);
    return notification;
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    throw error;
  }
}

// Функции для разных типов уведомлений
async function sendAdminResponse(userId, requestId, message, adminName) {
  return await sendNotification({
    userId: userId,
    title: 'Ответ администратора',
    message: message,
    type: 'admin_response',
    relatedRequestId: requestId,
    adminName: adminName
  });
}

async function sendSystemNotification(userId, title, message) {
  return await sendNotification({
    userId: userId,
    title: title,
    message: message,
    type: 'system'
  });
}

async function sendServiceUpdate(userId, requestId, message) {
  return await sendNotification({
    userId: userId,
    title: 'Обновление по заявке',
    message: message,
    type: 'service_update',
    relatedRequestId: requestId
  });
}

// Тестовые функции
async function testNotifications() {
  const testUserId = 'AC3077863'; // Замените на реальный ID пользователя
  
  console.log('🧪 Starting notification tests...');
  
  try {
    // Тест 1: Системное уведомление
    console.log('\n📢 Test 1: System notification');
    await sendSystemNotification(
      testUserId,
      'Системное уведомление',
      'Это тестовое системное уведомление для проверки работы приложения'
    );
    
    // Тест 2: Ответ администратора
    console.log('\n👨‍💼 Test 2: Admin response');
    await sendAdminResponse(
      testUserId,
      'test_request_123',
      'Ваша заявка рассмотрена. Все работы будут выполнены в течение 3 дней.',
      'Иван Петров'
    );
    
    // Тест 3: Обновление по услуге
    console.log('\n🔧 Test 3: Service update');
    await sendServiceUpdate(
      testUserId,
      'test_request_456',
      'Мастер выехал на выполнение работ по вашей заявке'
    );
    
    console.log('\n✅ All tests completed successfully!');
    console.log('📱 Check the mobile app notifications screen');
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

// Функция для массовой отправки
async function sendBulkNotification(title, message, type = 'system') {
  try {
    console.log('📤 Sending bulk notification to all users...');
    
    // Получаем всех пользователей
    const usersSnapshot = await db.collection('users').get();
    
    if (usersSnapshot.empty) {
      console.log('⚠️ No users found in database');
      return;
    }
    
    const promises = usersSnapshot.docs.map(userDoc => {
      const userData = userDoc.data();
      const userId = userData.passport_number || userData.passportNumber;
      
      if (userId) {
        return sendNotification({
          userId: userId,
          title: title,
          message: message,
          type: type
        });
      }
    });
    
    await Promise.all(promises.filter(p => p));
    console.log(`✅ Bulk notification sent to ${promises.length} users`);
    
  } catch (error) {
    console.error('❌ Error sending bulk notification:', error);
    throw error;
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
          name: userData.full_name || userData.fullName || 'Unknown',
          email: userData.email || 'No email'
        });
      }
    });
    
    console.log('👥 Users list:', users);
    return users;
  } catch (error) {
    console.error('❌ Error getting users list:', error);
    throw error;
  }
}

// Функция для проверки отправленных уведомлений
async function checkNotifications(userId) {
  try {
    const notificationsSnapshot = await db.collection('notifications')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();
    
    if (notificationsSnapshot.empty) {
      console.log('📭 No notifications found for user:', userId);
      return [];
    }
    
    const notifications = [];
    notificationsSnapshot.forEach(doc => {
      notifications.push({
        id: doc.id,
        ...doc.data()
      });
    });
    
    console.log(`📬 Found ${notifications.length} notifications for user ${userId}:`);
    notifications.forEach(n => {
      console.log(`  • ${n.title} (${n.type}) - ${n.isRead ? 'Read' : 'Unread'}`);
    });
    
    return notifications;
  } catch (error) {
    console.error('❌ Error checking notifications:', error);
    throw error;
  }
}

// Инструкции по использованию
console.log(`
🚀 Notification Test Script Loaded!

Available functions:
1. testNotifications() - Run all test notifications
2. sendSystemNotification(userId, title, message) - Send system notification
3. sendAdminResponse(userId, requestId, message, adminName) - Send admin response
4. sendServiceUpdate(userId, requestId, message) - Send service update
5. sendBulkNotification(title, message, type) - Send to all users
6. getUsersList() - Get list of all users
7. checkNotifications(userId) - Check notifications for specific user

Example usage:
- testNotifications()
- sendSystemNotification('AC3077863', 'Test', 'Hello from admin panel!')
- getUsersList()
- checkNotifications('AC3077863')

⚠️ Make sure to replace 'AC3077863' with actual user IDs from your database.
`); 