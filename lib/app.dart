import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home/home_screen.dart';

class ItScansApp extends StatelessWidget {
  const ItScansApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IT SCANS',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
