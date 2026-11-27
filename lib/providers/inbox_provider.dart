import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/scan_document.dart';
import '../services/firebase_share_service.dart';
import 'library_provider.dart';

class InboxProvider extends ChangeNotifier {
  final FirebaseShareService _shareService = FirebaseShareService();
  final LibraryProvider _libraryProvider;
  final Set<String> _processingMessageIds = {};

  StreamSubscription<List<Map<String, dynamic>>>? _inboxSubscription;
  int _unreadCount = 0;

  InboxProvider(this._libraryProvider);

  int get unreadCount => _unreadCount;

  void startListening() {
    unawaited(_inboxSubscription?.cancel() ?? Future<void>.value());
    _inboxSubscription = _shareService.getInboxStream().listen((messages) {
      int count = 0;
      for (final msg in messages) {
        if (msg['isRead'] == false) {
          count++;
          final messageId = msg['id'] as String?;
          if (messageId != null && !_processingMessageIds.contains(messageId)) {
            _processingMessageIds.add(messageId);
            unawaited(_autoDownloadAndAdd(msg));
          }
        }
      }
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    });
  }

  void stopListening() {
    unawaited(_inboxSubscription?.cancel() ?? Future<void>.value());
    _inboxSubscription = null;
  }

  Future<void> _autoDownloadAndAdd(Map<String, dynamic> message) async {
    final String messageId = message['id'] as String;
    final String downloadUrl = (message['downloadUrl'] as String?) ?? '';
    final String originalName =
        (message['fileName'] as String?) ?? 'Shared_Document';

    if (downloadUrl.isEmpty) {
      _processingMessageIds.remove(messageId);
      return;
    }

    try {
      await _shareService.markAsRead(messageId);

      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        debugPrint('Failed to download file from Google Drive link');
        return;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final scansDir = Directory(p.join(appDir.path, 'scans'));
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }

      final safeBase = originalName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final safeName =
          '${safeBase}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(p.join(scansDir.path, safeName));
      await file.writeAsBytes(response.bodyBytes);

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
    } finally {
      _processingMessageIds.remove(messageId);
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
