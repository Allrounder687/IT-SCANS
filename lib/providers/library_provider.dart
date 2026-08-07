import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/scan_document.dart';
import '../services/storage_service.dart';

class LibraryProvider extends ChangeNotifier {
  final StorageService _storageService;
  List<ScanDocument> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';

  LibraryProvider(this._storageService) {
    _loadDocuments();
  }

  List<ScanDocument> get documents {
    var filtered = _documents;
    if (_selectedCategory != 'All') {
      filtered = filtered.where((d) => d.category == _selectedCategory).toList();
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
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  void setCategory(String category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
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
    _isLoading = false;
    notifyListeners();
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
