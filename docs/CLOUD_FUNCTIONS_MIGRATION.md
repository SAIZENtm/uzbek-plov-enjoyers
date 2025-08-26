# Cloud Functions Migration Guide

## Изменения в безопасности

### Что изменилось:
1. ❌ `onRequest` → ✅ `onCall` (требует аутентификации)
2. ❌ CORS * → ✅ Только из приложения
3. ❌ Без проверки прав → ✅ Проверка ролей и доступа

## Обновление клиентского кода

### 1. Вызов функций из Flutter

**Старый код (HTTP Request):**
```dart
// ❌ Небезопасно
final response = await http.post(
  Uri.parse('https://us-central1-project.cloudfunctions.net/createNotification'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'userId': userId,
    'title': title,
    'message': message,
  }),
);
```

**Новый код (Callable Function):**
```dart
// ✅ Безопасно
import 'package:cloud_functions/cloud_functions.dart';

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Создание уведомления (только админ)
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? relatedRequestId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createNotification');
      
      final result = await callable.call({
        'userId': userId,
        'title': title,
        'message': message,
        'relatedRequestId': relatedRequestId,
      });
      
      if (result.data['success'] == true) {
        print('Уведомление создано: ${result.data['notificationId']}');
      }
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'unauthenticated':
          throw Exception('Требуется вход в систему');
        case 'permission-denied':
          throw Exception('У вас нет прав для этого действия');
        case 'invalid-argument':
          throw Exception('Неверные данные: ${e.message}');
        default:
          throw Exception('Ошибка: ${e.message}');
      }
    }
  }
  
  // Получение статистики (только админ)
  Future<Map<String, dynamic>> getNotificationStats() async {
    try {
      final callable = _functions.httpsCallable('getNotificationStats');
      final result = await callable.call();
      
      return result.data as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      rethrow;
    }
  }
  
  // Поиск пользователей (с проверкой доступа)
  Future<List<dynamic>> searchUsers(String userId) async {
    try {
      final callable = _functions.httpsCallable('searchUsers');
      final result = await callable.call({'userId': userId});
      
      return result.data['results'] as List<dynamic>;
    } on FirebaseFunctionsException catch (e) {
      _handleFunctionError(e);
      rethrow;
    }
  }
  
  void _handleFunctionError(FirebaseFunctionsException e) {
    print('Cloud Function error: ${e.code} - ${e.message}');
    
    switch (e.code) {
      case 'unauthenticated':
        // Перенаправить на экран входа
        break;
      case 'permission-denied':
        // Показать сообщение об отсутствии прав
        break;
      case 'failed-precondition':
        // Функция недоступна (например, тестовая в production)
        break;
    }
  }
}
```

### 2. Обновление сервиса уведомлений

```dart
class NotificationManagementService {
  final CloudFunctionsService _functionsService = CloudFunctionsService();
  final LoggingService _logging = GetIt.instance<LoggingService>();
  
  // Создание уведомления (для админ-панели)
  Future<bool> createAdminNotification({
    required String userId,
    required String title,
    required String message,
    String? requestId,
  }) async {
    try {
      await _functionsService.createNotification(
        userId: userId,
        title: title,
        message: message,
        relatedRequestId: requestId,
      );
      
      _logging.info('Admin notification created for user: $userId');
      return true;
    } catch (e) {
      _logging.error('Failed to create admin notification', e);
      return false;
    }
  }
  
  // Массовая рассылка (для админов)
  Future<void> sendBulkNotification({
    required List<String> userIds,
    required String title,
    required String message,
  }) async {
    // Отправляем по одному, чтобы отслеживать ошибки
    int successCount = 0;
    int failureCount = 0;
    
    for (final userId in userIds) {
      try {
        await createAdminNotification(
          userId: userId,
          title: title,
          message: message,
        );
        successCount++;
      } catch (e) {
        failureCount++;
        _logging.error('Failed to notify user $userId', e);
      }
      
      // Небольшая задержка между запросами
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    _logging.info('Bulk notification completed: $successCount success, $failureCount failures');
  }
}
```

### 3. Проверка ролей в UI

```dart
class AdminPanelScreen extends StatefulWidget {
  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final CloudFunctionsService _functions = CloudFunctionsService();
  bool _isAdmin = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }
  
  Future<void> _checkAdminAccess() async {
    try {
      // Пробуем вызвать админскую функцию
      await _functions.getNotificationStats();
      
      setState(() {
        _isAdmin = true;
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') {
        // Не админ
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
        
        // Перенаправляем обратно
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('У вас нет прав администратора'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop();
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (!_isAdmin) {
      return const Center(
        child: Text('Доступ запрещен'),
      );
    }
    
    return AdminPanelContent();
  }
}
```

## Конфигурация для разных окружений

### 1. Настройка Firebase Functions для разных проектов

```dart
// lib/config/firebase_config.dart
class FirebaseConfig {
  static void configureForEnvironment(String environment) {
    switch (environment) {
      case 'development':
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
        break;
      case 'staging':
        // Используем staging проект
        break;
      case 'production':
        // Production настройки по умолчанию
        break;
    }
  }
}

// В main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Настройка окружения
  const environment = String.fromEnvironment('ENV', defaultValue: 'development');
  FirebaseConfig.configureForEnvironment(environment);
  
  runApp(MyApp());
}
```

### 2. Запуск с разными окружениями

```bash
# Development с эмулятором
flutter run --dart-define=ENV=development

# Staging
flutter run --dart-define=ENV=staging

# Production
flutter run --dart-define=ENV=production --release
```

## Тестирование

### 1. Unit тесты для Cloud Functions

```javascript
// functions/test/index.test.js
const test = require('firebase-functions-test')();
const admin = require('firebase-admin');

describe('Cloud Functions Security', () => {
  let myFunctions;
  
  before(() => {
    myFunctions = require('../index-secure.js');
  });
  
  describe('createNotification', () => {
    it('should reject unauthenticated requests', async () => {
      const wrapped = test.wrap(myFunctions.createNotification);
      
      await expect(wrapped({
        userId: 'test',
        title: 'Test',
        message: 'Test'
      }, {
        auth: null // Не аутентифицирован
      })).to.be.rejectedWith('unauthenticated');
    });
    
    it('should reject non-admin requests', async () => {
      const wrapped = test.wrap(myFunctions.createNotification);
      
      // Mock isAdmin to return false
      // ... setup mocks
      
      await expect(wrapped({
        userId: 'test',
        title: 'Test',
        message: 'Test'
      }, {
        auth: { uid: 'regular-user' }
      })).to.be.rejectedWith('permission-denied');
    });
  });
});
```

### 2. Integration тесты в Flutter

```dart
// test/cloud_functions_test.dart
import 'package:test/test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

void main() {
  setUpAll(() async {
    await Firebase.initializeApp();
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  });
  
  group('Cloud Functions Security', () {
    test('Unauthenticated user cannot create notification', () async {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createNotification');
      
      expect(
        () => callable.call({
          'userId': 'test',
          'title': 'Test',
          'message': 'Test',
        }),
        throwsA(isA<FirebaseFunctionsException>()
          .having((e) => e.code, 'code', 'unauthenticated')),
      );
    });
  });
}
```

## Checklist миграции

- [ ] Заменить все HTTP вызовы на httpsCallable
- [ ] Добавить обработку ошибок аутентификации
- [ ] Обновить UI для проверки прав
- [ ] Протестировать с эмулятором
- [ ] Обновить документацию API
- [ ] Настроить мониторинг ошибок
- [ ] Деплой новых функций
