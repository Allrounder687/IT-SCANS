import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../core/theme.dart';
import 'cloud_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildAccessibilitySection(context),
              const SizedBox(height: 32),
              _buildGoogleAccountSection(context, auth),
              const SizedBox(height: 32),
              if (auth.isSignedIn) _buildSyncSettingsSection(context, auth),
              const SizedBox(height: 32),
              const _SecuritySection(),
              const SizedBox(height: 32),
              _buildAboutSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessibilitySection(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibility, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: appLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.accessibility_new, color: appAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Accessibility',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Large Text',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Increase text size and show quick-toggle button on Home Screen',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: appTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: accessibility.isLargeTextEnabled,
                    onChanged: (val) => accessibility.setLargeText(val),
                    activeColor: appAccent,
                    inactiveTrackColor: appBackground,
                  ),
                ],
              ),
              if (accessibility.isLargeTextEnabled) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('A', style: GoogleFonts.inter(color: appTextMuted, fontSize: 14)),
                    Expanded(
                      child: Slider(
                        value: accessibility.textScaleFactor,
                        min: 1.1,
                        max: 1.75,
                        divisions: 6,
                        activeColor: appAccent,
                        inactiveColor: appBackground,
                        onChanged: (val) => accessibility.setTextScaleFactor(val),
                      ),
                    ),
                    Text('A', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoogleAccountSection(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_circle, color: appAccent, size: 28),
              const SizedBox(width: 12),
              Text(
                'Google Drive Backup',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'This app does not send any data to external servers. It only uses official Google servers to store your data directly on your personal Drive, putting you in complete control.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: appTextMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (auth.isLoading)
            const Center(child: CircularProgressIndicator(color: appAccent))
          else if (auth.isSignedIn) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: auth.currentUser?.photoUrl != null
                      ? NetworkImage(auth.currentUser!.photoUrl!)
                      : null,
                  backgroundColor: appAccent,
                  child: auth.currentUser?.photoUrl == null
                      ? const Icon(Icons.person, color: Colors.black)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.currentUser?.displayName ?? 'Connected',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        auth.currentUser?.email ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: appTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: auth.signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Sign Out',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CloudManagementScreen()),
                  );
                },
                icon: const Icon(Icons.folder_shared, color: Colors.white),
                label: Text(
                  'Manage Cloud Data',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: appLine),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: auth.signIn,
                icon: const Icon(Icons.login, color: Colors.black),
                label: Text(
                  'Sign in with Google',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSyncSettingsSection(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appLine),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-Sync',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Automatically backup new scans to Drive',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: appTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: auth.autoSync,
                onChanged: auth.setAutoSync,
                activeColor: appAccent,
                inactiveTrackColor: appBackground,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: appLine),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: auth.isLoading
                  ? null
                  : () async {
                      final library = context.read<LibraryProvider>();
                      final count = await auth.restoreFromCloud(library);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              count > 0 ? 'Restored $count documents!' : 'No new documents to restore.',
                              style: GoogleFonts.inter(),
                            ),
                            backgroundColor: count > 0 ? Colors.green : Colors.grey[800],
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
              icon: auth.isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: appAccent, strokeWidth: 2))
                  : const Icon(Icons.cloud_download, color: appAccent),
              label: Text(
                auth.isLoading ? 'Restoring...' : 'Restore Backup from Drive',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: appLine),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Text(
            'IT SCANS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made for family by Syed Faisal Majeed',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: appTextMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SecuritySection extends StatefulWidget {
  const _SecuritySection();

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  bool _requireBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _requireBiometrics = prefs.getBool('require_biometrics') ?? false;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      final localAuth = LocalAuthentication();
      final isAvailable = await localAuth.canCheckBiometrics || await localAuth.isDeviceSupported();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometrics not supported on this device', style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('require_biometrics', value);
    setState(() {
      _requireBiometrics = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: appAccent, size: 28),
              const SizedBox(width: 12),
              Text(
                'Security',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Privacy Lock',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Require Face ID / Touch ID to open the app',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: appTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _requireBiometrics,
                onChanged: _toggleBiometrics,
                activeColor: appAccent,
                inactiveTrackColor: appBackground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
