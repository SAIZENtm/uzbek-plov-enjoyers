import 'package:intl/intl.dart';
import 'package:newport_resident/core/app_export.dart';

/// A card with a blue-cyan gradient that displays the account balance.
/// It includes a shimmer animation when refreshing and a subtle tilt effect on tap.
class AnimatedBalanceCard extends StatefulWidget {
  final int balance;
  final DateTime lastUpdated;
  final bool isRefreshing;
  final VoidCallback onTap;

  const AnimatedBalanceCard({
    super.key,
    required this.balance,
    required this.lastUpdated,
    required this.isRefreshing,
    required this.onTap,
  });

  @override
  State<AnimatedBalanceCard> createState() => _AnimatedBalanceCardState();
}

class _AnimatedBalanceCardState extends State<AnimatedBalanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isRefreshing) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBalanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRefreshing) {
      _shimmerController.repeat();
    } else {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: 'сум',
      decimalDigits: 0,
    );
    final formattedBalance = currencyFormatter.format(widget.balance);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2196F3), // Blue
              Color(0xFF00BCD4), // Cyan
              Color(0xFF03A9F4), // Light Blue
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withAlpha(77), // 0.3 opacity
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: const Color(0xFF00BCD4).withAlpha(51), // 0.2 opacity
              blurRadius: 15,
              offset: const Offset(0, 5),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Текущий баланс',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withAlpha(230), // 0.9 opacity
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedBalance,
                  style: AppTheme.lightTheme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black.withAlpha(25), // 0.1 opacity
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Последнее обновление: ${DateFormat('HH:mm, dd MMM', 'ru').format(widget.lastUpdated)}',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withAlpha(204), // 0.8 opacity
                  ),
                ),
              ],
            ),
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      final shimmerWidth = constraints.maxWidth;
                      return Transform.translate(
                        offset: Offset(
                            -shimmerWidth + (_shimmerController.value * 2 * shimmerWidth),
                            0),
                        child: child,
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(0), // 0.0 opacity
                            Colors.white.withAlpha(51), // 0.2 opacity
                            Colors.white.withAlpha(0), // 0.0 opacity
                          ],
                          stops: const [0.4, 0.5, 0.6],
                          begin: const Alignment(-1.0, -0.3),
                          end: const Alignment(1.0, 0.3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
} 