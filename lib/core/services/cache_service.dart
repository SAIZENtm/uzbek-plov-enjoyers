import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';

class CacheService {
  final SharedPreferences sharedPreferences;
  late Box<dynamic> _cacheBox;
  static const String _cacheBoxName = 'app_cache';
  static const int _maxCacheSize = 50 * 1024 * 1024; // 50MB
  static const Duration _defaultExpiration = Duration(days: 1);

  CacheService({required this.sharedPreferences}) {
    _initializeHive();
  }

  Future<void> _initializeHive() async {
    final appDir = await getApplicationDocumentsDirectory();
    Hive.init(appDir.path);
    _cacheBox = await Hive.openBox<dynamic>(_cacheBoxName);
    
    // Clean expired cache on initialization
    await _cleanExpiredCache();
  }

  Future<void> set(
    String key,
    dynamic value, {
    Duration expiration = _defaultExpiration,
  }) async {
    final cacheItem = CacheItem(
      value: value,
      expiresAt: DateTime.now().add(expiration),
    );

    // Check cache size before adding
    await _ensureCacheSize();
    
    await _cacheBox.put(key, cacheItem.toJson());
  }

  Future<T?> get<T>(String key) async {
    final data = await _cacheBox.get(key);
    if (data == null) return null;

    final cacheItem = CacheItem.fromJson(data);
    
    if (cacheItem.isExpired) {
      await _cacheBox.delete(key);
      return null;
    }

    return cacheItem.value as T;
  }

  Future<void> remove(String key) async {
    await _cacheBox.delete(key);
  }

  Future<void> clear() async {
    await _cacheBox.clear();
  }

  Future<void> _cleanExpiredCache() async {
    final keys = _cacheBox.keys.toList();
    
    for (final key in keys) {
      final data = await _cacheBox.get(key);
      if (data != null) {
        final cacheItem = CacheItem.fromJson(data);
        if (cacheItem.isExpired) {
          await _cacheBox.delete(key);
        }
      }
    }
  }

  Future<void> _ensureCacheSize() async {
    final cacheDir = await getTemporaryDirectory();
    final cacheSize = await _calculateDirectorySize(cacheDir);

    if (cacheSize > _maxCacheSize) {
      // Remove oldest items first
      final entries = _cacheBox.toMap().entries.toList()
        ..sort((a, b) {
          final aItem = CacheItem.fromJson(a.value);
          final bItem = CacheItem.fromJson(b.value);
          return aItem.expiresAt.compareTo(bItem.expiresAt);
        });

      // Remove oldest 20% of items
      final itemsToRemove = (entries.length * 0.2).ceil();
      for (var i = 0; i < itemsToRemove; i++) {
        await _cacheBox.delete(entries[i].key);
      }
    }
  }

  Future<int> _calculateDirectorySize(Directory directory) async {
    int totalSize = 0;
    final files = directory.listSync(recursive: true, followLinks: false);
    
    for (final file in files) {
      if (file is File) {
        totalSize += await file.length();
      }
    }
    
    return totalSize;
  }

  // Utility methods for specific data types
  Future<void> write(String key, dynamic value) async {
    if (value == null) {
      await sharedPreferences.remove(key);
      return;
    }

    if (value is String) {
      await sharedPreferences.setString(key, value);
    } else if (value is bool) {
      await sharedPreferences.setBool(key, value);
    } else if (value is int) {
      await sharedPreferences.setInt(key, value);
    } else if (value is double) {
      await sharedPreferences.setDouble(key, value);
    } else if (value is List<String>) {
      await sharedPreferences.setStringList(key, value);
    } else {
      await sharedPreferences.setString(key, jsonEncode(value));
    }
  }

  Future<dynamic> read(String key) async {
    final value = sharedPreferences.get(key);
    if (value == null) return null;

    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  Future<void> delete(String key) async {
    await sharedPreferences.remove(key);
  }

  bool containsKey(String key) {
    return sharedPreferences.containsKey(key);
  }

  Set<String> getKeys() {
    return sharedPreferences.getKeys();
  }
}

class CacheItem {
  final dynamic value;
  final DateTime expiresAt;

  CacheItem({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory CacheItem.fromJson(dynamic json) {
    if (json is Map) {
      return CacheItem(
        value: json['value'],
        expiresAt: DateTime.parse(json['expiresAt'].toString()),
      );
    }
    throw ArgumentError('Invalid cache item format');
  }
} 