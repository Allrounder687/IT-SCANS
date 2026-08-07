import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../services/firebase_share_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseShareService _shareService = FirebaseShareService();
  final Map<String, bool> _downloading = {};

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    int i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    double size = bytes / (1024 * i > 0 ? (1 << (i * 10)) : 1);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _downloadAndOpen(Map<String, dynamic> message) async {
    final messageId = message['id'] as String;
    setState(() => _downloading[messageId] = true);
    
    try {
      final url = message['downloadUrl'] as String;
      final fileName = message['fileName'] as String;
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
        final savePath = p.join(dir.path, '$safeName.pdf');
        
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        
        await _shareService.markAsRead(messageId);
        
        // Open the file
        await OpenFilex.open(savePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to download file', style: GoogleFonts.inter())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.inter())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloading[messageId] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Inbox',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _shareService.getInboxStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: appAccent));
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Something went wrong.\nPlease ensure you are logged in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.red),
              ),
            );
          }
          
          final messages = snapshot.data ?? [];
          
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_outlined, size: 64, color: appTextMuted),
                  const SizedBox(height: 16),
                  Text(
                    'Your inbox is empty',
                    style: GoogleFonts.inter(color: appTextMuted, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: messages.length,
            separatorBuilder: (context, index) => const Divider(color: appLine),
            itemBuilder: (context, index) {
              final message = messages[index];
              final isRead = message['isRead'] as bool? ?? false;
              final isDownloading = _downloading[message['id']] ?? false;
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isRead ? appSurface : appAccent,
                  child: Icon(
                    Icons.picture_as_pdf, 
                    color: isRead ? appTextMuted : Colors.white,
                  ),
                ),
                title: Text(
                  message['fileName'] ?? 'Document.pdf',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'From: ${message['senderEmail']}',
                      style: GoogleFonts.inter(color: appTextMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(message['timestamp'] as Timestamp)} • ${_formatBytes(message['fileSize'] as int? ?? 0)}',
                      style: GoogleFonts.inter(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    isDownloading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: appAccent, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download, color: appAccent),
                            onPressed: () => _downloadAndOpen(message),
                          ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _shareService.deleteMessage(message['id']),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
