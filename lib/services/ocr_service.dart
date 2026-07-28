import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  /// Renders the first page of the PDF and attempts to extract a logical title
  Future<String?> generateContextualName(String pdfPath) async {
    PdfDocument? document;
    try {
      // 1. Load the PDF
      document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);
      
      // 2. Render the first page to an image
      final pageImage = await page.render(
        width: page.width * 2, // 2x for better OCR resolution
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
      );
      
      await page.close();
      if (pageImage == null) return null;

      // 3. Save the rendered image to a temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(pageImage.bytes);
      
      // 4. Run ML Kit OCR
      final inputImage = InputImage.fromFile(tempFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      
      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      // 5. Extract a logical name from the text
      if (recognizedText.blocks.isEmpty) return null;
      
      // Simple heuristic: Get the first non-trivial line of text
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          // Filter out tiny lines (likely noise) and extremely long lines
          if (text.length >= 3 && text.length <= 40) {
            // Check if it has letters (not just numbers/symbols)
            if (RegExp(r'[a-zA-Z]').hasMatch(text)) {
              return _capitalize(text);
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('OCR Auto-naming failed: $e');
      return null;
    } finally {
      document?.close();
    }
  }
  
  String _capitalize(String text) {
    if (text.isEmpty) return text;
    // Replace newlines and limit length
    String clean = text.replaceAll('\n', ' ').trim();
    if (clean.length > 30) {
      clean = clean.substring(0, 30);
    }
    // Capitalize first letter of each word
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
