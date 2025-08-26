const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const axios = require('axios');

// Инициализация только если не инициализировано
if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ===== КОНФИГУРАЦИЯ TUYA (хранить в Firebase Functions Config) =====
// Установка: firebase functions:config:set tuya.client_id="YOUR_ID" tuya.client_secret="YOUR_SECRET"
const TUYA_CONFIG = {
  baseUrl: 'https://openapi.tuyaeu.com', // Или другой регион
  clientId: functions.config().tuya?.client_id || process.env.TUYA_CLIENT_ID,
  clientSecret: functions.config().tuya?.client_secret || process.env.TUYA_CLIENT_SECRET,
};

// Кэш для токена доступа
let accessTokenCache = {
  token: null,
  expiresAt: null,
};

/**
 * Проверка прав доступа к умному дому
 */
async function canAccessSmartHome(uid, apartmentId) {
  try {
    const apartmentDoc = await db.collection('apartments').doc(apartmentId).get();
    if (!apartmentDoc.exists) return false;
    
    const apartment = apartmentDoc.data();
    
    // Владелец или член семьи
    return apartment.ownerId === uid || 
           (apartment.familyMemberIds && apartment.familyMemberIds.includes(uid));
  } catch (error) {
    console.error('Error checking apartment access:', error);
    return false;
  }
}

/**
 * Генерация подписи для Tuya API
 */
function generateSignature(signStr) {
  const hmac = crypto.createHmac('sha256', TUYA_CONFIG.clientSecret);
  hmac.update(signStr);
  return hmac.digest('hex').toUpperCase();
}

/**
 * Получение токена доступа Tuya
 */
async function getTuyaAccessToken() {
  // Проверка кэша
  if (accessTokenCache.token && accessTokenCache.expiresAt > Date.now()) {
    return accessTokenCache.token;
  }
  
  const timestamp = Date.now().toString();
  const nonce = crypto.randomUUID();
  const signStr = `${TUYA_CONFIG.clientId}${timestamp}${nonce}`;
  const signature = generateSignature(signStr);
  
  const headers = {
    'client_id': TUYA_CONFIG.clientId,
    't': timestamp,
    'sign_method': 'HMAC-SHA256',
    'sign': signature,
    'nonce': nonce,
    'Content-Type': 'application/json',
  };
  
  try {
    const response = await axios.post(
      `${TUYA_CONFIG.baseUrl}/v1.0/token`,
      { grant_type: 'client_credentials' },
      { headers }
    );
    
    if (response.data.success) {
      const { access_token, expire_time } = response.data.result;
      
      // Сохраняем в кэш (обновляем за 5 минут до истечения)
      accessTokenCache = {
        token: access_token,
        expiresAt: Date.now() + ((expire_time - 300) * 1000),
      };
      
      console.log('Tuya access token obtained successfully');
      return access_token;
    } else {
      throw new Error(`Tuya auth failed: ${response.data.msg}`);
    }
  } catch (error) {
    console.error('Failed to get Tuya access token:', error);
    throw error;
  }
}

/**
 * Выполнение запроса к Tuya API
 */
async function makeTuyaRequest(method, endpoint, body = null) {
  const accessToken = await getTuyaAccessToken();
  
  const timestamp = Date.now().toString();
  const nonce = crypto.randomUUID();
  
  // Создание строки для подписи
  const bodyStr = body ? JSON.stringify(body) : '';
  const signStr = `${TUYA_CONFIG.clientId}${accessToken}${timestamp}${nonce}${method}\n\n${bodyStr}\n${endpoint}`;
  const signature = generateSignature(signStr);
  
  const headers = {
    'client_id': TUYA_CONFIG.clientId,
    'access_token': accessToken,
    't': timestamp,
    'sign_method': 'HMAC-SHA256',
    'sign': signature,
    'nonce': nonce,
    'Content-Type': 'application/json',
  };
  
  try {
    const url = `${TUYA_CONFIG.baseUrl}${endpoint}`;
    const config = { headers };
    
    let response;
    switch (method) {
      case 'GET':
        response = await axios.get(url, config);
        break;
      case 'POST':
        response = await axios.post(url, body, config);
        break;
      case 'PUT':
        response = await axios.put(url, body, config);
        break;
      case 'DELETE':
        response = await axios.delete(url, config);
        break;
      default:
        throw new Error(`Unsupported method: ${method}`);
    }
    
    return response.data;
  } catch (error) {
    console.error('Tuya API request failed:', error.response?.data || error.message);
    throw error;
  }
}

// ===== CLOUD FUNCTIONS =====

/**
 * Получить список устройств умного дома
 */
