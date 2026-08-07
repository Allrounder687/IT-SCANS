import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

class BiometricWrapper extends StatefulWidget {
  final Widget child;

  const BiometricWrapper({super.key, required this.child});

  @override
  State<BiometricWrapper> createState() => _BiometricWrapperState();
}

class _BiometricWrapperState extends State<BiometricWrapper> with WidgetsBindingObserver {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _requiresAuth = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkRequirementsAndAuthenticate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_requiresAuth && !_isAuthenticated && !_isAuthenticating) {
        _authenticate();
      }
    } else if (state == AppLifecycleState.paused) {
      if (_requiresAuth) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }
  }

  Future<void> _checkRequirementsAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final requiresAuth = prefs.getBool('require_biometrics') ?? false;
    setState(() {
      _requiresAuth = requiresAuth;
    });

    if (requiresAuth) {
      await _authenticate();
    } else {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    bool authenticated = false;
    try {
      final isAvailable = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!isAvailable) {
        authenticated = true; // Fallback if device doesn't support it
      } else {
        authenticated = await _auth.authenticate(
          localizedReason: 'Unlock IT SCANS to view your documents',
          biometricOnly: false,
          persistAcrossBackgrounding: true,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('Error authenticating: $e');
      authenticated = false;
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
        _isAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_requiresAuth || _isAuthenticated) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: appBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: appAccent),
            const SizedBox(height: 24),
            Text(
              'App Locked',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock to access your documents',
              style: GoogleFonts.inter(
                color: appTextMuted,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _authenticate,
              style: ElevatedButton.styleFrom(
                backgroundColor: appAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Unlock Now',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
