import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../models/scan_document.dart';
import 'document_card.dart';
import '../core/theme.dart';
import 'package:google_fonts/google_fonts.dart';

class FannedStackLayout extends StatefulWidget {
  final List<ScanDocument> documents;
  final bool isSelectionMode;
  final Set<String> selectedDocs;
  final Function(String) onSelect;
  final Function(ScanDocument) onTap;
  final Function(ScanDocument) onRename;
  final Function(String) onDelete;
  final Function(ScanDocument) onAutoName;

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
    HapticFeedback.selectionClick();
    setState(() {
      _isFanned = !_isFanned;
    });
  }

  Widget _buildCard(ScanDocument doc, int index) {
    final isSelected = widget.selectedDocs.contains(doc.id);
    return IgnorePointer(
      ignoring: false,
      child: DocumentCard(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) return const SizedBox.shrink();

    if (!_isFanned) {
      return ListView.separated(
        itemCount: widget.documents.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildCard(widget.documents[index], index);
        },
      );
    }

    final displayCount = math.min(widget.documents.length, 4);
    final displayDocs = widget.documents.sublist(0, displayCount).reversed.toList();

    return GestureDetector(
      onTap: _toggleFanned,
      child: Container(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              width: constraints.maxWidth,
              child: Stack(
                clipBehavior: Clip.none,
                children: List.generate(displayCount, (index) {
                final reverseIndex = displayCount - 1 - index;
                final doc = displayDocs[index];
                
                final double rotation = reverseIndex == 0 ? 0.0 : (reverseIndex % 2 == 0 ? -0.05 : 0.05) * reverseIndex;
                final double dy = reverseIndex * 15.0;
                
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
            );
          }
        ),
      ),
    );
  }
}
