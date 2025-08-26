import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_export.dart';
import '../../core/models/news_article_model.dart';
import '../../widgets/premium_card.dart';
import '../shared/widgets/optimized_image.dart';

class NewsDetailScreen extends StatefulWidget {
  final String newsId;
  
  const NewsDetailScreen({super.key, required this.newsId});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with SingleTickerProviderStateMixin {
  final NewsService _newsService = GetIt.instance<NewsService>();
  final UnreadTracker _unreadTracker = GetIt.instance<UnreadTracker>();
  NewsArticle? _article;
  bool _isLoading = true;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadArticle();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadArticle() async {
    try {
      final article = await _newsService.fetchNewsById(widget.newsId);
      if (article != null) {
        await _unreadTracker.markAsRead(widget.newsId);
        
        if (mounted) {
          setState(() {
            _article = article;
            _isLoading = false;
          });
          _animationController.forward();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchCTA(String url) async {
    try {
      if (url.startsWith('/')) {
        context.go(url);
      } else if (url.startsWith('tel:')) {
        await launchUrl(Uri.parse(url));
      } else {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть ссылку: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.offWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.charcoal,
          ),
          onPressed: () => context.pop(),
        ),
        title: _article != null
            ? Text(
                'Новость',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: AppTheme.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.newportPrimary,
              ),
            )
          : _article == null
              ? _buildNotFoundState()
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildArticleContent(),
                  ),
                ),
    );
  }

  Widget _buildNotFoundState() {
    return Center(
      child: PremiumCard(
        margin: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.mediumGray.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 40,
                color: AppTheme.mediumGray,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Новость не найдена',
              style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Возможно, она была удалена\nили перемещена',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.mediumGray,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PremiumButton(
              text: 'Назад к новостям',
              icon: Icons.arrow_back,
              onPressed: () => context.pop(),
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero image section
          if (_article!.imageUrl != null && _article!.imageUrl!.isNotEmpty)
            _buildHeroImage(),
          
          // Content section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildArticleHeader(),
                const SizedBox(height: 24),
                _buildArticleBodyContent(),
                if (_article!.ctaLabels.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _buildCTASection(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: OptimizedImage(
              imageUrl: _article!.imageUrl!,
              width: double.infinity,
              height: 250,
              fit: BoxFit.cover,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
          // Gradient overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status indicators and date
        Row(
          children: [
            if (_article!.isImportant)
              const PremiumStatusChip(
                status: 'important',
                customText: 'Важно',
                customColor: AppTheme.errorRed,
              ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: AppTheme.mediumGray,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('d MMMM yyyy, HH:mm', 'ru').format(_article!.publishedAt),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mediumGray,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Title
        Text(
          _article!.title,
          style: AppTheme.lightTheme.textTheme.displayMedium?.copyWith(
            color: AppTheme.charcoal,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        
        // Preview/subtitle
        if (_article!.preview.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            _article!.preview,
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              color: AppTheme.darkGray,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildArticleBodyContent() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(24),
      child: MarkdownWidget(
        data: _article!.content,
        shrinkWrap: true,
        selectable: true,
        config: MarkdownConfig(
          configs: [
            PConfig(
              textStyle: AppTheme.lightTheme.textTheme.bodyLarge!.copyWith(
                height: 1.6,
                color: AppTheme.darkGray,
              ),
            ),
            H1Config(
              style: AppTheme.lightTheme.textTheme.headlineMedium!.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w700,
              ),
            ),
            H2Config(
              style: AppTheme.lightTheme.textTheme.headlineSmall!.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
            H3Config(
              style: AppTheme.lightTheme.textTheme.titleLarge!.copyWith(
                color: AppTheme.charcoal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCTASection() {
    return PremiumCard(
      margin: EdgeInsets.zero,
      backgroundColor: AppTheme.lightGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.touch_app_outlined,
                color: AppTheme.newportPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Полезные ссылки',
                style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_article!.ctaLabels.length, (index) {
            if (index < _article!.ctaLinks.length) {
              final label = _article!.ctaLabels[index];
              final link = _article!.ctaLinks[index];
              final isExternal = _article!.ctaType == 'external';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PremiumButton(
                  text: label,
                  icon: isExternal
                      ? Icons.open_in_new
                      : link.startsWith('tel:')
                          ? Icons.phone_outlined
                          : Icons.arrow_forward_outlined,
                  onPressed: () => _launchCTA(link),
                  isPrimary: index == 0, // First button is primary
                ),
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
} 