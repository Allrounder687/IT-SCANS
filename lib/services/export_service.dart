import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExportService {
  static const MethodChannel _platformChannel =
      MethodChannel('com.syeds.itscans/platform');

  /// Saves the file to the public Downloads directory on Android (via
  /// MediaStore on Android 10+), Downloads/Documents on Desktop, or Documents
  /// on iOS.
  Future<String> saveToDownloads(
    String sourceFilePath,
    String preferredName,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source file not found');
      }

      final extension = p.extension(sourceFilePath).isNotEmpty
          ? p.extension(sourceFilePath)
          : '.pdf';
      final safeName =
          preferredName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fileName = '$safeName$extension';

      if (Platform.isAndroid) {
        final mimeType =
            extension.toLowerCase() == '.pdf' ? 'application/pdf' : 'image/*';
        final savedLocation = await _platformChannel.invokeMethod<String>(
          'saveToDownloads',
          {
            'sourcePath': sourceFilePath,
            'fileName': fileName,
            'mimeType': mimeType,
          },
        );
        if (savedLocation != null && savedLocation.isNotEmpty) {
          unawaited(_checkAndRequestReview());
          return savedLocation;
        }
        throw Exception('MediaStore returned empty path');
      }

      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        final bytes = await sourceFile.readAsBytes();
        final uri = await FilePicker.saveFile(
          fileName: fileName,
          bytes: bytes,
          mimeType: extension.toLowerCase() == '.pdf'
              ? 'application/pdf'
              : 'application/octet-stream',
        );
        if (uri == null) {
          throw Exception('Save cancelled');
        }
        unawaited(_checkAndRequestReview());
        return uri.toString();
      }

      // iOS application documents directory (accessible via Files app)
      final directory = await getApplicationDocumentsDirectory();
      String destinationPath = p.join(directory.path, fileName);
      int counter = 1;
      while (await File(destinationPath).exists()) {
        destinationPath =
            p.join(directory.path, '${safeName}_$counter$extension');
        counter++;
      }

      await sourceFile.copy(destinationPath);
      unawaited(_checkAndRequestReview());
      return destinationPath;
    } catch (e) {
      throw Exception('Could not save file: $e');
    }
  }

  Future<void> _checkAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int count = (prefs.getInt('exports_count') ?? 0) + 1;
      await prefs.setInt('exports_count', count);

      if (count == 5 || count == 15) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
      }
    } catch (_) {
      // Ignore errors for organic review prompts
    }
  }
}
