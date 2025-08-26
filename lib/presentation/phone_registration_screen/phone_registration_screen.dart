
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/app_export.dart';

import '../../widgets/blue_button.dart';
import '../../widgets/blue_text_field.dart';
import '../../widgets/card_container.dart';
import '../../core/di/service_locator.dart';

class PhoneRegistrationScreen extends StatefulWidget {
  final String? requestId; // ID семейного запроса для завершения

  const PhoneRegistrationScreen({
    super.key,
    this.requestId,
  });

  @override
  State<PhoneRegistrationScreen> createState() => _PhoneRegistrationScreenState();
}

class _PhoneRegistrationScreenState extends State<PhoneRegistrationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _codeFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _isLoading = false;
  bool _showCodeField = false;
  String? _phoneError;
  String? _codeError;
  String? _verificationId;
  int _resendTimer = 0;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startResendTimer();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendTimer--;
        });
        return _resendTimer > 0;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocusNode.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _phoneError = null;
      _codeError = null;
    });
  }

  bool _validatePhone() {
    _clearErrors();
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      setState(() {
        _phoneError = 'Введите номер телефона';
      });
      return false;
    }
    
    if (!phone.startsWith('+7') || phone.length != 12) {
      setState(() {
        _phoneError = 'Формат: +7XXXXXXXXXX';
      });
      return false;
    }
    
    return true;
  }

  bool _validateCode() {
    _clearErrors();
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      setState(() {
        _codeError = 'Введите код подтверждения';
      });
      return false;
    }
    
    if (code.length != 6) {
      setState(() {
        _codeError = 'Код должен содержать 6 цифр';
      });
      return false;
    }
    
    return true;
  }

  Future<void> _sendVerificationCode() async {
    if (!_validatePhone() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Автоматическая верификация (Android)
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _phoneError = _getErrorMessage(e.code);
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _showCodeField = true;
          });
          _startResendTimer();
          
          // Переводим фокус на поле кода
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _codeFocusNode.requestFocus();
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      setState(() {
        _phoneError = 'Ошибка отправки SMS. Попробуйте позже.';
      });
      getIt<LoggingService>().error('Error sending verification code', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!_validateCode() || _isLoading || _verificationId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      
      await _signInWithCredential(credential);
    } catch (e) {
      setState(() {
        _codeError = 'Неверный код подтверждения';
      });
      getIt<LoggingService>().error('Error verifying code', e);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (!mounted) return;

      if (userCredential.user != null) {
        // Завершаем регистрацию члена семьи
        await _completeRegistration(userCredential.user!);
      }
    } catch (e) {
      setState(() {
        _codeError = 'Ошибка подтверждения. Попробуйте позже.';
      });
      getIt<LoggingService>().error('Error signing in with credential', e);
    }
  }

  Future<void> _completeRegistration(User user) async {
    try {
      if (widget.requestId != null) {
        // Завершаем семейный запрос
        final familyRequestService = getIt<FamilyRequestService>();
        await familyRequestService.completeFamilyRegistration(
          requestId: widget.requestId!,
          userId: user.uid,
          phoneNumber: _phoneController.text.trim(),
        );
      }

      // Показываем успешное сообщение
      _showSuccessDialog();
    } catch (e) {
      _showErrorMessage('Не удалось завершить регистрацию. Попробуйте позже.');
      getIt<LoggingService>().error('Error completing registration', e);
    }
  }

  String _getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-phone-number':
        return 'Неверный формат номера телефона';
      case 'too-many-requests':
        return 'Слишком много запросов. Попробуйте позже';
      case 'quota-exceeded':
        return 'Превышен лимит отправки SMS';
      default:
        return 'Ошибка отправки SMS';
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Регистрация завершена'),
          ],
        ),
        content: const Text(
          'Вы успешно зарегистрированы как член семьи! '
          'Теперь у вас есть доступ к данным квартиры.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/dashboard');
            },
            child: const Text('Войти в приложение'),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Подтверждение телефона'),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        foregroundColor: AppTheme.charcoal,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildPhoneForm(),
                if (_showCodeField) ...[
                  const SizedBox(height: 24),
                  _buildCodeForm(),
                ],
                const SizedBox(height: 32),
                _buildActionButton(),
                if (_showCodeField) ...[
                  const SizedBox(height: 16),
                  _buildResendButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return CardContainer(
      child: Column(
        children: [
          const Icon(
            Icons.phone_android,
            size: 64,
            color: AppTheme.newportPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Завершение регистрации',
            style: AppTheme.typography.headlineMedium.copyWith(
              color: AppTheme.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _showCodeField 
                ? 'Введите код подтверждения из SMS'
                : 'Введите номер телефона для подтверждения',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm() {
    return CardContainer(
      child: BlueTextField(
        controller: _phoneController,
        focusNode: _phoneFocusNode,
        labelText: 'Номер телефона',
        hintText: '+7XXXXXXXXXX',
        validator: (_) => _phoneError,
        prefixIcon: const Icon(Icons.phone),
        keyboardType: TextInputType.phone,
        enabled: !_showCodeField,
        onFieldSubmitted: (_) => _sendVerificationCode(),
        inputFormatters: [
          LengthLimitingTextInputFormatter(12),
          FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
        ],
      ),
    );
  }

  Widget _buildCodeForm() {
    return CardContainer(
      child: BlueTextField(
        controller: _codeController,
        focusNode: _codeFocusNode,
        labelText: 'Код подтверждения',
        hintText: '123456',
        validator: (_) => _codeError,
        prefixIcon: const Icon(Icons.sms),
        keyboardType: TextInputType.number,
        onFieldSubmitted: (_) => _verifyCode(),
        inputFormatters: [
          LengthLimitingTextInputFormatter(6),
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    return BlueButton(
      text: _showCodeField ? 'Подтвердить код' : 'Отправить код',
      isLoading: _isLoading,
      onPressed: _isLoading 
          ? null 
          : (_showCodeField ? _verifyCode : _sendVerificationCode),
    );
  }

  Widget _buildResendButton() {
    return TextButton(
      onPressed: _resendTimer == 0 && !_isLoading ? _sendVerificationCode : null,
      child: Text(
        _resendTimer > 0 
            ? 'Отправить повторно через $_resendTimer сек'
            : 'Отправить код повторно',
        style: TextStyle(
          color: _resendTimer == 0 ? AppTheme.newportPrimary : AppTheme.mediumGray,
        ),
      ),
    );
  }
} 
