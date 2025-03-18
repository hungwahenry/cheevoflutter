//services/firebase/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'dart:math' as math;

class UserService {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  
  // Get total number of online users
  Stream<int> getOnlineUsersCount() {
    return _firestore
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .where('isBanned', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Find a random user for video chat (excluding the current user)
  Future<String?> findRandomUser(String currentUserId) async {
    try {
      // Update current user's matching status
      await _firestore.collection('users').doc(currentUserId).update({
        'isMatching': true,
        'lastMatchAttempt': FieldValue.serverTimestamp(),
      });
      
      // First, try to find users who have been waiting longer
      QuerySnapshot waitingUsersSnapshot = await _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .where('isMatching', isEqualTo: true)
          .where('isBanned', isEqualTo: false)
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .orderBy(FieldPath.documentId)
          .orderBy('lastMatchAttempt')
          .limit(5)
          .get();
      
      // If there are waiting users, select one randomly from the longest waiting
      if (waitingUsersSnapshot.docs.isNotEmpty) {
        // Prioritize matching with users who have been waiting longer
        // But still add some randomness to prevent always matching the same people
        final randomIndex = math.min(
          math.Random().nextInt(waitingUsersSnapshot.docs.length), 
          2
        );
        return waitingUsersSnapshot.docs[randomIndex].id;
      }
      
      // If no waiting users, find any online user
      QuerySnapshot onlineUsersSnapshot = await _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .where('isBanned', isEqualTo: false)
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .limit(10)
          .get();
      
      // If no users are available
      if (onlineUsersSnapshot.docs.isEmpty) {
        return null;
      }
      
      // Randomly select one of the available users
      final random = math.Random().nextInt(onlineUsersSnapshot.docs.length);
      return onlineUsersSnapshot.docs[random].id;
    } catch (e) {
      print('Error finding random user: $e');
      return null;
    }
  }
  
  // Update matching status
  Future<void> updateMatchingStatus(String userId, {required bool isMatching}) async {
    await _firestore.collection('users').doc(userId).update({
      'isMatching': isMatching,
      'lastMatchAttempt': isMatching ? FieldValue.serverTimestamp() : null,
    });
  }
  
  // Get users waiting for a match (for debugging and admin purposes)
  Future<int> getUsersWaitingCount() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('isOnline', isEqualTo: true)
          .where('isMatching', isEqualTo: true)
          .where('isBanned', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting users waiting count: $e');
      return 0;
    }
  }
  
  // Check if a specific user has been banned during an active session
  Future<bool> checkUserBanStatus(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['isBanned'] == true) {
        return true;
      }
      
      final banDoc = await _firestore.collection('bans').doc(userId).get();
      if (banDoc.exists) {
        final banData = banDoc.data();
        // Check if ban is permanent or still active
        if (banData?['isPermanent'] == true) {
          return true;
        }
        
        final expiresAt = banData?['expiresAt'] as Timestamp?;
        if (expiresAt != null && expiresAt.toDate().isAfter(DateTime.now())) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking user ban status: $e');
      return false;
    }
  }
  
  // Update user last active timestamp
  Future<void> updateUserActivity(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
  
  // Track user session metrics
  Future<void> trackSessionMetrics(String userId, {
    required int sessionDurationSeconds,
    required int callsCount,
    required int messagesCount,
  }) async {
    try {
      // Update user document with session metrics
      await _firestore.collection('users').doc(userId).update({
        'totalSessionTime': FieldValue.increment(sessionDurationSeconds),
        'totalCalls': FieldValue.increment(callsCount),
        'totalMessages': FieldValue.increment(messagesCount),
        'lastSessionEnd': FieldValue.serverTimestamp(),
      });
      
      // Add detailed session record
      await _firestore.collection('sessions').add({
        'userId': userId,
        'startTime': Timestamp.fromDate(
          DateTime.now().subtract(Duration(seconds: sessionDurationSeconds))
        ),
        'endTime': FieldValue.serverTimestamp(),
        'durationSeconds': sessionDurationSeconds,
        'callsCount': callsCount,
        'messagesCount': messagesCount,
      });
    } catch (e) {
      print('Error tracking session metrics: $e');
    }
  }
  
  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }
  
  // Stream of matched users (for active connections)
  Stream<QuerySnapshot> getActiveConnections(String userId) {
    return _firestore
        .collection('rooms')
        .where('participants', arrayContains: userId)
        .where('status', whereIn: ['created', 'joined'])
        .snapshots();
  }
}