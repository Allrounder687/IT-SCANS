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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and shows the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

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

    // Let the 600ms BeamWipeOverlay animation and initial async loads settle.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Scan document'), findsOneWidget);
    expect(find.text('Recent Scans'), findsOneWidget);
  });
}
