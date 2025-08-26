import '../../../../../core/app_export.dart';

class Step4PriorityWidget extends StatefulWidget {
  final List<Map<String, dynamic>> priorityOptions;
  final String selectedPriority;
  final ValueChanged<String> onPriorityChanged;

  const Step4PriorityWidget({
    super.key,
    required this.priorityOptions,
    required this.selectedPriority,
    required this.onPriorityChanged,
  });

  @override
  State<Step4PriorityWidget> createState() => _Step4PriorityWidgetState();
}

class _Step4PriorityWidgetState extends State<Step4PriorityWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Приоритет выполнения',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        const Text(
          'Выберите приоритет выполнения заявки',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        
        // Priority Options
        ...widget.priorityOptions.map((option) => _buildPriorityOption(option)),
      ],
    );
  }

  Widget _buildPriorityOption(Map<String, dynamic> option) {
    final isSelected = option['value'] == widget.selectedPriority;
    final color = option['color'] as Color;
    final emoji = option['emoji'] as String;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          widget.onPriorityChanged(option['value'] as String);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected
                  ? color
                  : AppTheme.lightTheme.colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? color.withValues(alpha: 0.05)
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
                        ? color
                        : AppTheme.lightTheme.colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      )
                    : null,
              ),
              
              const SizedBox(width: 16),
              
              // Emoji Indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['label'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? color
                            : AppTheme.lightTheme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPriorityDescription(option['value'] as String),
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected
                            ? color.withValues(alpha: 0.8)
                            : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Priority Level Indicator
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getPriorityLevel(option['value'] as String),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPriorityDescription(String priority) {
    switch (priority) {
      case 'Low':
        return 'Обычная заявка, выполнение в течение 3-5 дней';
      case 'Medium':
        return 'Средний приоритет, выполнение в течение 1-3 дней';
      case 'High':
        return 'Высокий приоритет, выполнение в течение 24 часов';
      case 'Emergency':
        return 'Экстренная заявка, выполнение в течение 2-4 часов';
      default:
        return '';
    }
  }

  String _getPriorityLevel(String priority) {
    switch (priority) {
      case 'Low':
        return '1';
      case 'Medium':
        return '2';
      case 'High':
        return '3';
      case 'Emergency':
        return '4';
      default:
        return '';
    }
  }
} 