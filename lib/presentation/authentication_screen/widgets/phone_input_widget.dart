
import '../../../core/app_export.dart';
import '../../../widgets/blue_text_field.dart';

class PhoneInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final Function(String)? onChanged;
  final Function(String)? onFieldSubmitted;

  const PhoneInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.errorText,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Номер телефона',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        BlueTextField(
          controller: controller,
          focusNode: focusNode,
          labelText: 'Номер телефона',
          keyboardType: TextInputType.phone,
          hintText: '+998 90 123 45 67',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d+\s]')),
            LengthLimitingTextInputFormatter(17),
          ],
          validator: (_) => errorText,
          prefixIcon: Padding(
            padding: EdgeInsets.all(3.w),
            child: CustomIconWidget(
              iconName: 'phone',
              color: errorText != null
                  ? AppTheme.errorLight
                  : AppTheme.textSecondaryLight,
              size: 6.w,
            ),
          ),
          maxLines: 1,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
        ),
      ],
    );
  }
}
