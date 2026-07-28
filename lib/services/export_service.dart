import 'dart:io';
import 'package:path/path.dart' as p;

class ExportService {
  /// Saves the file to the public Downloads directory on Android.
  Future<String> saveToDownloads(String sourceFilePath, String preferredName) async {
    try {
      // Android public Downloads directory
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      
      if (!await downloadsDirectory.exists()) {
        await downloadsDirectory.create(recursive: true);
      }

      final extension = p.extension(sourceFilePath);
      final safeName = preferredName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      
      String fileName = '$safeName$extension';
      String destinationPath = p.join(downloadsDirectory.path, fileName);
      
      // Ensure unique filename
      int counter = 1;
      while (await File(destinationPath).exists()) {
        fileName = '${safeName}_$counter$extension';
        destinationPath = p.join(downloadsDirectory.path, fileName);
        counter++;
      }

      final sourceFile = File(sourceFilePath);
      await sourceFile.copy(destinationPath);
      
      return destinationPath;
    } catch (e) {
      throw Exception('Could not save to Downloads: $e');
    }
  }
}
