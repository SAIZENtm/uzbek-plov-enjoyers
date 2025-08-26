import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberModel {
  final String? memberId; // Firebase Auth UID после регистрации
  final String name; // Имя члена семьи
  final String role; // Роль: 'mother', 'father', 'son', 'daughter', 'other'
  final String? phone; // Номер телефона (заполняется после регистрации)
  final bool isApproved; // Подтвержден ли владельцем
  final DateTime createdAt; // Дата создания запроса
  final DateTime? approvedAt; // Дата подтверждения

  FamilyMemberModel({
    this.memberId,
    required this.name,
    required this.role,
    this.phone,
    required this.isApproved,
    required this.createdAt,
    this.approvedAt,
  });

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      memberId: json['memberId'] as String?,
      name: json['name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      isApproved: json['isApproved'] as bool? ?? false,
      createdAt: _parseTimestamp(json['createdAt']) ?? DateTime.now(),
      approvedAt: _parseTimestamp(json['approvedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'memberId': memberId,
      'name': name,
      'role': role,
      'phone': phone,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    };
  }

  FamilyMemberModel copyWith({
    String? memberId,
    String? name,
    String? role,
    String? phone,
    bool? isApproved,
    DateTime? createdAt,
    DateTime? approvedAt,
  }) {
    return FamilyMemberModel(
      memberId: memberId ?? this.memberId,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  // Вспомогательные методы
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  // Роли семьи
  static const Map<String, String> roles = {
    'mother': 'Мать',
    'father': 'Отец',
    'son': 'Сын',
    'daughter': 'Дочь',
    'grandmother': 'Бабушка',
    'grandfather': 'Дедушка',
    'other': 'Другое',
  };

  String get roleDisplayName => roles[role] ?? role;
} 