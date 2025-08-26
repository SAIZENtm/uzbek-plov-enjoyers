
import '../../../core/app_export.dart';
import '../../../core/models/family_request_model.dart';
import '../../../core/di/service_locator.dart';


class FamilyRequestNotificationDialog extends StatefulWidget {
  final FamilyRequestModel request;
  final VoidCallback? onRequestHandled;

  const FamilyRequestNotificationDialog({
    super.key,
    required this.request,
    this.onRequestHandled,
  });

  @override
  State<FamilyRequestNotificationDialog> createState() =>
      _FamilyRequestNotificationDialogState();
}

class _FamilyRequestNotificationDialogState
    extends State<FamilyRequestNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isProcessing = false;
  String? _rejectionReason;
  final TextEditingController _rejectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _rejectionController.dispose();
    super.dispose();
  }

  Future<void> _handleRequest(bool approved) async {
    if (_isProcessing) return;

    // Добавляем тактильную обратную связь
    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessing = true;
    });

    try {
      final familyRequestService = getIt<FamilyRequestService>();

      final success = await familyRequestService.respondToFamilyRequest(
        requestId: widget.request.id,
        approved: approved,
        rejectionReason: approved ? null : _rejectionReason,
      );

      if (!mounted) return;

      if (success) {
        // Показываем успешное сообщение
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved 
                  ? 'Запрос одобрен. Заявитель получил уведомление.' 
                  : 'Запрос отклонен.',
            ),
            backgroundColor: approved ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Вызываем callback если есть
        widget.onRequestHandled?.call();

        // Закрываем диалог
        Navigator.of(context).pop();
      } else {
        _showErrorMessage('Не удалось обработать запрос. Попробуйте позже.');
      }
    } catch (e) {
      getIt<LoggingService>().error('Failed to handle family request', e);
      _showErrorMessage('Произошла ошибка. Попробуйте позже.');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showRejectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Причина отклонения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Укажите причину отклонения запроса (необязательно):',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionController,
              decoration: const InputDecoration(
                hintText: 'Например: Неверные данные',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              _rejectionReason = _rejectionController.text.trim();
              Navigator.of(context).pop();
              _handleRequest(false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Отклонить'),
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
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.newportPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  color: AppTheme.newportPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Новый запрос в семью',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRequestInfo(),
              const SizedBox(height: 16),
              _buildApartmentInfo(),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.lightGray.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                color: AppTheme.mediumGray,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Заявитель',
                style: AppTheme.typography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.request.name,
            style: AppTheme.typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.phone,
                color: AppTheme.mediumGray,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Телефон заявителя',
                style: AppTheme.typography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.request.applicantPhone ?? 'Не указан',
            style: AppTheme.typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.people,
                color: AppTheme.mediumGray,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Роль в семье',
                style: AppTheme.typography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: AppTheme.mediumGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.newportPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.request.role,
              style: AppTheme.typography.bodyMedium.copyWith(
                color: AppTheme.newportPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (widget.request.ownerPhone != null && widget.request.ownerPhone!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.phone,
                  color: AppTheme.mediumGray,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Телефон владельца',
                  style: AppTheme.typography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.lightGray.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    widget.request.ownerPhone!,
                    style: AppTheme.typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      // Копировать номер телефона в буфер обмена
                      Clipboard.setData(ClipboardData(text: widget.request.ownerPhone!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Номер телефона скопирован'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.copy,
                      size: 18,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApartmentInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.lightGray),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.apartment,
            color: AppTheme.newportPrimary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Квартира',
                  style: AppTheme.typography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: AppTheme.mediumGray,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.request.fullAddress,
                  style: AppTheme.typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Text(
          'Подтвердить этого человека как члена вашей семьи?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _showRejectionDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Отклонить'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _handleRequest(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.newportPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Подтвердить'),
              ),
            ),
          ],
        ),
      ],
    );
  }
} 
