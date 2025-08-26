const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');
const axios = require('axios');

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

// ===== КОНФИГУРАЦИЯ PAYME =====
// firebase functions:config:set payme.merchant_id="YOUR_ID" payme.key="YOUR_KEY"
const PAYME_CONFIG = {
  merchantId: functions.config().payme?.merchant_id || process.env.PAYME_MERCHANT_ID,
  key: functions.config().payme?.key || process.env.PAYME_KEY,
  baseUrl: process.env.NODE_ENV === 'production' 
    ? 'https://checkout.paycom.uz' 
    : 'https://checkout.test.paycom.uz',
};

// ===== HELPER ФУНКЦИИ =====

/**
 * Генерация идемпотентного ключа
 */
function generateIdempotencyKey(userId, amount, purpose) {
  const data = `${userId}:${amount}:${purpose}:${new Date().toDateString()}`;
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Проверка дублирования транзакции
 */
async function checkDuplicateTransaction(idempotencyKey) {
  const existingTx = await db.collection('payments')
    .where('idempotencyKey', '==', idempotencyKey)
    .where('status', 'in', ['pending', 'completed'])
    .limit(1)
    .get();
  
  return !existingTx.empty ? existingTx.docs[0] : null;
}

/**
 * Получение задолженности пользователя
 */
async function getUserDebt(userId, apartmentId) {
  // В реальном приложении это должно браться из системы учета
  // Сейчас возвращаем тестовые данные
  return {
    currentDebt: 850000,
    overdueAmount: 0,
    services: [
      { name: 'Коммунальные услуги', amount: 650000 },
      { name: 'Интернет', amount: 100000 },
      { name: 'Охрана', amount: 100000 },
    ],
    dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // +7 дней
  };
}

/**
 * Валидация суммы платежа
 */
function validatePaymentAmount(amount, minAmount = 1000, maxAmount = 10000000) {
  if (!amount || typeof amount !== 'number') {
    throw new Error('Неверная сумма платежа');
  }
  
  if (amount < minAmount) {
    throw new Error(`Минимальная сумма платежа: ${minAmount} сум`);
  }
  
  if (amount > maxAmount) {
    throw new Error(`Максимальная сумма платежа: ${maxAmount} сум`);
  }
  
  return true;
}

// ===== CLOUD FUNCTIONS =====

/**
 * Создание платежа
 */
exports.createPayment = functions.https.onCall(async (data, context) => {
  // Проверка аутентификации
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }
  
  const { amount, description, apartmentId } = data;
  const userId = context.auth.uid;
  
  try {
    // Валидация
    validatePaymentAmount(amount);
    
    if (!apartmentId) {
      throw new functions.https.HttpsError('invalid-argument', 'apartmentId обязателен');
    }
    
    // Проверка прав на квартиру
    const apartment = await db.collection('apartments').doc(apartmentId).get();
    if (!apartment.exists) {
      throw new functions.https.HttpsError('not-found', 'Квартира не найдена');
    }
    
    const apartmentData = apartment.data();
    if (apartmentData.ownerId !== userId && 
        (!apartmentData.familyMemberIds || !apartmentData.familyMemberIds.includes(userId))) {
      throw new functions.https.HttpsError('permission-denied', 'Нет доступа к этой квартире');
    }
    
    // Получаем профиль пользователя
    const userProfile = await db.collection('userProfiles').doc(userId).get();
    if (!userProfile.exists) {
      throw new functions.https.HttpsError('not-found', 'Профиль пользователя не найден');
    }
    
    const userData = userProfile.data();
    
    // Генерация идемпотентного ключа
    const idempotencyKey = generateIdempotencyKey(userId, amount, description || 'utility');
    
    // Проверка дубликата
    const existingTx = await checkDuplicateTransaction(idempotencyKey);
    if (existingTx) {
      console.log(`Duplicate payment attempt: ${idempotencyKey}`);
      return {
        success: true,
        paymentId: existingTx.id,
        checkoutUrl: existingTx.data().checkoutUrl,
        message: 'Платеж уже создан',
      };
    }
    
    // Создание записи платежа
    const paymentId = `PAY_${Date.now()}_${crypto.randomBytes(4).toString('hex')}`;
    
    const paymentData = {
      paymentId,
      userId,
      apartmentId,
      apartmentNumber: apartmentData.apartmentNumber,
      blockId: apartmentData.blockId,
      amount: amount,
      description: description || `Оплата коммунальных услуг за квартиру ${apartmentData.apartmentNumber}`,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      idempotencyKey,
      userName: userData.fullName,
      userPhone: userData.phone,
      merchantId: PAYME_CONFIG.merchantId,
    };
    
    // Создание URL для оплаты в Payme
    const paymeParams = {
      m: PAYME_CONFIG.merchantId,
      ac: {
        payment_id: paymentId,
        apartment_id: apartmentId,
      },
      a: amount * 100, // Payme принимает сумму в тийинах
      l: 'ru',
      c: `${PAYME_CONFIG.baseUrl}/pay`,
    };
    
    // Кодирование параметров
    const encodedParams = Buffer.from(JSON.stringify(paymeParams)).toString('base64');
    const checkoutUrl = `${PAYME_CONFIG.baseUrl}/${encodedParams}`;
    
    paymentData.checkoutUrl = checkoutUrl;
    paymentData.paymeParams = paymeParams;
    
    // Сохранение в БД
    await db.collection('payments').doc(paymentId).set(paymentData);
    
    console.log(`Payment created: ${paymentId} for user ${userId}, amount: ${amount}`);
    
    // Создание уведомления
    await db.collection('notifications').add({
      userId,
      title: 'Платеж создан',
      message: `Создан платеж на сумму ${amount.toLocaleString('ru-RU')} сум`,
      type: 'payment',
      relatedPaymentId: paymentId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
    
    return {
      success: true,
      paymentId,
      checkoutUrl,
      message: 'Платеж успешно создан',
    };
    
  } catch (error) {
    console.error('Error creating payment:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      'Ошибка создания платежа',
      error.message
    );
  }
});

/**
 * Webhook для обработки callback от Payme
 */
exports.paymeWebhook = functions.https.onRequest(async (req, res) => {
  // Проверка метода
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  try {
    // Проверка авторизации (Basic Auth)
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Basic ')) {
      return res.status(401).json({
        error: {
          code: -32504,
          message: 'Unauthorized',
        },
      });
    }
    
    // Проверка логина:пароля
    const base64Credentials = authHeader.split(' ')[1];
    const credentials = Buffer.from(base64Credentials, 'base64').toString('ascii');
    const [login, password] = credentials.split(':');
    
    if (login !== 'Paycom' || password !== PAYME_CONFIG.key) {
      return res.status(401).json({
        error: {
          code: -32504,
          message: 'Unauthorized',
        },
      });
    }
    
    const { method, params, id } = req.body;
    
    console.log(`Payme webhook: ${method}`, params);
    
    let response;
    
    switch (method) {
      case 'CheckPerformTransaction':
        response = await handleCheckPerformTransaction(params);
        break;
        
      case 'CreateTransaction':
        response = await handleCreateTransaction(params);
        break;
        
      case 'PerformTransaction':
        response = await handlePerformTransaction(params);
        break;
        
      case 'CancelTransaction':
        response = await handleCancelTransaction(params);
        break;
        
      case 'CheckTransaction':
        response = await handleCheckTransaction(params);
        break;
        
      case 'GetStatement':
        response = await handleGetStatement(params);
        break;
        
      default:
        response = {
          error: {
            code: -32601,
            message: 'Method not found',
          },
        };
    }
    
    res.json({
      jsonrpc: '2.0',
      id: id,
      ...response,
    });
    
  } catch (error) {
    console.error('Payme webhook error:', error);
    res.status(500).json({
      error: {
        code: -32400,
        message: 'Internal server error',
      },
    });
  }
});

// ===== PAYME API HANDLERS =====

async function handleCheckPerformTransaction(params) {
  try {
    const { account } = params;
    const paymentId = account.payment_id;
    
    // Проверка существования платежа
    const payment = await db.collection('payments').doc(paymentId).get();
    
    if (!payment.exists) {
      return {
        error: {
          code: -31050,
          message: 'Payment not found',
        },
      };
    }
    
    const paymentData = payment.data();
    
    // Проверка статуса
    if (paymentData.status === 'completed' || paymentData.status === 'cancelled') {
      return {
        error: {
          code: -31051,
          message: 'Payment already processed',
        },
      };
    }
    
    return {
      result: {
        allow: true,
        detail: {
          items: [
            {
              title: 'Квартира',
              value: `${paymentData.blockId}-${paymentData.apartmentNumber}`,
            },
            {
              title: 'Плательщик',
              value: paymentData.userName,
            },
          ],
        },
      },
    };
  } catch (error) {
    console.error('CheckPerformTransaction error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

async function handleCreateTransaction(params) {
  try {
    const { account, amount, time, id } = params;
    const paymentId = account.payment_id;
    
    const paymentRef = db.collection('payments').doc(paymentId);
    const payment = await paymentRef.get();
    
    if (!payment.exists) {
      return {
        error: {
          code: -31050,
          message: 'Payment not found',
        },
      };
    }
    
    const paymentData = payment.data();
    
    // Проверка суммы (amount в тийинах)
    if (amount !== paymentData.amount * 100) {
      return {
        error: {
          code: -31001,
          message: 'Invalid amount',
        },
      };
    }
    
    // Создание транзакции
    const transaction = {
      paymeId: id,
      paymentId: paymentId,
      amount: amount / 100, // Конвертируем обратно в сумы
      state: 1, // Created
      createTime: time,
      performTime: 0,
      cancelTime: 0,
      reason: null,
    };
    
    await db.collection('paymeTransactions').doc(id).set(transaction);
    
    // Обновляем статус платежа
    await paymentRef.update({
      status: 'processing',
      paymeTransactionId: id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    return {
      result: {
        create_time: time,
        transaction: id,
        state: 1,
      },
    };
  } catch (error) {
    console.error('CreateTransaction error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

async function handlePerformTransaction(params) {
  try {
    const { id } = params;
    
    const txRef = db.collection('paymeTransactions').doc(id);
    const tx = await txRef.get();
    
    if (!tx.exists) {
      return {
        error: {
          code: -31003,
          message: 'Transaction not found',
        },
      };
    }
    
    const txData = tx.data();
    
    if (txData.state !== 1) {
      return {
        error: {
          code: -31008,
          message: 'Invalid transaction state',
        },
      };
    }
    
    const performTime = Date.now();
    
    // Обновляем транзакцию
    await txRef.update({
      state: 2, // Completed
      performTime: performTime,
    });
    
    // Обновляем платеж
    await db.collection('payments').doc(txData.paymentId).update({
      status: 'completed',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Создаем уведомление
    const payment = await db.collection('payments').doc(txData.paymentId).get();
    const paymentData = payment.data();
    
    await db.collection('notifications').add({
      userId: paymentData.userId,
      title: 'Платеж успешно проведен',
      message: `Оплата на сумму ${txData.amount.toLocaleString('ru-RU')} сум успешно проведена`,
      type: 'payment_success',
      relatedPaymentId: txData.paymentId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
    
    return {
      result: {
        transaction: id,
        perform_time: performTime,
        state: 2,
      },
    };
  } catch (error) {
    console.error('PerformTransaction error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

async function handleCancelTransaction(params) {
  try {
    const { id, reason } = params;
    
    const txRef = db.collection('paymeTransactions').doc(id);
    const tx = await txRef.get();
    
    if (!tx.exists) {
      return {
        error: {
          code: -31003,
          message: 'Transaction not found',
        },
      };
    }
    
    const txData = tx.data();
    const cancelTime = Date.now();
    
    // Обновляем транзакцию
    await txRef.update({
      state: -1, // Cancelled
      cancelTime: cancelTime,
      reason: reason,
    });
    
    // Обновляем платеж
    await db.collection('payments').doc(txData.paymentId).update({
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelReason: reason,
    });
    
    return {
      result: {
        transaction: id,
        cancel_time: cancelTime,
        state: -1,
      },
    };
  } catch (error) {
    console.error('CancelTransaction error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

async function handleCheckTransaction(params) {
  try {
    const { id } = params;
    
    const tx = await db.collection('paymeTransactions').doc(id).get();
    
    if (!tx.exists) {
      return {
        error: {
          code: -31003,
          message: 'Transaction not found',
        },
      };
    }
    
    const txData = tx.data();
    
    return {
      result: {
        create_time: txData.createTime,
        perform_time: txData.performTime,
        cancel_time: txData.cancelTime,
        transaction: id,
        state: txData.state,
        reason: txData.reason,
      },
    };
  } catch (error) {
    console.error('CheckTransaction error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

async function handleGetStatement(params) {
  // Для отчетности - возвращаем список транзакций за период
  try {
    const { from, to } = params;
    
    const transactions = await db.collection('paymeTransactions')
      .where('createTime', '>=', from)
      .where('createTime', '<=', to)
      .orderBy('createTime', 'desc')
      .get();
    
    const result = await Promise.all(transactions.docs.map(async (doc) => {
      const tx = doc.data();
      const payment = await db.collection('payments').doc(tx.paymentId).get();
      const paymentData = payment.data();
      
      return {
        id: doc.id,
        time: tx.createTime,
        amount: tx.amount * 100,
        account: {
          payment_id: tx.paymentId,
          apartment_id: paymentData.apartmentId,
        },
        create_time: tx.createTime,
        perform_time: tx.performTime,
        cancel_time: tx.cancelTime,
        transaction: doc.id,
        state: tx.state,
        reason: tx.reason,
      };
    }));
    
    return {
      result: {
        transactions: result,
      },
    };
  } catch (error) {
    console.error('GetStatement error:', error);
    return {
      error: {
        code: -32400,
        message: 'Internal error',
      },
    };
  }
}

/**
 * Получение истории платежей пользователя
 */
exports.getPaymentHistory = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Требуется аутентификация');
  }
  
  const { apartmentId, limit = 20 } = data;
  const userId = context.auth.uid;
  
  try {
    let query = db.collection('payments')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(limit);
    
    if (apartmentId) {
      query = query.where('apartmentId', '==', apartmentId);
    }
    
    const payments = await query.get();
    
    const history = payments.docs.map(doc => {
      const data = doc.data();
      return {
        paymentId: doc.id,
        amount: data.amount,
        description: data.description,
        status: data.status,
        createdAt: data.createdAt?.toDate()?.toISOString(),
        completedAt: data.completedAt?.toDate()?.toISOString(),
        apartmentNumber: data.apartmentNumber,
        blockId: data.blockId,
      };
    });
    
    return {
      success: true,
      payments: history,
    };
  } catch (error) {
    console.error('Error getting payment history:', error);
    throw new functions.https.HttpsError('internal', 'Ошибка получения истории платежей');
  }
});
