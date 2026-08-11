import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'cloud_sync_service.dart';

class FirebaseShareService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final CloudSyncService _syncService = CloudSyncService();

  bool get _isFirebaseInitialized => Firebase.apps.isNotEmpty;

  /// Uploads a PDF to the user's Google Drive, gets a public link, and creates a notification document in the recipient's inbox.
  Future<void> shareDocument(String pdfPath, String originalName, String recipientEmail) async {
    if (!_isFirebaseInitialized) {
      throw Exception('Firebase is not initialized.');
    }
    
    final firebaseUser = _auth.currentUser;
    final syncUser = _syncService.currentUser;
    final userEmail = firebaseUser?.email ?? syncUser?.email;
    
    if (userEmail == null) {
      throw Exception('Must be logged in to share.');
    }

    final file = File(pdfPath);
    if (!await file.exists()) {
      throw Exception('File does not exist.');
    }

    // 1. Upload to Google Drive and get public link
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final downloadUrl = await _syncService.uploadAndGetPublicLink(pdfPath, '${originalName}_$uniqueId.pdf');
    
    if (downloadUrl == null) {
      throw Exception('Failed to upload to Google Drive. Check your connection or permissions.');
    }

    // 2. Create Inbox Document in Firestore
    try {
      final recipientEmailLower = recipientEmail.toLowerCase().trim();
      await _firestore
          .collection('users')
          .doc(recipientEmailLower)
          .collection('inbox')
          .doc(uniqueId)
          .set({
        'senderEmail': userEmail,
        'fileName': originalName,
        'downloadUrl': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'fileSize': await file.length(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('Firestore write failed: $e');
      throw Exception('Cloud Database Error: $e');
    }
  }

  /// Returns a real-time stream of documents shared with the current user.
  Stream<List<Map<String, dynamic>>> getInboxStream() {
    if (!_isFirebaseInitialized) return const Stream.empty();

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return const Stream.empty();
    }

    final myEmail = user.email!.toLowerCase().trim();
    return _firestore
        .collection('users')
        .doc(myEmail)
        .collection('inbox')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Marks an inbox message as read.
  Future<void> markAsRead(String messageId) async {
    if (!_isFirebaseInitialized) return;

    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      final myEmail = user.email!.toLowerCase().trim();
      await _firestore
          .collection('users')
          .doc(myEmail)
          .collection('inbox')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Deletes an inbox message (does not delete the underlying storage file to prevent affecting others if shared multiple times).
  Future<void> deleteMessage(String messageId) async {
    if (!_isFirebaseInitialized) return;

    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      final myEmail = user.email!.toLowerCase().trim();
      await _firestore
          .collection('users')
          .doc(myEmail)
          .collection('inbox')
          .doc(messageId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }
}
