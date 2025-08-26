
import 'package:go_router/go_router.dart';
import '../../../core/app_export.dart';
import './widgets/card_payment_form_widget.dart';
import './widgets/mobile_payment_widget.dart';
import './widgets/payment_amount_selector_widget.dart';
import './widgets/payment_method_selector_widget.dart';
import './widgets/transaction_summary_widget.dart';

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
  // Mock debt data
  final Map<String, dynamic> debtData = {
    "currentDebt": 850000.0,
    "isOverdue": true,
    "dueDate": "15.12.2024",
    "serviceFee": 5000.0,
  };

  // Payment state
  double selectedAmount = 0.0;
  String selectedPaymentMethod = 'card'; // card, mobile, banking
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Set initial amount if provided
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      selectedAmount = widget.initialAmount!;
    }
  }

  // Card form data
  String cardNumber = '';
  String expiryDate = '';
  String cvv = '';

  // Mobile payment data
  String phoneNumber = '+998 90 123 45 67';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Оплата услуг',
          style: AppTheme.lightTheme.textTheme.titleLarge,
        ),
        leading: IconButton(
          onPressed: () => _handleBackNavigation(),
          icon: CustomIconWidget(
            iconName: 'arrow_back',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 2,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDebtInfoCard(),
              const SizedBox(height: 24),
              PaymentAmountSelectorWidget(
                currentDebt: debtData["currentDebt"] as double,
                selectedAmount: selectedAmount,
                onAmountChanged: (amount) {
                  setState(() {
                    selectedAmount = amount;
                  });
                },
              ),
              const SizedBox(height: 24),
              PaymentMethodSelectorWidget(
                selectedMethod: selectedPaymentMethod,
                onMethodChanged: (method) {
                  setState(() {
                    selectedPaymentMethod = method;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildPaymentForm(),
              const SizedBox(height: 24),
              TransactionSummaryWidget(
                paymentAmount: selectedAmount,
                serviceFee: debtData["serviceFee"] as double,
              ),
              const SizedBox(height: 32),
              _buildPayButton(),
              const SizedBox(height: 16),
              _buildSecurityIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtInfoCard() {
    final isOverdue = debtData["isOverdue"] as bool;
    final debtAmount = debtData["currentDebt"] as double;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? AppTheme.errorLight
              : AppTheme.lightTheme.colorScheme.outline,
          width: isOverdue ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppTheme.shadowLight,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: isOverdue ? 'warning' : 'account_balance_wallet',
                color: isOverdue
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                isOverdue
                    ? 'Просроченная задолженность'
                    : 'Текущая задолженность',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: isOverdue
                      ? AppTheme.errorLight
                      : AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(debtAmount),
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              color: isOverdue
                  ? AppTheme.errorLight
                  : AppTheme.lightTheme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(height: 8),
            Text(
              'Срок оплаты: ${debtData["dueDate"]}',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.errorLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    switch (selectedPaymentMethod) {
      case 'card':
        return CardPaymentFormWidget(
          cardNumber: cardNumber,
          expiryDate: expiryDate,
          cvv: cvv,
          onCardNumberChanged: (value) {
            setState(() {
              cardNumber = value;
            });
          },
          onExpiryDateChanged: (value) {
            setState(() {
              expiryDate = value;
            });
          },
          onCvvChanged: (value) {
            setState(() {
              cvv = value;
            });
          },
        );
      case 'mobile':
        return MobilePaymentWidget(
          phoneNumber: phoneNumber,
          onPhoneNumberChanged: (value) {
            setState(() {
              phoneNumber = value;
            });
          },
        );
      case 'banking':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.lightTheme.colorScheme.outline),
          ),
          child: Column(
            children: [
              CustomIconWidget(
                iconName: 'account_balance',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Онлайн банкинг',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Вы будете перенаправлены в ваш банк для завершения платежа',
                style: AppTheme.lightTheme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPayButton() {
    final isEnabled = selectedAmount > 0 && _isPaymentFormValid();

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled && !isProcessing ? _processPayment : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? AppTheme.lightTheme.colorScheme.primary
              : AppTheme.lightTheme.colorScheme.outline,
          foregroundColor: AppTheme.lightTheme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: isEnabled ? 4 : 0,
        ),
        child: isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.lightTheme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Обработка...',
                    style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'payment',
                    color: AppTheme.lightTheme.colorScheme.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Оплатить ${_formatCurrency(selectedAmount + (debtData["serviceFee"] as double))}',
                    style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.lightTheme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityIndicator() {
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
          const CustomIconWidget(
            iconName: 'security',
            color: AppTheme.successLight,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Защищенное соединение SSL. Ваши данные в безопасности.',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.successLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isPaymentFormValid() {
    switch (selectedPaymentMethod) {
      case 'card':
        return cardNumber.length >= 16 &&
            expiryDate.length >= 5 &&
            cvv.length >= 3;
      case 'mobile':
        return phoneNumber.length >= 13;
      case 'banking':
        return true;
      default:
        return false;
    }
  }

  void _processPayment() async {
    if (!_isPaymentFormValid() || selectedAmount <= 0) return;

    setState(() {
      isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 3));

    setState(() {
      isProcessing = false;
    });

    // Show success dialog
    _showPaymentSuccessDialog();
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                child: const CustomIconWidget(
                  iconName: 'check_circle',
                  color: AppTheme.successLight,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Платеж успешно выполнен!',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Номер транзакции: ${DateTime.now().millisecondsSinceEpoch}',
                style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Закрыть'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Share receipt functionality
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Поделиться'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleBackNavigation() {
    if (selectedAmount > 0 || cardNumber.isNotEmpty) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Несохраненные изменения'),
            content: const Text(
                'У вас есть несохраненные данные. Вы уверены, что хотите выйти?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Safe navigation back
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/dashboard');
                  }
                },
                child: const Text('Выйти'),
              ),
            ],
          );
        },
      );
    } else {
      // Safe navigation back
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/dashboard');
      }
    }
  }

  String _formatCurrency(double amount) {
    try {
      if (amount.isNaN || amount.isInfinite) {
        return '0 сум';
      }

      // Round to nearest integer
      final roundedAmount = amount.round();
      
      // Handle negative amounts
      final isNegative = roundedAmount < 0;
      final absoluteAmount = roundedAmount.abs();

      // Format with thousand separators
      final formattedAmount = absoluteAmount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]} ',
      );

      return '${isNegative ? '-' : ''}$formattedAmount сум';
    } catch (e) {
      debugPrint('Error formatting currency: $e');
      return '0 сум';
    }
  }
}
