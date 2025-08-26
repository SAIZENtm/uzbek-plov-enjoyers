import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:collection';

import 'api_service.dart';
import 'cache_service.dart';
import 'logging_service_secure.dart';
import 'auth_service.dart';

/// Enhanced Offline Service with queue management, conflict resolution, and auto-sync
class OfflineService {
  static const String _offlineDataKey = 'offline_data_v2';
  static const String _syncQueueKey = 'sync_queue_v2';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _conflictsKey = 'sync_conflicts';

  final ApiService apiService;
  final CacheService cacheService;
  final LoggingService loggingService;
  final AuthService authService;
  
  // Sync queue and status
  final Queue<OfflineAction> _syncQueue = Queue<OfflineAction>();
  bool _isSyncing = false;
  StreamController<OfflineSyncStatus>? _syncStatusController;
  Timer? _autoSyncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Cache management
  final Map<String, CacheEntry> _memoryCache = {};
  static const int _maxMemoryCacheSize = 100;

  OfflineService({
    required this.apiService,
    required this.cacheService,
    required this.loggingService,
    required this.authService,
  });

  /// Initialize offline service with auto-sync and connectivity monitoring
  Future<void> initialize() async {
    try {
      loggingService.info('🔄 Initializing enhanced offline service...');
      
      // Load existing queue from storage
      await _loadSyncQueue();
      
      // Setup connectivity monitoring
      _setupConnectivityMonitoring();
      
      // Setup auto-sync timer
      _setupAutoSync();
      
      // Create sync status stream
      _syncStatusController = StreamController<OfflineSyncStatus>.broadcast();
      
      loggingService.info('✅ Enhanced offline service initialized');
      loggingService.info('📊 OFFLINE SERVICE STATUS:');
      loggingService.info('   📦 Queue items: ${_syncQueue.length}');
      loggingService.info('   💾 Memory cache: ${_memoryCache.length} items');
      loggingService.info('   🔄 Auto-sync: Active');
      loggingService.info('   🌐 Connectivity monitoring: Active');
      
    } catch (e) {
      loggingService.error('Failed to initialize offline service', e);
    }
  }

