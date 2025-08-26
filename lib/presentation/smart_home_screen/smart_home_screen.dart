import 'package:go_router/go_router.dart';
import '../../core/app_export.dart';
import '../../widgets/connection_indicator.dart';
import '../../widgets/blue_button.dart';
import 'widgets/device_card_widget.dart';
import 'widgets/smart_home_header_widget.dart';
import 'add_device_screen.dart';
import 'device_setup_screen.dart';

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen>
    with TickerProviderStateMixin {
  late final SmartHomeService _smartHomeService;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _smartHomeService = GetIt.instance<SmartHomeService>();
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

    _animationController.forward();
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
      body: StreamBuilder<SmartHomeConfiguration>(
        stream: _smartHomeService.getSmartHomeConfigurationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          final config = snapshot.data ?? SmartHomeConfiguration.empty;
          return _buildMainContent(config);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF007AFF),
          ),
          SizedBox(height: 16),
          Text(
            'Загружаем умный дом...',
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.home_outlined,
            size: 64,
            color: Color(0xFFD1D1D6),
          ),
          const SizedBox(height: 16),
          const Text(
            'Не удалось загрузить\nумный дом',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          BlueButton(
            text: 'Повторить попытку',
            onPressed: () {
              setState(() {});
            },
            width: 180,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(SmartHomeConfiguration config) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                _buildAppBar(config),
                _buildDevicesGrid(config),
                if (config.devices.isEmpty) _buildEmptyState(),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100), // Space for FAB
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(SmartHomeConfiguration config) {
    return SliverAppBar(
      backgroundColor: const Color(0xFFF8F9FA),
      elevation: 0,
      pinned: true,
      expandedHeight: 120,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF007AFF)),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
          child: SmartHomeHeaderWidget(
            totalDevices: config.devices.length,
            activeDevices: config.activeDevicesCount,
            lastUpdate: config.lastSyncTime,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz, color: Color(0xFF007AFF)),
          onPressed: () => _showMoreOptions(context),
        ),
      ],
    );
  }

  Widget _buildDevicesGrid(SmartHomeConfiguration config) {
    if (config.devices.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Группируем устройства по типу
    final devicesByType = config.devicesByType;
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final types = devicesByType.keys.toList();
          final type = types[index];
          final devices = devicesByType[type]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок категории
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Row(
                  children: [
                    Text(
                      type.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      type.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${devices.length} ${devices.length == 1 ? 'устройство' : 'устройства'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    ),
                  ],
                ),
              ),
              // Устройства в категории
              ...devices.asMap().entries.map((entry) {
                final deviceIndex = entry.key;
                final device = entry.value;
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    20, 
                    deviceIndex == 0 ? 0 : 12,
                    20, 
                    deviceIndex == devices.length - 1 ? 0 : 0
                  ),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(1.0, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (deviceIndex * 0.1).clamp(0.0, 1.0),
                          1.0,
                          curve: Curves.easeOutCubic,
                        ),
                      ));

                      return SlideTransition(
                        position: slideAnimation,
                        child: DeviceCardWidget(
                          device: device,
                          onToggle: (bool value) => _toggleDevice(device.id, value),
                          onTemperatureChange: (double temperature) => 
                              _updateTemperature(device.id, temperature),
                          onLongPress: () => _showDeviceOptions(device),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          );
        },
        childCount: devicesByType.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.home_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          const Text(
            'Умный дом пуст',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте первое устройство\nчтобы начать управлять домом',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          BlueButton(
            text: 'Найти умные устройства',
            onPressed: () => _showDeviceSetupScreen(),
            width: 220,
            icon: Icons.wifi_find,
          ),
          
          const SizedBox(height: 16),
          
          TextButton(
            onPressed: () => _showAddDeviceScreen(),
            child: const Text(
              'Добавить виртуальное устройство',
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

  // Методы управления устройствами
  Future<void> _toggleDevice(String deviceId, bool value) async {
    HapticFeedback.lightImpact();
    
    final success = await _smartHomeService.updateDeviceStatus(deviceId, value);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить устройство'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateTemperature(String deviceId, double temperature) async {
    final success = await _smartHomeService.updateDeviceTemperature(deviceId, temperature);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось обновить температуру'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAddDeviceScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddDeviceScreen(),
      ),
    );
  }

  void _showDeviceSetupScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DeviceSetupScreen(),
      ),
    );
  }

  void _showDeviceOptions(SmartHomeDevice device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildDeviceOptionsSheet(device),
    );
  }

  Widget _buildDeviceOptionsSheet(SmartHomeDevice device) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D1D6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Device info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      device.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        device.type.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Actions
          _buildOptionTile(
            icon: Icons.edit_outlined,
            title: 'Переименовать',
            onTap: () {
              Navigator.pop(context);
              _showRenameDialog(device);
            },
          ),
          _buildOptionTile(
            icon: Icons.delete_outline,
            title: 'Удалить устройство',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(device);
            },
          ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : const Color(0xFF007AFF),
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive ? Colors.red : const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            const SizedBox(height: 20),
            
            _buildOptionTile(
              icon: Icons.wifi_find,
              title: 'Найти умные устройства',
              onTap: () {
                Navigator.pop(context);
                _showDeviceSetupScreen();
              },
            ),
            _buildOptionTile(
              icon: Icons.add,
              title: 'Добавить устройство',
              onTap: () {
                Navigator.pop(context);
                _showAddDeviceScreen();
              },
            ),
            _buildOptionTile(
              icon: Icons.refresh,
              title: 'Обновить',
              onTap: () {
                Navigator.pop(context);
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(SmartHomeDevice device) {
    final controller = TextEditingController(text: device.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать устройство'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Введите новое название',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != device.name) {
                Navigator.pop(context);
                await _smartHomeService.updateDeviceName(device.id, newName);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(SmartHomeDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить устройство'),
        content: Text('Вы уверены, что хотите удалить "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _smartHomeService.removeDevice(device.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 