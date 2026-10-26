import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/vault_document.dart';
import '../../domain/vault_repository.dart';

// ---------------- Events ----------------

sealed class DocumentsEvent extends Equatable {
  const DocumentsEvent();

  @override
  List<Object?> get props => [];
}

/// Load the offline copy, then listen to Firestore for live updates.
final class DocumentsStarted extends DocumentsEvent {
  const DocumentsStarted();
}

final class DocumentAdded extends DocumentsEvent {
  const DocumentAdded(this.document, {this.filePath});

  final VaultDocument document;
  final String? filePath;

  @override
  List<Object?> get props => [document, filePath];
}

final class DocumentDeleted extends DocumentsEvent {
  const DocumentDeleted(this.document);

  final VaultDocument document;

  @override
  List<Object?> get props => [document];
}

// ---------------- State ----------------

enum DocumentsStatus { initial, loading, success, failure }

final class DocumentsState extends Equatable {
  const DocumentsState({
    this.status = DocumentsStatus.initial,
    this.documents = const [],
    this.isFromCache = false,
    this.isSaving = false,
    this.errorMessage,
  });

  final DocumentsStatus status;
  final List<VaultDocument> documents;

  /// True while we are showing the offline copy (before Firestore answers).
  final bool isFromCache;
  final bool isSaving;
  final String? errorMessage;

  DocumentsState copyWith({
    DocumentsStatus? status,
    List<VaultDocument>? documents,
    bool? isFromCache,
    bool? isSaving,
    String? errorMessage,
  }) =>
      DocumentsState(
        status: status ?? this.status,
        documents: documents ?? this.documents,
        isFromCache: isFromCache ?? this.isFromCache,
        isSaving: isSaving ?? this.isSaving,
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props =>
      [status, documents, isFromCache, isSaving, errorMessage];
}

// ---------------- Bloc ----------------

/// Manages the list of vault documents for one signed-in user.
class DocumentsBloc extends Bloc<DocumentsEvent, DocumentsState> {
  DocumentsBloc({required VaultRepository repository, required String uid})
      : _repository = repository,
        _uid = uid,
        super(const DocumentsState()) {
    on<DocumentsStarted>(_onStarted);
    on<DocumentAdded>(_onAdded);
    on<DocumentDeleted>(_onDeleted);
  }

  final VaultRepository _repository;
  final String _uid;

  Future<void> _onStarted(
    DocumentsStarted event,
    Emitter<DocumentsState> emit,
  ) async {
    // 1. Show the offline copy immediately (works without internet).
    final cached = _repository.getCachedDocuments(_uid);
    emit(state.copyWith(
      status: cached.isEmpty ? DocumentsStatus.loading : DocumentsStatus.success,
      documents: cached,
      isFromCache: cached.isNotEmpty,
    ));

    // 2. Replace it with live Firestore data as soon as it arrives.
    await emit.forEach<List<VaultDocument>>(
      _repository.watchDocuments(_uid),
      onData: (docs) => state.copyWith(
        status: DocumentsStatus.success,
        documents: docs,
        isFromCache: false,
      ),
      onError: (_, __) => state.copyWith(
        status: state.documents.isEmpty
            ? DocumentsStatus.failure
            : DocumentsStatus.success,
        errorMessage: 'Showing offline copy. Could not reach the server.',
      ),
    );
  }

  Future<void> _onAdded(
    DocumentAdded event,
    Emitter<DocumentsState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));
    try {
      await _repository.addDocument(
        _uid,
        event.document,
        filePath: event.filePath,
      );
      emit(state.copyWith(isSaving: false));
    } on Failure catch (f) {
      emit(state.copyWith(isSaving: false, errorMessage: f.message));
    }
  }

  Future<void> _onDeleted(
    DocumentDeleted event,
    Emitter<DocumentsState> emit,
  ) async {
    try {
      await _repository.deleteDocument(_uid, event.document);
    } on Failure catch (f) {
      emit(state.copyWith(errorMessage: f.message));
    }
  }
}