  /// Dispose resources
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _syncStatusController?.close();
  }

  // ENHANCED DATA STORAGE WITH VERSIONING

  /// Save data with versioning and conflict detection
  Future<void> saveOfflineData(
    String key, 
    dynamic data, {
    OfflineDataType type = OfflineDataType.cache,
    Duration? expiry,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final entry = OfflineDataEntry(
        key: key,
        data: data,
        type: type,
        timestamp: DateTime.now(),
        version: await _getNextVersion(key),
        userId: authService.userData?['passport_number'] ?? 'anonymous',
        expiry: expiry != null ? DateTime.now().add(expiry) : null,
        metadata: metadata ?? {},
      );

      // Save to persistent storage
      await _saveDataEntry(entry);
      
      // Add to memory cache if cacheable
      if (type == OfflineDataType.cache) {
        _addToMemoryCache(key, entry);
      }

      loggingService.info('💾 Saved offline data: $key (v${entry.version}, ${type.name})');
    } catch (e) {
      loggingService.error('Failed to save offline data: $key', e);
    }
  }

  /// Get data with cache-first strategy
  Future<T?> getOfflineData<T>(
    String key, {
    bool useMemoryCache = true,
    bool fallbackToExpired = false,
  }) async {
    try {
      // Check memory cache first
      if (useMemoryCache && _memoryCache.containsKey(key)) {
        final entry = _memoryCache[key]!;
        if (!entry.isExpired || fallbackToExpired) {
          loggingService.info('📱 Memory cache hit: $key');
          return entry.data.data as T?;
        } else {
          _memoryCache.remove(key);
        }
      }

      // Check persistent storage
      final entry = await _getDataEntry(key);
      if (entry != null) {
        if (!entry.isExpired || fallbackToExpired) {
          // Add to memory cache
          _addToMemoryCache(key, entry);
          loggingService.info('💿 Disk cache hit: $key');
          return entry.data as T?;
        } else {
          await removeOfflineData(key);
        }
      }

      loggingService.info('❌ Cache miss: $key');
      return null;
    } catch (e) {
      loggingService.error('Failed to get offline data: $key', e);
      return null;
    }
  }

  // ENHANCED SYNC QUEUE MANAGEMENT

  /// Add action to sync queue
  Future<void> enqueueAction(OfflineAction action) async {
    try {
      action.id ??= DateTime.now().millisecondsSinceEpoch.toString();
      action.timestamp = DateTime.now();
      action.userId = authService.userData?['passport_number'] ?? 'anonymous';

      _syncQueue.add(action);
      await _saveSyncQueue();

      loggingService.info('➕ Added to sync queue: ${action.type.name} (${action.id})');
      
      // Try immediate sync if online
      if (await isOnline()) {
        _processSyncQueue();
      }
    } catch (e) {
      loggingService.error('Failed to enqueue action', e);
    }
  }

  /// Process sync queue with retry logic and conflict resolution
  Future<void> _processSyncQueue() async {
    if (_isSyncing || _syncQueue.isEmpty) return;

    try {
      _isSyncing = true;
      _broadcastSyncStatus(OfflineSyncStatus.syncing());

      loggingService.info('🔄 Processing sync queue: ${_syncQueue.length} items');

      final processedActions = <OfflineAction>[];
      final failedActions = <OfflineAction>[];

      while (_syncQueue.isNotEmpty) {
        final action = _syncQueue.removeFirst();
        
        try {
          final result = await _executeAction(action);
          
          if (result.success) {
            processedActions.add(action);
            loggingService.info('✅ Synced: ${action.type.name} (${action.id})');
          } else if (result.isConflict) {
            await _handleConflict(action, result);
            processedActions.add(action);
          } else {
            // Retry with exponential backoff
            action.retryCount++;
            if (action.retryCount < action.maxRetries) {
              action.nextRetry = DateTime.now().add(
                Duration(seconds: (2 * action.retryCount).clamp(1, 60))
              );
              _syncQueue.add(action);
            } else {
              failedActions.add(action);
              loggingService.error('❌ Failed after ${action.maxRetries} retries: ${action.type.name}');
            }
          }
        } catch (e) {
          loggingService.error('Error executing action: ${action.type.name}', e);
          failedActions.add(action);
        }
      }

      await _saveSyncQueue();
      
      final syncStatus = OfflineSyncStatus.completed();
      syncStatus.processedCount = processedActions.length;
      syncStatus.failedCount = failedActions.length;
      _broadcastSyncStatus(syncStatus);

      await updateLastSyncTimestamp();
      
    } catch (e) {
      loggingService.error('Error processing sync queue', e);
      _broadcastSyncStatus(OfflineSyncStatus.error());
    } finally {
      _isSyncing = false;
    }
  }

  /// Execute individual sync action
  Future<SyncResult> _executeAction(OfflineAction action) async {
    switch (action.type) {
      case OfflineActionType.createServiceRequest:
        return await _syncServiceRequest(action);
      case OfflineActionType.updateUtilityReading:
        return await _syncUtilityReading(action);
      case OfflineActionType.createFeedback:
        return await _syncFeedback(action);
      case OfflineActionType.updateProfile:
        return await _syncProfile(action);
      case OfflineActionType.markNewsAsRead:
        return await _syncNewsRead(action);
    }
  }

  // SPECIFIC SYNC IMPLEMENTATIONS

  Future<SyncResult> _syncServiceRequest(OfflineAction action) async {
    try {
      final data = action.data;
      
      // Check for existing request (conflict detection)
      if (action.targetId != null) {
        final existing = await FirebaseFirestore.instance
            .collection('serviceRequests')
            .doc(action.targetId)
            .get();
            
        if (existing.exists) {
          final existingData = existing.data()!;
          final existingTimestamp = existingData['lastModified'] as Timestamp?;
          
          if (existingTimestamp != null && 
              existingTimestamp.toDate().isAfter(action.timestamp)) {
            return SyncResult.conflict('Server version is newer');
          }
        }
      }

      // Create or update service request
      final docRef = action.targetId != null
          ? FirebaseFirestore.instance.collection('serviceRequests').doc(action.targetId)
          : FirebaseFirestore.instance.collection('serviceRequests').doc();

      await docRef.set({
        ...data,
        'lastModified': FieldValue.serverTimestamp(),
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<SyncResult> _syncUtilityReading(OfflineAction action) async {
    try {
      final data = action.data;
      
      await FirebaseFirestore.instance
          .collection('utilityReadings')
          .doc(action.targetId)
          .set({
        ...data,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<SyncResult> _syncFeedback(OfflineAction action) async {
    try {
      final data = action.data;
      
      await FirebaseFirestore.instance
          .collection('feedback')
          .add({
        ...data,
        'syncedAt': FieldValue.serverTimestamp(),
      });

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<SyncResult> _syncProfile(OfflineAction action) async {
    try {
      final data = action.data;
      final userId = authService.userData?['passport_number'];
      
      if (userId == null) {
        return SyncResult.error('User not authenticated');
      }

      await FirebaseFirestore.instance
          .collection('residents')
          .doc(userId)
          .update({
        ...data,
        'lastModified': FieldValue.serverTimestamp(),
      });

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  Future<SyncResult> _syncNewsRead(OfflineAction action) async {
    try {
      final data = action.data;
      
      await FirebaseFirestore.instance
          .collection('newsReadStatus')
          .doc('${action.userId}_${action.targetId}')
          .set({
        'userId': action.userId,
        'newsId': action.targetId,
        'readAt': Timestamp.fromDate(DateTime.parse(data['readAt'])),
        'syncedAt': FieldValue.serverTimestamp(),
      });

      return SyncResult.success();
    } catch (e) {
      return SyncResult.error(e.toString());
    }
  }

  // CONFLICT RESOLUTION

  Future<void> _handleConflict(OfflineAction action, SyncResult result) async {
    final conflict = ConflictData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      action: action,
      conflictReason: result.errorMessage ?? 'Unknown conflict',
      timestamp: DateTime.now(),
      resolved: false,
    );

    await _saveConflict(conflict);
    loggingService.warning('⚠️ Conflict detected: ${action.type.name} - ${result.errorMessage}');
  }

  /// Get all unresolved conflicts
  Future<List<ConflictData>> getConflicts() async {
    final prefs = await SharedPreferences.getInstance();
    final conflictsJson = prefs.getString(_conflictsKey) ?? '[]';
    final conflictsList = jsonDecode(conflictsJson) as List;
    
    return conflictsList
        .map((json) => ConflictData.fromJson(json))
        .where((conflict) => !conflict.resolved)
        .toList();
  }

  /// Resolve conflict with user choice
  Future<void> resolveConflict(String conflictId, ConflictResolution resolution) async {
    final conflicts = await getConflicts();
    final conflict = conflicts.firstWhere((c) => c.id == conflictId);
    
    conflict.resolved = true;
    conflict.resolution = resolution;
    
    await _saveConflict(conflict);
    
    // Re-enqueue with resolution strategy
    if (resolution == ConflictResolution.useLocal) {
      await enqueueAction(conflict.action);
    }
    
    loggingService.info('✅ Conflict resolved: $conflictId (${resolution.name})');
  }

  // CONNECTIVITY AND AUTO-SYNC

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOnlineNow = result != ConnectivityResult.none;
      
      if (isOnlineNow && _syncQueue.isNotEmpty) {
        loggingService.info('🌐 Connection restored, starting sync...');
        _processSyncQueue();
      }
    });
  }

  void _setupAutoSync() {
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      if (await isOnline() && _syncQueue.isNotEmpty) {
        _processSyncQueue();
      }
    });
  }

  // UTILITY METHODS

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> updateLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    final timestampString = prefs.getString(_lastSyncKey);
    return timestampString != null ? DateTime.parse(timestampString) : null;
  }

  Future<bool> needsSync() async {
    final lastSync = await getLastSyncTimestamp();
    if (lastSync == null) return true;
    
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    return lastSync.isBefore(oneHourAgo);
  }

  Future<void> clearOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_offlineDataKey);
    await prefs.remove(_syncQueueKey);
    await prefs.remove(_lastSyncKey);
    await prefs.remove(_conflictsKey);
    _memoryCache.clear();
    _syncQueue.clear();
  }

  /// Force manual sync
  Future<bool> forceSync() async {
    if (!await isOnline()) {
      loggingService.warning('Cannot sync: device is offline');
      return false;
    }

    await _processSyncQueue();
    return true;
  }

  /// Get sync status stream
  Stream<OfflineSyncStatus> get syncStatusStream => 
      _syncStatusController?.stream ?? const Stream.empty();

  /// Get sync queue status
  SyncQueueStatus get queueStatus => SyncQueueStatus(
    pendingCount: _syncQueue.length,
    isSyncing: _isSyncing,
    lastSync: getLastSyncTimestamp(),
  );

  // PRIVATE HELPER METHODS

  void _addToMemoryCache(String key, OfflineDataEntry entry) {
    if (_memoryCache.length >= _maxMemoryCacheSize) {
      // Remove oldest entry
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    
    _memoryCache[key] = CacheEntry(entry.data, entry.timestamp, entry.expiry);
  }

  Future<int> _getNextVersion(String key) async {
    final entry = await _getDataEntry(key);
    return (entry?.version ?? 0) + 1;
  }

  Future<void> _saveDataEntry(OfflineDataEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final allData = await _getAllDataEntries();
    allData[entry.key] = entry;
    
    final encoded = allData.map((key, entry) => 
        MapEntry(key, entry.toJson()));
    await prefs.setString(_offlineDataKey, jsonEncode(encoded));
  }

  Future<OfflineDataEntry?> _getDataEntry(String key) async {
    final allData = await _getAllDataEntries();
    return allData[key];
  }

  Future<Map<String, OfflineDataEntry>> _getAllDataEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_offlineDataKey) ?? '{}';
    final dataMap = jsonDecode(dataString) as Map<String, dynamic>;
    
    return dataMap.map((key, json) => 
        MapEntry(key, OfflineDataEntry.fromJson(json)));
  }

  Future<void> removeOfflineData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final allData = await _getAllDataEntries();
    allData.remove(key);
    _memoryCache.remove(key);
    
    final encoded = allData.map((key, entry) => 
        MapEntry(key, entry.toJson()));
    await prefs.setString(_offlineDataKey, jsonEncode(encoded));
  }

  Future<void> _loadSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey) ?? '[]';
      final queueList = jsonDecode(queueJson) as List;
      
      _syncQueue.clear();
      for (final actionJson in queueList) {
        _syncQueue.add(OfflineAction.fromJson(actionJson));
      }
    } catch (e) {
      loggingService.error('Failed to load sync queue', e);
    }
  }

  Future<void> _saveSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueList = _syncQueue.map((action) => action.toJson()).toList();
      await prefs.setString(_syncQueueKey, jsonEncode(queueList));
    } catch (e) {
      loggingService.error('Failed to save sync queue', e);
    }
  }

  Future<void> _saveConflict(ConflictData conflict) async {
    final prefs = await SharedPreferences.getInstance();
    final conflicts = await getConflicts();
    conflicts.add(conflict);
    
    final conflictsJson = conflicts.map((c) => c.toJson()).toList();
    await prefs.setString(_conflictsKey, jsonEncode(conflictsJson));
  }

  void _broadcastSyncStatus(OfflineSyncStatus status) {
    _syncStatusController?.add(status);
  }
}

