const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Импортируем функции push уведомлений
const pushNotifications = require('./sendPushNotification');

// Импортируем функции семейной функциональности
const familyFunctions = require('./familyRequestFunctions');

// Импортируем функции приглашений
const inviteFunctions = require('./inviteFunctions');

// Cloud Function для отслеживания ответов администратора в serviceRequests
exports.onServiceRequestUpdate = functions.firestore
  .document('serviceRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const requestId = context.params.requestId;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    console.log(`Service request ${requestId} updated`);

    try {
      // Проверяем, добавился ли ответ администратора
      const adminResponseAdded = !beforeData.adminResponse && afterData.adminResponse;
      const adminResponseUpdated = beforeData.adminResponse !== afterData.adminResponse && afterData.adminResponse;
      
      // Проверяем изменение статуса
      const statusChanged = beforeData.status !== afterData.status;

      if (adminResponseAdded || adminResponseUpdated) {
        console.log(`Admin response detected for request ${requestId}: ${afterData.adminResponse}`);
        
        // Создаем уведомление о ответе администратора
        await createNotificationForAdminResponse(requestId, afterData);
      }

      if (statusChanged) {
        console.log(`Status changed for request ${requestId}: ${beforeData.status} -> ${afterData.status}`);
        
        // Создаем уведомление об изменении статуса
        await createNotificationForStatusChange(requestId, afterData, beforeData.status);
      }

    } catch (error) {
      console.error('Error processing service request update:', error);
    }

    return null;
  });

// Функция для создания уведомления о ответе администратора
async function createNotificationForAdminResponse(requestId, requestData) {
  try {
    // Определяем userId - используем userName если userId неизвестен
    let userId = requestData.userId;
    if (!userId || userId === 'unknown') {
      // Пытаемся найти пользователя по номеру телефона
      userId = await findUserIdByPhone(requestData.userPhone);
      if (!userId) {
        console.warn(`Cannot find userId for request ${requestId}, using phone: ${requestData.userPhone}`);
        userId = requestData.userPhone; // Используем телефон как fallback
      }
    }

    // Проверяем, есть ли уже уведомление с таким же ответом для этой заявки
    const existingNotifications = await db.collection('notifications')
      .where('relatedRequestId', '==', requestId)
      .where('type', '==', 'admin_response')
      .where('message', '==', requestData.adminResponse)
      .limit(1)
      .get();

    if (!existingNotifications.empty) {
      console.log(`Admin response notification already exists for request ${requestId} with same message`);
      return; // Не создаем дублированное уведомление
    }

    const notificationId = `admin_response_${requestId}_${Date.now()}`;
    const notification = {
      id: notificationId,
      userId: userId,
      title: `Ответ на заявку #${requestId.substring(0, 8)}`,
      message: requestData.adminResponse,
      type: 'admin_response',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {
        requestId: requestId,
        requestType: requestData.requestType,
        priority: requestData.priority,
        apartmentNumber: requestData.apartmentNumber,
        block: requestData.block,
        status: requestData.status
      },
      relatedRequestId: requestId,
      adminName: 'Администратор',
      imageUrl: null
    };

    await db.collection('notifications')
      .doc(notificationId)
      .set(notification);

    console.log(`Admin response notification created: ${notificationId} for user: ${userId}`);

  } catch (error) {
    console.error('Error creating admin response notification:', error);
  }
}

// Функция для создания уведомления об изменении статуса
async function createNotificationForStatusChange(requestId, requestData, oldStatus) {
  try {
    // Определяем userId
    let userId = requestData.userId;
    if (!userId || userId === 'unknown') {
      userId = await findUserIdByPhone(requestData.userPhone);
      if (!userId) {
        userId = requestData.userPhone;
      }
    }

    const statusMessages = {
      'pending': 'Ваша заявка получена и ожидает обработки',
      'in-progress': 'Ваша заявка принята в работу',
      'completed': 'Ваша заявка выполнена',
      'cancelled': 'Ваша заявка отменена',
      'on-hold': 'Ваша заявка приостановлена'
    };

    const message = statusMessages[requestData.status] || `Статус заявки изменен на: ${requestData.status}`;

    const notificationId = `status_update_${requestId}_${Date.now()}`;
    const notification = {
      id: notificationId,
      userId: userId,
      title: 'Обновление статуса заявки',
      message: message,
      type: 'service_update',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {
        requestId: requestId,
        requestType: requestData.requestType,
        priority: requestData.priority,
        apartmentNumber: requestData.apartmentNumber,
        block: requestData.block,
        oldStatus: oldStatus,
        newStatus: requestData.status
      },
      relatedRequestId: requestId,
      adminName: 'Система управления',
      imageUrl: null
    };

    await db.collection('notifications')
      .doc(notificationId)
      .set(notification);

    console.log(`Status update notification created: ${notificationId} for user: ${userId}`);

  } catch (error) {
    console.error('Error creating status update notification:', error);
  }
}

