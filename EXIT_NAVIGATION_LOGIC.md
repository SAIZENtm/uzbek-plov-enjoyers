# Логика навигации и выхода из приложения

## 🎯 Задача
Реализовать логику навигации, где:
1. Главная страница (Dashboard) является предпоследней перед выходом из приложения
2. Перед выходом из приложения показывается предупреждение
3. Кнопка "Назад" всегда ведет к главной странице, а с главной страницы - к выходу с подтверждением

## ✅ Решение

### 1. Обновлен PremiumMainShell с логикой PopScope

**Добавлен глобальный обработчик кнопки "Назад":**
```dart
@override
Widget build(BuildContext context) {
  return PopScope(
    canPop: false,
    onPopInvoked: (didPop) async {
      if (didPop) return;
      
      final location = GoRouterState.of(context).uri.toString();
      
      // Если мы на главной странице, показываем диалог выхода
      if (location == '/dashboard') {
        final shouldExit = await _showExitDialog(context);
        if (shouldExit) {
          // Выходим из приложения
          SystemNavigator.pop();
        }
      } else {
        // Если не на главной странице, переходим на главную
        context.go('/dashboard');
      }
    },
    child: Scaffold(
      body: child,
      bottomNavigationBar: _buildBottomNavigationBar(context),
    ),
  );
}
```

### 2. Добавлен диалог подтверждения выхода

**Красивый диалог с подтверждением:**
```dart
Future<bool> _showExitDialog(BuildContext context) async {
  return await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.exit_to_app,
              color: AppTheme.newportPrimary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Выход из приложения',
              style: AppTheme.lightTheme.textTheme.titleLarge,
            ),
          ],
        ),
        content: Text(
          'Вы действительно хотите выйти из приложения?',
          style: AppTheme.lightTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.newportPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      );
    },
  ) ?? false;
}
```

### 3. Убрана конфликтующая логика из ServiceRequestStepperScreen

**Удален PopScope из формы заявки:**
- Убран `PopScope` из `service_request_stepper_screen.dart`
- Теперь форма подчиняется глобальной логике навигации
- Кнопка "Назад" в форме ведет к главной странице

## 🚀 Новая логика навигации

### Поведение кнопки "Назад":

1. **С любого экрана (кроме Dashboard):**
   - Нажатие "Назад" → Переход на Dashboard
   - Примеры:
     - Profile → **Назад** → Dashboard ✅
     - Services → **Назад** → Dashboard ✅
     - News → **Назад** → Dashboard ✅
     - Service Request → **Назад** → Dashboard ✅

2. **С главной страницы (Dashboard):**
   - Нажатие "Назад" → Диалог подтверждения выхода
   - Выбор "Выйти" → Закрытие приложения
   - Выбор "Отмена" → Остаемся на Dashboard

### Преимущества новой логики:

- ✅ **Предсказуемость** - пользователь всегда знает, что кнопка "Назад" ведет к главной
- ✅ **Безопасность** - нельзя случайно выйти из приложения
- ✅ **Центральный хаб** - Dashboard как главная точка навигации
- ✅ **UX** - интуитивное поведение для мобильных приложений

## 📱 Сценарии использования

### Сценарий 1: Навигация по разделам
```
Dashboard → Profile → Назад → Dashboard ✅
Dashboard → Services → New Request → Назад → Dashboard ✅
Dashboard → News → Article → Назад → Dashboard ✅
```

### Сценарий 2: Выход из приложения
```
Dashboard → Назад → "Выйти из приложения?" → Выйти → Закрытие приложения ✅
Dashboard → Назад → "Выйти из приложения?" → Отмена → Dashboard ✅
```

### Сценарий 3: Глубокая навигация
```
Dashboard → Services → New Request → Step 3 → Назад → Dashboard ✅
Dashboard → Profile → Edit → Назад → Dashboard ✅
```

## 🧪 Тестирование

### Проверка функциональности:

1. **Навигация к Dashboard:**
   - ✅ Перейдите на любой экран
   - ✅ Нажмите кнопку "Назад"
   - ✅ Должны попасть на Dashboard

2. **Диалог выхода:**
   - ✅ Находясь на Dashboard, нажмите "Назад"
   - ✅ Должен появиться диалог подтверждения
   - ✅ "Отмена" → остаемся на Dashboard
   - ✅ "Выйти" → приложение закрывается

3. **Формы и диалоги:**
   - ✅ Заполните форму заявки
   - ✅ Нажмите "Назад" → должны попасть на Dashboard
   - ✅ Черновик должен сохраниться

### Результаты тестирования:
```bash
flutter analyze  # ✅ Только предупреждения, нет критических ошибок
flutter run      # ✅ Приложение работает корректно
```

## 🎉 Результат

### Что достигнуто:
1. ✅ **Dashboard как предпоследняя страница** - все пути ведут к главной
2. ✅ **Подтверждение выхода** - красивый диалог с выбором
3. ✅ **Интуитивная навигация** - понятное поведение кнопки "Назад"
4. ✅ **Безопасность** - нельзя случайно выйти из приложения
5. ✅ **Централизованная логика** - вся навигация в одном месте

### Пользовательский опыт:
- 🎯 **Простота** - одна кнопка для возврата к главной
- 🎯 **Безопасность** - подтверждение перед выходом
- 🎯 **Предсказуемость** - всегда знаешь, куда ведет "Назад"
- 🎯 **Эффективность** - быстрый доступ к главной странице

Теперь навигация работает именно так, как вы просили! 🚀 