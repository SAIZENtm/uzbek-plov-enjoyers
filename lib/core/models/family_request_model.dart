import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyRequestModel {
  final String id; // Документ ID
  final String name; // Имя заявителя
  final String role; // Роль в семье
  final String blockId; // ID блока (например, "D")
  final String apartmentNumber; // Номер квартиры (например, "01-222")
  final String? apartmentId; // ID квартиры (составной: блок_номер)
  final String status; // 'pending', 'approved', 'rejected'
  final String? applicantId; // Firebase Auth UID заявителя (заполняется после создания аккаунта)
  final String? applicantPhone; // Телефон заявителя (будущего члена семьи)
  final String? fcmToken; // FCM токен заявителя для уведомлений
  final String? ownerPhone; // Телефон владельца квартиры (для поиска квартиры)
  final DateTime createdAt;
  final DateTime? respondedAt; // Дата ответа владельца
  final String? rejectionReason; // Причина отклонения (опционально)

  FamilyRequestModel({
    required this.id,
    required this.name,
    required this.role,
    required this.blockId,
    required this.apartmentNumber,
    this.apartmentId,
    required this.status,
    this.applicantId,
    this.applicantPhone,
    this.fcmToken,
    this.ownerPhone,
    required this.createdAt,
    this.respondedAt,
    this.rejectionReason,
  });

  factory FamilyRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyRequestModel.fromJson(data..['id'] = doc.id);
  }

  factory FamilyRequestModel.fromJson(Map<String, dynamic> json) {
    return FamilyRequestModel(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      blockId: json['blockId'] as String? ?? json['block'] as String,
      apartmentNumber: json['apartmentNumber'] as String? ?? json['number'] as String,
      apartmentId: json['apartmentId'] as String?,
      status: json['status'] as String? ?? 'pending',
      applicantId: json['applicantId'] as String?,
      applicantPhone: json['applicantPhone'] as String?,
      fcmToken: json['fcmToken'] as String?,
      ownerPhone: json['ownerPhone'] as String?,
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
      respondedAt: _parseTimestamp(json['respondedAt']),
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'role': role,
      'blockId': blockId,
      'apartmentNumber': apartmentNumber,
      'apartmentId': apartmentId,
      'status': status,
      'applicantId': applicantId,
      'applicantPhone': applicantPhone,
      'fcmToken': fcmToken,
      'ownerPhone': ownerPhone,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'rejectionReason': rejectionReason,
    };
  }

  FamilyRequestModel copyWith({
    String? id,
    String? name,
    String? role,
    String? blockId,
    String? apartmentNumber,
    String? apartmentId,
    String? status,
    String? applicantId,
    String? applicantPhone,
    String? fcmToken,
    String? ownerPhone,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? rejectionReason,
  }) {
    return FamilyRequestModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      blockId: blockId ?? this.blockId,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      apartmentId: apartmentId ?? this.apartmentId,
      status: status ?? this.status,
      applicantId: applicantId ?? this.applicantId,
      applicantPhone: applicantPhone ?? this.applicantPhone,
      fcmToken: fcmToken ?? this.fcmToken,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  // Вспомогательные методы
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // Статусы запросов
  static const Map<String, String> statuses = {
    'pending': 'Ожидает ответа',
    'approved': 'Одобрен',
    'rejected': 'Отклонен',
  };

  String get statusDisplayName => statuses[status] ?? status;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  // Полный адрес квартиры
  String get fullAddress => 'Блок $blockId, кв. $apartmentNumber';
} 