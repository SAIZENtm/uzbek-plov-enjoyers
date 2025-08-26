import 'package:provider/provider.dart';

import '../../core/app_export.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/service_locator.dart';
import '../../widgets/premium_card.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _smsController = TextEditingController();
  final FocusNode _apartmentFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _smsFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  String? _apartmentError;
  String? _phoneError;
  String? _smsError;
  bool _isFormValid = false;
  bool _showSmsField = false;

  @override
  void initState() {
    super.initState();
    _apartmentController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _apartmentController.dispose();
    _phoneController.dispose();
    _smsController.dispose();
    _apartmentFocusNode.dispose();
    _phoneFocusNode.dispose();
    _smsFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final apartmentText = _apartmentController.text.trim();
    final phoneText = _phoneController.text.trim();

    String? apartmentError;
    if (apartmentText.isEmpty) {
      apartmentError = 'Введите номер квартиры';
    }

    String? phoneError;
    if (phoneText.isEmpty) {
      phoneError = 'Введите номер телефона';
    } else if (!phoneText.startsWith('+998')) {
      phoneError = 'Номер должен начинаться с +998';
    }

    setState(() {
      _apartmentError = apartmentError;
      _phoneError = phoneError;
      _isFormValid = apartmentError == null && phoneError == null;
    });

    if (apartmentError != null || phoneError != null) {
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _verifyAndSendSMS() async {
    if (!_isFormValid || _isLoading) return;
    
    setState(() { 
      _isLoading = true; 
      _apartmentError = null; 
      _phoneError = null;
      _smsError = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apartmentNumber = _apartmentController.text.trim();
      final phoneNumber = _phoneController.text.trim();
      
      getIt<LoggingService>().debug('DEBUG: Apartment input: "$apartmentNumber"');
      getIt<LoggingService>().debug('DEBUG: Phone input: "$phoneNumber"');
      
      final isValid = await authService.checkUserData(
        apartmentNumber: apartmentNumber,
        phoneNumber: phoneNumber,
      );

      if (!mounted) return;

      if (isValid) {
        final smsSent = await authService.sendVerificationSMS(phoneNumber);
        
        if (!mounted) return;
        
        if (smsSent) {
          setState(() {
            _showSmsField = true;
          });
          // Delay focus to allow animation
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            FocusScope.of(context).requestFocus(_smsFocusNode);
          }
        } else {
          setState(() {
            _phoneError = 'Не удалось отправить SMS. Попробуйте позже.';
          });
        }
      } else {
        setState(() {
          _apartmentError = 'Проверьте правильность введенных данных';
        });
      }
    } catch (e) {
      getIt<LoggingService>().error('DEBUG: Error in _verifyAndSendSMS: $e');
      setState(() {
        _apartmentError = 'Произошла ошибка. Попробуйте позже.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifySmsCode() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _smsError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final smsCode = _smsController.text.trim();
      
      final verified = await authService.verifySMSCode(smsCode);
      
      if (!mounted) return;

      if (verified) {
        getIt<LoggingService>().info('DEBUG: SMS verification successful, navigating immediately...');
        
        // Немедленно переходим к дашборду для быстрого входа
        context.go('/dashboard');
        
        // Проверяем количество квартир в фоне и перенаправляем при необходимости
        _checkApartmentsInBackground(authService);
      } else {
        setState(() {
          _smsError = 'Неверный код подтверждения';
        });
      }
    } catch (e) {
      setState(() {
        _smsError = 'Ошибка проверки кода. Попробуйте позже.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Проверка количества квартир в фоне
  void _checkApartmentsInBackground(AuthService authService) async {
    try {
      // Ждем немного для загрузки данных в фоне
      await Future.delayed(const Duration(milliseconds: 500));
      
      final apartments = authService.userApartments;
      
      // Перенаправляем на список квартир для всех пользователей
      if (apartments != null && apartments.isNotEmpty && mounted) {
        getIt<LoggingService>().info('DEBUG: User has ${apartments.length} apartments, redirecting to list...');
        context.go('/apartments');
      }
    } catch (e) {
      getIt<LoggingService>().info('Background apartment check failed: $e');
      // Игнорируем ошибку, пользователь остается на дашборде
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.offWhite,
              AppTheme.lightGray,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    _buildPremiumLogo(),
                    const SizedBox(height: 48),
                    _buildWelcomeText(),
                    const SizedBox(height: 40),
                    _buildLoginForm(),
                    const SizedBox(height: 32),
                    _buildActionButton(),
                    if (_showSmsField) ...[
                      const SizedBox(height: 24),
                      _buildSmsVerificationTip(),
                    ],
                    const SizedBox(height: 24),
                    _buildFamilyMemberButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Premium Newport logo with sophisticated styling
  Widget _buildPremiumLogo() {
    return Hero(
      tag: 'newport_logo',
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.newportPrimary,
              AppTheme.newportSecondary,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppTheme.newportPrimary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
              color: AppTheme.pureWhite,
              size: 40,
            ),
            SizedBox(height: 8),
            Text(
              'Newport',
              style: TextStyle(
                color: AppTheme.pureWhite,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                fontFamily: 'Aeroport',
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Friendly welcome message
  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Добро пожаловать домой!',
          style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
            color: AppTheme.charcoal,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Войдите, чтобы воспользоваться\nсервисами вашего дома',
          style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
            color: AppTheme.mediumGray,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Clean login form with premium styling
  Widget _buildLoginForm() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Данные для входа',
            style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
              color: AppTheme.charcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          PremiumTextField(
            label: 'Номер квартиры',
            hint: 'Например: 102',
            controller: _apartmentController,
            prefixIcon: Icons.home_outlined,
            keyboardType: TextInputType.text,
            validator: (_) => _apartmentError,
            onChanged: (_) => _validateForm(),
          ),
          const SizedBox(height: 20),
          PremiumTextField(
            label: 'Номер телефона',
            hint: '+998 90 123 45 67',
            controller: _phoneController,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (_) => _phoneError,
            onChanged: (_) => _validateForm(),
          ),
          if (_showSmsField) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppTheme.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SMS отправлен на ${_phoneController.text}',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PremiumTextField(
              label: 'Код подтверждения',
              hint: '123456',
              controller: _smsController,
              focusNode: _smsFocusNode,
              prefixIcon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
              validator: (_) => _smsError,
              maxLines: 1,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.infoBlue.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.developer_mode,
                      color: AppTheme.infoBlue,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Тестовый режим: введите 123456',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.infoBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Premium action button
  Widget _buildActionButton() {
    return PremiumButton(
      text: _showSmsField ? 'Подтвердить код' : 'Войти в Newport',
      icon: _showSmsField ? Icons.verified_user : Icons.login,
      onPressed: _isFormValid 
          ? (_showSmsField ? _verifySmsCode : _verifyAndSendSMS)
          : null,
      isLoading: _isLoading,
    );
  }

  /// Helpful SMS verification tip
  Widget _buildSmsVerificationTip() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      backgroundColor: AppTheme.lightGray,
      showBorder: false,
      child: Column(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.mediumGray,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            'Не получили SMS?',
            style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
              color: AppTheme.darkGray,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Проверьте правильность номера телефона.\nСМС может прийти в течение 2-3 минут.',
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mediumGray,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showSmsField = false;
                _smsController.clear();
                _smsError = null;
              });
                             FocusScope.of(context).requestFocus(_phoneFocusNode);
            },
            child: const Text(
              'Изменить номер',
              style: TextStyle(
                color: AppTheme.newportPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMemberButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.newportPrimary.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
              child: TextButton(
        onPressed: () {
          context.go('/family-request');
        },
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.newportPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.family_restroom,
              size: 20,
              color: AppTheme.newportPrimary,
            ),
            SizedBox(width: 8),
            Text(
              'Я член семьи',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.newportPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}