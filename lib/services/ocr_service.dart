import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';

class OcrResult {
  final String? name;
  final String? category;
  final String fullText;

  OcrResult({this.name, this.category, required this.fullText});
}

class OcrService {
  // Serialize OCR calls across the app so we never render multiple PDFs or
  // allocate multiple ML Kit recognizers simultaneously (prevents OOM crashes).
  static Future<void> _queue = Future<void>.value();

  /// Renders the first page of the PDF, extracts text, categorizes it, and finds a name.
  Future<OcrResult?> analyzeDocument(String pdfPath) {
    final completer = Completer<OcrResult?>();
    _queue = _queue.then((_) async {
      try {
        final result = await _analyzeSingleDocument(pdfPath);
        completer.complete(result);
      } catch (e) {
        debugPrint('OCR Auto-naming failed: $e');
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<OcrResult?> _analyzeSingleDocument(String pdfPath) async {
    if (!await File(pdfPath).exists()) return null;

    PdfDocument? document;
    PdfPage? page;
    TextRecognizer? textRecognizer;
    File? tempFile;

    try {
      document = await PdfDocument.openFile(pdfPath);
      page = await document.getPage(1);

      // Keep max dimension around 1024px to stay well below mobile OOM limits
      // while preserving crisp Latin text for ML Kit recognition.
      final maxDim = page.width > page.height ? page.width : page.height;
      final double scale = maxDim > 0
          ? (maxDim > 1024 ? 1024 / maxDim : (1024 / maxDim).clamp(1.0, 2.0))
          : 1.0;

      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
      );

      await page.close();
      page = null;
      await document.close();
      document = null;

      if (pageImage == null) return null;

      final tempDir = Directory.systemTemp;
      tempFile = File(
        '${tempDir.path}/ocr_temp_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(pageImage.bytes);

      final inputImage = InputImage.fromFile(tempFile);
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) return null;

      final fullText = recognizedText.text;
      final category = _determineCategory(fullText);
      final name = _extractName(recognizedText);

      return OcrResult(
        name: name,
        category: category,
        fullText: fullText,
      );
    } catch (e) {
      debugPrint('OCR Auto-naming failed: $e');
      return null;
    } finally {
      await page?.close();
      await document?.close();
      await textRecognizer?.close();
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  String? _determineCategory(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('total') ||
        lowerText.contains('receipt') ||
        lowerText.contains('cash') ||
        lowerText.contains('\$')) {
      return 'Receipts';
    } else if (lowerText.contains('invoice') ||
        lowerText.contains('due') ||
        lowerText.contains('bill to')) {
      return 'Invoices';
    } else if (lowerText.contains('id') ||
        lowerText.contains('passport') ||
        lowerText.contains('license') ||
        lowerText.contains('identity')) {
      return 'IDs';
    } else if (lowerText.contains('tax') ||
        lowerText.contains('w-2') ||
        lowerText.contains('1099')) {
      return 'Taxes';
    } else if (lowerText.length > 50) {
      return 'Notes';
    }

    return 'Documents';
  }

  String? _extractName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.length >= 3 && text.length <= 40) {
          if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
            return _capitalize(text);
          }
        }
      }
    }
    return null;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    String clean = text.replaceAll('\n', ' ').trim();
    if (clean.length > 30) {
      clean = clean.substring(0, 30);
    }
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
