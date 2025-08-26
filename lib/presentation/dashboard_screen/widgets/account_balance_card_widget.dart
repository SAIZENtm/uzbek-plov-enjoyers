
import '../../../core/app_export.dart';

class AccountBalanceCardWidget extends StatelessWidget {
  final int balance;
  final DateTime lastUpdated;
  final bool isRefreshing;
  final VoidCallback onTap;

  const AccountBalanceCardWidget({
    super.key,
    required this.balance,
    required this.lastUpdated,
    required this.isRefreshing,
    required this.onTap,
  });

  String _formatBalance(int amount) {
    final absAmount = amount.abs();
    final formatted = absAmount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
    return formatted.trim();
  }

  Color _getBalanceColor(BuildContext context) {
    if (balance > 0) {
      return AppTheme.successLight;
    } else if (balance < 0) {
      return AppTheme.errorLight;
    } else {
      return Theme.of(context).colorScheme.onSurface;
    }
  }

  String _getBalanceLabel() {
    if (balance > 0) {
      return 'Переплата';
    } else if (balance < 0) {
      return 'Задолженность';
    } else {
      return 'Баланс';
    }
  }

  String _formatLastUpdated() {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inMinutes < 1) {
      return 'Только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else {
      return '${difference.inDays} дн назад';
    }
  }

  LinearGradient _buildGradient() {
    if (balance < 0) {
      return LinearGradient(
        colors: [
          AppTheme.errorLight.withAlpha(38), // 0.15 opacity
          AppTheme.errorLight.withAlpha(13), // 0.05 opacity
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (balance > 0) {
      return LinearGradient(
        colors: [
          AppTheme.successLight.withAlpha(38), // 0.15 opacity
          AppTheme.successLight.withAlpha(13), // 0.05 opacity
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return LinearGradient(
        colors: [
          AppTheme.textSecondaryLight.withAlpha(38), // 0.15 opacity
          AppTheme.textSecondaryLight.withAlpha(13), // 0.05 opacity
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBalanceColor(context);

    return Hero(
      tag: 'balanceCard',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            gradient: _buildGradient(),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getBalanceLabel(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                  ),
                  if (isRefreshing)
                    SizedBox(
                      width: 5.w,
                      height: 5.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    )
                  else
                    CustomIconWidget(
                      iconName: 'account_balance_wallet',
                      color: color,
                      size: 24,
                    ),
                ],
              ),
              SizedBox(height: 3.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (balance < 0)
                    Text(
                      '-',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  Flexible(
                    child: Text(
                      _formatBalance(balance),
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 48,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 1.w),
                  Padding(
                    padding: EdgeInsets.only(bottom: 0.8.h),
                    child: Text(
                      'сум',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  CustomIconWidget(
                    iconName: 'access_time',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 16,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    'Обновлено ${_formatLastUpdated()}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
