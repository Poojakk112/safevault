import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:safevault/core/errors/failures.dart';
import 'package:safevault/features/vault/domain/vault_document.dart';
import 'package:safevault/features/vault/domain/vault_repository.dart';
import 'package:safevault/features/vault/presentation/bloc/documents_bloc.dart';

class MockVaultRepository extends Mock implements VaultRepository {}

void main() {
  late MockVaultRepository repo;
  const uid = 'u1';
  final doc = VaultDocument(
    id: 'd1',
    title: 'SBI savings account',
    category: DocumentCategory.bank,
    createdAt: DateTime(2026, 10, 26),
  );
  final doc2 = VaultDocument(
    id: 'd2',
    title: 'LIC policy',
    category: DocumentCategory.insurance,
    createdAt: DateTime(2026, 10, 27),
  );

  setUpAll(() => registerFallbackValue(doc));
  setUp(() => repo = MockVaultRepository());

  blocTest<DocumentsBloc, DocumentsState>(
    'shows the offline copy first, then live data',
    setUp: () {
      when(() => repo.getCachedDocuments(uid)).thenReturn([doc]);
      when(() => repo.watchDocuments(uid))
          .thenAnswer((_) => Stream.value([doc2, doc]));
    },
    build: () => DocumentsBloc(repository: repo, uid: uid),
    act: (bloc) => bloc.add(const DocumentsStarted()),
    expect: () => [
      DocumentsState(
        status: DocumentsStatus.success,
        documents: [doc],
        isFromCache: true,
      ),
      DocumentsState(
        status: DocumentsStatus.success,
        documents: [doc2, doc],
      ),
    ],
  );

  blocTest<DocumentsBloc, DocumentsState>(
    'shows loading when there is no offline copy',
    setUp: () {
      when(() => repo.getCachedDocuments(uid)).thenReturn([]);
      when(() => repo.watchDocuments(uid))
          .thenAnswer((_) => Stream.value(const []));
    },
    build: () => DocumentsBloc(repository: repo, uid: uid),
    act: (bloc) => bloc.add(const DocumentsStarted()),
    expect: () => const [
      DocumentsState(status: DocumentsStatus.loading),
      DocumentsState(status: DocumentsStatus.success),
    ],
  );

  blocTest<DocumentsBloc, DocumentsState>(
    'emits failure when the server fails and there is no offline copy',
    setUp: () {
      when(() => repo.getCachedDocuments(uid)).thenReturn([]);
      when(() => repo.watchDocuments(uid))
          .thenAnswer((_) => Stream.error(Exception('offline')));
    },
    build: () => DocumentsBloc(repository: repo, uid: uid),
    act: (bloc) => bloc.add(const DocumentsStarted()),
    expect: () => const [
      DocumentsState(status: DocumentsStatus.loading),
      DocumentsState(
        status: DocumentsStatus.failure,
        errorMessage: 'Showing offline copy. Could not reach the server.',
      ),
    ],
  );

  blocTest<DocumentsBloc, DocumentsState>(
    'saving a document toggles isSaving and passes the file path',
    setUp: () => when(() => repo.addDocument(uid, any(),
        filePath: any(named: 'filePath'))).thenAnswer((_) async {}),
    build: () => DocumentsBloc(repository: repo, uid: uid),
    act: (bloc) => bloc.add(DocumentAdded(doc, filePath: '/tmp/a.pdf')),
    expect: () => const [
      DocumentsState(isSaving: true),
      DocumentsState(isSaving: false),
    ],
    verify: (_) => verify(() =>
            repo.addDocument(uid, doc, filePath: '/tmp/a.pdf')).called(1),
  );

  blocTest<DocumentsBloc, DocumentsState>(
    'shows an error message when saving fails',
    setUp: () => when(() => repo.addDocument(uid, any(),
            filePath: any(named: 'filePath')))
        .thenThrow(const VaultFailure('Could not save document.')),
    build: () => DocumentsBloc(repository: repo, uid: uid),
    act: (bloc) => bloc.add(DocumentAdded(doc)),
    expect: () => const [
      DocumentsState(isSaving: true),
      DocumentsState(errorMessage: 'Could not save document.'),
    ],
  );
}
