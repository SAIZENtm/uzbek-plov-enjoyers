import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import '../models/client_model.dart';
import 'logging_service_secure.dart';

class ClientService {
  late final FirebaseFirestore _firestore;
  final LoggingService loggingService;

  ClientService({required this.loggingService}) {
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  // Найти клиента по паспорту
  Future<ClientModel?> findClientByPassport(String passportNumber) async {
    try {
      loggingService.info('Searching for client with passport: $passportNumber');
      
      final clientId = ClientModel.createIdFromPassport(passportNumber);
      final doc = await _firestore.collection('clients').doc(clientId).get();
      
      if (doc.exists) {
        loggingService.info('Client found');
        return ClientModel.fromFirestore(doc);
      }
      
      // Если не нашли по ID, попробуем поискать по полю
      final query = await _firestore
          .collection('clients')
          .where('passportNumber', isEqualTo: passportNumber)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        loggingService.info('Client found by query');
        return ClientModel.fromFirestore(query.docs.first);
      }
      
      loggingService.info('Client not found');
      return null;
    } catch (e) {
      loggingService.error('Error finding client by passport', e);
      return null;
    }
  }

  // Найти клиента по телефону
  Future<ClientModel?> findClientByPhone(String phoneNumber) async {
    try {
      final normalizedPhone = ClientModel.normalizePhone(phoneNumber);
      loggingService.info('Searching for client with phone: $normalizedPhone');
      
      final query = await _firestore
          .collection('clients')
          .where('phone', isEqualTo: normalizedPhone)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        loggingService.info('Client found');
        return ClientModel.fromFirestore(query.docs.first);
      }
      
      loggingService.info('Client not found');
      return null;
    } catch (e) {
      loggingService.error('Error finding client by phone', e);
      return null;
    }
  }

  // Создать или обновить клиента (с обработкой сетевых ошибок)
  Future<ClientModel?> createOrUpdateClient({
    required String fullName,
    required String phone,
    required String passportNumber,
    String? clientAddress,
    List<String>? apartmentIds,
    String? email,
  }) async {
    try {
      final clientId = ClientModel.createIdFromPassport(passportNumber);
      final normalizedPhone = ClientModel.normalizePhone(phone);
      
      loggingService.info('Creating/updating client: $clientId');
      
      // Проверяем, существует ли клиент (с timeout)
      final existingClient = await findClientByPassport(passportNumber)
          .timeout(const Duration(seconds: 8));
      
      if (existingClient != null) {
        // Обновляем существующего клиента
        loggingService.info('Updating existing client: $clientId');
        
        final updatedApartmentIds = existingClient.apartmentIds;
        if (apartmentIds != null) {
          // Добавляем новые квартиры, избегая дубликатов
          for (var apartmentId in apartmentIds) {
            if (!updatedApartmentIds.contains(apartmentId)) {
              updatedApartmentIds.add(apartmentId);
            }
          }
        }
        
        await _firestore.collection('clients').doc(clientId).update({
          'fullName': fullName,
          'phone': normalizedPhone,
          'clientAddress': clientAddress ?? existingClient.clientAddress,
          'apartmentIds': updatedApartmentIds,
          'email': email ?? existingClient.email,
          'updatedAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      } else {
        // Создаем нового клиента
        loggingService.info('Creating new client: $clientId');
        
        final newClient = ClientModel(
          id: clientId,
          fullName: fullName,
          phone: normalizedPhone,
          passportNumber: passportNumber,
          clientAddress: clientAddress,
          apartmentIds: apartmentIds ?? [],
          email: email,
        );
        
        await _firestore.collection('clients').doc(clientId).set(newClient.toMap())
            .timeout(const Duration(seconds: 8));
      }
      
      // Возвращаем обновленного клиента (с fallback)
      try {
        return await findClientByPassport(passportNumber)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        loggingService.info('Failed to fetch updated client (non-critical): $e');
        // Возвращаем минимальный объект клиента
        return ClientModel(
          id: clientId,
          fullName: fullName,
          phone: normalizedPhone,
          passportNumber: passportNumber,
          clientAddress: clientAddress,
          apartmentIds: apartmentIds ?? [],
          email: email,
        );
      }
    } catch (e) {
      // Проверяем, является ли это ошибкой недоступности сервиса
      if (e.toString().contains('unavailable') || 
          e.toString().contains('SERVICE_NOT_AVAILABLE') ||
          e.toString().contains('TimeoutException')) {
        loggingService.info('Firestore unavailable, skipping client creation: $e');
      } else {
        loggingService.error('Error creating/updating client', e);
      }
      return null;
    }
  }

  // Добавить квартиру к клиенту
  Future<bool> addApartmentToClient(String passportNumber, String apartmentId) async {
    try {
      final clientId = ClientModel.createIdFromPassport(passportNumber);
      
      await _firestore.collection('clients').doc(clientId).update({
        'apartmentIds': FieldValue.arrayUnion([apartmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      loggingService.info('Added apartment $apartmentId to client $clientId');
      return true;
    } catch (e) {
      loggingService.error('Error adding apartment to client', e);
      return false;
    }
  }

  // Удалить квартиру у клиента
  Future<bool> removeApartmentFromClient(String passportNumber, String apartmentId) async {
    try {
      final clientId = ClientModel.createIdFromPassport(passportNumber);
      
      await _firestore.collection('clients').doc(clientId).update({
        'apartmentIds': FieldValue.arrayRemove([apartmentId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      loggingService.info('Removed apartment $apartmentId from client $clientId');
      return true;
    } catch (e) {
      loggingService.error('Error removing apartment from client', e);
      return false;
    }
  }

  // Получить всех клиентов
  Future<List<ClientModel>> getAllClients() async {
    try {
      final snapshot = await _firestore
          .collection('clients')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) => ClientModel.fromFirestore(doc)).toList();
    } catch (e) {
      loggingService.error('Error getting all clients', e);
      return [];
    }
  }
} 