// Функция для поиска userId по номеру телефона
async function findUserIdByPhone(phoneNumber) {
  try {
    if (!phoneNumber) return null;

    // Ищем в коллекции users (blocks) -> apartments
    const blocksSnapshot = await db.collection('users').get();
    
    for (const blockDoc of blocksSnapshot.docs) {
      const apartmentsSnapshot = await blockDoc.ref.collection('apartments').get();
      
      for (const apartmentDoc of apartmentsSnapshot.docs) {
        const apartmentData = apartmentDoc.data();
        if (apartmentData.phone === phoneNumber) {
          return apartmentData.passport_number || apartmentData.passportNumber;
        }
      }
    }

    console.log(`User not found for phone: ${phoneNumber}`);
    return null;

  } catch (error) {
    console.error('Error finding user by phone:', error);
    return null;
  }
}

// Cloud Function для создания уведомлений вручную (для тестирования)
exports.createNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const {
      userId,
      title,
      message,
      type = 'admin_response',
      relatedRequestId,
      adminName,
      data = {}
    } = req.body;

    if (!userId || !title || !message) {
      return res.status(400).json({ 
        error: 'Missing required fields: userId, title, message' 
      });
    }

    const notificationId = `manual_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const notification = {
      id: notificationId,
      userId,
      title,
      message,
      type,
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data,
      relatedRequestId: relatedRequestId || null,
      adminName: adminName || 'Администратор',
      imageUrl: null
    };

    await db.collection('notifications')
      .doc(notificationId)
      .set(notification);

    console.log(`Manual notification created: ${notificationId} for user: ${userId}`);

    res.status(200).json({ 
      success: true, 
      notificationId: notificationId,
      message: 'Notification created successfully'
    });

  } catch (error) {
    console.error('Error creating manual notification:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message 
    });
  }
});

// Cloud Function для тестирования - создает тестовое уведомление
exports.createTestNotification = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId parameter is required' });
    }

    const notificationId = `test_${Date.now()}`;
    const notification = {
      id: notificationId,
      userId,
      title: 'Тестовое уведомление',
      message: 'Это тестовое уведомление для проверки системы. Все работает корректно!',
      type: 'system',
      createdAt: new Date().toISOString(),
      readAt: null,
      isRead: false,
      data: {
        test: true,
        timestamp: Date.now()
      },
      relatedRequestId: null,
      adminName: 'Система тестирования',
      imageUrl: null
    };

    await db.collection('notifications')
      .doc(notificationId)
      .set(notification);

    res.status(200).json({ 
      success: true, 
      notificationId,
      message: 'Test notification created successfully'
    });

  } catch (error) {
    console.error('Error creating test notification:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message 
    });
  }
});

// Функция для получения статистики уведомлений
exports.getNotificationStats = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  try {
    const notificationsRef = db.collection('notifications');
    const snapshot = await notificationsRef.get();

    const stats = {
      total: snapshot.size,
      byType: {},
      byStatus: {
        read: 0,
        unread: 0
      },
      recent: 0
    };

    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    snapshot.forEach(doc => {
      const data = doc.data();
      
      stats.byType[data.type] = (stats.byType[data.type] || 0) + 1;
      
      if (data.isRead) {
        stats.byStatus.read++;
      } else {
        stats.byStatus.unread++;
      }
      
      const createdAt = new Date(data.createdAt);
      if (createdAt > oneDayAgo) {
        stats.recent++;
      }
    });

    res.status(200).json(stats);

  } catch (error) {
    console.error('Error getting notification stats:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      details: error.message 
    });
  }
}); 

// Cloud Function: create notification when a new news article is published
exports.onNewsCreate = functions.firestore
  .document('news/{newsId}')
  .onCreate(async (snap, context) => {
    const newsData = snap.data();
    const newsId = context.params.newsId;
    
    console.log('New news article published:', newsId);
    
    // Проверяем, что новость опубликована
    if (newsData.status !== 'published') {
      console.log('News is not published, skipping notifications');
      return;
    }
    
    try {
      console.log('Starting news notification creation...');
      
      // Используем collectionGroup('apartments') как в коде приложения
      const apartmentsSnapshot = await db.collectionGroup('apartments').get();
      
      if (apartmentsSnapshot.empty) {
        console.log('No apartments found using collectionGroup');
        return;
      }
      
      let notificationCount = 0;
      const targetBlocks = newsData.targetBlocks || ['all'];
      
      console.log('Target blocks:', targetBlocks);
      console.log('Found apartments using collectionGroup:', apartmentsSnapshot.size);
      
      // Проходим по каждой квартире
      for (const apartmentDoc of apartmentsSnapshot.docs) {
        const apartmentData = apartmentDoc.data();
        const apartmentNumber = apartmentDoc.id;
        
        // Получаем ID блока из пути документа
        const blockId = apartmentDoc.ref.parent.parent?.id;
        console.log(`Processing apartment ${apartmentNumber} in block ${blockId}`);
        
        // Если указаны конкретные блоки, проверяем соответствие
        if (!targetBlocks.includes('all') && !targetBlocks.includes(blockId)) {
          console.log(`Skipping apartment ${apartmentNumber} - block ${blockId} not in target`);
          continue;
        }
        
        // Ищем passport_number в данных квартиры (как в коде приложения)
        let userId = null;
        
        // Проверяем все возможные поля для passport_number
        if (apartmentData.passport_number) {
          userId = apartmentData.passport_number;
        } else if (apartmentData.passportNumber) {
          userId = apartmentData.passportNumber;
        } else if (apartmentData.client_passport_details) {
          userId = apartmentData.client_passport_details;
        }
        
        if (!userId) {
          console.log(`No passport_number found for apartment ${apartmentNumber} in block ${blockId}`);
          continue;
        }
        
        console.log(`Found user with passport: ${userId} in apartment ${apartmentNumber}, block ${blockId}`);
        
        // Проверяем, не создано ли уже уведомление для этого пользователя
        const existingNotificationQuery = await db.collection('notifications')
          .where('userId', '==', userId)
          .where('type', '==', 'news')
          .where('relatedRequestId', '==', newsId)
          .limit(1)
          .get();
        
        if (!existingNotificationQuery.empty) {
          console.log(`Notification already exists for user ${userId} and news ${newsId}`);
          continue;
        }
        
        // Создаем уведомление
        const notification = {
          userId: userId,
          title: newsData.title || 'Новость',
          message: newsData.preview || newsData.content?.substring(0, 200) || 'Новая новость',
          type: 'news',
          relatedRequestId: newsId,
          imageUrl: newsData.imageUrl || '',
          data: {
            newsId: newsId,
            targetBlocks: targetBlocks,
            isImportant: newsData.isImportant || false,
            ctaLabels: newsData.ctaLabels || [],
            ctaLinks: newsData.ctaLinks || [],
            ctaType: newsData.ctaType || 'internal'
          },
          createdAt: new Date().toISOString(),
          readAt: null,
          isRead: false
        };
        
        await db.collection('notifications').add(notification);
        notificationCount++;
        
        console.log(`Created notification for user: ${userId} from apartment: ${apartmentNumber}, block: ${blockId}`);
      }
      
      console.log(`Created ${notificationCount} news notifications for news ${newsId}`);
      
    } catch (error) {
      console.error('Error creating news notifications:', error);
    }
  });

// Cloud Function: create notification when a new service request is created
exports.onServiceRequestCreate = functions.firestore
  .document('serviceRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = context.params.requestId;

    console.log(`Service request created: ${requestId}`);

    try {
      let userId = requestData.userId;
      if (!userId || userId === 'unknown') {
        userId = await findUserIdByPhone(requestData.userPhone);
        if (!userId) userId = requestData.userPhone;
      }

      const notificationId = `request_created_${requestId}`;
      const notification = {
        id: notificationId,
        userId,
        title: 'Заявка создана',
        message: 'Ваша заявка принята и ожидает обработки',
        type: 'service_update',
        createdAt: new Date().toISOString(),
        readAt: null,
        isRead: false,
        data: {
          requestId,
          requestType: requestData.requestType,
          priority: requestData.priority,
          apartmentNumber: requestData.apartmentNumber,
          block: requestData.block,
          status: requestData.status,
        },
        relatedRequestId: requestId,
        adminName: 'Система управления',
        imageUrl: null,
      };

      await db.collection('notifications').doc(notificationId).set(notification);
      console.log('Service request creation notification stored');
    } catch (error) {
      console.error('Error creating request created notification:', error);
    }
  }); 

// Экспортируем функции push уведомлений
exports.sendPushNotification = pushNotifications.sendPushNotification;
exports.onNotificationCreate = pushNotifications.onNotificationCreate;
exports.cleanupFCMTokens = pushNotifications.cleanupFCMTokens;
exports.testPushNotification = pushNotifications.testPushNotification;

// Импортируем и экспортируем функцию проверки FCM данных
const checkFCM = require('./checkFCMData');
exports.checkFCMData = checkFCM.checkFCMData;

// Cloud Function для поиска пользователей (для диагностики)
exports.searchUsers = functions.https.onRequest(async (req, res) => {
  // Устанавливаем CORS заголовки
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type');
  
  // Обработка preflight запроса
  if (req.method === 'OPTIONS') {
    res.status(200).send('');
    return;
  }

  try {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    console.log(`Searching for user: ${userId}`);
    
    const collections = ['users', 'residents', 'clients'];
    const results = [];
    
    for (const collection of collections) {
      try {
        console.log(`Searching in collection: ${collection}`);
        
        // Поиск по ID документа
        const docRef = db.collection(collection).doc(userId);
        const docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          results.push({
            collection,
            type: 'by_id',
            data: { id: docSnapshot.id, ...docSnapshot.data() }
          });
          console.log(`Found in ${collection} by ID`);
        }

        // Поиск по полю passportNumber
        const passportQuery = await db.collection(collection)
          .where('passportNumber', '==', userId)
          .get();
        
        passportQuery.forEach(doc => {
          results.push({
            collection,
            type: 'by_passport',
            data: { id: doc.id, ...doc.data() }
          });
          console.log(`Found in ${collection} by passport`);
        });

        // Поиск по полю phone
        const phoneQuery = await db.collection(collection)
          .where('phone', '==', userId)
          .get();
        
        phoneQuery.forEach(doc => {
          results.push({
            collection,
            type: 'by_phone',
            data: { id: doc.id, ...doc.data() }
          });
          console.log(`Found in ${collection} by phone`);
        });

        // Поиск по полю phone без + префикса
        const phoneWithoutPlus = userId.startsWith('+') ? userId.substring(1) : `+${userId}`;
        const phoneAltQuery = await db.collection(collection)
          .where('phone', '==', phoneWithoutPlus)
          .get();
        
        phoneAltQuery.forEach(doc => {
          results.push({
            collection,
            type: 'by_phone_alt',
            data: { id: doc.id, ...doc.data() }
          });
          console.log(`Found in ${collection} by phone (alternative format)`);
        });

      } catch (error) {
        console.error(`Error searching in ${collection}:`, error);
      }
    }

    console.log(`Search completed. Found ${results.length} results.`);
    
    res.json({
      success: true,
      results,
      searchTerm: userId,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ 
      error: 'Internal server error',
      message: error.message 
    });
  }
}); 

// Экспортируем функции push уведомлений
exports.sendPushNotification = pushNotifications.sendPushNotification;
exports.onNotificationCreate = pushNotifications.onNotificationCreate;

// Экспортируем функции семейной функциональности
exports.onFamilyRequestCreate = familyFunctions.onFamilyRequestCreate;
exports.onFamilyRequestUpdate = familyFunctions.onFamilyRequestUpdate;
exports.respondToFamilyRequest = familyFunctions.respondToFamilyRequest;
exports.removeFamilyMember = familyFunctions.removeFamilyMember;

// Экспортируем функции приглашений
exports.createFamilyInvite = inviteFunctions.createFamilyInvite;
exports.acceptFamilyInvite = inviteFunctions.acceptFamilyInvite;
exports.revokeFamilyInvite = inviteFunctions.revokeFamilyInvite;
exports.cleanupExpiredInvitations = inviteFunctions.cleanupExpiredInvitations;