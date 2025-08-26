const admin = require('firebase-admin');

// Инициализация Firebase Admin SDK
const serviceAccount = require('./functions/newport-23a19-firebase-adminsdk-jglbo-8b0d0de19e.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testFCMSystem() {
  console.log('🧪 Тестирование системы FCM токенов и push-уведомлений');
  console.log('=' .repeat(60));

  // 1. Проверяем данные в коллекции fcm_tokens
  console.log('\n1. 📱 Проверяем коллекцию fcm_tokens:');
  const fcmTokensSnapshot = await db.collection('fcm_tokens').get();
  console.log(`   Найдено документов: ${fcmTokensSnapshot.size}`);
  
  fcmTokensSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`   📞 Телефон: ${doc.id}`);
    console.log(`   👤 Паспорт: ${data.passportNumber}`);
    console.log(`   🏠 Квартира: ${data.apartmentNumber} (блок ${data.blockId})`);
    console.log(`   🔑 FCM токенов: ${data.tokens?.length || 0}`);
    if (data.tokens?.length > 0) {
      console.log(`   📱 Последний токен: ${data.tokens[data.tokens.length - 1].substring(0, 30)}...`);
    }
    console.log('   ---');
  });

  // 2. Проверяем данные в старой коллекции users
  console.log('\n2. 👥 Проверяем коллекцию users:');
  const usersSnapshot = await db.collection('users').get();
  console.log(`   Найдено документов: ${usersSnapshot.size}`);
  
  let usersWithTokens = 0;
  usersSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.fcmTokens && data.fcmTokens.length > 0) {
      usersWithTokens++;
      console.log(`   👤 ${doc.id}: ${data.fcmTokens.length} токен(ов)`);
      console.log(`   📞 Телефон: ${data.phone}`);
      console.log(`   🏠 Квартира: ${data.apartmentNumber} (блок ${data.blockId})`);
    }
  });
  console.log(`   Пользователей с FCM токенами: ${usersWithTokens}`);

  // 3. Создаем тестовое уведомление
  console.log('\n3. 🔔 Создаем тестовое уведомление:');
  
  // Берем первого пользователя с FCM токенами
  let testUserId = null;
  const firstUserWithTokens = usersSnapshot.docs.find(doc => {
    const data = doc.data();
    return data.fcmTokens && data.fcmTokens.length > 0;
  });
  
  if (firstUserWithTokens) {
    testUserId = firstUserWithTokens.id;
    console.log(`   Тестируем с пользователем: ${testUserId}`);
    
    const testNotificationId = `test_fcm_${Date.now()}`;
    const testNotification = {
      id: testNotificationId,
      userId: testUserId,
      title: '🧪 Тест FCM системы',
      message: 'Если вы видите это уведомление, значит система работает корректно!',
      type: 'system_test',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {
        test: true,
        timestamp: Date.now(),
        testPhase: 'fcm_system_verification'
      },
      relatedRequestId: null,
      adminName: 'Система тестирования FCM',
      imageUrl: null
    };

    // Создаем уведомление - это автоматически запустит Cloud Function
    await db.collection('notifications').doc(testNotificationId).set(testNotification);
    console.log(`   ✅ Тестовое уведомление создано: ${testNotificationId}`);
    console.log(`   ⏳ Ожидаем обработки Cloud Function...`);
    
    // Ждем 3 секунды и проверяем результат
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    const notificationDoc = await db.collection('notifications').doc(testNotificationId).get();
    const notificationData = notificationDoc.data();
    
    console.log('\n   📊 Результат отправки push:');
    console.log(`   Push отправлен: ${notificationData.pushSent ? '✅ ДА' : '❌ НЕТ'}`);
    if (notificationData.pushSent) {
      console.log(`   Успешно доставлено: ${notificationData.pushSuccessCount || 0}`);
      console.log(`   Неудачных попыток: ${notificationData.pushFailureCount || 0}`);
      console.log(`   Использовано токенов: ${notificationData.pushTokensUsed || 0}`);
    } else {
      console.log(`   Ошибка: ${notificationData.pushError || 'Неизвестная ошибка'}`);
      console.log(`   Причина: ${notificationData.noTokensReason || 'Не указана'}`);
    }
  } else {
    console.log('   ❌ Не найдено пользователей с FCM токенами для тестирования');
  }

  // 4. Статистика
  console.log('\n4. 📈 Общая статистика:');
  const notificationsSnapshot = await db.collection('notifications').get();
  console.log(`   Всего уведомлений: ${notificationsSnapshot.size}`);
  
  let sentPushes = 0;
  let failedPushes = 0;
  notificationsSnapshot.forEach(doc => {
    const data = doc.data();
    if (data.pushSent === true) sentPushes++;
    if (data.pushSent === false) failedPushes++;
  });
  
  console.log(`   Успешных push: ${sentPushes}`);
  console.log(`   Неудачных push: ${failedPushes}`);
  console.log(`   Без push данных: ${notificationsSnapshot.size - sentPushes - failedPushes}`);

  console.log('\n' + '=' .repeat(60));
  console.log('🎯 Тестирование завершено!');
  
  // Проверяем что нужно исправить
  console.log('\n💡 Рекомендации:');
  if (fcmTokensSnapshot.size === 0) {
    console.log('❗ В коллекции fcm_tokens нет данных. Войдите в приложение заново.');
  }
  if (usersWithTokens === 0) {
    console.log('❗ В коллекции users нет FCM токенов. Проверьте сохранение токенов.');
  }
  if (fcmTokensSnapshot.size > 0 && usersWithTokens > 0) {
    console.log('✅ FCM токены найдены в обеих коллекциях. Система готова к работе.');
  }
}

// Запускаем тест
testFCMSystem()
  .then(() => {
    console.log('\n🏁 Тест завершен успешно');
    process.exit(0);
  })
  .catch(error => {
    console.error('\n💥 Ошибка при тестировании:', error);
    process.exit(1);
  }); 