const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Инициализируем Admin SDK если еще не инициализирован
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/**
 * Cloud Function для отправки push уведомлений
 * Вызывается из админ панели
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  // Проверяем что запрос от админа
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }

  const { tokens, notification, data: notificationData } = data;

  if (!tokens || tokens.length === 0) {
    console.log('No FCM tokens provided');
    return { success: false, error: 'No tokens' };
  }

  try {
    // Создаем сообщение для FCM
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
        image: notification.image || undefined
      },
      data: {
        ...notificationData,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    // Отправляем multicast для всех токенов
    const response = await admin.messaging().sendMulticast({
      ...message,
      tokens: tokens
    });

    console.log(`Push sent: ${response.successCount} success, ${response.failureCount} failed`);

    // Обрабатываем неудачные токены
    if (response.failureCount > 0) {
      const failedTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.error(`Token ${tokens[idx]} failed:`, resp.error);
          failedTokens.push(tokens[idx]);
        }
      });
      // Здесь можно удалить невалидные токены из базы
    }

    return {
      success: true,
      successCount: response.successCount,
      failureCount: response.failureCount
    };
  } catch (error) {
    console.error('Error sending push notification:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Trigger для автоматической отправки push при создании уведомления
 */
exports.onNotificationCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const notificationId = context.params.notificationId;

    console.log('New notification created:', notificationId);
    console.log('Notification userId:', notification.userId);

    try {
      let fcmTokens = [];
      let foundInApartment = false;

      // Основной способ: поиск в коллекции квартир
      console.log('Searching for user by notification.userId:', notification.userId);
      
      // Ищем квартиру пользователя через collectionGroup
      let apartmentDoc = null;
      
      // Поиск по паспорту
      if (notification.userId && !notification.userId.startsWith('+')) {
        console.log('Searching apartments by passport_number:', notification.userId);
        const apartmentsByPassport = await admin.firestore()
          .collectionGroup('apartments')
          .where('passport_number', '==', notification.userId)
          .limit(1)
          .get();
          
        if (!apartmentsByPassport.empty) {
          apartmentDoc = apartmentsByPassport.docs[0];
          console.log('Found apartment by passport_number');
        }
      }
      
      // Поиск по телефону
      if (!apartmentDoc && notification.userId?.startsWith('+')) {
        console.log('Searching apartments by phone:', notification.userId);
        const apartmentsByPhone = await admin.firestore()
          .collectionGroup('apartments')
          .where('phone', '==', notification.userId)
          .limit(1)
          .get();
          
        if (!apartmentsByPhone.empty) {
          apartmentDoc = apartmentsByPhone.docs[0];
          console.log('Found apartment by phone');
        }
      }
      
      // Если нашли квартиру, получаем FCM токены из нее
      if (apartmentDoc) {
        const apartmentData = apartmentDoc.data();
        fcmTokens = apartmentData.fcmTokens || [];
        foundInApartment = true;
        
        const blockId = apartmentDoc.ref.parent.parent?.id;
        const apartmentNumber = apartmentDoc.id;
        console.log(`Found ${fcmTokens.length} FCM tokens in apartment: ${blockId}/apartments/${apartmentNumber}`);
      }

      // Запасной способ 1: коллекция fcm_tokens по телефону
      if (!foundInApartment && fcmTokens.length === 0) {
        const normalizedPhone = notification.userId?.toString().replaceAll('+', '').replaceAll(' ', '');
        if (normalizedPhone && normalizedPhone.length > 5) {
          console.log('Fallback: Searching fcm_tokens by phone:', normalizedPhone);
          const fcmTokenDoc = await admin.firestore()
            .collection('fcm_tokens')
            .doc(normalizedPhone)
            .get();

          if (fcmTokenDoc.exists) {
            const fcmData = fcmTokenDoc.data();
            fcmTokens = fcmData.tokens || [];
            console.log(`Found ${fcmTokens.length} FCM tokens in fcm_tokens collection`);
          }
        }
      }

      // Запасной способ 2: коллекция users по passport
      if (!foundInApartment && fcmTokens.length === 0) {
        console.log('Fallback: Searching users by passport:', notification.userId);
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(notification.userId)
          .get();

        if (userDoc.exists) {
          const userData = userDoc.data();
          fcmTokens = userData.fcmTokens || [];
          console.log(`Found ${fcmTokens.length} FCM tokens in users collection`);
        }
      }

      if (fcmTokens.length === 0) {
        console.log('No FCM tokens found for user:', notification.userId);
        // Отмечаем что push не отправлен из-за отсутствия токенов
        await snap.ref.update({
          pushSent: false,
          pushError: 'No FCM tokens found',
          noTokensReason: 'User has no registered FCM tokens'
        });
        return;
      }

      console.log(`Preparing to send push to ${fcmTokens.length} tokens`);

      // Формируем сообщение
      const message = {
        notification: {
          title: notification.title,
          body: notification.message
        },
        data: {
          type: notification.type || 'system',
          notificationId: notificationId,
          userId: notification.userId,
          ...(notification.relatedRequestId && { requestId: notification.relatedRequestId }),
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'high_importance_channel'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      // Отправляем push
      const response = await admin.messaging().sendMulticast({
        ...message,
        tokens: fcmTokens
      });

      console.log(`Push sent for notification ${notificationId}: ${response.successCount} success, ${response.failureCount} failed`);

      // Обрабатываем неудачные токены
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Token ${fcmTokens[idx]} failed:`, resp.error?.code);
            failedTokens.push({
              token: fcmTokens[idx],
              error: resp.error?.code || 'unknown'
            });
          }
        });
        console.log('Failed tokens:', failedTokens);
      }

      // Обновляем статус доставки в документе уведомления
      await snap.ref.update({
        pushSent: true,
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushSuccessCount: response.successCount,
        pushFailureCount: response.failureCount,
        pushTokensUsed: fcmTokens.length
      });

    } catch (error) {
      console.error('Error sending push for notification:', error);
      // Отмечаем ошибку отправки
      await snap.ref.update({
        pushSent: false,
        pushError: error.message,
        pushErrorCode: error.code || 'unknown'
      });
    }
  });

/**
 * Функция для очистки старых FCM токенов
 */
exports.cleanupFCMTokens = functions.pubsub.schedule('every 24 hours').onRun(async (context) => {
  console.log('Starting FCM token cleanup');
  
  const usersSnapshot = await admin.firestore().collection('users').get();
  let cleanedCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens || [];
    
    if (fcmTokens.length === 0) continue;

    // Проверяем валидность токенов
    const validTokens = [];
    
    for (const token of fcmTokens) {
      try {
        // Dry run для проверки токена
        await admin.messaging().send({
          token: token,
          notification: { title: 'Test' }
        }, true);
        validTokens.push(token);
      } catch (error) {
        console.log(`Invalid token for user ${userDoc.id}: ${token}`);
      }
    }

    // Обновляем только если есть изменения
    if (validTokens.length !== fcmTokens.length) {
      await userDoc.ref.update({
        fcmTokens: validTokens
      });
      cleanedCount++;
    }
  }

  console.log(`FCM token cleanup completed. Cleaned ${cleanedCount} users`);
  return null;
});

/**
 * HTTP Cloud Function для тестирования push уведомлений
 * Используется для отправки тестовых push из браузера
 */
exports.testPushNotification = functions.https.onRequest(async (req, res) => {
  // Настройка CORS для работы из браузера
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
    const { tokens, notification, data: notificationData } = req.body;

    if (!tokens || tokens.length === 0) {
      return res.status(400).json({ 
        success: false, 
        error: 'No FCM tokens provided' 
      });
    }

    if (!notification || !notification.title || !notification.body) {
      return res.status(400).json({ 
        success: false, 
        error: 'Notification title and body are required' 
      });
    }

    console.log(`Sending test push to ${tokens.length} tokens`);

    // Создаем сообщение для FCM
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
        image: notification.image || undefined
      },
      data: {
        type: 'test',
        source: 'test_function',
        timestamp: Date.now().toString(),
        ...notificationData
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          channelId: 'high_importance_channel'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    // Отправляем к каждому токену
    const results = [];
    const invalidTokens = [];

    for (const token of tokens) {
      try {
        const response = await admin.messaging().send({
          ...message,
          token: token
        });
        
        results.push({
          token: token.substring(0, 10) + '...',
          success: true,
          messageId: response
        });
        
        console.log(`Push sent successfully to token ${token.substring(0, 10)}...`);
        
      } catch (error) {
        console.error(`Failed to send push to token ${token.substring(0, 10)}...:`, error.message);
        
        results.push({
          token: token.substring(0, 10) + '...',
          success: false,
          error: error.message
        });

        // Если токен недействителен, добавляем в список для удаления
        if (error.code === 'messaging/registration-token-not-registered' ||
            error.code === 'messaging/invalid-registration-token') {
          invalidTokens.push(token);
        }
      }
    }

    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;

    console.log(`Push notification results: ${successCount} success, ${failureCount} failures`);

    res.status(200).json({
      success: true,
      message: `Push notifications sent`,
      results: {
        total: tokens.length,
        successful: successCount,
        failed: failureCount,
        invalidTokens: invalidTokens.length,
        details: results
      }
    });

  } catch (error) {
    console.error('Error in testPushNotification:', error);
    res.status(500).json({
      success: false,
      error: 'Internal server error',
      details: error.message
    });
  }
}); 