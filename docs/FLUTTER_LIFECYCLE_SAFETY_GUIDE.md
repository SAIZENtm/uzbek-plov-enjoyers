# Flutter Lifecycle Safety Guide

## Распространенные проблемы

### 1. setState после await без mounted проверки

```dart
// ❌ ОПАСНО - может вызвать ошибку если виджет размонтирован
Future<void> loadData() async {
  final data = await api.fetchData();
  setState(() {
    _data = data;
  });
}

// ✅ БЕЗОПАСНО - проверяем mounted
Future<void> loadData() async {
  final data = await api.fetchData();
  if (mounted) {
    setState(() {
      _data = data;
    });
  }
}
```

### 2. Неотписанные подписки

```dart
// ❌ УТЕЧКА ПАМЯТИ
class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    stream.listen((data) {
      setState(() => _data = data);
    });
  }
}

// ✅ ПРАВИЛЬНО
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _subscription = stream.listen((data) {
      if (mounted) {
        setState(() => _data = data);
      }
    });
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

### 3. Неотмененные таймеры

```dart
// ❌ ТАЙМЕР ПРОДОЛЖИТ РАБОТАТЬ
Timer.periodic(Duration(seconds: 1), (timer) {
  setState(() => _counter++);
});

// ✅ ПРАВИЛЬНО
Timer? _timer;

@override
void initState() {
  super.initState();
  _timer = Timer.periodic(Duration(seconds: 1), (timer) {
    if (mounted) {
      setState(() => _counter++);
    }
  });
}

@override
void dispose() {
  _timer?.cancel();
  super.dispose();
}
```

## Решение: SafeStateMixin

### Использование

```dart
class _MyScreenState extends State<MyScreen> with SafeStateMixin {
  @override
  void initState() {
    super.initState();
    
    // Автоматическая отписка при dispose
    listenToStream(
      authService.userStream,
      (user) => safeSetState(() => _user = user),
    );
    
    // Автоматическая отмена при dispose
    addTimer(
      Duration(seconds: 5),
      () => _showWelcomeMessage(),
    );
    
    // Контроллеры с автоматическим dispose
    _textController = addController(TextEditingController());
  }
  
  // Безопасная асинхронная операция
  Future<void> _loadData() async {
    await runWithSetState(
      () => api.fetchData(),
      onStart: () => _isLoading = true,
      onSuccess: (data) {
        _data = data;
        _isLoading = false;
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
      },
    );
  }
}
```

### Возможности SafeStateMixin

| Метод | Описание | Автоматически |
|-------|----------|--------------|
| `safeSetState()` | setState с проверкой mounted | ✅ mounted проверка |
| `listenToStream()` | Подписка на Stream | ✅ отписка в dispose |
| `addTimer()` | Создание Timer | ✅ отмена в dispose |
| `addController()` | Регистрация Controller | ✅ dispose контроллера |
| `runSafeAsync()` | Выполнение Future | ✅ mounted проверка |
| `runWithSetState()` | Future с обновлением UI | ✅ обработка всех состояний |
| `debounce()` | Отложенное выполнение | ✅ отмена при dispose |
| `throttle()` | Ограничение частоты | ✅ очистка таймеров |

## Миграция существующего кода

### 1. Автоматический поиск проблем

```bash
# Найти все проблемы
dart scripts/fix_setstate_issues.dart

# Автоматически исправить
dart scripts/fix_setstate_issues.dart --fix

# Подробный вывод
dart scripts/fix_setstate_issues.dart --verbose
```

### 2. Ручная миграция

#### Шаг 1: Добавить SafeStateMixin

```dart
// Было
class _MyScreenState extends State<MyScreen> {

// Стало
class _MyScreenState extends State<MyScreen> with SafeStateMixin {
```

#### Шаг 2: Заменить setState

```dart
// Было
setState(() => _counter++);

// Стало
safeSetState(() => _counter++);
```

#### Шаг 3: Обернуть подписки

```dart
// Было
_subscription = stream.listen(handler);

// Стало
listenToStream(stream, handler);
// или
_subscription = stream.listen(handler);
addSubscription(_subscription);
```

#### Шаг 4: Обернуть таймеры

```dart
// Было
Timer(duration, callback);

// Стало
addTimer(duration, callback);
```

#### Шаг 5: Зарегистрировать контроллеры

```dart
// Было
_controller = TextEditingController();

// Стало
_controller = addController(TextEditingController());
```

## Best Practices

### 1. Всегда проверяйте mounted после await

```dart
Future<void> doSomethingAsync() async {
  // Операция 1
  await operation1();
  if (!mounted) return; // Проверка
  
  // Операция 2
  await operation2();
  if (!mounted) return; // Проверка
  
  // Обновление UI
  setState(() => _result = 'Done');
}
```

### 2. Используйте правильные паттерны для навигации

```dart
// ❌ Опасно - может вызвать ошибку
Future<void> navigateDelayed() async {
  await Future.delayed(Duration(seconds: 2));
  Navigator.push(context, route); // context может быть невалидным
}

// ✅ Безопасно
Future<void> navigateDelayed() async {
  await Future.delayed(Duration(seconds: 2));
  if (!mounted) return;
  Navigator.push(context, route);
}
```

### 3. Отменяйте операции при dispose

```dart
class _MyScreenState extends State<MyScreen> {
  CancelableOperation? _operation;
  
