// services/firebase/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  // Use getters instead of direct instance variables
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  
  // Check if user is signed in
  bool get isUserSignedIn => auth.currentUser != null;
  
  // Get current user ID
  String? get currentUserId => auth.currentUser?.uid;
  
  // Get a timestamp for the current time
  FieldValue get timestamp => FieldValue.serverTimestamp();
  
  // Collection references for cleaner code
  CollectionReference get usersRef => firestore.collection('users');
  CollectionReference get roomsRef => firestore.collection('rooms');
  CollectionReference get reportsRef => firestore.collection('reports');
  CollectionReference get bansRef => firestore.collection('bans');
  CollectionReference get adsRef => firestore.collection('ads');
}