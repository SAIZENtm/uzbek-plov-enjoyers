import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/models/news_article_model.dart';
import '../../widgets/premium_card.dart';
import '../../widgets/connection_indicator.dart';

final getIt = GetIt.instance;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _residentData;
  bool _isLoading = true;
  late final NewsService _newsService;
  late final NotificationService _notificationService;
  late final UnreadTracker _unreadTracker;
  List<NewsArticle> _newsArticles = [];

  @override
  void initState() {
    super.initState();
    _newsService = getIt<NewsService>();
    _notificationService = getIt<NotificationService>();
    _unreadTracker = getIt<UnreadTracker>();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final authService = getIt<AuthService>();
    if (!authService.isAuthenticated || authService.userData == null) {
      if (mounted) {
        context.go('/auth');
      }
      return;
    }

    final userData = authService.userData!;
    final fullName = userData['fullName'] as String? ?? 'Пользователь';
    // Extract first name only for cleaner greeting
    final firstName = fullName.split(' ').first;
    
    // Get selected apartment or use default from userData
    final selectedApartment = authService.verifiedApartment;
    final apartmentNumber = selectedApartment?.apartmentNumber ?? 
                           userData['apartmentNumber'] as String? ?? 
                           'Не указан';
    final blockId = selectedApartment?.blockId ?? 
                   userData['blockId'] as String? ?? 
                   '';
    
    final debtStr = userData['debt'] as String? ?? '0';

    setState(() {
      _residentData = {
        "firstName": firstName,
        "fullName": fullName,
        "apartment": apartmentNumber,
        "blockId": blockId,
        "balance": _parseDebtAmount(debtStr),
      };
      _isLoading = false;
    });

    _loadNews();
  }

  Future<void> _loadNews() async {
    try {
      final articles = await _newsService.fetchLatestNews();
      if (mounted) {
        setState(() {
          _newsArticles = articles.take(3).toList(); // Show only 3 latest for preview
        });
        await _unreadTracker.updateUnreadCount(articles);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _newsArticles = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Не удалось загрузить новости. Проверьте подключение к интернету.'),
            backgroundColor: AppTheme.warningAmber,
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _loadNews,
            ),
          ),
        );
      }
    }
  }

  int _parseDebtAmount(String debt) {
    final lower = debt.toLowerCase();
    if (lower.contains('нет') || lower.contains('100')) return 0;
    final cleaned = debt.replaceAll(RegExp(r'[^0-9-]'), '');
    if (cleaned.isEmpty) return 0;
    int amount = int.tryParse(cleaned.replaceAll('-', '')) ?? 0;
    if (amount < 1000 && debt.contains('.')) amount *= 1000;
    return cleaned.startsWith('-') ? -amount : amount;
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait([
        _loadAllData(),
        Future.delayed(const Duration(seconds: 1)),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка при обновлении данных'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(child: _buildDashboardContent()),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.newportPrimary,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppTheme.newportPrimary,
      child: AnimationLimiter(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 400),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              _buildPremiumHeader(),
              const SizedBox(height: 24),
              _buildBalanceStatusCard(),
              const SizedBox(height: 32),
              _buildQuickActions(),
              const SizedBox(height: 32),
              _buildNewsPreview(),
              const SizedBox(height: 100), // Bottom padding for tab bar
            ],
          ),
        ),
      ),
    );
  }

  /// Premium minimalist header with clean greeting
  Widget _buildPremiumHeader() {
    final authService = getIt<AuthService>();
    final hasMultipleApartments = (authService.userApartments?.length ?? 0) > 1;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTimeBasedGreeting(),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.mediumGray,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _residentData!['firstName'],
                  style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: hasMultipleApartments ? () => context.go('/apartments') : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _residentData!['blockId'].toString().isNotEmpty 
                            ? '${_residentData!['blockId']} • Квартира ${_residentData!['apartment']}'
                            : 'Квартира ${_residentData!['apartment']}',
                        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mediumGray,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      if (hasMultipleApartments) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more,
                          size: 16,
                          color: AppTheme.mediumGray,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildNotificationIcon(),
        ],
      ),
    );
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'Доброй ночи!';
    if (hour < 12) return 'Доброе утро!';
    if (hour < 17) return 'Добрый день!';
    if (hour < 22) return 'Добрый вечер!';
    return 'Доброй ночи!';
  }

  /// Clean balance status card
  Widget _buildBalanceStatusCard() {
    final balance = _residentData!['balance'] as int;
    
    return PremiumCard(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getBalanceStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getBalanceStatusIcon(),
                  color: _getBalanceStatusColor(),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getBalanceStatusText(),
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.darkGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (balance != 0)
                      Text(
                        '${balance.abs().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} сум',
                        style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                          color: _getBalanceStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (balance != 0)
                PremiumButton(
                  text: 'Оплатить',
                  onPressed: () => context.go('/payment'),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBalanceStatusColor() {
    final balance = _residentData!['balance'] as int;
    if (balance > 0) return AppTheme.successGreen;
    if (balance < 0) return AppTheme.errorRed;
    return AppTheme.successGreen;
  }

  IconData _getBalanceStatusIcon() {
    final balance = _residentData!['balance'] as int;
    if (balance > 0) return Icons.trending_up_outlined;
    if (balance < 0) return Icons.receipt_long_outlined;
    return Icons.check_circle_outline;
  }

  String _getBalanceStatusText() {
    final balance = _residentData!['balance'] as int;
    if (balance > 0) return 'Переплата';
    if (balance < 0) return 'К оплате';
    return 'Все счета оплачены 👍';
  }

  /// Large, clear quick action tiles - Apple style
  Widget _buildQuickActions() {
    final authService = getIt<AuthService>();
    final userApartments = authService.userApartments;
    final apartmentCount = userApartments?.length ?? 0;
    
    final actions = [
      const _QuickAction(
        id: 'new_request',
        title: 'Новая заявка',
        subtitle: 'Ремонт и обслуживание',
        icon: Icons.build_outlined,
        color: AppTheme.newportPrimary,
      ),
      const _QuickAction(
        id: 'my_requests',
        title: 'Мои заявки',
        subtitle: 'Статус и история',
        icon: Icons.list_alt_outlined,
        color: AppTheme.infoBlue,
      ),
      _QuickAction(
        id: 'my_apartments',
        title: 'Мои квартиры',
        subtitle: apartmentCount > 1 ? '$apartmentCount квартир' : (apartmentCount == 1 ? '1 квартира' : 'Управление'),
        icon: Icons.home_outlined,
        color: Colors.purple.shade600,
      ),
      const _QuickAction(
        id: 'utility_readings',
        title: 'Показания счётчиков',
        subtitle: 'Передать показания',
        icon: Icons.speed_outlined,
        color: AppTheme.successGreen,
      ),
      const _QuickAction(
        id: 'guest_access',
        title: 'Пропуск гостю',
        subtitle: 'Оформить доступ',
        icon: Icons.person_add_alt_1_outlined,
        color: AppTheme.warningAmber,
      ),
      const _QuickAction(
        id: 'smart_home',
        title: '🏠 Умный дом',
        subtitle: 'Управление устройствами',
        icon: Icons.home_outlined,
        color: Color(0xFF5856D6),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Быстрые действия',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.charcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2, // Немного уменьшил для лучшего размещения текста
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _QuickActionTile(
              action: action,
              onTap: () => _handleQuickAction(action.id),
            );
          },
        ),
      ],
    );
  }

  /// Inline news preview - cleaner than separate section
  Widget _buildNewsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Новости сообщества',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _unreadTracker,
                    builder: (context, child) {
                      final unreadCount = _unreadTracker.unreadCount;
                      if (unreadCount > 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.errorRed,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: AppTheme.pureWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  TextButton(
                    onPressed: () => context.go('/news'),
                    child: const Text(
                      'Все новости',
                      style: TextStyle(
                        color: AppTheme.newportPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_newsArticles.isEmpty)
          PremiumCard(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 48,
                  color: AppTheme.mediumGray,
                ),
                const SizedBox(height: 12),
                Text(
                  'Новостей пока нет',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Актуальные объявления появятся здесь',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _newsArticles.length,
            itemBuilder: (context, index) {
              final article = _newsArticles[index];
              return _NewsPreviewItem(
                article: article,
                onTap: () => context.go('/news/${article.id}'),
              );
            },
          ),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return StreamBuilder<List<dynamic>>(
      stream: _notificationService.notificationsStream,
      builder: (context, snapshot) {
        final unreadCount = _notificationService.unreadCount;
        final hasError = snapshot.hasError;

        return GestureDetector(
          onTap: () => context.go('/notifications'),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.pureWhite,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Stack(
              children: [
                Icon(
                  hasError ? Icons.notifications_off : Icons.notifications_none,
                  color: hasError ? AppTheme.mediumGray : AppTheme.newportPrimary,
                  size: 24,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: AppTheme.pureWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleQuickAction(String actionId) {
    switch (actionId) {
      case 'new_request':
        context.go('/services/new-request');
        break;
      case 'my_requests':
        context.go('/services/my-requests');
        break;
      case 'my_apartments':
        context.go('/apartments');
        break;
      case 'utility_readings':
        context.go('/utility-readings');
        break;
      case 'guest_access':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оформление пропуска для гостей'),
            backgroundColor: AppTheme.infoBlue,
          ),
        );
        break;
      case 'smart_home':
        context.go('/smart-home');
        break;
    }
  }
}

/// Data class for quick actions
class _QuickAction {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _QuickAction({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

/// Premium quick action tile widget
class _QuickActionTile extends StatefulWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.action,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

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
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) {
        _animationController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.pureWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neutralGray, width: 0.5),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.action.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.action.icon,
                        color: widget.action.color,
                        size: 24,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.action.title,
                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.action.subtitle,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// News preview item widget
class _NewsPreviewItem extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;

  const _NewsPreviewItem({
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      onTap: onTap,
      child: Row(
        children: [
          if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                article.imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: AppTheme.mediumGray,
                      size: 24,
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.article_outlined,
                color: AppTheme.mediumGray,
                size: 24,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article.title,
                  style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.charcoal,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                                 Text(
                   article.preview.isNotEmpty ? article.preview : article.content.substring(0, article.content.length > 100 ? 100 : article.content.length),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(article.createdAt),
                  style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.mediumGray,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Сегодня';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
