const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Импортируем функции
const pushNotifications = require('./sendPushNotification');
const familyFunctions = require('./familyRequestFunctions');
const inviteFunctions = require('./inviteFunctions');

// ===== HELPER ФУНКЦИИ =====

/**
 * Проверка является ли пользователь администратором
 */
async function isAdmin(uid) {
  if (!uid) return false;
  
  try {
    const adminDoc = await db.collection('admins').doc(uid).get();
    return adminDoc.exists;
  } catch (error) {
    console.error('Error checking admin status:', error);
    return false;
  }
}

/**
 * Проверка доступа к данным пользователя
 */
async function canAccessUserData(requesterId, targetUserId) {
  // Пользователь может видеть свои данные
  if (requesterId === targetUserId) return true;
  
  // Админ может видеть все
  if (await isAdmin(requesterId)) return true;
  
  // Проверка семейных связей
  try {
    const requesterProfile = await db.collection('userProfiles').doc(requesterId).get();
    const targetProfile = await db.collection('userProfiles').doc(targetUserId).get();
    
    if (requesterProfile.exists && targetProfile.exists) {
      const requesterData = requesterProfile.data();
      const targetData = targetProfile.data();
      
      // Проверяем принадлежность к одной квартире
      return requesterData.apartmentNumber === targetData.apartmentNumber &&
             requesterData.blockId === targetData.blockId;
    }
  } catch (error) {
    console.error('Error checking user access:', error);
  }
  
  return false;
}

// ===== ЗАЩИЩЕННЫЕ ФУНКЦИИ =====

/**
 * Создание уведомления (только для админов)
 */
