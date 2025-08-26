import 'package:cloud_firestore/cloud_firestore.dart';
import 'family_member_model.dart';

class ApartmentModel {
  final String id; // Составной ID: blockId_apartmentNumber (например: "D_01-222")
  final String blockId; // ID блока (D BLOK, E BLOK и т.д.)
  final String apartmentNumber; // Номер квартиры (например: "01-222")
  final String floorName; // Этаж
  final double netAreaM2; // Чистая площадь
  final double grossAreaM2; // Общая площадь
  final String ownershipCode; // Код собственности
  final String? ownerId; // ID владельца (ссылка на документ в коллекции clients)
  
  // Данные о семье
  final List<FamilyMemberModel> familyMembers; // Список членов семьи
  final bool isActivated; // Активирована ли квартира
  
  // Данные владельца (денормализованные для быстрого доступа)
  final String? fullName;
  final String? phone;
  final String? passportNumber;
  final String? clientAddress;
  
  // Данные о договоре
  final String? contractNumber;
  final String? contractStatus; // 'Активный', 'Завершенный', 'Начальный'
  final bool contractSigned;
  final DateTime? contractDate;
  final DateTime? contractEndDate;
  
  // Финансовые данные
  final double? totalPrice;
  final double? pricePerM2;
  final String? currency;
  final double? paidAmount;
  final double? remainingAmount;
  
  // Дополнительная информация
  final String? propertyType; // Тип недвижимости
  final String? salesManager;
  final String? status; // Статус квартиры
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Временные поля для семейной логики
  final bool? isFamilyMember; // Найден ли член семьи при поиске
  final Map<String, dynamic>? familyMemberData; // Данные найденного члена семьи

  ApartmentModel({
    required this.id,
    required this.blockId,
    required this.apartmentNumber,
    required this.floorName,
    required this.netAreaM2,
    required this.grossAreaM2,
    required this.ownershipCode,
    this.ownerId,
    this.familyMembers = const [],
    this.isActivated = false,
    this.fullName,
    this.phone,
    this.passportNumber,
    this.clientAddress,
    this.contractNumber,
    this.contractStatus,
    required this.contractSigned,
    this.contractDate,
    this.contractEndDate,
    this.totalPrice,
    this.pricePerM2,
    this.currency,
    this.paidAmount,
    this.remainingAmount,
    this.propertyType,
    this.salesManager,
    this.status,
    this.createdAt,
    this.updatedAt,
    // Временные поля
    this.isFamilyMember,
    this.familyMemberData,
  });

