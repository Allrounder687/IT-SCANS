import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/scan_document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/export_service.dart';
import '../../services/firebase_share_service.dart';
import '../../widgets/app_pdf_viewer.dart';
import '../../widgets/biometric_wrapper.dart';

class ExportScreen extends StatelessWidget {
  final ScanDocument document;
  final ExportService _exportService = ExportService();
  final FirebaseShareService _shareService = FirebaseShareService();

  ExportScreen({super.key, required this.document});

  Future<void> _shareDocument(ScanDocument doc) async {
    await BiometricWrapper.runWithAuthBypass(
      () => SharePlus.instance.share(
        ShareParams(
          files: [XFile(doc.filePath)],
          text: 'Here is the scanned document: ${doc.name}',
        ),
      ),
    );
  }

  Future<void> _savePdf(BuildContext context, ScanDocument doc) async {
    try {
      await _exportService.saveToDownloads(
        doc.filePath,
        'IT_SCANS_${doc.name}_${doc.id}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully to Downloads!')),
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

  Future<void> _sendToUser(BuildContext context, ScanDocument doc) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentContacts = prefs.getStringList('recent_contacts') ?? [];

    if (!context.mounted) return;

    final email = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recent Contacts',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (recentContacts.isEmpty)
                Text(
                  'No recent contacts yet.',
                  style: GoogleFonts.inter(color: appTextMuted),
                ),
              if (recentContacts.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentContacts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final contact = recentContacts[index];
                      return GestureDetector(
                        onTap: () => Navigator.pop(context, contact),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: appAccent.withValues(alpha: 0.2),
                              child: Text(
                                contact[0].toUpperCase(),
                                style: const TextStyle(color: appAccent),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              contact.length > 10
                                  ? '${contact.substring(0, 8)}...'
                                  : contact,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
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
                  label: Text(
                    'Send to New Contact',
                    style: GoogleFonts.spaceGrotesk(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: appLine),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            title: Text(
              'Send to User',
              style: GoogleFonts.spaceGrotesk(color: Colors.white),
            ),
            content: TextField(
              controller: emailController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter recipient email',
                hintStyle: GoogleFonts.inter(color: appTextMuted),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: appLine),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: appAccent),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: appTextMuted),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, emailController.text.trim()),
                child: Text(
                  'Send',
                  style: GoogleFonts.inter(
                    color: appAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
        if (recentContacts.length > 5) {
          recentContacts = recentContacts.sublist(0, 5);
        }
        await prefs.setStringList('recent_contacts', recentContacts);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending document...', style: GoogleFonts.inter()),
        ),
      );

      try {
        await _shareService.shareDocument(
          doc.filePath,
          '${doc.name}.pdf',
          finalEmail,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document sent to $finalEmail successfully!',
                style: GoogleFonts.inter(color: Colors.black),
              ),
              backgroundColor: appAccent,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $errorMsg', style: GoogleFonts.inter()),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveDoc = context.select<LibraryProvider, ScanDocument>(
      (library) => library.findById(document.id) ?? document,
    );

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
                child: Builder(
                  builder: (context) {
                    final isPdf =
                        liveDoc.filePath.toLowerCase().endsWith('.pdf');
                    final container = Container(
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
                        child: isPdf
                            ? Container(
                                color: Colors.white,
                                padding: const EdgeInsets.all(16.0),
                                child: AppPdfViewer(
                                  filePath: liveDoc.filePath,
                                  isThumbnail: false,
                                ),
                              )
                            : Image.file(
                                File(liveDoc.filePath),
                                fit: BoxFit.cover,
                              ),
                      ),
                    );

                    // Avoid Hero transitions on heavy PDF PlatformViews to
                    // prevent Android SurfaceView flicker/crashes.
                    if (!isPdf) {
                      return Hero(
                        tag: 'card_${liveDoc.id}',
                        child: container,
                      );
                    }
                    return container;
                  },
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
                    liveDoc.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${liveDoc.pageCount} page(s)',
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
                          onPressed: () => _shareDocument(liveDoc),
                          icon: const Icon(
                            Icons.share,
                            color: Colors.blueAccent,
                          ),
                          label: Text(
                            'Social Media',
                            style: GoogleFonts.spaceGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: appLine),
                            backgroundColor:
                                Colors.blueAccent.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _savePdf(context, liveDoc),
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.black,
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                            final driveId =
                                await auth.syncService.uploadDocument(liveDoc);
                            if (context.mounted) {
                              if (driveId != null) {
                                unawaited(
                                  context
                                      .read<LibraryProvider>()
                                      .updateSyncStatus(
                                        liveDoc.id,
                                        true,
                                        driveId: driveId,
                                      ),
                                );
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    driveId != null
                                        ? 'Backed up to Google Drive!'
                                        : 'Failed to backup to Drive',
                                    style: GoogleFonts.inter(),
                                  ),
                                  backgroundColor: driveId != null
                                      ? Colors.green
                                      : Colors.red,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon:
                              const Icon(Icons.cloud_upload, color: appAccent),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _sendToUser(context, liveDoc),
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.blueAccent,
                      ),
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
