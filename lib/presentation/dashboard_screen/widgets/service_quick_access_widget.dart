
import '../../../core/app_export.dart';

class ServiceQuickAccessWidget extends StatelessWidget {
  final Map<String, String> lastActivity;
  final Function(String) onServiceTap;

  const ServiceQuickAccessWidget({
    super.key,
    required this.lastActivity,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final services = [
      {
        'key': 'maintenance',
        'title': 'Ремонт',
        'icon': 'build',
        'color': AppTheme.lightTheme.colorScheme.secondary,
      },
      {
        'key': 'utility',
        'title': 'Счётчики',
        'icon': 'speed',
        'color': AppTheme.lightTheme.colorScheme.tertiary,
      },
      {
        'key': 'guest',
        'title': 'Пропуск',
        'icon': 'badge',
        'color': AppTheme.warningLight,
      },
      {
        'key': 'properties',
        'title': 'Недвижимость',
        'icon': 'home',
        'color': AppTheme.successLight,
      },
    ];

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 3.h,
      children: services.map((service) {
        final color = service['color'] as Color;
        final lastActivityText =
            lastActivity[service['key']] ?? '—';
        return SizedBox(
          width: 21.w,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => onServiceTap(service['key'] as String),
                child: Container(
                  width: 18.w,
                  height: 18.w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withAlpha(38), // 0.15 opacity
                        color.withAlpha(13), // 0.05 opacity
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CustomIconWidget(
                      iconName: service['icon'] as String,
                      color: color,
                      size: 24,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                service['title'] as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 0.3.h),
              Text(
                lastActivityText,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
