class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type; // 'admin_response', 'system', 'service_update', etc.
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final Map<String, dynamic> data; // Additional data like request ID, etc.
  final String? relatedRequestId;
  final String? adminName;
  final String? imageUrl;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.readAt,
    this.isRead = false,
    this.data = const {},
    this.relatedRequestId,
    this.adminName,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'isRead': isRead,
      'data': data,
      'relatedRequestId': relatedRequestId,
      'adminName': adminName,
      'imageUrl': imageUrl,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'system',
      createdAt: DateTime.parse(json['createdAt']),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      isRead: json['isRead'] ?? false,
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      relatedRequestId: json['relatedRequestId'],
      adminName: json['adminName'],
      imageUrl: json['imageUrl'],
    );
  }

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, {String? docId}) {
    return NotificationModel(
      id: docId ?? data['id'] ?? '',
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'system',
      createdAt: _parseDateTime(data['createdAt']),
      readAt: data['readAt'] != null ? _parseDateTime(data['readAt']) : null,
      isRead: data['isRead'] ?? false,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      relatedRequestId: data['relatedRequestId'],
      adminName: data['adminName'],
      imageUrl: data['imageUrl'],
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    
    // Handle Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      return (value as dynamic).toDate();
    }
    
    // Handle String
    if (value is String) {
      return DateTime.parse(value);
    }
    
    // Handle DateTime (already parsed)
    if (value is DateTime) {
      return value;
    }
    
    // Fallback
    return DateTime.now();
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    DateTime? readAt,
    bool? isRead,
    Map<String, dynamic>? data,
    String? relatedRequestId,
    String? adminName,
    String? imageUrl,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      relatedRequestId: relatedRequestId ?? this.relatedRequestId,
      adminName: adminName ?? this.adminName,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  // Helper methods
  bool get isAdminResponse => type == 'admin_response';
  bool get isSystemNotification => type == 'system';
  bool get isServiceUpdate => type == 'service_update';
  
  String get displayTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inMinutes < 1) {
      return 'Только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    } else {
      return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
    }
  }
} 