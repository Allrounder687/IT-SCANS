import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../models/scan_document.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../core/theme.dart';
import '../../services/export_service.dart';

class ExportScreen extends StatelessWidget {
  final ScanDocument document;
  final ExportService _exportService = ExportService();

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
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: Text(
                            'Share',
                            style: GoogleFonts.spaceGrotesk(color: Colors.white),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: appLine),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
