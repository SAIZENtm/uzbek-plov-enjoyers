
import '../../../core/app_export.dart';
import '../../../widgets/blue_text_field.dart';

class ApartmentInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final Function(String)? onFieldSubmitted;

  const ApartmentInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    this.errorText,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Номер квартиры',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 1.h),
        BlueTextField(
          controller: controller,
          focusNode: focusNode,
          labelText: 'Номер квартиры',
          hintText: 'Например: 101',
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (_) => errorText,
          prefixIcon: Padding(
            padding: EdgeInsets.all(3.w),
            child: CustomIconWidget(
              iconName: 'home',
              color: errorText != null
                  ? AppTheme.errorLight
                  : AppTheme.textSecondaryLight,
              size: 6.w,
            ),
          ),
          maxLines: 1,
        ),
      ],
    );
  }
}
