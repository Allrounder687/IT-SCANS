import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_document.dart';

/// Abstraction over the underlying document scanner plugin for testability.
abstract class DocumentScannerAdapter {
  Future<PdfScanResult?> scanAsPdf({required int maxPages});
}

class FlutterDocScannerAdapter implements DocumentScannerAdapter {
  final FlutterDocScanner _plugin;

  FlutterDocScannerAdapter([FlutterDocScanner? plugin])
      : _plugin = plugin ?? FlutterDocScanner();

  @override
  Future<PdfScanResult?> scanAsPdf({required int maxPages}) {
    return _plugin.getScannedDocumentAsPdf(page: maxPages);
  }
}

/// Callback that resolves a permanent directory for saved scan PDFs.
typedef SaveDirectoryProvider = Future<Directory> Function();

/// Callback that counts pages in a PDF file.
typedef PdfPageCounter = Future<int> Function(String filePath);

class ScannerService {
  /// High ceiling so users can scan large multi-page documents without
  /// hitting flutter_doc_scanner's default 4-page limit.
  static const int defaultMaxPages = 100;

  static const MethodChannel _platformChannel =
      MethodChannel('com.syeds.itscans/platform');

  final DocumentScannerAdapter _scanner;
  final SaveDirectoryProvider? _saveDirectoryProvider;
  final PdfPageCounter? _pdfPageCounter;

  ScannerService({
    DocumentScannerAdapter? scanner,
    SaveDirectoryProvider? saveDirectoryProvider,
    PdfPageCounter? pdfPageCounter,
  })  : _scanner = scanner ?? FlutterDocScannerAdapter(),
        _saveDirectoryProvider = saveDirectoryProvider,
        _pdfPageCounter = pdfPageCounter;

  /// Launches the native document scanner and persists the resulting PDF to
  /// permanent storage before returning.
  ///
  /// OCR is intentionally NOT run synchronously here so a memory spike or
  /// lifecycle interruption can never prevent the scan from being saved.
  Future<ScanDocument?> scan({int maxPages = defaultMaxPages}) async {
    try {
      await _notifyAndroidScanStarted();
      final result = await _scanner.scanAsPdf(maxPages: maxPages);
      if (result == null) return null;

      final rawPath = result.pdfUri;
      if (rawPath.isEmpty) {
        throw Exception(
          'Could not extract a valid file path from the scan result',
        );
      }

      final permanentPath = await _persistScannedPdf(rawPath);
      int pageCount = result.pageCount;
      if (pageCount <= 0) {
        pageCount = await _countPdfPages(permanentPath);
      }

      return buildScanDocument(
        filePath: permanentPath,
        pageCount: pageCount,
      );
    } catch (e) {
      throw Exception('Failed to process scan: $e');
    } finally {
      await _notifyAndroidScanFinished();
    }
  }

  /// Checks Android native recovery storage for any scan whose Activity was
  /// killed by the OS while ML Kit Document Scanner was open.
  Future<List<ScanDocument>> consumeRecoveredScans() async {
    if (!Platform.isAndroid) return const [];
    try {
      final rawJson = await _platformChannel.invokeMethod<String>(
        'consumeRecoveredScans',
      );
      if (rawJson == null || rawJson.isEmpty || rawJson == '[]') {
        return const [];
      }

      final List<dynamic> items = jsonDecode(rawJson) as List<dynamic>;
      final List<ScanDocument> recovered = [];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final path = item['filePath'] as String?;
        if (path == null || path.isEmpty || !await File(path).exists()) {
          continue;
        }
        final permanentPath = await _persistScannedPdf(path);
        final pageCount =
            (item['pageCount'] as int?) ?? await _countPdfPages(permanentPath);
        final timestamp = item['timestamp'] as int?;
        final createdAt = timestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(timestamp)
            : DateTime.now();
        recovered.add(
          buildScanDocument(
            filePath: permanentPath,
            pageCount: pageCount,
            createdAt: createdAt,
          ),
        );
      }
      return recovered;
    } catch (e) {
      debugPrint('Failed to consume recovered scans: $e');
      return const [];
    }
  }

  /// Builds a [ScanDocument] with a consistent timestamped fallback name.
  static ScanDocument buildScanDocument({
    required String filePath,
    required int pageCount,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final safePages = pageCount < 1 ? 1 : pageCount;
    final formattedTime =
        now.toIso8601String().substring(0, 16).replaceAll('T', ' ');
    return ScanDocument(
      id: now.microsecondsSinceEpoch.toString(),
      name: 'Scan $formattedTime',
      pageCount: safePages,
      filePath: filePath,
      createdAt: now,
      category: 'Documents',
    );
  }

  Future<Directory> _resolveSaveDirectory() async {
    if (_saveDirectoryProvider != null) {
      final dir = await _saveDirectoryProvider();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('customSaveLocation');
    if (customPath != null && customPath.isNotEmpty) {
      try {
        final customDir = Directory(customPath);
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (e) {
        debugPrint(
          'Custom save location unavailable ($customPath), falling back: $e',
        );
      }
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory(p.join(appDocsDir.path, 'scans'));
    if (!await scansDir.exists()) {
      await scansDir.create(recursive: true);
    }
    return scansDir;
  }

  Future<String> _persistScannedPdf(String rawUriOrPath) async {
    final saveDir = await _resolveSaveDirectory();
    final uniqueName = 'scan_${DateTime.now().microsecondsSinceEpoch}.pdf';
    final destPath = p.join(saveDir.path, uniqueName);

    if (rawUriOrPath.startsWith('content://') && Platform.isAndroid) {
      final copiedPath = await _platformChannel.invokeMethod<String>(
        'copyUriToFile',
        {
          'uri': rawUriOrPath,
          'destPath': destPath,
        },
      );
      if (copiedPath != null && await File(copiedPath).exists()) {
        return copiedPath;
      }
      throw Exception('Failed to copy content URI to permanent storage');
    }

    final resolvedPath = rawUriOrPath.startsWith('file://')
        ? Uri.parse(rawUriOrPath).toFilePath()
        : rawUriOrPath;

    final sourceFile = File(resolvedPath);
    if (!await sourceFile.exists()) {
      throw Exception('Scanned file does not exist at $resolvedPath');
    }

    // If the file is already inside the target directory, keep it as-is.
    if (p.equals(p.dirname(resolvedPath), saveDir.path)) {
      return resolvedPath;
    }

    final copied = await sourceFile.copy(destPath);
    return copied.path;
  }

  Future<int> _countPdfPages(String filePath) async {
    if (_pdfPageCounter != null) {
      return _pdfPageCounter(filePath);
    }
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(filePath);
      return doc.pagesCount > 0 ? doc.pagesCount : 1;
    } catch (_) {
      return 1;
    } finally {
      await doc?.close();
    }
  }

  Future<void> _notifyAndroidScanStarted() async {
    if (!Platform.isAndroid) return;
    try {
      await _platformChannel.invokeMethod<void>('markScanStarted');
    } catch (_) {
      // Non-fatal in tests or unsupported contexts
    }
  }

  Future<void> _notifyAndroidScanFinished() async {
    if (!Platform.isAndroid) return;
    try {
      await _platformChannel.invokeMethod<void>('markScanFinished');
    } catch (_) {
      // Non-fatal in tests or unsupported contexts
    }
  }
}
