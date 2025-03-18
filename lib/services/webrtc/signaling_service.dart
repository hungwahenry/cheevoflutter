//services/webrtc/signaling_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'package:cheevo/models/message.dart';

class SignalingService {
 final FirebaseFirestore _firestore = FirebaseService().firestore;
 String? _currentUserId;
 String? _remoteUserId;
 String? _roomId;
 
 // RTC configurations
 final Map<String, dynamic> _configuration = {
   'iceServers': [
     {'urls': 'stun:stun.l.google.com:19302'},
     {'urls': 'stun:stun1.l.google.com:19302'},
     {'urls': 'stun:stun2.l.google.com:19302'},
     {'urls': 'stun:stun3.l.google.com:19302'},
     {'urls': 'stun:stun4.l.google.com:19302'},
     {
       'urls': 'turn:numb.viagenie.ca',
       'credential': 'muazkh',
       'username': 'webrtc@live.com'
     },
     {
       'urls': 'turn:192.158.29.39:3478?transport=udp',
       'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
       'username': '28224511:1379330808'
     }
   ],
   'sdpSemantics': 'unified-plan',
   'iceCandidatePoolSize': 10,
 };
 
 RTCPeerConnection? _peerConnection;
 MediaStream? _localStream;
 MediaStream? _remoteStream;
 RTCDataChannel? _dataChannel;
 
 // Stream controllers
 final _localStreamController = StreamController<MediaStream>.broadcast();
 final _remoteStreamController = StreamController<MediaStream>.broadcast();
 final _messageController = StreamController<Message>.broadcast();
 final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
 final _reactionController = StreamController<String>.broadcast();
 
 // Streams for UI
 Stream<MediaStream> get localStream => _localStreamController.stream;
 Stream<MediaStream> get remoteStream => _remoteStreamController.stream;
 Stream<Message> get messageStream => _messageController.stream;
 Stream<RTCPeerConnectionState> get connectionStateStream => _connectionStateController.stream;
 Stream<String> get reactionStream => _reactionController.stream;
 
 // Subscriptions
 StreamSubscription? _roomSubscription;
 StreamSubscription? _offersSubscription;
 StreamSubscription? _answersSubscription;
 StreamSubscription? _candidatesSubscription;
 
 // Connection timeout timer
 Timer? _connectionTimer;
 
 // Reconnection attempts
 int _reconnectionAttempts = 0;
 static const int maxReconnectionAttempts = 3;
 
 // Initialize the signaling service
 Future<void> initialize(String currentUserId) async {
   _currentUserId = currentUserId;
 }
 
 // Create a room for signaling
 Future<String> createRoom(String remoteUserId) async {
   _remoteUserId = remoteUserId;
   
   // Generate a unique room ID
   final uuid = Uuid();
   _roomId = uuid.v4();
   
   // Create a document for the room
   await _firestore.collection('rooms').doc(_roomId).set({
     'createdAt': FieldValue.serverTimestamp(),
     'createdBy': _currentUserId,
     'participants': [_currentUserId, _remoteUserId],
     'status': 'created',
     'lastActivity': FieldValue.serverTimestamp(),
   });
   
   // Create peer connection and setup data channel
   await _createPeerConnection(true);
   
   return _roomId!;
 }
 
 // Join a room that was created by another user
 Future<void> joinRoom(String roomId, String remoteUserId) async {
   _roomId = roomId;
   _remoteUserId = remoteUserId;
   
   // Update room status
   await _firestore.collection('rooms').doc(_roomId).update({
     'status': 'joined',
     'lastActivity': FieldValue.serverTimestamp(),
   });
   
   // Create peer connection
   await _createPeerConnection(false);
   
   // Listen for offers, answers, and ICE candidates
   _setupRoomListeners();
 }
 
