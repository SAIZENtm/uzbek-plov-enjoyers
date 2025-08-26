import 'package:go_router/go_router.dart';
import '../core/app_export.dart';

/// Premium shell widget that provides the main navigation structure
class PremiumMainShell extends StatelessWidget {
  final Widget child;

  const PremiumMainShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final location = GoRouterState.of(context).uri.toString();
        
        // Если мы на главной странице, показываем диалог выхода
        if (location == '/dashboard') {
          final shouldExit = await _showExitDialog(context);
          if (shouldExit) {
            // Выходим из приложения
            SystemNavigator.pop();
          }
        } else {
          // Если не на главной странице, переходим на главную
          context.go('/dashboard');
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: _buildBottomNavigationBar(context),
      ),
    );
  }

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.exit_to_app,
                color: AppTheme.newportPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Выход из приложения',
                style: AppTheme.lightTheme.textTheme.titleLarge,
              ),
            ],
          ),
          content: Text(
            'Вы действительно хотите выйти из приложения?',
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.newportPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 70, // Фиксированная высота
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildNavItem(
                context,
                icon: Icons.home_rounded,
                label: 'Главная',
                path: '/dashboard',
                isActive: location == '/dashboard',
              )),
              Expanded(child: _buildNavItem(
                context,
                icon: Icons.newspaper_rounded,
                label: 'Новости',
                path: '/news',
                isActive: location.startsWith('/news'),
              )),
              Expanded(child: _buildNavItem(
                context,
                icon: Icons.build_rounded,
                label: 'Услуги',
                path: '/services',
                isActive: location.startsWith('/services'),
              )),
              Expanded(child: _buildNavItem(
                context,
                icon: Icons.person_rounded,
                label: 'Профиль',
                path: '/profile',
                isActive: location.startsWith('/profile'),
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => context.go(path),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive 
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive 
                  ? AppTheme.primaryColor
                  : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive 
                    ? AppTheme.primaryColor
                    : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
} 