//services/firebase/report_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  
  // Submit a report
  Future<void> submitReport({
    required String reportedUserId,
    required String reason,
    String? details,
    List<String>? mediaUrls,
  }) async {
    String? reporterId = FirebaseService().currentUserId;
    
    if (reporterId == null) {
      throw Exception('User not signed in');
    }
    
    // Create the report
    final reportRef = await _firestore.collection('reports').add({
      'reportedUserId': reportedUserId,
      'reporterId': reporterId,
      'reason': reason,
      'details': details,
      'mediaUrls': mediaUrls ?? [],
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'adminReviewed': false,
      'adminNotes': null,
      'actionTaken': null,
    });
    
    // Update user document to increment their report count
    await _firestore.collection('users').doc(reportedUserId).set({
      'reportCount': FieldValue.increment(1),
      'lastReportTimestamp': FieldValue.serverTimestamp(),
      'lastReportReason': reason,
    }, SetOptions(merge: true));
    
    // Check if multiple reports have been filed against this user recently
    final recentReports = await _firestore
        .collection('reports')
        .where('reportedUserId', isEqualTo: reportedUserId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 1))
        ))
        .get();
    
    // Flag for admin review if multiple recent reports
    if (recentReports.docs.length >= 3) {
      await _firestore.collection('users').doc(reportedUserId).update({
        'requiresReview': true,
        'reviewReason': 'Multiple reports within 24 hours',
        'reviewPriority': 'high',
      });
      
      // Auto-ban users with excessive reports if needed
      if (recentReports.docs.length >= 10) {
        await _autoTempBanUser(reportedUserId, 'Excessive reports in short timeframe');
      }
    }
    
    // Add a reference to this report in the ban candidates collection for admin review
    await _firestore.collection('banCandidates').doc(reportedUserId).set({
      'latestReportId': reportRef.id,
      'reportCount': FieldValue.increment(1),
      'lastReportTimestamp': FieldValue.serverTimestamp(),
      'reviewed': false,
      'reasons': FieldValue.arrayUnion([reason]),
    }, SetOptions(merge: true));
  }
  
  // Automatically temp ban a user for severe violations
  Future<void> _autoTempBanUser(String userId, String reason) async {
    // Get user data to include in ban record
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    
    // Create ban record
    await _firestore.collection('bans').doc(userId).set({
      'userId': userId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
      'isPermanent': false,
      'issuedBy': 'system',
      'deviceInfo': userData['deviceInfo'],
      'userInfo': {
        'reportCount': userData['reportCount'] ?? 0,
        'createdAt': userData['createdAt'],
      }
    });
    
    // Update user document
    await _firestore.collection('users').doc(userId).update({
      'isBanned': true,
      'banReason': reason,
      'bannedAt': FieldValue.serverTimestamp(),
      'banExpiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 3))),
    });
  }
  
  // Get the status of a report
  Future<Map<String, dynamic>?> getReportStatus(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      return doc.data();
    } catch (e) {
      print('Error getting report status: $e');
      return null;
    }
  }
  
  // Get user's report history (their reports about others)
  Future<List<Map<String, dynamic>>> getUserReportHistory(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('reports')
          .where('reporterId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting user report history: $e');
      return [];
    }
  }
  
  // Get reports against a user
  Future<List<Map<String, dynamic>>> getReportsAgainstUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('reports')
          .where('reportedUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting reports against user: $e');
      return [];
    }
  }
  
  // Track when a user is blocked (for internal metrics)
  Future<void> trackUserBlocked(String blockedUserId, String reason) async {
    String? currentUserId = FirebaseService().currentUserId;
    if (currentUserId == null) return;
    
    await _firestore.collection('blocks').add({
      'blockerId': currentUserId,
      'blockedId': blockedUserId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // Update user block lists
    await _firestore.collection('users').doc(currentUserId).set({
      'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
    }, SetOptions(merge: true));
  }
}