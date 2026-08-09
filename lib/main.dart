import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'providers/library_provider.dart';
import 'providers/monetization_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/accessibility_provider.dart';
import 'providers/inbox_provider.dart';
import 'services/storage_service.dart';
import 'services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  /*
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  */

  final storageService = StorageService();
  final cloudSyncService = CloudSyncService();
  final prefs = await SharedPreferences.getInstance();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF121214), // appBackground
    ),
  );
  
  if (Platform.isAndroid || Platform.isIOS) {
    await MobileAds.instance.initialize();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(storageService)),
        ChangeNotifierProvider(create: (_) => MonetizationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(cloudSyncService, prefs)),
        ChangeNotifierProvider(create: (_) => AccessibilityProvider(prefs)),
        ChangeNotifierProxyProvider<LibraryProvider, InboxProvider>(
          create: (context) => InboxProvider(context.read<LibraryProvider>()),
          update: (context, library, previous) => previous ?? InboxProvider(library),
        ),
      ],
      child: const ItScansApp(),
    ),
  );
}
