import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invitation_model.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';
import 'family_request_service.dart';

class InviteService {
  static const String _inviteKey = 'pending_invite';
  static const String _inviteCollection = 'familyInvites';
  
  final LoggingService loggingService;
  late final FirebaseFirestore _firestore;
  
  // Get AuthService lazily to avoid circular dependency
  AuthService? get _authService {
    try {
      return GetIt.instance<AuthService>();
    } catch (e) {
      return null;
    }
  }

  InviteService({required this.loggingService}) {
    _firestore = GetIt.instance<FirebaseFirestore>();
  }

  /// Генерирует новый инвайт для семьи
  Future<InvitationModel?> createFamilyInvite({
    required String apartmentId,
    required String blockId,
    required String apartmentNumber,
    required String ownerName,
    required String ownerPhone,
    String? ownerPassport,
    String? customMessage,
    int maxUses = 5,
    Duration validityDuration = const Duration(days: 7),
  }) async {
    try {
      loggingService.info('Creating family invite for apartment: $blockId-$apartmentNumber');
      
      // Проверяем аутентификацию
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        loggingService.error('User not authenticated for creating invite');
        return null;
      }
      
      loggingService.info('User authenticated: ${currentUser.uid}');
      loggingService.info('User display name: ${currentUser.displayName ?? 'No name'}');
      loggingService.info('User email: ${currentUser.email ?? 'No email'}');
      
      final inviteId = _generateInviteId();
      final now = DateTime.now();
      final expiresAt = now.add(validityDuration);
      
      final invite = InvitationModel(
        id: inviteId,
        apartmentId: apartmentId,
        blockId: blockId,
        apartmentNumber: apartmentNumber,
        ownerName: ownerName,
        ownerPhone: ownerPhone,
        ownerPassport: ownerPassport,
        createdAt: now,
        expiresAt: expiresAt,
        isActive: true,
        maxUses: maxUses,
        currentUses: 0,
        usedBy: [],
        customMessage: customMessage,
      );

      // Сохраняем в Firestore с метаданными о создателе
      final inviteData = invite.toJson();
      inviteData['createdBy'] = {
        'uid': currentUser.uid,
        'displayName': currentUser.displayName ?? ownerName,
        'timestamp': FieldValue.serverTimestamp(),
      };
      
      await _firestore
          .collection(_inviteCollection)
          .doc(inviteId)
          .set(inviteData);

      loggingService.info('Family invite created successfully: $inviteId');
      return invite;
    } catch (e) {
      loggingService.error('Failed to create family invite', e);
      return null;
    }
  }

  /// Получает инвайт по ID
  Future<InvitationModel?> getInviteById(String inviteId) async {
    try {
      loggingService.info('Fetching invite: $inviteId');
      
      final doc = await _firestore
          .collection(_inviteCollection)
          .doc(inviteId)
          .get();

      if (!doc.exists) {
        loggingService.warning('Invite not found: $inviteId');
        return null;
      }

      final invite = InvitationModel.fromFirestore(doc);
      
      // Проверяем валидность
      if (!invite.canBeUsed) {
        loggingService.warning('Invite is not valid: $inviteId');
        return null;
      }

      loggingService.info('Invite fetched successfully: $inviteId');
      return invite;
    } catch (e) {
      loggingService.error('Failed to fetch invite: $inviteId', e);
      return null;
    }
  }

  /// Использует инвайт (добавляет пользователя в семью)
  Future<bool> useInvite({
    required String inviteId,
    required String memberName,
    required String memberPhone,
    required String memberRole,
  }) async {
    try {
      loggingService.info('Using invite: $inviteId for $memberName ($memberPhone)');
      
      final invite = await getInviteById(inviteId);
      if (invite == null) {
        loggingService.error('Invite not found or invalid: $inviteId');
        return false;
      }

      // Проверяем, не использовал ли уже этот пользователь инвайт
      if (invite.hasBeenUsedBy(memberPhone)) {
        loggingService.warning('User already used this invite: $memberPhone');
        return false;
      }

      // Создаем семейный запрос через FamilyRequestService
      final familyRequestService = GetIt.instance<FamilyRequestService>();
      final success = await familyRequestService.submitFamilyRequest(
        name: memberName,
        role: memberRole,
        blockId: invite.blockId,
        apartmentNumber: invite.apartmentNumber,
        ownerPhone: invite.ownerPhone,
        applicantPhone: memberPhone,
      );

      if (success) {
        // Обновляем статистику использования инвайта
        await _updateInviteUsage(inviteId, memberPhone);
        loggingService.info('Invite used successfully: $inviteId');
        return true;
      } else {
        loggingService.error('Failed to submit family request for invite: $inviteId');
        return false;
      }
    } catch (e) {
      loggingService.error('Failed to use invite: $inviteId', e);
      return false;
    }
  }

  /// Обновляет статистику использования инвайта
  Future<void> _updateInviteUsage(String inviteId, String userPhone) async {
    try {
      await _firestore
          .collection(_inviteCollection)
          .doc(inviteId)
          .update({
        'currentUses': FieldValue.increment(1),
        'usedBy': FieldValue.arrayUnion([userPhone]),
      });
    } catch (e) {
      loggingService.error('Failed to update invite usage: $inviteId', e);
    }
  }

  /// Получает все активные инвайты пользователя
  Future<List<InvitationModel>> getUserInvites() async {
    try {
      final authService = _authService;
      if (authService == null || !authService.isAuthenticated) {
        return [];
      }

      final userPhone = authService.userData?['phone'];
      if (userPhone == null) return [];

      final snapshot = await _firestore
          .collection(_inviteCollection)
          .where('ownerPhone', isEqualTo: userPhone)
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .get();

      final invites = snapshot.docs
          .map((doc) => InvitationModel.fromFirestore(doc))
          .where((invite) => invite.canBeUsed)
          .toList();

      loggingService.info('Found ${invites.length} active invites for user');
      return invites;
    } catch (e) {
      loggingService.error('Failed to get user invites', e);
      return [];
    }
  }

  /// Отменяет инвайт
  Future<bool> cancelInvite(String inviteId) async {
    try {
      await _firestore
          .collection(_inviteCollection)
          .doc(inviteId)
          .update({
        'isActive': false,
      });

      loggingService.info('Invite cancelled: $inviteId');
      return true;
    } catch (e) {
      loggingService.error('Failed to cancel invite: $inviteId', e);
      return false;
    }
  }

  /// Сохраняет ожидающий инвайт локально
  Future<void> savePendingInvite(InvitationModel invite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_inviteKey, jsonEncode(invite.toJson()));
      loggingService.info('Pending invite saved: ${invite.id}');
    } catch (e) {
      loggingService.error('Failed to save pending invite', e);
    }
  }

  /// Получает ожидающий инвайт из локального хранилища
  Future<InvitationModel?> getPendingInvite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inviteJson = prefs.getString(_inviteKey);
      
      if (inviteJson == null) return null;

      final invite = InvitationModel.fromJson(jsonDecode(inviteJson));
      
      // Проверяем валидность
      if (!invite.canBeUsed) {
        await clearPendingInvite();
        return null;
      }

      return invite;
    } catch (e) {
      loggingService.error('Failed to get pending invite', e);
      return null;
    }
  }

  /// Очищает ожидающий инвайт
  Future<void> clearPendingInvite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_inviteKey);
      loggingService.info('Pending invite cleared');
    } catch (e) {
      loggingService.error('Failed to clear pending invite', e);
    }
  }

  /// Генерирует уникальный ID для инвайта
  String _generateInviteId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  /// Парсит инвайт из URL
  String? parseInviteFromUrl(String url) {
    try {
      // Поддерживаемые форматы:
      // newport://invite/ABC123DEF456
      // https://newport-resident.com/invite/ABC123DEF456
      // newport://invite/ABC123DEF456?param=value
      
      final uri = Uri.parse(url);
      
      if (uri.scheme == 'newport' && uri.host == 'invite') {
        return uri.pathSegments.last;
      }
      
      if (uri.scheme == 'https' && 
          uri.host == 'newport-resident.com' && 
          uri.pathSegments.length >= 2 &&
          uri.pathSegments[0] == 'invite') {
        return uri.pathSegments[1];
      }
      
      return null;
    } catch (e) {
      loggingService.error('Failed to parse invite from URL: $url', e);
      return null;
    }
  }

  /// Поделиться инвайтом
  Future<bool> shareInvite(InvitationModel invite, {String? customMessage}) async {
    try {
      final message = customMessage ?? 
          'Привет! Владелец квартиры ${invite.blockId} ${invite.apartmentNumber} приглашает вас присоединиться к семье в приложении Newport Resident.\n\n'
          'Нажмите на ссылку, чтобы зарегистрироваться:\n'
          '${invite.inviteLink}';
      
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      
      // Fallback: копируем в буфер обмена
      // TODO: Добавить копирование в буфер обмена
      loggingService.info('Share URL: $message');
      return true;
    } catch (e) {
      loggingService.error('Failed to share invite', e);
      return false;
    }
  }

  /// Проверяет, есть ли активный инвайт для обработки
  Future<bool> hasPendingInvite() async {
    final invite = await getPendingInvite();
    return invite != null;
  }
} 