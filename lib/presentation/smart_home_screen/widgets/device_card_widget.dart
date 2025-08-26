import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/smart_home_device_model.dart';

class DeviceCardWidget extends StatefulWidget {
  final SmartHomeDevice device;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double>? onTemperatureChange;
  final VoidCallback? onLongPress;

  const DeviceCardWidget({
    super.key,
    required this.device,
    required this.onToggle,
    this.onTemperatureChange,
    this.onLongPress,
  });

  @override
  State<DeviceCardWidget> createState() => _DeviceCardWidgetState();
}

class _DeviceCardWidgetState extends State<DeviceCardWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _switchController;
  late Animation<double> _switchAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _switchController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _switchAnimation = CurvedAnimation(
      parent: _switchController,
      curve: Curves.easeOutCubic,
    );

    if (widget.device.status) {
      _switchController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(DeviceCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.device.status != widget.device.status) {
      if (widget.device.status) {
        _switchController.forward();
        _startPulseAnimation();
      } else {
        _switchController.reverse();
        _pulseController.stop();
      }
    }
  }

  void _startPulseAnimation() {
    if (widget.device.status && widget.device.type == SmartDeviceType.light) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _switchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseAnimation, _switchAnimation]),
        builder: (context, child) {
          final isLightOn = widget.device.type == SmartDeviceType.light && 
                           widget.device.status;
          
          return Transform.scale(
            scale: isLightOn ? _pulseAnimation.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.device.status 
                      ? _getDeviceAccentColor().withOpacity(0.2)
                      : const Color(0xFFE5E5EA),
                  width: widget.device.status ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.device.status
                        ? _getDeviceAccentColor().withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: widget.device.status ? 20 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildContent(),
                  if (widget.device.hasTemperatureControl) ...[
                    const SizedBox(height: 20),
                    _buildTemperatureControl(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Icon container
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.device.status 
                ? _getDeviceAccentColor().withOpacity(0.15)
                : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 24,
                color: widget.device.status 
                    ? _getDeviceAccentColor()
                    : const Color(0xFF8E8E93),
              ),
              child: Text(widget.device.icon),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Device info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.device.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 14,
                  color: widget.device.status 
                      ? _getDeviceAccentColor()
                      : const Color(0xFF8E8E93),
                  fontWeight: widget.device.status 
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                child: Text(widget.device.statusText),
              ),
            ],
          ),
        ),
        
        // Toggle switch
        _buildToggleSwitch(),
      ],
    );
  }

  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onToggle(!widget.device.status);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: widget.device.status 
              ? _getDeviceAccentColor()
              : const Color(0xFFE5E5EA),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              left: widget.device.status ? 22 : 2,
              top: 2,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!widget.device.status) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getDeviceAccentColor().withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getDeviceAccentColor().withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildStatusIndicator(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusDescription(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _getDeviceAccentColor(),
                  ),
                ),
                if (widget.device.hasTemperatureControl && 
                    widget.device.temperature != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${widget.device.temperature!.round()}°C',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: _getDeviceAccentColor(),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildTemperatureControl() {
    if (!widget.device.status || !widget.device.hasTemperatureControl) {
      return const SizedBox.shrink();
    }

    final currentTemp = widget.device.temperature ?? 23.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Температура',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Decrease button
              _buildTemperatureButton(
                icon: Icons.remove,
                onPressed: currentTemp > 16
                    ? () => widget.onTemperatureChange?.call(currentTemp - 1)
                    : null,
              ),
              
              // Temperature display
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFE5E5EA),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${currentTemp.round()}°C',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Increase button
              _buildTemperatureButton(
                icon: Icons.add,
                onPressed: currentTemp < 30
                    ? () => widget.onTemperatureChange?.call(currentTemp + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTemperatureButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed != null 
          ? () {
              HapticFeedback.lightImpact();
              onPressed();
            }
          : null,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: onPressed != null 
              ? _getDeviceAccentColor()
              : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: onPressed != null 
              ? Colors.white
              : const Color(0xFF8E8E93),
          size: 20,
        ),
      ),
    );
  }

  Color _getDeviceAccentColor() {
    switch (widget.device.type) {
      case SmartDeviceType.light:
        return const Color(0xFFFF9500); // Orange for lights
      case SmartDeviceType.ac:
        return const Color(0xFF007AFF); // Blue for AC
      case SmartDeviceType.heater:
        return const Color(0xFFFF3B30); // Red for heater
      case SmartDeviceType.door:
        return const Color(0xFF34C759); // Green for door locks
      case SmartDeviceType.camera:
        return const Color(0xFF5856D6); // Purple for cameras
    }
  }

  String _getStatusDescription() {
    if (!widget.device.status) return 'Выключено';

    switch (widget.device.type) {
      case SmartDeviceType.light:
        return 'Светит';
      case SmartDeviceType.ac:
        return 'Охлаждает';
      case SmartDeviceType.heater:
        return 'Нагревает';
      case SmartDeviceType.door:
        return 'Заблокирован';
      case SmartDeviceType.camera:
        return 'Записывает';
    }
  }
} 