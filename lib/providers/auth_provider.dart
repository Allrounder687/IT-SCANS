import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/cloud_sync_service.dart';
import '../models/scan_document.dart';
import '../providers/library_provider.dart';

class AuthProvider extends ChangeNotifier {
  final CloudSyncService _syncService;
  final SharedPreferences _prefs;
  
  bool _autoSync = false;
  GoogleSignInAccount? _currentUser;
  bool _isLoading = true;

  AuthProvider(this._syncService, this._prefs) {
    _init();
  }

  bool get autoSync => _autoSync;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null;
  CloudSyncService get syncService => _syncService;

  Future<void> _init() async {
    _autoSync = _prefs.getBool('auto_sync') ?? false;
    
    _syncService.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      notifyListeners();
    });

    _currentUser = await _syncService.signInSilently();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn() async {
    _isLoading = true;
    notifyListeners();
    await _syncService.signIn();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();
    await _syncService.signOut();
    _autoSync = false;
    await _prefs.setBool('auto_sync', false);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAutoSync(bool value) async {
    _autoSync = value;
    await _prefs.setBool('auto_sync', value);
    notifyListeners();
  }

  Future<int> restoreFromCloud(LibraryProvider library) async {
    _isLoading = true;
    notifyListeners();
    
    int restoredCount = 0;
    try {
      final driveFiles = await _syncService.listBackedUpFiles();
      if (driveFiles.isEmpty) return 0;
      
      final localDir = await getApplicationDocumentsDirectory();
      
      for (final df in driveFiles) {
        if (df.name == null || !df.name!.endsWith('.pdf')) continue;
        
        final docName = df.name!.replaceAll('.pdf', '');
        
        // 1. Check for exact match via Drive ID
        if (library.documents.any((d) => d.driveId != null && d.driveId == df.id)) {
          continue; // Already anchored perfectly
        }

        // 2. Check for name match and compare byte size
        final existingDocs = library.documents.where((d) => d.name == docName).toList();
        if (existingDocs.isNotEmpty) {
          bool exactMatchFound = false;
          final cloudSize = int.tryParse(df.size ?? '0') ?? 0;
          
          for (final localDoc in existingDocs) {
            final localFile = File(localDoc.filePath);
            if (await localFile.exists()) {
              final localSize = await localFile.length();
              if (localSize == cloudSize) {
                // The sizes match! It's the same file, just missing the driveId locally
                await library.updateSyncStatus(localDoc.id, true, driveId: df.id);
                exactMatchFound = true;
                break;
              }
            }
          }
          
          if (exactMatchFound) {
            continue; // Skip downloading because we have an identical file
          }
        }

        // 3. Doesn't exist locally, OR it has the same name but different size
        String finalDocName = docName;
        if (existingDocs.isNotEmpty) {
          finalDocName = '$docName (Cloud Copy)';
        }

        final docId = DateTime.now().microsecondsSinceEpoch.toString();
        final savePath = p.join(localDir.path, '$docId.pdf');
        
        final success = await _syncService.downloadFile(df, savePath);
        if (success) {
          final newDoc = ScanDocument(
            id: docId,
            name: finalDocName,
            pageCount: 1, 
            filePath: savePath,
            createdAt: df.createdTime ?? DateTime.now(),
            isSynced: true,
            driveId: df.id,
          );
          
          await library.addDocument(newDoc);
          restoredCount++;
        }
      }
    } catch (e) {
      debugPrint('Restore failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    return restoredCount;
  }
}
