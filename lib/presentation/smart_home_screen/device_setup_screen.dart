import 'package:go_router/go_router.dart';
import '../../core/app_export.dart';
import '../../widgets/blue_button.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen>
    with TickerProviderStateMixin {
  late final SmartHomeService _smartHomeService;
  late final SmartDeviceDiscoveryService _discoveryService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isScanning = false;
  bool _isConnecting = false;
  List<DiscoveredDevice> _foundDevices = [];
  DiscoveredDevice? _selectedDevice;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _smartHomeService = GetIt.instance<SmartHomeService>();
    _discoveryService = SmartDeviceDiscoveryService(
      loggingService: GetIt.instance<LoggingService>(),
    );
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
    
    // Автоматически начинаем сканирование
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDeviceScan();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Подключение устройств',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1C1C1E),
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isScanning) {
      return _buildScanningState();
    }
    
    if (_foundDevices.isEmpty && !_isScanning) {
      return _buildNoDevicesState();
    }
    
    if (_selectedDevice != null && _isConnecting) {
      return _buildConnectingState();
    }
    
    return _buildDevicesList();
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Анимированная иконка сканирования
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 2),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 6.28, // 2π радиан = 360°
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF007AFF),
                      width: 3,
                    ),
                  ),
                  child: const Icon(
                    Icons.wifi_find,
                    size: 50,
                    color: Color(0xFF007AFF),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Поиск умных устройств',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            _statusMessage.isEmpty 
                ? 'Сканируем WiFi сеть на умные устройства...'
                : _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 32),
          
          const CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFF007AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDevicesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off,
              size: 50,
              color: Color(0xFFFF9500),
            ),
          ),
          
          const SizedBox(height: 32),
          
          const Text(
            'Устройства не найдены',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'Убедитесь что:\n• Умные устройства подключены к WiFi\n• Устройства в той же сети что и телефон\n• Устройства включены и работают',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 32),
          
          BlueButton(
            text: 'Повторить поиск',
            onPressed: _startDeviceScan,
            icon: Icons.refresh,
          ),
          
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => _showManualSetupDialog(),
            child: const Text(
              'Настроить вручную',
              style: TextStyle(
                color: Color(0xFF007AFF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    return Column(
      children: [
        // Заголовок
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Найденные устройства',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Найдено ${_foundDevices.length} ${_getDeviceWord(_foundDevices.length)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ),
        
        // Список устройств
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _foundDevices.length,
            itemBuilder: (context, index) {
              final device = _foundDevices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildDeviceCard(device),
              );
            },
          ),
        ),
        
        // Нижняя панель
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: BlueButton(
              text: 'Повторить поиск',
              onPressed: _startDeviceScan,
              icon: Icons.refresh,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(DiscoveredDevice device) {
    return GestureDetector(
      onTap: () => _connectToDevice(device),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E5EA),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Иконка устройства
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.memory,
                size: 30,
                color: Color(0xFF007AFF),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Информация об устройстве
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1C1C1E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.brand} • ${device.ipAddress}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        device.isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 16,
                        color: device.isOnline 
                            ? const Color(0xFF34C759)
                            : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        device.isOnline ? 'Онлайн' : 'Оффлайн',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.isOnline 
                              ? const Color(0xFF34C759)
                              : const Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Кнопка подключения
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Подключить',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Анимация подключения
          TweenAnimationBuilder<double>(
            duration: const Duration(seconds: 1),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 4,
                      color: const Color(0xFF34C759),
                    ),
                    const Icon(
                      Icons.link,
                      size: 40,
                      color: Color(0xFF34C759),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Подключение к\n${_selectedDevice?.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'Настраиваем связь с устройством...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ),
    );
  }

  // Методы управления
  Future<void> _startDeviceScan() async {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
      _statusMessage = 'Сканируем WiFi сети...';
    });

    try {
      // Сканируем умные устройства в WiFi сети
      final devices = await _discoveryService.scanForSmartDevices();
      
      await Future.delayed(const Duration(seconds: 2)); // Для UX
      
      setState(() {
        _foundDevices = devices;
        _isScanning = false;
        _statusMessage = devices.isEmpty 
            ? 'Устройства не найдены'
            : 'Найдено ${devices.length} ${_getDeviceWord(devices.length)}';
      });

      if (devices.isNotEmpty) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Ошибка сканирования: $e';
      });
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    setState(() {
      _selectedDevice = device;
      _isConnecting = true;
    });

    try {
      HapticFeedback.mediumImpact();
      
      // Конвертируем в SmartHomeDevice и добавляем
      final smartDevice = device.toSmartHomeDevice();
      final success = await _smartHomeService.addDevice(smartDevice);
      
      if (success && mounted) {
        
        // Показываем успех
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('${device.name} подключен!'),
              ],
            ),
            backgroundColor: const Color(0xFF34C759),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Возвращаемся назад
        context.pop();
      } else {
        throw Exception('Не удалось подключиться к устройству');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка подключения: $e'),
            backgroundColor: Colors.red,
          ),
        );
        
        setState(() {
          _selectedDevice = null;
          _isConnecting = false;
        });
      }
    }
  }

  void _showManualSetupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ручная настройка'),
        content: const Text(
          'Для ручной настройки:\n\n'
          '1. Убедитесь что устройство подключено к WiFi\n'
          '2. Проверьте что устройство в той же сети\n'
          '3. Попробуйте перезапустить устройство\n'
          '4. Обратитесь к инструкции устройства'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  String _getDeviceWord(int count) {
    if (count == 1) return 'устройство';
    if (count >= 2 && count <= 4) return 'устройства';
    return 'устройств';
  }
} 