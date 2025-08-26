
import '../../../../core/app_export.dart';

class CardPaymentFormWidget extends StatefulWidget {
  final String cardNumber;
  final String expiryDate;
  final String cvv;
  final Function(String) onCardNumberChanged;
  final Function(String) onExpiryDateChanged;
  final Function(String) onCvvChanged;

  const CardPaymentFormWidget({
    super.key,
    required this.cardNumber,
    required this.expiryDate,
    required this.cvv,
    required this.onCardNumberChanged,
    required this.onExpiryDateChanged,
    required this.onCvvChanged,
  });

  @override
  State<CardPaymentFormWidget> createState() => _CardPaymentFormWidgetState();
}

class _CardPaymentFormWidgetState extends State<CardPaymentFormWidget> {
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  final FocusNode _cardNumberFocus = FocusNode();
  final FocusNode _expiryFocus = FocusNode();
  final FocusNode _cvvFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _cardNumberController.text = widget.cardNumber;
    _expiryController.text = widget.expiryDate;
    _cvvController.text = widget.cvv;
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
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
                iconName: 'credit_card',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Данные карты',
                style: AppTheme.lightTheme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Card number field
          TextField(
            controller: _cardNumberController,
            focusNode: _cardNumberFocus,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CardNumberInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: 'Номер карты',
              hintText: '0000 0000 0000 0000',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CustomIconWidget(
                  iconName: 'credit_card',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              suffixIcon: _getCardTypeIcon(),
            ),
            onChanged: (value) {
              widget.onCardNumberChanged(value);
              if (value.length == 19) {
                // 16 digits + 3 spaces
                _expiryFocus.requestFocus();
              }
            },
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              // Expiry date field
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _expiryController,
                  focusNode: _expiryFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ExpiryDateInputFormatter(),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Срок действия',
                    hintText: 'ММ/ГГ',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CustomIconWidget(
                        iconName: 'calendar_today',
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    widget.onExpiryDateChanged(value);
                    if (value.length == 5) {
                      // MM/YY
                      _cvvFocus.requestFocus();
                    }
                  },
                ),
              ),

              const SizedBox(width: 16),

              // CVV field
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  focusNode: _cvvFocus,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CustomIconWidget(
                        iconName: 'security',
                        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                  onChanged: widget.onCvvChanged,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Security notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.successLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.successLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const CustomIconWidget(
                  iconName: 'lock',
                  color: AppTheme.successLight,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ваши данные защищены 256-битным шифрованием',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.successLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _getCardTypeIcon() {
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');

    if (cardNumber.isEmpty) return null;

    String cardType = 'credit_card';
    Color iconColor = AppTheme.lightTheme.colorScheme.onSurfaceVariant;

    if (cardNumber.startsWith('4')) {
      cardType = 'credit_card'; // Visa
      iconColor = const Color(0xFF1A1F71);
    } else if (cardNumber.startsWith('5') || cardNumber.startsWith('2')) {
      cardType = 'credit_card'; // MasterCard
      iconColor = const Color(0xFFEB001B);
    } else if (cardNumber.startsWith('8600')) {
      cardType = 'credit_card'; // UzCard
      iconColor = const Color(0xFF00A651);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: CustomIconWidget(
        iconName: cardType,
        color: iconColor,
        size: 20,
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll(' ', '');
    if (digitsOnly.length > 16) {
      digitsOnly = digitsOnly.substring(0, 16);
    }

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    String digitsOnly = newValue.text.replaceAll('/', '');
    if (digitsOnly.length > 4) {
      digitsOnly = digitsOnly.substring(0, 4);
    }

    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2) {
        formatted += '/';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
