import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'cache_service.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';
import 'local_notification_service.dart';


class ServiceRequestService {
  static const String _requestsKey = 'service_requests';
  static const String _feedbackKey = 'feedback';

  static const String _webhookUrl = 'https://your-website.com/api/service-requests'; // Замените на ваш URL
  static const bool _enableExternalWebhook = false; // Отключено пока URL не настроен
  
  final ApiService apiService;
  final CacheService cacheService;
  final LoggingService loggingService;
  late final FirebaseFirestore _firestore;
  late final AuthService _authService;
  final Dio _dio = Dio();

  ServiceRequestService({
    required this.apiService,
    required this.cacheService,
    required this.loggingService,
  }) {
    try {
      _firestore = GetIt.instance<FirebaseFirestore>();
      _authService = GetIt.instance<AuthService>();
    } catch (e) {
      loggingService.error('Failed to initialize Firebase services', e);
      rethrow;
    }
  }



  // Начать отслеживание заявок пользователя
  Future<void> startTrackingUserRequests() async {
    try {
      final user = _authService.userData;
      if (user == null) return;

      final userId = user['passport_number'] ?? user['uid'] ?? user['phone'];
      final userPhone = user['phone'];
      
      loggingService.info('Starting to track service requests');

      // Слушаем только свои заявки в коллекции serviceRequests
      final baseQuery = _firestore.collection('serviceRequests');
      final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
      if (userId != null) {
        stream = baseQuery.where('userId', isEqualTo: userId).snapshots();
      } else if (userPhone != null) {
        stream = baseQuery.where('userPhone', isEqualTo: userPhone).snapshots();
      } else {
        // Если нет идентификаторов, не подписываемся
        loggingService.warning('No user identifiers for service request subscription');
        return;
      }

      stream.listen((snapshot) {
        _onServiceRequestsUpdate(snapshot, userId, userPhone);
      });

    } catch (e) {
      loggingService.error('Failed to start tracking requests', e);
    }
  }

