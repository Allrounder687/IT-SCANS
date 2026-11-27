import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import '../core/theme.dart';

class AppPdfViewer extends StatefulWidget {
  final String filePath;
  final bool isThumbnail;

  const AppPdfViewer({
    super.key,
    required this.filePath,
    this.isThumbnail = false,
  });

  @override
  State<AppPdfViewer> createState() => _AppPdfViewerState();
}

class _AppPdfViewerState extends State<AppPdfViewer> {
  // Serialize thumbnail generation so scrolling a grid/list of PDFs never
  // spawns concurrent Pdfium renderers and triggers OOM crashes.
  static Future<void> _thumbnailQueue = Future<void>.value();

  pdfx.PdfController? _pdfController;
  File? _cachedThumbnailFile;
  bool _loadingThumbnail = false;
  int _currentPage = 1;
  int _totalPages = 0;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _initViewer();
  }

  void _initViewer() {
    if (widget.isThumbnail) {
      unawaited(_loadOrGenerateThumbnail());
    } else if (_isDesktop) {
      _pdfController = pdfx.PdfController(
        document: pdfx.PdfDocument.openFile(widget.filePath),
      );
    }
  }

  @override
  void didUpdateWidget(covariant AppPdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath ||
        oldWidget.isThumbnail != widget.isThumbnail) {
      _pdfController?.dispose();
      _pdfController = null;
      _cachedThumbnailFile = null;
      _currentPage = 1;
      _totalPages = 0;
      _initViewer();
    }
  }

  Future<void> _loadOrGenerateThumbnail() async {
    if (!mounted) return;
    setState(() => _loadingThumbnail = true);

    try {
      final sourceFile = File(widget.filePath);
      if (!await sourceFile.exists()) {
        if (mounted) setState(() => _loadingThumbnail = false);
        return;
      }

      final stat = await sourceFile.stat();
      final cacheDir = await getTemporaryDirectory();
      final thumbsDir = Directory(p.join(cacheDir.path, 'pdf_thumbs'));
      if (!await thumbsDir.exists()) {
        await thumbsDir.create(recursive: true);
      }

      final rawKey =
          '${widget.filePath}_${stat.modified.millisecondsSinceEpoch}_${stat.size}';
      final cacheKey = rawKey.hashCode.toUnsigned(32).toRadixString(16);
      final thumbFile = File(p.join(thumbsDir.path, 'thumb_$cacheKey.jpg'));

      if (await thumbFile.exists() && await thumbFile.length() > 100) {
        if (mounted) {
          setState(() {
            _cachedThumbnailFile = thumbFile;
            _loadingThumbnail = false;
          });
        }
        return;
      }

      await _enqueueThumbnailRender(widget.filePath, thumbFile);

      if (mounted &&
          await thumbFile.exists() &&
          await thumbFile.length() > 100) {
        setState(() {
          _cachedThumbnailFile = thumbFile;
        });
      }
    } catch (e) {
      debugPrint('Error generating PDF thumbnail: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingThumbnail = false);
      }
    }
  }

  static Future<void> _enqueueThumbnailRender(
    String pdfPath,
    File destFile,
  ) {
    final completer = Completer<void>();
    _thumbnailQueue = _thumbnailQueue.then((_) async {
      pdfx.PdfDocument? document;
      pdfx.PdfPage? page;
      try {
        if (!await File(pdfPath).exists()) {
          completer.complete();
          return;
        }
        if (await destFile.exists() && await destFile.length() > 100) {
          completer.complete();
          return;
        }
        document = await pdfx.PdfDocument.openFile(pdfPath);
        page = await document.getPage(1);

        const double maxThumbWidth = 240.0;
        final double scale =
            page.width > 0 ? (maxThumbWidth / page.width).clamp(0.2, 1.0) : 1.0;

        final pageImage = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        if (pageImage != null && pageImage.bytes.isNotEmpty) {
          await destFile.writeAsBytes(pageImage.bytes);
        }
      } catch (e) {
        debugPrint('Serialized thumbnail render error: $e');
      } finally {
        await page?.close();
        await document?.close();
        completer.complete();
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isThumbnail) {
      if (_cachedThumbnailFile != null) {
        return Image.file(_cachedThumbnailFile!, fit: BoxFit.cover);
      }
      if (_loadingThumbnail) {
        return const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return const Center(
        child: Icon(Icons.picture_as_pdf, color: Colors.blueAccent, size: 24),
      );
    }

    if (_isDesktop) {
      if (_pdfController == null) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          pdfx.PdfView(
            controller: _pdfController!,
            scrollDirection: Axis.horizontal,
            pageSnapping: true,
            onDocumentLoaded: (doc) {
              if (mounted) {
                setState(() => _totalPages = doc.pagesCount);
              }
            },
            onPageChanged: (page) {
              if (mounted) {
                setState(() => _currentPage = page);
              }
            },
            builders: pdfx.PdfViewBuilders<pdfx.DefaultBuilderOptions>(
              options: const pdfx.DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error) => Center(child: Text(error.toString())),
            ),
          ),
          if (_totalPages > 1) _buildPageBadge(),
        ],
      );
    }

    return Stack(
      children: [
        PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: true,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: 0,
          fitPolicy: FitPolicy.BOTH,
          backgroundColor: Colors.white,
          onRender: (pages) {
            if (mounted && pages != null) {
              setState(() => _totalPages = pages);
            }
          },
          onPageChanged: (page, total) {
            if (mounted && page != null) {
              setState(() {
                _currentPage = page + 1;
                if (total != null) _totalPages = total;
              });
            }
          },
        ),
        if (_totalPages > 1) _buildPageBadge(),
      ],
    );
  }

  Widget _buildPageBadge() {
    return Positioned(
      bottom: 8,
      right: 8,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: appBackground.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: appLine),
          ),
          child: Text(
            '$_currentPage / $_totalPages',
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
