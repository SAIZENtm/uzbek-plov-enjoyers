import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for resident role types
enum ResidentRole {
  owner('owner'),
  renter('renter'),
  guest('guest'),
  familyFull('family_full'); // New role for family members with full access

  const ResidentRole(this.value);
  final String value;

  static ResidentRole fromString(String value) {
    return ResidentRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => ResidentRole.owner,
    );
  }
  
  /// Get display name for the role in Russian
  String get displayName {
    switch (this) {
      case ResidentRole.owner:
        return 'Собственник';
      case ResidentRole.renter:
        return 'Арендатор';
      case ResidentRole.guest:
        return 'Гость';
      case ResidentRole.familyFull:
        return 'Член семьи';
    }
  }
  
  /// Check if the role has management permissions (can invite others)
  bool get canManageFamily {
    switch (this) {
      case ResidentRole.owner:
      case ResidentRole.renter:
        return true;
      case ResidentRole.guest:
      case ResidentRole.familyFull:
        return false;
    }
  }
  
  /// Check if the role has full access to apartment features
  bool get hasFullAccess {
    switch (this) {
      case ResidentRole.owner:
      case ResidentRole.renter:
      case ResidentRole.familyFull:
        return true;
      case ResidentRole.guest:
        return false;
    }
  }
}

/// Notification preferences for different channels
class NotificationPrefs {
  final bool critical;
  final bool general;
  final bool service;

  const NotificationPrefs({
    required this.critical,
    required this.general,
    required this.service,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      critical: json['critical'] as bool? ?? true,
      general: json['general'] as bool? ?? true,
      service: json['service'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'critical': critical,
      'general': general,
      'service': service,
    };
  }

  NotificationPrefs copyWith({
    bool? critical,
    bool? general,
    bool? service,
  }) {
    return NotificationPrefs(
      critical: critical ?? this.critical,
      general: general ?? this.general,
      service: service ?? this.service,
    );
  }
}

/// Model representing a resident profile
class ResidentProfile {
  final String uid;
  final String fullName;
  final String blockId;
  final String apartmentNumber;
  final String phone;
  final String? email;
  final String? telegram;
  final ResidentRole role;
  final bool hasUnpaidBills;
  final bool hasOpenRequests;
  final List<String> fcmTokens;
  final NotificationPrefs prefs;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ResidentProfile({
    required this.uid,
    required this.fullName,
    required this.blockId,
    required this.apartmentNumber,
    required this.phone,
    this.email,
    this.telegram,
    this.role = ResidentRole.owner,
    this.hasUnpaidBills = false,
    this.hasOpenRequests = false,
    this.fcmTokens = const [],
    required this.prefs,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper to safely parse a date from Firestore Timestamp or ISO8601 String
  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  factory ResidentProfile.fromJson(Map<String, dynamic> json) {
    return ResidentProfile(
      uid: json['uid'] as String,
      fullName: json['fullName'] as String? ?? '',
      blockId: json['blockId'] as String? ?? '',
      apartmentNumber: json['apartmentNumber'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      telegram: json['telegram'] as String?,
      role: ResidentRole.fromString(json['role'] as String? ?? 'owner'),
      hasUnpaidBills: json['hasUnpaidBills'] as bool? ?? false,
      hasOpenRequests: json['hasOpenRequests'] as bool? ?? false,
      fcmTokens: List<String>.from(json['fcmTokens'] as List? ?? []),
      prefs: NotificationPrefs.fromJson(json['prefs'] as Map<String, dynamic>? ?? {}),
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'blockId': blockId,
      'apartmentNumber': apartmentNumber,
      'phone': phone,
      'email': email,
      'telegram': telegram,
      'role': role.value,
      'hasUnpaidBills': hasUnpaidBills,
      'hasOpenRequests': hasOpenRequests,
      'fcmTokens': fcmTokens,
      'prefs': prefs.toJson(),
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ResidentProfile copyWith({
    String? uid,
    String? fullName,
    String? blockId,
    String? apartmentNumber,
    String? phone,
    String? email,
    String? telegram,
    ResidentRole? role,
    bool? hasUnpaidBills,
    bool? hasOpenRequests,
    List<String>? fcmTokens,
    NotificationPrefs? prefs,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResidentProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      blockId: blockId ?? this.blockId,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      telegram: telegram ?? this.telegram,
      role: role ?? this.role,
      hasUnpaidBills: hasUnpaidBills ?? this.hasUnpaidBills,
      hasOpenRequests: hasOpenRequests ?? this.hasOpenRequests,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      prefs: prefs ?? this.prefs,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Helper getters
  String get displayName => fullName.isNotEmpty ? fullName : 'Резидент';
  String get apartmentDisplay => '$blockId-$apartmentNumber';
  bool get hasNotifications => hasUnpaidBills || hasOpenRequests;
  String get roleDisplay => role.displayName;
} 