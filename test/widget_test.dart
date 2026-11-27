import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itscans/app.dart';
import 'package:itscans/models/app_user.dart';
import 'package:itscans/models/category_model.dart';
import 'package:itscans/models/scan_document.dart';
import 'package:itscans/providers/accessibility_provider.dart';
import 'package:itscans/providers/auth_provider.dart';
import 'package:itscans/providers/inbox_provider.dart';
import 'package:itscans/providers/library_provider.dart';
import 'package:itscans/providers/monetization_provider.dart';
import 'package:itscans/services/cloud_sync_service.dart';
import 'package:itscans/services/monetization_service.dart';
import 'package:itscans/services/storage_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestStorageService extends StorageService {
  @override
  Future<List<ScanDocument>> getScanDocuments() async => [];

  @override
  Future<List<AppSection>> getSections() async => [];

  @override
  Future<List<AppSubfolder>> getAllSubfolders() async => [];
}

class _TestCloudSyncService extends CloudSyncService {
  @override
  Future<AppUser?> signInSilently() async => null;
}

class _TestMonetizationService extends MonetizationService {
  @override
  Future<int> getScanCount() async => 0;

  @override
  Future<bool> hasUnlockedPremium() async => false;

  @override
  Future<bool> isAdSupported() async => false;

  @override
  Future<int> getPurchasedScans() async => 0;
}

Future<void> _pumpTestApp(WidgetTester tester, Size screenSize) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = screenSize;
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(_TestStorageService()),
        ),
        ChangeNotifierProvider(
          create: (_) => MonetizationProvider(_TestMonetizationService()),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(_TestCloudSyncService(), prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => AccessibilityProvider(prefs),
        ),
        ChangeNotifierProxyProvider<LibraryProvider, InboxProvider>(
          create: (context) => InboxProvider(context.read<LibraryProvider>()),
          update: (context, library, previous) =>
              previous ?? InboxProvider(library),
        ),
      ],
      child: const ItScansApp(),
    ),
  );

  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots cleanly on compact phone (320x568)', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    await _pumpTestApp(tester, const Size(320, 568));

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Recent Scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('App boots cleanly on tablet (800x1280)', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    await _pumpTestApp(tester, const Size(800, 1280));

    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Recent Scans'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
