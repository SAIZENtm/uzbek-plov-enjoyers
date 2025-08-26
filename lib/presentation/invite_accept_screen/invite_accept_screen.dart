import 'package:go_router/go_router.dart';

import '../../core/app_export.dart';
import '../../core/di/service_locator.dart';
import '../../core/models/invitation_model.dart';
import '../../widgets/blue_button.dart';
import '../../widgets/blue_text_field.dart';
import '../../widgets/frosted_glass_card.dart';

class InviteAcceptScreen extends StatefulWidget {
  final String inviteId;

  const InviteAcceptScreen({
    super.key,
    required this.inviteId,
  });

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  InvitationModel? _invite;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Form fields
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRole = 'Семья';

  final List<String> _availableRoles = [
    'Семья',
    'Родственник',
    'Друг',
    'Сосед',
  ];

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final inviteService = getIt<InviteService>();
      final invite = await inviteService.getInviteById(widget.inviteId);

      if (invite == null) {
        setState(() {
          _errorMessage = 'Инвайт не найден или истек';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _invite = invite;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка загрузки инвайта: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitInvite() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ваше имя')),
      );
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите номер телефона')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final inviteService = getIt<InviteService>();
      final success = await inviteService.useInvite(
        inviteId: widget.inviteId,
        memberName: _nameController.text.trim(),
        memberPhone: _phoneController.text.trim(),
        memberRole: _selectedRole,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Заявка отправлена! Владелец квартиры рассмотрит её.'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/auth');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ошибка отправки заявки. Попробуйте позже.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.colors.background,
      appBar: AppBar(
        backgroundColor: AppTheme.colors.pureWhite,
        elevation: 0,
        surfaceTintColor: AppTheme.colors.pureWhite,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.colors.charcoal),
          onPressed: () => context.go('/auth'),
        ),
        title: Text(
          'Присоединиться к семье',
          style: AppTheme.typography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.colors.charcoal,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildInviteForm(),
    );
  }

  Widget _buildErrorState() {
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
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ошибка',
              style: AppTheme.typography.headlineSmall.copyWith(
                color: AppTheme.colors.charcoal,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.colors.darkGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            BlueButton(
              onPressed: () => context.go('/auth'),
              text: 'Вернуться к входу',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteForm() {
    if (_invite == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInviteInfo(),
          const SizedBox(height: 32),
          _buildForm(),
        ],
      ),
    );
  }

  Widget _buildInviteInfo() {
    return FrostedGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.home,
                    color: AppTheme.colors.pureWhite,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Квартира ${_invite!.apartmentNumber}',
                        style: AppTheme.typography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.colors.charcoal,
                        ),
                      ),
                      Text(
                        'Блок ${_invite!.blockId}',
                        style: AppTheme.typography.bodyMedium.copyWith(
                          color: AppTheme.colors.darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.colors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    color: AppTheme.colors.mediumGray,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Владелец: ${_invite!.ownerName}',
                      style: AppTheme.typography.bodyMedium.copyWith(
                        color: AppTheme.colors.darkGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.colors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppTheme.colors.mediumGray,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Действует до: ${_formatDate(_invite!.expiresAt)}',
                      style: AppTheme.typography.bodyMedium.copyWith(
                        color: AppTheme.colors.darkGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return FrostedGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ваши данные',
              style: AppTheme.typography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.colors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Заполните форму, чтобы присоединиться к семье',
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.colors.darkGray,
              ),
            ),
            const SizedBox(height: 24),
            BlueTextField(
              controller: _nameController,
              labelText: 'Ваше имя',
              hintText: 'Введите полное имя',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            const SizedBox(height: 16),
            BlueTextField(
              controller: _phoneController,
              labelText: 'Номер телефона',
              hintText: '+998 XX XXX XX XX',
              prefixIcon: const Icon(Icons.phone_outlined),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Text(
              'Роль в семье',
              style: AppTheme.typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.colors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.colors.lightGray),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: _availableRoles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: BlueButton(
                onPressed: _isSubmitting ? null : _submitInvite,
                text: _isSubmitting ? 'Отправка...' : 'Присоединиться к семье',
                isLoading: _isSubmitting,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'После отправки заявки владелец квартиры рассмотрит её и добавит вас в семью.',
              style: AppTheme.typography.bodySmall.copyWith(
                color: AppTheme.colors.mediumGray,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
} 