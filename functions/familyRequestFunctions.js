const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Триггер для автоматической обработки создания семейного запроса
 * Отправляет push-уведомление владельцу квартиры
 */
exports.onFamilyRequestCreate = functions.firestore
  .document('familyRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = context.params.requestId;

    console.log('New family request created:', requestId);
    console.log('Request data:', requestData);

    try {
      // Ищем квартиру по blockId и apartmentNumber
      let apartmentDoc = null;
      
      // Сначала пробуем поиск в коллекции apartments
      const apartmentQuery = await admin.firestore()
        .collection('apartments')
        .where('blockId', '==', requestData.blockId)
        .where('apartment_number', '==', requestData.apartmentNumber)
        .limit(1)
        .get();

      if (!apartmentQuery.empty) {
        apartmentDoc = apartmentQuery.docs[0];
      } else {
        // Если не найдено, пробуем через collection group
        const groupQuery = await admin.firestore()
          .collectionGroup('apartments')
          .where('block_name', '==', requestData.blockId)
          .where('apartment_number', '==', requestData.apartmentNumber)
          .limit(1)
          .get();

        if (!groupQuery.empty) {
          apartmentDoc = groupQuery.docs[0];
        }
      }

      if (!apartmentDoc) {
        console.log('Apartment not found for request:', requestId);
        await snap.ref.update({
          status: 'rejected',
          rejectionReason: 'Квартира не найдена'
        });
        return;
      }

      const apartmentData = apartmentDoc.data();
      console.log('Found apartment:', apartmentDoc.id);

      // Проверяем, что квартира активирована и есть владелец
      if (!apartmentData.isActivated || !apartmentData.ownerId) {
        console.log('Apartment not activated or no owner');
        await snap.ref.update({
          status: 'rejected',
          rejectionReason: 'Квартира не активирована или не имеет владельца'
        });
        return;
      }

      // Обновляем запрос с ID квартиры
      await snap.ref.update({
        apartmentId: apartmentDoc.id
      });

      // Ищем FCM токены владельца
      let fcmTokens = [];
      
      // Поиск по ownerId в коллекции users или apartments
      const ownerQuery = await admin.firestore()
        .collectionGroup('apartments')
        .where('passport_number', '==', apartmentData.ownerId)
        .limit(1)
        .get();

      if (!ownerQuery.empty) {
        const ownerApartment = ownerQuery.docs[0].data();
        if (ownerApartment.fcmTokens && Array.isArray(ownerApartment.fcmTokens)) {
          fcmTokens = ownerApartment.fcmTokens;
        }
      }

      // Запасной поиск в коллекции users
      if (fcmTokens.length === 0) {
        const userDoc = await admin.firestore()
          .collection('users')
          .doc(apartmentData.ownerId)
          .get();

        if (userDoc.exists) {
          const userData = userDoc.data();
          if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
            fcmTokens = userData.fcmTokens;
          }
        }
      }

      if (fcmTokens.length === 0) {
        console.log('No FCM tokens found for owner:', apartmentData.ownerId);
        return;
      }

      console.log(`Sending notification to ${fcmTokens.length} tokens`);

      // Формируем уведомление для владельца
      const message = {
        notification: {
          title: 'Новый запрос в семью',
          body: `${requestData.name} просит присоединиться к вашей семье в роли "${requestData.role}"`
        },
        data: {
          type: 'family_request',
          requestId: requestId,
          applicantName: requestData.name,
          applicantRole: requestData.role,
          apartment: `${requestData.blockId}-${requestData.apartmentNumber}`,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'family_requests_channel'
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

      // Отправляем уведомления
      const response = await admin.messaging().sendToDevice(fcmTokens, message);
      
      console.log(`Family request notification sent: ${response.successCount} success, ${response.failureCount} failed`);

      // Обрабатываем неудачные токены
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            console.error(`Token ${fcmTokens[idx]} failed:`, resp.error);
            failedTokens.push(fcmTokens[idx]);
          }
        });
      }

      return {
        success: true,
        notificationsSent: response.successCount
      };

    } catch (error) {
      console.error('Error processing family request:', error);
      
      // Помечаем запрос как ошибочный
      await snap.ref.update({
        status: 'error',
        errorMessage: error.message
      });
      
      throw error;
    }
  });

/**
 * Триггер для обработки ответа на семейный запрос
 * Отправляет уведомление заявителю о решении владельца
 */