  Future<void> _startLongOperation() async {
    _operation?.cancel();
    _operation = CancelableOperation.fromFuture(
      _performLongOperation(),
    );
    
    final result = await _operation!.value;
    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }
  
  @override
  void dispose() {
    _operation?.cancel();
    super.dispose();
  }
}
```

### 4. Используйте FutureBuilder для простых случаев

```dart
// Вместо ручного управления состоянием
FutureBuilder<Data>(
  future: api.fetchData(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    
    if (snapshot.hasError) {
      return Text('Error: ${snapshot.error}');
    }
    
    return Text('Data: ${snapshot.data}');
  },
)
```

### 5. Правильное использование GlobalKey

```dart
class _MyScreenState extends State<MyScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();
  
  void _showSnackBar() {
    // Проверяем что key still mounted
    if (_scaffoldKey.currentState?.mounted ?? false) {
      _scaffoldKey.currentState!.showSnackBar(
        SnackBar(content: Text('Hello')),
      );
    }
  }
}
```

## Общие антипаттерны

### 1. Вызов setState в initState

```dart
// ❌ НЕПРАВИЛЬНО
@override
void initState() {
  super.initState();
  setState(() => _value = 10); // Ошибка!
}

// ✅ ПРАВИЛЬНО
@override
void initState() {
  super.initState();
  _value = 10; // Просто присвойте значение
  
  // Или используйте WidgetsBinding
  WidgetsBinding.instance.addPostFrameCallback((_) {
    setState(() => _value = 10);
  });
}
```

### 2. setState в build методе

```dart
// ❌ БЕСКОНЕЧНЫЙ ЦИКЛ
@override
Widget build(BuildContext context) {
  setState(() => _counter++); // Никогда так не делайте!
  return Text('$_counter');
}
```

### 3. Забытый super.dispose()

```dart
// ❌ НЕПРАВИЛЬНО
@override
void dispose() {
  _controller.dispose();
  // Забыли super.dispose()!
}

// ✅ ПРАВИЛЬНО
@override
void dispose() {
  _controller.dispose();
  super.dispose(); // Всегда вызывайте в конце
}
```

## Тестирование

### 1. Unit тесты для SafeStateMixin

```dart
testWidgets('SafeStateMixin cancels timers on dispose', (tester) async {
  await tester.pumpWidget(MyWidget());
  
  // Проверяем что таймер работает
  expect(find.text('0'), findsOneWidget);
  
  await tester.pump(Duration(seconds: 1));
  expect(find.text('1'), findsOneWidget);
  
  // Dispose widget
  await tester.pumpWidget(Container());
  
  // Таймер должен быть отменен
  await tester.pump(Duration(seconds: 1));
  // Никаких ошибок
});
```

### 2. Проверка mounted в тестах

```dart
testWidgets('Does not setState after dispose', (tester) async {
  await tester.pumpWidget(MyWidget());
  
  // Запускаем асинхронную операцию
  final state = tester.state<MyWidgetState>(find.byType(MyWidget));
  state.startAsyncOperation();
  
  // Dispose widget до завершения операции
  await tester.pumpWidget(Container());
  
  // Завершаем операцию
  await tester.pump(Duration(seconds: 2));
  
  // Не должно быть ошибок
  expect(tester.takeException(), isNull);
});
```

## Checklist

- [ ] Все setState обернуты в mounted проверку
- [ ] Все StreamSubscription отписаны в dispose
- [ ] Все Timer отменены в dispose
- [ ] Все Controller disposed
- [ ] Навигация проверяет mounted
- [ ] Используется SafeStateMixin где возможно
- [ ] Нет setState в initState или build
- [ ] super.dispose() вызывается последним
