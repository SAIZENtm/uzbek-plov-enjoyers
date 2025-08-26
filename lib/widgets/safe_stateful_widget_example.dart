import 'dart:async';
import 'package:flutter/material.dart';
import '../core/mixins/safe_state_mixin.dart';

/// Пример безопасного StatefulWidget с использованием SafeStateMixin
class SafeExampleScreen extends StatefulWidget {
  const SafeExampleScreen({super.key});

  @override
  State<SafeExampleScreen> createState() => _SafeExampleScreenState();
}

class _SafeExampleScreenState extends State<SafeExampleScreen> 
    with SafeStateMixin {
  

  
  // Контроллеры добавляются через addController
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  
  // Состояние
  bool _isLoading = false;
  List<String> _items = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    
    // Инициализация контроллеров с автоматическим dispose
    _searchController = addController(TextEditingController());
    _scrollController = addController(ScrollController());
    
    // Подписка на Stream с автоматической отпиской (заглушка)
    listenToStream(
      Stream.periodic(Duration(seconds: 10), (i) => i), // Заглушка
      (data) {
        // Безопасное обновление состояния
        safeSetState(() {
          // Обновляем UI при изменении авторизации
        });
      },
    );
    
    // Добавляем debounced поиск
    _searchController.addListener(
      debounce(_performSearch, duration: const Duration(milliseconds: 500)),
    );
    
    // Загружаем начальные данные
    _loadData();
    
    // Периодическое обновление с автоматической отменой
    addPeriodicTimer(
      const Duration(minutes: 5),
      (_) => _refreshData(),
    );
  }
  
  /// Загрузка данных с безопасным обновлением состояния
  Future<void> _loadData() async {
    await runWithSetState(
      () => Future.value(['item1', 'item2', 'item3']), // Заглушка
      onStart: () {
        _isLoading = true;
        _error = null;
      },
      onSuccess: (data) {
        _items = List<String>.from(data);
        _isLoading = false;
      },
      onError: (error) {
        _error = error.toString();
        _isLoading = false;
      },
    );
  }
  
  /// Обновление данных
  Future<void> _refreshData() async {
    // runSafeAsync автоматически проверяет mounted
    final newData = await runSafeAsync(() => Future.value(['refreshed1', 'refreshed2']));
    
    if (newData != null) {
      safeSetState(() {
        _items = newData;
      });
    }
  }
  
  /// Поиск
  Future<void> _performSearch() async {
    final query = _searchController.text;
    
    if (query.isEmpty) {
      await _loadData();
      return;
    }
    
    // Безопасное выполнение асинхронной операции
    await runWithSetState(
      () => Future.value(['search_result_1', 'search_result_2']),
      onStart: () => _isLoading = true,
      onSuccess: (results) {
        _items = List<String>.from(results);
        _isLoading = false;
      },
      onError: (error) {
        _error = 'Ошибка поиска: $error';
        _isLoading = false;
      },
    );
  }
  
  /// Обработка нажатия на элемент
  Future<void> _onItemTap(String itemId) async {
    // Показываем индикатор загрузки
    safeSetState(() => _isLoading = true);
    
    try {
      // Выполняем операцию
      final details = {'title': 'Item $itemId', 'description': 'Details for $itemId'};
      
      // Проверяем mounted перед навигацией
      if (!mounted) return;
      
      // Безопасная навигация
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ItemDetailsScreen(details: details),
        ),
      );
      
      // Обновляем список после возврата
      await _refreshData();
      
    } catch (e) {
      // Безопасное отображение ошибки
      safeSetState(() {
        _error = 'Не удалось загрузить детали';
      });
    } finally {
      // Убираем индикатор загрузки
      safeSetState(() => _isLoading = false);
    }
  }
  

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Безопасный пример'),
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          // Контент
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent() {
    if (_isLoading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    
    if (_items.isEmpty) {
      return const Center(
        child: Text('Нет данных'),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          
          return ListTile(
            title: Text(item),
            trailing: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _onItemTap(item),
          );
        },
      ),
    );
  }
}

/// Пример экрана деталей
class ItemDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> details;
  
  const ItemDetailsScreen({
    super.key,
    required this.details,
  });
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(details['title'] ?? 'Детали'),
      ),
      body: Center(
        child: Text('Детали элемента'),
      ),
    );
  }
}
