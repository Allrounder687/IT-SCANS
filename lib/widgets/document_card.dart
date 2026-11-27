import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/scan_document.dart';
import 'app_pdf_viewer.dart';
import 'move_document_dialog.dart';
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
    final layout = AppLayout.of(context);
    final isPdf = document.filePath.toLowerCase().endsWith('.pdf');
    final thumbnail = Container(
      width: layout.thumbWidth,
      height: layout.thumbHeight,
      decoration: BoxDecoration(
        color: isSelected ? appAccent : appPaper,
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: isSelectionMode
          ? Center(
              child: Icon(
                isSelected ? Icons.check : Icons.circle_outlined,
                color: isSelected ? Colors.black : appTextMuted,
              ),
            )
          : AbsorbPointer(
              child: isPdf
                  ? AppPdfViewer(filePath: document.filePath, isThumbnail: true)
                  : Image.file(File(document.filePath), fit: BoxFit.cover),
            ),
    );

    return Dismissible(
      key: Key(document.id),
      direction:
          isSelectionMode ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_sweep, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          onTap();
        },
        onLongPress: () {
          if (isSelectionMode) return;
          unawaited(HapticFeedback.selectionClick());
          unawaited(
            showModalBottomSheet<void>(
              context: context,
              backgroundColor: appSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (context) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading:
                            const Icon(Icons.share, color: Colors.blueAccent),
                        title: Text(
                          'Open / Share',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onTap();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit, color: Colors.white),
                        title: Text(
                          'Rename',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onRename();
                        },
                      ),
                      ListTile(
                        leading:
                            const Icon(Icons.auto_awesome, color: appAccent),
                        title: Text(
                          'Auto-Name (AI)',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onAutoName();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: Text(
                          'Delete',
                          style: GoogleFonts.inter(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(layout.cardPadding),
          decoration: BoxDecoration(
            color: isSelected ? appAccent.withValues(alpha: 0.1) : appSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? appAccent : appLine),
          ),
          child: Row(
            children: [
              isPdf
                  ? thumbnail
                  : Hero(tag: 'card_${document.id}', child: thumbnail),
              SizedBox(width: layout.isNarrow ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      document.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: layout.isNarrow ? 14 : 15,
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
                              fontSize: layout.isNarrow ? 11 : 12,
                              color: appTextMuted,
                            ),
                          ),
                        ),
                        if (document.isSynced) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.cloud_done,
                            color: appAccent,
                            size: 15,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isSelectionMode)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: appTextMuted),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  color: appSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'move',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.drive_file_move_outline,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Move',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'autoname',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 18,
                            color: appAccent,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Auto-Name',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'move') {
                      unawaited(showMoveDocumentDialog(context, document));
                    } else if (value == 'autoname') {
                      onAutoName();
                    }
                  },
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
      if (bytes <= 0) return '0 B';
      const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
      final i = (math.log(bytes) / math.log(1024)).floor();
      return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
    } catch (_) {
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
