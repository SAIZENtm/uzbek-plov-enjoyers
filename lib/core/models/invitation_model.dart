import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a family invitation
enum InvitationStatus {
  pending('pending'),
  consumed('consumed'),
  revoked('revoked'),
  expired('expired');

  const InvitationStatus(this.value);
  final String value;

  static InvitationStatus fromString(String value) {
    return InvitationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => InvitationStatus.pending,
    );
  }

  /// Get display name for the status in Russian
  String get displayName {
    switch (this) {
      case InvitationStatus.pending:
        return 'Ожидает принятия';
      case InvitationStatus.consumed:
        return 'Принято';
      case InvitationStatus.revoked:
        return 'Отменено';
      case InvitationStatus.expired:
        return 'Истекло';
    }
  }

  /// Check if invitation is still active
  bool get isActive => this == InvitationStatus.pending;

  /// Check if invitation is finished (cannot be used)
  bool get isFinished => this != InvitationStatus.pending;
}

class InvitationModel {
  final String id;
  final String apartmentId;
  final String blockId;
  final String apartmentNumber;
  final String ownerName;
  final String ownerPhone;
  final String? ownerPassport;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final int maxUses;
  final int currentUses;
  final List<String> usedBy; // Список телефонов, которые уже использовали инвайт
  final String? customMessage;

  InvitationModel({
    required this.id,
    required this.apartmentId,
    required this.blockId,
    required this.apartmentNumber,
    required this.ownerName,
    required this.ownerPhone,
    this.ownerPassport,
    required this.createdAt,
    required this.expiresAt,
    required this.isActive,
    required this.maxUses,
    required this.currentUses,
    required this.usedBy,
    this.customMessage,
  });

  // Проверяем, можно ли использовать инвайт
  bool get canBeUsed => 
    isActive && 
    DateTime.now().isBefore(expiresAt) && 
    currentUses < maxUses;

  // Проверяем, использовал ли конкретный пользователь этот инвайт
  bool hasBeenUsedBy(String phone) => usedBy.contains(phone);

  // Генерируем короткий код для ссылки
  String get shortCode => id.substring(0, 8).toUpperCase();

  // Создаем ссылку для инвайта
  String get inviteLink => 'newport://invite/$id';

  // Создаем веб-ссылку (для fallback)
  String get webInviteLink => 'https://newport-resident.com/invite/$id';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'apartmentId': apartmentId,
      'blockId': blockId,
      'apartmentNumber': apartmentNumber,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerPassport': ownerPassport,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isActive': isActive,
      'maxUses': maxUses,
      'currentUses': currentUses,
      'usedBy': usedBy,
      'customMessage': customMessage,
    };
  }

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id: json['id'],
      apartmentId: json['apartmentId'],
      blockId: json['blockId'],
      apartmentNumber: json['apartmentNumber'],
      ownerName: json['ownerName'],
      ownerPhone: json['ownerPhone'],
      ownerPassport: json['ownerPassport'],
      createdAt: DateTime.parse(json['createdAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      isActive: json['isActive'] ?? true,
      maxUses: json['maxUses'] ?? 5,
      currentUses: json['currentUses'] ?? 0,
      usedBy: List<String>.from(json['usedBy'] ?? []),
      customMessage: json['customMessage'],
    );
  }

  factory InvitationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return InvitationModel.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  InvitationModel copyWith({
    String? id,
    String? apartmentId,
    String? blockId,
    String? apartmentNumber,
    String? ownerName,
    String? ownerPhone,
    String? ownerPassport,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    int? maxUses,
    int? currentUses,
    List<String>? usedBy,
    String? customMessage,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      apartmentId: apartmentId ?? this.apartmentId,
      blockId: blockId ?? this.blockId,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      ownerPassport: ownerPassport ?? this.ownerPassport,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      maxUses: maxUses ?? this.maxUses,
      currentUses: currentUses ?? this.currentUses,
      usedBy: usedBy ?? this.usedBy,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  /// Генерирует deep link для приложения
  String generateDeepLink() {
    return 'newport://invite/$id';
  }

  /// Генерирует веб-ссылку с fallback
  String generateWebLink() {
    // Используем GitHub Pages для хостинга
    return 'https://saizentm1.github.io/newportfamily/?invite=$id';
  }

  /// Генерирует универсальную ссылку для шаринга (с автоматическим fallback)
  String generateShareableLink() {
    // Используем GitHub Pages для хостинга
    return 'https://saizentm1.github.io/newportfamily/?invite=$id';
  }

  /// Генерирует текст для шаринга
  String generateShareText() {
    return '''
🏠 Приглашение в Newport

Вас приглашает: $ownerName
Адрес: $blockId, квартира $apartmentNumber
Телефон: $ownerPhone

${customMessage ?? 'Присоединяйтесь к нашей семье в приложении Newport!'}

Ссылка для присоединения:
${generateShareableLink()}

Если у вас нет приложения, оно автоматически предложит его скачать.
    '''.trim();
  }
} 