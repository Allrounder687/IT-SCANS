import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_document.dart';
import '../models/category_model.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<ScanDocument> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  List<AppSection> _sections = [];
  List<AppSubfolder> _subfolders = [];
  String? _selectedSubfolder;
  String _searchQuery = '';
  
  String? _customSaveLocation;

  LibraryProvider(this._storageService) {
    _loadDocuments();
    _loadSettings();
  }

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
      filtered = filtered.where((d) => d.category == _selectedCategory).toList();
    }
    if (_selectedSubfolder != null) {
      filtered = filtered.where((d) => d.subfolder == _selectedSubfolder).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final matchesName = d.name.toLowerCase().contains(query);
        final matchesText = d.extractedText?.toLowerCase().contains(query) ?? false;
        return matchesName || matchesText;
      }).toList();
    }
    return filtered;
  }
  
  String get selectedCategory => _selectedCategory;
  String? get selectedSubfolder => _selectedSubfolder;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<AppSection> get sections => _sections;
  
  List<String> get allCategories {
    final defaultCategories = ['Receipts', 'Invoices', 'IDs', 'Taxes', 'Notes', 'Documents'];
    return [
      ...defaultCategories,
      ..._sections.map((s) => s.name),
    ];
  }
  
  List<AppSubfolder> get currentSubfolders => _subfolders.where((s) => s.sectionId == _selectedCategory).toList();
  List<AppSubfolder> getSubfoldersForCategory(String category) => _subfolders.where((s) => s.sectionId == category).toList();

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      _selectedSubfolder = null; // Reset subfolder on category change
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
    _documents = await _storageService.getScanDocuments();
    _sections = await _storageService.getSections();
    _subfolders = await _storageService.getAllSubfolders();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> importStructure(String jsonString) async {
    await _storageService.importStructureFromJson(jsonString);
    _sections = await _storageService.getSections();
    _subfolders = await _storageService.getAllSubfolders();
    notifyListeners();
  }

  Future<String> exportStructureToJson() async {
    return await _storageService.exportStructureToJson();
  }

  Future<void> addSection(String name) async {
    final newSection = AppSection(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name);
    await _storageService.saveSection(newSection);
    _sections.add(newSection);
    notifyListeners();
  }

  Future<void> addSubfolder(String name) async {
    if (_selectedCategory == 'All') return;
    await ensureSubfolderExists(_selectedCategory, name);
  }

  Future<void> ensureSubfolderExists(String sectionId, String name) async {
    if (!_subfolders.any((s) => s.sectionId == sectionId && s.name == name)) {
      final newSubfolder = AppSubfolder(id: DateTime.now().millisecondsSinceEpoch.toString(), sectionId: sectionId, name: name);
      await _storageService.saveSubfolder(newSubfolder);
      _subfolders.add(newSubfolder);
      notifyListeners();
    }
  }

  Future<void> addDocument(ScanDocument doc) async {
    await _storageService.saveScanDocument(doc);
    _documents.insert(0, doc);
    notifyListeners();
  }

  final Map<String, ScanDocument> _hiddenDocuments = {};

  void deleteDocument(String id) {
    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex == -1) return;
    
    final doc = _documents.removeAt(docIndex);
    _hiddenDocuments[id] = doc;
    notifyListeners();

    // Auto-commit delete after 4 seconds if not undone
    Future.delayed(const Duration(seconds: 4), () {
      if (_hiddenDocuments.containsKey(id)) {
        _executeDelete(id);
      }
    });
  }

  void undoDelete(String id) {
    if (_hiddenDocuments.containsKey(id)) {
      _documents.insert(0, _hiddenDocuments.remove(id)!);
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
    for (String id in ids) {
      final docIndex = _documents.indexWhere((d) => d.id == id);
      if (docIndex != -1) {
        final doc = _documents.removeAt(docIndex);
        _hiddenDocuments[id] = doc;
        
        Future.delayed(const Duration(seconds: 4), () {
          if (_hiddenDocuments.containsKey(id)) {
            _executeDelete(id);
          }
        });
      }
    }
    notifyListeners();
  }

  Future<void> renameDocument(String id, String newName) async {
    await _storageService.updateDocumentName(id, newName);
    
    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      final oldDoc = _documents[docIndex];
      _documents[docIndex] = ScanDocument(
        id: oldDoc.id,
        name: newName,
        pageCount: oldDoc.pageCount,
        filePath: oldDoc.filePath,
        createdAt: oldDoc.createdAt,
        category: oldDoc.category,
        extractedText: oldDoc.extractedText,
      );
      notifyListeners();
    }
  }

  Future<void> updateDocumentCategory(String id, String newCategory) async {
    await _storageService.updateDocumentCategory(id, newCategory);
    
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
        category: newCategory,
        subfolder: oldDoc.subfolder,
        extractedText: oldDoc.extractedText,
      );
      notifyListeners();
    }
  }

  Future<void> moveDocument(String id, String category, String? subfolder) async {
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

  Future<void> updateSyncStatus(String id, bool isSynced, {String? driveId}) async {
    await _storageService.updateSyncStatus(id, isSynced, driveId: driveId);
    
    final docIndex = _documents.indexWhere((d) => d.id == id);
    if (docIndex != -1) {
      final oldDoc = _documents[docIndex];
      _documents[docIndex] = ScanDocument(
        id: oldDoc.id,
        name: oldDoc.name,
        pageCount: oldDoc.pageCount,
        filePath: oldDoc.filePath,
        createdAt: oldDoc.createdAt,
        isSynced: isSynced,
        driveId: driveId ?? oldDoc.driveId,
        category: oldDoc.category,
        extractedText: oldDoc.extractedText,
      );
      notifyListeners();
    }
  }
}

