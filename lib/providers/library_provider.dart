import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/scan_document.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService;
  final Completer<void> _initCompleter = Completer<void>();

  List<ScanDocument> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<AppSection> _sections = [];
  List<AppSubfolder> _subfolders = [];
  String? _selectedSubfolder;
  String _searchQuery = '';
  String? _customSaveLocation;

  final Map<String, ScanDocument> _hiddenDocuments = {};
  final Map<String, Timer> _deleteTimers = {};

  LibraryProvider(this._storageService) {
    unawaited(_loadDocuments());
    unawaited(_loadSettings());
  }

  Future<void> get ready => _initCompleter.future;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _customSaveLocation = prefs.getString('customSaveLocation');
    notifyListeners();
  }

  Future<void> setCustomSaveLocation(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove('customSaveLocation');
    } else {
      await prefs.setString('customSaveLocation', path);
    }
    _customSaveLocation = path;
    notifyListeners();
  }

  String? get customSaveLocation => _customSaveLocation;

  List<ScanDocument> get documents {
    var filtered = _documents;
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((d) => d.category == _selectedCategory).toList();
    }
    if (_selectedSubfolder != null) {
      filtered =
          filtered.where((d) => d.subfolder == _selectedSubfolder).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final matchesName = d.name.toLowerCase().contains(query);
        final matchesText =
            d.extractedText?.toLowerCase().contains(query) ?? false;
        return matchesName || matchesText;
      }).toList();
    }
    return filtered;
  }

  ScanDocument? findById(String id) {
    for (final doc in _documents) {
      if (doc.id == id) return doc;
    }
    return null;
  }

  String get selectedCategory => _selectedCategory;
  String? get selectedSubfolder => _selectedSubfolder;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<AppSection> get sections => _sections;

  List<String> get allCategories {
    const defaultCategories = [
      'Receipts',
      'Invoices',
      'IDs',
      'Taxes',
      'Notes',
      'Documents',
    ];
    return [
      ...defaultCategories,
      ..._sections.map((s) => s.name),
    ];
  }

  List<AppSubfolder> get currentSubfolders =>
      _subfolders.where((s) => s.sectionId == _selectedCategory).toList();
  List<AppSubfolder> getSubfoldersForCategory(String category) =>
      _subfolders.where((s) => s.sectionId == category).toList();

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      _selectedSubfolder = null;
      notifyListeners();
    }
  }

  void setSubfolder(String? subfolder) {
    if (_selectedSubfolder != subfolder) {
      _selectedSubfolder = subfolder;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  Future<void> _loadDocuments() async {
    try {
      _documents = await _storageService.getScanDocuments();
      _sections = await _storageService.getSections();
      _subfolders = await _storageService.getAllSubfolders();
    } finally {
      _isLoading = false;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      notifyListeners();
    }
  }

  Future<void> importStructure(String jsonString) async {
    await ready;
    await _storageService.importStructureFromJson(jsonString);
    _sections = await _storageService.getSections();
    _subfolders = await _storageService.getAllSubfolders();
    notifyListeners();
  }

  Future<String> exportStructureToJson() async {
    return _storageService.exportStructureToJson();
  }

  Future<void> addSection(String name) async {
    await ready;
    final newSection = AppSection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
    );
    await _storageService.saveSection(newSection);
    _sections.add(newSection);
    notifyListeners();
  }

  Future<void> addSubfolder(String name) async {
    if (_selectedCategory == 'All') return;
    await ensureSubfolderExists(_selectedCategory, name);
  }

  Future<void> ensureSubfolderExists(String sectionId, String name) async {
    await ready;
    if (!_subfolders.any((s) => s.sectionId == sectionId && s.name == name)) {
      final newSubfolder = AppSubfolder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sectionId: sectionId,
        name: name,
      );
      await _storageService.saveSubfolder(newSubfolder);
      _subfolders.add(newSubfolder);
      notifyListeners();
    }
  }

  Future<void> addDocument(ScanDocument doc) async {
    await ready;
    await _storageService.saveScanDocument(doc);
    _documents.removeWhere((existing) => existing.id == doc.id);
    _documents.insert(0, doc);
    notifyListeners();
  }

  void deleteDocument(String id) {
    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex == -1) return;

    final doc = _documents.removeAt(docIndex);
    _hiddenDocuments[id] = doc;
    notifyListeners();

    _deleteTimers[id]?.cancel();
    _deleteTimers[id] = Timer(const Duration(seconds: 4), () {
      _deleteTimers.remove(id);
      if (_hiddenDocuments.containsKey(id)) {
        unawaited(_executeDelete(id));
      }
    });
  }

  void undoDelete(String id) {
    _deleteTimers.remove(id)?.cancel();
    final doc = _hiddenDocuments.remove(id);
    if (doc != null) {
      _documents.insert(0, doc);
      notifyListeners();
    }
  }

  Future<void> _executeDelete(String id) async {
    final doc = _hiddenDocuments.remove(id);
    if (doc == null) return;

    await _storageService.deleteDocument(id);
    try {
      final file = File(doc.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete file: $e');
    }
  }

  void deleteMultipleDocuments(Set<String> ids) {
    for (final id in ids) {
      final docIndex = _documents.indexWhere((d) => d.id == id);
      if (docIndex != -1) {
        final doc = _documents.removeAt(docIndex);
        _hiddenDocuments[id] = doc;

        _deleteTimers[id]?.cancel();
        _deleteTimers[id] = Timer(const Duration(seconds: 4), () {
          _deleteTimers.remove(id);
          if (_hiddenDocuments.containsKey(id)) {
            unawaited(_executeDelete(id));
          }
        });
      }
    }
    notifyListeners();
  }

  Future<void> renameDocument(
    String id,
    String newName, {
    String? extractedText,
  }) async {
    await ready;
    await _storageService.updateDocumentName(id, newName);

    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      final oldDoc = _documents[docIndex];
      final updated = oldDoc.copyWith(
        name: newName,
        extractedText: extractedText ?? oldDoc.extractedText,
      );
      if (extractedText != null) {
        await _storageService.saveScanDocument(updated);
      }
      _documents[docIndex] = updated;
      notifyListeners();
    }
  }

  Future<void> updateDocumentCategory(String id, String newCategory) async {
    await ready;
    await _storageService.updateDocumentCategory(id, newCategory);

    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      _documents[docIndex] = _documents[docIndex].copyWith(
        category: newCategory,
      );
      notifyListeners();
    }
  }

  Future<void> moveDocument(
    String id,
    String category,
    String? subfolder,
  ) async {
    await ready;
    await _storageService.moveDocument(id, category, subfolder);

    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      final oldDoc = _documents[docIndex];
      _documents[docIndex] = ScanDocument(
        id: oldDoc.id,
        name: oldDoc.name,
        pageCount: oldDoc.pageCount,
        filePath: oldDoc.filePath,
        createdAt: oldDoc.createdAt,
        isSynced: oldDoc.isSynced,
        driveId: oldDoc.driveId,
        category: category,
        subfolder: subfolder,
        extractedText: oldDoc.extractedText,
      );
      notifyListeners();
    }
  }

  Future<void> updateSyncStatus(
    String id,
    bool isSynced, {
    String? driveId,
  }) async {
    await ready;
    await _storageService.updateSyncStatus(id, isSynced, driveId: driveId);

    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      _documents[docIndex] = _documents[docIndex].copyWith(
        isSynced: isSynced,
        driveId: driveId ?? _documents[docIndex].driveId,
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final timer in _deleteTimers.values) {
      timer.cancel();
    }
    _deleteTimers.clear();
    // Flush any pending soft-deletes so they don't resurrect on next launch.
    for (final id in _hiddenDocuments.keys.toList()) {
      unawaited(_executeDelete(id));
    }
    super.dispose();
  }
}
