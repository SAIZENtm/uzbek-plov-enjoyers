// ignore_for_file: avoid_print

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:excel/excel.dart';

// Это скрипт для импорта данных из Excel в Firestore
// Запускать из корня проекта: dart run scripts/import_data_to_firestore.dart

void main() async {
  print('Starting data import to Firestore...');
  
  // Инициализация Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;
  
  // Путь к Excel файлу
  final file = File('data/final_cleaned.xlsx');
  if (!file.existsSync()) {
    print('Error: Excel file not found at ${file.path}');
    return;
  }
  
  var bytes = file.readAsBytesSync();
  var excel = Excel.decodeBytes(bytes);
  
  // Счетчики для статистики
  int totalRows = 0;
  int importedApartments = 0;
  int importedClients = 0;
  int skippedRows = 0;
  
  // Карта для хранения уникальных клиентов
  Map<String, Map<String, dynamic>> uniqueClients = {};
  
  // Карта для хранения блоков и их квартир
  Map<String, List<Map<String, dynamic>>> blockApartments = {};
  
  // Обрабатываем каждый лист в Excel
  for (var table in excel.tables.keys) {
    print('\nProcessing sheet: $table');
    var sheet = excel.tables[table]!;
    
    // Пропускаем заголовок
    bool isFirstRow = true;
    
    for (var row in sheet.rows) {
      if (isFirstRow) {
        isFirstRow = false;
        continue;
      }
      
      totalRows++;
      
      // Извлекаем данные из строки
      String? blockNumber = row[0]?.value?.toString(); // block_number
      String? apartmentNumber = row[1]?.value?.toString(); // apartment_number
      String? floorName = row[2]?.value?.toString(); // floor_name
      double? netAreaM2 = _parseDouble(row[3]?.value); // net_area_m2
      double? grossAreaM2 = _parseDouble(row[4]?.value); // gross_area_m2
      String? ownershipCode = row[5]?.value?.toString(); // ownership_code
      String? contractNumber = row[6]?.value?.toString(); // contract_number
      String? contractStatus = row[7]?.value?.toString(); // contract_status
      String? contractSigned = row[8]?.value?.toString(); // contract_signed
      DateTime? contractDate = _parseDate(row[9]?.value); // contract_date
      DateTime? contractEndDate = _parseDate(row[10]?.value); // contract_end_date
      String? fullName = row[11]?.value?.toString(); // full_name
      String? phone = _normalizePhone(row[12]?.value?.toString()); // phone
      String? passportNumber = row[13]?.value?.toString(); // passport_number
      String? clientAddress = row[14]?.value?.toString(); // client_address
      double? totalPrice = _parseDouble(row[15]?.value); // total_price
      double? pricePerM2 = _parseDouble(row[16]?.value); // price_per_m2
      String? currency = row[17]?.value?.toString(); // currency
      double? paidAmount = _parseDouble(row[18]?.value); // paid_amount
      double? remainingAmount = _parseDouble(row[19]?.value); // remaining_amount
      String? propertyType = row[20]?.value?.toString(); // property_type
      String? salesManager = row[21]?.value?.toString(); // sales_manager
      
      // Пропускаем строки без обязательных данных
      if (blockNumber == null || apartmentNumber == null || netAreaM2 == null || grossAreaM2 == null) {
        print('Skipping row $totalRows: missing required data');
        skippedRows++;
        continue;
      }
      
      // Фильтруем только заключенные договоры
      if (contractSigned != 'Договор заключен') {
        print('Skipping row $totalRows: contract not signed');
        skippedRows++;
        continue;
      }
      
      // Преобразуем блок в формат "D BLOK", "E BLOK" и т.д.
      String blockId = '$blockNumber BLOK';
      
      // Подготавливаем данные квартиры с подчеркиваниями в названиях полей
      Map<String, dynamic> apartmentData = {
        'apartment_number': apartmentNumber,
        'floor_name': floorName ?? '',
        'net_area_m2': netAreaM2,
        'gross_area_m2': grossAreaM2,
        'ownership_code': ownershipCode ?? '',
        'contract_number': contractNumber,
        'contract_status': contractStatus,
        'contract_signed': contractSigned == 'Договор заключен',
        'contract_date': contractDate,
        'contract_end_date': contractEndDate,
        'full_name': fullName,
        'phone': phone,
        'passport_number': passportNumber,
        'client_address': clientAddress,
        'total_price': totalPrice,
        'price_per_m2': pricePerM2,
        'currency': currency,
        'paid_amount': paidAmount,
        'remaining_amount': remainingAmount,
        'property_type': propertyType,
        'sales_manager': salesManager,
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Добавляем квартиру в список для блока
      if (!blockApartments.containsKey(blockId)) {
        blockApartments[blockId] = [];
      }
      blockApartments[blockId]!.add({
        'id': apartmentNumber,
        'data': apartmentData,
      });
      
      importedApartments++;
      print('Prepared apartment: $blockId/$apartmentNumber');
      
      // Обрабатываем клиента
      if (passportNumber != null && fullName != null && phone != null) {
        String clientId = _createClientId(passportNumber);
        
        if (!uniqueClients.containsKey(clientId)) {
          uniqueClients[clientId] = {
            'full_name': fullName,
            'phone': phone,
            'passport_number': passportNumber,
            'client_address': clientAddress,
            'apartment_ids': ['$blockId/$apartmentNumber'],
            'is_active': true,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          };
        } else {
          // Добавляем квартиру к существующему клиенту
          List<String> apartmentIds = uniqueClients[clientId]!['apartment_ids'] as List<String>;
          String apartmentRef = '$blockId/$apartmentNumber';
          if (!apartmentIds.contains(apartmentRef)) {
            apartmentIds.add(apartmentRef);
          }
        }
      }
    }
  }
  
  // Импортируем данные в Firestore
  print('\nImporting data to Firestore...');
  
  // Создаем документы блоков и их квартиры
  for (var entry in blockApartments.entries) {
    String blockId = entry.key;
    List<Map<String, dynamic>> apartments = entry.value;
    
    try {
      // Создаем или обновляем документ блока
      await firestore
          .collection('users')
          .doc(blockId)
          .set({
        'name': blockId,
        'total_apartments': apartments.length,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('Created/Updated block: $blockId');
      
      // Импортируем квартиры в подколлекцию
      for (var apartment in apartments) {
        String apartmentId = apartment['id'];
        Map<String, dynamic> apartmentData = apartment['data'];
        
        await firestore
            .collection('users')
            .doc(blockId)
            .collection('apartments')
            .doc(apartmentId)
            .set(apartmentData);
        
        print('  Imported apartment: $apartmentId');
      }
    } catch (e) {
      print('Error importing block $blockId: $e');
    }
  }
  
  // Импортируем клиентов (если нужно)
  print('\nImporting clients...');
  for (var entry in uniqueClients.entries) {
    try {
      await firestore
          .collection('clients')
          .doc(entry.key)
          .set(entry.value);
      importedClients++;
      print('Imported client: ${entry.key}');
    } catch (e) {
      print('Error importing client ${entry.key}: $e');
    }
  }
  
  // Выводим статистику
  print('\n=== Import Statistics ===');
  print('Total rows processed: $totalRows');
  print('Apartments imported: $importedApartments');
  print('Blocks created: ${blockApartments.length}');
  print('Clients imported: $importedClients');
  print('Rows skipped: $skippedRows');
  print('\nImport completed!');
}

// Вспомогательные функции
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value.replaceAll(',', '.'));
    } catch (e) {
      return null;
    }
  }
  return null;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      // Попробуем другие форматы
      try {
        var parts = value.split('.');
        if (parts.length == 3) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (e) {
        return null;
      }
    }
  }
  return null;
}

String? _normalizePhone(String? phone) {
  if (phone == null) return null;
  String normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
  if (!normalized.startsWith('+')) {
    normalized = '+$normalized';
  }
  return normalized;
}

String _createClientId(String passportNumber) {
  return passportNumber.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
} 