exports.createNotification = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Требуется аутентификация'
    );
  }
  
  // Проверка прав администратора
  if (!await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Требуются права администратора'
    );
  }
  
  const {
    userId,
    title,
    message,
    type = 'admin_response',
    relatedRequestId,
    adminName,
    data: notificationData = {}
  } = data;
  
  // Валидация обязательных полей
  if (!userId || !title || !message) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Отсутствуют обязательные поля: userId, title, message'
    );
  }
  
  try {
    const notificationId = `manual_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    const notification = {
      id: notificationId,
      userId,
      title,
      message,
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      readAt: null,
      isRead: false,
      data: notificationData,
      relatedRequestId: relatedRequestId || null,
      adminName: adminName || context.auth.token.name || 'Администратор',
      imageUrl: null,
      createdBy: context.auth.uid
    };
    
    await db.collection('notifications')
      .doc(notificationId)
      .set(notification);
    
    console.log(`Notification created by admin ${context.auth.uid}: ${notificationId}`);
    
    return {
      success: true,
      notificationId: notificationId,
      message: 'Уведомление создано успешно'
    };
  } catch (error) {
    console.error('Error creating notification:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка создания уведомления',
      error.message
    );
  }
});

/**
 * Получение статистики уведомлений (только для админов)
 */
exports.getNotificationStats = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Требуется аутентификация'
    );
  }
  
  // Проверка прав администратора
  if (!await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Требуются права администратора'
    );
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
      recent: 0,
      requestedBy: context.auth.uid,
      requestedAt: new Date().toISOString()
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
      
      const createdAt = data.createdAt?.toDate() || new Date(0);
      if (createdAt > oneDayAgo) {
        stats.recent++;
      }
    });
    
    console.log(`Notification stats requested by admin ${context.auth.uid}`);
    
    return stats;
  } catch (error) {
    console.error('Error getting notification stats:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка получения статистики',
      error.message
    );
  }
});

/**
 * Поиск пользователей (с проверкой прав)
 */
exports.searchUsers = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Требуется аутентификация'
    );
  }
  
  const { userId } = data;
  
  if (!userId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'userId обязателен'
    );
  }
  
  // Проверка прав доступа
  if (!await canAccessUserData(context.auth.uid, userId)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'У вас нет доступа к данным этого пользователя'
    );
  }
  
  try {
    console.log(`User search by ${context.auth.uid} for: ${userId}`);
    
    const collections = ['userProfiles', 'residents', 'clients'];
    const results = [];
    
    for (const collection of collections) {
      try {
        // Поиск по ID документа
        const docRef = db.collection(collection).doc(userId);
        const docSnapshot = await docRef.get();
        
        if (docSnapshot.exists) {
          // Фильтруем чувствительные данные для не-админов
          const data = docSnapshot.data();
          if (!await isAdmin(context.auth.uid)) {
            delete data.passportNumber;
            delete data.fcmTokens;
            delete data.email;
          }
          
          results.push({
            collection,
            type: 'by_id',
            data: { id: docSnapshot.id, ...data }
          });
        }
      } catch (error) {
        console.error(`Error searching in ${collection}:`, error);
      }
    }
    
    return {
      success: true,
      results,
      searchTerm: userId,
      searchedBy: context.auth.uid,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error('Search users error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка поиска',
      error.message
    );
  }
});

/**
 * Тестовое уведомление (только для разработки)
 */
if (process.env.FUNCTIONS_EMULATOR || process.env.NODE_ENV === 'development') {
  exports.createTestNotification = functions.https.onCall(async (data, context) => {
    // В production эта функция недоступна
    if (process.env.NODE_ENV === 'production') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Тестовые функции недоступны в production'
      );
    }
    
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Требуется аутентификация'
      );
    }
    
    const { userId } = data;
    
    if (!userId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'userId обязателен'
      );
    }
    
    try {
      const notificationId = `test_${Date.now()}`;
      const notification = {
        id: notificationId,
        userId,
        title: 'Тестовое уведомление',
        message: 'Это тестовое уведомление для проверки системы',
        type: 'system',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        readAt: null,
        isRead: false,
        data: {
          test: true,
          timestamp: Date.now()
        },
        createdBy: context.auth.uid
      };
      
      await db.collection('notifications')
        .doc(notificationId)
        .set(notification);
      
      return {
        success: true,
        notificationId,
        message: 'Тестовое уведомление создано'
      };
    } catch (error) {
      throw new functions.https.HttpsError(
        'internal',
        'Ошибка создания тестового уведомления',
        error.message
      );
    }
  });
}

// ===== ТРИГГЕРЫ (остаются без изменений) =====

/**
 * Обработка обновления сервисных заявок
 */
exports.onServiceRequestUpdate = functions.firestore
  .document('serviceRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const requestId = context.params.requestId;
    const beforeData = change.before.data();
    const afterData = change.after.data();
    
    console.log(`Service request ${requestId} updated`);
    
    try {
      // Проверяем изменения
      const adminResponseAdded = !beforeData.adminResponse && afterData.adminResponse;
      const statusChanged = beforeData.status !== afterData.status;
      
      if (adminResponseAdded) {
        await createNotificationForAdminResponse(requestId, afterData);
      }
      
      if (statusChanged) {
        await createNotificationForStatusChange(requestId, afterData, beforeData.status);
      }
    } catch (error) {
      console.error('Error processing service request update:', error);
    }
    
    return null;
  });

/**
 * Обработка создания новостей
 */
exports.onNewsCreate = functions.firestore
  .document('news/{newsId}')
  .onCreate(async (snap, context) => {
    const newsData = snap.data();
    const newsId = context.params.newsId;
    
    if (newsData.status !== 'published') {
      return;
    }
    
    try {
      // Создание уведомлений для целевой аудитории
      const targetBlocks = newsData.targetBlocks || ['all'];
      const apartmentsSnapshot = await db.collectionGroup('apartments').get();
      
      let notificationCount = 0;
      
      for (const apartmentDoc of apartmentsSnapshot.docs) {
        const apartmentData = apartmentDoc.data();
        const blockId = apartmentDoc.ref.parent.parent?.id;
        
        if (!targetBlocks.includes('all') && !targetBlocks.includes(blockId)) {
          continue;
        }
        
        const userId = apartmentData.passport_number || 
                      apartmentData.passportNumber || 
                      apartmentData.client_passport_details;
        
        if (!userId) continue;
        
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
            isImportant: newsData.isImportant || false
          },
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          readAt: null,
          isRead: false
        };
        
        await db.collection('notifications').add(notification);
        notificationCount++;
      }
      
      console.log(`Created ${notificationCount} news notifications for news ${newsId}`);
    } catch (error) {
      console.error('Error creating news notifications:', error);
    }
  });

// ===== HELPER ФУНКЦИИ ДЛЯ ТРИГГЕРОВ =====

async function createNotificationForAdminResponse(requestId, requestData) {
  // ... (код остается тот же)
}

async function createNotificationForStatusChange(requestId, requestData, oldStatus) {
  // ... (код остается тот же)
}

async function findUserIdByPhone(phoneNumber) {
  // ... (код остается тот же)
}

// ===== ЭКСПОРТ ЗАЩИЩЕННЫХ ФУНКЦИЙ =====

// Push уведомления (требуют аутентификации)
exports.sendPushNotification = pushNotifications.sendPushNotification;
exports.onNotificationCreate = pushNotifications.onNotificationCreate;
exports.cleanupFCMTokens = pushNotifications.cleanupFCMTokens;

// Семейные функции
exports.onFamilyRequestCreate = familyFunctions.onFamilyRequestCreate;
exports.onFamilyRequestUpdate = familyFunctions.onFamilyRequestUpdate;
exports.respondToFamilyRequest = familyFunctions.respondToFamilyRequest;
exports.removeFamilyMember = familyFunctions.removeFamilyMember;

// Приглашения
exports.createFamilyInvite = inviteFunctions.createFamilyInvite;
exports.acceptFamilyInvite = inviteFunctions.acceptFamilyInvite;
exports.revokeFamilyInvite = inviteFunctions.revokeFamilyInvite;
exports.cleanupExpiredInvitations = inviteFunctions.cleanupExpiredInvitations;
