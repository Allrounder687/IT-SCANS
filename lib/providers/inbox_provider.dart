import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/firebase_share_service.dart';
import '../models/scan_document.dart';
import 'library_provider.dart';

class InboxProvider extends ChangeNotifier {
  final FirebaseShareService _shareService = FirebaseShareService();
  final LibraryProvider _libraryProvider;
  
  StreamSubscription? _inboxSubscription;
  int _unreadCount = 0;
  
  InboxProvider(this._libraryProvider);

  int get unreadCount => _unreadCount;

  void startListening() {
    _inboxSubscription?.cancel();
    _inboxSubscription = _shareService.getInboxStream().listen((messages) {
      int count = 0;
      for (final msg in messages) {
        if (msg['isRead'] == false) {
          count++;
          _autoDownloadAndAdd(msg);
        }
      }
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    });
  }

  void stopListening() {
    _inboxSubscription?.cancel();
    _inboxSubscription = null;
  }

  Future<void> _autoDownloadAndAdd(Map<String, dynamic> message) async {
    final String messageId = message['id'];
    final String downloadUrl = message['downloadUrl'] ?? '';
    final String originalName = message['fileName'] ?? 'Shared_Document';
    
    if (downloadUrl.isEmpty) return;
    
    try {
      // 1. Mark as read immediately to prevent double processing
      await _shareService.markAsRead(messageId);
      
      // 2. Download the file
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        debugPrint('Failed to download file from Google Drive link');
        return;
      }
      
      // 3. Save to local storage
      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory(p.join(appDir.path, 'scans'));
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }
      
      final safeName = '${originalName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(p.join(scansDir.path, safeName));
      await file.writeAsBytes(response.bodyBytes);
      
      // 4. Add to Library
      final doc = ScanDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: originalName,
        pageCount: 1,
        filePath: file.path,
        createdAt: DateTime.now(),
        category: 'Documents',
      );
      await _libraryProvider.addDocument(doc);
      
      debugPrint('Auto-downloaded and added $originalName to library');
      
    } catch (e) {
      debugPrint('Auto-download error: $e');
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
