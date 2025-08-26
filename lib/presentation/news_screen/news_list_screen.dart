import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../core/app_export.dart';
import '../../core/models/news_article_model.dart';
import '../../widgets/premium_card.dart';
import '../shared/widgets/optimized_image.dart';

class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  late final NewsService _newsService;
  late final UnreadTracker _unreadTracker;
  late Stream<List<NewsArticle>> _newsStream;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _newsService = GetIt.instance<NewsService>();
    _unreadTracker = GetIt.instance<UnreadTracker>();
    _newsStream = _newsService.newsStream;
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      await _newsService.fetchLatestNews(forceRefresh: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: Text(
          'Новости сообщества',
          style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
            color: AppTheme.charcoal,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        actions: [
          AnimatedBuilder(
            animation: _unreadTracker,
            builder: (context, child) {
              final unreadCount = _unreadTracker.unreadCount;
              if (unreadCount > 0) {
                return Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.newportPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$unreadCount новых',
                    style: const TextStyle(
                      color: AppTheme.pureWhite,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppTheme.newportPrimary,
        child: StreamBuilder<List<NewsArticle>>(
          stream: _newsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !_isRefreshing) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.newportPrimary,
                ),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final news = snapshot.data ?? [];
            if (news.isEmpty) {
              return _buildEmptyState();
            }

            return AnimationLimiter(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: news.length,
                itemBuilder: (context, index) {
                  final article = news[index];
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _NewsCard(
                            article: article,
                            unreadTracker: _unreadTracker,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 48,
                color: AppTheme.mediumGray,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Новостей пока нет',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Здесь будут появляться актуальные\nобъявления и новости комплекса',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PremiumButton(
              text: 'Обновить',
              icon: Icons.refresh,
              onPressed: _refresh,
              isPrimary: false,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.wifi_off_outlined,
                size: 48,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Не удалось загрузить новости',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Проверьте подключение к интернету\nи попробуйте снова',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PremiumButton(
              text: 'Попробовать снова',
              icon: Icons.refresh,
              onPressed: _refresh,
              isLoading: _isRefreshing,
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium news card with clean design and status indicators
class _NewsCard extends StatefulWidget {
  final NewsArticle article;
  final UnreadTracker unreadTracker;
  
  const _NewsCard({
    required this.article,
    required this.unreadTracker,
  });

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard>
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
      end: 0.98,
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.unreadTracker.isUnreadStream(widget.article.id),
      builder: (context, snapshot) {
        final isUnread = snapshot.data ?? false;
        
        return GestureDetector(
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) {
            _animationController.reverse();
            context.go('/news/${widget.article.id}');
          },
          onTapCancel: () => _animationController.reverse(),
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  borderColor: isUnread 
                      ? AppTheme.newportPrimary.withValues(alpha: 0.3)
                      : AppTheme.lightGray,
                  backgroundColor: isUnread 
                      ? AppTheme.pureWhite 
                      : AppTheme.pureWhite.withValues(alpha: 0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status and date
                      Row(
                        children: [
                          if (widget.article.isImportant)
                            const PremiumStatusChip(
                              status: 'important',
                              customText: 'Важно',
                              customColor: AppTheme.errorRed,
                            ),
                          if (widget.article.isImportant && isUnread)
                            const SizedBox(width: 8),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.newportPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const Spacer(),
                          Text(
                            _formatDate(widget.article.publishedAt),
                            style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.mediumGray,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Article image if available
                      if (widget.article.imageUrl != null && widget.article.imageUrl!.isNotEmpty) ...[
                        NewsImageWidget(
                          imageUrl: widget.article.imageUrl!,
                          aspectRatio: 16 / 9,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Title
                      Text(
                        widget.article.title,
                        style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.charcoal,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      
                      // Preview text
                      if (widget.article.preview.isNotEmpty)
                        Text(
                          widget.article.preview,
                          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.darkGray,
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Read more indicator
                      Row(
                        children: [
                          Text(
                            'Читать полностью',
                            style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                              color: AppTheme.newportPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: AppTheme.newportPrimary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} мин назад';
      }
      return '${difference.inHours} ч назад';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
} 