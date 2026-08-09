import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
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
      body: Consumer2<AuthProvider, LibraryProvider>(
        builder: (context, auth, library, child) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            children: [
              _buildStorageCard(context, library),
              const SizedBox(height: 16),
              _buildAppearanceCard(context),
              const SizedBox(height: 16),
              _buildAccountCard(context, auth),
              const SizedBox(height: 16),
              const _SecurityCard(),
              const SizedBox(height: 32),
              _buildAboutSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      color: appSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: appLine)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context, LibraryProvider library) {
    return _buildCard(
      children: [
        ListTile(
          leading: const CircleAvatar(backgroundColor: appBackground, child: Icon(Icons.folder, color: appAccent)),
          title: Text('Save Location', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
          subtitle: Text(library.customSaveLocation ?? 'Default App Storage', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
          trailing: TextButton(
            onPressed: () async {
              String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
              if (selectedDirectory != null) {
                library.setCustomSaveLocation(selectedDirectory);
              }
            },
            child: Text('Change', style: GoogleFonts.inter(color: appAccent, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibility, child) {
        return _buildCard(
          children: [
            SwitchListTile(
              secondary: const CircleAvatar(backgroundColor: appBackground, child: Icon(Icons.text_fields, color: appAccent)),
              title: Text('Large Text', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: Text('Increase text size everywhere', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
              value: accessibility.isLargeTextEnabled,
              onChanged: (val) => accessibility.setLargeText(val),
              activeTrackColor: appAccent.withValues(alpha: 0.5),
              activeColor: appAccent,
            ),
            if (accessibility.isLargeTextEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
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
              ),
          ],
        );
      },
    );
  }

  Widget _buildAccountCard(BuildContext context, AuthProvider auth) {
    return _buildCard(
      children: [
        if (auth.isLoading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: appAccent)))
        else if (auth.isSignedIn) ...[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: appBackground,
              backgroundImage: auth.currentUser?.photoUrl != null ? NetworkImage(auth.currentUser!.photoUrl!) : null,
              child: auth.currentUser?.photoUrl == null ? const Icon(Icons.person, color: appAccent) : null,
            ),
            title: Text(auth.currentUser?.displayName ?? 'Connected', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
            subtitle: Text(auth.currentUser?.email ?? '', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
            trailing: IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: auth.signOut,
            ),
          ),
          const Divider(color: appLine),
          SwitchListTile(
            secondary: const Icon(Icons.sync, color: appAccent),
            title: Text('Auto-Sync to Drive', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
            value: auth.autoSync,
            onChanged: auth.setAutoSync,
            activeTrackColor: appAccent.withValues(alpha: 0.5),
            activeColor: appAccent,
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download, color: appAccent),
            title: Text('Restore Backup', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
            onTap: () async {
              final library = context.read<LibraryProvider>();
              final count = await auth.restoreFromCloud(library);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(count > 0 ? 'Restored $count documents' : 'No new documents found', style: GoogleFonts.inter()),
                    backgroundColor: count > 0 ? Colors.green : Colors.grey[800],
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_shared, color: appAccent),
            title: Text('Manage Cloud Data', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
            trailing: const Icon(Icons.chevron_right, color: appTextMuted),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudManagementScreen()));
            },
          ),
        ] else ...[
          ListTile(
            leading: const CircleAvatar(backgroundColor: appBackground, child: Icon(Icons.login, color: appAccent)),
            title: Text('Google Drive Backup', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
            subtitle: Text('Tap to sign in and backup scans', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
            onTap: auth.signIn,
          ),
        ],
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        Text('IT SCANS', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Made for family by Syed Faisal Majeed', style: GoogleFonts.inter(fontSize: 14, color: appTextMuted), textAlign: TextAlign.center),
      ],
    );
  }
}

class _SecurityCard extends StatefulWidget {
  const _SecurityCard();

  @override
  State<_SecurityCard> createState() => _SecurityCardState();
}

class _SecurityCardState extends State<_SecurityCard> {
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
            SnackBar(content: Text('Biometrics not supported on this device', style: GoogleFonts.inter()), backgroundColor: Colors.red),
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
    return Card(
      color: appSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: appLine)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SwitchListTile(
          secondary: const CircleAvatar(backgroundColor: appBackground, child: Icon(Icons.fingerprint, color: appAccent)),
          title: Text('App Lock', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
          subtitle: Text('Require biometrics to open', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
          value: _requireBiometrics,
          onChanged: _toggleBiometrics,
          activeTrackColor: appAccent.withValues(alpha: 0.5),
          activeColor: appAccent,
        ),
      ),
    );
  }
}
