# Очистка маршрутов - оставлена только Stepper форма

## 🎯 Цель
Убрать дублирование маршрутов для подачи заявки и оставить только новую многошаговую форму (Stepper).

## 🔧 Внесенные изменения

### 1. Обновлен роутер (`lib/routes/app_router.dart`)

**Было:**
```dart
GoRoute(
  path: 'new-request',
  name: 'new_service_request',
  builder: (context, state) {
    final serviceType = state.uri.queryParameters['type'];
    return ServiceRequestScreen(initialRequestType: serviceType); // Старая форма
  },
),
GoRoute(
  path: 'new-request-stepper',
  name: 'new_service_request_stepper',
  builder: (context, state) {
    final serviceType = state.uri.queryParameters['type'];
    return ServiceRequestStepperScreen(initialRequestType: serviceType); // Новая форма
  },
),
```

**Стало:**
```dart
GoRoute(
  path: 'new-request',
  name: 'new_service_request',
  builder: (context, state) {
    final serviceType = state.uri.queryParameters['type'];
    return ServiceRequestStepperScreen(initialRequestType: serviceType); // Только новая форма
  },
),
```

### 2. Обновлен экран услуг (`lib/presentation/services_screen/services_screen.dart`)

**Было:**
```dart
onTap: () => context.go('/services/new-request-stepper'),
```

**Стало:**
```dart
onTap: () => context.go('/services/new-request'),
```

### 3. Удален неиспользуемый импорт

**Удалено:**
```dart
import '../presentation/service_request_screen/service_request_screen.dart';
```

**Оставлено:**
```dart
import '../presentation/service_request_screen/service_request_stepper_screen.dart';
```

## ✅ Результат

### Преимущества:
1. **Упрощение навигации** - один маршрут вместо двух
2. **Единообразие** - все пользователи используют одну и ту же улучшенную форму
3. **Очистка кода** - убраны дублирующиеся маршруты
4. **Поддержка** - проще поддерживать один компонент

### Поведение:
- ✅ Кнопка "Подать заявку" теперь ведет на многошаговую форму
- ✅ Старая форма больше не доступна
- ✅ Все существующие ссылки `/services/new-request` работают корректно
- ✅ Параметры `?type=plumbing` по-прежнему поддерживаются

### Тестирование:
```bash
flutter analyze  # ✅ Без ошибок
flutter run      # ✅ Приложение запускается
```

### Проверка навигации:
1. Откройте экран "Сервисы"
2. Нажмите "Подать заявку"
3. Должна открыться многошаговая форма (Stepper)
4. Старая форма больше не доступна

## 🎉 Готово!
Теперь у вас есть только одна, улучшенная многошаговая форма для подачи заявок! 