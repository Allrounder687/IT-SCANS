import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/scan_document.dart';
import '../core/theme.dart';
import '../providers/library_provider.dart';
import 'app_pdf_viewer.dart';
import 'rotating_subtitle.dart';
import 'move_document_dialog.dart';
import 'package:google_fonts/google_fonts.dart';

class DocumentGridCard extends StatelessWidget {
  final ScanDocument document;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAutoName;
  final bool isSelectionMode;
  final bool isSelected;

  const DocumentGridCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onAutoName,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () {
        if (isSelectionMode) return;
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: appSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.blueAccent),
                  title: Text('Open / Share', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    onTap();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title: Text('Rename', style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    onRename();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? appAccent.withValues(alpha: 0.1) : appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? appAccent : appLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: appPaper,
                    child: AbsorbPointer(
                      child: document.filePath.toLowerCase().endsWith('.pdf')
                        ? AppPdfViewer(filePath: document.filePath, isThumbnail: true)
                        : Image.file(File(document.filePath), fit: BoxFit.cover),
                    ),
                  ),
                  if (isSelectionMode)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isSelected ? appAccent : Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSelected ? Icons.check : Icons.circle_outlined,
                          size: 16,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                  if (!isSelectionMode)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, color: appTextMuted),
                        color: appSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'move',
                            child: Row(
                              children: [
                                const Icon(Icons.drive_file_move_outline, size: 18, color: Colors.white),
                                const SizedBox(width: 12),
                                Text('Move', style: GoogleFonts.inter(color: Colors.white)),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (value) {
                          if (value == 'move') {
                            showMoveDocumentDialog(context, document);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RotatingSubtitle(
                          texts: [
                            '${document.pageCount} pg',
                            _formatDate(document.createdAt),
                            _getFileSize(document.filePath),
                          ],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: appTextMuted,
                          ),
                        ),
                      ),
                      if (document.isSynced)
                        const Icon(Icons.cloud_done, color: appAccent, size: 14),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final timeStr = '$hour12:$minute $amPm';
    
    if (difference.inDays == 0 && now.day == date.day) {
      return 'Today, $timeStr';
    } else if (difference.inDays <= 1 && now.day != date.day) {
      return 'Yesterday, $timeStr';
    } else {
      return '${date.day}/${date.month}/${date.year}, $timeStr';
    }
  }

  String _getFileSize(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return '0 B';
      final bytes = file.lengthSync();
      if (bytes <= 0) return "0 B";
      const suffixes = ["B", "KB", "MB", "GB", "TB"];
      var i = (math.log(bytes) / math.log(1024)).floor();
      return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
    } catch (e) {
      return '0 B';
    }
  }
}
