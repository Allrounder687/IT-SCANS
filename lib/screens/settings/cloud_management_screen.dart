import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/cloud_sync_service.dart';
import 'package:provider/provider.dart';

class CloudManagementScreen extends StatefulWidget {
  const CloudManagementScreen({super.key});

  @override
  State<CloudManagementScreen> createState() => _CloudManagementScreenState();
}

class _CloudManagementScreenState extends State<CloudManagementScreen> {
  List<CloudDocument> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFiles());
  }

  Future<void> _loadFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final files = await auth.syncService.fetchCloudHierarchy();
    if (!mounted) return;
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  Future<void> _deleteFile(String fileId) async {
    final auth = context.read<AuthProvider>();
    final success = await auth.syncService.deleteFile(fileId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File deleted from Google Drive',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      unawaited(_loadFiles());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete file',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (math.log(bytes) / math.log(1024))
        .floor()
        .clamp(0, suffixes.length - 1);
    final double size = bytes / math.pow(1024, i);
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

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
          'Manage Cloud Data',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: appAccent))
          : _files.isEmpty
              ? Center(
                  child: Text(
                    'No documents backed up yet.',
                    style: GoogleFonts.inter(color: appTextMuted, fontSize: 16),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: appLine),
                  itemBuilder: (context, index) {
                    final cloudDoc = _files[index];
                    final file = cloudDoc.file;
                    final size = int.tryParse(file.size ?? '0') ?? 0;

                    String subtitleText =
                        '${_formatBytes(size)} • ${file.createdTime?.toLocal().toString().split('.')[0] ?? 'Unknown date'}';
                    if (cloudDoc.category != 'Documents') {
                      subtitleText +=
                          '\nFolder: ${cloudDoc.category}${cloudDoc.subfolder != null ? ' / ${cloudDoc.subfolder}' : ''}';
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: appAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.picture_as_pdf, color: appAccent),
                      ),
                      title: Text(
                        file.name ?? 'Unknown Document',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        subtitleText,
                        style: GoogleFonts.inter(
                          color: appTextMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          unawaited(
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: appSurface,
                                title: Text(
                                  'Delete from Cloud?',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: Colors.white,
                                  ),
                                ),
                                content: Text(
                                  'This will remove the file from your Google Drive backup. It will not delete your local copy.',
                                  style: GoogleFonts.inter(color: appTextMuted),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.inter(
                                        color: appTextMuted,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      if (file.id != null) {
                                        unawaited(_deleteFile(file.id!));
                                      }
                                    },
                                    child: Text(
                                      'Delete',
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
