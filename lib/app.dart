import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'screens/home/home_screen.dart';
import 'providers/accessibility_provider.dart';

import 'widgets/biometric_wrapper.dart';

class ItScansApp extends StatelessWidget {
  const ItScansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IT SCANS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) {
        final accessibility = context.watch<AccessibilityProvider>();
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(accessibility.currentScale),
          ),
          child: child!,
        );
      },
      home: const BiometricWrapper(child: HomeScreen()),
    );
  }
}
