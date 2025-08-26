# Storage Migration Guide

## Изменения в структуре путей Storage

### Старая структура (небезопасная):
- ❌ Публичное чтение всех файлов
- ❌ Запись для любого аутентифицированного пользователя
- ❌ Нет проверки владения

### Новая структура (безопасная):
- ✅ Файлы привязаны к userId
- ✅ Проверка владения перед доступом
- ✅ Ограничение типов и размеров

## Обновление кода в приложении

### 1. Service Request Images

**Старый код:**
```dart
// Загрузка изображения
final ref = FirebaseStorage.instance
    .ref()
    .child('service_requests/${DateTime.now()}.jpg');
```

**Новый код:**
```dart
// Загрузка изображения с привязкой к requestId
final ref = FirebaseStorage.instance
    .ref()
    .child('service_requests/$requestId/images/${Uuid().v4()}.jpg');
```

### 2. Profile Images

**Старый код:**
```dart
final ref = FirebaseStorage.instance
    .ref()
    .child('users/profile_${DateTime.now()}.jpg');
```

**Новый код:**
```dart
final userId = FirebaseAuth.instance.currentUser!.uid;
final ref = FirebaseStorage.instance
    .ref()
    .child('users/$userId/profile/${Uuid().v4()}.jpg');
```

### 3. Utility Reading Images

**Новый путь:**
```dart
final ref = FirebaseStorage.instance
    .ref()
    .child('utility_readings/$readingId/images/${Uuid().v4()}.jpg');
```

## Миграция существующих файлов

### Скрипт для миграции (запускать через Cloud Function):

```javascript
const admin = require('firebase-admin');
const storage = admin.storage();

exports.migrateStorageFiles = functions.https.onCall(async (data, context) => {
  // Проверка админа
  if (!context.auth || !isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }
  
  const bucket = storage.bucket();
  const [files] = await bucket.getFiles();
  
  for (const file of files) {
    const filePath = file.name;
    
    // Миграция service_requests
    if (filePath.startsWith('service_requests/') && !filePath.includes('/images/')) {
      // Старый формат: service_requests/timestamp.jpg
      // Новый формат: service_requests/{requestId}/images/{imageId}.jpg
      
      // Найти связанную заявку по метаданным или времени
      const metadata = file.metadata;
      const requestId = metadata.customMetadata?.requestId || 'orphaned';
      
      const newPath = `service_requests/${requestId}/images/${path.basename(filePath)}`;
      
      // Копировать файл
      await file.copy(newPath);
      
      // Удалить старый файл после проверки
      // await file.delete();
    }
  }
  
  return { success: true, message: 'Migration completed' };
});
```

## Обновление сервисов в приложении

### PhotoAttachmentService

```dart
class PhotoAttachmentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Future<String> uploadServiceRequestImage({
    required String requestId,
    required File imageFile,
  }) async {
    // Проверка аутентификации
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');
    
    // Генерация уникального ID для изображения
    final imageId = const Uuid().v4();
    final extension = path.extension(imageFile.path);
    
    // Создание ссылки с правильной структурой
    final ref = _storage.ref().child(
      'service_requests/$requestId/images/$imageId$extension'
    );
    
    // Добавление метаданных
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': user.uid,
        'uploadedAt': DateTime.now().toIso8601String(),
        'requestId': requestId,
      },
    );
    
    // Загрузка
    final uploadTask = ref.putFile(imageFile, metadata);
    final snapshot = await uploadTask;
    
    // Получение URL
    final downloadUrl = await snapshot.ref.getDownloadURL();
    
    return downloadUrl;
  }
  
  Future<List<String>> getServiceRequestImages(String requestId) async {
    // Проверка прав доступа будет на уровне Storage Rules
    final ref = _storage.ref().child('service_requests/$requestId/images');
    
    try {
      final result = await ref.listAll();
      final urls = await Future.wait(
        result.items.map((item) => item.getDownloadURL()),
      );
      return urls;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('У вас нет доступа к этим изображениям');
      }
      rethrow;
    }
  }
}
```

## Проверка безопасности

1. **Тестирование доступа:**
   ```dart
   // Попытка доступа к чужим файлам должна быть запрещена
   try {
     await FirebaseStorage.instance
         .ref('users/OTHER_USER_ID/profile/image.jpg')
         .getDownloadURL();
     // Это должно выбросить permission-denied
   } catch (e) {
     print('Доступ правильно запрещен: $e');
   }
   ```

2. **Валидация типов файлов:**
   ```dart
   // Загрузка не-изображения должна быть запрещена
   final textFile = File('document.txt');
   try {
     await ref.putFile(textFile); // Должно быть отклонено
   } catch (e) {
     print('Неверный тип файла правильно отклонен');
   }
   ```

## Checklist миграции

- [ ] Обновить все пути загрузки в приложении
- [ ] Добавить userId в структуру путей
- [ ] Обновить сервисы для работы с новой структурой
- [ ] Протестировать права доступа
- [ ] Мигрировать существующие файлы
- [ ] Обновить документацию
- [ ] Деплой новых правил только после миграции кода
