
import '../../../../core/app_export.dart';

class TransactionSummaryWidget extends StatelessWidget {
  final double paymentAmount;
  final double serviceFee;

  const TransactionSummaryWidget({
    super.key,
    required this.paymentAmount,
    required this.serviceFee,
  });

  @override
  Widget build(BuildContext context) {
    final double totalAmount = paymentAmount + serviceFee;

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
                iconName: 'receipt',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Сводка платежа',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Payment amount
          _buildSummaryRow(
            'Сумма к оплате',
            _formatCurrency(paymentAmount),
            isMain: true,
          ),

          const SizedBox(height: 12),

          // Service fee
          _buildSummaryRow(
            'Комиссия за услугу',
            _formatCurrency(serviceFee),
            isSecondary: true,
          ),

          const SizedBox(height: 16),

          // Divider
          Container(
            height: 1,
            color: AppTheme.lightTheme.colorScheme.outline,
          ),

          const SizedBox(height: 16),

          // Total amount
          _buildSummaryRow(
            'Итого к списанию',
            _formatCurrency(totalAmount),
            isTotal: true,
          ),

          if (paymentAmount > 0) ...[
            const SizedBox(height: 20),

            // Payment breakdown info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.primary
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'info_outline',
                        color: AppTheme.lightTheme.colorScheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Детали платежа',
                        style:
                            AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.lightTheme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Получатель', 'ЖК "Newport"'),
                  _buildDetailRow('Лицевой счет', '№ 12345678'),
                  _buildDetailRow('Период', 'Декабрь 2024'),
                  _buildDetailRow('Дата платежа', _getCurrentDate()),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String amount, {
    bool isMain = false,
    bool isSecondary = false,
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: isTotal
                ? AppTheme.lightTheme.colorScheme.onSurface
                : isSecondary
                    ? AppTheme.lightTheme.colorScheme.onSurfaceVariant
                    : AppTheme.lightTheme.colorScheme.onSurface,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          amount,
          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
            color: isTotal
                ? AppTheme.lightTheme.colorScheme.primary
                : isMain
                    ? AppTheme.lightTheme.colorScheme.onSurface
                    : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            fontWeight: isTotal
                ? FontWeight.bold
                : isMain
                    ? FontWeight.w600
                    : FontWeight.w400,
            fontSize: isTotal ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount == 0) return '0 сум';
    return '${amount.toInt().toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]} ',
        )} сум';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }
}
