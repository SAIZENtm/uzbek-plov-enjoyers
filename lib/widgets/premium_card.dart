import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium card widget with clean Apple-inspired design
/// Features subtle shadows, rounded corners, and premium spacing
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final bool showBorder;
  final Color? borderColor;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.shadows,
    this.onTap,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? 20.0;
    final effectivePadding = padding ?? const EdgeInsets.all(20);
    final effectiveMargin = margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    final effectiveBackgroundColor = backgroundColor ?? AppTheme.pureWhite;

    return Container(
      margin: effectiveMargin,
      child: Material(
        color: effectiveBackgroundColor,
        borderRadius: BorderRadius.circular(effectiveBorderRadius),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(effectiveBorderRadius),
              border: showBorder
                  ? Border.all(
                      color: borderColor ?? AppTheme.neutralGray,
                      width: 0.5,
                    )
                  : null,
              boxShadow: shadows ?? AppTheme.cardShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Premium button with Newport brand styling
class PremiumButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isPrimary;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const PremiumButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isPrimary = true,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    _animationController.forward();
  }

  void _onTapUp(_) {
    _animationController.reverse();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final effectivePadding = widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    final effectiveBorderRadius = widget.borderRadius ?? 16.0;
    
    Color effectiveBackgroundColor;
    Color effectiveForegroundColor;
    
    if (widget.isPrimary) {
      effectiveBackgroundColor = widget.backgroundColor ?? AppTheme.newportPrimary;
      effectiveForegroundColor = widget.foregroundColor ?? AppTheme.pureWhite;
    } else {
      effectiveBackgroundColor = widget.backgroundColor ?? AppTheme.pureWhite;
      effectiveForegroundColor = widget.foregroundColor ?? AppTheme.newportPrimary;
    }

    return GestureDetector(
      onTapDown: widget.onPressed != null ? _onTapDown : null,
      onTapUp: widget.onPressed != null ? _onTapUp : null,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              padding: effectivePadding,
              decoration: BoxDecoration(
                color: effectiveBackgroundColor,
                borderRadius: BorderRadius.circular(effectiveBorderRadius),
                border: !widget.isPrimary
                    ? Border.all(color: AppTheme.newportPrimary, width: 1.5)
                    : null,
                boxShadow: widget.isPrimary ? AppTheme.buttonShadow : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isLoading ? null : widget.onPressed,
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              effectiveForegroundColor,
                            ),
                          ),
                        )
                      else if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: effectiveForegroundColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (!widget.isLoading)
                        Text(
                          widget.text,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: effectiveForegroundColor,
                            fontFamily: 'Aeroport',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Premium input field with clean design
class PremiumTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool enabled;
  final int? maxLines;

  const PremiumTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.enabled = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.darkGray,
              fontFamily: 'Aeroport',
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onChanged: onChanged,
          enabled: enabled,
          maxLines: maxLines,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppTheme.charcoal,
            fontFamily: 'Aeroport',
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: AppTheme.mediumGray)
                : null,
            suffixIcon: suffixIcon != null
                ? GestureDetector(
                    onTap: onSuffixIconTap,
                    child: Icon(suffixIcon, color: AppTheme.mediumGray),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Premium status chip with semantic colors
class PremiumStatusChip extends StatelessWidget {
  final String status;
  final String? customText;
  final Color? customColor;

  const PremiumStatusChip({
    super.key,
    required this.status,
    this.customText,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? AppTheme.getStatusColor(status);
    final text = customText ?? _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: 'Aeroport',
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'success':
      case 'paid':
      case 'completed':
        return 'Выполнено';
      case 'pending':
      case 'in_progress':
        return 'В работе';
      case 'error':
      case 'failed':
        return 'Ошибка';
      case 'new':
        return 'Новое';
      default:
        return status;
    }
  }
} 