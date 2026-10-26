import 'package:flutter_test/flutter_test.dart';
import 'package:safevault/features/vault/domain/nominee.dart';
import 'package:safevault/features/vault/domain/vault_document.dart';

void main() {
  group('VaultDocument', () {
    test('toMap / fromMap round trip keeps all fields', () {
      final doc = VaultDocument(
        id: 'd1',
        title: 'LIC policy',
        category: DocumentCategory.insurance,
        notes: 'Papers in the steel cupboard',
        fileUrl: 'https://example.com/f.pdf',
        fileName: 'f.pdf',
        nomineeIds: const ['n1', 'n2'],
        createdAt: DateTime(2026, 10, 26, 17),
      );
      expect(VaultDocument.fromMap(doc.toMap()), doc);
    });

    test('fromMap handles missing optional fields and unknown category', () {
      final doc = VaultDocument.fromMap({'id': 'd2', 'category': 'crypto'});
      expect(doc.title, '');
      expect(doc.category, DocumentCategory.other);
      expect(doc.nomineeIds, isEmpty);
      expect(doc.hasFile, isFalse);
    });
  });

  test('Nominee toMap / fromMap round trip', () {
    const n = Nominee(
      id: 'n1',
      name: 'Kallayya',
      relation: 'Father',
      phone: '9999999999',
    );
    expect(Nominee.fromMap(n.toMap()), n);
  });
}
