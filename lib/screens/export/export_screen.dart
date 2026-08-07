import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../models/scan_document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../core/theme.dart';
import '../../services/export_service.dart';
import '../../services/firebase_share_service.dart';

class ExportScreen extends StatelessWidget {
  final ScanDocument document;
  final ExportService _exportService = ExportService();
  final FirebaseShareService _shareService = FirebaseShareService();

  ExportScreen({super.key, required this.document});

  void _shareDocument() {
    Share.shareXFiles([XFile(document.filePath)], text: 'Here is the scanned document: ${document.name}');
  }

  Future<void> _savePdf(BuildContext context) async {
    try {
      final savedPath = await _exportService.saveToDownloads(document.filePath, 'IT_SCANS_${document.id}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved successfully to Downloads!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _sendToUser(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentContacts = prefs.getStringList('recent_contacts') ?? [];
    
    if (!context.mounted) return;
    
    final email = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: appSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recent Contacts', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (recentContacts.isEmpty)
                Text('No recent contacts yet.', style: GoogleFonts.inter(color: appTextMuted)),
              if (recentContacts.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentContacts.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final contact = recentContacts[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, contact),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: appAccent.withValues(alpha: 0.2),
                              child: Text(contact[0].toUpperCase(), style: const TextStyle(color: appAccent)),
                            ),
                            const SizedBox(height: 4),
                            Text(contact.length > 10 ? '${contact.substring(0, 8)}...' : contact, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, 'NEW_CONTACT'),
                  icon: const Icon(Icons.person_add, color: appAccent),
                  label: Text('Send to New Contact', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: appLine),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    String? finalEmail;

    if (email == 'NEW_CONTACT' && context.mounted) {
      final TextEditingController emailController = TextEditingController();
      finalEmail = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: appSurface,
            title: Text('Send to User', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            content: TextField(
              controller: emailController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter recipient email',
                hintStyle: GoogleFonts.inter(color: appTextMuted),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appLine)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appAccent)),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, emailController.text.trim()),
                child: Text('Send', style: GoogleFonts.inter(color: appAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } else {
      finalEmail = email;
    }

    if (finalEmail != null && finalEmail.isNotEmpty && context.mounted) {
      if (!recentContacts.contains(finalEmail)) {
        recentContacts.insert(0, finalEmail);
        if (recentContacts.length > 5) recentContacts = recentContacts.sublist(0, 5);
        await prefs.setStringList('recent_contacts', recentContacts);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sending document...', style: GoogleFonts.inter())),
      );
      
      final success = await _shareService.shareDocument(document.filePath, '${document.name}.pdf', finalEmail);
      
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Document sent to $finalEmail successfully!', style: GoogleFonts.inter(color: Colors.black)), backgroundColor: appAccent),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send document. Ensure you are signed in.', style: GoogleFonts.inter())),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Hero(
                  tag: 'card_${document.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: appPaper,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: document.filePath.toLowerCase().endsWith('.pdf') 
                        ? Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16.0),
                            child: PDFView(
                              filePath: document.filePath,
                              enableSwipe: true,
                              swipeHorizontal: false,
                              autoSpacing: true,
                              pageFling: true,
                              fitPolicy: FitPolicy.BOTH,
                              backgroundColor: Colors.white,
                            ),
                          )
                        : Image.file(File(document.filePath), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: appSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Text(
                    document.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${document.pageCount} page(s)',
                    style: GoogleFonts.jetBrainsMono(
                      color: appTextMuted,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareDocument,
                          icon: const Icon(Icons.adaptive.share, color: Colors.blueAccent),
                          label: Text(
                            'Social Media',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: appLine),
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _savePdf(context),
                          icon: const Icon(Icons.picture_as_pdf, color: Colors.black),
                          label: Text(
                            'Save PDF',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: appAccent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      if (!auth.isSignedIn) return const SizedBox.shrink();
                      
                      return SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final driveId = await auth.syncService.uploadDocument(document);
                            if (context.mounted) {
                              if (driveId != null) {
                                context.read<LibraryProvider>().updateSyncStatus(document.id, true, driveId: driveId);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    driveId != null ? 'Backed up to Google Drive!' : 'Failed to backup to Drive',
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: driveId != null ? Colors.green : Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.cloud_upload, color: appAccent),
                          label: Text(
                            'Backup to Drive',
                            style: GoogleFonts.spaceGrotesk(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: appLine),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _sendToUser(context),
                      icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                      label: Text(
                        'Direct Send to User',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: appLine),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
