
import '../../../../core/app_export.dart';

class PaymentAmountSelectorWidget extends StatefulWidget {
  final double currentDebt;
  final double selectedAmount;
  final Function(double) onAmountChanged;

  const PaymentAmountSelectorWidget({
    super.key,
    required this.currentDebt,
    required this.selectedAmount,
    required this.onAmountChanged,
  });

  @override
  State<PaymentAmountSelectorWidget> createState() =>
      _PaymentAmountSelectorWidgetState();
}

class _PaymentAmountSelectorWidgetState
    extends State<PaymentAmountSelectorWidget> {
  final TextEditingController _customAmountController = TextEditingController();
  final List<double> presetAmounts = [50000, 100000, 500000];

  @override
  void initState() {
    super.initState();
    if (widget.selectedAmount > 0) {
      _customAmountController.text = widget.selectedAmount.toInt().toString();
    }
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.lightTheme.colorScheme.outline),
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
                iconName: 'payments',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Сумма к оплате',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick amount buttons
          Text(
            'Быстрый выбор:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildQuickAmountButton(widget.currentDebt, 'Полная сумма'),
              ...presetAmounts
                  .map((amount) => _buildQuickAmountButton(amount, null)),
            ],
          ),

          const SizedBox(height: 20),

          // Custom amount input
          Text(
            'Или введите сумму:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _customAmountController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: 'Введите сумму',
              suffixText: 'сум',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomIconWidget(
                  iconName: 'attach_money',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                final amount = double.tryParse(value.replaceAll(' ', '')) ?? 0;
                widget.onAmountChanged(amount);
              } else {
                widget.onAmountChanged(0);
              }
            },
          ),

          if (widget.selectedAmount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'info',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Выбрано: ${_formatCurrency(widget.selectedAmount)}',
                      style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
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

  Widget _buildQuickAmountButton(double amount, String? label) {
    final isSelected = widget.selectedAmount == amount;

    return GestureDetector(
      onTap: () {
        _customAmountController.text = amount.toInt().toString();
        widget.onAmountChanged(amount);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label ?? _formatCurrency(amount),
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.onPrimary
                : AppTheme.lightTheme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return '${amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        )} сум';
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final formattedText = newValue.text.replaceAll(RegExp(r'\s+'), '');

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
