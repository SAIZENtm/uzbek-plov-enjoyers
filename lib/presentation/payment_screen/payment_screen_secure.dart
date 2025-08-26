import 'package:go_router/go_router.dart';
import '../../core/app_export.dart';
import '../../core/services/payment_service_secure.dart';
import '../../widgets/blue_button.dart';
import '../../widgets/premium_card.dart';

class PaymentScreen extends StatefulWidget {
  final double? initialAmount;
  final String? description;
  
  const PaymentScreen({
    super.key,
    this.initialAmount,
    this.description,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = GetIt.instance<PaymentService>();
  final LoggingService _loggingService = GetIt.instance<LoggingService>();
  
  DebtInfo? _debtInfo;
  double _selectedAmount = 0.0;
  bool _isLoading = false;
  bool _isProcessing = false;
  List<PaymentHistory> _paymentHistory = [];
  
  // Предустановленные суммы
  final List<double> _quickAmounts = [
    100000,
    250000,
    500000,
    1000000,
  ];
  
  @override
  void initState() {
    super.initState();
    _loadPaymentData();
    
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _selectedAmount = widget.initialAmount!;
    }
  }
  
  Future<void> _loadPaymentData() async {
    setState(() => _isLoading = true);
    
    try {
      // Загружаем задолженность и историю параллельно
      final results = await Future.wait([
        _paymentService.getCurrentDebt(),
        _paymentService.getPaymentHistory(limit: 5),
      ]);
      
      setState(() {
        _debtInfo = results[0] as DebtInfo?;
        _paymentHistory = results[1] as List<PaymentHistory>;
        
        // Если сумма не выбрана, устанавливаем текущую задолженность
        if (_selectedAmount == 0 && _debtInfo != null) {
          _selectedAmount = _debtInfo!.currentDebt;
        }
      });
    } catch (e) {
      _loggingService.error('Failed to load payment data', e);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _processPayment() async {
    if (_selectedAmount <= 0 || _isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      // Создаем платеж через сервер
      final result = await _paymentService.createPayment(
        amount: _selectedAmount,
        description: widget.description,
      );
      
      if (result.success && result.checkoutUrl != null) {
        // Открываем Payme для оплаты
        final opened = await _paymentService.openPaymentCheckout(
          result.checkoutUrl!,
        );
        
        if (opened) {
          // Показываем информационное сообщение
          _showPaymentInProgressDialog(result.paymentId!);
        } else {
          _showErrorMessage('Не удалось открыть страницу оплаты');
        }
      } else {
        _showErrorMessage(result.message ?? 'Ошибка создания платежа');
      }
    } on PaymentException catch (e) {
      _showErrorMessage(e.message);
    } catch (e) {
      _showErrorMessage('Произошла ошибка. Попробуйте позже.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  void _showPaymentInProgressDialog(String paymentId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.newportPrimary),
            const SizedBox(height: 24),
            Text(
              'Платеж обрабатывается',
              style: AppTheme.lightTheme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Вы были перенаправлены в Payme.\nПосле завершения оплаты вернитесь в приложение.',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Проверяем статус платежа
              await _checkPaymentStatus(paymentId);
            },
            child: const Text('Я оплатил'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _checkPaymentStatus(String paymentId) async {
    setState(() => _isLoading = true);
    
    try {
      final status = await _paymentService.checkPaymentStatus(paymentId);
      
      if (status != null && status.status == 'completed') {
        _showSuccessDialog();
        // Обновляем данные
        await _loadPaymentData();
      } else {
        _showInfoMessage('Платеж еще обрабатывается. Проверьте позже.');
      }
    } catch (e) {
      _showErrorMessage('Не удалось проверить статус платежа');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.successLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppTheme.successLight,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Платеж успешно выполнен!',
              style: AppTheme.lightTheme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              _formatCurrency(_selectedAmount),
              style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                color: AppTheme.newportPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/dashboard');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.newportPrimary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Оплата услуг'),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          onPressed: () => _handleBackNavigation(),
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.charcoal),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_debtInfo != null) _buildDebtInfoCard(),
                  const SizedBox(height: 24),
                  _buildAmountSelector(),
                  const SizedBox(height: 24),
                  _buildServiceBreakdown(),
                  const SizedBox(height: 24),
                  _buildPaymentHistory(),
                  const SizedBox(height: 32),
                  _buildPayButton(),
                  const SizedBox(height: 16),
                  _buildSecurityNote(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildDebtInfoCard() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      backgroundColor: _debtInfo!.isOverdue 
          ? AppTheme.errorLight.withValues(alpha: 0.1)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _debtInfo!.isOverdue ? Icons.warning : Icons.account_balance_wallet,
                color: _debtInfo!.isOverdue ? AppTheme.errorLight : AppTheme.newportPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _debtInfo!.isOverdue 
                      ? 'Есть просроченная задолженность'
                      : 'Текущая задолженность',
                  style: AppTheme.lightTheme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(_debtInfo!.currentDebt),
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              color: _debtInfo!.isOverdue ? AppTheme.errorLight : AppTheme.charcoal,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Оплатить до ${_formatDate(_debtInfo!.dueDate)}',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAmountSelector() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments, color: AppTheme.newportPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Сумма к оплате',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Поле ввода суммы
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.mediumGray.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    style: AppTheme.lightTheme.textTheme.headlineSmall,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                        color: AppTheme.mediumGray,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    controller: TextEditingController(
                      text: _selectedAmount > 0 ? _selectedAmount.toStringAsFixed(0) : '',
                    ),
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      setState(() => _selectedAmount = amount);
                    },
                  ),
                ),
                Text(
                  'сум',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Быстрые суммы
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_debtInfo != null)
                              _buildQuickAmountChip(
                _debtInfo!.currentDebt,
                'Полная оплата',
                true, // isPrimary
              ),
              ..._quickAmounts.map((amount) => _buildQuickAmountChip(amount)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickAmountChip(double amount, [String? label, bool isPrimary = false]) {
    final isSelected = _selectedAmount == amount;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedAmount = amount),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.newportPrimary 
              : isPrimary 
                  ? AppTheme.newportPrimary.withValues(alpha: 0.1)
                  : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? AppTheme.newportPrimary 
                : isPrimary 
                    ? AppTheme.newportPrimary.withValues(alpha: 0.3)
                    : Colors.transparent,
          ),
        ),
        child: Text(
          label ?? _formatCurrency(amount),
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: isSelected 
                ? Colors.white 
                : isPrimary 
                    ? AppTheme.newportPrimary
                    : AppTheme.charcoal,
            fontWeight: isSelected || isPrimary ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  Widget _buildServiceBreakdown() {
    if (_debtInfo == null || _debtInfo!.services.isEmpty) return const SizedBox.shrink();
    
    return PremiumCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.newportPrimary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Детализация услуг',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._debtInfo!.services.map((service) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  service.name,
                  style: AppTheme.lightTheme.textTheme.bodyMedium,
                ),
                Text(
                  _formatCurrency(service.amount),
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildPaymentHistory() {
    if (_paymentHistory.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Последние платежи',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.push('/payments/history'),
                child: const Text('Все'),
              ),
            ],
          ),
        ),
        ..._paymentHistory.map((payment) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: PremiumCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: payment.statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.description,
                        style: AppTheme.lightTheme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (payment.createdAt != null)
                        Text(
                          _formatDate(payment.createdAt!),
                          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.mediumGray,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(payment.amount),
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      payment.statusText,
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: payment.statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
  
  Widget _buildPayButton() {
    final isEnabled = _selectedAmount >= 1000 && !_isProcessing;
    
    return BlueButton(
      text: _isProcessing 
          ? 'Обработка...' 
          : 'Оплатить ${_formatCurrency(_selectedAmount)}',
      onPressed: isEnabled ? _processPayment : null,
      isLoading: _isProcessing,
      icon: Icons.payment,
    );
  }
  
  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.successLight.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.security,
            color: AppTheme.successLight,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Безопасная оплата через Payme. Мы не храним данные вашей карты.',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.successLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleBackNavigation() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }
  
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorLight,
      ),
    );
  }
  
  void _showInfoMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.newportPrimary,
      ),
    );
  }
  
  String _formatCurrency(double amount) {
    final formattedAmount = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return '$formattedAmount сум';
  }
  
  String _formatDate(DateTime date) {
    final months = [
      'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
      'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