// ENHANCED DATA MODELS

class OfflineDataEntry {
  final String key;
  final dynamic data;
  final OfflineDataType type;
  final DateTime timestamp;
  final int version;
  final String userId;
  final DateTime? expiry;
  final Map<String, dynamic> metadata;

  OfflineDataEntry({
    required this.key,
    required this.data,
    required this.type,
    required this.timestamp,
    required this.version,
    required this.userId,
    this.expiry,
    required this.metadata,
  });

  bool get isExpired => expiry != null && DateTime.now().isAfter(expiry!);

  Map<String, dynamic> toJson() => {
    'key': key,
    'data': data,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'version': version,
    'userId': userId,
    'expiry': expiry?.toIso8601String(),
    'metadata': metadata,
  };

  factory OfflineDataEntry.fromJson(Map<String, dynamic> json) => OfflineDataEntry(
    key: json['key'],
    data: json['data'],
    type: OfflineDataType.values.firstWhere((t) => t.name == json['type']),
    timestamp: DateTime.parse(json['timestamp']),
    version: json['version'],
    userId: json['userId'],
    expiry: json['expiry'] != null ? DateTime.parse(json['expiry']) : null,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
}

class OfflineAction {
  String? id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final String? targetId;
  DateTime timestamp;
  String userId;
  int retryCount;
  final int maxRetries;
  DateTime? nextRetry;

