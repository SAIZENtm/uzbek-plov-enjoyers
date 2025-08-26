import 'package:intl/intl.dart';
import '../../../../../core/app_export.dart';

class Step5DateTimeWidget extends StatefulWidget {
  final DateTime? selectedDateTime;
  final ValueChanged<DateTime?> onDateTimeChanged;

  const Step5DateTimeWidget({
    super.key,
    required this.selectedDateTime,
    required this.onDateTimeChanged,
  });

  @override
  State<Step5DateTimeWidget> createState() => _Step5DateTimeWidgetState();
}

class _Step5DateTimeWidgetState extends State<Step5DateTimeWidget> {
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Предпочтительное время обслуживания',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        const Text(
          'Выберите удобное для вас время',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        
        // Date and Time Selection
        InkWell(
          onTap: () {
            setState(() {
              _showError = false;
            });
            _showDateTimePicker(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _showError && widget.selectedDateTime == null
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: 'schedule',
                  color: widget.selectedDateTime != null
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.selectedDateTime != null
                        ? _formatDateTime(widget.selectedDateTime!)
                        : 'Выберите дату и время',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: widget.selectedDateTime != null
                          ? AppTheme.lightTheme.colorScheme.onSurface
                          : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CustomIconWidget(
                  iconName: 'keyboard_arrow_down',
                  color: AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        
        if (_showError && widget.selectedDateTime == null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              'Пожалуйста, выберите время обслуживания',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.errorLight,
              ),
            ),
          ),
        
        const SizedBox(height: 16),
        
        // Quick Time Options
        if (widget.selectedDateTime != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Быстрый выбор времени:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildQuickTimeOptions(),
              ),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Time Restrictions Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.2),
            ),
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
                  'Время обслуживания: Пн-Пт 09:00-18:00, Сб 09:00-15:00',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.lightTheme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildQuickTimeOptions() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Generate quick time options for next 3 days
    final quickOptions = <Widget>[];
    
    for (int i = 0; i < 3; i++) {
      final date = today.add(Duration(days: i));
      final isToday = i == 0;
      final isTomorrow = i == 1;
      
      String label;
      if (isToday) {
        label = 'Сегодня';
      } else if (isTomorrow) {
        label = 'Завтра';
      } else {
        label = DateFormat('dd.MM').format(date);
      }
      
      quickOptions.add(
        _buildQuickTimeChip(
          label: label,
          time: '09:00',
          date: date,
        ),
      );
      
      quickOptions.add(
        _buildQuickTimeChip(
          label: label,
          time: '14:00',
          date: date,
        ),
      );
    }
    
    return quickOptions;
  }

  Widget _buildQuickTimeChip({
    required String label,
    required String time,
    required DateTime date,
  }) {
    final selectedDate = DateTime(date.year, date.month, date.day);
    final selectedTime = time.split(':');
    final selectedDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      int.parse(selectedTime[0]),
      int.parse(selectedTime[1]),
    );
    
    final isSelected = widget.selectedDateTime != null &&
        widget.selectedDateTime!.year == selectedDateTime.year &&
        widget.selectedDateTime!.month == selectedDateTime.month &&
        widget.selectedDateTime!.day == selectedDateTime.day &&
        widget.selectedDateTime!.hour == selectedDateTime.hour &&
        widget.selectedDateTime!.minute == selectedDateTime.minute;
    
    return InkWell(
      onTap: () {
        widget.onDateTimeChanged(selectedDateTime);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.lightTheme.colorScheme.primary
              : AppTheme.lightTheme.colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : AppTheme.lightTheme.colorScheme.outline,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          '$label $time',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : AppTheme.lightTheme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    final timeFormat = DateFormat('HH:mm');
    return '${dateFormat.format(dateTime)} в ${timeFormat.format(dateTime)}';
  }

  Future<void> _showDateTimePicker(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = widget.selectedDateTime ?? now;
    
    // Show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('ru', 'RU'),
          child: child!,
        );
      },
    );
    
    if (selectedDate != null) {
      // Show time picker
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Localizations.override(
            context: context,
            locale: const Locale('ru', 'RU'),
            child: child!,
          );
        },
      );
      
      if (selectedTime != null) {
        final combinedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
        
        widget.onDateTimeChanged(combinedDateTime);
      }
    }
  }

  void validate() {
    setState(() {
      _showError = widget.selectedDateTime == null;
    });
  }
} 