// Проверка пользователей в Firestore
const https = require('https');

async function checkUser(userId) {
  const url = `https://us-central1-newport-23a19.cloudfunctions.net/searchUsers?query=${userId}`;
  
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      
      res.on('data', (chunk) => {
        data += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          resolve(result);
        } catch (e) {
          resolve({ error: 'Invalid JSON', data });
        }
      });
    }).on('error', (error) => {
      reject(error);
    });
  });
}

async function checkAllUsers() {
  console.log('🔍 Проверяем пользователей в Firestore...\n');
  
  // Список ID из логов (пользователи для которых создавались уведомления)
  const userIds = [
    'AA2807040',
    'AD0066548', 
    'AD2427427',
    'AA2005264',
    'AD2100470',
    'AD1914183',
    'AA3599472'
  ];
  
  for (const userId of userIds) {
    try {
      console.log(`👤 Проверяем пользователя: ${userId}`);
      const result = await checkUser(userId);
      
      if (result.users && result.users.length > 0) {
        const user = result.users[0];
        console.log(`✅ Найден!`);
        console.log(`   📱 FCM токенов: ${user.fcmTokens?.length || 0}`);
        console.log(`   🏠 Блок: ${user.blockId || 'Не указан'}`);
        console.log(`   🚪 Квартира: ${user.apartmentNumber || 'Не указана'}`);
        console.log(`   📞 Телефон: ${user.phone || 'Не указан'}`);
      } else {
        console.log(`❌ Не найден в коллекции users`);
      }
      console.log('');
      
      // Пауза между запросами
      await new Promise(resolve => setTimeout(resolve, 500));
      
    } catch (error) {
      console.log(`❌ Ошибка: ${error.message}\n`);
    }
  }
}

console.log('📋 Структура пользователя в Firestore должна быть:');
console.log('');
console.log('Коллекция: users');
console.log('Документ: [номер паспорта]');
console.log('Поля:');
console.log('  ├── fcmTokens: [массив строк]');
console.log('  ├── lastTokenUpdate: timestamp');
console.log('  ├── blockId: string');
console.log('  ├── apartmentNumber: string');
console.log('  └── phone: string');
console.log('');
console.log('🔧 Для админ-панели используйте:');
console.log('collection("users").doc(passportNumber)');
console.log('');

checkAllUsers().then(() => {
  console.log('🏁 Проверка завершена');
  console.log('');
  console.log('💡 Если пользователи не найдены:');
  console.log('1. Войдите в мобильное приложение');
  console.log('2. Проверьте логи: firebase functions:log');
  console.log('3. Повторите проверку');
}); 