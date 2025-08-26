import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_export.dart';
import '../../core/models/notification_model.dart';
import '../../widgets/frosted_glass_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late final NotificationService _notificationService;
  late final LoggingService _loggingService;
  late AnimationController _filterAnimationController;
  late Animation<double> _filterSlideAnimation;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _notificationService = GetIt.instance<NotificationService>();
    _loggingService = GetIt.instance<LoggingService>();
    
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _filterSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _initializeNotifications();
    _filterAnimationController.forward();
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    _notificationService.refreshNotifications().catchError((e) {
      _loggingService.error('Notification initialization failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: _buildAppBar(),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && 
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildEmptyState();
          }

          final notifications = snapshot.data ?? [];
          final filteredNotifications = _getFilteredNotifications(notifications);

          if (filteredNotifications.isEmpty) {
            return Column(
              children: [
                _buildFilterTabs(),
                Expanded(child: _buildEmptyState()),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: _notificationService.refreshNotifications,
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.colors.pureWhite,
            child: Column(
              children: [
                _buildFilterTabs(),
                Expanded(
                  child: _buildGroupedNotificationsList(filteredNotifications),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.colors.pureWhite,
      elevation: 0,
      surfaceTintColor: AppTheme.colors.pureWhite,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: AppTheme.colors.charcoal,
        ),
        onPressed: () => context.go('/dashboard'),
      ),
      title: Text(
        'Уведомления',
        style: AppTheme.typography.headlineSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.colors.charcoal,
        ),
      ),
      actions: [
        StreamBuilder<List<NotificationModel>>(
          stream: _notificationService.notificationsStream,
          builder: (context, snapshot) {
            final unreadCount = _notificationService.unreadCount;
            if (unreadCount > 0) {
              return TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 18,
                  color: AppTheme.primaryColor,
                ),
                label: Text(
                  'Все',
                  style: AppTheme.typography.bodyMedium.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppTheme.colors.lightGray,
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return AnimatedBuilder(
      animation: _filterSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _filterSlideAnimation.value)),
          child: Opacity(
            opacity: _filterSlideAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(16),
              child: FrostedGlassCard(
                child: Row(
                  children: [
                    _buildFilterTab('all', 'Все', Icons.notifications_outlined),
                    _buildFilterTab('admin_response', 'Ответы', Icons.admin_panel_settings_outlined),
                    _buildFilterTab('news', 'Новости', Icons.article_outlined),
                    _buildFilterTab('system', 'Система', Icons.settings_outlined),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterTab(String filter, String label, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppTheme.colors.pureWhite : AppTheme.colors.darkGray,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTheme.typography.bodySmall.copyWith(
                  color: isSelected ? AppTheme.colors.pureWhite : AppTheme.colors.darkGray,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedNotificationsList(List<NotificationModel> notifications) {
    final groupedNotifications = _groupNotificationsByDate(notifications);
    
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groupedNotifications.length,
        itemBuilder: (context, groupIndex) {
          final group = groupedNotifications[groupIndex];
          final date = group['date'] as String;
          final groupNotifications = group['notifications'] as List<NotificationModel>;
          
          return AnimationConfiguration.staggeredList(
            position: groupIndex,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(date),
                    ...groupNotifications.asMap().entries.map((entry) {
                      final index = entry.key;
                      final notification = entry.value;
                      return AnimationConfiguration.staggeredList(
                        position: index,
                        delay: Duration(milliseconds: 50 * index),
                        duration: const Duration(milliseconds: 300),
                        child: SlideAnimation(
                          horizontalOffset: 30.0,
                          child: FadeInAnimation(
                            child: _buildNotificationCard(notification),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 16),
      child: Text(
        date,
        style: AppTheme.typography.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.colors.charcoal,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline,
            color: AppTheme.colors.pureWhite,
            size: 24,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить уведомление?'),
              content: const Text('Это действие нельзя отменить.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Удалить',
                    style: TextStyle(color: Colors.red.shade600),
                  ),
                ),
              ],
            ),
          );
        },
        onDismissed: (direction) {
          _notificationService.deleteNotification(notification.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Уведомление удалено'),
              backgroundColor: AppTheme.colors.charcoal,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
        child: FrostedGlassCard(
          borderColor: notification.isRead
              ? Colors.transparent
              : AppTheme.primaryColor.withValues(alpha: 0.3),
          child: InkWell(
            onTap: () => _onNotificationTap(notification),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildNotificationIcon(notification.type),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: AppTheme.typography.titleMedium.copyWith(
                                      fontWeight: notification.isRead 
                                          ? FontWeight.w500 
                                          : FontWeight.bold,
                                      color: notification.isRead 
                                          ? AppTheme.colors.darkGray 
                                          : AppTheme.colors.charcoal,
                                    ),
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            if (notification.adminName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'От: ${notification.adminName}',
                                style: AppTheme.typography.bodySmall.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        notification.displayTime,
                        style: AppTheme.typography.bodySmall.copyWith(
                          color: AppTheme.colors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    notification.message,
                    style: AppTheme.typography.bodyMedium.copyWith(
                      color: notification.isRead 
                          ? AppTheme.colors.darkGray 
                          : AppTheme.colors.charcoal,
                      height: 1.4,
                    ),
                  ),
                  if (notification.relatedRequestId != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.link_outlined,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Заявка #${notification.relatedRequestId?.substring(0, 8)}',
                            style: AppTheme.typography.bodySmall.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'admin_response':
        icon = Icons.admin_panel_settings_outlined;
        color = AppTheme.secondaryColor;
        break;
      case 'service_update':
        icon = Icons.build_outlined;
        color = Colors.orange.shade600;
        break;
      case 'news':
        icon = Icons.article_outlined;
        color = Colors.purple.shade600;
        break;
      case 'system':
        icon = Icons.info_outline;
        color = Colors.green.shade600;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = AppTheme.colors.mediumGray;
    }

    return Container(
      width: 40,
      height: 40,
              decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String subtitle;
    IconData icon;
    
    switch (_selectedFilter) {
      case 'admin_response':
        message = 'Нет ответов администратора';
        subtitle = 'Здесь будут отображаться ответы\nна ваши заявки и обращения';
        icon = Icons.admin_panel_settings_outlined;
        break;
      case 'news':
        message = 'Нет новостей';
        subtitle = 'Здесь будут появляться важные\nновости и объявления';
        icon = Icons.article_outlined;
        break;
      case 'system':
        message = 'Нет системных уведомлений';
        subtitle = 'Здесь отображаются технические\nуведомления и обновления';
        icon = Icons.settings_outlined;
        break;
      default:
        message = 'Пока нет уведомлений';
        subtitle = 'Здесь будут появляться ответы администратора,\nновости и системные уведомления';
        icon = Icons.notifications_none_outlined;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.colors.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.colors.mediumGray,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: AppTheme.typography.headlineSmall.copyWith(
                color: AppTheme.colors.darkGray,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.colors.mediumGray,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _groupNotificationsByDate(List<NotificationModel> notifications) {
    final Map<String, List<NotificationModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    for (final notification in notifications) {
      final date = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );
      
      String dateKey;
      if (date == today) {
        dateKey = 'Сегодня';
      } else if (date == yesterday) {
        dateKey = 'Вчера';
      } else {
        dateKey = DateFormat('d MMMM', 'ru').format(date);
      }
      
      grouped[dateKey] ??= [];
      grouped[dateKey]!.add(notification);
    }
    
    // Sort groups by date (newest first)
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'Сегодня') return -1;
      if (b == 'Сегодня') return 1;
      if (a == 'Вчера') return -1;
      if (b == 'Вчера') return 1;
      return b.compareTo(a);
    });
    
    return sortedKeys.map((dateKey) => {
      'date': dateKey,
      'notifications': grouped[dateKey]!..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    }).toList();
  }

  List<NotificationModel> _getFilteredNotifications(List<NotificationModel> notifications) {
    switch (_selectedFilter) {
      case 'admin_response':
        return notifications.where((n) => n.type == 'admin_response').toList();
      case 'news':
        return notifications.where((n) => n.type == 'news').toList();
      case 'system':
        return notifications.where((n) => n.type == 'system').toList();
      default:
        return notifications;
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    _loggingService.info('Tapping notification with ID: "${notification.id}"');
    
    // Mark as read with animation feedback
    if (!notification.isRead && notification.id.isNotEmpty) {
      _notificationService.markAsRead(notification.id);
      
      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } else if (notification.id.isEmpty) {
      _loggingService.error('Notification has empty ID!');
    }

    // Navigate to related screen based on notification type
    if (notification.relatedRequestId != null) {
      _loggingService.info('Navigating with type: "${notification.type}", relatedId: "${notification.relatedRequestId}"');
      
      switch (notification.type) {
        case 'news':
          _loggingService.info('Navigating to news: /news/${notification.relatedRequestId}');
          context.go('/news/${notification.relatedRequestId}');
          break;
        case 'admin_response':
        case 'service_update':
        default:
          _loggingService.info('Navigating to service request: /service-request-details');
          context.go('/service-request-details', extra: notification.relatedRequestId);
          break;
      }
    } else {
      _loggingService.info('No relatedRequestId found for notification type: "${notification.type}"');
    }
  }

  void _markAllAsRead() {
    _notificationService.markAllAsRead();
    
    // Provide haptic feedback
    HapticFeedback.mediumImpact();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: AppTheme.colors.pureWhite,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text('Все уведомления прочитаны'),
          ],
        ),
        backgroundColor: AppTheme.colors.charcoal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

