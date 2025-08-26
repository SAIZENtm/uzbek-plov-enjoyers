
import '../../../../core/app_export.dart';

class MobilePaymentWidget extends StatefulWidget {
  final String phoneNumber;
  final Function(String) onPhoneNumberChanged;

  const MobilePaymentWidget({
    super.key,
    required this.phoneNumber,
    required this.onPhoneNumberChanged,
  });

  @override
  State<MobilePaymentWidget> createState() => _MobilePaymentWidgetState();
}

class _MobilePaymentWidgetState extends State<MobilePaymentWidget> {
  final TextEditingController _phoneController = TextEditingController();
  String selectedCarrier = 'beeline';

  final List<Map<String, dynamic>> carriers = [
    {
      'id': 'beeline',
      'name': 'Beeline',
      'color': const Color(0xFFFEED00),
      'prefixes': ['90', '91'],
    },
    {
      'id': 'ucell',
      'name': 'Ucell',
      'color': const Color(0xFF8B00FF),
      'prefixes': ['93', '94'],
    },
    {
      'id': 'ums',
      'name': 'UMS',
      'color': const Color(0xFF00A651),
      'prefixes': ['95', '99'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.phoneNumber;
    _detectCarrier(widget.phoneNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _detectCarrier(String phoneNumber) {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length >= 5) {
      final prefix = cleanNumber.substring(3, 5);
      for (final carrier in carriers) {
        final prefixes = carrier['prefixes'] as List<String>;
        if (prefixes.contains(prefix)) {
          setState(() {
            selectedCarrier = carrier['id'] as String;
          });
          break;
        }
      }
    }
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
                iconName: 'phone_android',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Мобильный платеж',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Carrier selection
          Text(
            'Выберите оператора:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: carriers
                .map((carrier) => _buildCarrierButton(carrier))
                .toList(),
          ),

          const SizedBox(height: 20),

          // Phone number input
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _PhoneNumberInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Номер телефона',
              hintText: '+998 90 123 45 67',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomIconWidget(
                  iconName: 'phone',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              suffixIcon: _getCarrierIcon(),
            ),
            onChanged: (value) {
              widget.onPhoneNumberChanged(value);
              _detectCarrier(value);
            },
          ),

          const SizedBox(height: 16),

          // Payment info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightTheme.colorScheme.primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.lightTheme.colorScheme.primary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CustomIconWidget(
                      iconName: 'info',
                      color: AppTheme.lightTheme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Информация о платеже',
                      style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '• Средства будут списаны с баланса мобильного телефона\n'
                  '• Комиссия оператора: 2-3% от суммы платежа\n'
                  '• Максимальная сумма платежа: 500 000 сум',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.primary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Balance check button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkBalance,
              icon: CustomIconWidget(
                iconName: 'account_balance_wallet',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 20,
              ),
              label: const Text('Проверить баланс'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierButton(Map<String, dynamic> carrier) {
    final isSelected = selectedCarrier == carrier['id'];

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedCarrier = carrier['id'] as String;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (carrier['color'] as Color).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? carrier['color'] as Color
                  : AppTheme.lightTheme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            carrier['name'] as String,
            textAlign: TextAlign.center,
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? carrier['color'] as Color
                  : AppTheme.lightTheme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget? _getCarrierIcon() {
    final selectedCarrierData = carriers.firstWhere(
      (carrier) => carrier['id'] == selectedCarrier,
      orElse: () => carriers.first,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selectedCarrierData['color'] as Color,
        shape: BoxShape.circle,
      ),
    );
  }

  void _checkBalance() {
    // Simulate balance check
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Баланс телефона'),
          content: const Text(
              'Текущий баланс: 45 000 сум\n\nДостаточно для совершения платежа.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ОК'),
            ),
          ],
        );
      },
    );
  }
}

class _PhoneNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length > 12) {
      digitsOnly = digitsOnly.substring(0, 12);
    }

    String formatted = '';
    if (digitsOnly.isNotEmpty) {
      formatted = '+';
      for (int i = 0; i < digitsOnly.length; i++) {
        if (i == 3) formatted += ' ';
        if (i == 5) formatted += ' ';
        if (i == 8) formatted += ' ';
        if (i == 10) formatted += ' ';
        formatted += digitsOnly[i];
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
