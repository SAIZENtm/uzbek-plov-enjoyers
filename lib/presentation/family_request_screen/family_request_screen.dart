
import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/models/family_member_model.dart';
import '../../widgets/blue_button.dart';
import '../../widgets/blue_text_field.dart';
import '../../widgets/card_container.dart';
import '../../core/di/service_locator.dart';

class FamilyRequestScreen extends StatefulWidget {
  const FamilyRequestScreen({super.key});

  @override
  State<FamilyRequestScreen> createState() => _FamilyRequestScreenState();
}

class _FamilyRequestScreenState extends State<FamilyRequestScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _applicantPhoneController = TextEditingController(); // Телефон заявителя
  final TextEditingController _ownerPhoneController = TextEditingController(); // Телефон владельца
  final TextEditingController _blockController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _applicantPhoneFocusNode = FocusNode();
  final FocusNode _ownerPhoneFocusNode = FocusNode();
  final FocusNode _blockFocusNode = FocusNode();
  final FocusNode _apartmentFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _selectedRole;
  bool _isLoading = false;
  String? _nameError;
  String? _applicantPhoneError;
  String? _ownerPhoneError;
  String? _blockError;
  String? _apartmentError;
  String? _roleError;

  final List<String> _availableBlocks = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
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

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _applicantPhoneController.dispose();
    _ownerPhoneController.dispose();
    _blockController.dispose();
    _apartmentController.dispose();
    _nameFocusNode.dispose();
    _applicantPhoneFocusNode.dispose();
    _ownerPhoneFocusNode.dispose();
    _blockFocusNode.dispose();
    _apartmentFocusNode.dispose();
    super.dispose();
  }

  void _clearErrors() {
    setState(() {
      _nameError = null;
      _applicantPhoneError = null;
      _ownerPhoneError = null;
      _blockError = null;
      _apartmentError = null;
      _roleError = null;
    });
  }

  bool _validateForm() {
    _clearErrors();
    bool isValid = true;

    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _nameError = 'Введите ваше имя';
      });
      isValid = false;
    }

    if (_applicantPhoneController.text.trim().isEmpty) {
      setState(() {
        _applicantPhoneError = 'Введите ваш телефон';
      });
      isValid = false;
    } else if (!_applicantPhoneController.text.trim().startsWith('+998')) {
      setState(() {
        _applicantPhoneError = 'Номер должен начинаться с +998';
      });
      isValid = false;
    } else if (_applicantPhoneController.text.trim().length < 13) {
      setState(() {
        _applicantPhoneError = 'Введите полный номер телефона';
      });
      isValid = false;
    }

    if (_ownerPhoneController.text.trim().isEmpty) {
      setState(() {
        _ownerPhoneError = 'Введите телефон владельца квартиры';
      });
      isValid = false;
    } else if (!_ownerPhoneController.text.trim().startsWith('+998')) {
      setState(() {
        _ownerPhoneError = 'Номер должен начинаться с +998';
      });
      isValid = false;
    } else if (_ownerPhoneController.text.trim().length < 13) {
      setState(() {
        _ownerPhoneError = 'Введите полный номер телефона владельца';
      });
      isValid = false;
    }

    if (_selectedRole == null) {
      setState(() {
        _roleError = 'Выберите вашу роль в семье';
      });
      isValid = false;
    }

    if (_blockController.text.trim().isEmpty) {
      setState(() {
        _blockError = 'Выберите блок';
      });
      isValid = false;
    }

    if (_apartmentController.text.trim().isEmpty) {
      setState(() {
        _apartmentError = 'Введите номер квартиры';
      });
      isValid = false;
    }

    return isValid;
  }

  Future<void> _submitRequest() async {
    if (!_validateForm() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final familyRequestService = getIt<FamilyRequestService>();
      
      final success = await familyRequestService.submitFamilyRequest(
        name: _nameController.text.trim(),
        role: _selectedRole!,
        blockId: _blockController.text.trim(),
        apartmentNumber: _apartmentController.text.trim(),
        ownerPhone: _ownerPhoneController.text.trim(),
        applicantPhone: _applicantPhoneController.text.trim(), // Добавляем телефон заявителя
      );

      if (!mounted) return;

      if (success) {
        // Показываем успешное сообщение
        _showSuccessDialog();
      } else {
        _showErrorMessage('Квартира не найдена или не активирована');
      }
    } catch (e) {
      getIt<LoggingService>().error('Failed to submit family request', e);
      _showErrorMessage('Произошла ошибка. Попробуйте позже.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            Text('Запрос отправлен'),
          ],
        ),
        content: const Text(
          'Ваш запрос на присоединение к семье отправлен владельцу квартиры. '
          'Вы получите уведомление о решении.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/');
            },
            child: const Text('Понятно'),
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
        title: const Text('Присоединиться к семье'),
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
                _buildRequestForm(),
                const SizedBox(height: 32),
                _buildSubmitButton(),
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
            Icons.family_restroom,
            size: 64,
            color: AppTheme.newportPrimary,
          ),
          const SizedBox(height: 16),
          Text(
            'Присоединение к семье',
            style: AppTheme.typography.headlineMedium.copyWith(
              color: AppTheme.charcoal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Заполните форму, чтобы отправить запрос владельцу квартиры.\nУкажите телефон владельца для точного поиска квартиры.',
            style: AppTheme.typography.bodyMedium.copyWith(
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm() {
    return CardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Имя
          BlueTextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            labelText: 'Ваше имя',
            hintText: 'Введите ваше полное имя',
            validator: (_) => _nameError,
            prefixIcon: const Icon(Icons.person),
            onFieldSubmitted: (_) => _applicantPhoneFocusNode.requestFocus(),
          ),
          const SizedBox(height: 16),

          // Телефон заявителя
          BlueTextField(
            controller: _applicantPhoneController,
            focusNode: _applicantPhoneFocusNode,
            labelText: 'Ваш телефон',
            hintText: '+998 90 123 45 67',
            keyboardType: TextInputType.phone,
            validator: (_) => _applicantPhoneError,
            prefixIcon: const Icon(Icons.phone),
            onFieldSubmitted: (_) => _ownerPhoneFocusNode.requestFocus(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]')),
              LengthLimitingTextInputFormatter(17),
            ],
          ),
          const SizedBox(height: 16),

          // Телефон владельца квартиры
          BlueTextField(
            controller: _ownerPhoneController,
            focusNode: _ownerPhoneFocusNode,
            labelText: 'Телефон владельца квартиры',
            hintText: '+998 90 123 45 67',
            keyboardType: TextInputType.phone,
            validator: (_) => _ownerPhoneError,
            prefixIcon: const Icon(Icons.phone),
            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]')),
              LengthLimitingTextInputFormatter(17),
            ],
          ),
          const SizedBox(height: 16),

          // Роль в семье
          Text(
            'Ваша роль в семье',
            style: AppTheme.typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _roleError != null ? Colors.red : AppTheme.lightGray,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.people),
              ),
              hint: const Text('Выберите роль'),
              items: FamilyMemberModel.roles.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                  _roleError = null;
                });
              },
            ),
          ),
          if (_roleError != null) ...[
            const SizedBox(height: 4),
            Text(
              _roleError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),

          // Блок
          Text(
            'Блок',
            style: AppTheme.typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _blockError != null ? Colors.red : AppTheme.lightGray,
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: _blockController.text.isEmpty ? null : _blockController.text,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.apartment),
              ),
              hint: const Text('Выберите блок'),
              items: _availableBlocks.map((block) {
                return DropdownMenuItem<String>(
                  value: block,
                  child: Text('Блок $block'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _blockController.text = value ?? '';
                  _blockError = null;
                });
              },
            ),
          ),
          if (_blockError != null) ...[
            const SizedBox(height: 4),
            Text(
              _blockError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),

          // Номер квартиры
          BlueTextField(
            controller: _apartmentController,
            focusNode: _apartmentFocusNode,
            labelText: 'Номер квартиры',
            hintText: 'Например: 01-222',
            validator: (_) => _apartmentError,
            prefixIcon: const Icon(Icons.door_front_door),
            onFieldSubmitted: (_) => _submitRequest(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return BlueButton(
      text: 'Отправить запрос',
      isLoading: _isLoading,
      onPressed: _isLoading ? null : _submitRequest,
    );
  }
} 
