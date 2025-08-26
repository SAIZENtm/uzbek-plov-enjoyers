const admin = require('firebase-admin');

// Инициализируем Admin SDK
const serviceAccount = require('./functions/newport-23a19-firebase-adminsdk-wc8hi-0c2db81f9a.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://newport-23a19-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

async function createTestNotification() {
  try {
    console.log('🚀 Создаем тестовое уведомление...');
    
    // Замените на реальный номер паспорта пользователя
    const testUserId = 'AA2807040'; // Или любой другой ID из логов
    
    const notification = {
      userId: testUserId,
      title: 'Тест push-уведомления',
      message: 'Это тестовое уведомление для проверки системы push!',
      type: 'system',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {},
      relatedRequestId: null,
      adminName: 'Тест Админ',
      imageUrl: null
    };

    // Создаем уведомление в Firestore
    const docRef = await db.collection('notifications').add(notification);
    console.log('✅ Уведомление создано с ID:', docRef.id);
    console.log('📱 Cloud Function должна автоматически отправить push...');
    
    // Проверяем, есть ли пользователь в коллекции users
    const userDoc = await db.collection('users').doc(testUserId).get();
    if (userDoc.exists) {
      const userData = userDoc.data();
      console.log('👤 Данные пользователя:', {
        fcmTokens: userData.fcmTokens?.length || 0,
        blockId: userData.blockId,
        apartmentNumber: userData.apartmentNumber
      });
    } else {
      console.log('❌ Пользователь не найден в коллекции users!');
      console.log('🔧 Нужно войти в приложение для создания записи пользователя');
    }
    
  } catch (error) {
    console.error('❌ Ошибка:', error);
  }
}

// Запускаем тест
createTestNotification().then(() => {
  console.log('🏁 Тест завершен');
  process.exit(0);
}); 