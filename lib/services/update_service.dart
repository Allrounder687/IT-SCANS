import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateInfo {
  final bool isUpdateAvailable;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.isUpdateAvailable,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String _repoApiUrl = 'https://api.github.com/repos/Allrounder687/IT-SCANS/releases/latest';

  /// Checks if a new version is available on GitHub
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. 1.0.3

      final response = await http.get(Uri.parse(_repoApiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tagName = data['tag_name'] ?? ''; // e.g. v1.0.3
        
        // Remove 'v' prefix if exists
        final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        
        // Find APK asset
        final assets = data['assets'] as List;
        String? apkUrl;
        for (var asset in assets) {
          final name = asset['name'] as String;
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'];
            break;
          }
        }

        if (apkUrl != null) {
          // Simple version string comparison (assuming semantic versioning format X.Y.Z)
          final isUpdateAvailable = _isVersionGreater(latestVersion, currentVersion);
          
          return UpdateInfo(
            isUpdateAvailable: isUpdateAvailable,
            latestVersion: latestVersion,
            downloadUrl: apkUrl,
            releaseNotes: data['body'] ?? 'Minor fixes and improvements.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  /// Downloads the APK and returns the local file path
  Future<String?> downloadUpdate(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/itscans_update.apk';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return savePath;
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
    }
    return null;
  }

  /// Opens the downloaded APK to prompt installation
  Future<void> installUpdate(String path) async {
    try {
      await OpenFilex.open(path);
    } catch (e) {
      debugPrint('Error installing update: $e');
    }
  }

  bool _isVersionGreater(String latest, String current) {
    try {
      List<int> latestParts = latest.split('.').map((e) => int.parse(e)).toList();
      List<int> currentParts = current.split('.').map((e) => int.parse(e)).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (e) {
      debugPrint('Version parsing error: $e');
    }
    return false;
  }
}
