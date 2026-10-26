import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

/// Keeps the encryption key for the offline Hive cache in secure storage.
///
/// flutter_secure_storage saves values in the Android Keystore / iOS Keychain,
/// which is protected by the OS. We generate a random 256-bit key once,
/// store it there, and use it to encrypt the local vault cache with AES.
/// So even if someone copies the app's files, the cached data is unreadable.
class SecureKeyStore {
  SecureKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _hiveKeyName = 'safevault_hive_key';

  Future<List<int>> getOrCreateHiveKey() async {
    final existing = await _storage.read(key: _hiveKeyName);
    if (existing != null) {
      return base64Url.decode(existing);
    }
    final key = Hive.generateSecureKey(); // 32 random bytes
    await _storage.write(key: _hiveKeyName, value: base64UrlEncode(key));
    return key;
  }

  /// Removes the key (for example when the user deletes their account).
  Future<void> deleteHiveKey() => _storage.delete(key: _hiveKeyName);
}
