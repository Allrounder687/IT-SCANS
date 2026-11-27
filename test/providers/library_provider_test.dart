import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/models/category_model.dart';
import 'package:itscans/models/scan_document.dart';
import 'package:itscans/providers/library_provider.dart';
import 'package:itscans/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStorageService extends StorageService {
  final List<ScanDocument> savedDocs = [];
  final List<AppSection> savedSections = [];
  final List<AppSubfolder> savedSubfolders = [];
  final Duration loadDelay;

  _FakeStorageService({this.loadDelay = Duration.zero});

  @override
  Future<List<ScanDocument>> getScanDocuments() async {
    if (loadDelay > Duration.zero) {
      await Future<void>.delayed(loadDelay);
    }
    return List<ScanDocument>.from(savedDocs);
  }

  @override
  Future<List<AppSection>> getSections() async =>
      List<AppSection>.from(savedSections);

  @override
  Future<List<AppSubfolder>> getAllSubfolders() async =>
      List<AppSubfolder>.from(savedSubfolders);

  @override
  Future<void> saveScanDocument(ScanDocument doc) async {
    savedDocs.removeWhere((d) => d.id == doc.id);
    savedDocs.insert(0, doc);
  }

  @override
  Future<void> updateDocumentName(String id, String newName) async {
    final idx = savedDocs.indexWhere((d) => d.id == id);
    if (idx != -1) {
      savedDocs[idx] = savedDocs[idx].copyWith(name: newName);
    }
  }

  @override
  Future<void> updateSyncStatus(
    String id,
    bool isSynced, {
    String? driveId,
  }) async {
    final idx = savedDocs.indexWhere((d) => d.id == id);
    if (idx != -1) {
      savedDocs[idx] = savedDocs[idx].copyWith(
        isSynced: isSynced,
        driveId: driveId ?? savedDocs[idx].driveId,
      );
    }
  }

  @override
  Future<void> deleteDocument(String id) async {
    savedDocs.removeWhere((d) => d.id == id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'addDocument waits for initial load so recovered scans are not overwritten',
      () async {
    final storage = _FakeStorageService(
      loadDelay: const Duration(milliseconds: 50),
    );
    final provider = LibraryProvider(storage);

    final recoveredDoc = ScanDocument(
      id: 'recovered-1',
      name: 'Scan 2026-08-18',
      pageCount: 9,
      filePath: '/tmp/recovered.pdf',
      createdAt: DateTime(2026, 8, 18),
      category: 'Documents',
    );

    await provider.addDocument(recoveredDoc);

    expect(provider.documents.length, 1);
    expect(provider.findById('recovered-1')?.pageCount, 9);
  });

  test('renameDocument preserves sync status, driveId, and subfolder',
      () async {
    final storage = _FakeStorageService();
    final provider = LibraryProvider(storage);
    await provider.ready;

    final doc = ScanDocument(
      id: 'doc-1',
      name: 'Scan 2026',
      pageCount: 6,
      filePath: '/tmp/doc1.pdf',
      createdAt: DateTime(2026, 8, 18),
      isSynced: true,
      driveId: 'drive-99',
      category: 'Invoices',
      subfolder: 'ClientA',
    );

    await provider.addDocument(doc);
    await provider.renameDocument(
      'doc-1',
      'Acme Invoice',
      extractedText: 'Total \$500',
    );

    final updated = provider.findById('doc-1');
    expect(updated, isNotNull);
    expect(updated!.name, 'Acme Invoice');
    expect(updated.isSynced, isTrue);
    expect(updated.driveId, 'drive-99');
    expect(updated.category, 'Invoices');
    expect(updated.subfolder, 'ClientA');
    expect(updated.extractedText, 'Total \$500');
  });

  test('updateSyncStatus preserves subfolder', () async {
    final storage = _FakeStorageService();
    final provider = LibraryProvider(storage);
    await provider.ready;

    final doc = ScanDocument(
      id: 'doc-2',
      name: 'Passport',
      pageCount: 2,
      filePath: '/tmp/doc2.pdf',
      createdAt: DateTime(2026, 8, 18),
      category: 'IDs',
      subfolder: 'Family',
    );

    await provider.addDocument(doc);
    await provider.updateSyncStatus('doc-2', true, driveId: 'drv-2');

    final updated = provider.findById('doc-2');
    expect(updated!.isSynced, isTrue);
    expect(updated.driveId, 'drv-2');
    expect(updated.subfolder, 'Family');
  });

  test('deleteDocument removes immediately and undoDelete restores it',
      () async {
    final storage = _FakeStorageService();
    final provider = LibraryProvider(storage);
    await provider.ready;

    final doc = ScanDocument(
      id: 'doc-3',
      name: 'Receipt',
      pageCount: 1,
      filePath: '/tmp/doc3.pdf',
      createdAt: DateTime(2026, 8, 18),
      category: 'Receipts',
    );

    await provider.addDocument(doc);
    expect(provider.documents.length, 1);

    provider.deleteDocument('doc-3');
    expect(provider.documents, isEmpty);

    provider.undoDelete('doc-3');
    expect(provider.documents.length, 1);
    expect(provider.documents.first.id, 'doc-3');
  });
}
