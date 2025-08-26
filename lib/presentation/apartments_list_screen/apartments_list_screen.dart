import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import '../../widgets/frosted_glass_card.dart';

class ApartmentsListScreen extends StatefulWidget {
  const ApartmentsListScreen({super.key});

  @override
  State<ApartmentsListScreen> createState() => _ApartmentsListScreenState();
}

class _ApartmentsListScreenState extends State<ApartmentsListScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _headerSlideAnimation = Tween<double>(
      begin: -30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    ));
    
    _headerAnimationController.forward();
    
    // Автоматически перезагружаем квартиры при открытии экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoRefreshApartments();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: _buildAppBar(),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          final apartments = authService.userApartments;
          final currentApartment = authService.verifiedApartment;

          // Добавляем диагностику
          getIt<LoggingService>().info('🔄 UI rebuild - apartments: ${apartments?.length ?? 0}');
          if (apartments != null) {
            for (var apt in apartments) {
              getIt<LoggingService>().info('   - ${apt.blockId} ${apt.apartmentNumber} (${apt.id})');
            }
          }

          if (apartments == null || apartments.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              _buildHeader(apartments.length),
              Expanded(
                child: _buildApartmentsList(apartments, currentApartment, authService),
              ),
            ],
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
        AppStrings.i18nPlaceholder.isNotEmpty ? 'Мои квартиры' : AppStrings.i18nPlaceholder,
        style: AppTheme.typography.headlineSmall.copyWith(
          fontWeight: FontWeight.bold,
          color: AppTheme.colors.charcoal,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.refresh,
            color: AppTheme.colors.charcoal,
          ),
          onPressed: () => _refreshApartments(),
        ),
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

  Widget _buildHeader(int apartmentCount) {
    return AnimatedBuilder(
      animation: _headerFadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _headerSlideAnimation.value),
          child: Opacity(
            opacity: _headerFadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.secondaryColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          color: AppTheme.pureWhite,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Доступные квартиры',
                              style: AppTheme.typography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.colors.charcoal,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Выберите квартиру для работы',
                              style: AppTheme.typography.bodyMedium.copyWith(
                                color: AppTheme.colors.darkGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$apartmentCount кв.',
                          style: AppTheme.typography.bodySmall.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildApartmentsList(
    List<ApartmentModel> apartments,
    ApartmentModel? currentApartment,
    AuthService authService,
  ) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: apartments.length,
        itemBuilder: (context, index) {
          final apartment = apartments[index];
          final isSelected = currentApartment?.id == apartment.id;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 30.0,
              child: FadeInAnimation(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApartmentCard(
                    apartment: apartment,
                    isSelected: isSelected,
                    onTap: () => _selectApartment(apartment, authService),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.colors.lightGray,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.home_outlined,
                size: 64,
                color: AppTheme.colors.mediumGray,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Квартиры не найдены',
              style: AppTheme.typography.headlineSmall.copyWith(
                color: AppTheme.colors.darkGray,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Обратитесь к администратору для\nдобавления квартир в ваш профиль',
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.colors.mediumGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _selectApartment(ApartmentModel apartment, AuthService authService) {
    HapticFeedback.lightImpact();
    authService.selectApartment(apartment);
    context.go('/dashboard');
  }

  void _autoRefreshApartments() async {
    final authService = getIt<AuthService>();
    final currentApartments = authService.userApartments;
    
    // Если у пользователя только 1 квартира, попробуем найти дополнительные
    if (currentApartments != null && currentApartments.length <= 1) {
      getIt<LoggingService>().info('🔄 Auto-refreshing apartments (current: ${currentApartments.length})');
      
      try {
        await authService.reloadUserApartments();
        
        final newApartments = authService.userApartments;
        if (newApartments != null && newApartments.length > currentApartments.length) {
          getIt<LoggingService>().info('✅ Found additional apartments: ${newApartments.length}');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Найдено ${newApartments.length} квартир'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        getIt<LoggingService>().error('Auto-refresh failed: $e');
      }
    }
  }

  void _refreshApartments() async {
    final authService = getIt<AuthService>();
    
    // Show loading message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Обновление списка квартир...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Use the new reload method
    await authService.reloadUserApartments();
    
    // Show completion message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Список квартир обновлен'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

class _ApartmentCard extends StatefulWidget {
  final ApartmentModel apartment;
  final bool isSelected;
  final VoidCallback onTap;

  const _ApartmentCard({
    required this.apartment,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ApartmentCard> createState() => _ApartmentCardState();
}

class _ApartmentCardState extends State<_ApartmentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _scaleController.forward(),
            onTapUp: (_) {
              _scaleController.reverse();
              widget.onTap();
            },
            onTapCancel: () => _scaleController.reverse(),
            child: FrostedGlassCard(
              borderColor: widget.isSelected 
                  ? AppTheme.primaryColor 
                  : Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: widget.isSelected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.05),
                            AppTheme.secondaryColor.withValues(alpha: 0.02),
                          ],
                        ),
                      )
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: widget.isSelected
                            ? const LinearGradient(
                                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                              )
                            : const LinearGradient(
                                colors: [
                                  AppTheme.lightGray,
                                  AppTheme.neutralGray,
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: widget.isSelected ? AppTheme.shadows.medium : null,
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        color: widget.isSelected
                            ? AppTheme.colors.pureWhite
                            : AppTheme.colors.darkGray,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Квартира ${widget.apartment.apartmentNumber}',
                                  style: AppTheme.typography.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: widget.isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.colors.charcoal,
                                  ),
                                ),
                              ),
                              if (widget.isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Активна',
                                    style: AppTheme.typography.bodySmall.copyWith(
                                      color: AppTheme.colors.pureWhite,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_city_outlined,
                                size: 16,
                                color: AppTheme.colors.mediumGray,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Блок ${widget.apartment.blockId}',
                                  style: AppTheme.typography.bodyMedium.copyWith(
                                    color: AppTheme.colors.darkGray,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.square_foot_outlined,
                                size: 16,
                                color: AppTheme.colors.mediumGray,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${widget.apartment.netAreaM2.toStringAsFixed(0)} м²',
                                  style: AppTheme.typography.bodyMedium.copyWith(
                                    color: AppTheme.colors.darkGray,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      widget.isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
                      color: widget.isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.colors.mediumGray,
                      size: widget.isSelected ? 24 : 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
} 