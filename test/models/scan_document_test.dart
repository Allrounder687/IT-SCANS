import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/models/scan_document.dart';

void main() {
  group('ScanDocument', () {
    test('toMap and fromMap round-trip all fields', () {
      final createdAt = DateTime(2026, 8, 18, 14, 30);
      final doc = ScanDocument(
        id: 'doc-123',
        name: 'Tax Return 2026',
        pageCount: 18,
        filePath: '/data/scans/tax.pdf',
        createdAt: createdAt,
        isSynced: true,
        driveId: 'drive-abc',
        category: 'Taxes',
        subfolder: '2026',
        extractedText: 'Form 1040',
      );

      final roundTripped = ScanDocument.fromMap(doc.toMap());

      expect(roundTripped.id, doc.id);
      expect(roundTripped.name, doc.name);
      expect(roundTripped.pageCount, 18);
      expect(roundTripped.filePath, doc.filePath);
      expect(roundTripped.createdAt, createdAt);
      expect(roundTripped.isSynced, isTrue);
      expect(roundTripped.driveId, 'drive-abc');
      expect(roundTripped.category, 'Taxes');
      expect(roundTripped.subfolder, '2026');
      expect(roundTripped.extractedText, 'Form 1040');
    });

    test('copyWith preserves unspecified fields', () {
      final doc = ScanDocument(
        id: '1',
        name: 'Original',
        pageCount: 12,
        filePath: '/tmp/a.pdf',
        createdAt: DateTime(2026, 1, 1),
        isSynced: true,
        driveId: 'drv-1',
        category: 'Receipts',
        subfolder: 'Travel',
        extractedText: 'Hotel',
      );

      final renamed = doc.copyWith(name: 'Updated');

      expect(renamed.name, 'Updated');
      expect(renamed.isSynced, isTrue);
      expect(renamed.driveId, 'drv-1');
      expect(renamed.category, 'Receipts');
      expect(renamed.subfolder, 'Travel');
      expect(renamed.extractedText, 'Hotel');
    });
  });
}
