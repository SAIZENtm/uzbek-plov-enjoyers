import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../models/resident_profile_model.dart';
import '../services/profile_service.dart';
import '../services/logging_service.dart';
import '../services/auth_service.dart';

/// Provider for managing resident profile state
class ProfileProvider extends ChangeNotifier {
  final ProfileService _profileService;
  final LoggingService _loggingService;
  final AuthService _authService;

  ProfileProvider()
      : _profileService = GetIt.instance<ProfileService>(),
        _loggingService = GetIt.instance<LoggingService>(),
        _authService = GetIt.instance<AuthService>();

  // State
  ResidentProfile? _profile;
  bool _isLoading = false;
  String? _error;
  bool _isUpdating = false;

  // Getters
  ResidentProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUpdating => _isUpdating;
  bool get hasProfile => _profile != null;

  // Computed properties
  String get displayName => _profile?.displayName ?? 'Пользователь';
  String get apartmentDisplay => _profile?.apartmentDisplay ?? '';
  bool get hasUnpaidBills => _profile?.hasUnpaidBills ?? false;
  bool get hasOpenRequests => _profile?.hasOpenRequests ?? false;
  bool get hasNotifications => _profile?.hasNotifications ?? false;
  NotificationPrefs get notificationPrefs => _profile?.prefs ?? const NotificationPrefs(
    critical: true,
    general: true,
    service: true,
  );

  /// Load profile for current user
  Future<void> loadProfile() async {
    if (!_authService.isAuthenticated || _authService.userData == null) {
      _setError('Пользователь не авторизован');
      return;
    }

    // Create a mock UID from user data for now
    final uid = _authService.userData!['phone'] ?? 'unknown_user';
    await loadProfileByUid(uid);
  }

  /// Load profile by specific UID
  Future<void> loadProfileByUid(String uid) async {
    _setLoading(true);
    _clearError();

    try {
      final profile = await _profileService.fetchProfile(uid);
      if (profile != null) {
        _profile = profile;
        _loggingService.info('Profile loaded successfully for UID: $uid');
      } else {
        _setError('Профиль не найден');
      }
    } catch (e, st) {
      _loggingService.error('Failed to load profile for UID: $uid', e, st);
      _setError('Ошибка загрузки профиля: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Update profile
  Future<bool> updateProfile(ResidentProfile updatedProfile) async {
    _setUpdating(true);
    _clearError();

    try {
      final success = await _profileService.updateProfile(updatedProfile);
      if (success) {
        _profile = updatedProfile;
        _loggingService.info('Profile updated successfully');
        notifyListeners();
        return true;
      } else {
        _setError('Не удалось обновить профиль');
        return false;
      }
    } catch (e, st) {
      _loggingService.error('Failed to update profile', e, st);
      _setError('Ошибка обновления профиля: ${e.toString()}');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  /// Toggle notification channel
  Future<bool> toggleNotificationChannel(String channel, bool enabled) async {
    if (_profile == null) {
      _setError('Профиль не загружен');
      return false;
    }

    _setUpdating(true);
    _clearError();

    try {
      final success = await _profileService.toggleNotificationChannel(
        _profile!.uid,
        channel,
        enabled,
      );

      if (success) {
        // Update local state
        NotificationPrefs updatedPrefs;
        switch (channel) {
          case 'critical':
            updatedPrefs = _profile!.prefs.copyWith(critical: enabled);
            break;
          case 'general':
            updatedPrefs = _profile!.prefs.copyWith(general: enabled);
            break;
          case 'service':
            updatedPrefs = _profile!.prefs.copyWith(service: enabled);
            break;
          default:
            _setError('Неизвестный канал уведомлений');
            return false;
        }

        _profile = _profile!.copyWith(prefs: updatedPrefs);
        _loggingService.info('Notification channel $channel toggled to $enabled');
        notifyListeners();
        return true;
      } else {
        _setError('Не удалось изменить настройки уведомлений');
        return false;
      }
    } catch (e, st) {
      _loggingService.error('Failed to toggle notification channel: $channel', e, st);
      _setError('Ошибка изменения настроек: ${e.toString()}');
      return false;
    } finally {
      _setUpdating(false);
    }
  }

  /// Update contact information
  Future<bool> updateContactInfo({
    String? phone,
    String? email,
    String? telegram,
  }) async {
    if (_profile == null) {
      _setError('Профиль не загружен');
      return false;
    }

    final updatedProfile = _profile!.copyWith(
      phone: phone ?? _profile!.phone,
      email: email ?? _profile!.email,
      telegram: telegram ?? _profile!.telegram,
    );

    return await updateProfile(updatedProfile);
  }

  /// Update personal information
  Future<bool> updatePersonalInfo({
    String? fullName,
    String? avatarUrl,
  }) async {
    if (_profile == null) {
      _setError('Профиль не загружен');
      return false;
    }

    final updatedProfile = _profile!.copyWith(
      fullName: fullName ?? _profile!.fullName,
      avatarUrl: avatarUrl ?? _profile!.avatarUrl,
    );

    return await updateProfile(updatedProfile);
  }

  /// Refresh profile data
  Future<void> refresh() async {
    if (_profile != null) {
      await loadProfileByUid(_profile!.uid);
    } else {
      await loadProfile();
    }
  }

  /// Clear profile data (for logout)
  void clearProfile() {
    _profile = null;
    _error = null;
    _isLoading = false;
    _isUpdating = false;
    notifyListeners();
  }

  /// Load mock profile for testing
  void loadMockProfile() {
    _profile = ProfileService.createMockProfile();
    _error = null;
    _isLoading = false;
    _loggingService.info('Mock profile loaded');
    notifyListeners();
  }

  // Private methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setUpdating(bool updating) {
    if (_isUpdating != updating) {
      _isUpdating = updating;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

} 