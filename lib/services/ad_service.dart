//services/ad_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';

class AdService {
  final FirebaseFirestore _firestore = FirebaseService().firestore;
  
  // Cache ads to reduce Firestore reads
  List<Map<String, dynamic>> _cachedAds = [];
  DateTime _lastCacheUpdate = DateTime(2000);
  
  // Track ad impressions and clicks for analytics
  final Map<String, int> _impressionCounts = {};
  
  // Initialize the ad service
  Future<void> initialize() async {
    await _refreshAdCache();
  }
  
  // Refresh the ad cache
  Future<void> _refreshAdCache() async {
    try {
      final now = DateTime.now();
      
      // Only refresh cache if it's older than 5 minutes
      if (now.difference(_lastCacheUpdate).inMinutes < 5 && _cachedAds.isNotEmpty) {
        return;
      }
      
      final adsSnapshot = await _firestore
          .collection('ads')
          .where('active', isEqualTo: true)
          .get();
      
      _cachedAds = adsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'] ?? 'image',
          'title': data['title'] ?? '',
          'description': data['description'] ?? '',
          'imageUrl': data['imageUrl'] ?? '',
          'videoUrl': data['videoUrl'] ?? '',
          'ctaText': data['ctaText'] ?? 'Learn More',
          'ctaUrl': data['ctaUrl'] ?? '',
          'duration': data['duration'] ?? 5,
          'canSkip': data['canSkip'] ?? true,
          'priority': data['priority'] ?? 1,
          'campaignId': data['campaignId'],
          'startDate': data['startDate'],
          'endDate': data['endDate'],
        };
      }).toList();
      
      // Filter out expired ads
      final currentDate = Timestamp.now();
      _cachedAds = _cachedAds.where((ad) {
        final endDate = ad['endDate'] as Timestamp?;
        return endDate == null || endDate.compareTo(currentDate) > 0;
      }).toList();
      
      _lastCacheUpdate = now;
    } catch (e) {
      print('Error refreshing ad cache: $e');
    }
  }
  
  // Determine if an ad should be shown
  Future<bool> shouldShowAd() async {
    // Refresh cache if needed
    await _refreshAdCache();
    
    if (_cachedAds.isEmpty) {
      return false;
    }
    
    // Check frequency - show ads based on session activity
    String? userId = FirebaseService().currentUserId;
    if (userId != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data();
        
        // Check if user has premium status
        if (userData != null && userData['isPremium'] == true) {
          return false; // Premium users don't see ads
        }
        
        // Check ad frequency based on user activity
        final sessionCount = userData?['sessionCount'] ?? 0;
        
        // New users see fewer ads
        if (sessionCount < 3) {
          return math.Random().nextDouble() < 0.1; // 10% chance
        }
        
        // Regular users see more ads
        return math.Random().nextDouble() < 0.3; // 30% chance
      } catch (e) {
        print('Error checking user status for ads: $e');
      }
    }
    
    // Default ad frequency
    return math.Random().nextDouble() < 0.3;
  }
  
  // Get a random ad to display
  Future<Map<String, dynamic>> getRandomAd() async {
    // Refresh cache if needed
    await _refreshAdCache();
    
    if (_cachedAds.isEmpty) {
      // Return default ad data if no ads available
      return {
        'id': 'default',
        'type': 'image',
        'title': 'Cheevo Premium',
        'description': 'Upgrade to Cheevo Premium for an ad-free experience!',
        'imageUrl': 'assets/images/premium_ad.png',
        'ctaText': 'Upgrade Now',
        'ctaUrl': 'https://cheevo.app/premium',
        'duration': 5,
        'canSkip': true,
        'priority': 1,
      };
    }
    
    // Sort by priority (higher priority = more likely to be shown)
    _cachedAds.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    
    // Select ad with weighted probability based on priority
    final totalPriority = _cachedAds.fold<int>(0, (sum, ad) => sum + (ad['priority'] as int));
    final random = math.Random().nextInt(totalPriority);
    
    int runningSum = 0;
    for (final ad in _cachedAds) {
      runningSum += ad['priority'] as int;
      if (random < runningSum) {
        return ad;
      }
    }
    
    // Fallback to first ad
    return _cachedAds.first;
  }
  
  // Track ad impression
  Future<void> trackAdImpression(String adId) async {
    try {
      // Update local count
      _impressionCounts[adId] = (_impressionCounts[adId] ?? 0) + 1;
      
      // Only update Firestore occasionally to reduce writes
      if (_impressionCounts[adId]! % 5 == 0) {
        await _firestore.collection('adStats').add({
          'adId': adId,
          'event': 'impression',
          'count': 5,
          'timestamp': FieldValue.serverTimestamp(),
          'userId': FirebaseService().currentUserId,
        });
        
        // Also update the ad document itself
        await _firestore.collection('ads').doc(adId).update({
          'impressions': FieldValue.increment(5),
        });
      }
    } catch (e) {
      print('Error tracking ad impression: $e');
    }
  }
  
  // Track ad click
  Future<void> trackAdClick(String adId) async {
    try {
      await _firestore.collection('adStats').add({
        'adId': adId,
        'event': 'click',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseService().currentUserId,
      });
      
      // Update the ad document
      await _firestore.collection('ads').doc(adId).update({
        'clicks': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking ad click: $e');
    }
  }
  
  // Track ad skip
  Future<void> trackAdSkip(String adId, int secondsWatched) async {
    try {
      await _firestore.collection('adStats').add({
        'adId': adId,
        'event': 'skip',
        'secondsWatched': secondsWatched,
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseService().currentUserId,
      });
    } catch (e) {
      print('Error tracking ad skip: $e');
    }
  }
  
  // Track ad completion
  Future<void> trackAdCompletion(String adId) async {
    try {
      await _firestore.collection('adStats').add({
        'adId': adId,
        'event': 'completion',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': FirebaseService().currentUserId,
      });
      
      // Update the ad document
      await _firestore.collection('ads').doc(adId).update({
        'completions': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error tracking ad completion: $e');
    }
  }
}