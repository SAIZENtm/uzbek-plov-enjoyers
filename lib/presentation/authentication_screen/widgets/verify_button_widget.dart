import 'package:flutter/material.dart';


import '../../../core/app_export.dart';
import '../../../widgets/blue_button.dart';

class VerifyButtonWidget extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String text;

  const VerifyButtonWidget({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return BlueButton(
      text: text,
      isLoading: isLoading,
      icon: text == 'Войти' ? Icons.verified_user : Icons.sms,
      onPressed: onPressed,
    );
  }
}
