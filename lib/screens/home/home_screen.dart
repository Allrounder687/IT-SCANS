import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../models/scan_document.dart';
import '../../providers/accessibility_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inbox_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/monetization_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/scanner_service.dart';
import '../../services/update_service.dart';
import '../../widgets/beam_wipe_overlay.dart';
import '../../widgets/biometric_wrapper.dart';
import '../../widgets/document_card.dart';
import '../../widgets/document_grid_card.dart';
import '../../widgets/fanned_stack_layout.dart';
import '../../widgets/scan_button.dart';
import '../export/export_screen.dart';
import '../inbox/inbox_screen.dart';
import '../paywall/paywall_screen.dart';
import '../settings/settings_screen.dart';

enum ViewMode { stack, list, grid }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedDocs = {};
  final _scannerService = ScannerService();
  final _ocrService = OcrService();
  final TextEditingController _searchController = TextEditingController();
  bool _isScanning = false;
  ViewMode _viewMode = ViewMode.stack;
  bool _isUiVisible = true;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  InterstitialAd? _interstitialAd;
  MonetizationProvider? _monetizationProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _monetizationProvider = context.read<MonetizationProvider>();
      _monetizationProvider?.addListener(_onMonetizationChanged);
      _syncAdsWithMonetization();

      if (context.read<AuthProvider>().isSignedIn) {
        context.read<InboxProvider>().startListening();
      }
      await _recoverOrphanedScans();
      if (!mounted) return;
      unawaited(_runOcrSweep());
      if (Platform.isAndroid) {
        unawaited(_checkUpdatesInBackground());
      }
    });
  }

  void _onMonetizationChanged() {
    if (mounted) {
      _syncAdsWithMonetization();
    }
  }

  void _syncAdsWithMonetization() {
    final monetization = _monetizationProvider;
    if (monetization == null) return;
    final shouldShowAds = monetization.isAdSupported && !monetization.isPremium;
    if (shouldShowAds) {
      if (_bannerAd == null && !_isBannerAdLoaded) {
        _loadBannerAd();
      }
      if (_interstitialAd == null) {
        _loadInterstitialAd();
      }
    }
  }

  Future<void> _recoverOrphanedScans() async {
    final library = context.read<LibraryProvider>();
    final monetization = context.read<MonetizationProvider>();
    final recovered = await _scannerService.consumeRecoveredScans();
    if (recovered.isEmpty) return;

    for (final doc in recovered) {
      await library.addDocument(doc);
      await monetization.incrementScanCount();
      unawaited(_analyzeAndUpdateDocument(doc, library));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recovered ${recovered.length} scanned document(s)!',
            style: GoogleFonts.inter(color: Colors.black),
          ),
          backgroundColor: appAccent,
        ),
      );
    }
  }

  Future<void> _checkUpdatesInBackground() async {
    final updateService = UpdateService();
    final info = await updateService.checkForUpdate();

    if (!mounted) return;
    if (info != null && info.isUpdateAvailable) {
      final path = await updateService.downloadUpdate(info.downloadUrl);
      if (!mounted) return;

      if (path != null) {
        unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: appSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: appAccent),
              ),
              title: Text(
                'Yay! A New Update! 🚀',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'I found a new version of IT SCANS (${info.latestVersion}) and downloaded it for you! Install it now to get the latest magic! ✨',
                style: GoogleFonts.inter(color: appTextMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe Later',
                    style: GoogleFonts.inter(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    unawaited(updateService.installUpdate(path));
                  },
                  child: Text(
                    'Install Magic ✨',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _runOcrSweep() async {
    if (!mounted) return;
    final library = context.read<LibraryProvider>();
    await library.ready;
    if (!mounted) return;

    final pendingDocs = library.documents
        .where(
          (doc) =>
              doc.name.startsWith('Scan 20') || doc.name.startsWith('Scan 2'),
        )
        .toList();

    for (final doc in pendingDocs) {
      if (!mounted) return;
      await _analyzeAndUpdateDocument(doc, library);
    }
  }

  Future<void> _analyzeAndUpdateDocument(
    ScanDocument doc,
    LibraryProvider library,
  ) async {
    try {
      final ocrResult = await _ocrService.analyzeDocument(doc.filePath);
      if (ocrResult == null) return;
      final newName = ocrResult.name;
      if (newName != null && newName.isNotEmpty && newName != doc.name) {
        await library.renameDocument(
          doc.id,
          newName,
          extractedText: ocrResult.fullText,
        );
      }
    } catch (e) {
      debugPrint('Background OCR failed for ${doc.id}: $e');
    }
  }

  void _loadBannerAd() {
    if (!Platform.isAndroid && !Platform.isIOS) return;
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
    if (!Platform.isAndroid && !Platform.isIOS) return;
    unawaited(
      InterstitialAd.load(
        adUnitId: 'ca-app-pub-3940256099942544/1033173712',
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (ad, err) {
                ad.dispose();
                _interstitialAd = null;
                _loadInterstitialAd();
              },
            );
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (err) {
            _interstitialAd = null;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _monetizationProvider?.removeListener(_onMonetizationChanged);
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) return;

    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedDocs.clear();
      });
    }

    setState(() => _isScanning = true);

    try {
      final monetization = context.read<MonetizationProvider>();

      if (!monetization.canScan) {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaywallScreen()),
          );
        }
        return;
      }

      final library = context.read<LibraryProvider>();
      final auth = context.read<AuthProvider>();

      final doc = await BiometricWrapper.runWithAuthBypass(
        () => _scannerService.scan(),
      );
      if (doc != null) {
        final selectedCategory = library.selectedCategory == 'All'
            ? 'Documents'
            : library.selectedCategory;
        final selectedSubfolder = library.selectedSubfolder;

        final updatedDoc = doc.copyWith(
          category: selectedCategory,
          subfolder: selectedSubfolder,
        );

        await library.addDocument(updatedDoc);
        await monetization.incrementScanCount();

        if (auth.isSignedIn && auth.autoSync) {
          unawaited(
            auth.syncService.uploadDocument(updatedDoc).then((driveId) {
              if (driveId != null) {
                unawaited(
                  library.updateSyncStatus(
                    updatedDoc.id,
                    true,
                    driveId: driveId,
                  ),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${updatedDoc.name} synced to Drive!',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            }),
          );
        }

        if (mounted) {
          if (monetization.isAdSupported &&
              !monetization.isPremium &&
              (monetization.scanCount % 2 == 0) &&
              _interstitialAd != null) {
            unawaited(_interstitialAd!.show());
            _interstitialAd = null;
          }

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExportScreen(document: updatedDoc),
            ),
          );
        }

        unawaited(_analyzeAndUpdateDocument(updatedDoc, library));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan failed: $e', style: GoogleFonts.inter()),
          ),
        );
      }
    } finally {
      if (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (mounted) setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    final libraryProvider = context.read<LibraryProvider>();
    final pickedFiles = await BiometricWrapper.runWithAuthBypass(
      () => ImagePicker().pickMultiImage(),
    );
    if (pickedFiles.isEmpty) return;

    try {
      final customPath = libraryProvider.customSaveLocation;
      final targetCategory = libraryProvider.selectedCategory == 'All'
          ? 'Documents'
          : libraryProvider.selectedCategory;
      final targetSubfolder = libraryProvider.selectedSubfolder;

      final Directory saveDir;
      if (customPath != null && customPath.isNotEmpty) {
        saveDir = Directory(customPath);
      } else {
        final appDocs = await getApplicationDocumentsDirectory();
        saveDir = Directory(p.join(appDocs.path, 'scans'));
      }

      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      for (var i = 0; i < pickedFiles.length; i++) {
        final pickedFile = pickedFiles[i];
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${timestamp}_${pickedFile.name}';
        final savedImage =
            await File(pickedFile.path).copy(p.join(saveDir.path, fileName));

        final now = DateTime.now();
        final newDoc = ScanDocument(
          id: '${now.microsecondsSinceEpoch}_$i',
          name:
              'Upload ${now.toIso8601String().substring(0, 16).replaceAll('T', ' ')}${pickedFiles.length > 1 ? ' ${i + 1}' : ''}',
          pageCount: 1,
          filePath: savedImage.path,
          createdAt: now,
          category: targetCategory,
          subfolder: targetSubfolder,
        );

        await libraryProvider.addDocument(newDoc);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Uploaded ${pickedFiles.length} file(s) to $targetCategory',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading: $e', style: GoogleFonts.inter()),
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(ScanDocument doc) async {
    final library = context.read<LibraryProvider>();
    final name =
        await _showInputDialog('Rename Document', initialValue: doc.name);
    if (name != null && name.isNotEmpty) {
      await library.renameDocument(doc.id, name);
    }
  }

  Future<String?> _showInputDialog(String title, {String? initialValue}) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appSurface,
        title:
            Text(title, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: const InputDecoration(
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: appAccent),
            ),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: appTextMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: appAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedDocs.clear();
    });
  }

  void _toggleDocumentSelection(String id) {
    unawaited(HapticFeedback.selectionClick());
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

    unawaited(HapticFeedback.heavyImpact());
    final idsToDelete = Set<String>.from(_selectedDocs);
    final library = context.read<LibraryProvider>();
    library.deleteMultipleDocuments(idsToDelete);

    setState(() {
      _isSelectionMode = false;
      _selectedDocs.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count scans deleted.', style: GoogleFonts.inter()),
        backgroundColor: appSurface,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: appAccent,
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            for (final id in idsToDelete) {
              library.undoDelete(id);
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleSingleDelete(ScanDocument doc) {
    if (_isSelectionMode) {
      _toggleDocumentSelection(doc.id);
      return;
    }

    unawaited(HapticFeedback.heavyImpact());
    final library = context.read<LibraryProvider>();
    library.deleteDocument(doc.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document deleted.', style: GoogleFonts.inter()),
        backgroundColor: appSurface,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: appAccent,
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            library.undoDelete(doc.id);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleAutoName(ScanDocument doc) async {
    unawaited(HapticFeedback.selectionClick());
    final library = context.read<LibraryProvider>();
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Analyzing document with AI...',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: appSurface,
        duration: const Duration(seconds: 1),
      ),
    );
    try {
      final ocrResult = await _ocrService.analyzeDocument(doc.filePath);
      final String newName = ocrResult?.name ?? doc.name;
      if (newName != doc.name) {
        await library.renameDocument(
          doc.id,
          newName,
          extractedText: ocrResult?.fullText,
        );
        unawaited(HapticFeedback.lightImpact());
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Renamed to "$newName"',
                style: GoogleFonts.inter(color: Colors.black),
              ),
              backgroundColor: appAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Could not auto-name document.',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != null) {
      if (notification.metrics.pixels > 20 && notification.scrollDelta! > 3) {
        if (_isUiVisible) setState(() => _isUiVisible = false);
      } else if (notification.scrollDelta! < -5 ||
          notification.metrics.pixels <= 20) {
        if (!_isUiVisible) setState(() => _isUiVisible = true);
      }
    }
    return false;
  }

  Widget _buildHeader(BuildContext context, AppLayout layout) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Consumer<AuthProvider>(
            builder: (context, auth, child) {
              final name = auth.currentUser?.displayName;
              final firstName = (name != null && name.isNotEmpty)
                  ? name.split(' ').first
                  : null;
              final greetingText = firstName != null
                  ? '${_getGreeting()}, $firstName'
                  : _getGreeting();

              return Text(
                greetingText,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: layout.greetingFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer<MonetizationProvider>(
              builder: (context, monetization, child) {
                if (monetization.isAdSupported && !monetization.isPremium) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4.0),
                    child: TextButton.icon(
                      onPressed: () {
                        unawaited(
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PaywallScreen(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.workspace_premium,
                        color: appAccent,
                        size: 16,
                      ),
                      label: Text(
                        'Pro',
                        style: GoogleFonts.inter(
                          color: appAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: appAccent.withValues(alpha: 0.12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<AccessibilityProvider>(
              builder: (context, accessibility, child) {
                if (accessibility.isLargeTextEnabled) {
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.text_increase,
                      color: appAccent,
                      size: 20,
                    ),
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      unawaited(accessibility.toggleLargeText());
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Consumer<InboxProvider>(
              builder: (context, inbox, child) {
                const icon = Icon(
                  Icons.inbox_outlined,
                  color: Colors.white,
                  size: 22,
                );
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  icon: inbox.unreadCount > 0
                      ? Badge(
                          label: Text('${inbox.unreadCount}'),
                          child: icon,
                        )
                      : icon,
                  onPressed: () {
                    unawaited(
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InboxScreen(),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.settings,
                color: appTextMuted,
                size: 22,
              ),
              onPressed: () {
                unawaited(
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(AppLayout layout) {
    return SizedBox(
      height: layout.searchBarHeight,
      child: Consumer<LibraryProvider>(
        builder: (context, library, child) {
          return TextField(
            controller: _searchController,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search documents...',
              hintStyle: GoogleFonts.inter(color: appTextMuted, fontSize: 14),
              prefixIcon: const Icon(
                Icons.search,
                color: appTextMuted,
                size: 19,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 36,
              ),
              suffixIcon: library.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: appTextMuted,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        library.setSearchQuery('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: appSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => library.setSearchQuery(val),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPills(AppLayout layout) {
    return SizedBox(
      height: layout.chipHeight,
      child: Consumer<LibraryProvider>(
        builder: (context, library, child) {
          const defaultCategories = [
            'All',
            'Receipts',
            'Invoices',
            'IDs',
            'Taxes',
            'Notes',
            'Documents',
          ];
          final allCategories = [
            ...defaultCategories,
            ...library.sections.map((s) => s.name),
          ];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allCategories.length + 1,
            itemBuilder: (context, index) {
              if (index == allCategories.length) {
                return GestureDetector(
                  onTap: () async {
                    unawaited(HapticFeedback.selectionClick());
                    final auth = context.read<AuthProvider>();
                    final name = await _showInputDialog('New Section Name');
                    if (name != null && name.isNotEmpty) {
                      await library.addSection(name);
                      if (auth.isSignedIn) {
                        final json = await library.exportStructureToJson();
                        unawaited(
                          auth.syncService.uploadStructureJson(json),
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: appSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: appLine),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: appTextMuted,
                        size: 16,
                      ),
                    ),
                  ),
                );
              }

              final cat = allCategories[index];
              final isSelected = library.selectedCategory == cat;
              return GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  library.setCategory(cat);
                },
                child: Container(
                  margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? appAccent : appSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSubfoldersAndSectionHeader(AppLayout layout) {
    return Consumer<LibraryProvider>(
      builder: (context, library, child) {
        final isCategorySelected = library.selectedCategory != 'All';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCategorySelected) ...[
              SizedBox(
                height: layout.chipHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: library.currentSubfolders.length + 1,
                  itemBuilder: (context, index) {
                    if (index == library.currentSubfolders.length) {
                      return GestureDetector(
                        onTap: () async {
                          unawaited(HapticFeedback.selectionClick());
                          final auth = context.read<AuthProvider>();
                          final name =
                              await _showInputDialog('New Folder Name');
                          if (name != null && name.isNotEmpty) {
                            await library.addSubfolder(name);
                            if (auth.isSignedIn) {
                              final json =
                                  await library.exportStructureToJson();
                              unawaited(
                                auth.syncService.uploadStructureJson(json),
                              );
                            }
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: appLine),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.create_new_folder_outlined,
                                color: appTextMuted,
                                size: 15,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Add Folder',
                                style: GoogleFonts.inter(
                                  color: appTextMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final sub = library.currentSubfolders[index];
                    final isSelected = library.selectedSubfolder == sub.name;
                    return GestureDetector(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        library.setSubfolder(isSelected ? null : sub.name);
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: index == 0 ? 0 : 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? appAccent.withValues(alpha: 0.12)
                              : appPaper,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? appAccent : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.folder : Icons.folder_outlined,
                              color: isSelected ? appAccent : appTextMuted,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              sub.name,
                              style: GoogleFonts.inter(
                                color: isSelected ? appAccent : appBackground,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: layout.tightGap),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isCategorySelected
                        ? (library.selectedSubfolder != null
                            ? '${library.selectedCategory} / ${library.selectedSubfolder}'
                            : library.selectedCategory)
                        : 'Recent Scans',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: layout.sectionTitleFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isCategorySelected) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.document_scanner,
                          color: appAccent,
                          size: 19,
                        ),
                        onPressed: _startScan,
                        tooltip:
                            'Scan to ${library.selectedSubfolder ?? library.selectedCategory}',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.photo_library,
                          color: appAccent,
                          size: 19,
                        ),
                        onPressed: _uploadFromGallery,
                        tooltip:
                            'Upload to ${library.selectedSubfolder ?? library.selectedCategory}',
                      ),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 34,
                        minHeight: 34,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _viewMode == ViewMode.stack
                            ? Icons.view_agenda_rounded
                            : _viewMode == ViewMode.grid
                                ? Icons.grid_view_rounded
                                : Icons.view_list_rounded,
                        color: appTextMuted,
                        size: 20,
                      ),
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
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
                    if (library.documents.isNotEmpty)
                      TextButton(
                        onPressed: _toggleSelectionMode,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _isSelectionMode ? 'Cancel' : 'Select',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: appAccent,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentFeed(AppLayout layout, double listBottomPadding) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Consumer<LibraryProvider>(
        builder: (context, library, child) {
          if (library.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: appAccent),
            );
          }
          if (library.documents.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: listBottomPadding),
                child: Text(
                  'No documents yet.\nTap the scanner to digitize your first page.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: appTextMuted,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }
          if (_viewMode == ViewMode.grid) {
            return GridView.builder(
              padding: EdgeInsets.only(bottom: listBottomPadding),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: layout.gridColumns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: layout.gridAspectRatio,
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
                      unawaited(
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExportScreen(document: doc),
                          ),
                        ),
                      );
                    }
                  },
                  onRename: () {
                    if (_isSelectionMode) {
                      _toggleDocumentSelection(doc.id);
                    } else {
                      unawaited(_showRenameDialog(doc));
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
              padding: EdgeInsets.only(bottom: listBottomPadding),
              itemCount: library.documents.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: layout.cardSpacing),
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
                      unawaited(
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExportScreen(document: doc),
                          ),
                        ),
                      );
                    }
                  },
                  onRename: () {
                    if (_isSelectionMode) {
                      _toggleDocumentSelection(doc.id);
                    } else {
                      unawaited(_showRenameDialog(doc));
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
            bottomPadding: listBottomPadding,
            onSelect: _toggleDocumentSelection,
            onTap: (doc) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExportScreen(document: doc),
              ),
            ),
            onRename: _showRenameDialog,
            onDelete: (id) {
              final doc = library.findById(id);
              if (doc != null) {
                _handleSingleDelete(doc);
              }
            },
            onAutoName: _handleAutoName,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    final monetization = context.watch<MonetizationProvider>();
    final showAds = monetization.isAdSupported && !monetization.isPremium;
    final adHeight = showAds
        ? (_isBannerAdLoaded && _bannerAd != null
            ? _bannerAd!.size.height.toDouble()
            : 50.0)
        : 0.0;
    final bottomClearance =
        _isSelectionMode ? 80.0 : layout.floatingDockClearance + adHeight;

    return BeamWipeOverlay(
      child: Scaffold(
        backgroundColor: appBackground,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: layout.topGap),
                    _buildHeader(context, layout),
                    SizedBox(height: layout.tightGap),
                    _buildSearchBar(layout),
                    SizedBox(height: layout.tightGap),
                    _buildCategoryPills(layout),
                    SizedBox(height: layout.sectionGap),
                    _buildSubfoldersAndSectionHeader(layout),
                    SizedBox(height: layout.tightGap),
                    Expanded(
                      child: _buildDocumentFeed(
                        layout,
                        bottomClearance + layout.viewPadding.bottom,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isSelectionMode)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSlide(
                        duration: const Duration(milliseconds: 260),
                        offset:
                            _isUiVisible ? Offset.zero : const Offset(0, 1.5),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                appBackground.withValues(alpha: 0.0),
                                appBackground.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            layout.horizontalPadding,
                            12,
                            layout.horizontalPadding,
                            showAds ? 8 : layout.viewPadding.bottom + 12,
                          ),
                          child: ScanButton(
                            onPressed: _isScanning ? null : _startScan,
                          ),
                        ),
                      ),
                      if (showAds)
                        SafeArea(
                          top: false,
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: appTextMuted,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
            ],
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
      ),
    );
  }
}
