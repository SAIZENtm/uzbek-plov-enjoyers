import '../../../widgets/frosted_glass_card.dart';
import '../../../core/app_export.dart';

class ServiceCategoryCardWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final int? badgeCount;
  final VoidCallback onTap;

  const ServiceCategoryCardWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<ServiceCategoryCardWidget> createState() => _ServiceCategoryCardWidgetState();
}

class _ServiceCategoryCardWidgetState extends State<ServiceCategoryCardWidget> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _onTapDown(_) {
    setState(() => _scale = 0.95);
  }

  void _onTapUp(_) {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.lightTheme;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapCancel: () => _onTapUp(null),
      onTapUp: _onTapUp,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _scale,
        curve: Curves.easeOut,
        child: SizedBox(
          width: 28.w,
          child: FrostedGlassCard(
            padding: EdgeInsets.symmetric(vertical: 3.h),
            borderRadius: 18,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 28.sp, color: theme.colorScheme.primary),
                    SizedBox(height: 1.h),
                    Text(
                      widget.title,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (widget.badgeCount != null && widget.badgeCount! > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      child: Text(
                        widget.badgeCount!.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 