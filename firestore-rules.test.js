// Тесты для Firestore Security Rules
// Запуск: npm test firestore-rules.test.js

const { assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const firebase = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'newport-test';
const RULES_PATH = 'firestore-secure.rules';

// Тестовые данные
const testData = {
  users: {
    owner: { uid: 'owner123', role: 'resident' },
    family: { uid: 'family123', role: 'familyMember' },
    stranger: { uid: 'stranger123', role: 'resident' },
    admin: { uid: 'admin123', role: 'admin' }
  },
  apartment: {
    id: 'apt123',
    ownerId: 'owner123',
    familyMemberIds: ['family123'],
    blockId: 'D',
    apartmentNumber: '101'
  }
};

describe('Firestore Security Rules', () => {
  let testEnv;
  
  beforeAll(async () => {
    testEnv = await firebase.initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(RULES_PATH, 'utf8'),
        host: 'localhost',
        port: 8080
      }
    });
  });
  
  beforeEach(async () => {
    await testEnv.clearFirestore();
    
    // Настройка начальных данных
    const adminContext = testEnv.authenticatedContext('admin123');
    const adminDb = adminContext.firestore();
    
    // Создаем админа
    await adminDb.collection('admins').doc('admin123').set({ role: 'admin' });
    
    // Создаем профили пользователей
    await adminDb.collection('userProfiles').doc('owner123').set({
      fullName: 'Владелец Квартиры',
      phone: '+998901234567',
      role: 'resident',
      blockId: 'D',
      apartmentNumber: '101',
      apartmentIds: ['apt123']
    });
    
    await adminDb.collection('userProfiles').doc('family123').set({
      fullName: 'Член Семьи',
      phone: '+998907654321',
      role: 'familyMember',
      blockId: 'D',
      apartmentNumber: '101',
      apartmentIds: ['apt123']
    });
    
    // Создаем квартиру
    await adminDb.collection('apartments').doc('apt123').set(testData.apartment);
  });
  
  afterAll(async () => {
    await testEnv.cleanup();
  });
  
  describe('Профили пользователей (userProfiles)', () => {
    test('Пользователь может читать только свой профиль', async () => {
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      const strangerDb = testEnv.authenticatedContext('stranger123').firestore();
      
      // Владелец может читать свой профиль
      await assertSucceeds(
        ownerDb.collection('userProfiles').doc('owner123').get()
      );
      
      // Чужой не может читать профиль владельца
      await assertFails(
        strangerDb.collection('userProfiles').doc('owner123').get()
      );
    });
    
    test('Пользователь может обновлять только разрешенные поля', async () => {
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      
      // Разрешенные поля
      await assertSucceeds(
        ownerDb.collection('userProfiles').doc('owner123').update({
          fullName: 'Новое Имя',
          phone: '+998901111111'
        })
      );
      
      // Запрещенные поля
      await assertFails(
        ownerDb.collection('userProfiles').doc('owner123').update({
          role: 'admin' // Нельзя менять роль
        })
      );
    });
  });
  
  describe('Квартиры (apartments)', () => {
    test('Только владелец и члены семьи могут читать квартиру', async () => {
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      const familyDb = testEnv.authenticatedContext('family123').firestore();
      const strangerDb = testEnv.authenticatedContext('stranger123').firestore();
      
      // Владелец может читать
      await assertSucceeds(
        ownerDb.collection('apartments').doc('apt123').get()
      );
      
      // Член семьи может читать
      await assertSucceeds(
        familyDb.collection('apartments').doc('apt123').get()
      );
      
      // Посторонний не может читать
      await assertFails(
        strangerDb.collection('apartments').doc('apt123').get()
      );
    });
    
    test('Члены семьи могут обновлять только FCM токены', async () => {
      const familyDb = testEnv.authenticatedContext('family123').firestore();
      
      // Может обновить FCM токены
      await assertSucceeds(
        familyDb.collection('apartments').doc('apt123').update({
          fcmTokens: ['token123']
        })
      );
      
      // Не может обновить другие поля
      await assertFails(
        familyDb.collection('apartments').doc('apt123').update({
          ownerId: 'family123' // Попытка стать владельцем
        })
      );
    });
  });
  
  describe('Сервисные заявки (serviceRequests)', () => {
    test('Пользователь видит только свои заявки', async () => {
      const adminDb = testEnv.authenticatedContext('admin123').firestore();
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      const strangerDb = testEnv.authenticatedContext('stranger123').firestore();
      
      // Создаем заявку от имени владельца
      await adminDb.collection('serviceRequests').doc('req123').set({
        userId: 'owner123',
        passportNumber: 'AA1234567',
        apartmentNumber: '101',
        blockId: 'D',
        requestType: 'cleaning',
        description: 'Уборка',
        status: 'pending'
      });
      
      // Владелец может читать свою заявку
      await assertSucceeds(
        ownerDb.collection('serviceRequests').doc('req123').get()
      );
      
      // Посторонний не может читать чужую заявку
      await assertFails(
        strangerDb.collection('serviceRequests').doc('req123').get()
      );
    });
    
    test('Пользователь может создавать заявки только от своего имени', async () => {
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      
      // Правильная заявка
      await assertSucceeds(
        ownerDb.collection('serviceRequests').add({
          userId: 'owner123',
          apartmentNumber: '101',
          blockId: 'D',
          requestType: 'repair',
          description: 'Ремонт',
          status: 'pending'
        })
      );
      
      // Заявка от чужого имени
      await assertFails(
        ownerDb.collection('serviceRequests').add({
          userId: 'stranger123', // Чужой ID
          apartmentNumber: '101',
          blockId: 'D',
          requestType: 'repair',
          description: 'Ремонт',
          status: 'pending'
        })
      );
    });
  });
  
  describe('FCM токены (fcm_tokens)', () => {
    test('Пользователь может управлять только своими токенами', async () => {
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      const strangerDb = testEnv.authenticatedContext('stranger123').firestore();
      
      // Может создать свой документ
      await assertSucceeds(
        ownerDb.collection('fcm_tokens').doc('owner123').set({
          tokens: ['token1', 'token2']
        })
      );
      
      // Не может создать чужой документ
      await assertFails(
        ownerDb.collection('fcm_tokens').doc('stranger123').set({
          tokens: ['token3']
        })
      );
      
      // Не может читать чужой документ
      await assertFails(
        strangerDb.collection('fcm_tokens').doc('owner123').get()
      );
    });
  });
  
  describe('Блоки и квартиры (users/apartments)', () => {
    test('Пользователь может читать только свой блок и квартиру', async () => {
      const adminDb = testEnv.authenticatedContext('admin123').firestore();
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      const strangerDb = testEnv.authenticatedContext('stranger123').firestore();
      
      // Создаем структуру блока
      await adminDb.collection('users').doc('D').set({ name: 'Block D' });
      await adminDb.collection('users').doc('D').collection('apartments').doc('101').set({
        phone: '+998901234567',
        fcmTokens: []
      });
      
      // Владелец может читать свой блок
      await assertSucceeds(
        ownerDb.collection('users').doc('D').get()
      );
      
      // Владелец может читать свою квартиру
      await assertSucceeds(
        ownerDb.collection('users').doc('D').collection('apartments').doc('101').get()
      );
      
      // Посторонний не может читать чужой блок
      await assertFails(
        strangerDb.collection('users').doc('D').get()
      );
    });
  });
  
  describe('Административные функции', () => {
    test('Только админ может читать коллекцию админов', async () => {
      const adminDb = testEnv.authenticatedContext('admin123').firestore();
      const ownerDb = testEnv.authenticatedContext('owner123').firestore();
      
      await assertSucceeds(
        adminDb.collection('admins').doc('admin123').get()
      );
      
      await assertFails(
        ownerDb.collection('admins').doc('admin123').get()
      );
    });
    
    test('Админ имеет полный доступ ко всем коллекциям', async () => {
      const adminDb = testEnv.authenticatedContext('admin123').firestore();
      
      // Может читать любые профили
      await assertSucceeds(
        adminDb.collection('userProfiles').doc('stranger123').get()
      );
      
      // Может создавать квартиры
      await assertSucceeds(
        adminDb.collection('apartments').doc('apt999').set({
          ownerId: 'owner999',
          blockId: 'E',
          apartmentNumber: '999'
        })
      );
    });
  });
});
