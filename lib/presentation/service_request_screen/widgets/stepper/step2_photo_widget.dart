import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/app_export.dart';

class Step2PhotoWidget extends StatefulWidget {
  final List<String> attachedPhotos;
  final ValueChanged<List<String>> onPhotosChanged;

  const Step2PhotoWidget({
    super.key,
    required this.attachedPhotos,
    required this.onPhotosChanged,
  });

  @override
  State<Step2PhotoWidget> createState() => _Step2PhotoWidgetState();
}

class _Step2PhotoWidgetState extends State<Step2PhotoWidget> {
  final ImagePicker _picker = ImagePicker();
  final List<String> _photoUrls = [];
  final List<String> _localPaths = []; // Храним локальные пути для предпросмотра
  bool _isLoading = false;
  
  late final ImageUploadService _imageUploadService;
  late final LoggingService _loggingService;

  @override
  void initState() {
    super.initState();
    _imageUploadService = GetIt.instance<ImageUploadService>();
    _loggingService = GetIt.instance<LoggingService>();
    
    _photoUrls.addAll(widget.attachedPhotos);
    // Если есть уже загруженные фото, добавляем их как URL
    _localPaths.addAll(widget.attachedPhotos);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Фотографии',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        const Text(
          'Добавьте фотографии проблемы (необязательно)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        
        // Photo Grid
        if (_photoUrls.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _photoUrls.length,
            itemBuilder: (context, index) {
              return _buildPhotoItem(index);
            },
          ),
        
        const SizedBox(height: 16),
        
        // Add Photo Button
        if (_photoUrls.length < 3)
          InkWell(
            onTap: _isLoading ? null : _showImageSourceDialog,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'add_photo_alternate',
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавить фото',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.lightTheme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_photoUrls.length}/3',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoItem(int index) {
    final photoPath = index < _localPaths.length ? _localPaths[index] : _photoUrls[index];
    final isUploaded = _photoUrls[index].startsWith('https://firebasestorage.googleapis.com');
    
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUploaded 
                  ? Colors.green 
                  : AppTheme.lightTheme.colorScheme.outline,
              width: isUploaded ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              children: [
                photoPath.startsWith('http')
                    ? Image.network(
                        photoPath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(photoPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                // Индикатор загрузки
                if (!isUploaded)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                // Индикатор успешной загрузки
                if (isUploaded)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: () => _removePhoto(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выберите источник'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Камера'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Галерея'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_photoUrls.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Можно прикрепить максимум 3 фотографии'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920, // Убираем ограничение соотношения сторон
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (image != null) {
        _loggingService.info('Image selected: ${image.path}');
        
        // Добавляем локальный путь для предпросмотра
        setState(() {
          _localPaths.add(image.path);
          _photoUrls.add(image.path); // Временно добавляем локальный путь
        });
        
        // Показываем загрузку пользователю
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Загружаем фотографию...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Загружаем в Firebase Storage в фоне
        _uploadImageToFirebase(image.path, _photoUrls.length - 1);
        
        // Уведомляем родительский виджет о временном изменении
        widget.onPhotosChanged(_photoUrls);
      }
    } catch (e) {
      _loggingService.error('Error picking image', e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе изображения: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Загружает изображение в Firebase Storage
  Future<void> _uploadImageToFirebase(String localPath, int index) async {
    try {
      _loggingService.info('Starting Firebase upload for image $index');
      
      // Создаем уникальный путь для заявки
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final uploadPath = ImageUploadService.createServiceRequestPath(requestId);
      
      // Загружаем изображение
      final downloadUrl = await _imageUploadService.uploadImage(
        filePath: localPath,
        uploadPath: uploadPath,
        customName: 'image_${index + 1}',
      );

      if (downloadUrl != null) {
        // Заменяем локальный путь на URL Firebase Storage
        setState(() {
          if (index < _photoUrls.length) {
            _photoUrls[index] = downloadUrl;
          }
        });
        
        // Уведомляем родительский виджет об обновленном URL
        widget.onPhotosChanged(_photoUrls);
        
        _loggingService.info('Image uploaded successfully: $downloadUrl');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Фотография загружена успешно'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        _loggingService.error('Failed to upload image to Firebase Storage');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось загрузить в облако, но фото сохранено локально'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      _loggingService.error('Exception during Firebase upload', e);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) async {
    if (index >= 0 && index < _photoUrls.length) {
      final photoUrl = _photoUrls[index];
      
      // Если это URL Firebase Storage, удаляем файл
      if (photoUrl.startsWith('https://firebasestorage.googleapis.com')) {
        try {
          await _imageUploadService.deleteImage(photoUrl);
          _loggingService.info('Image deleted from Firebase Storage: $photoUrl');
        } catch (e) {
          _loggingService.error('Failed to delete image from Firebase Storage', e);
          // Продолжаем удаление из UI даже если удаление из Storage не удалось
        }
      }
      
      setState(() {
        _photoUrls.removeAt(index);
        if (index < _localPaths.length) {
          _localPaths.removeAt(index);
        }
      });
      
      widget.onPhotosChanged(_photoUrls);
    }
  }
} 