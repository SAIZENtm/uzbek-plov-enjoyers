const admin = require('firebase-admin');

// Используем существующую инициализацию Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function checkFCMData() {
  console.log('🔍 Проверяем данные FCM токенов в Firebase...');
  console.log('=' .repeat(60));

  try {
    // 1. Проверяем коллекцию fcm_tokens
    console.log('\n📱 Проверяем коллекцию fcm_tokens:');
    const fcmTokensSnapshot = await db.collection('fcm_tokens').get();
    console.log(`   Найдено документов: ${fcmTokensSnapshot.size}`);
    
    if (fcmTokensSnapshot.size > 0) {
      fcmTokensSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`   📞 ID: ${doc.id}`);
        console.log(`   📱 Токенов: ${data.tokens?.length || 0}`);
        console.log(`   📄 Паспорт: ${data.passportNumber || 'N/A'}`);
        console.log(`   🏠 Блок: ${data.blockId || 'N/A'}`);
        console.log(`   🚪 Квартира: ${data.apartmentNumber || 'N/A'}`);
        console.log(`   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}`);
        console.log('   ' + '-'.repeat(40));
      });
    } else {
      console.log('   ❌ Документы не найдены');
    }

    // 2. Проверяем коллекцию users
    console.log('\n👤 Проверяем коллекцию users:');
    const usersSnapshot = await db.collection('users').get();
    console.log(`   Найдено документов: ${usersSnapshot.size}`);
    
    if (usersSnapshot.size > 0) {
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmTokens && data.fcmTokens.length > 0) {
          console.log(`   📄 ID: ${doc.id}`);
          console.log(`   📱 FCM токенов: ${data.fcmTokens?.length || 0}`);
          console.log(`   📞 Телефон: ${data.phone || 'N/A'}`);
          console.log(`   🏠 Блок: ${data.blockId || 'N/A'}`);
          console.log(`   🚪 Квартира: ${data.apartmentNumber || 'N/A'}`);
          console.log(`   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}`);
          console.log('   ' + '-'.repeat(40));
        }
      });
    } else {
      console.log('   ❌ Документы с FCM токенами не найдены');
    }

    // 3. Проверяем конкретного пользователя
    console.log('\n🎯 Проверяем конкретного пользователя AA2807040:');
    const userDoc = await db.collection('users').doc('AA2807040').get();
    if (userDoc.exists) {
      const data = userDoc.data();
      console.log(`   📱 FCM токенов: ${data.fcmTokens?.length || 0}`);
      console.log(`   📞 Телефон: ${data.phone || 'N/A'}`);
      console.log(`   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}`);
    } else {
      console.log('   ❌ Пользователь AA2807040 не найден');
    }

    // 4. Проверяем по телефону 998952354500
    console.log('\n📞 Проверяем по телефону 998952354500:');
    const phoneDoc = await db.collection('fcm_tokens').doc('998952354500').get();
    if (phoneDoc.exists) {
      const data = phoneDoc.data();
      console.log(`   📱 Токенов: ${data.tokens?.length || 0}`);
      console.log(`   📄 Паспорт: ${data.passportNumber || 'N/A'}`);
      console.log(`   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}`);
    } else {
      console.log('   ❌ Документ для телефона 998952354500 не найден');
    }

  } catch (error) {
    console.error('❌ Ошибка при проверке данных:', error);
  }
}

checkFCMData().then(() => {
  console.log('\n✅ Проверка завершена');
  process.exit(0);
}).catch(error => {
  console.error('❌ Критическая ошибка:', error);
  process.exit(1);
}); 