import '../../../../../core/app_export.dart';

class Step1RequestTypeWidget extends StatefulWidget {
  final List<Map<String, dynamic>> requestTypes;
  final String? selectedRequestType;
  final TextEditingController descriptionController;
  final ValueChanged<String?> onRequestTypeChanged;

  const Step1RequestTypeWidget({
    super.key,
    required this.requestTypes,
    required this.selectedRequestType,
    required this.descriptionController,
    required this.onRequestTypeChanged,
  });

  @override
  State<Step1RequestTypeWidget> createState() => _Step1RequestTypeWidgetState();
}

class _Step1RequestTypeWidgetState extends State<Step1RequestTypeWidget> {
  bool _showRequestTypeError = false;
  bool _showDescriptionError = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Request Type Selection
        const Text(
          'Тип заявки',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        InkWell(
          onTap: () {
            setState(() {
              _showRequestTypeError = false;
            });
            _showRequestTypeDialog(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _showRequestTypeError && widget.selectedRequestType == null
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CustomIconWidget(
                  iconName: _getSelectedTypeIcon(),
                  color: widget.selectedRequestType != null
                      ? AppTheme.lightTheme.colorScheme.primary
                      : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getSelectedTypeLabel(),
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: widget.selectedRequestType != null
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
        
        if (_showRequestTypeError && widget.selectedRequestType == null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              'Пожалуйста, выберите тип заявки',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.errorLight,
              ),
            ),
          ),
        
        const SizedBox(height: 24),
        
        // Description Field
        const Text(
          'Описание проблемы',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        TextFormField(
          controller: widget.descriptionController,
          maxLines: 4,
          maxLength: 500,
          onChanged: (value) {
            setState(() {
              _showDescriptionError = false;
            });
          },
          decoration: InputDecoration(
            hintText: 'Пожалуйста, опишите проблему подробно...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showDescriptionError && widget.descriptionController.text.trim().isEmpty
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _showDescriptionError && widget.descriptionController.text.trim().isEmpty
                    ? AppTheme.errorLight
                    : AppTheme.lightTheme.colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorLight,
              ),
            ),
            counterStyle: TextStyle(
              color: widget.descriptionController.text.length > 450
                  ? Colors.orange
                  : AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        
        if (_showDescriptionError && widget.descriptionController.text.trim().isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Text(
              'Пожалуйста, опишите проблему',
              style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                color: AppTheme.errorLight,
              ),
            ),
          ),
      ],
    );
  }

  String _getSelectedTypeLabel() {
    if (widget.selectedRequestType == null) {
      return 'Выберите тип заявки';
    }
    
    final selectedType = widget.requestTypes.firstWhere(
      (type) => type['value'] == widget.selectedRequestType,
      orElse: () => {'label': 'Выберите тип заявки'},
    );
    
    return selectedType['label'] as String;
  }

  String _getSelectedTypeIcon() {
    if (widget.selectedRequestType == null) {
      return 'build';
    }
    
    final selectedType = widget.requestTypes.firstWhere(
      (type) => type['value'] == widget.selectedRequestType,
      orElse: () => {'icon': 'build'},
    );
    
    return selectedType['icon'] as String;
  }

  void _showRequestTypeDialog(BuildContext context) {
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
                final isSelected = type['value'] == widget.selectedRequestType;
                
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
                    widget.onRequestTypeChanged(type['value'] as String);
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
    setState(() {
      _showRequestTypeError = widget.selectedRequestType == null;
      _showDescriptionError = widget.descriptionController.text.trim().isEmpty;
    });
  }
} 