 // Setup local media stream
 Future<MediaStream> createLocalStream() async {
   final Map<String, dynamic> constraints = {
     'audio': true,
     'video': {
       'mandatory': {
         'minWidth': '640',
         'minHeight': '480',
         'minFrameRate': '30',
       },
       'facingMode': 'user',
       'optional': [],
     }
   };
   
   try {
     _localStream = await navigator.mediaDevices.getUserMedia(constraints);
     _localStreamController.add(_localStream!);
     return _localStream!;
   } catch (e) {
     print('Error getting user media: $e');
     rethrow;
   }
 }
 
 // Create peer connection
 Future<void> _createPeerConnection(bool isCreator) async {
   try {
     _peerConnection = await createPeerConnection(_configuration);
     
     // Set up event listeners
     _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
       _sendIceCandidate(candidate);
     };
     
     _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
       print('ICE Connection State: $state');
       if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
         _attemptReconnection();
       } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
         // Start a timer to check if we get reconnected
         _connectionTimer?.cancel();
         _connectionTimer = Timer(Duration(seconds: 5), () {
           if (_peerConnection?.iceConnectionState == 
               RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
             _attemptReconnection();
           }
         });
       } else if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
         // Cancel reconnection timer if connection is restored
         _connectionTimer?.cancel();
         _reconnectionAttempts = 0;
       }
     };
     
     _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
       print('Peer Connection State: $state');
       _connectionStateController.add(state);
       
       // Update room status in Firestore
       if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
         _updateRoomStatus('connected');
       } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected || 
                state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
         _updateRoomStatus('disconnected');
       }
     };
     
     _peerConnection!.onTrack = (RTCTrackEvent event) {
       if (event.streams.isNotEmpty) {
         _remoteStream = event.streams[0];
         _remoteStreamController.add(_remoteStream!);
       }
     };
     
     // Setup data channel
     if (isCreator) {
       final dataChannel = await _peerConnection!.createDataChannel(
         'messages',
         RTCDataChannelInit()
           ..ordered = true
           ..maxRetransmits = 30,
       );
       _setupDataChannel(dataChannel);
     } else {
       _peerConnection!.onDataChannel = (RTCDataChannel channel) {
         _setupDataChannel(channel);
       };
     }
     
     // Add local stream to peer connection
     if (_localStream == null) {
       await createLocalStream();
     }
     
     _localStream!.getTracks().forEach((track) {
       _peerConnection!.addTrack(track, _localStream!);
     });
     
     // If creator, create and send offer
     if (isCreator) {
       await createOffer();
     }
     
     _setupRoomListeners();
   } catch (e) {
     print('Error creating peer connection: $e');
     rethrow;
   }
 }
 
 void _setupDataChannel(RTCDataChannel channel) {
   _dataChannel = channel;
   
   _dataChannel!.onMessage = (RTCDataChannelMessage message) {
     if (message.isBinary) return; // Skip binary messages
     
     try {
       final data = jsonDecode(message.text);
       
       // Check if this is a reaction or text message
       if (data['type'] == 'reaction') {
         final emoji = data['emoji'];
         _reactionController.add(emoji);
       } else {
         final msg = Message.fromJson(data, false);
         _messageController.add(msg);
       }
     } catch (e) {
       print('Error parsing message: $e');
     }
   };
   
   _dataChannel!.onDataChannelState = (RTCDataChannelState state) {
     print('Data Channel State: $state');
     if (state == RTCDataChannelState.RTCDataChannelOpen) {
       // Send a ping to verify channel is working
       _sendPing();
     }
   };
 }
 
 // Send a text message through the data channel
 Future<void> sendMessage(String text) async {
   if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
     throw Exception('Data channel not open');
   }
   
   try {
     final message = Message(
       text: text,
       isFromMe: true,
       timestamp: DateTime.now().millisecondsSinceEpoch,
     );
     
     _messageController.add(message); // Add to local stream
     
     _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message.toJson())));
     
     // Update room's lastActivity timestamp
     _updateRoomActivity();
   } catch (e) {
     print('Error sending message: $e');
     rethrow;
   }
 }
 
 // Send a ping to check data channel
 void _sendPing() {
   if (_dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
     try {
       final pingData = {
         'type': 'ping',
         'timestamp': DateTime.now().millisecondsSinceEpoch,
       };
       _dataChannel!.send(RTCDataChannelMessage(jsonEncode(pingData)));
     } catch (e) {
       print('Error sending ping: $e');
     }
   }
 }
 
 // Update room status in Firestore
 Future<void> _updateRoomStatus(String status) async {
   if (_roomId != null) {
     try {
       await _firestore.collection('rooms').doc(_roomId).update({
         'status': status,
         'lastActivity': FieldValue.serverTimestamp(),
       });
     } catch (e) {
       print('Error updating room status: $e');
     }
   }
 }
 
 // Update room's lastActivity timestamp
 Future<void> _updateRoomActivity() async {
   if (_roomId != null) {
     try {
       await _firestore.collection('rooms').doc(_roomId).update({
         'lastActivity': FieldValue.serverTimestamp(),
       });
     } catch (e) {
       print('Error updating room activity: $e');
     }
   }
 }
 
 // Set up listeners for room updates
 void _setupRoomListeners() {
   // Cancel existing subscriptions if they exist
   _offersSubscription?.cancel();
   _answersSubscription?.cancel();
   _candidatesSubscription?.cancel();
   
   // Listen for room status changes
   _roomSubscription = _firestore
       .collection('rooms')
       .doc(_roomId)
       .snapshots()
       .listen((snapshot) {
         if (!snapshot.exists) {
           // Room was deleted
           _connectionStateController.add(RTCPeerConnectionState.RTCPeerConnectionStateClosed);
         }
       });
   
   // Listen for offers
   _offersSubscription = _firestore
       .collection('rooms')
       .doc(_roomId)
       .collection('offers')
       .snapshots()
       .listen((snapshot) async {
         for (var change in snapshot.docChanges) {
           if (change.type == DocumentChangeType.added) {
             var data = change.doc.data() as Map<String, dynamic>;
             
             if (data['sender'] != _currentUserId) {
               // Handle received offer
               String sdp = data['sdp'];
               String type = data['type'];
               
               await _handleOffer(sdp, type);
             }
           }
         }
       });
   
   // Listen for answers
   _answersSubscription = _firestore
       .collection('rooms')
       .doc(_roomId)
       .collection('answers')
       .snapshots()
       .listen((snapshot) async {
         for (var change in snapshot.docChanges) {
           if (change.type == DocumentChangeType.added) {
             var data = change.doc.data() as Map<String, dynamic>;
             
             if (data['sender'] != _currentUserId) {
               // Handle received answer
               String sdp = data['sdp'];
               String type = data['type'];
               
               await _handleAnswer(sdp, type);
             }
           }
         }
       });
   
   // Listen for ICE candidates
   _candidatesSubscription = _firestore
       .collection('rooms')
       .doc(_roomId)
       .collection('candidates')
       .snapshots()
       .listen((snapshot) async {
         for (var change in snapshot.docChanges) {
           if (change.type == DocumentChangeType.added) {
             var data = change.doc.data() as Map<String, dynamic>;
             
             if (data['sender'] != _currentUserId) {
               // Handle received ICE candidate
               RTCIceCandidate candidate = RTCIceCandidate(
                 data['candidate'],
                 data['sdpMid'],
                 data['sdpMLineIndex'],
               );
               
               await _peerConnection!.addCandidate(candidate);
             }
           }
         }
       });
 }
 
 // Create and send an offer
 Future<void> createOffer() async {
   try {
     RTCSessionDescription description =
         await _peerConnection!.createOffer({
           'offerToReceiveAudio': true,
           'offerToReceiveVideo': true,
         });
     await _peerConnection!.setLocalDescription(description);
     
     // Send offer to signaling server
     await _firestore.collection('rooms').doc(_roomId).collection('offers').add({
       'sender': _currentUserId,
       'type': description.type,
       'sdp': description.sdp,
       'timestamp': FieldValue.serverTimestamp(),
     });
   } catch (e) {
     print('Error creating offer: $e');
     rethrow;
   }
 }
 
 // Handle received offer and create answer
 Future<void> _handleOffer(String sdp, String type) async {
   try {
     RTCSessionDescription description =
         RTCSessionDescription(sdp, type);
     await _peerConnection!.setRemoteDescription(description);
     
     // Create answer
     RTCSessionDescription answer = await _peerConnection!.createAnswer();
     await _peerConnection!.setLocalDescription(answer);
     
     // Send answer to signaling server
     await _firestore.collection('rooms').doc(_roomId).collection('answers').add({
       'sender': _currentUserId,
       'type': answer.type,
       'sdp': answer.sdp,
       'timestamp': FieldValue.serverTimestamp(),
     });
   } catch (e) {
     print('Error handling offer: $e');
     rethrow;
   }
 }
 
 // Handle received answer
 Future<void> _handleAnswer(String sdp, String type) async {
   try {
     RTCSessionDescription description =
         RTCSessionDescription(sdp, type);
     await _peerConnection!.setRemoteDescription(description);
   } catch (e) {
     print('Error handling answer: $e');
     rethrow;
   }
 }
 
 // Send ICE candidate to signaling server
 Future<void> _sendIceCandidate(RTCIceCandidate candidate) async {
   try {
     await _firestore.collection('rooms').doc(_roomId).collection('candidates').add({
       'sender': _currentUserId,
       'candidate': candidate.candidate,
       'sdpMid': candidate.sdpMid,
       'sdpMLineIndex': candidate.sdpMLineIndex,
       'timestamp': FieldValue.serverTimestamp(),
     });
   } catch (e) {
     print('Error sending ICE candidate: $e');
   }
 }
 
 // Attempt to reconnect on failure
 Future<void> _attemptReconnection() async {
   if (_reconnectionAttempts >= maxReconnectionAttempts) {
     print('Maximum reconnection attempts reached');
     _connectionStateController.add(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
     return;
   }
   
   _reconnectionAttempts++;
   print('Attempting reconnection: attempt $_reconnectionAttempts');
   
   // Close the existing connection
   await _peerConnection?.close();
   
   // Create a new peer connection
   if (_currentUserId == _firestore.collection('rooms').doc(_roomId).get().then((doc) => doc.data()?['createdBy'])) {
     await _createPeerConnection(true);  // Creator
   } else {
     await _createPeerConnection(false); // Joiner
   }
 }
 
 // Send a reaction emoji
 Future<void> sendReaction(String emoji) async {
   if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
     return;
   }
   
   try {
     final message = {
       'type': 'reaction',
       'emoji': emoji,
       'timestamp': DateTime.now().millisecondsSinceEpoch,
     };
     
     _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message)));
     
     // Update room's lastActivity timestamp
     _updateRoomActivity();
   } catch (e) {
     print('Error sending reaction: $e');
   }
 }
 
 // Close the connection and clean up
 Future<void> closeConnection() async {
   // Cancel any timers
   _connectionTimer?.cancel();
   
   // Cancel all subscriptions
   _roomSubscription?.cancel();
   _offersSubscription?.cancel();
   _answersSubscription?.cancel();
   _candidatesSubscription?.cancel();
   
   // Close streams
   _localStream?.getTracks().forEach((track) => track.stop());
   _remoteStream?.getTracks().forEach((track) => track.stop());
   
   // Close data channel
   _dataChannel?.close();
   
   // Close peer connection
   await _peerConnection?.close();
   
   // Update room status
   if (_roomId != null) {
     try {
       await _firestore.collection('rooms').doc(_roomId).update({
         'status': 'closed',
         'closedAt': FieldValue.serverTimestamp(),
         'lastActivity': FieldValue.serverTimestamp(),
       });
     } catch (e) {
       print('Error updating room status: $e');
     }
   }
   
   // Reset variables
   _dataChannel = null;
   _peerConnection = null;
   _localStream = null;
   _remoteStream = null;
   _remoteUserId = null;
   _roomId = null;
   _reconnectionAttempts = 0;
 }
 
 // Dispose resources
 void dispose() {
   closeConnection();
   _localStreamController.close();
   _remoteStreamController.close();
   _messageController.close();
   _connectionStateController.close();
   _reactionController.close();
 }
}