  OfflineAction({
    this.id,
    required this.type,
    required this.data,
    this.targetId,
    required this.timestamp,
    this.userId = '',
    this.retryCount = 0,
    this.maxRetries = 3,
    this.nextRetry,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'targetId': targetId,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'retryCount': retryCount,
    'maxRetries': maxRetries,
    'nextRetry': nextRetry?.toIso8601String(),
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id'],
    type: OfflineActionType.values.firstWhere((t) => t.name == json['type']),
    data: Map<String, dynamic>.from(json['data']),
    targetId: json['targetId'],
    timestamp: DateTime.parse(json['timestamp']),
    userId: json['userId'],
    retryCount: json['retryCount'] ?? 0,
    maxRetries: json['maxRetries'] ?? 3,
    nextRetry: json['nextRetry'] != null ? DateTime.parse(json['nextRetry']) : null,
  );
}

class SyncResult {
  final bool success;
  final String? errorMessage;
  final bool isConflict;

  SyncResult.success() : success = true, errorMessage = null, isConflict = false;
  SyncResult.error(this.errorMessage) : success = false, isConflict = false;
  SyncResult.conflict(this.errorMessage) : success = false, isConflict = true;
}

class ConflictData {
  final String id;
  final OfflineAction action;
  final String conflictReason;
  final DateTime timestamp;
  bool resolved;
  ConflictResolution? resolution;

