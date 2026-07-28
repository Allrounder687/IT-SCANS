import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../models/scan_document.dart';
import '../core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'rotating_subtitle.dart';

class DocumentCard extends StatelessWidget {
  final ScanDocument document;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAutoName;
  final bool isSelectionMode;
  final bool isSelected;

  const DocumentCard({
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
    return Dismissible(
      key: Key(document.id),
      direction: isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 32),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        onLongPress: onRename,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? appAccent.withValues(alpha: 0.1) : appSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? appAccent : appLine),
        ),
        child: Row(
          children: [
            Hero(
              tag: 'card_${document.id}',
              child: Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? appAccent : appPaper,
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: isSelectionMode
                  ? Center(child: Icon(isSelected ? Icons.check : Icons.circle_outlined, color: isSelected ? Colors.black : appTextMuted))
                  : AbsorbPointer(
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
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.name,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: RotatingSubtitle(
                          texts: [
                            '${document.pageCount} page${document.pageCount > 1 ? 's' : ''}',
                            _formatDate(document.createdAt),
                            _getFileSize(document.filePath),
                          ],
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            color: appTextMuted,
                          ),
                        ),
                      ),
                      if (document.isSynced) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.cloud_done, color: appAccent, size: 16),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!isSelectionMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: appTextMuted),
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
              )
            else
              const Icon(Icons.chevron_right, color: appTextMuted),
          ],
        ),
        ),
      ),
    );
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

}
