
import '../../../core/app_export.dart';

class RequestTypeDropdownWidget extends StatefulWidget {
  final List<Map<String, dynamic>> requestTypes;
  final String? selectedType;
  final ValueChanged<String?> onChanged;

  const RequestTypeDropdownWidget({
    super.key,
    required this.requestTypes,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  State<RequestTypeDropdownWidget> createState() => _RequestTypeDropdownWidgetState();
}

class _RequestTypeDropdownWidgetState extends State<RequestTypeDropdownWidget> {
  bool _showError = false;

  @override
  Widget build(BuildContext context) {
    // Проверяем, что selectedType действительно есть в списке
    final validSelectedType = widget.selectedType != null && 
        widget.requestTypes.any((type) => type['value'] == widget.selectedType) 
        ? widget.selectedType 
        : null;

    // Находим выбранный тип для отображения
    Map<String, dynamic>? selectedItem;
    if (validSelectedType != null) {
      selectedItem = widget.requestTypes.firstWhere(
        (type) => type['value'] == validSelectedType,
        orElse: () => {'label': 'Выберите тип заявки', 'icon': 'build'},
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showError = false;
            });
            _showRequestTypeDialog(context, validSelectedType);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _showError && validSelectedType == null
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: selectedItem?['icon'] ?? 'build',
                  color: validSelectedType != null
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedItem?['label'] ?? 'Выберите тип заявки',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: validSelectedType != null
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
        if (_showError && validSelectedType == null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              'Пожалуйста, выберите тип заявки',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.errorLight,
              ),
            ),
          ),
      ],
    );
  }

  void _showRequestTypeDialog(BuildContext context, String? currentValue) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите тип заявки'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.requestTypes.length,
              itemBuilder: (context, index) {
                final type = widget.requestTypes[index];
                final isSelected = type['value'] == currentValue;
                
                return ListTile(
                  leading: CustomIconWidget(
                    iconName: type['icon'] as String,
                    color: isSelected
                        ? AppTheme.lightTheme.colorScheme.primary
                        : AppTheme.lightTheme.colorScheme.onSurface,
                    size: 20,
                  ),
                  title: Text(
                    type['label'] as String,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.primary
                          : null,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onChanged(type['value'] as String);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  void validate() {
    if (widget.selectedType == null) {
      setState(() {
        _showError = true;
      });
    }
  }
}
