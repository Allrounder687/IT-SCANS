import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/library_provider.dart';
import '../core/theme.dart';
import '../models/scan_document.dart';

Future<void> showMoveDocumentDialog(BuildContext context, ScanDocument document) async {
  await showDialog(
    context: context,
    builder: (context) => MoveDocumentDialog(document: document),
  );
}

class MoveDocumentDialog extends StatefulWidget {
  final ScanDocument document;

  const MoveDocumentDialog({super.key, required this.document});

  @override
  State<MoveDocumentDialog> createState() => _MoveDocumentDialogState();
}

class _MoveDocumentDialogState extends State<MoveDocumentDialog> {
  String? _selectedCategory;
  String? _selectedSubfolder;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.document.category ?? 'Documents';
    _selectedSubfolder = widget.document.subfolder;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final categories = library.allCategories;
    
    // Ensure selected category is in the list
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = categories.isNotEmpty ? categories.first : 'Documents';
    }

    final subfolders = _selectedCategory != null 
        ? library.getSubfoldersForCategory(_selectedCategory!) 
        : [];

    return AlertDialog(
      backgroundColor: appSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Move "${widget.document.name}"',
        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Section', style: GoogleFonts.inter(color: appTextMuted, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: appBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: appLine),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  dropdownColor: appBackground,
                  value: _selectedCategory,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  style: GoogleFonts.inter(color: Colors.white),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                      _selectedSubfolder = null;
                    });
                  },
                  items: categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            if (subfolders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Select Subfolder (Optional)', style: GoogleFonts.inter(color: appTextMuted, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: appBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: appLine),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    dropdownColor: appBackground,
                    value: _selectedSubfolder,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    style: GoogleFonts.inter(color: Colors.white),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubfolder = value;
                      });
                    },
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None (Root of Section)', style: TextStyle(fontStyle: FontStyle.italic, color: appTextMuted)),
                      ),
                      ...subfolders.map((sub) {
                        return DropdownMenuItem<String?>(
                          value: sub.name,
                          child: Text(sub.name),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: appAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            if (_selectedCategory != null) {
              library.moveDocument(widget.document.id, _selectedCategory!, _selectedSubfolder);
              Navigator.pop(context);
            }
          },
          child: Text('Move', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
