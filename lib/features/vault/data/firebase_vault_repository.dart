import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/errors/failures.dart';
import '../domain/nominee.dart';
import '../domain/vault_document.dart';
import '../domain/vault_repository.dart';
import 'vault_local_cache.dart';

/// Stores the vault in Firebase:
///   Firestore: users/{uid}/documents/{docId}
///              users/{uid}/nominees/{nomineeId}
///   Storage:   users/{uid}/documents/{docId}/{fileName}
///
/// Firestore security rules (see firestore.rules) make sure each user can
/// only read and write their own `users/{uid}` data.
class FirebaseVaultRepository implements VaultRepository {
  FirebaseVaultRepository({
    required VaultLocalCache cache,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _cache = cache,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final VaultLocalCache _cache;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _documents(String uid) =>
      _firestore.collection('users').doc(uid).collection('documents');

  CollectionReference<Map<String, dynamic>> _nominees(String uid) =>
      _firestore.collection('users').doc(uid).collection('nominees');

  @override
  List<VaultDocument> getCachedDocuments(String uid) =>
      _cache.readDocuments(uid);

  @override
  Stream<List<VaultDocument>> watchDocuments(String uid) => _documents(uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
        final docs = snapshot.docs
            .map((d) => VaultDocument.fromMap({...d.data(), 'id': d.id}))
            .toList();
        await _cache.saveDocuments(uid, docs); // keep offline copy fresh
        return docs;
      });

  @override
  Future<void> addDocument(
    String uid,
    VaultDocument document, {
    String? filePath,
  }) async {
    try {
      var toSave = document;
      if (filePath != null) {
        final file = File(filePath);
        final fileName = file.uri.pathSegments.last;
        final ref = _storage
            .ref()
            .child('users/$uid/documents/${document.id}/$fileName');
        await ref.putFile(
          file,
          SettableMetadata(contentType: _contentTypeFor(fileName)),
        );
        final url = await ref.getDownloadURL();
        toSave = document.copyWith(fileUrl: url, fileName: fileName);
      }
      await _documents(uid).doc(toSave.id).set(toSave.toMap());
    } on FirebaseException catch (e) {
      throw VaultFailure('Could not save document (${e.code}).');
    }
  }

  /// Storage rules only accept PDFs and images, so we set the type.
  static String _contentTypeFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<void> deleteDocument(String uid, VaultDocument document) async {
    try {
      if (document.fileName != null) {
        await _storage
            .ref()
            .child('users/$uid/documents/${document.id}/${document.fileName}')
            .delete()
            .catchError((Object _) {}); // file may already be gone
      }
      await _documents(uid).doc(document.id).delete();
    } on FirebaseException catch (e) {
      throw VaultFailure('Could not delete document (${e.code}).');
    }
  }

  @override
  Stream<List<Nominee>> watchNominees(String uid) =>
      _nominees(uid).orderBy('name').snapshots().map((snapshot) => snapshot
          .docs
          .map((d) => Nominee.fromMap({...d.data(), 'id': d.id}))
          .toList());

  @override
  Future<void> addNominee(String uid, Nominee nominee) async {
    try {
      await _nominees(uid).doc(nominee.id).set(nominee.toMap());
    } on FirebaseException catch (e) {
      throw VaultFailure('Could not save nominee (${e.code}).');
    }
  }

  @override
  Future<void> deleteNominee(String uid, String nomineeId) async {
    try {
      await _nominees(uid).doc(nomineeId).delete();
    } on FirebaseException catch (e) {
      throw VaultFailure('Could not delete nominee (${e.code}).');
    }
  }
}