  void _onServiceRequestsUpdate(QuerySnapshot snapshot, String? userId, String? userPhone) {
    try {
      loggingService.info('Service requests update received: ${snapshot.docs.length} requests');

      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final requestData = docChange.doc.data() as Map<String, dynamic>;
          final requestId = requestData['id'] ?? docChange.doc.id;
          
          // Проверяем, принадлежит ли заявка текущему пользователю
          final requestUserId = requestData['userId'];
          final requestUserPhone = requestData['userPhone'];
          
          bool isUserRequest = false;
          
          // Проверяем по userId
          if (userId != null && userId == requestUserId) {
            isUserRequest = true;
          }
          
          // Проверяем по номеру телефона
          if (!isUserRequest && userPhone != null && userPhone == requestUserPhone) {
            isUserRequest = true;
          }
          
          // Если заявка принадлежит пользователю, проверяем наличие ответа администратора
          if (isUserRequest) {
            _checkForAdminResponse(requestId, requestData);
          }
        }
      }
    } catch (e) {
      loggingService.error('Error processing service requests update', e);
    }
  }

  Future<void> _checkForAdminResponse(String requestId, Map<String, dynamic> requestData) async {
    try {
      final adminResponse = requestData['adminResponse'];
      if (adminResponse == null || adminResponse.toString().trim().isEmpty) {
        return;
      }

      // НЕ создаем уведомление в Firestore - это делает Cloud Function
      // Только показываем локальное push-уведомление
      try {
        final localNotificationService = LocalNotificationService();
        await localNotificationService.showAdminResponseNotification(
          requestId: requestId,
          adminResponse: adminResponse,
          requestType: requestData['requestType'],
        );
        loggingService.info('Showed local push notification for request: $requestId');
      } catch (e) {
        loggingService.error('Failed to show local notification', e);
      }

    } catch (e) {
      loggingService.error('Error checking admin response for request $requestId', e);
    }
  }





  Future<String> createServiceRequest({
    required String category,
    required String description,
    required String apartmentNumber,
    required String blockName,
    required String priority,
    required String contactMethod,
    required DateTime preferredTime,
    List<String>? photos,
    Map<String, dynamic>? additionalData,
  }) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Получаем данные пользователя и выбранной квартиры
    final user = _authService.userData;
    final selectedApartment = _authService.verifiedApartment;
    final userId = user?['passport_number'] ?? selectedApartment?.passportNumber ?? 'unknown';
    
    // Используем данные выбранной квартиры, если она есть
    final actualApartmentNumber = selectedApartment?.apartmentNumber ?? apartmentNumber;
    final actualBlockName = selectedApartment?.blockId ?? blockName;
    
    final request = ServiceRequest(
      id: requestId,
      userId: userId,
      category: category,
      description: description,
      apartmentNumber: actualApartmentNumber,
      block: actualBlockName,
      priority: priority,
      contactMethod: contactMethod,
      preferredTime: preferredTime,
      status: RequestStatus.pending,
      createdAt: DateTime.now(),
      photos: photos ?? [],
      additionalData: {
        ...?additionalData,
        'selectedApartmentId': selectedApartment?.id,
      },
    );

    try {
      // 1. Сохраняем в Firestore
      try {
        await _saveToFirestore(request);
        loggingService.info('Service request saved to Firestore: $requestId');
      } catch (firestoreError) {
        loggingService.error('Failed to save to Firestore', firestoreError);
        // Продолжаем выполнение, не прерывая процесс
      }
      
      // 2. Отправляем на внешний сайт
      try {
        await _sendToExternalWebsite(request);
        loggingService.info('Service request sent to external website: $requestId');
      } catch (webhookError) {
        loggingService.error('Failed to send to external website', webhookError);
        // Продолжаем выполнение, не прерывая процесс
      }
      
      // 3. Сохраняем локально для офлайн режима
      await _saveRequestLocally(request);
      
      return requestId;
    } catch (e) {
      loggingService.error('Failed to create service request', e);
      // Сохраняем локально как fallback
      try {
        await _saveOfflineRequest(request);
      } catch (saveError) {
        loggingService.error('Failed to save offline request', saveError);
        // Переброс ошибки если даже локальное сохранение не удалось
        throw Exception('Не удалось сохранить заявку. Проверьте свободное место на устройстве.');
      }
      return requestId;
    }
  }

  Future<void> _saveToFirestore(ServiceRequest request) async {
    // Get user data from auth service
    final user = _authService.userData;
    final apartmentData = _authService.verifiedApartment;
    
    // Extract user name and phone
    final userName = user?['fullName'] ?? apartmentData?.fullName ?? '';
    final userPhone = user?['phone'] ?? apartmentData?.phone ?? '';
    
    // Clean block name (remove duplication)
    String cleanBlockName = request.block;
    if (cleanBlockName.contains(' BLOK')) {
      cleanBlockName = cleanBlockName.replaceAll(' BLOK', '');
    }
    
    final requestData = {
      'id': request.id,
      'userId': request.userId,
      'userName': userName,
      'userPhone': userPhone,
      'apartmentNumber': request.apartmentNumber,
      'block': cleanBlockName,
      'requestType': request.category,
      'description': request.description,
      'priority': request.priority,
      'contactMethod': request.contactMethod,
      'preferredTime': request.preferredTime.toIso8601String(),
      'photos': request.photos,
      'status': request.status.toString().split('.').last,
      'createdAt': request.createdAt.toIso8601String(),
      'updatedAt': request.createdAt.toIso8601String(),
      'additionalData': request.additionalData,
      'requestSource': 'mobile_app',
    };

    await _firestore
        .collection('serviceRequests')
        .doc(request.id)
        .set(requestData);
  }

  Future<void> _sendToExternalWebsite(ServiceRequest request) async {
    // Проверяем, включен ли внешний webhook и валиден ли URL
    if (!_enableExternalWebhook || _webhookUrl.contains('your-website.com')) {
      loggingService.info('External webhook disabled or URL not configured, skipping external submission');
      return;
    }
    
    try {
      // Get user data from auth service
      final user = _authService.userData;
      final apartmentData = _authService.verifiedApartment;
      
      // Extract user name and phone
      final userName = user?['fullName'] ?? apartmentData?.fullName ?? '';
      final userPhone = user?['phone'] ?? apartmentData?.phone ?? '';
      
      // Clean block name (remove duplication)
      String cleanBlockName = request.block;
      if (cleanBlockName.contains(' BLOK')) {
        cleanBlockName = cleanBlockName.replaceAll(' BLOK', '');
      }
      
      final requestData = {
        'requestSource': 'mobile_app',
        'userName': userName,
        'userPhone': userPhone,
        'userId': request.userId,
        'apartmentNumber': request.apartmentNumber,
        'block': cleanBlockName,
        'requestType': request.category,
        'description': request.description,
        'priority': request.priority,
        'contactMethod': request.contactMethod,
        'preferredTime': request.preferredTime.toIso8601String(),
        'photos': request.photos,
        'status': 'new',
        'createdAt': request.createdAt.toIso8601String(),
        'updatedAt': request.createdAt.toIso8601String(),
        'additionalData': request.additionalData,
      };

      final response = await _dio.post(
        _webhookUrl,
        data: requestData,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': 'your-api-key', // Замените на ваш API ключ
          },
          followRedirects: true, // Следовать редиректам
          maxRedirects: 3, // Максимум 3 редиректа
          validateStatus: (status) {
            // Принимаем 200, 201, 302 как валидные статусы
            return status != null && (status < 400 || status == 302);
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 302) {
        loggingService.info('Successfully sent request to external website (status: ${response.statusCode})');
      } else {
        throw Exception('Failed to send to external website: ${response.statusCode}');
      }
    } catch (e) {
      loggingService.error('Error sending to external website', e);
      // Не прерываем процесс, если внешний сайт недоступен
    }
  }

  Future<String> submitFeedback({
    required String type,
    required String message,
    required String apartmentNumber,
    Map<String, dynamic>? additionalData,
  }) async {
    final feedback = ServiceFeedback(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      message: message,
      apartmentNumber: apartmentNumber,
      status: FeedbackStatus.pending,
      createdAt: DateTime.now(),
      additionalData: additionalData ?? {},
    );

    try {
      // Сохраняем в Firestore
      await _firestore
          .collection('feedback')
          .doc(feedback.id)
          .set(feedback.toJson());
      
      await _saveFeedbackLocally(feedback);
      return feedback.id;
    } catch (e) {
      loggingService.error('Failed to submit feedback', e);
      await _saveOfflineFeedback(feedback);
      return feedback.id;
    }
  }

  Future<List<ServiceRequest>> getServiceRequests() async {
    try {
      // Пытаемся получить из Firestore
      final user = _authService.userData;
      if (user != null) {
        final userId = user['passport_number'];
        final userPhone = user['phone'];
        
        List<ServiceRequest> allRequests = [];
        
        // Получаем заявки по userId, если он есть
        if (userId != null) {
          final snapshot = await _firestore
              .collection('serviceRequests')
              .where('userId', isEqualTo: userId)
              .get();
              
          allRequests.addAll(snapshot.docs.map((doc) {
            final data = doc.data();
            return ServiceRequest.fromFirestore(data);
          }));
        }
        
        // Получаем заявки по номеру телефона, если он есть
        if (userPhone != null) {
          final snapshot = await _firestore
              .collection('serviceRequests')
              .where('userPhone', isEqualTo: userPhone)
              .get();
              
          // Добавляем только те заявки, которых еще нет в списке
          final phoneRequests = snapshot.docs.map((doc) {
            final data = doc.data();
            return ServiceRequest.fromFirestore(data);
          }).where((request) => 
            !allRequests.any((existingRequest) => existingRequest.id == request.id)
          );
          
          allRequests.addAll(phoneRequests);
        }
        
        // Сортируем по дате создания (от новых к старым)
        allRequests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return allRequests;
      }
    } catch (e) {
      loggingService.error('Error getting requests from Firestore', e);
    }

    // Fallback к локальному хранилищу
    return await _getLocalRequests();
  }

  Future<List<ServiceRequest>> _getLocalRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final requestsString = prefs.getString(_requestsKey) ?? '[]';
    final List<dynamic> requestsJson = jsonDecode(requestsString);
    
    return requestsJson
        .map((json) => ServiceRequest.fromJson(json))
        .toList();
  }

  Future<List<ServiceFeedback>> getFeedback() async {
    try {
      // Пытаемся получить из Firestore
      final user = _authService.userData;
      if (user != null) {
        final userId = user['passport_number'];
        final snapshot = await _firestore
            .collection('feedback')
            .where('userId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .get();

        return snapshot.docs.map((doc) {
          final data = doc.data();
          return ServiceFeedback.fromFirestore(data);
        }).toList();
      }
    } catch (e) {
      loggingService.error('Error getting feedback from Firestore', e);
    }

    // Fallback к локальному хранилищу
    return await _getLocalFeedback();
  }

  Future<List<ServiceFeedback>> _getLocalFeedback() async {
    final prefs = await SharedPreferences.getInstance();
    final feedbackString = prefs.getString(_feedbackKey) ?? '[]';
    final List<dynamic> feedbackJson = jsonDecode(feedbackString);
    
    return feedbackJson
        .map((json) => ServiceFeedback.fromJson(json))
        .toList();
  }

  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    try {
      // Обновляем в Firestore
      await _firestore
          .collection('serviceRequests')
          .doc(requestId)
          .update({
        'status': status.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      loggingService.error('Error updating request status in Firestore', e);
    }

    // Обновляем локально
    final requests = await _getLocalRequests();
    final requestIndex = requests.indexWhere((r) => r.id == requestId);
    
    if (requestIndex != -1) {
      requests[requestIndex].status = status;
      await _saveRequestsLocally(requests);
    }
  }

  Future<void> updateFeedbackStatus(String feedbackId, FeedbackStatus status) async {
    final feedbackList = await _getLocalFeedback();
    final feedbackIndex = feedbackList.indexWhere((f) => f.id == feedbackId);
    
    if (feedbackIndex != -1) {
      feedbackList[feedbackIndex].status = status;
      await _saveFeedbackListLocally(feedbackList);
    }
  }

  Future<void> addCommentToRequest(String requestId, String comment) async {
    final requests = await _getLocalRequests();
    final requestIndex = requests.indexWhere((r) => r.id == requestId);
    
    if (requestIndex != -1) {
      requests[requestIndex].comments.add(comment);
      await _saveRequestsLocally(requests);
    }
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _saveFeedbackLocally(ServiceFeedback feedback) async {
    final feedbackList = await _getLocalFeedback();
    feedbackList.add(feedback);
    await _saveFeedbackListLocally(feedbackList);
  }

  Future<void> _saveFeedbackListLocally(List<ServiceFeedback> feedbackList) async {
    final prefs = await SharedPreferences.getInstance();
    final feedbackJson = feedbackList.map((f) => f.toJson()).toList();
    await prefs.setString(_feedbackKey, jsonEncode(feedbackJson));
  }

  Future<void> _saveOfflineFeedback(ServiceFeedback feedback) async {
    feedback.additionalData['isOffline'] = true;
    await _saveFeedbackLocally(feedback);
  }

  Future<void> syncOfflineRequests() async {
    final isOnline = await _isOnline();
    if (!isOnline) return;

    try {
      final requests = await _getLocalRequests();
      final offlineRequests = requests.where((r) => r.additionalData['isOffline'] == true).toList();

      for (final request in offlineRequests) {
        try {
          await _saveToFirestore(request);
          await _sendToExternalWebsite(request);
          
          // Убираем флаг офлайн
          request.additionalData.remove('isOffline');
          await _saveRequestLocally(request);
          
          loggingService.info('Synced offline request: ${request.id}');
        } catch (e) {
          loggingService.error('Failed to sync offline request: ${request.id}', e);
        }
      }
    } catch (e) {
      loggingService.error('Error syncing offline requests', e);
    }
  }

  Future<void> _saveRequestLocally(ServiceRequest request) async {
    final requests = await _getLocalRequests();
    final existingIndex = requests.indexWhere((r) => r.id == request.id);
    
    if (existingIndex != -1) {
      requests[existingIndex] = request;
    } else {
      requests.add(request);
    }
    
    await _saveRequestsLocally(requests);
  }

  Future<void> _saveRequestsLocally(List<ServiceRequest> requests) async {
    final prefs = await SharedPreferences.getInstance();
    final requestsJson = requests.map((r) => r.toJson()).toList();
    await prefs.setString(_requestsKey, jsonEncode(requestsJson));
  }

  Future<void> _saveOfflineRequest(ServiceRequest request) async {
    request.additionalData['isOffline'] = true;
    await _saveRequestLocally(request);
  }


}

enum RequestStatus {
  pending,
  inProgress,
  completed,
  cancelled,
  rejected
}

enum FeedbackStatus {
  pending,
  inProgress,
  resolved,
  rejected
}

class ServiceRequest {
  final String id;
  final String userId;
  final String category;
  final String description;
  final String apartmentNumber;
  final String block;
  final String priority;
  final String contactMethod;
  final DateTime preferredTime;
  RequestStatus status;
  final DateTime createdAt;
  final List<String> photos;
  final Map<String, dynamic> additionalData;
  final List<String> comments;

  ServiceRequest({
    required this.id,
    required this.userId,
    required this.category,
    required this.description,
    required this.apartmentNumber,
    required this.block,
    required this.priority,
    required this.contactMethod,
    required this.preferredTime,
    required this.status,
    required this.createdAt,
    required this.photos,
    required this.additionalData,
    List<String>? comments,
  }) : comments = comments ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'category': category,
      'description': description,
      'apartmentNumber': apartmentNumber,
      'block': block,
      'priority': priority,
      'contactMethod': contactMethod,
      'preferredTime': preferredTime.toIso8601String(),
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'photos': photos,
      'additionalData': additionalData,
      'comments': comments,
    };
  }

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    return ServiceRequest(
      id: json['id'],
      userId: json['userId'] ?? '',
      category: json['category'],
      description: json['description'],
      apartmentNumber: json['apartmentNumber'],
      block: json['block'] ?? '',
      priority: json['priority'] ?? 'Low',
      contactMethod: json['contactMethod'] ?? 'phone',
      preferredTime: DateTime.parse(json['preferredTime']),
      status: RequestStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => RequestStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      photos: List<String>.from(json['photos']),
      additionalData: Map<String, dynamic>.from(json['additionalData']),
      comments: List<String>.from(json['comments']),
    );
  }

  factory ServiceRequest.fromFirestore(Map<String, dynamic> data) {
    // Создаем базовую карту additionalData
    Map<String, dynamic> additionalData = Map<String, dynamic>.from(data['additionalData'] ?? {});
    
    // Добавляем adminResponse в additionalData, если оно есть
    if (data.containsKey('adminResponse') && data['adminResponse'] != null) {
      additionalData['adminResponse'] = data['adminResponse'];
    }
    
    // Безопасное преобразование даты из Firestore
    DateTime parseFirestoreDate(dynamic dateValue) {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      } else {
        return DateTime.now(); // fallback
      }
    }
    
    return ServiceRequest(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      category: data['requestType'] ?? data['category'] ?? 'general',
      description: data['description'] ?? '',
      apartmentNumber: data['apartmentNumber'] ?? '',
      block: data['block'] ?? '',
      priority: data['priority'] ?? 'Low',
      contactMethod: data['contactMethod'] ?? 'phone',
      preferredTime: parseFirestoreDate(data['preferredTime']),
      status: RequestStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (data['status'] ?? 'pending'),
        orElse: () => RequestStatus.pending,
      ),
      createdAt: parseFirestoreDate(data['createdAt']),
      photos: List<String>.from(data['photos'] ?? []),
      additionalData: additionalData,
      comments: List<String>.from(data['comments'] ?? []),
    );
  }
}

