import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/app_export.dart';

/// Оптимизированный виджет для загрузки изображений с кэшированием и улучшенной производительностью
class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useFadeIn;
  final Duration fadeInDuration;

  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.useFadeIn = true,
    this.fadeInDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: useFadeIn ? fadeInDuration : Duration.zero,
        memCacheWidth: width != null && width!.isFinite ? width!.toInt() : null,
        memCacheHeight: height != null && height!.isFinite ? height!.toInt() : null,
        maxWidthDiskCache: 800, // Ограничиваем размер кэша
        maxHeightDiskCache: 600,
        httpHeaders: const {
          'User-Agent': 'Newport Resident App/1.0',
        },
        placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) => errorWidget ?? _buildDefaultError(),
      ),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.newportPrimary.withValues(alpha: 0.1),
            AppTheme.newportSecondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.newportPrimary),
        ),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.newportPrimary.withValues(alpha: 0.1),
            AppTheme.newportSecondary.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.image_not_supported_outlined,
            size: 32,
            color: AppTheme.mediumGray,
          ),
          const SizedBox(height: 8),
          Text(
            'Изображение недоступно',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.mediumGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Специализированный виджет для изображений новостей с оптимизированными размерами
class NewsImageWidget extends StatelessWidget {
  final String imageUrl;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  const NewsImageWidget({
    Key? key,
    required this.imageUrl,
    this.aspectRatio = 16 / 9,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: OptimizedImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width / aspectRatio,
      ),
    );
  }
}
