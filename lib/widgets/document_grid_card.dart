import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/scan_document.dart';
import '../core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rotating_subtitle.dart';

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
      onTap: onTap,
      onLongPress: onRename,
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
                        ? PDFView(
                            filePath: document.filePath,
                            enableSwipe: false,
                            swipeHorizontal: false,
                            autoSpacing: false,
                            pageFling: false,
                            pageSnap: false,
                            defaultPage: 0,
                            fitPolicy: FitPolicy.BOTH,
                          )
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
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.more_vert, color: Colors.white, size: 16),
                        ),
                        color: appSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'rename') onRename();
                          if (value == 'delete') onDelete();
                          if (value == 'autoname') onAutoName();
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'autoname',
                            child: Text('Auto-Name (AI)', style: GoogleFonts.inter(color: Colors.blueAccent)),
                          ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename', style: GoogleFonts.inter(color: Colors.white)),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                          ),
                        ],
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
