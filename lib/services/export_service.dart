import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_review/in_app_review.dart';

class ExportService {
  /// Saves the file to the public Downloads directory on Android, and Documents on iOS.
  Future<String> saveToDownloads(String sourceFilePath, String preferredName) async {
    try {
      Directory directory;
      if (Platform.isAndroid) {
        // Android public Downloads directory
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } else {
        // iOS application documents directory (accessible via Files app if UIFileSharingEnabled=true)
        directory = await getApplicationDocumentsDirectory();
      }

      final extension = p.extension(sourceFilePath);
      final safeName = preferredName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      
      String fileName = '$safeName$extension';
      String destinationPath = p.join(directory.path, fileName);
      
      // Ensure unique filename
      int counter = 1;
      while (await File(destinationPath).exists()) {
        fileName = '${safeName}_$counter$extension';
        destinationPath = p.join(directory.path, fileName);
        counter++;
      }

      final sourceFile = File(sourceFilePath);
      await sourceFile.copy(destinationPath);
      
      _checkAndRequestReview();
      
      return destinationPath;
    } catch (e) {
      throw Exception('Could not save file: $e');
    }
  }

  Future<void> _checkAndRequestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt('exports_count') ?? 0) + 1;
      await prefs.setInt('exports_count', count);
      
      if (count == 5 || count == 15) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
        }
      }
    } catch (e) {
      // Ignore errors for organic review prompts
    }
  }
}