exports.getSmartHomeDevices = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }
  
  const { apartmentId } = data;
  
  if (!apartmentId) {
    throw new functions.https.HttpsError('invalid-argument', 'apartmentId обязателен');
  }
  
  // Проверка доступа
  if (!await canAccessSmartHome(context.auth.uid, apartmentId)) {
    throw new functions.https.HttpsError('permission-denied', 'У вас нет доступа к этой квартире');
  }
  
  try {
    // Получаем устройства из Tuya
    const response = await makeTuyaRequest('GET', '/v1.0/users/devices');
    
    if (response.success) {
      // Фильтруем чувствительные данные перед отправкой клиенту
      const devices = response.result.map(device => ({
        id: device.id,
        name: device.name,
        category: device.category,
        online: device.online,
        status: device.status,
        // Не отправляем: local_key, ip, lat, lon и другие чувствительные данные
      }));
      
      // Сохраняем связь устройств с квартирой
      await db.collection('apartments').doc(apartmentId).update({
        smartHomeDevices: devices.map(d => d.id),
        lastSmartHomeSync: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        devices: devices,
        syncedAt: new Date().toISOString(),
      };
    } else {
      throw new Error(`Failed to get devices: ${response.msg}`);
    }
  } catch (error) {
    console.error('Error getting smart home devices:', error);
    throw new functions.https.HttpsError('internal', 'Ошибка получения устройств', error.message);
  }
});

/**
 * Управление устройством умного дома
 */
exports.controlSmartHomeDevice = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }
  
  const { apartmentId, deviceId, command, value } = data;
  
  // Валидация
  if (!apartmentId || !deviceId || !command || value === undefined) {
    throw new functions.https.HttpsError(
      'invalid-argument', 
      'Требуются: apartmentId, deviceId, command, value'
    );
  }
  
  // Проверка доступа
  if (!await canAccessSmartHome(context.auth.uid, apartmentId)) {
    throw new functions.https.HttpsError('permission-denied', 'У вас нет доступа к этой квартире');
  }
  
  try {
    // Проверяем, что устройство принадлежит квартире
    const apartmentDoc = await db.collection('apartments').doc(apartmentId).get();
    const apartment = apartmentDoc.data();
    
    if (!apartment.smartHomeDevices || !apartment.smartHomeDevices.includes(deviceId)) {
      throw new functions.https.HttpsError(
        'permission-denied', 
        'Устройство не принадлежит вашей квартире'
      );
    }
    
    // Отправляем команду в Tuya
    const response = await makeTuyaRequest('POST', `/v1.0/devices/${deviceId}/commands`, {
      commands: [{
        code: command,
        value: value,
      }],
    });
    
    if (response.success) {
      // Логируем действие
      await db.collection('smartHomeActivityLog').add({
        userId: context.auth.uid,
        apartmentId: apartmentId,
        deviceId: deviceId,
        command: command,
        value: value,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        success: true,
      });
      
      return {
        success: true,
        message: 'Команда выполнена успешно',
      };
    } else {
      throw new Error(`Command failed: ${response.msg}`);
    }
  } catch (error) {
    console.error('Error controlling device:', error);
    
    // Логируем неудачную попытку
    await db.collection('smartHomeActivityLog').add({
      userId: context.auth.uid,
      apartmentId: apartmentId,
      deviceId: deviceId,
      command: command,
      value: value,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      success: false,
      error: error.message,
    });
    
    throw new functions.https.HttpsError('internal', 'Ошибка управления устройством', error.message);
  }
});

/**
 * Получение статуса устройства
 */
exports.getDeviceStatus = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }
  
  const { apartmentId, deviceId } = data;
  
  if (!apartmentId || !deviceId) {
    throw new functions.https.HttpsError('invalid-argument', 'Требуются: apartmentId, deviceId');
  }
  
  // Проверка доступа
  if (!await canAccessSmartHome(context.auth.uid, apartmentId)) {
    throw new functions.https.HttpsError('permission-denied', 'У вас нет доступа');
  }
  
  try {
    const response = await makeTuyaRequest('GET', `/v1.0/devices/${deviceId}/status`);
    
    if (response.success) {
      // Преобразуем статус в удобный формат
      const status = {};
      response.result.forEach(item => {
        status[item.code] = item.value;
      });
      
      return {
        success: true,
        deviceId: deviceId,
        status: status,
        online: true,
        lastUpdate: new Date().toISOString(),
      };
    } else {
      throw new Error(`Failed to get status: ${response.msg}`);
    }
  } catch (error) {
    console.error('Error getting device status:', error);
    throw new functions.https.HttpsError('internal', 'Ошибка получения статуса', error.message);
  }
});

/**
 * Периодическая синхронизация устройств (запускается по расписанию)
 */
exports.syncSmartHomeDevices = functions.pubsub.schedule('every 30 minutes').onRun(async (context) => {
  console.log('Starting smart home devices sync');
  
  try {
    // Получаем все квартиры с умным домом
    const apartmentsSnapshot = await db.collection('apartments')
      .where('smartHomeEnabled', '==', true)
      .get();
    
    let syncCount = 0;
    
    for (const apartmentDoc of apartmentsSnapshot.docs) {
      const apartmentId = apartmentDoc.id;
      
      try {
        // Получаем актуальный список устройств
        const response = await makeTuyaRequest('GET', '/v1.0/users/devices');
        
        if (response.success) {
          const deviceIds = response.result.map(d => d.id);
          
          // Обновляем список в БД
          await apartmentDoc.ref.update({
            smartHomeDevices: deviceIds,
            lastSmartHomeSync: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          syncCount++;
        }
      } catch (error) {
        console.error(`Failed to sync apartment ${apartmentId}:`, error);
      }
    }
    
    console.log(`Smart home sync completed: ${syncCount} apartments synced`);
  } catch (error) {
    console.error('Smart home sync error:', error);
  }
  
  return null;
});
