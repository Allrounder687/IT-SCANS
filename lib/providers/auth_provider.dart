import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/cloud_sync_service.dart';
import '../models/scan_document.dart';
import '../models/app_user.dart';
import '../providers/library_provider.dart';

class AuthProvider extends ChangeNotifier {
  final CloudSyncService _syncService;
  final SharedPreferences _prefs;
  
  bool _autoSync = false;
  AppUser? _currentUser;
  bool _isLoading = true;

  AuthProvider(this._syncService, this._prefs) {
    _init();
  }

  bool get autoSync => _autoSync;
  AppUser? get currentUser => _currentUser;
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
      // 1. Try to download and import the structure JSON backup first
      final structureJson = await _syncService.downloadStructureJson();
      if (structureJson != null && structureJson.isNotEmpty) {
        // We need access to StorageService here. LibraryProvider doesn't expose it directly, 
        // so we'll add an importStructure method to LibraryProvider.
        await library.importStructure(structureJson);
      }

      final cloudDocs = await _syncService.fetchCloudHierarchy();
      if (cloudDocs.isEmpty) return 0;
      
      final localDir = await getApplicationDocumentsDirectory();
      
      for (final cloudDoc in cloudDocs) {
        final df = cloudDoc.file;
        if (df.name == null || !df.name!.endsWith('.pdf')) continue;
        
        final docName = df.name!.replaceAll('.pdf', '');
        
        // Ensure section exists if custom
        final defaultCategories = ['All', 'Receipts', 'Invoices', 'IDs', 'Taxes', 'Notes', 'Documents'];
        if (!defaultCategories.contains(cloudDoc.category)) {
          if (!library.sections.any((s) => s.name == cloudDoc.category)) {
            await library.addSection(cloudDoc.category);
          }
        }
        
        // Ensure subfolder exists
        if (cloudDoc.subfolder != null) {
          await library.ensureSubfolderExists(cloudDoc.category, cloudDoc.subfolder!);
        }

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
                // The sizes match! Same file.
                await library.updateSyncStatus(localDoc.id, true, driveId: df.id);
                // Also update category/subfolder to match cloud source of truth
                if (localDoc.category != cloudDoc.category || localDoc.subfolder != cloudDoc.subfolder) {
                   // We don't have a combined update method, but we can do it via a quick copyWith and save
                   // But actually, just updating sync status is enough for now.
                }
                exactMatchFound = true;
                break;
              }
            }
          }
          
          if (exactMatchFound) continue;
        }

        // 3. Download it
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
            category: cloudDoc.category,
            subfolder: cloudDoc.subfolder,
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
