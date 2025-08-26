
import 'package:image_picker/image_picker.dart';
import '../../../core/app_export.dart';

class PhotoAttachmentWidget extends StatelessWidget {
  final List<String> attachedPhotos;
  final ValueChanged<List<String>> onPhotosChanged;

  const PhotoAttachmentWidget({
    super.key,
    required this.attachedPhotos,
    required this.onPhotosChanged,
  });

  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Добавить фото',
                style: AppTheme.lightTheme.textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: 'camera_alt',
                      label: 'Камера',
                      onTap: () => _pickFromCamera(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPickerOption(
                      context,
                      icon: 'photo_library',
                      label: 'Галерея',
                      onTap: () => _pickFromGallery(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPickerOption(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppTheme.lightTheme.dividerColor,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            CustomIconWidget(
              iconName: icon,
              color: AppTheme.lightTheme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.lightTheme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _pickFromCamera(BuildContext context) async {
    Navigator.pop(context);
    await _pickImageWithSource(ImageSource.camera);
  }

  void _pickFromGallery(BuildContext context) async {
    Navigator.pop(context);
    await _pickImageWithSource(ImageSource.gallery);
  }

  Future<void> _pickImageWithSource(ImageSource source) async {
    if (attachedPhotos.length >= 3) return;

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920, // Убираем ограничение соотношения сторон
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (image != null) {
        // Временно добавляем локальный путь
        final newPhotos = List<String>.from(attachedPhotos);
        newPhotos.add(image.path);
        onPhotosChanged(newPhotos);

        // Загружаем в Firebase Storage
        final imageUploadService = GetIt.instance<ImageUploadService>();
        final requestId = DateTime.now().millisecondsSinceEpoch.toString();
        final uploadPath = 'service_requests/$requestId/images';
        
        final downloadUrl = await imageUploadService.uploadImage(
          filePath: image.path,
          uploadPath: uploadPath,
          customName: 'image_${newPhotos.length}',
        );

        if (downloadUrl != null) {
          // Заменяем локальный путь на Firebase URL
          final updatedPhotos = List<String>.from(newPhotos);
          updatedPhotos[updatedPhotos.length - 1] = downloadUrl;
          onPhotosChanged(updatedPhotos);
        }
      }
    } catch (e) {
      // Handle error silently for now
      print('Error picking image: $e');
    }
  }

  void _removePhoto(int index) {
    final newPhotos = List<String>.from(attachedPhotos);
    newPhotos.removeAt(index);
    onPhotosChanged(newPhotos);
  }

  String _getPhotoCountText(int count) {
    if (count == 1) {
      return 'фото';
    } else if (count >= 2 && count <= 4) {
      return 'фото';
    } else {
      return 'фото';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showImagePickerOptions(context),
                  icon: CustomIconWidget(
                    iconName: 'add_a_photo',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 20,
                  ),
                  label: const Text('Добавить фото'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (attachedPhotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Прикреплено ${attachedPhotos.length} ${_getPhotoCountText(attachedPhotos.length)}',
              style: AppTheme.lightTheme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: attachedPhotos.asMap().entries.map((entry) {
                final index = entry.key;
                final photoUrl = entry.value;
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.lightTheme.dividerColor,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: CustomImageWidget(
                          imageUrl: photoUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removePhoto(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorLight,
                            shape: BoxShape.circle,
                          ),
                          child: const CustomIconWidget(
                            iconName: 'close',
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
