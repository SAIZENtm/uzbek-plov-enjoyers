// Простой тест push-уведомлений через уже развернутую Cloud Function
const https = require('https');

async function testPushNotification() {
  try {
    console.log('🚀 Тестируем push-уведомления...');
    
    // Данные для тестового уведомления
    const notificationData = {
      userId: 'AA2807040', // Замените на реальный номер паспорта
      title: 'Тест push-уведомления',
      message: 'Это тестовое уведомление для проверки системы!',
      type: 'system',
      adminName: 'Тест Админ'
    };

    // URL Cloud Function для создания уведомления
    const url = 'https://us-central1-newport-23a19.cloudfunctions.net/createNotification';
    
    const postData = JSON.stringify(notificationData);
    
    const options = {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    console.log('📤 Отправляем запрос на:', url);
    console.log('📋 Данные:', notificationData);

    return new Promise((resolve, reject) => {
      const req = https.request(url, options, (res) => {
        let data = '';
        
        res.on('data', (chunk) => {
          data += chunk;
        });
        
        res.on('end', () => {
          console.log('📨 Статус ответа:', res.statusCode);
          console.log('📄 Ответ сервера:', data);
          
          if (res.statusCode === 200) {
            console.log('✅ Уведомление успешно создано!');
            console.log('📱 Push должен быть отправлен автоматически через onNotificationCreate');
          } else {
            console.log('❌ Ошибка создания уведомления');
          }
          
          resolve();
        });
      });
      
      req.on('error', (error) => {
        console.error('❌ Ошибка запроса:', error);
        reject(error);
      });
      
      req.write(postData);
      req.end();
    });
    
  } catch (error) {
    console.error('❌ Ошибка:', error);
  }
}

console.log('🎯 Инструкция по тестированию:');
console.log('1. Убедитесь, что вы вошли в мобильное приложение');
console.log('2. Замените userId на ваш номер паспорта');
console.log('3. Запустите: node test_push_simple.js');
console.log('4. Проверьте push на телефоне');
console.log('');

// Запускаем тест
testPushNotification().then(() => {
  console.log('🏁 Тест завершен');
  
  console.log('');
  console.log('🔍 Для диагностики запустите:');
  console.log('firebase functions:log --only onNotificationCreate');
}); 