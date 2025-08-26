
import '../../../core/app_export.dart';

class PhotoCaptureWidget extends StatelessWidget {
  final String meterType;
  final String? capturedPhoto;
  final Function(String?) onPhotoCapture;

  const PhotoCaptureWidget({
    super.key,
    required this.meterType,
    this.capturedPhoto,
    required this.onPhotoCapture,
  });

  void _showCameraOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Сфотографировать счетчик',
              style: AppTheme.lightTheme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Убедитесь, что показания четко видны на фото',
              style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _simulatePhotoCapture('camera');
                    },
                    icon: const CustomIconWidget(
                      iconName: 'camera_alt',
                      color: AppTheme.primaryLight,
                      size: 20,
                    ),
                    label: const Text('Камера'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _simulatePhotoCapture('gallery');
                    },
                    icon: const CustomIconWidget(
                      iconName: 'photo_library',
                      color: AppTheme.primaryLight,
                      size: 20,
                    ),
                    label: const Text('Галерея'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
          ],
        ),
      ),
    );
  }

  void _simulatePhotoCapture(String source) {
    // Simulate photo capture with mock path
    final mockPhotoPath =
        'mock_photos/${meterType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    onPhotoCapture(mockPhotoPath);
  }

  void _showPhotoPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Фото счетчика'),
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: CustomIconWidget(
                  iconName: 'close',
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                  size: 24,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onPhotoCapture(null);
                  },
                  icon: const CustomIconWidget(
                    iconName: 'delete',
                    color: AppTheme.errorLight,
                    size: 24,
                  ),
                ),
              ],
            ),
            Container(
              height: 300,
              width: double.infinity,
              color: AppTheme.lightTheme.colorScheme.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomIconWidget(
                    iconName: 'image',
                    color: AppTheme.textSecondaryLight,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Фото счетчика',
                    style: AppTheme.lightTheme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    capturedPhoto ?? '',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showCameraOptions(context);
                      },
                      child: const Text('Переснять'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фото счетчика',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (capturedPhoto != null) ...[
          // Photo Preview
          GestureDetector(
            onTap: () => _showPhotoPreview(context),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successLight,
                  width: 2,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CustomIconWidget(
                          iconName: 'image',
                          color: AppTheme.successLight,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Фото добавлено',
                          style: AppTheme.lightTheme.textTheme.bodyMedium
                              ?.copyWith(
                            color: AppTheme.successLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const CustomIconWidget(
                        iconName: 'check',
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showCameraOptions(context),
                  icon: const CustomIconWidget(
                    iconName: 'camera_alt',
                    color: AppTheme.primaryLight,
                    size: 16,
                  ),
                  label: const Text('Переснять'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPhotoPreview(context),
                  icon: const CustomIconWidget(
                    iconName: 'visibility',
                    color: AppTheme.primaryLight,
                    size: 16,
                  ),
                  label: const Text('Просмотр'),
                ),
              ),
            ],
          ),
        ] else ...[
          // Capture Button
          GestureDetector(
            onTap: () => _showCameraOptions(context),
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.dividerLight,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CustomIconWidget(
                    iconName: 'add_a_photo',
                    color: AppTheme.textSecondaryLight,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавить фото счетчика',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Рекомендуется для подтверждения',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMediumEmphasisLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
