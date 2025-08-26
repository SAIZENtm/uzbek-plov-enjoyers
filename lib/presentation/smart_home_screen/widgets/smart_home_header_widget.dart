import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SmartHomeHeaderWidget extends StatelessWidget {
  final int totalDevices;
  final int activeDevices;
  final DateTime? lastUpdate;

  const SmartHomeHeaderWidget({
    super.key,
    required this.totalDevices,
    required this.activeDevices,
    this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        
        // Title
        const Text(
          '🏠 Умный дом',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1C1E),
            height: 1.1,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Stats row
        Row(
          children: [
            _buildStatChip(
              icon: '📱',
              label: totalDevices == 0 
                  ? 'Нет устройств'
                  : '$totalDevices ${_getDeviceWord(totalDevices)}',
              color: const Color(0xFF007AFF),
            ),
            
            if (totalDevices > 0) ...[
              const SizedBox(width: 12),
              _buildStatChip(
                icon: activeDevices > 0 ? '🟢' : '⭕',
                label: activeDevices > 0
                    ? '$activeDevices включено'
                    : 'Все выключено',
                color: activeDevices > 0 
                    ? const Color(0xFF34C759)
                    : const Color(0xFF8E8E93),
              ),
            ],
          ],
        ),
        
        // Last update info
        if (lastUpdate != null) ...[
          const SizedBox(height: 8),
          Text(
            'Обновлено ${_formatLastUpdate(lastUpdate!)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8E93),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatChip({
    required String icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            icon,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
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

  String _formatLastUpdate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 30) {
      return 'только что';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds} сек назад';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays == 1) {
      return 'вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    } else {
      return DateFormat('dd.MM.yyyy').format(dateTime);
    }
  }
} 