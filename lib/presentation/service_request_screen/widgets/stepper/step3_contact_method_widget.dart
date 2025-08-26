import '../../../../../core/app_export.dart';

class Step3ContactMethodWidget extends StatefulWidget {
  final String selectedContactMethod;
  final ValueChanged<String> onContactMethodChanged;

  const Step3ContactMethodWidget({
    super.key,
    required this.selectedContactMethod,
    required this.onContactMethodChanged,
  });

  @override
  State<Step3ContactMethodWidget> createState() => _Step3ContactMethodWidgetState();
}

class _Step3ContactMethodWidgetState extends State<Step3ContactMethodWidget> {
  final List<Map<String, dynamic>> _contactMethods = [
    {
      'value': 'phone',
      'label': 'Телефонный звонок',
      'description': 'Мы свяжемся с вами по телефону',
      'icon': 'phone',
    },
    {
      'value': 'notification',
      'label': 'Уведомление в приложении',
      'description': 'Получайте обновления через приложение',
      'icon': 'notifications',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Способ связи',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        const Text(
          'Выберите предпочтительный способ связи',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        
        // Contact Method Options
        ..._contactMethods.map((method) => _buildContactMethodOption(method)),
      ],
    );
  }

  Widget _buildContactMethodOption(Map<String, dynamic> method) {
    final isSelected = method['value'] == widget.selectedContactMethod;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          widget.onContactMethodChanged(method['value'] as String);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.05)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              // Radio Button
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.lightTheme.colorScheme.primary
                        : AppTheme.lightTheme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.lightTheme.colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Icon
              CustomIconWidget(
                iconName: method['icon'] as String,
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.onSurface,
                size: 24,
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method['label'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? AppTheme.lightTheme.colorScheme.primary
                            : AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method['description'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.8)
                            : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 