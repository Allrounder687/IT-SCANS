import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'screens/home/home_screen.dart';
import 'providers/accessibility_provider.dart';

class ItScansApp extends StatelessWidget {
  const ItScansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IT SCANS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        final isLargeText = context.watch<AccessibilityProvider>().isLargeTextEnabled;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: isLargeText ? const TextScaler.linear(1.25) : const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
      home: const HomeScreen(),
    );
  }
}
