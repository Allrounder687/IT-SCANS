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
  int _delaySeconds = 0;
  DateTime? _pausedAt;

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
      _checkRequirementsAndAuthenticate();
    } else if (state == AppLifecycleState.paused) {
      if (_requiresAuth && !_isAuthenticating) {
        _pausedAt = DateTime.now();
        if (_delaySeconds == 0) {
          setState(() {
            _isAuthenticated = false;
          });
        }
      }
    }
  }

  Future<void> _checkRequirementsAndAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final requiresAuth = prefs.getBool('require_biometrics') ?? false;
    final delaySeconds = prefs.getInt('autolock_delay_seconds') ?? 0;
    
    if (mounted) {
      setState(() {
        _requiresAuth = requiresAuth;
        _delaySeconds = delaySeconds;
      });
    }

    if (requiresAuth) {
      if (_pausedAt != null && delaySeconds > 0) {
        final elapsed = DateTime.now().difference(_pausedAt!).inSeconds;
        _pausedAt = null;
        if (elapsed < delaySeconds) {
          return; // Do not lock
        } else {
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
            });
          }
        }
      }
      _pausedAt = null;

      if (!_isAuthenticated && !_isAuthenticating) {
        await _authenticate();
      }
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
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
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Always render the child to preserve its state and ongoing tasks (e.g. document scanning)
        widget.child,

        // Show the lock screen as an overlay when auth is required
        if (_requiresAuth && !_isAuthenticated)
          Positioned.fill(
            child: Scaffold(
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
            ),
          ),
      ],
    );
  }
}
