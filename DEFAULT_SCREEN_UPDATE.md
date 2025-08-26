# Установка главного экрана как дефолтного

## 🎯 Задача
Сделать главный экран (Dashboard) дефолтным при запуске приложения для аутентифицированных пользователей.

## ✅ Изменения

### 1. Обновлен initialLocation в роутере

**До:**
```dart
static final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  debugLogDiagnostics: true,
```

**После:**
```dart
static final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  debugLogDiagnostics: true,
```

### 2. Улучшена логика редиректа

**Добавлено дополнительное правило:**
```dart
// If authenticated and trying to go to splash, redirect to dashboard
if (isAuthenticated && state.uri.path == '/splash') {
  return '/dashboard';
}
```

**Полная логика редиректа:**
```dart
redirect: (context, state) {
  final authService = GetIt.instance<AuthService>();
  final isAuthenticated = authService.isAuthenticated;
  final isOnAuthFlow = ['/splash', '/auth', '/apartments', '/family-request', '/phone-registration', '/invite'].contains(state.uri.path);
  
  // If not authenticated and not on auth flow, go to splash
  if (!isAuthenticated && !isOnAuthFlow) {
    return '/splash';
  }
  
  // If authenticated and on auth flow (except apartments), go to dashboard
  if (isAuthenticated && isOnAuthFlow && state.uri.path != '/apartments') {
    return '/dashboard';
  }
  
  // If authenticated and trying to go to splash, redirect to dashboard
  if (isAuthenticated && state.uri.path == '/splash') {
    return '/dashboard';
  }
  
  return null; // No redirect needed
},
```

## 🚀 Результат

### Новое поведение приложения:

#### Для аутентифицированных пользователей:
- ✅ **Запуск приложения** → Dashboard (главный экран)
- ✅ **Переход на /splash** → Редирект на Dashboard
- ✅ **Переход на /auth** → Редирект на Dashboard
- ✅ **Прямая навигация** → Dashboard остается доступным

#### Для неаутентифицированных пользователей:
- ✅ **Запуск приложения** → Splash Screen (процесс авторизации)
- ✅ **Попытка доступа к защищенным экранам** → Редирект на Splash
- ✅ **Процесс авторизации** → Auth flow работает как прежде

### Логика работы:

1. **Первый запуск (не авторизован):**
   - Попытка перейти на `/dashboard`
   - Редирект на `/splash`
   - Процесс авторизации
   - После успешной авторизации → Dashboard

2. **Повторный запуск (авторизован):**
   - Переход на `/dashboard`
   - Пользователь сразу видит главный экран

3. **Прямые переходы:**
   - Авторизованный пользователь может напрямую переходить на любые экраны
   - Неавторизованный пользователь перенаправляется на авторизацию

### Преимущества:
- ✅ **Быстрый доступ** - авторизованные пользователи сразу видят главный экран
- ✅ **Интуитивность** - Dashboard как центральный хаб приложения
- ✅ **Безопасность** - неавторизованные пользователи по-прежнему проходят авторизацию
- ✅ **Совместимость** - все существующие маршруты работают как прежде

## 🧪 Тестирование

### Сценарии для проверки:

1. **Авторизованный пользователь:**
   ```
   Запуск приложения → Dashboard ✅
   Переход на /splash → Dashboard ✅
   Переход на /auth → Dashboard ✅
   Прямая навигация → Работает ✅
   ```

2. **Неавторизованный пользователь:**
   ```
   Запуск приложения → Splash → Auth flow ✅
   Попытка доступа к Dashboard → Splash ✅
   Процесс авторизации → Dashboard ✅
   ```

3. **Смешанные сценарии:**
   ```
   Выход из аккаунта → Splash ✅
   Повторный вход → Dashboard ✅
   Глубокие ссылки → Работают с редиректом ✅
   ```

### Проверка кода:
```bash
flutter analyze  # ✅ Без ошибок
flutter run      # ✅ Приложение запускается
```

## 🎉 Готово!
Теперь главный экран (Dashboard) является дефолтным для всех авторизованных пользователей! Приложение открывается сразу на главном экране, что улучшает пользовательский опыт. 