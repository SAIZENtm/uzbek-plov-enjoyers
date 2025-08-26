import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';

import '../models/resident_profile_model.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';

/// Service for managing resident profiles
class ProfileService {
  late final FirebaseFirestore _firestore;
  late final FirebaseMessaging _messaging;
  late final LoggingService _loggingService;

  ProfileService() {
    _firestore = GetIt.instance<FirebaseFirestore>();
    _messaging = FirebaseMessaging.instance;
    _loggingService = GetIt.instance<LoggingService>();
  }

  /// Helper to safely parse a date from Firestore Timestamp or ISO8601 String
  static DateTime _parseDate(dynamic dateValue) {
    if (dateValue is Timestamp) {
      return dateValue.toDate();
    } else if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    return DateTime.now();
  }

  /// Fetch resident profile by UID
  Future<ResidentProfile?> fetchProfile(String uid) async {
    try {
      // First try to get from residents collection
      final residentDoc = await _firestore.collection('residents').doc(uid).get();
      
      if (residentDoc.exists) {
        final data = residentDoc.data()!;
        data['uid'] = uid;
        return ResidentProfile.fromJson(data);
      }

      // Fallback: try to construct from clients and users collections
      final clientDoc = await _firestore.collection('clients').doc(uid).get();
      if (clientDoc.exists) {
        final clientData = clientDoc.data()!;
        
        // Get block and apartment info
        String blockId = '';
        String apartmentNumber = '';
        
        if (clientData['blockId'] != null && clientData['apartmentNumber'] != null) {
          blockId = clientData['blockId'] as String;
          apartmentNumber = clientData['apartmentNumber'] as String;
        }

        // Create profile from available data
        return ResidentProfile(
          uid: uid,
          fullName: clientData['fullName'] as String? ?? '',
          blockId: blockId,
          apartmentNumber: apartmentNumber,
          phone: clientData['phone'] as String? ?? '',
          email: clientData['email'] as String?,
          telegram: clientData['telegram'] as String?,
          role: ResidentRole.fromString(clientData['role'] as String? ?? 'owner'),
          hasUnpaidBills: clientData['hasUnpaidBills'] as bool? ?? false,
          hasOpenRequests: clientData['hasOpenRequests'] as bool? ?? false,
          fcmTokens: List<String>.from(clientData['fcmTokens'] as List? ?? []),
          prefs: NotificationPrefs.fromJson(clientData['prefs'] as Map<String, dynamic>? ?? {}),
          avatarUrl: clientData['avatarUrl'] as String?,
          createdAt: clientData['createdAt'] != null 
              ? _parseDate(clientData['createdAt'])
              : DateTime.now(),
          updatedAt: clientData['updatedAt'] != null
              ? _parseDate(clientData['updatedAt'])
              : DateTime.now(),
        );
      }

      // If no profile found, try to create one from auth data
      _loggingService.warning('Profile not found for UID: $uid');
      return await _createProfileFromAuthData(uid);
    } catch (e, st) {
      _loggingService.error('Failed to fetch profile for UID: $uid', e, st);
      return null;
    }
  }

