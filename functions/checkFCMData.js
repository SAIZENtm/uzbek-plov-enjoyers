const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.checkFCMData = functions.https.onRequest(async (req, res) => {
  const db = admin.firestore();
  
  try {
    console.log('🔍 Проверяем данные FCM токенов в Firebase...');
    let result = '🔍 Проверяем данные FCM токенов в Firebase...\n';
    result += '='.repeat(60) + '\n\n';

    // 1. Проверяем коллекцию fcm_tokens
    result += '📱 Проверяем коллекцию fcm_tokens:\n';
    const fcmTokensSnapshot = await db.collection('fcm_tokens').get();
    result += `   Найдено документов: ${fcmTokensSnapshot.size}\n`;
    
    if (fcmTokensSnapshot.size > 0) {
      fcmTokensSnapshot.forEach(doc => {
        const data = doc.data();
        result += `   📞 ID: ${doc.id}\n`;
        result += `   📱 Токенов: ${data.tokens?.length || 0}\n`;
        result += `   📄 Паспорт: ${data.passportNumber || 'N/A'}\n`;
        result += `   🏠 Блок: ${data.blockId || 'N/A'}\n`;
        result += `   🚪 Квартира: ${data.apartmentNumber || 'N/A'}\n`;
        result += `   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}\n`;
        result += '   ' + '-'.repeat(40) + '\n';
      });
    } else {
      result += '   ❌ Документы не найдены\n';
    }

    // 2. Проверяем коллекцию users
    result += '\n👤 Проверяем коллекцию users:\n';
    const usersSnapshot = await db.collection('users').get();
    result += `   Найдено документов: ${usersSnapshot.size}\n`;
    
    let usersWithTokens = 0;
    if (usersSnapshot.size > 0) {
      usersSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmTokens && data.fcmTokens.length > 0) {
          usersWithTokens++;
          result += `   📄 ID: ${doc.id}\n`;
          result += `   📱 FCM токенов: ${data.fcmTokens?.length || 0}\n`;
          result += `   📞 Телефон: ${data.phone || 'N/A'}\n`;
          result += `   🏠 Блок: ${data.blockId || 'N/A'}\n`;
          result += `   🚪 Квартира: ${data.apartmentNumber || 'N/A'}\n`;
          result += `   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}\n`;
          result += '   ' + '-'.repeat(40) + '\n';
        }
      });
    }
    
    if (usersWithTokens === 0) {
      result += '   ❌ Документы с FCM токенами не найдены\n';
    }

    // 3. Проверяем конкретного пользователя
    result += '\n🎯 Проверяем конкретного пользователя AA2807040:\n';
    const userDoc = await db.collection('users').doc('AA2807040').get();
    if (userDoc.exists) {
      const data = userDoc.data();
      result += `   📱 FCM токенов: ${data.fcmTokens?.length || 0}\n`;
      result += `   📞 Телефон: ${data.phone || 'N/A'}\n`;
      result += `   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}\n`;
    } else {
      result += '   ❌ Пользователь AA2807040 не найден\n';
    }

    // 4. Проверяем по телефону 998952354500
    result += '\n📞 Проверяем по телефону 998952354500:\n';
    const phoneDoc = await db.collection('fcm_tokens').doc('998952354500').get();
    if (phoneDoc.exists) {
      const data = phoneDoc.data();
      result += `   📱 Токенов: ${data.tokens?.length || 0}\n`;
      result += `   📄 Паспорт: ${data.passportNumber || 'N/A'}\n`;
      result += `   ⏰ Обновлено: ${data.lastTokenUpdate?.toDate?.() || 'N/A'}\n`;
    } else {
      result += '   ❌ Документ для телефона 998952354500 не найден\n';
    }

    result += '\n✅ Проверка завершена\n';
    
    res.set('Content-Type', 'text/plain; charset=utf-8');
    res.send(result);

  } catch (error) {
    console.error('❌ Ошибка при проверке данных:', error);
    res.status(500).send(`❌ Ошибка: ${error.message}`);
  }
}); 