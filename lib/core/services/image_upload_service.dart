import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:get_it/get_it.dart';
import 'logging_service_secure.dart';

class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  final LoggingService _loggingService;

  ImageUploadService({required LoggingService loggingService}) 
      : _loggingService = loggingService;

  /// Гарантирует аутентификацию пользователя перед загрузкой
  Future<bool> _ensureAuthentication() async {
    try {
      final auth = GetIt.instance<FirebaseAuth>();
      
      // Проверяем текущего пользователя
      if (auth.currentUser != null) {
        return true;
      }
      
      // Выполняем анонимную аутентификацию
      final userCredential = await auth.signInAnonymously();
      return userCredential.user != null;
    } catch (e) {
      _loggingService.error('Authentication failed for image upload', e);
      return false;
    }
  }

  /// Повторяет загрузку с принудительной новой аутентификацией
  Future<String?> _retryWithFreshAuth(String filePath, String uploadPath, String? customName) async {
    try {
      final auth = GetIt.instance<FirebaseAuth>();
      
      // Принудительно выходим и заново аутентифицируемся
      await auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Новая анонимная аутентификация
      final userCredential = await auth.signInAnonymously();
      if (userCredential.user == null) {
        throw Exception('Failed to authenticate');
      }
      
      _loggingService.info('Fresh authentication successful, retrying upload...');
      
      // Повторяем загрузку
      final file = File(filePath);
      final fileName = customName ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}';
      
      final storageRef = _storage.ref().child('$uploadPath/$fileName');
      
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(filePath),
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
            'retryAttempt': 'true',
          },
        ),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      _loggingService.info('Retry upload successful');
      return downloadUrl;
    } catch (e) {
      _loggingService.error('Retry upload failed', e);
      rethrow;
    }
  }

  /// Загружает изображение в Firebase Storage
  /// Возвращает URL загруженного изображения
  Future<String?> uploadImage({
    required String filePath,
    required String uploadPath, // например: 'service_requests/images'
    String? customName,
  }) async {
    try {
      // Гарантируем аутентификацию перед загрузкой
      final isAuthenticated = await _ensureAuthentication();
      if (!isAuthenticated) {
        throw Exception('Authentication required for image upload');
      }
      
      // Проверяем что файл существует
      final file = File(filePath);
      if (!await file.exists()) {
        _loggingService.error('File does not exist: $filePath');
        return null;
      }

      // Генерируем уникальное имя файла
      final fileName = customName ?? 
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}';
      
      // Создаем ссылку на файл в Storage
      final storageRef = _storage.ref().child('$uploadPath/$fileName');
      
      _loggingService.info('Uploading image to Storage: $uploadPath/$fileName');
      
      // Загружаем файл
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: _getContentType(filePath),
          customMetadata: {
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Ждем завершения загрузки
      final snapshot = await uploadTask;
      
      // Получаем URL загруженного файла
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      _loggingService.info('Image uploaded successfully');
      
      return downloadUrl;
    } catch (e) {
      _loggingService.error('Failed to upload image', e);
      
      // Дополнительная информация для основных типов ошибок
      if (e.toString().contains('firebase_storage/unauthorized')) {
        _loggingService.error('Storage authorization error - check Firebase Auth status');
      } else if (e.toString().contains('Permission denied')) {
        _loggingService.error('Storage permission denied - check Storage rules');
      } else if (e.toString().contains('service account') || e.toString().contains('412')) {
        _loggingService.warning('Firebase Storage configuration issue - HTTP 412: ${e.toString()}');
        
        // Повторяем попытку с принудительной аутентификацией
        try {
          _loggingService.info('Retrying upload with fresh authentication...');
          await _retryWithFreshAuth(filePath, uploadPath, customName);
        } catch (retryError) {
          _loggingService.error('Retry failed, using local fallback', retryError);
          return 'local://$filePath';
        }
      }
      
      return null;
    }
  }

  /// Загружает несколько изображений и возвращает список URL
  Future<List<String>> uploadMultipleImages({
    required List<String> filePaths,
    required String uploadPath,
    String? namePrefix,
  }) async {
    final List<String> uploadedUrls = [];
    
    _loggingService.info('Starting batch upload of ${filePaths.length} images');
    
    for (int i = 0; i < filePaths.length; i++) {
      final filePath = filePaths[i];
      final customName = namePrefix != null 
          ? '${namePrefix}_${i + 1}_${DateTime.now().millisecondsSinceEpoch}'
          : null;
      
      final url = await uploadImage(
        filePath: filePath,
        uploadPath: uploadPath,
        customName: customName,
      );
      
      if (url != null) {
        uploadedUrls.add(url);
      } else {
        _loggingService.warning('Failed to upload image $i: $filePath');
      }
    }
    
    _loggingService.info('Batch upload completed: ${uploadedUrls.length}/${filePaths.length} successful');
    
    return uploadedUrls;
  }

  /// Удаляет изображение из Firebase Storage
  Future<bool> deleteImage(String downloadUrl) async {
    try {
      _loggingService.info('Deleting image: $downloadUrl');
      
      // Получаем ссылку на файл из URL
      final storageRef = _storage.refFromURL(downloadUrl);
      
      // Удаляем файл
      await storageRef.delete();
      
      _loggingService.info('Image deleted successfully');
      return true;
    } catch (e) {
      _loggingService.error('Failed to delete image', e);
      return false;
    }
  }

  /// Определяет MIME тип файла по расширению
  String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg'; // По умолчанию
    }
  }

  /// Создает уникальный путь для заявки на обслуживание
  static String createServiceRequestPath(String requestId) {
    return 'service_requests/$requestId/images';
  }

  /// Создает уникальный путь для профиля пользователя
  static String createUserProfilePath(String userId) {
    return 'users/$userId/profile';
  }

  /// Создает уникальный путь для показаний счетчиков
  static String createUtilityReadingPath(String readingId) {
    return 'utility_readings/$readingId/images';
  }
} 