import 'dart:io';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/services/scanner_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _FakeScannerAdapter implements DocumentScannerAdapter {
  int? capturedMaxPages;
  PdfScanResult? resultToReturn;

  _FakeScannerAdapter({this.resultToReturn});

  @override
  Future<PdfScanResult?> scanAsPdf({required int maxPages}) async {
    capturedMaxPages = maxPages;
    return resultToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;
  late Directory cacheDir;
  late Directory saveDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempRoot = await Directory.systemTemp.createTemp('scanner_service_test_');
    cacheDir = Directory(p.join(tempRoot.path, 'cache'))..createSync();
    saveDir = Directory(p.join(tempRoot.path, 'permanent'))..createSync();
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('passes high page limit (>= 100) instead of plugin default 4', () async {
    final sourcePdf = File(p.join(cacheDir.path, 'mlkit_temp.pdf'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final adapter = _FakeScannerAdapter(
      resultToReturn: PdfScanResult(pdfUri: sourcePdf.path, pageCount: 15),
    );
    final service = ScannerService(
      scanner: adapter,
      saveDirectoryProvider: () async => saveDir,
    );

    final doc = await service.scan();

    expect(adapter.capturedMaxPages, greaterThanOrEqualTo(100));
    expect(doc, isNotNull);
    expect(doc!.pageCount, 15);
  });

  test('copies scanned PDF out of temp cache into permanent directory',
      () async {
    final sourcePdf = File(p.join(cacheDir.path, 'mlkit_temp.pdf'))
      ..writeAsBytesSync([10, 20, 30]);
    final adapter = _FakeScannerAdapter(
      resultToReturn: PdfScanResult(
        pdfUri: Uri.file(sourcePdf.path).toString(),
        pageCount: 7,
      ),
    );
    final service = ScannerService(
      scanner: adapter,
      saveDirectoryProvider: () async => saveDir,
    );

    final doc = await service.scan();

    expect(doc, isNotNull);
    expect(p.dirname(doc!.filePath), equals(saveDir.path));
    expect(await File(doc.filePath).exists(), isTrue);
    expect(await File(doc.filePath).readAsBytes(), [10, 20, 30]);

    // Deleting the temp ML Kit cache file must not affect the saved scan.
    await sourcePdf.delete();
    expect(await File(doc.filePath).exists(), isTrue);
  });

  test('falls back to PDF page counter when plugin returns pageCount 0',
      () async {
    final sourcePdf = File(p.join(cacheDir.path, 'ios_scan.pdf'))
      ..writeAsBytesSync([5, 6, 7]);
    final adapter = _FakeScannerAdapter(
      resultToReturn: PdfScanResult(pdfUri: sourcePdf.path, pageCount: 0),
    );
    final service = ScannerService(
      scanner: adapter,
      saveDirectoryProvider: () async => saveDir,
      pdfPageCounter: (_) async => 12,
    );

    final doc = await service.scan();

    expect(doc, isNotNull);
    expect(doc!.pageCount, 12);
  });

  test('returns null when user cancels scanning', () async {
    final adapter = _FakeScannerAdapter(resultToReturn: null);
    final service = ScannerService(
      scanner: adapter,
      saveDirectoryProvider: () async => saveDir,
    );

    final doc = await service.scan();

    expect(doc, isNull);
  });
}
