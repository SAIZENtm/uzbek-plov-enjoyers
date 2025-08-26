import 'package:newport_resident/core/app_export.dart';

class QuickAccessItem {
  final String id;
  final IconData icon;
  final String label;

  const QuickAccessItem({required this.id, required this.icon, required this.label});
}

class HorizontalQuickAccess extends StatelessWidget {
  final List<QuickAccessItem> items;
  final Function(String) onServiceTap;

  const HorizontalQuickAccess({
    super.key,
    required this.items,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          return _QuickAccessIcon(
            item: item,
            onTap: () => onServiceTap(item.id),
          );
        },
      ),
    );
  }
}

class _QuickAccessIcon extends StatefulWidget {
  final QuickAccessItem item;
  final VoidCallback onTap;

  const _QuickAccessIcon({required this.item, required this.onTap});

  @override
  State<_QuickAccessIcon> createState() => _QuickAccessIconState();
}

class _QuickAccessIconState extends State<_QuickAccessIcon> {
  double _scale = 1.0;

  void _onTapDown(_) {
    setState(() => _scale = 0.9);
  }

  void _onTapUp(_) {
    setState(() => _scale = 1.0);
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _onTapUp(null),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(13), // 0.05 opacity
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                widget.item.icon,
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.item.label,
              style: AppTheme.lightTheme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
} 