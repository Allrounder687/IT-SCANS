import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_user.dart';
import '../models/scan_document.dart';
import '../providers/library_provider.dart';
import '../services/cloud_sync_service.dart';

class AuthProvider extends ChangeNotifier {
  final CloudSyncService _syncService;
  final SharedPreferences _prefs;

  bool _autoSync = false;
  AppUser? _currentUser;
  bool _isLoading = true;
  StreamSubscription<AppUser?>? _userSub;

  AuthProvider(this._syncService, this._prefs) {
    unawaited(_init());
  }

  bool get autoSync => _autoSync;
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _currentUser != null;
  CloudSyncService get syncService => _syncService;

  Future<void> _init() async {
    _autoSync = _prefs.getBool('auto_sync') ?? false;

    _userSub = _syncService.onCurrentUserChanged.listen((account) {
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
      final structureJson = await _syncService.downloadStructureJson();
      if (structureJson != null && structureJson.isNotEmpty) {
        await library.importStructure(structureJson);
      }

      final cloudDocs = await _syncService.fetchCloudHierarchy();
      if (cloudDocs.isEmpty) return 0;

      final localDir = await getApplicationDocumentsDirectory();

      for (final cloudDoc in cloudDocs) {
        final df = cloudDoc.file;
        if (df.name == null || !df.name!.endsWith('.pdf')) continue;

        final docName = df.name!.replaceAll('.pdf', '');

        const defaultCategories = [
          'All',
          'Receipts',
          'Invoices',
          'IDs',
          'Taxes',
          'Notes',
          'Documents',
        ];
        if (!defaultCategories.contains(cloudDoc.category)) {
          if (!library.sections.any((s) => s.name == cloudDoc.category)) {
            await library.addSection(cloudDoc.category);
          }
        }

        if (cloudDoc.subfolder != null) {
          await library.ensureSubfolderExists(
            cloudDoc.category,
            cloudDoc.subfolder!,
          );
        }

        if (library.documents
            .any((d) => d.driveId != null && d.driveId == df.id)) {
          continue;
        }

        final existingDocs =
            library.documents.where((d) => d.name == docName).toList();
        if (existingDocs.isNotEmpty) {
          bool exactMatchFound = false;
          final cloudSize = int.tryParse(df.size ?? '0') ?? 0;

          for (final localDoc in existingDocs) {
            final localFile = File(localDoc.filePath);
            if (await localFile.exists()) {
              final localSize = await localFile.length();
              if (localSize == cloudSize) {
                await library.updateSyncStatus(
                  localDoc.id,
                  true,
                  driveId: df.id,
                );
                exactMatchFound = true;
                break;
              }
            }
          }

          if (exactMatchFound) continue;
        }

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

  @override
  void dispose() {
    unawaited(_userSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }
}
