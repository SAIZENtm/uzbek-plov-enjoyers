import 'package:cloud_firestore/cloud_firestore.dart';

class ClientModel {
  final String id; // ID документа (может быть номер телефона или UID)
  final String fullName;
  final String phone;
  final String passportNumber;
  final String? clientAddress;
  final List<String> apartmentIds; // Список ID квартир, принадлежащих клиенту
  final String? email;
  final String? clientType; // Тип клиента (физ. лицо, юр. лицо)
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ClientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.passportNumber,
    this.clientAddress,
    required this.apartmentIds,
    this.email,
    this.clientType,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ClientModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClientModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      passportNumber: data['passportNumber'] ?? '',
      clientAddress: data['clientAddress'],
      apartmentIds: List<String>.from(data['apartmentIds'] ?? []),
      email: data['email'],
      clientType: data['clientType'],
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'passportNumber': passportNumber,
      'clientAddress': clientAddress,
      'apartmentIds': apartmentIds,
      'email': email,
      'clientType': clientType,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Вспомогательный метод для нормализации номера телефона
  static String normalizePhone(String phone) {
    String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!normalized.startsWith('+')) {
      normalized = '+$normalized';
    }
    return normalized;
  }

  // Метод для создания ID на основе паспорта
  static String createIdFromPassport(String passportNumber) {
    return passportNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }
} 