import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:flutter/foundation.dart';

class AppPdfViewer extends StatefulWidget {
  final String filePath;
  final bool isThumbnail;

  const AppPdfViewer({super.key, required this.filePath, this.isThumbnail = false});

  @override
  State<AppPdfViewer> createState() => _AppPdfViewerState();
}

class _AppPdfViewerState extends State<AppPdfViewer> {
  pdfx.PdfController? _pdfController;
  bool _isDesktop = false;

  Uint8List? _thumbnailBytes;
  bool _loadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (_isDesktop) {
      if (widget.isThumbnail) {
        _generateThumbnail();
      } else {
        _pdfController = pdfx.PdfController(
          document: pdfx.PdfDocument.openFile(widget.filePath),
        );
      }
    }
  }

  Future<void> _generateThumbnail() async {
    if (!mounted) return;
    setState(() => _loadingThumbnail = true);
    try {
      final document = await pdfx.PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.jpeg,
      );
      if (mounted && pageImage != null) {
        setState(() {
          _thumbnailBytes = pageImage.bytes;
        });
      }
      await page.close();
      await document.close();
    } catch (e) {
      debugPrint('Error generating PDF thumbnail: $e');
    } finally {
      if (mounted) setState(() => _loadingThumbnail = false);
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      if (widget.isThumbnail) {
        if (_thumbnailBytes != null) {
          return Image.memory(_thumbnailBytes!, fit: BoxFit.cover);
        }
        if (_loadingThumbnail) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return const Center(child: Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 32));
      }
      if (_pdfController == null) return const Center(child: CircularProgressIndicator());
      return pdfx.PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
        builders: pdfx.PdfViewBuilders<pdfx.DefaultBuilderOptions>(
          options: const pdfx.DefaultBuilderOptions(),
          documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, error) => Center(child: Text(error.toString())),
        ),
      );
    } else {
      return PDFView(
        filePath: widget.filePath,
        enableSwipe: !widget.isThumbnail,
        swipeHorizontal: false,
        autoSpacing: !widget.isThumbnail,
        pageFling: !widget.isThumbnail,
        pageSnap: !widget.isThumbnail,
        defaultPage: 0,
        fitPolicy: FitPolicy.BOTH,
        backgroundColor: Colors.white,
      );
    }
  }
}
