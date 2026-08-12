import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String? name;
  final String? category;
  final String fullText;

  OcrResult({this.name, this.category, required this.fullText});
}

class OcrService {
  /// Renders the first page of the PDF, extracts text, categorizes it, and finds a name.
  Future<OcrResult?> analyzeDocument(String pdfPath) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);
      
      // Calculate a safe scale factor to prevent OOM on mid-range devices.
      // We aim for a max dimension of around 1600 pixels which is plenty for OCR.
      double scale = 1.0;
      final maxDim = page.width > page.height ? page.width : page.height;
      if (maxDim > 800) {
        scale = 1600 / maxDim;
      } else {
        scale = 2.0; // If it's a small PDF (e.g. 595x842 points), 2x scale is safe
      }
      
      final pageImage = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
      );
      
      await page.close();
      if (pageImage == null) return null;

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(pageImage.bytes);
      
      final inputImage = InputImage.fromFile(tempFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
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
      if (document != null) {
        await document.close();
      }
    }
  }

  String? _determineCategory(String text) {
    final lowerText = text.toLowerCase();
    
    if (lowerText.contains('total') || lowerText.contains('receipt') || lowerText.contains('cash') || lowerText.contains('\$')) {
      return 'Receipts';
    } else if (lowerText.contains('invoice') || lowerText.contains('due') || lowerText.contains('bill to')) {
      return 'Invoices';
    } else if (lowerText.contains('id') || lowerText.contains('passport') || lowerText.contains('license') || lowerText.contains('identity')) {
      return 'IDs';
    } else if (lowerText.contains('tax') || lowerText.contains('w-2') || lowerText.contains('1099')) {
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
