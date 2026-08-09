import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/accessibility_provider.dart';
import '../../services/update_service.dart';
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
    return const _AboutSection();
  }
}

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '';
  bool _isChecking = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking || _isDownloading) return;
    
    setState(() {
      _isChecking = true;
    });

    final updateService = UpdateService();
    final info = await updateService.checkForUpdate();
    
    if (!mounted) return;
    
    if (info != null && info.isUpdateAvailable) {
      setState(() {
        _isChecking = false;
        _isDownloading = true;
      });
      
      final path = await updateService.downloadUpdate(info.downloadUrl);
      
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
      });
      
      if (path != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: appSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: appAccent)),
            title: Text('Yay! Update Ready! 🚀', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'A new version (${info.latestVersion}) is downloaded and ready to install. Update now to get the latest magic for the family!',
              style: GoogleFonts.inter(color: appTextMuted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Later', style: GoogleFonts.inter(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: appAccent, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(context);
                  updateService.installUpdate(path);
                },
                child: Text('Install Magic ✨', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download update', style: GoogleFonts.inter()), backgroundColor: Colors.red),
        );
      }
    } else {
      setState(() {
        _isChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are on the latest version! 🎉', style: GoogleFonts.inter(color: Colors.black)),
          backgroundColor: appAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('IT SCANS', style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        if (_version.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('Version $_version', style: GoogleFonts.inter(fontSize: 12, color: appAccent)),
        ],
        const SizedBox(height: 4),
        Text('Made for family by Syed Faisal Majeed', style: GoogleFonts.inter(fontSize: 14, color: appTextMuted), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        if (_isDownloading)
          Column(
            children: [
              const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: appAccent, strokeWidth: 2),
              ),
              const SizedBox(height: 8),
              Text('Downloading magic...', style: GoogleFonts.inter(fontSize: 12, color: appTextMuted)),
            ],
          )
        else
          TextButton.icon(
            onPressed: _isChecking ? null : _checkForUpdates,
            icon: _isChecking 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: appAccent, strokeWidth: 2))
              : const Icon(Icons.system_update, color: appAccent, size: 18),
            label: Text(_isChecking ? 'Checking...' : 'Check for Updates', style: GoogleFonts.inter(color: appAccent)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: appAccent.withValues(alpha: 0.3)),
              ),
            ),
          ),
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
  int _delaySeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _requireBiometrics = prefs.getBool('require_biometrics') ?? false;
      _delaySeconds = prefs.getInt('autolock_delay_seconds') ?? 0;
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

  Future<void> _setDelay(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autolock_delay_seconds', seconds);
    setState(() {
      _delaySeconds = seconds;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              secondary: const CircleAvatar(backgroundColor: appBackground, child: Icon(Icons.fingerprint, color: appAccent)),
              title: Text('App Lock', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: Text('Require biometrics to open', style: GoogleFonts.inter(color: appTextMuted, fontSize: 13)),
              value: _requireBiometrics,
              onChanged: _toggleBiometrics,
              activeTrackColor: appAccent.withValues(alpha: 0.5),
              activeColor: appAccent,
            ),
            if (_requireBiometrics) ...[
              const Divider(color: appLine, height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Require lock after:', style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? appAccent : appBackground),
                        foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white),
                        side: const WidgetStatePropertyAll(BorderSide(color: appLine)),
                      ),
                      segments: const [
                        ButtonSegment<int>(value: 0, label: Text('Immediately')),
                        ButtonSegment<int>(value: 60, label: Text('1 Min')),
                        ButtonSegment<int>(value: 300, label: Text('5 Min')),
                      ],
                      selected: {_delaySeconds},
                      onSelectionChanged: (Set<int> newSelection) {
                        _setDelay(newSelection.first);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