exports.onFamilyRequestUpdate = functions.firestore
  .document('familyRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;

    // Проверяем, изменился ли статус на approved или rejected
    if (before.status === 'pending' && (after.status === 'approved' || after.status === 'rejected')) {
      console.log(`Family request ${requestId} status changed to: ${after.status}`);

      try {
        // Получаем FCM токен заявителя
        const applicantToken = after.fcmToken;
        
        if (!applicantToken) {
          console.log('No FCM token found for applicant');
          return;
        }

        // Формируем сообщение в зависимости от решения
        const isApproved = after.status === 'approved';
        const title = isApproved ? 'Запрос одобрен!' : 'Запрос отклонен';
        const body = isApproved 
          ? 'Ваш запрос на присоединение к семье одобрен. Завершите регистрацию по номеру телефона.'
          : `Ваш запрос отклонен. ${after.rejectionReason || ''}`.trim();

        const message = {
          notification: {
            title: title,
            body: body
          },
          data: {
            type: 'family_request_response',
            requestId: requestId,
            status: after.status,
            apartmentId: after.apartmentId || '',
            ...(isApproved && { action: 'complete_registration' }),
            click_action: 'FLUTTER_NOTIFICATION_CLICK'
          },
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: isApproved ? 'family_approved_channel' : 'family_rejected_channel'
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

        // Отправляем уведомление заявителю
        const response = await admin.messaging().sendToDevice([applicantToken], message);
        
        console.log(`Family request response notification sent: ${response.successCount} success, ${response.failureCount} failed`);

        if (response.failureCount > 0) {
          console.error('Failed to send notification to applicant:', response.responses[0].error);
        }

        return {
          success: true,
          notificationSent: response.successCount > 0
        };

      } catch (error) {
        console.error('Error sending family request response notification:', error);
        throw error;
      }
    }

    return null;
  });

/**
 * Callable функция для ответа на семейный запрос
 * Используется как альтернатива прямому обновлению документа
 */
exports.respondToFamilyRequest = functions.https.onCall(async (data, context) => {
  // Проверяем аутентификацию
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { requestId, approved, rejectionReason } = data;

  if (!requestId || typeof approved !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const requestRef = admin.firestore().collection('familyRequests').doc(requestId);
    const requestDoc = await requestRef.get();

    if (!requestDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Family request not found');
    }

    const requestData = requestDoc.data();

    // Проверяем, что пользователь - владелец квартиры
    if (requestData.apartmentId) {
      const apartmentDoc = await admin.firestore()
        .collection('apartments')
        .doc(requestData.apartmentId)
        .get();

      if (apartmentDoc.exists) {
        const apartmentData = apartmentDoc.data();
        if (apartmentData.ownerId !== context.auth.uid) {
          throw new functions.https.HttpsError('permission-denied', 'Only apartment owner can respond to requests');
        }
      }
    }

    // Обновляем статус запроса
    const updateData = {
      status: approved ? 'approved' : 'rejected',
      respondedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    if (!approved && rejectionReason) {
      updateData.rejectionReason = rejectionReason;
    }

    await requestRef.update(updateData);

    console.log(`Family request ${requestId} ${approved ? 'approved' : 'rejected'} by user ${context.auth.uid}`);

    return {
      success: true,
      status: approved ? 'approved' : 'rejected'
    };

  } catch (error) {
    console.error('Error responding to family request:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Internal server error');
  }
});

/**
 * Callable функция для удаления члена семьи
 */
exports.removeFamilyMember = functions.https.onCall(async (data, context) => {
  // Проверяем аутентификацию
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { apartmentId, memberId } = data;

  if (!apartmentId || !memberId) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
  }

  try {
    const apartmentRef = admin.firestore().collection('apartments').doc(apartmentId);
    const apartmentDoc = await apartmentRef.get();

    if (!apartmentDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Apartment not found');
    }

    const apartmentData = apartmentDoc.data();

    // Проверяем, что пользователь - владелец квартиры
    if (apartmentData.ownerId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'Only apartment owner can remove family members');
    }

    // Получаем текущий список членов семьи
    const familyMembers = apartmentData.familyMembers || [];
    
    // Находим и удаляем члена семьи
    const updatedMembers = familyMembers.filter(member => member.memberId !== memberId);

    if (updatedMembers.length === familyMembers.length) {
      throw new functions.https.HttpsError('not-found', 'Family member not found');
    }

    // Обновляем документ квартиры
    await apartmentRef.update({
      familyMembers: updatedMembers
    });

    // Удаляем профиль пользователя (опционально)
    try {
      await admin.firestore().collection('users').doc(memberId).delete();
      console.log(`User profile deleted for member: ${memberId}`);
    } catch (error) {
      console.log(`Failed to delete user profile for member ${memberId}:`, error);
      // Не прерываем выполнение, если не удалось удалить профиль
    }

    console.log(`Family member ${memberId} removed from apartment ${apartmentId} by owner ${context.auth.uid}`);

    return {
      success: true,
      message: 'Family member removed successfully'
    };

  } catch (error) {
    console.error('Error removing family member:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Internal server error');
  }
}); 