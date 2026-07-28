import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/library_provider.dart';
import 'providers/monetization_provider.dart';
import 'providers/auth_provider.dart';
import 'services/storage_service.dart';
import 'services/cloud_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final storageService = StorageService();
  final cloudSyncService = CloudSyncService();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider(storageService)),
        ChangeNotifierProvider(create: (_) => MonetizationProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(cloudSyncService, prefs)),
      ],
      child: const ItScansApp(),
    ),
  );
}