class ServiceFeedback {
  final String id;
  final String type;
  final String message;
  final String apartmentNumber;
  FeedbackStatus status;
  final DateTime createdAt;
  final Map<String, dynamic> additionalData;

  ServiceFeedback({
    required this.id,
    required this.type,
    required this.message,
    required this.apartmentNumber,
    required this.status,
    required this.createdAt,
    required this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'apartmentNumber': apartmentNumber,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'additionalData': additionalData,
    };
  }

  factory ServiceFeedback.fromJson(Map<String, dynamic> json) {
    return ServiceFeedback(
      id: json['id'],
      type: json['type'],
      message: json['message'],
      apartmentNumber: json['apartmentNumber'],
      status: FeedbackStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => FeedbackStatus.pending,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      additionalData: Map<String, dynamic>.from(json['additionalData']),
    );
  }

  factory ServiceFeedback.fromFirestore(Map<String, dynamic> data) {
    // Безопасное преобразование даты из Firestore
    DateTime parseFirestoreDate(dynamic dateValue) {
      if (dateValue is Timestamp) {
        return dateValue.toDate();
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        return dateValue;
      } else {
        return DateTime.now(); // fallback
      }
    }
    
    return ServiceFeedback(
      id: data['id'],
      type: data['type'],
      message: data['message'],
      apartmentNumber: data['apartmentNumber'],
      status: FeedbackStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => FeedbackStatus.pending,
      ),
      createdAt: parseFirestoreDate(data['createdAt']),
      additionalData: Map<String, dynamic>.from(data['additionalData'] ?? {}),
    );
  }
} 