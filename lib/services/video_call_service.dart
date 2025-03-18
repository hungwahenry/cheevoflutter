//services/video_call_service.dart
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'package:cheevo/services/firebase/auth_service.dart';
import 'package:cheevo/services/firebase/user_service.dart';
import 'package:cheevo/services/webrtc/signaling_service.dart';
import 'package:cheevo/models/call_state.dart';
import 'package:cheevo/models/message.dart';
import 'package:cheevo/config/constants.dart';

class VideoCallService {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final SignalingService _signalingService = SignalingService();
  
  String? _currentUserId;
  String? _remoteUserId;
  // ignore: unused_field
  String? _roomId;
  
  CallState _state = CallState.idle;
  CallState get state => _state;
  String? get remoteUserId => _remoteUserId;
  
  // Call metrics
  DateTime? _callStartTime;
  int _messagesCount = 0;
  int _callsCount = 0;
  
  // Stream controllers
  final _callStateController = StreamController<CallState>.broadcast();
  final _reactionController = StreamController<String>.broadcast();
  
  // Stream subscriptions
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _banStatusSubscription;
  
  // Connection timer
  Timer? _connectionTimer;
  
  // Streams that the UI can listen to
  Stream<CallState> get callStateStream => _callStateController.stream;
  Stream<MediaStream> get localStream => _signalingService.localStream;
  Stream<MediaStream> get remoteStream => _signalingService.remoteStream;
  Stream<Message> get messagesStream => _signalingService.messageStream;
  Stream<String> get reactionStream => _reactionController.stream;
  
  // Initialize the service
  Future<void> initialize() async {
    // Make sure user is signed in
    if (!FirebaseService().isUserSignedIn) {
      await _authService.signInAnonymously();
    }
    
    _currentUserId = FirebaseService().currentUserId;
    
    // Initialize signaling service
    if (_currentUserId != null) {
      await _signalingService.initialize(_currentUserId!);
      
      // Update user status
      await _authService.updateUserStatus(isOnline: true);
      
      // Listen for connection state changes
      _connectionStateSubscription = _signalingService.connectionStateStream.listen((state) {
        switch (state) {
          case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
            _updateState(CallState.connected);
            _startCallTimer();
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
            _updateState(CallState.disconnected);
            break;
          case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
            _updateState(CallState.idle);
            break;
          default:
            break;
        }
      });
      
      // Listen for message events to count messages
      _signalingService.messageStream.listen((_) {
        _messagesCount++;
      });
      
      // Listen for reaction events
      _signalingService.reactionStream.listen((emoji) {
        _reactionController.add(emoji);
      });
      
      // Listen for ban status changes
      _banStatusSubscription = _authService.getCurrentUserBanStatus().listen((isBanned) {
        if (isBanned) {
          // User was banned during session
          endCall();
          _updateState(CallState.error);
        }
      });
    }
  }
  
  // Start tracking call metrics
  void _startCallTimer() {
    _callStartTime = DateTime.now();
    _callsCount++;
  }
  
  // Calculate session duration in seconds
  int _getSessionDuration() {
    if (_callStartTime == null) return 0;
    return DateTime.now().difference(_callStartTime!).inSeconds;
  }
  
  // Start looking for a call
  Future<void> startCall() async {
    if (_currentUserId == null) {
      _updateState(CallState.error);
      return;
    }
    
    _updateState(CallState.connecting);
    
    // Set a connection timeout
    _connectionTimer?.cancel();
    _connectionTimer = Timer(AppConstants.connectionTimeout, () {
      if (_state == CallState.connecting) {
        _updateState(CallState.error);
      }
    });
    
    try {
      // Check if user is banned before proceeding
      final isBanned = await _userService.checkUserBanStatus(_currentUserId!);
      if (isBanned) {
        _updateState(CallState.error);
        return;
      }
      
      // Update user status to matching
      await _userService.updateMatchingStatus(_currentUserId!, isMatching: true);
      
      // Find a random user
      _remoteUserId = await _userService.findRandomUser(_currentUserId!);
      
      if (_remoteUserId == null) {
        // No users available
        _updateState(CallState.error);
        return;
      }
      
      // Create a room
      _roomId = await _signalingService.createRoom(_remoteUserId!);
      
      // Setup local stream
      await _signalingService.createLocalStream();
      
      // Connection state will be updated via the subscription
    } catch (e) {
      print('Error starting call: $e');
      _updateState(CallState.error);
    }
  }
  
