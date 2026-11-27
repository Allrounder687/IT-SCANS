import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../models/scan_document.dart';
import 'document_card.dart';

class FannedStackLayout extends StatefulWidget {
  final List<ScanDocument> documents;
  final bool isSelectionMode;
  final Set<String> selectedDocs;
  final Function(String) onSelect;
  final Function(ScanDocument) onTap;
  final Function(ScanDocument) onRename;
  final Function(String) onDelete;
  final Function(ScanDocument) onAutoName;
  final double bottomPadding;

  const FannedStackLayout({
    super.key,
    required this.documents,
    required this.isSelectionMode,
    required this.selectedDocs,
    required this.onSelect,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    required this.onAutoName,
    this.bottomPadding = 0,
  });

  @override
  State<FannedStackLayout> createState() => _FannedStackLayoutState();
}

class _FannedStackLayoutState extends State<FannedStackLayout> {
  bool _isFanned = true;

  @override
  void didUpdateWidget(FannedStackLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelectionMode && !oldWidget.isSelectionMode) {
      _isFanned = false;
    }
  }

  void _toggleFanned() {
    if (widget.isSelectionMode) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _isFanned = !_isFanned;
    });
  }

  Widget _buildCard(ScanDocument doc) {
    final isSelected = widget.selectedDocs.contains(doc.id);
    return DocumentCard(
      document: doc,
      isSelectionMode: widget.isSelectionMode,
      isSelected: isSelected,
      onTap: () {
        if (widget.isSelectionMode) {
          widget.onSelect(doc.id);
        } else {
          widget.onTap(doc);
        }
      },
      onRename: () {
        if (widget.isSelectionMode) {
          widget.onSelect(doc.id);
        } else {
          widget.onRename(doc);
        }
      },
      onDelete: () {
        widget.onDelete(doc.id);
      },
      onAutoName: () {
        if (!widget.isSelectionMode) {
          widget.onAutoName(doc);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) return const SizedBox.shrink();

    final layout = AppLayout.of(context);

    if (!_isFanned) {
      return ListView.separated(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        itemCount: widget.documents.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: layout.cardSpacing),
        itemBuilder: (context, index) {
          return _buildCard(widget.documents[index]);
        },
      );
    }

    final displayCount = math.min(widget.documents.length, 4);
    final displayDocs =
        widget.documents.sublist(0, displayCount).reversed.toList();

    return GestureDetector(
      onTap: _toggleFanned,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double stepDy = layout.isCompactHeight ? 11.0 : 14.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(displayCount, (index) {
                      final reverseIndex = displayCount - 1 - index;
                      final doc = displayDocs[index];

                      final double rotation = reverseIndex == 0
                          ? 0.0
                          : (reverseIndex % 2 == 0 ? -0.04 : 0.04) *
                              reverseIndex;
                      final double dy = reverseIndex * stepDy;

                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        top: dy,
                        left: 0,
                        right: 0,
                        child: Transform.rotate(
                          angle: rotation,
                          child: IgnorePointer(
                            ignoring: true,
                            child: DocumentCard(
                              document: doc,
                              isSelectionMode: false,
                              isSelected: false,
                              onTap: () {},
                              onRename: () {},
                              onDelete: () {},
                              onAutoName: () {},
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: Text(
                      'Tap stack to view ${widget.documents.length} scan${widget.documents.length == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(
                        color: appTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
