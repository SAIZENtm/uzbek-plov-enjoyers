import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static const String _keyStorageKey = 'encryption_key';
  late final Key _key;
  late final IV _iv;
  late final Encrypter _encrypter;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  EncryptionService() {
    _initializeEncryption();
  }

  Future<void> _initializeEncryption() async {
    String? storedKey = await _secureStorage.read(key: _keyStorageKey);
    if (storedKey == null) {
      final key = Key.fromSecureRandom(32);
      await _secureStorage.write(
        key: _keyStorageKey,
        value: base64Encode(key.bytes),
      );
      storedKey = base64Encode(key.bytes);
    }

    _key = Key(base64Decode(storedKey));
    _iv = IV.fromSecureRandom(16);
    _encrypter = Encrypter(AES(_key));
  }

  String encrypt(String data) {
    return _encrypter.encrypt(data, iv: _iv).base64;
  }

  String decrypt(String encryptedData) {
    return _encrypter.decrypt64(encryptedData, iv: _iv);
  }

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String hashString(String input) {
    try {
      final bytes = utf8.encode(input);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw Exception('Hashing failed: $e');
    }
  }

  bool verifyHash(String input, String hash) {
    try {
      final computedHash = hashString(input);
      return computedHash == hash;
    } catch (e) {
      throw Exception('Hash verification failed: $e');
    }
  }

  // For sensitive data like API keys
  Future<void> secureStore(String key, String value) async {
    final encrypted = encrypt(value);
    await _secureStorage.write(key: key, value: encrypted);
  }

  Future<String?> secureRetrieve(String key) async {
    final encrypted = await _secureStorage.read(key: key);
    if (encrypted == null) return null;
    return decrypt(encrypted);
  }

  Future<void> secureDelete(String key) async {
    await _secureStorage.delete(key: key);
  }

  // Generate a random secure token
  String generateSecureToken() {
    final random = Key.fromSecureRandom(32);
    return base64.encode(random.bytes);
  }

  Future<void> changeEncryptionKey() async {
    final newKey = Key.fromSecureRandom(32);
    await _secureStorage.write(
      key: _keyStorageKey,
      value: base64Encode(newKey.bytes),
    );
    _key = newKey;
    _encrypter = Encrypter(AES(_key));
  }

  Future<void> clearEncryptionKey() async {
    await _secureStorage.delete(key: _keyStorageKey);
  }
} 