  factory ApartmentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ApartmentModel.fromJson(data..['document_id'] = doc.id);
  }

  factory ApartmentModel.fromJson(Map<String, dynamic> data) {
    // Обрабатываем различные варианты названий полей (с подчеркиваниями и camelCase)
    return ApartmentModel(
      id: data['document_id'] ?? data['id'] ?? '',
      blockId: _parseString(data['block_name'] ?? data['blockId'] ?? data['block_id'] ?? data['block_number']),
      apartmentNumber: _parseString(data['apartment_number'] ?? data['apartmentNumber']),
      floorName: _parseString(data['floor_name'] ?? data['floorName']),
      netAreaM2: _parseDouble(data['net_area_m2'] ?? data['netAreaM2']),
      grossAreaM2: _parseDouble(data['gross_area_m2'] ?? data['grossAreaM2']),
      ownershipCode: _parseString(data['ownership_code'] ?? data['ownershipCode']),
      ownerId: _parseNullableString(data['owner_id'] ?? data['ownerId']),
      familyMembers: _parseFamilyMembers(data['familyMembers'] ?? data['family_members']),
      isActivated: _parseBool(data['isActivated'] ?? data['is_activated']),
      fullName: _parseNullableString(data['full_name'] ?? data['fullName']),
      phone: _parseNullableString(data['phone']),
      passportNumber: _parseNullableString(data['passport_number'] ?? data['passportNumber']),
      clientAddress: _parseNullableString(data['client_address'] ?? data['clientAddress']),
      contractNumber: _parseNullableString(data['contract_number'] ?? data['contractNumber']),
      contractStatus: _parseNullableString(data['contract_status'] ?? data['contractStatus']),
      contractSigned: _parseBool(data['contract_signed'] ?? data['contractSigned']),
      contractDate: _parseTimestamp(data['contract_date'] ?? data['contractDate']),
      contractEndDate: _parseTimestamp(data['contract_end_date'] ?? data['contractEndDate']),
      totalPrice: _parseDouble(data['final_price'] ?? data['total_price'] ?? data['totalPrice']),
      pricePerM2: _parseDouble(data['price_per_m2'] ?? data['pricePerM2']),
      currency: _parseNullableString(data['currency'] ?? data['currency_code']),
      paidAmount: _parseDouble(data['amount_paid'] ?? data['paid_amount'] ?? data['paidAmount']),
      remainingAmount: _parseDouble(data['amount_due'] ?? data['remaining_amount'] ?? data['remainingAmount']),
      propertyType: _parseNullableString(data['property_type'] ?? data['propertyType']),
      salesManager: _parseNullableString(data['sales_manager'] ?? data['salesManager']),
      status: _parseNullableString(data['operation_status'] ?? data['status']),
      createdAt: _parseTimestamp(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseTimestamp(data['updatedAt'] ?? data['updated_at']),
      // Временные поля для семейной логики
      isFamilyMember: data['_isFamilyMember'] as bool?,
      familyMemberData: data['_familyMemberData'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blockId': blockId,
      'apartment_number': apartmentNumber,
      'floor_name': floorName,
      'net_area_m2': netAreaM2,
      'gross_area_m2': grossAreaM2,
      'ownership_code': ownershipCode,
      'owner_id': ownerId,
      'familyMembers': familyMembers.map((member) => member.toJson()).toList(),
      'isActivated': isActivated,
      'full_name': fullName,
      'phone': phone,
      'passport_number': passportNumber,
      'client_address': clientAddress,
      'contract_number': contractNumber,
      'contract_status': contractStatus,
      'contract_signed': contractSigned,
      'contract_date': contractDate != null ? Timestamp.fromDate(contractDate!) : null,
      'contract_end_date': contractEndDate != null ? Timestamp.fromDate(contractEndDate!) : null,
      'total_price': totalPrice,
      'price_per_m2': pricePerM2,
      'currency': currency,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'property_type': propertyType,
      'sales_manager': salesManager,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toJson() {
    final json = toMap();
    // Добавляем временные поля если они есть
    if (isFamilyMember != null) {
      json['_isFamilyMember'] = isFamilyMember;
    }
    if (familyMemberData != null) {
      json['_familyMemberData'] = familyMemberData;
    }
    return json;
  }

  // Вспомогательный метод для создания ID
  static String createId(String blockId, String apartmentNumber) {
    return '${blockId}_$apartmentNumber';
  }

  // Вспомогательные методы для парсинга
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    return 0.0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == 'yes' || v == '1') return true;
      return false;
    }
    if (value is int) {
      return value != 0;
    }
    return false;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static List<FamilyMemberModel> _parseFamilyMembers(dynamic value) {
    if (value == null) return [];
    if (value is! List) return [];
    
    return value
        .map((item) {
          try {
            if (item is Map<String, dynamic>) {
              return FamilyMemberModel.fromJson(item);
            }
            return null;
          } catch (e) {
            return null;
          }
        })
        .where((member) => member != null)
        .cast<FamilyMemberModel>()
        .toList();
  }

  // Методы для работы с семьей
  bool get hasOwner => ownerId != null && ownerId!.isNotEmpty;
  bool get hasFamilyMembers => familyMembers.isNotEmpty;
  int get familyMemberCount => familyMembers.length;
  
  // Проверка лимита членов семьи (максимум 10)
  bool get canAddFamilyMember => familyMembers.length < 10;
  
  // Получить одобренных членов семьи
  List<FamilyMemberModel> get approvedFamilyMembers => 
      familyMembers.where((member) => member.isApproved).toList();
} 