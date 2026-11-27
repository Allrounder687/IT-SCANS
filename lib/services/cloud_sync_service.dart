import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_user.dart';
import '../models/scan_document.dart';

class CloudSyncService {
  static const List<String> _driveScopes = [
    drive.DriveApi.driveFileScope,
  ];

  static const _iosClientId =
      '133389928359-pqm3l00qprqqej2oqjc0vcp5tobbm7dj.apps.googleusercontent.com';
  static const _desktopClientId =
      '133389928359-0ojsajpfffobdvll4nuktg6756ued430.apps.googleusercontent.com';
  static const _desktopClientSecret = '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';

  final _currentUserController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  GoogleSignInAccount? _googleAccount;
  AuthClient? _desktopAuthClient;
  Future<void>? _googleInitFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;

  CloudSyncService() {
    if (Platform.isAndroid || Platform.isIOS) {
      unawaited(_ensureGoogleSignInInitialized());
    }
  }

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleInitFuture ??= _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS ? _iosClientId : null,
    );
    _authEventsSub ??= GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn(:final user):
            _googleAccount = user;
            _currentUser = AppUser(
              displayName: user.displayName,
              email: user.email,
              photoUrl: user.photoUrl,
            );
          case GoogleSignInAuthenticationEventSignOut():
            _googleAccount = null;
            _currentUser = null;
        }
        _currentUserController.add(_currentUser);
      },
      onError: (Object e) {
        debugPrint('Google Sign-In event error: $e');
      },
    );
  }

  AppUser? get currentUser => _currentUser;
  Stream<AppUser?> get onCurrentUserChanged => _currentUserController.stream;

  Future<AppUser?> signIn() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _signInDesktop();
    }

    try {
      await _ensureGoogleSignInInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _driveScopes,
      );
      _googleAccount = account;

      // Ensure Drive scope is authorized while user interaction is allowed.
      final authz = await account.authorizationClient
              .authorizationForScopes(_driveScopes) ??
          await account.authorizationClient.authorizeScopes(_driveScopes);

      await _firebaseAuthWithGoogle(
        account,
        accessToken: authz.accessToken,
      );

      _currentUser = AppUser(
        displayName: account.displayName,
        email: account.email,
        photoUrl: account.photoUrl,
      );
      _currentUserController.add(_currentUser);
      return _currentUser;
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
      await _ensureGoogleSignInInitialized();
      final attempt = GoogleSignIn.instance.attemptLightweightAuthentication();
      final account = attempt != null ? await attempt : null;
      if (account != null) {
        _googleAccount = account;
        final authz = await account.authorizationClient
            .authorizationForScopes(_driveScopes);
        await _firebaseAuthWithGoogle(
          account,
          accessToken: authz?.accessToken,
        );
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

      _desktopAuthClient =
          await clientViaUserConsent(clientId, scopes, (url) async {
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

  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  Future<void> _firebaseAuthWithGoogle(
    GoogleSignInAccount account, {
    String? accessToken,
  }) async {
    debugPrint('Attempting Firebase auth with Google...');
    if (!_isFirebaseInitialized) {
      debugPrint('Firebase is NOT initialized yet!');
      return;
    }
    try {
      final GoogleSignInAuthentication googleAuth = account.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('Firebase auth successful! UID: ${userCred.user?.uid}');
    } catch (e) {
      debugPrint('Firebase auth failed: $e');
    }
  }

  Future<void> signOut() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
      if (_isFirebaseInitialized) {
        await FirebaseAuth.instance.signOut();
      }
    }

    _googleAccount = null;
    _desktopAuthClient?.close();
    _desktopAuthClient = null;
    _currentUser = null;
    _currentUserController.add(null);
  }

  Future<AuthClient?> _getAuthClient() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return _desktopAuthClient;
    }
    await _ensureGoogleSignInInitialized();
    final client = _googleAccount?.authorizationClient ??
        GoogleSignIn.instance.authorizationClient;
    final authz = await client.authorizationForScopes(_driveScopes);
    return authz?.authClient(scopes: _driveScopes);
  }

  Future<String?> uploadDocument(ScanDocument doc) async {
    final client = await _getAuthClient();
    if (client == null) {
      debugPrint('Not authenticated for Drive API.');
      return null;
    }

    try {
      final driveApi = drive.DriveApi(client);

      String folderId = await _getOrCreateAppFolder(driveApi);

      if (doc.category != null && doc.category != 'All') {
        folderId = await _getOrCreateFolder(driveApi, doc.category!, folderId);

        if (doc.subfolder != null) {
          folderId =
              await _getOrCreateFolder(driveApi, doc.subfolder!, folderId);
        }
      }

      final file = File(doc.filePath);
      if (!await file.exists()) return null;
      final driveFile = drive.File()
        ..name = '${doc.name}.pdf'
        ..parents = [folderId];
      final media = drive.Media(file.openRead(), await file.length());
      final createdFile =
          await driveApi.files.create(driveFile, uploadMedia: media);
      return createdFile.id;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  Future<String?> uploadAndGetPublicLink(
    String localFilePath,
    String fileName,
  ) async {
    final client = await _getAuthClient();
    if (client == null) return null;
    try {
      final driveApi = drive.DriveApi(client);
      final String folderId = await _getOrCreateAppFolder(driveApi);
      final file = File(localFilePath);
      if (!await file.exists()) return null;
      final driveFile = drive.File()
        ..name = fileName
        ..parents = [folderId];
      final media = drive.Media(file.openRead(), await file.length());
      final createdFile =
          await driveApi.files.create(driveFile, uploadMedia: media);
      final fileId = createdFile.id;
      if (fileId == null) return null;
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';
      await driveApi.permissions.create(permission, fileId);
      final retrievedFile = await driveApi.files
          .get(fileId, $fields: 'webContentLink') as drive.File;
      return retrievedFile.webContentLink;
    } catch (e) {
      debugPrint('Upload and get link failed: $e');
      return null;
    }
  }

  Future<String> _getOrCreateAppFolder(drive.DriveApi driveApi) async {
    const folderName = 'IT SCANS';
    const query =
        "mimeType='application/vnd.google-apps.folder' and name='$folderName' and trashed=false and 'root' in parents";
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

  Future<String> _getOrCreateFolder(
    drive.DriveApi driveApi,
    String folderName,
    String parentId,
  ) async {
    final escapedName = folderName.replaceAll("'", "\\'");
    final query =
        "mimeType='application/vnd.google-apps.folder' and name='$escapedName' and trashed=false and '$parentId' in parents";
    final fileList = await driveApi.files.list(q: query, spaces: 'drive');
    if (fileList.files != null && fileList.files!.isNotEmpty) {
      return fileList.files!.first.id!;
    }
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
      final String rootFolderId = await _getOrCreateAppFolder(driveApi);

      final List<CloudDocument> allDocs = [];

      final rootQuery = "'$rootFolderId' in parents and trashed=false";
      final rootItems = await driveApi.files.list(
        q: rootQuery,
        spaces: 'drive',
        $fields: 'files(id, name, createdTime, size, mimeType)',
      );

      if (rootItems.files == null) return [];

      for (final item in rootItems.files!) {
        if (item.mimeType == 'application/vnd.google-apps.folder') {
          final categoryName = item.name!;
          final catQuery = "'${item.id}' in parents and trashed=false";
          final catItems = await driveApi.files.list(
            q: catQuery,
            spaces: 'drive',
            $fields: 'files(id, name, createdTime, size, mimeType)',
          );

          if (catItems.files != null) {
            for (final catItem in catItems.files!) {
              if (catItem.mimeType == 'application/vnd.google-apps.folder') {
                final subfolderName = catItem.name!;
                final subQuery = "'${catItem.id}' in parents and trashed=false";
                final subItems = await driveApi.files.list(
                  q: subQuery,
                  spaces: 'drive',
                  $fields: 'files(id, name, createdTime, size, mimeType)',
                );

                if (subItems.files != null) {
                  for (final subItem in subItems.files!) {
                    if (subItem.mimeType !=
                        'application/vnd.google-apps.folder') {
                      allDocs.add(
                        CloudDocument(subItem, categoryName, subfolderName),
                      );
                    }
                  }
                }
              } else {
                allDocs.add(CloudDocument(catItem, categoryName, null));
              }
            }
          }
        } else {
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
      final media = await driveApi.files.get(
        driveFile.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
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
      final query =
          "name='$fileName' and '$rootFolderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');

      final bytes = utf8.encode(jsonString);
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
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
      final query =
          "name='$fileName' and '$rootFolderId' in parents and trashed=false";
      final fileList = await driveApi.files.list(q: query, spaces: 'drive');

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        final media = await driveApi.files.get(
          fileId,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;
        final bytes = await media.stream.expand((element) => element).toList();
        return utf8.decode(bytes);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to download structure.json: $e');
      return null;
    }
  }

  void dispose() {
    unawaited(_authEventsSub?.cancel() ?? Future<void>.value());
    unawaited(_currentUserController.close());
  }
}

class CloudDocument {
  final drive.File file;
  final String category;
  final String? subfolder;

  CloudDocument(this.file, this.category, this.subfolder);
}
