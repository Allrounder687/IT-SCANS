import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import '../models/scan_document.dart';
import 'ocr_service.dart';
class ScannerService {
  final _plugin = FlutterDocScanner();
  final _ocrService = OcrService();

  Future<ScanDocument?> scan() async {
    try {
      final result = await _plugin.getScanDocuments();
      if (result == null) return null;

      String? filePath;
      int pageCount = 1;

      if (result is Map) {
        filePath = result['pdfUri']?.toString() ?? result['pdf']?.toString() ?? result.values.first?.toString();
        pageCount = (result['pageCount'] ?? result['count'] ?? 1) as int;
      } else if (result is String) {
        filePath = result;
      } else if (result is List && result.isNotEmpty) {
        filePath = result.first.toString();
        pageCount = result.length;
      }

      if (filePath != null && filePath.isNotEmpty) {
        if (filePath.startsWith('file://')) {
          filePath = filePath.substring(7);
        }
        
        final prefs = await SharedPreferences.getInstance();
        final customPath = prefs.getString('customSaveLocation');
        if (customPath != null) {
          final fileName = filePath.split(Platform.pathSeparator).last;
          final saveDir = Directory(customPath);
          if (!await saveDir.exists()) {
            await saveDir.create(recursive: true);
          }
          final copiedFile = await File(filePath).copy('${saveDir.path}${Platform.pathSeparator}$fileName');
          filePath = copiedFile.path;
        }
        
        // Generate a name contextually
        final ocrResult = await _ocrService.analyzeDocument(filePath);
        String docName = ocrResult?.name ?? 'Scan ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
        
        return ScanDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: docName,
          pageCount: pageCount,
          filePath: filePath,
          createdAt: DateTime.now(),
          category: ocrResult?.category ?? 'Documents',
          extractedText: ocrResult?.fullText,
        );
      } else {
        throw Exception("Could not extract a valid file path from the scan result");
      }
    } catch (e) {
      throw Exception('Failed to process scan: $e');
    }
  }
}
