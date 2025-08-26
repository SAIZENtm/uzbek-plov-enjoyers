import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../services/offline_service.dart';

/// Extensions for easy offline functionality integration
extension OfflineContext on BuildContext {
  /// Get offline service instance
  OfflineService get offline => GetIt.instance<OfflineService>();
  
  /// Check if device is online
  Future<bool> get isOnline => offline.isOnline();
  
  /// Save data with automatic offline handling
  Future<void> saveOfflineData(
    String key, 
    dynamic data, {
    OfflineDataType type = OfflineDataType.cache,
    Duration? expiry,
  }) async {
    await offline.saveOfflineData(key, data, type: type, expiry: expiry);
  }
  
  /// Get cached data with offline fallback
  Future<T?> getCachedData<T>(String key) async {
    return await offline.getOfflineData<T>(key);
  }
  
  /// Queue action for offline sync
  Future<void> queueOfflineAction(OfflineActionType type, Map<String, dynamic> data, {String? targetId}) async {
    final action = OfflineAction(
      type: type,
      data: data,
      targetId: targetId,
      timestamp: DateTime.now(),
    );
    
    await offline.enqueueAction(action);
  }
}

/// Extensions for offline-aware service requests
extension OfflineServiceRequest on Map<String, dynamic> {
  /// Create service request with offline support
  Future<void> createOfflineServiceRequest(BuildContext context) async {
    final offline = context.offline;
    
    if (await context.isOnline) {
      // Online - try immediate sync
      await offline.enqueueAction(OfflineAction(
        type: OfflineActionType.createServiceRequest,
        data: this,
        timestamp: DateTime.now(),
      ));
    } else {
      // Offline - queue for later
      await offline.enqueueAction(OfflineAction(
        type: OfflineActionType.createServiceRequest,
        data: this,
        timestamp: DateTime.now(),
      ));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Заявка сохранена и будет отправлена при подключении к интернету'),
              ],
            ),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}

/// Extensions for offline-aware utility readings
extension OfflineUtilityReading on Map<String, dynamic> {
  /// Submit utility reading with offline support
  Future<void> submitOfflineReading(BuildContext context, String readingId) async {
    final offline = context.offline;
    
    await offline.enqueueAction(OfflineAction(
      type: OfflineActionType.updateUtilityReading,
      data: this,
      targetId: readingId,
      timestamp: DateTime.now(),
    ));
    
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final isOnline = await context.isOnline;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_upload : Icons.cloud_queue,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(isOnline 
                  ? 'Показания отправлены'
                  : 'Показания сохранены для отправки'),
            ],
          ),
          backgroundColor: isOnline ? Colors.green.shade600 : Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Extensions for offline-aware news interaction
extension OfflineNewsAction on String {
  /// Mark news as read with offline support
  Future<void> markNewsAsReadOffline(BuildContext context) async {
    final offline = context.offline;
    
    // Save read status locally immediately
    await offline.saveOfflineData(
      'news_read_$this',
      {'readAt': DateTime.now().toIso8601String()},
      type: OfflineDataType.userAction,
    );
    
    // Queue for server sync
    await offline.enqueueAction(OfflineAction(
      type: OfflineActionType.markNewsAsRead,
      data: {'readAt': DateTime.now().toIso8601String()},
      targetId: this,
      timestamp: DateTime.now(),
    ));
  }
  
  /// Check if news is read (including offline status)
  Future<bool> isNewsReadOffline(BuildContext context) async {
    final offline = context.offline;
    final localRead = await offline.getOfflineData('news_read_$this');
    return localRead != null;
  }
}

/// Extensions for offline-aware profile updates
extension OfflineProfileUpdate on Map<String, dynamic> {
  /// Update profile with offline support
  Future<void> updateProfileOffline(BuildContext context) async {
    final offline = context.offline;
    
    // Save profile data locally
    await offline.saveOfflineData(
      'user_profile',
      this,
      type: OfflineDataType.userAction,
      expiry: const Duration(days: 30),
    );
    
    // Queue for server sync
    await offline.enqueueAction(OfflineAction(
      type: OfflineActionType.updateProfile,
      data: this,
      timestamp: DateTime.now(),
    ));
    
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final isOnline = await context.isOnline;
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isOnline ? Icons.cloud_done : Icons.cloud_queue,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(isOnline 
                  ? 'Профиль обновлен'
                  : 'Изменения сохранены локально'),
            ],
          ),
          backgroundColor: isOnline ? Colors.green.shade600 : Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Offline-aware widget mixin
mixin OfflineAwareMixin<T extends StatefulWidget> on State<T> {
  late final OfflineService _offlineService;
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _offlineService = GetIt.instance<OfflineService>();
    _checkConnectivity();
    _setupOfflineListeners();
  }
  
  void _checkConnectivity() async {
    _isOnline = await _offlineService.isOnline();
    if (mounted) setState(() {});
  }
  
  void _setupOfflineListeners() {
    _offlineService.syncStatusStream.listen((status) {
      if (mounted) {
        onSyncStatusChanged(status);
      }
    });
  }
  
  /// Override this method to handle sync status changes
  void onSyncStatusChanged(OfflineSyncStatus status) {
    // Default implementation - can be overridden
    switch (status.state) {
      case SyncState.completed:
        if (status.processedCount > 0) {
          _showSyncSuccess(status.processedCount);
        }
        break;
      case SyncState.error:
        _showSyncError();
        break;
      default:
        break;
    }
  }
  
  void _showSyncSuccess(int count) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Text('Синхронизировано $count элементов'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
  
  void _showSyncError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Ошибка синхронизации'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: 'Повторить',
            textColor: Colors.white,
            onPressed: () => _offlineService.forceSync(),
          ),
        ),
      );
    }
  }
  
  /// Get current offline status
  bool get isOnline => _isOnline;
  
  /// Get offline service instance
  OfflineService get offlineService => _offlineService;
  
  /// Force sync with user feedback
  Future<void> forceSync() async {
    final success = await _offlineService.forceSync();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Нет подключения к интернету'),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}

/// Offline-aware form mixin for automatic data saving
mixin OfflineFormMixin<T extends StatefulWidget> on State<T> {
  late final OfflineService _offlineService;
  String? _formKey;
  
  @override
  void initState() {
    super.initState();
    _offlineService = GetIt.instance<OfflineService>();
    _formKey = 'form_draft_${widget.runtimeType}_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Save form data as draft
  Future<void> saveDraft(Map<String, dynamic> formData) async {
    if (_formKey != null) {
      await _offlineService.saveOfflineData(
        _formKey!,
        formData,
        type: OfflineDataType.userAction,
        expiry: const Duration(days: 7), // Drafts expire after 7 days
      );
    }
  }
  
  /// Load saved draft
  Future<Map<String, dynamic>?> loadDraft() async {
    if (_formKey != null) {
      return await _offlineService.getOfflineData<Map<String, dynamic>>(_formKey!);
    }
    return null;
  }
  
  /// Clear draft after successful submission
  Future<void> clearDraft() async {
    if (_formKey != null) {
      await _offlineService.removeOfflineData(_formKey!);
    }
  }
} 