import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/scan_document.dart';
import '../../providers/library_provider.dart';
import '../../providers/monetization_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/scanner_service.dart';
import '../../widgets/scan_button.dart';
import '../../widgets/document_card.dart';
import '../../widgets/document_grid_card.dart';
import '../../widgets/beam_wipe_overlay.dart';
import '../../widgets/fanned_stack_layout.dart';
import '../../services/ocr_service.dart';
import '../../core/theme.dart';
import '../export/export_screen.dart';
import '../paywall/paywall_screen.dart';
import '../settings/settings_screen.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum ViewMode { stack, list, grid }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  Set<String> _selectedDocs = {};
  final _scannerService = ScannerService();
  final _ocrService = OcrService();
  bool _isScanning = false;
  ViewMode _viewMode = ViewMode.stack;
  bool _isUiVisible = true;
  double _lastScrollPosition = 0;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runOcrSweep();
    });
  }

  Future<void> _runOcrSweep() async {
    final library = context.read<LibraryProvider>();
    // Wait for documents to load
    while (library.isLoading) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Find documents with default names
    for (var doc in library.documents) {
      if (doc.name.startsWith('Scan 20') || doc.name.startsWith('Scan 2')) {
        try {
          String newName = await _ocrService.generateContextualName(doc.filePath) ?? doc.name;
          if (newName != doc.name && mounted) {
            await library.renameDocument(doc.id, newName);
          }
        } catch (e) {
          debugPrint('Background OCR failed for ${doc.id}: $e');
        }
      }
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isBannerAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
        },
      ),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (err) {
          _interstitialAd = null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  String _getGreeting(String? name) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }
    
    if (name != null && name.isNotEmpty) {
      final firstName = name.split(' ').first;
      return '$greeting, $firstName.';
    }
    return '$greeting.';
  }

  Future<void> _startScan() async {
    if (_isScanning) return;
    
    // Cannot scan while in selection mode
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedDocs.clear();
      });
    }
    
    setState(() => _isScanning = true);
    
    try {
      final monetization = context.read<MonetizationProvider>();
      
      // Check limit before launching scanner
      if (!monetization.canScan) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaywallScreen()),
          );
        }
        return;
      }

      final doc = await _scannerService.scan();
      if (doc != null) {

        if (mounted) {
          // Save document to library
          await context.read<LibraryProvider>().addDocument(doc);
          
          // Increment the scan counter
          await monetization.incrementScanCount();
          
          // Trigger Auto-Sync if enabled
          final auth = context.read<AuthProvider>();
          final libraryProvider = context.read<LibraryProvider>();
          if (auth.isSignedIn && auth.autoSync) {
            // Kick it off in the background without blocking the UI
            auth.syncService.uploadDocument(doc).then((driveId) {
              if (driveId != null && mounted) {
                libraryProvider.updateSyncStatus(doc.id, true, driveId: driveId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${doc.name} synced to Drive!', style: GoogleFonts.inter()),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
          }
          
          if (mounted) {
            // Show Interstitial ad every 2 scans for free ad-supported users
            if (monetization.isAdSupported && (monetization.scanCount % 2 == 0)) {
              if (_interstitialAd != null) {
                _interstitialAd!.show();
              }
            }

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExportScreen(document: doc),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e', style: GoogleFonts.inter())),
        );
      }
    } finally {
      if (mounted) {
        // Add a small cooldown to ensure native Android resources are fully disposed
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _showRenameDialog(ScanDocument doc) async {
    if (_isSelectionMode) return;
    
    final TextEditingController controller = TextEditingController(text: doc.name)
      ..selection = TextSelection(baseOffset: 0, extentOffset: doc.name.length);
      
    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Rename Document',
            style: GoogleFonts.spaceGrotesk(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: Colors.white),
            cursorColor: appAccent,
            decoration: InputDecoration(
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appAccent)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: appLine)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Save', style: GoogleFonts.inter(color: appAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != doc.name && mounted) {
      await context.read<LibraryProvider>().renameDocument(doc.id, newName);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedDocs.clear();
    });
  }

  void _toggleDocumentSelection(String id) {
    setState(() {
      if (_selectedDocs.contains(id)) {
        _selectedDocs.remove(id);
      } else {
        _selectedDocs.add(id);
      }
    });
  }

  Future<void> _deleteSelectedDocuments() async {
    final count = _selectedDocs.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete $count Scans?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete these $count scans?',
          style: GoogleFonts.inter(color: appTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.heavyImpact();
      await context.read<LibraryProvider>().deleteMultipleDocuments(_selectedDocs);
      setState(() {
        _isSelectionMode = false;
        _selectedDocs.clear();
      });
    }
  }

  void _handleSingleDelete(ScanDocument doc) {
    if (_isSelectionMode) {
      _toggleDocumentSelection(doc.id);
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: appSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete Scan?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          content: Text(
            'Are you sure you want to permanently delete "${doc.name}"?',
            style: GoogleFonts.inter(color: appTextMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: appTextMuted)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<LibraryProvider>().deleteDocument(doc.id);
                HapticFeedback.heavyImpact();
              },
              child: Text('Delete', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleAutoName(ScanDocument doc) async {
    HapticFeedback.selectionClick();
    
    // Show a quick loading snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analyzing document with AI...', style: GoogleFonts.inter()),
        backgroundColor: appSurface,
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      String newName = await _ocrService.generateContextualName(doc.filePath) ?? doc.name;
      if (newName != doc.name && mounted) {
        await context.read<LibraryProvider>().renameDocument(doc.id, newName);
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Renamed to "$newName"', style: GoogleFonts.inter(color: Colors.black)),
            backgroundColor: appAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not auto-name document.', style: GoogleFonts.inter())),
        );
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels > 20 && notification.scrollDelta! > 3) {
        if (_isUiVisible) setState(() => _isUiVisible = false);
      } else if (notification.scrollDelta! < -5 || notification.metrics.pixels <= 20) {
        if (!_isUiVisible) setState(() => _isUiVisible = true);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return BeamWipeOverlay(
      child: Scaffold(
        backgroundColor: appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return Text(
                        _getGreeting(auth.currentUser?.displayName),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Consumer<MonetizationProvider>(
                        builder: (context, monetization, child) {
                          if (monetization.isAdSupported && !monetization.isPremium) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
                                },
                                icon: const Icon(Icons.workspace_premium, color: appAccent, size: 20),
                                label: Text(
                                  'Upgrade',
                                  style: GoogleFonts.inter(
                                    color: appAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: appAccent.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: appTextMuted),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Scans',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _viewMode == ViewMode.stack ? Icons.view_agenda_rounded :
                          _viewMode == ViewMode.grid ? Icons.grid_view_rounded :
                          Icons.view_list_rounded,
                          color: appTextMuted,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (_viewMode == ViewMode.stack) {
                              _viewMode = ViewMode.grid;
                            } else if (_viewMode == ViewMode.grid) {
                              _viewMode = ViewMode.list;
                            } else {
                              _viewMode = ViewMode.stack;
                            }
                          });
                        },
                      ),
                      Consumer<LibraryProvider>(
                        builder: (context, library, child) {
                          if (library.documents.isEmpty) return const SizedBox.shrink();
                          return TextButton(
                            onPressed: _toggleSelectionMode,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _isSelectionMode ? 'Cancel' : 'Select',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: appAccent,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: Consumer<LibraryProvider>(
                  builder: (context, library, child) {
                    if (library.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: appAccent));
                    }
                    if (library.documents.isEmpty) {
                      return Center(
                        child: Text(
                          'No documents yet.\nTap the scanner to digitize your first page.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: appTextMuted,
                            height: 1.5,
                          ),
                        ),
                      );
                    }
                    if (_viewMode == ViewMode.grid) {
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: library.documents.length,
                        itemBuilder: (context, index) {
                          final doc = library.documents[index];
                          return DocumentGridCard(
                            document: doc,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedDocs.contains(doc.id),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleDocumentSelection(doc.id);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ExportScreen(document: doc)));
                              }
                            },
                            onRename: () {
                              if (_isSelectionMode) {
                                _toggleDocumentSelection(doc.id);
                              } else {
                                _showRenameDialog(doc);
                              }
                            },
                            onDelete: () => _handleSingleDelete(doc),
                            onAutoName: () => _handleAutoName(doc),
                          );
                        },
                      );
                    }
                    
                    if (_viewMode == ViewMode.list) {
                      return ListView.separated(
                        itemCount: library.documents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final doc = library.documents[index];
                          return DocumentCard(
                            document: doc,
                            isSelectionMode: _isSelectionMode,
                            isSelected: _selectedDocs.contains(doc.id),
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleDocumentSelection(doc.id);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => ExportScreen(document: doc)));
                              }
                            },
                            onRename: () {
                              if (_isSelectionMode) {
                                _toggleDocumentSelection(doc.id);
                              } else {
                                _showRenameDialog(doc);
                              }
                            },
                            onDelete: () => _handleSingleDelete(doc),
                            onAutoName: () => _handleAutoName(doc),
                          );
                        },
                      );
                    }

                    return FannedStackLayout(
                      documents: library.documents,
                      isSelectionMode: _isSelectionMode,
                      selectedDocs: _selectedDocs,
                      onSelect: _toggleDocumentSelection,
                      onTap: (doc) => Navigator.push(context, MaterialPageRoute(builder: (context) => ExportScreen(document: doc))),
                      onRename: _showRenameDialog,
                      onDelete: (id) {
                        context.read<LibraryProvider>().deleteDocument(id);
                      },
                      onAutoName: _handleAutoName,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: _isSelectionMode && _selectedDocs.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _deleteSelectedDocuments,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text(
                'Delete (${_selectedDocs.length})',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: !_isSelectionMode 
          ? Consumer<MonetizationProvider>(
              builder: (context, monetization, child) {
                if (monetization.isAdSupported && _bannerAd == null && !_isBannerAdLoaded) {
                  _loadBannerAd();
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SafeArea(
                      bottom: !monetization.isAdSupported,
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 300),
                        offset: _isUiVisible ? Offset.zero : const Offset(0, 1.5),
                        curve: Curves.easeOutCubic,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0, top: 16.0),
                          child: ScanButton(onPressed: _isScanning ? null : _startScan),
                        ),
                      ),
                    ),
                    if (monetization.isAdSupported)
                      SafeArea(
                        child: _isBannerAdLoaded && _bannerAd != null
                            ? Container(
                                color: appBackground,
                                width: _bannerAd!.size.width.toDouble(),
                                height: _bannerAd!.size.height.toDouble(),
                                child: AdWidget(ad: _bannerAd!),
                              )
                            : Container(
                                color: appBackground,
                                height: 50,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: appTextMuted),
                                  ),
                                ),
                              ),
                      ),
                  ],
                );
              },
            )
          : null,
      ),
    );
  }
}
