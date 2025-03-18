//services/firebase/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseService().auth;
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;
      
      if (user != null) {
        // Check if user is banned before creating/updating user document
        final isBanned = await checkIfUserIsBanned(user.uid);
        
        if (isBanned) {
          // If banned, sign out and return null
          await _auth.signOut();
          return null;
        }
        
        // Get device info for ban enforcement
        final deviceInfo = await _getDeviceInfo();
        
        // Create or update user document
        await _firestore.collection('users').doc(user.uid).set({
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'isOnline': true,
          'isMatching': false,
          'deviceInfo': deviceInfo,
          'isBanned': false,
          'reportCount': 0,
        }, SetOptions(merge: true));
      }
      
      return user;
    } catch (e) {
      print('Error signing in anonymously: $e');
      return null;
    }
  }
  
  // Get detailed device info for ban enforcement
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return {
          'platform': 'android',
          'id': androidInfo.id,
          'brand': androidInfo.brand,
          'model': androidInfo.model,
          'androidVersion': androidInfo.version.release,
          'sdkVersion': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
          'fingerprint': androidInfo.fingerprint,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return {
          'platform': 'ios',
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'model': iosInfo.model,
          'localizedModel': iosInfo.localizedModel,
          'identifierForVendor': iosInfo.identifierForVendor,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
        };
      } else {
        // Web or other platforms
        return {
          'platform': Platform.operatingSystem,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
      return {
        'platform': 'unknown',
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }
  
  // Check if a user is banned
  Future<bool> checkIfUserIsBanned(String userId) async {
    try {
      // Check direct ban on user ID
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?['isBanned'] == true) {
        return true;
      }
      
      // Check bans collection for this user
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
        
        // Check for device ban (device fingerprint match)
        final deviceInfo = await _getDeviceInfo();
        final deviceBansQuery = await _firestore
            .collection('deviceBans')
            .where('deviceFingerprint', isEqualTo: 
                Platform.isAndroid ? deviceInfo['fingerprint'] : 
                deviceInfo['identifierForVendor'])
            .get();
        
        if (deviceBansQuery.docs.isNotEmpty) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error checking if user is banned: $e');
      return false; // Default to not banned if there's an error
    }
  }
  
  // Update user status
  Future<void> updateUserStatus({required bool isOnline}) async {
    String? userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Sign out
  Future<void> signOut() async {
    // Update user status before signing out
    await updateUserStatus(isOnline: false);
    await _auth.signOut();
  }
  
  // Get current user ban status
  Stream<bool> getCurrentUserBanStatus() {
    String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(false);
    }
    
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['isBanned'] == true);
  }
  
  // Check if ban has expired and update status
  Future<void> checkAndUpdateBanStatus(String userId) async {
    final banDoc = await _firestore.collection('bans').doc(userId).get();
    
    if (banDoc.exists) {
      final banData = banDoc.data();
      final expiresAt = banData?['expiresAt'] as Timestamp?;
      
      // If ban has expired, update user status
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now()) && 
          banData?['isPermanent'] != true) {
        await _firestore.collection('users').doc(userId).update({
          'isBanned': false,
        });
        
        // Add record to ban history
        await _firestore.collection('banHistory').add({
          'userId': userId,
          'banId': banDoc.id,
          'banStart': banData?['createdAt'],
          'banEnd': FieldValue.serverTimestamp(),
          'reason': banData?['reason'],
          'wasExpired': true,
        });
        
        // Delete the active ban
        await _firestore.collection('bans').doc(userId).delete();
      }
    }
  }
}