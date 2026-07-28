import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/scan_document.dart';

class CloudSyncService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Stream<GoogleSignInAccount?> get onCurrentUserChanged => _googleSignIn.onCurrentUserChanged;

  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      return null;
    }
  }

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  Future<String?> uploadDocument(ScanDocument doc) async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      debugPrint('Not authenticated for Drive API.');
      return null;
    }

    try {
      final driveApi = drive.DriveApi(client);
      
      // 1. Find or create the "IT SCANS" folder
      String folderId = await _getOrCreateAppFolder(driveApi);

      // 2. Upload the file
      final file = File(doc.filePath);
      if (!await file.exists()) {
        debugPrint('File does not exist: ${doc.filePath}');
        return null;
      }

      final driveFile = drive.File()
        ..name = '${doc.name}.pdf'
        ..parents = [folderId];

      final media = drive.Media(file.openRead(), file.lengthSync());
      
      final createdFile = await driveApi.files.create(driveFile, uploadMedia: media);
      
      return createdFile.id;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<String> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    const folderName = 'IT SCANS';
    final query = "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false";
    
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }

    final newFolder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final createdFolder = await driveApi.files.create(newFolder);
    return createdFolder.id!;
  }

  Future<List<drive.File>> listBackedUpFiles() async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return [];

    try {
      final driveApi = drive.DriveApi(client);
      String folderId = await _getOrCreateAppFolder(driveApi);
      
      final query = "'$folderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query, 
        spaces: 'drive',
        $fields: 'files(id, name, createdTime, size)',
      );
      
      return fileList.files ?? [];
    } catch (e) {
      debugPrint('Failed to list files: $e');
      return [];
    }
  }

  Future<bool> downloadFile(drive.File driveFile, String savePath) async {
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) return false;

    try {
      final driveApi = drive.DriveApi(client);
      final media = await driveApi.files.get(driveFile.id!, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
      
      final file = File(savePath);
      final sink = file.openWrite();
      await media.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      
      return true;
    } catch (e) {
      debugPrint('Failed to download file: $e');
      return false;
    }
  }
}
