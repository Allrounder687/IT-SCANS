import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../core/theme.dart';

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
              _buildGoogleAccountSection(context, auth),
              const SizedBox(height: 32),
              if (auth.isSignedIn) _buildSyncSettingsSection(context, auth),
            ],
          );
        },
      ),
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
}
