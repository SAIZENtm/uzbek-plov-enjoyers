import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quickServices = [
      _ServiceItem(
        icon: Icons.build_outlined,
        title: 'Подать заявку',
        subtitle: 'Ремонт и обслуживание',
        color: AppTheme.newportPrimary,
        onTap: () => context.go('/services/new-request'),
        isPopular: false,
      ),
      _ServiceItem(
        icon: Icons.list_alt_outlined,
        title: 'Мои заявки',
        subtitle: 'Статус и история',
        color: AppTheme.infoBlue,
        onTap: () => context.go('/services/my-requests'),
        badgeCount: 2, // Example badge
      ),
      _ServiceItem(
        icon: Icons.speed_outlined,
        title: 'Счетчики',
        subtitle: 'Передать показания',
        color: AppTheme.successGreen,
        onTap: () => context.go('/utility-readings'),
      ),
      _ServiceItem(
        icon: Icons.receipt_long_outlined,
        title: 'Оплатить',
        subtitle: 'Счета и услуги',
        color: AppTheme.warningAmber,
        onTap: () => context.go('/payment'),
      ),
    ];

    final bookingServices = [
      _ServiceItem(
        icon: Icons.fitness_center_outlined,
        title: 'Спортзал',
        subtitle: 'Забронировать время',
        color: AppTheme.newportSecondary,
        onTap: () => _showComingSoon(context, 'Бронирование спортзала'),
      ),
      _ServiceItem(
        icon: Icons.meeting_room_outlined,
        title: 'Конференц-зал',
        subtitle: 'Зал для встреч',
        color: Colors.deepPurple,
        onTap: () => _showComingSoon(context, 'Бронирование конференц-зала'),
      ),
      _ServiceItem(
        icon: Icons.local_parking_outlined,
        title: 'Парковка',
        subtitle: 'Зарезервировать место',
        color: Colors.teal,
        onTap: () => _showComingSoon(context, 'Бронирование парковки'),
      ),
    ];

    final additionalServices = [
      _ServiceItem(
        icon: Icons.cleaning_services_outlined,
        title: 'Клининг',
        subtitle: 'Заказать уборку',
        color: Colors.cyan,
        onTap: () => _showComingSoon(context, 'Заказ клининга'),
      ),
      _ServiceItem(
        icon: Icons.badge_outlined,
        title: 'Гостевой пропуск',
        subtitle: 'Оформить доступ',
        color: Colors.orange,
        onTap: () => _showComingSoon(context, 'Оформление пропуска'),
      ),
      _ServiceItem(
        icon: Icons.local_cafe_outlined,
        title: 'Кафе и рестораны',
        subtitle: 'Скидки для жителей',
        color: Colors.brown,
        onTap: () => _showComingSoon(context, 'Партнерские предложения'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Сервисы Newport',
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        centerTitle: false,
      ),
      body: AnimationLimiter(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 375),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(child: widget),
            ),
            children: [
              _buildQuickServicesSection(quickServices),
              const SizedBox(height: 32),
              _buildBookingSection(bookingServices),
              const SizedBox(height: 32),
              _buildAdditionalServicesSection(additionalServices),
              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: _buildNewRequestFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildQuickServicesSection(List<_ServiceItem> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.newportPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.flash_on_outlined,
                color: AppTheme.newportPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Быстрые действия',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
            childAspectRatio: 1.3, // Как в главном экране
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            return _ServiceTile(service: services[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBookingSection(List<_ServiceItem> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: AppTheme.successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Бронирование',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
            childAspectRatio: 1.3, // Как в главном экране
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            return _ServiceTile(service: services[index], isCompact: false);
          },
        ),
      ],
    );
  }

  Widget _buildAdditionalServicesSection(List<_ServiceItem> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.more_horiz_outlined,
                color: AppTheme.infoBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Дополнительные услуги',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
            childAspectRatio: 1.3, // Как в главном экране
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            return _ServiceTile(service: services[index], isCompact: false);
          },
        ),
      ],
    );
  }

  Widget _buildNewRequestFAB(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.floatingShadow,
      ),
      child: FloatingActionButton.extended(
                    onPressed: () => context.go('/services/new-request'),
        backgroundColor: AppTheme.newportPrimary,
        foregroundColor: AppTheme.pureWhite,
        elevation: 0,
        icon: const Icon(Icons.add, size: 24),
        label: Text(
          'Новая заявка',
          style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
            color: AppTheme.pureWhite,
            fontWeight: FontWeight.w600,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature скоро будет доступен'),
        backgroundColor: AppTheme.infoBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool isPopular;
  final int? badgeCount;

  _ServiceItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.isPopular = false,
    this.badgeCount,
  });
}

class _ServiceTile extends StatefulWidget {
  final _ServiceItem service;
  final bool isCompact;

  const _ServiceTile({
    required this.service,
    this.isCompact = false,
  });

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile>
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
        widget.service.onTap();
      },
      onTapCancel: () => _animationController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                Container(
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
                            color: widget.service.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.service.icon,
                            color: widget.service.color,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.service.title,
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.service.subtitle,
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
                
                // Popular badge
                if (widget.service.isPopular)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.newportPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Популярное',
                        style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.pureWhite,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                
                // Badge count
                if (widget.service.badgeCount != null && widget.service.badgeCount! > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorRed,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Text(
                        widget.service.badgeCount! > 99 
                            ? '99+' 
                            : widget.service.badgeCount.toString(),
                        style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
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
          );
        },
      ),
    );
  }
} 