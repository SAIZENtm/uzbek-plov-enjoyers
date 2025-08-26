import 'dart:async';
import 'package:flutter/material.dart';

/// Миксин для безопасного управления состоянием
/// Автоматически отменяет подписки и проверяет mounted
mixin SafeStateMixin<T extends StatefulWidget> on State<T> {
  /// Список активных подписок
  final List<StreamSubscription> _subscriptions = [];
  
  /// Список активных таймеров
  final List<Timer> _timers = [];
  
  /// Список контроллеров для dispose
  final List<ChangeNotifier> _controllers = [];
  
  /// Активные Future операции
  final Set<CancelableOperation> _operations = {};
  
  /// Безопасный setState с проверкой mounted
  void safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
  
  /// Добавить подписку для автоматической отмены
  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }
  
  /// Подписаться на Stream с автоматической отпиской
  StreamSubscription<S> listenToStream<S>(
    Stream<S> stream,
    void Function(S event) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
    
    addSubscription(subscription);
    return subscription;
  }
  
  /// Добавить таймер для автоматической отмены
  Timer addTimer(Duration duration, VoidCallback callback) {
    final timer = Timer(duration, callback);
    _timers.add(timer);
    return timer;
  }
  
  /// Добавить периодический таймер
  Timer addPeriodicTimer(Duration duration, void Function(Timer) callback) {
    final timer = Timer.periodic(duration, callback);
    _timers.add(timer);
    return timer;
  }
  
  /// Добавить контроллер для автоматического dispose
  T addController<T extends ChangeNotifier>(T controller) {
    _controllers.add(controller);
    return controller;
  }
  
  /// Выполнить Future с проверкой mounted
  Future<T?> runSafeAsync<T>(Future<T> Function() computation) async {
    if (!mounted) return null;
    
    try {
      final result = await computation();
      
      // Проверяем mounted после await
      if (!mounted) return null;
      
      return result;
    } catch (e) {
      // Если виджет был размонтирован, игнорируем ошибку
      if (!mounted) return null;
      
      // Иначе пробрасываем ошибку
      rethrow;
    }
  }
  
  /// Выполнить Future с обновлением состояния
  Future<void> runWithSetState<T>(
    Future<T> Function() computation, {
    void Function()? onStart,
    void Function(T result)? onSuccess,
    void Function(Object error)? onError,
    void Function()? onComplete,
  }) async {
    // Вызываем onStart
    if (onStart != null) {
      safeSetState(onStart);
    }
    
    try {
      final result = await computation();
      
      // Проверяем mounted после await
      if (!mounted) return;
      
      // Вызываем onSuccess
      if (onSuccess != null) {
        safeSetState(() => onSuccess(result));
      }
    } catch (e) {
      // Проверяем mounted
      if (!mounted) return;
      
      // Вызываем onError
      if (onError != null) {
        safeSetState(() => onError(e));
      } else {
        // Если обработчик ошибок не предоставлен, пробрасываем
        rethrow;
      }
    } finally {
      // Проверяем mounted
      if (!mounted) return;
      
      // Вызываем onComplete
      if (onComplete != null) {
        safeSetState(onComplete);
      }
    }
  }
  
  /// Создать debounced функцию
  VoidCallback debounce(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    Timer? debounceTimer;
    
    return () {
      // Отменяем предыдущий таймер
      debounceTimer?.cancel();
      
      // Создаем новый таймер
      debounceTimer = Timer(duration, () {
        if (mounted) {
          callback();
        }
      });
      
      // Добавляем в список для очистки
      if (debounceTimer != null) {
        _timers.add(debounceTimer!);
      }
    };
  }
  
  /// Создать throttled функцию
  VoidCallback throttle(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 300),
  }) {
    bool canCall = true;
    
    return () {
      if (!canCall) return;
      
      if (mounted) {
        callback();
        canCall = false;
        
        addTimer(duration, () {
          canCall = true;
        });
      }
    };
  }
  
  @override
  void dispose() {
    // Отменяем все подписки
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Отменяем все таймеры
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    
    // Dispose всех контроллеров
    for (final controller in _controllers) {
      controller.dispose();
    }
    _controllers.clear();
    
    // Отменяем все операции
    for (final operation in _operations) {
      operation.cancel();
    }
    _operations.clear();
    
    super.dispose();
  }
}

/// Расширение для безопасной работы с Future
extension SafeFutureExtension<T> on Future<T> {
  /// Выполнить Future только если виджет mounted
  Future<T?> runIfMounted(State state) async {
    if (!state.mounted) return null;
    
    final result = await this;
    
    if (!state.mounted) return null;
    
    return result;
  }
  
  /// Выполнить Future с setState если mounted
  Future<void> thenSetState(
    State state,
    void Function(T value) onValue,
  ) async {
    final result = await this;
    
    if (state.mounted) {
      // Используем safeSetState если доступен, иначе обычный setState через рефлексию
      if (state is SafeStateMixin) {
        state.safeSetState(() => onValue(result));
      } else {
        // Для обычных State виджетов - пользователь должен вызывать это изнутри класса
        throw UnsupportedError(
          'thenSetState can only be used with SafeStateMixin. '
          'Use runIfMounted instead or call setState manually inside your State class.'
        );
      }
    }
  }
}

/// Cancelable operation wrapper
class CancelableOperation<T> {
  final Future<T> _future;
  final void Function()? _onCancel;
  bool _isCanceled = false;
  
  CancelableOperation(this._future, [this._onCancel]);
  
  bool get isCanceled => _isCanceled;
  
  void cancel() {
    _isCanceled = true;
    _onCancel?.call();
  }
  
  Future<T?> get value async {
    if (_isCanceled) return null;
    
    try {
      return await _future;
    } catch (e) {
      if (_isCanceled) return null;
      rethrow;
    }
  }
}
