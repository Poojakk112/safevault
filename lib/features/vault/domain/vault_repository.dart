import 'nominee.dart';
import 'vault_document.dart';

/// What the app needs to store and read the vault.
abstract class VaultRepository {
  /// Offline copy saved on the phone (shown instantly on app start).
  List<VaultDocument> getCachedDocuments(String uid);

  /// Live list of documents from Firestore; also refreshes the offline copy.
  Stream<List<VaultDocument>> watchDocuments(String uid);

  /// Saves a document. If [filePath] is given, the file is uploaded first.
  Future<void> addDocument(
    String uid,
    VaultDocument document, {
    String? filePath,
  });

  Future<void> deleteDocument(String uid, VaultDocument document);

  Stream<List<Nominee>> watchNominees(String uid);

  Future<void> addNominee(String uid, Nominee nominee);

  Future<void> deleteNominee(String uid, String nomineeId);
}