  ConflictData({
    required this.id,
    required this.action,
    required this.conflictReason,
    required this.timestamp,
    this.resolved = false,
    this.resolution,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'action': action.toJson(),
    'conflictReason': conflictReason,
    'timestamp': timestamp.toIso8601String(),
    'resolved': resolved,
    'resolution': resolution?.name,
  };

  factory ConflictData.fromJson(Map<String, dynamic> json) => ConflictData(
    id: json['id'],
    action: OfflineAction.fromJson(json['action']),
    conflictReason: json['conflictReason'],
    timestamp: DateTime.parse(json['timestamp']),
    resolved: json['resolved'] ?? false,
    resolution: json['resolution'] != null 
        ? ConflictResolution.values.firstWhere((r) => r.name == json['resolution'])
        : null,
  );
}

class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final DateTime? expiry;

  CacheEntry(this.data, this.timestamp, this.expiry);

  bool get isExpired => expiry != null && DateTime.now().isAfter(expiry!);
}

class OfflineSyncStatus {
  final SyncState state;
  int processedCount;
  int failedCount;
  String? errorMessage;

  OfflineSyncStatus(this.state, {this.processedCount = 0, this.failedCount = 0, this.errorMessage});

  static OfflineSyncStatus idle() => OfflineSyncStatus(SyncState.idle);
  static OfflineSyncStatus syncing() => OfflineSyncStatus(SyncState.syncing);
  static OfflineSyncStatus completed() => OfflineSyncStatus(SyncState.completed);
  static OfflineSyncStatus error() => OfflineSyncStatus(SyncState.error);
}

class SyncQueueStatus {
  final int pendingCount;
  final bool isSyncing;
  final Future<DateTime?> lastSync;

  SyncQueueStatus({
    required this.pendingCount,
    required this.isSyncing,
    required this.lastSync,
  });
}

// ENUMS

enum OfflineDataType {
  cache,
  userAction,
  systemData,
}

enum OfflineActionType {
  createServiceRequest,
  updateUtilityReading,
  createFeedback,
  updateProfile,
  markNewsAsRead,
}

enum ConflictResolution {
  useLocal,
  useServer,
  merge,
  skip,
}

enum SyncState {
  idle,
  syncing,
  completed,
  error,
} 