
import '../../../core/app_export.dart';

class SubmissionStatusWidget extends StatelessWidget {
  final DateTime deadline;
  final String timeRemaining;

  const SubmissionStatusWidget({
    super.key,
    required this.deadline,
    required this.timeRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = DateTime.now().isAfter(deadline);
    final isUrgent = DateTime.now().add(const Duration(days: 2)).isAfter(deadline);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverdue
            ? AppTheme.errorLight.withValues(alpha: 0.1)
            : isUrgent
                ? AppTheme.warningLight.withValues(alpha: 0.1)
                : AppTheme.successLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? AppTheme.errorLight
              : isUrgent
                  ? AppTheme.warningLight
                  : AppTheme.successLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOverdue
                  ? AppTheme.errorLight
                  : isUrgent
                      ? AppTheme.warningLight
                      : AppTheme.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomIconWidget(
              iconName: isOverdue
                  ? 'error'
                  : isUrgent
                      ? 'schedule'
                      : 'check_circle',
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue
                      ? 'Срок подачи истек'
                      : 'Подача показаний до 20 числа',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: isOverdue
                        ? AppTheme.errorLight
                        : isUrgent
                            ? AppTheme.warningLight
                            : AppTheme.successLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOverdue
                      ? 'Обратитесь в управляющую компанию'
                      : 'Осталось: $timeRemaining',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
