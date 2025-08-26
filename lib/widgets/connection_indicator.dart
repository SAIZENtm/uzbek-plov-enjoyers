import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/services/connectivity_service.dart';
import '../core/di/service_locator.dart';

class ConnectionIndicator extends StatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  State<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends State<ConnectionIndicator>
    with SingleTickerProviderStateMixin {
  late final ConnectivityService _connectivityService;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _connectivityService = getIt<ConnectivityService>();
    
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _connectivityService.addListener(_onConnectivityChanged);
    _updateAnimation();
  }

  @override
  void dispose() {
    _connectivityService.removeListener(_onConnectivityChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onConnectivityChanged() {
    if (mounted) {
      setState(() {});
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    if (!_connectivityService.isConnected) {
      _animationController.repeat(reverse: true);
    } else {
      _animationController.stop();
      _animationController.value = 1.0;
    }
  }

  Color _getIndicatorColor() {
    if (!_connectivityService.isConnected) {
      return Colors.red.withValues(alpha: 0.7);
    }
    
    switch (_connectivityService.connectionStatus) {
      case ConnectivityResult.wifi:
        return Colors.green;
      case ConnectivityResult.mobile:
        return Colors.blue;
      case ConnectivityResult.ethernet:
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getConnectionIcon() {
    if (!_connectivityService.isConnected) {
      return Icons.signal_wifi_off;
    }
    
    switch (_connectivityService.connectionStatus) {
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.mobile:
        return Icons.signal_cellular_4_bar;
      case ConnectivityResult.ethernet:
        return Icons.lan;
      default:
        return Icons.signal_wifi_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getIndicatorColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getIndicatorColor(),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getConnectionIcon(),
                size: 14,
                color: _getIndicatorColor().withValues(alpha: _pulseAnimation.value),
              ),
              const SizedBox(width: 4),
              Text(
                _connectivityService.connectionType,
                style: TextStyle(
                  fontSize: 12,
                  color: _getIndicatorColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityService = getIt<ConnectivityService>();
    
    return AnimatedBuilder(
      animation: connectivityService,
      builder: (context, child) {
        if (connectivityService.isConnected) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border(
              bottom: BorderSide(
                color: Colors.orange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.signal_wifi_off,
                size: 16,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Нет подключения к интернету. Показан кешированный контент.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  connectivityService.refreshConnectivity();
                },
                child: Text(
                  'Обновить',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 