import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/app_export.dart';

class RequestCard extends StatefulWidget {
  final ServiceRequest request;
  final VoidCallback? onTap;

  const RequestCard({
    super.key,
    required this.request,
    this.onTap,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => _handleTapDown(),
                onTapUp: (_) => _handleTapUp(),
                onTapCancel: () => _handleTapUp(),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getBorderColor(),
                      width: _hasAdminResponse() ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _hasAdminResponse() 
                          ? AppTheme.newportPrimary.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.1),
                        blurRadius: _hasAdminResponse() ? 12 : 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildTypeIcon(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getCategoryName(widget.request.category),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.request.description,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Показываем фотографии если есть
                      if (widget.request.photos.isNotEmpty) ...[
                        _buildPhotosPreview(),
                        const SizedBox(height: 16),
                      ],
                      // Показываем ответ администратора если есть
                      if (_hasAdminResponse()) ...[
                        _buildAdminResponsePreview(),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(widget.request.createdAt),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Кв. ${widget.request.apartmentNumber}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTapDown() {
    setState(() {
      _isPressed = true;
    });
    _animationController.forward();
  }

  void _handleTapUp() {
    setState(() {
      _isPressed = false;
    });
    _animationController.reverse();
  }

  bool _hasAdminResponse() {
    return widget.request.additionalData['adminResponse'] != null && 
           widget.request.additionalData['adminResponse'].toString().trim().isNotEmpty;
  }

  Color _getBorderColor() {
    if (_isPressed) {
      return AppTheme.newportPrimary.withValues(alpha: 0.5);
    }
    
    // Если есть ответ администратора, всегда используем основной цвет
    if (_hasAdminResponse()) {
      return AppTheme.newportPrimary;
    }
    
    switch (widget.request.status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.inProgress:
        return AppTheme.newportPrimary;
      case RequestStatus.completed:
        return Colors.green;
      case RequestStatus.cancelled:
      case RequestStatus.rejected:
        return Colors.red;
    }
  }

  Widget _buildTypeIcon() {
    final iconData = _getTypeIcon();
    final iconColor = _getTypeIconColor();
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusConfig = _getStatusConfig();
    final hasResponse = _hasAdminResponse();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusConfig.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusConfig.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusConfig.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusConfig.text,
            style: TextStyle(
              color: statusConfig.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasResponse) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.admin_panel_settings,
              size: 12,
              color: statusConfig.color,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (widget.request.category.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing_rounded;
      case 'electrical':
        return Icons.electrical_services_rounded;
      case 'maintenance':
      case 'general':
        return Icons.build_rounded;
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'hvac':
        return Icons.thermostat_rounded;
      default:
        return Icons.build_rounded;
    }
  }

  Color _getTypeIconColor() {
    switch (widget.request.category.toLowerCase()) {
      case 'plumbing':
        return const Color(0xFF007AFF);
      case 'electrical':
        return const Color(0xFFFF9500);
      case 'maintenance':
      case 'general':
        return const Color(0xFF34C759);
      case 'cleaning':
        return const Color(0xFF5856D6);
      case 'hvac':
        return const Color(0xFFFF3B30);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  String _getCategoryName(String category) {
    switch (category.toLowerCase()) {
      case 'plumbing':
        return 'Сантехника';
      case 'electrical':
        return 'Электричество';
      case 'hvac':
        return 'Отопление/Кондиционирование';
      case 'general':
        return 'Общее обслуживание';
      case 'cleaning':
        return 'Уборка';
      case 'maintenance':
        return 'Обслуживание';
      default:
        return category;
    }
  }

  StatusConfig _getStatusConfig() {
    // Если есть ответ администратора, заявка автоматически "В процессе"
    if (_hasAdminResponse()) {
      return const StatusConfig(
        text: 'В процессе',
        color: AppTheme.newportPrimary,
      );
    }
    
    switch (widget.request.status) {
      case RequestStatus.pending:
        return const StatusConfig(
          text: 'В ожидании',
          color: Colors.orange,
        );
      case RequestStatus.inProgress:
        return const StatusConfig(
          text: 'В процессе',
          color: AppTheme.newportPrimary,
        );
      case RequestStatus.completed:
        return const StatusConfig(
          text: 'Завершено',
          color: Colors.green,
        );
      case RequestStatus.cancelled:
        return const StatusConfig(
          text: 'Отменено',
          color: Colors.red,
        );
      case RequestStatus.rejected:
        return const StatusConfig(
          text: 'Отклонено',
          color: Colors.red,
        );
    }
  }

  Widget _buildAdminResponsePreview() {
    final adminResponse = widget.request.additionalData['adminResponse'].toString();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.newportPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.newportPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                size: 16,
                color: AppTheme.newportPrimary,
              ),
              SizedBox(width: 4),
              Text(
                'Ответ администратора:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.newportPrimary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            adminResponse,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosPreview() {
    final photos = widget.request.photos;
    final displayPhotos = photos.take(3).toList(); // Показываем максимум 3 фото
    
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          ...displayPhotos.asMap().entries.map((entry) {
            final index = entry.key;
            final photoUrl = entry.value;
            
            return Container(
              margin: EdgeInsets.only(right: index < displayPhotos.length - 1 ? 8 : 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover, // Важно! Сохраняем пропорции
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          if (photos.length > 3) ...[
            const SizedBox(width: 8),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.mediumGray),
              ),
              child: Center(
                child: Text(
                  '+${photos.length - 3}',
                  style: const TextStyle(
                    color: AppTheme.mediumGray,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} дн назад';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months мес назад';
    }
  }
}

class StatusConfig {
  final String text;
  final Color color;

  const StatusConfig({
    required this.text,
    required this.color,
  });
} 