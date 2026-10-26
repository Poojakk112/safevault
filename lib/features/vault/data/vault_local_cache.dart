import 'package:hive/hive.dart';

import '../domain/vault_document.dart';

/// Offline copy of the vault, stored in an AES-encrypted Hive box.
///
/// Hive returns `Map<dynamic, dynamic>`, so we convert each entry back to
/// `Map<String, dynamic>` before creating the model.
class VaultLocalCache {
  VaultLocalCache(this._box);

  final Box<dynamic> _box;

  String _key(String uid) => 'documents_$uid';

  Future<void> saveDocuments(String uid, List<VaultDocument> documents) =>
      _box.put(_key(uid), documents.map((d) => d.toMap()).toList());

  List<VaultDocument> readDocuments(String uid) {
    final raw = _box.get(_key(uid));
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => VaultDocument.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<void> clear(String uid) => _box.delete(_key(uid));
}