  // Join an existing call
  Future<void> joinCall(String roomId, String remoteUserId) async {
    if (_currentUserId == null) {
      _updateState(CallState.error);
      return;
    }
    
    _updateState(CallState.connecting);
    _remoteUserId = remoteUserId;
    _roomId = roomId;
    
    // Set a connection timeout
    _connectionTimer?.cancel();
    _connectionTimer = Timer(AppConstants.connectionTimeout, () {
      if (_state == CallState.connecting) {
        _updateState(CallState.error);
      }
    });
    
    try {
      // Check if user is banned before proceeding
      final isBanned = await _userService.checkUserBanStatus(_currentUserId!);
      if (isBanned) {
        _updateState(CallState.error);
        return;
      }
      
      // Update user status to matching
      await _userService.updateMatchingStatus(_currentUserId!, isMatching: true);
      
      // Setup local stream
      await _signalingService.createLocalStream();
      
      // Join the room
      await _signalingService.joinRoom(roomId, remoteUserId);
      
      // Connection state will be updated via the subscription
    } catch (e) {
      print('Error joining call: $e');
      _updateState(CallState.error);
    }
  }
  
  // Send a chat message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    try {
      await _signalingService.sendMessage(text);
      _messagesCount++;
    } catch (e) {
      print('Error sending message: $e');
    }
  }
  
  // Send a reaction emoji
  Future<void> sendReaction(String emoji) async {
    try {
      await _signalingService.sendReaction(emoji);
      _reactionController.add(emoji);
    } catch (e) {
      print('Error sending reaction: $e');
    }
  }
  
  // End the current call
  Future<void> endCall() async {
    // Cancel connection timer
    _connectionTimer?.cancel();
    
    if (_currentUserId != null) {
      // Track session metrics
      if (_callStartTime != null) {
        await _userService.trackSessionMetrics(
          _currentUserId!,
          sessionDurationSeconds: _getSessionDuration(),
          callsCount: _callsCount,
          messagesCount: _messagesCount,
        );
      }
      
      // Update matching status
      await _userService.updateMatchingStatus(_currentUserId!, isMatching: false);
    }
    
    await _signalingService.closeConnection();
    _updateState(CallState.idle);
    
    // Reset call metrics
    _callStartTime = null;
    _messagesCount = 0;
    
    _remoteUserId = null;
    _roomId = null;
  }
  
  // Skip to next user
  Future<void> skipToNextUser() async {
    // End current call
    await endCall();
    
    // Start a new call
    await startCall();
  }
  
  // Update the call state
  void _updateState(CallState newState) {
    _state = newState;
    _callStateController.add(newState);
  }
  
  // Get count of online users
  Stream<int> getOnlineUsersCount() {
    return _userService.getOnlineUsersCount();
  }
  
  // Check if a specific user is banned
  Future<bool> isUserBanned(String userId) async {
    return _userService.checkUserBanStatus(userId);
  }
  
  // Update user activity timestamp
  Future<void> updateUserActivity() async {
    if (_currentUserId != null) {
      await _userService.updateUserActivity(_currentUserId!);
    }
  }
  
  // Dispose resources
  void dispose() {
    _connectionTimer?.cancel();
    _connectionStateSubscription?.cancel();
    _banStatusSubscription?.cancel();
    _callStateController.close();
    _reactionController.close();
    _signalingService.dispose();
    
    // Track final metrics before disposing
    if (_currentUserId != null && _callStartTime != null) {
      _userService.trackSessionMetrics(
        _currentUserId!,
        sessionDurationSeconds: _getSessionDuration(),
        callsCount: _callsCount,
        messagesCount: _messagesCount,
      );
    }
  }
}