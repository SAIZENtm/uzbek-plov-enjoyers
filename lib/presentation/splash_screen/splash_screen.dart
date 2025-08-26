
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;

  bool _hasError = false;
  String _errorMessage = '';
  bool _showRetryButton = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeIn,
    ));

    _logoScaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOut,
    ));

    _logoAnimationController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Check connectivity first
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (!mounted) return;

      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Нет подключения к интернету';
          _showRetryButton = true;
        });
        return;
      }

      // Check authentication state using AuthService
      final authService = getIt<AuthService>();
      final isAuthenticated = await authService.checkAuthStatus();

      getIt<LoggingService>().debug('DEBUG: Splash screen - isAuthenticated: $isAuthenticated');

      if (!mounted) return;

      // Check for pending invite
      final prefs = await SharedPreferences.getInstance();
      final pendingInviteId = prefs.getString('pending_invite_id');
      
      if (pendingInviteId != null) {
        // Очищаем ожидающий инвайт
        await prefs.remove('pending_invite_id');
        
        // Проверяем валидность инвайта
        final inviteService = getIt<InviteService>();
        final invite = await inviteService.getInviteById(pendingInviteId);
        
        if (invite != null && invite.canBeUsed) {
          getIt<LoggingService>().info('DEBUG: Splash screen - navigating to invite: $pendingInviteId');
          context.go('/invite/$pendingInviteId');
          return;
        }
      }

      // Add a small delay to show the splash animation
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;

      if (isAuthenticated) {
        getIt<LoggingService>().info('DEBUG: Splash screen - navigating to dashboard');
        context.go('/dashboard');
      } else {
        getIt<LoggingService>().info('DEBUG: Splash screen - navigating to authentication');
        context.go('/auth');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _showRetryButton = true;
      });
    }
  }

  void _retryInitialization() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _showRetryButton = false;
    });
    _initializeApp();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.lightTheme.colorScheme.primary,
              AppTheme.lightTheme.colorScheme.primaryContainer,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _logoAnimationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _logoFadeAnimation,
                        child: ScaleTransition(
                          scale: _logoScaleAnimation,
                          child: SvgPicture.asset(
                            'assets/images/img_app_logo.svg',
                            width: 35.w,
                            height: 35.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_hasError) ...[
                Text(
                  _errorMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_showRetryButton)
                  TextButton(
                    onPressed: _retryInitialization,
                    child: Text(
                      'Повторить',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }
}