  /// Create profile from authentication data
  Future<ResidentProfile?> _createProfileFromAuthData(String uid) async {
    try {
      // Get auth service
      final authService = GetIt.instance<AuthService>();
      
      if (!authService.isAuthenticated) {
        _loggingService.warning('User not authenticated, cannot create profile');
        return null;
      }

      final userData = authService.userData;
      final apartmentData = authService.verifiedApartment;
      
      if (userData == null) {
        _loggingService.warning('No user data available for profile creation');
        return null;
      }

      // Create profile from auth data
      final profile = ResidentProfile(
        uid: uid,
        fullName: userData['fullName'] as String? ?? '',
        blockId: userData['blockId'] as String? ?? apartmentData?.blockId ?? '',
        apartmentNumber: userData['apartmentNumber'] as String? ?? apartmentData?.apartmentNumber ?? '',
        phone: userData['phone'] as String? ?? '',
        email: null,
        telegram: null,
        role: ResidentRole.owner,
        hasUnpaidBills: false,
        hasOpenRequests: false,
        fcmTokens: const [],
        prefs: const NotificationPrefs(
          critical: true,
          general: true,
          service: true,
        ),
        avatarUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save the new profile
      final success = await updateProfile(profile);
      if (success) {
        _loggingService.info('Created new profile for UID: $uid');
        return profile;
      } else {
        _loggingService.error('Failed to save new profile for UID: $uid');
        return null;
      }
    } catch (e, st) {
      _loggingService.error('Failed to create profile from auth data for UID: $uid', e, st);
      return null;
    }
  }

  /// Update resident profile
  Future<bool> updateProfile(ResidentProfile profile) async {
    try {
      final batch = _firestore.batch();
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      
      // Update in residents collection
      final residentRef = _firestore.collection('residents').doc(profile.uid);
      batch.set(residentRef, updatedProfile.toJson(), SetOptions(merge: true));
      
      // Also update in clients collection for backward compatibility
      final clientRef = _firestore.collection('clients').doc(profile.uid);
      batch.set(clientRef, updatedProfile.toJson(), SetOptions(merge: true));
      
      await batch.commit();
      
      _loggingService.info('Profile updated successfully for UID: ${profile.uid}');
      return true;
    } catch (e, st) {
      _loggingService.error('Failed to update profile for UID: ${profile.uid}', e, st);
      return false;
    }
  }

  /// Toggle notification channel and update FCM subscriptions
  Future<bool> toggleNotificationChannel(String uid, String channel, bool enabled) async {
    try {
      final profile = await fetchProfile(uid);
      if (profile == null) {
        _loggingService.warning('Profile not found for notification toggle: $uid');
        return false;
      }

      // Update notification preferences
      NotificationPrefs updatedPrefs;
      switch (channel) {
        case 'critical':
          updatedPrefs = profile.prefs.copyWith(critical: enabled);
          break;
        case 'general':
          updatedPrefs = profile.prefs.copyWith(general: enabled);
          break;
        case 'service':
          updatedPrefs = profile.prefs.copyWith(service: enabled);
          break;
        default:
          _loggingService.warning('Unknown notification channel: $channel');
          return false;
      }

      // Update profile with new preferences
      final updatedProfile = profile.copyWith(prefs: updatedPrefs);
      final success = await updateProfile(updatedProfile);
      
      if (success) {
        // Update FCM topic subscriptions
        await _updateFCMSubscriptions(uid, channel, enabled);
      }
      
      return success;
    } catch (e, st) {
      _loggingService.error('Failed to toggle notification channel: $channel for UID: $uid', e, st);
      return false;
    }
  }

  /// Sanitize UID for use in Firebase topic names
  /// Firebase topic names can only contain: a-zA-Z0-9-_.~%
  String _sanitizeTopicName(String uid) {
    return uid
        .replaceAll('+', '')  // Remove plus signs
        .replaceAll(' ', '_') // Replace spaces with underscores
        .replaceAll('@', '_') // Replace @ with underscores
        .replaceAll('.', '_') // Replace dots with underscores
        .replaceAll('/', '_') // Replace slashes with underscores
        .replaceAll('?', '_') // Replace question marks with underscores
        .replaceAll('#', '_') // Replace hash with underscores
        .replaceAll('[', '_') // Replace brackets with underscores
        .replaceAll(']', '_')
        .replaceAll('!', '_') // Replace exclamation with underscores
        .replaceAll('\$', '_') // Replace dollar with underscores
        .replaceAll('&', '_') // Replace ampersand with underscores
        .replaceAll("'", '_') // Replace quotes with underscores
        .replaceAll('(', '_') // Replace parentheses with underscores
        .replaceAll(')', '_')
        .replaceAll('*', '_') // Replace asterisk with underscores
        .replaceAll(',', '_') // Replace comma with underscores
        .replaceAll(';', '_') // Replace semicolon with underscores
        .replaceAll('=', '_') // Replace equals with underscores
        .replaceAll(':', '_'); // Replace colon with underscores
  }

  /// Update FCM topic subscriptions
  Future<void> _updateFCMSubscriptions(String uid, String channel, bool enabled) async {
    final sanitizedUid = _sanitizeTopicName(uid);
    final topicName = 'notifications_${channel}_$sanitizedUid';
    
    try {
      if (enabled) {
        await _messaging.subscribeToTopic(topicName);
        _loggingService.info('Subscribed to FCM topic: $topicName');
      } else {
        await _messaging.unsubscribeFromTopic(topicName);
        _loggingService.info('Unsubscribed from FCM topic: $topicName');
      }
    } catch (e, st) {
      _loggingService.error('Failed to update FCM subscription for topic: $topicName', e, st);
    }
  }

  /// Get stream of profile updates
  Stream<ResidentProfile?> getProfileStream(String uid) {
    return _firestore.collection('residents').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['uid'] = uid;
      return ResidentProfile.fromJson(data);
    });
  }

  /// Add FCM token to profile
  Future<bool> addFCMToken(String uid, String token) async {
    try {
      final profile = await fetchProfile(uid);
      if (profile == null) return false;

      if (!profile.fcmTokens.contains(token)) {
        final updatedTokens = [...profile.fcmTokens, token];
        final updatedProfile = profile.copyWith(fcmTokens: updatedTokens);
        return await updateProfile(updatedProfile);
      }
      
      return true; // Token already exists
    } catch (e, st) {
      _loggingService.error('Failed to add FCM token for UID: $uid', e, st);
      return false;
    }
  }

  /// Remove FCM token from profile
  Future<bool> removeFCMToken(String uid, String token) async {
    try {
      final profile = await fetchProfile(uid);
      if (profile == null) return false;

      if (profile.fcmTokens.contains(token)) {
        final updatedTokens = profile.fcmTokens.where((t) => t != token).toList();
        final updatedProfile = profile.copyWith(fcmTokens: updatedTokens);
        return await updateProfile(updatedProfile);
      }
      
      return true; // Token doesn't exist
    } catch (e, st) {
      _loggingService.error('Failed to remove FCM token for UID: $uid', e, st);
      return false;
    }
  }

  /// Create a mock profile for testing
  static ResidentProfile createMockProfile({
    String uid = 'mock_uid',
    String fullName = 'Иван Петров',
    String blockId = 'A',
    String apartmentNumber = '101',
    String phone = '+998901234567',
    String? email = 'ivan@example.com',
    String? telegram = '@ivan_petrov',
    ResidentRole role = ResidentRole.owner,
    bool hasUnpaidBills = false,
    bool hasOpenRequests = false,
  }) {
    return ResidentProfile(
      uid: uid,
      fullName: fullName,
      blockId: blockId,
      apartmentNumber: apartmentNumber,
      phone: phone,
      email: email,
      telegram: telegram,
      role: role,
      hasUnpaidBills: hasUnpaidBills,
      hasOpenRequests: hasOpenRequests,
      fcmTokens: const ['mock_token_1', 'mock_token_2'],
      prefs: const NotificationPrefs(
        critical: true,
        general: true,
        service: false,
      ),
      avatarUrl: 'https://example.com/avatar.jpg',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now(),
    );
  }
} 