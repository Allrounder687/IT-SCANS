import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scan_document.dart';
import '../models/app_user.dart';

class CloudSyncService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
    ],
    clientId: Platform.isIOS ? '133389928359-pqm3l00qprqqej2oqjc0vcp5tobbm7dj.apps.googleusercontent.com' : null,
  );

  final _currentUserController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  AuthClient? _desktopAuthClient;
  
  static const _desktopClientId = '133389928359-0ojsajpfffobdvll4nuktg6756ued430.apps.googleusercontent.com';
  static const _desktopClientSecret = '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';

  CloudSyncService() {
    if (Platform.isAndroid || Platform.isIOS) {
      _googleSignIn.onCurrentUserChanged.listen((account) {
        if (account != null) {
          _currentUser = AppUser(
            displayName: account.displayName,
            email: account.email,
            photoUrl: account.photoUrl,
          );
        } else {
          _currentUser = null;
        }
        _currentUserController.add(_currentUser);
      });
    }
  }

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get onCurrentUserChanged => _currentUserController.stream;

  Future<AppUser?> signIn() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _signInDesktop();
    }
    
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        await _firebaseAuthWithGoogle(account);
        _currentUser = AppUser(
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
        );
        _currentUserController.add(_currentUser);
        return _currentUser;
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign-In failed: $e');
      return null;
    }
  }

  Future<AppUser?> signInSilently() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return null;
    }

    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await _firebaseAuthWithGoogle(account);
        _currentUser = AppUser(
          displayName: account.displayName,
          email: account.email,
          photoUrl: account.photoUrl,
        );
        _currentUserController.add(_currentUser);
        return _currentUser;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<AppUser?> _signInDesktop() async {
    try {
      final clientId = ClientId(_desktopClientId, _desktopClientSecret);
      final scopes = [drive.DriveApi.driveFileScope, 'email', 'profile'];
      
      _desktopAuthClient = await clientViaUserConsent(clientId, scopes, (url) async {
        final parsedUrl = Uri.parse(url);
        if (await canLaunchUrl(parsedUrl)) {
          await launchUrl(parsedUrl);
        } else {
          debugPrint('Could not launch $url');
        }
      });
      
      _currentUser = AppUser(
        displayName: 'Desktop User',
        email: 'desktop@local',
        photoUrl: null,
      );
      _currentUserController.add(_currentUser);
      return _currentUser;
    } catch (e) {
      debugPrint('Desktop OAuth failed: $e');
      return null;
    }
  }

  Future<void> _firebaseAuthWithGoogle(GoogleSignInAccount account) async {
    try {
      final GoogleSignInAuthentication googleAuth = await account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Firebase auth failed: $e');
    }
  }

  Future<void> signOut() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _googleSignIn.signOut();
      await FirebaseAuth.instance.signOut();
    }
    
    _desktopAuthClient?.close();
    _desktopAuthClient = null;
    _currentUser = null;
    _currentUserController.add(null);
  }

  Future<AuthClient?> _getAuthClient() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _desktopAuthClient;
    }
    return await _googleSignIn.authenticatedClient();
  }

  Future<String?> uploadDocument(ScanDocument doc) async {
    final client = await _getAuthClient();
    if (client == null) {
      debugPrint('Not authenticated for Drive API.');
      return null;
    }

    try {
      final driveApi = drive.DriveApi(client);
      
      // Get root 'IT SCANS' folder
      String folderId = await _getOrCreateAppFolder(driveApi);
      
      // If document has a category, get/create that folder inside root
      if (doc.category != null && doc.category != 'All') {
        folderId = await _getOrCreateFolder(driveApi, doc.category!, folderId);
        
        // If document has a subfolder, get/create that inside the category folder
        if (doc.subfolder != null) {
          folderId = await _getOrCreateFolder(driveApi, doc.subfolder!, folderId);
        }
      }

      final file = File(doc.filePath);
      if (!await file.exists()) return null;
      final driveFile = drive.File()..name = '${doc.name}.pdf'..parents = [folderId];
      final media = drive.Media(file.openRead(), file.lengthSync());
      final createdFile = await driveApi.files.create(driveFile, uploadMedia: media);
      return createdFile.id;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<String?> uploadAndGetPublicLink(String localFilePath, String fileName) async {
    final client = await _getAuthClient();
    if (client == null) return null;
    try {
      final driveApi = drive.DriveApi(client);
      String folderId = await _getOrCreateAppFolder(driveApi);
      final file = File(localFilePath);
      if (!await file.exists()) return null;
      final driveFile = drive.File()..name = fileName..parents = [folderId];
      final media = drive.Media(file.openRead(), file.lengthSync());
      final createdFile = await driveApi.files.create(driveFile, uploadMedia: media);
      final fileId = createdFile.id;
      if (fileId == null) return null;
      final permission = drive.Permission()..type = 'anyone'..role = 'reader';
      await driveApi.permissions.create(permission, fileId);
      final retrievedFile = await driveApi.files.get(fileId, $fields: 'webContentLink') as drive.File;
      return retrievedFile.webContentLink;
    } catch (e) {
      debugPrint('Upload and get link failed: $e');
      return null;
    }
  }

  Future<String> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    const folderName = 'IT SCANS';
    final query = "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false and 'root' in parents";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) return fileList.files!.first.id!;
    final newFolder = drive.File()..name = folderName..mimeType = 'application/vnd.google-apps.folder';
    final createdFolder = await driveApi.files.create(newFolder);
    return createdFolder.id!;
  }

  Future<String> _getOrCreateFolder(drive.DriveApi driveApi, String folderName, String parentId) async {
    // Escape single quotes in folder name
    final escapedName = folderName.replaceAll("'", "\\'");
    final query = "mimeType='application/vnd.google-apps.folder' and name='$escapedName' and trashed=false and '$parentId' in parents";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) return fileList.files!.first.id!;
    final newFolder = drive.File()
      ..name = folderName
      ..parents = [parentId]
      ..mimeType = 'application/vnd.google-apps.folder';
    final createdFolder = await driveApi.files.create(newFolder);
    return createdFolder.id!;
  }

  Future<List<CloudDocument>> fetchCloudHierarchy() async {
    final client = await _getAuthClient();
    if (client == null) return [];
    
    try {
      final driveApi = drive.DriveApi(client);
      String rootFolderId = await _getOrCreateAppFolder(driveApi);
      
      List<CloudDocument> allDocs = [];

      // Fetch all direct children of root folder
      final rootQuery = "'$rootFolderId' in parents and trashed=false";
      final rootItems = await driveApi.files.list(q: rootQuery, spaces: 'drive', $fields: 'files(id, name, createdTime, size, mimeType)');
      
      if (rootItems.files == null) return [];

      for (var item in rootItems.files!) {
        if (item.mimeType == 'application/vnd.google-apps.folder') {
          // This is a section/category
          final categoryName = item.name!;
          final catQuery = "'${item.id}' in parents and trashed=false";
          final catItems = await driveApi.files.list(q: catQuery, spaces: 'drive', $fields: 'files(id, name, createdTime, size, mimeType)');
          
          if (catItems.files != null) {
            for (var catItem in catItems.files!) {
              if (catItem.mimeType == 'application/vnd.google-apps.folder') {
                // This is a subfolder
                final subfolderName = catItem.name!;
                final subQuery = "'${catItem.id}' in parents and trashed=false";
                final subItems = await driveApi.files.list(q: subQuery, spaces: 'drive', $fields: 'files(id, name, createdTime, size, mimeType)');
                
                if (subItems.files != null) {
                  for (var subItem in subItems.files!) {
                    if (subItem.mimeType != 'application/vnd.google-apps.folder') {
                      allDocs.add(CloudDocument(subItem, categoryName, subfolderName));
                    }
                  }
                }
              } else {
                // Direct file inside category
                allDocs.add(CloudDocument(catItem, categoryName, null));
              }
            }
          }
        } else {
          // Direct file inside root folder
          allDocs.add(CloudDocument(item, 'Documents', null));
        }
      }
      return allDocs;
    } catch (e) {
      debugPrint('Failed to fetch hierarchy: $e');
      return [];
    }
  }

  Future<bool> downloadFile(drive.File driveFile, String savePath) async {
    final client = await _getAuthClient();
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

  Future<bool> deleteFile(String fileId) async {
    final client = await _getAuthClient();
    if (client == null) return false;
    try {
      final driveApi = drive.DriveApi(client);
      await driveApi.files.delete(fileId);
      return true;
    } catch (e) {
      debugPrint('Failed to delete file: $e');
      return false;
    }
  }

  Future<void> uploadStructureJson(String jsonString) async {
    final client = await _getAuthClient();
    if (client == null) return;
    try {
      final driveApi = drive.DriveApi(client);
      final rootFolderId = await _getOrCreateAppFolder(driveApi);
      
      const fileName = 'structure.json';
      final query = "name='$fileName' and '$rootFolderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      
      final media = drive.Media(
        Stream.value(utf8.encode(jsonString)),
        utf8.encode(jsonString).length,
      );
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Update existing
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        // Create new
        final newFile = drive.File()
          ..name = fileName
          ..parents = [rootFolderId]
          ..mimeType = 'application/json';
        await driveApi.files.create(newFile, uploadMedia: media);
      }
    } catch (e) {
      debugPrint('Failed to upload structure.json: $e');
    }
  }

  Future<String?> downloadStructureJson() async {
    final client = await _getAuthClient();
    if (client == null) return null;
    try {
      final driveApi = drive.DriveApi(client);
      final rootFolderId = await _getOrCreateAppFolder(driveApi);
      
      const fileName = 'structure.json';
      final query = "name='$fileName' and '$rootFolderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');
      
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
        final bytes = await media.stream.expand((element) => element).toList();
        return utf8.decode(bytes);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to download structure.json: $e');
      return null;
    }
  }
}
class CloudDocument {
  final drive.File file;
  final String category;
  final String? subfolder;
  
  CloudDocument(this.file, this.category, this.subfolder);
}
