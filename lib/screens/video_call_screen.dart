//screens/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cheevo/screens/banned_user_screen.dart';
import 'package:cheevo/widgets/report_modal.dart';
import 'package:cheevo/widgets/reaction_emoji.dart';
import 'package:cheevo/widgets/ad_display.dart';
import 'package:cheevo/services/video_call_service.dart';
import 'package:cheevo/services/firebase/report_service.dart';
import 'package:cheevo/services/firebase/auth_service.dart';
import 'package:cheevo/services/ad_service.dart';
import 'package:cheevo/config/constants.dart';
import 'package:cheevo/models/call_state.dart';
import 'package:cheevo/utils/haptics.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final VideoCallService _videoCallService = VideoCallService();
  final ReportService _reportService = ReportService();
  final AdService _adService = AdService();
  final AuthService _authService = AuthService();
  
  bool _isConnecting = true;
  bool _isChatVisible = false;
  bool _isShowingAd = false;
  bool _isCheckingBanStatus = false;
  
  String? _connectionError;
  Map<String, dynamic>? _currentAd;
  DateTime? _adStartTime;
  
  // Video rendering
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  // Swipe detection state
  Offset? _dragStartPosition;
  bool _isSwipingToSkip = false;
  double _swipeProgress = 0.0;
  
  // Message history
  final List<Map<String, dynamic>> _messages = [];
  
  // Animation controller for skip effect
  late AnimationController _skipAnimationController;
  late Animation<double> _skipAnimation;
  
  // Emoji reactions
  final List<Map<String, dynamic>> _reactions = [
    {'emoji': '❤️', 'label': 'Heart'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '👎', 'label': 'Dislike'},
    {'emoji': '😬', 'label': 'Cringe'},
    {'emoji': '😂', 'label': 'Laugh'},
  ];
  
  // List to track displayed reactions
  final List<Map<String, dynamic>> _displayedReactions = [];
  
  // Subscriptions
  StreamSubscription? _callStateSubscription;
  StreamSubscription? _localStreamSubscription;
  StreamSubscription? _remoteStreamSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _reactionSubscription;
  StreamSubscription? _banStatusSubscription;
  
  // Periodic ban status check timer
  Timer? _banCheckTimer;

  @override
  void initState() {
    super.initState();
    
    _initRenderers();
    _setupVideoCall();
    _checkForAds();
    
    _skipAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _skipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _skipAnimationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start periodic ban status check
    _banCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkUserBanStatus();
    });
  }
  
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }
  
  Future<void> _setupVideoCall() async {
    // Initialize the video call service
    await _videoCallService.initialize();
    
    // Listen for call state changes
    _callStateSubscription = _videoCallService.callStateStream.listen((state) {
      setState(() {
        switch (state) {
          case CallState.connecting:
            _isConnecting = true;
            _connectionError = null;
            break;
          case CallState.connected:
            _isConnecting = false;
            _connectionError = null;
            break;
          case CallState.error:
            _isConnecting = false;
            _connectionError = "Could not find a match at this time";
            break;
          case CallState.disconnected:
            _isConnecting = false;
            _connectionError = "Call disconnected";
            break;
          default:
            break;
        }
      });
    });
    
    // Listen for local stream
    _localStreamSubscription = _videoCallService.localStream.listen((stream) {
      _localRenderer.srcObject = stream;
    });
    
    // Listen for remote stream
    _remoteStreamSubscription = _videoCallService.remoteStream.listen((stream) {
      _remoteRenderer.srcObject = stream;
    });
    
    // Listen for chat messages
    _messageSubscription = _videoCallService.messagesStream.listen((message) {
      setState(() {
        _messages.add({
          'text': message.text,
          'isMe': message.isFromMe,
          'timestamp': message.timestamp,
        });
      });
      
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
    
    // Listen for reactions
    _reactionSubscription = _videoCallService.reactionStream.listen((emoji) {
      _displayReaction(emoji, false);
    });
    
    // Listen for ban status changes
    _banStatusSubscription = _authService.getCurrentUserBanStatus().listen((isBanned) {
      if (isBanned) {
        // Navigate to banned screen
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const BannedUserScreen(),
            transitionDuration: AppConstants.pageTransitionDuration,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
    
    // Start finding a match
    _connectToUser();
  }
  
  Future<void> _checkUserBanStatus() async {
    if (_isCheckingBanStatus) return;
    
    setState(() {
      _isCheckingBanStatus = true;
    });
    
    try {
      final isBanned = await _videoCallService.isUserBanned(
        _videoCallService.remoteUserId ?? ''
      );
      
      if (isBanned && mounted) {
        // If remote user is banned, disconnect and find new match
        _skipToNextUser();
      }
    } catch (e) {
      print('Error checking user ban status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingBanStatus = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatScrollController.dispose();
    _skipAnimationController.dispose();
    _banCheckTimer?.cancel();
    
    _callStateSubscription?.cancel();
    _localStreamSubscription?.cancel();
    _remoteStreamSubscription?.cancel();
    _messageSubscription?.cancel();
    _reactionSubscription?.cancel();
    _banStatusSubscription?.cancel();
    
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    
    _videoCallService.endCall();
    
    super.dispose();
  }
  
  Future<void> _checkForAds() async {
    try {
      final shouldShow = await _adService.shouldShowAd();
      
      if (shouldShow) {
        _currentAd = await _adService.getRandomAd();
        
        if (_currentAd != null) {
          setState(() {
            _isShowingAd = true;
            _adStartTime = DateTime.now();
          });
          
          // Track impression
          _adService.trackAdImpression(_currentAd!['id']);
          
          // For video ads with fixed duration
          if (_currentAd!['type'] == 'video' && !_currentAd!['canSkip']) {
            Future.delayed(Duration(seconds: _currentAd!['duration']), () {
              if (mounted && _isShowingAd) {
                _adService.trackAdCompletion(_currentAd!['id']);
                setState(() {
                  _isShowingAd = false;
                });
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error checking for ads: $e');
    }
  }
  
  void _dismissAd({bool wasSkipped = true}) {
    if (!_isShowingAd || _currentAd == null) return;
    
    HapticUtils.lightImpact();
    
    if (wasSkipped) {
      // Track skip if user dismissed before completion
      if (_adStartTime != null) {
        final secondsWatched = DateTime.now().difference(_adStartTime!).inSeconds;
        _adService.trackAdSkip(_currentAd!['id'], secondsWatched);
      }
    } else {
      // Track completion if natural end
      _adService.trackAdCompletion(_currentAd!['id']);
    }
    
    setState(() {
      _isShowingAd = false;
      _currentAd = null;
      _adStartTime = null;
    });
  }
  
  Future<void> _connectToUser() async {
    setState(() {
      _isConnecting = true;
      _displayedReactions.clear();
      _swipeProgress = 0.0;
      _messages.clear();
    });
    
    // Check if we should show an ad before connecting
    await _checkForAds();
    
    if (!_isShowingAd) {
      // Start the call (if not showing ad)
      await _videoCallService.startCall();
    }
  }

  void _skipToNextUser() {
    HapticUtils.mediumImpact();
    
    // Reset swipe state
    setState(() {
      _isSwipingToSkip = false;
      _swipeProgress = 0.0;
    });
    
    _skipAnimationController.forward().then((_) {
      _skipAnimationController.reset();
      _videoCallService.skipToNextUser();
    });
  }

  void _completeSwipeToSkip() {
    setState(() {
      _isSwipingToSkip = false;
    });
    _skipToNextUser();
  }

  void _cancelSwipeToSkip() {
    setState(() {
      _isSwipingToSkip = false;
      _swipeProgress = 0.0;
    });
  }

  void _showReportModal() {
    HapticUtils.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportModal(
        userId: 'User',
        onSubmit: (reason, details) {
          _submitReport(reason, details);
        },
      ),
    );
  }
  
  Future<void> _submitReport(String reason, String? details) async {
    try {
      if (_videoCallService.remoteUserId != null) {
        await _reportService.submitReport(
          reportedUserId: _videoCallService.remoteUserId!,
          reason: reason,
          details: details,
        );
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Report submitted successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error submitting report: $e');
    }
  }

  void _sendReaction(Map<String, dynamic> reaction) {
    HapticUtils.lightImpact();
    
    // Send to peer
    _videoCallService.sendReaction(reaction['emoji']);
    
    // Display locally
    _displayReaction(reaction['emoji'], true);
  }
  
  void _displayReaction(String emoji, bool isFromMe) {
    // Generate a unique ID for this reaction
    final reactionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Add reaction to displayed reactions
    setState(() {
      _displayedReactions.add({
        'emoji': emoji,
        'id': reactionId,
        'position': Offset(
          20.0 + math.Random().nextDouble() * (MediaQuery.of(context).size.width - 100),
          isFromMe
              ? MediaQuery.of(context).size.height * 0.75 - 50.0  // From bottom (local user)
              : MediaQuery.of(context).size.height * 0.25 - 50.0, // From top (remote user)
        ),
      });
    });
    
    // Remove reaction after animation completes
    Future.delayed(AppConstants.reactionDisplayDuration, () {
      if (mounted) {
        setState(() {
          _displayedReactions.removeWhere((r) => r['id'] == reactionId);
        });
      }
    });
  }

  void _toggleChat() {
    HapticUtils.selectionClick();
    setState(() {
      _isChatVisible = !_isChatVisible;
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      HapticUtils.lightImpact();
      
      // Send the message
      _videoCallService.sendMessage(_messageController.text.trim());
      
      _messageController.clear();
    }
  }
  
  void _handleAdClick() {
    if (_currentAd != null) {
      _adService.trackAdClick(_currentAd!['id']);
      // Handle opening the URL (could use url_launcher package)
      print('Would open URL: ${_currentAd!['ctaUrl']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isShowingAd) {
      return _buildAdScreen();
    }
    
    return Scaffold(
      body: GestureDetector(
        onVerticalDragStart: (details) {
          if (!_isConnecting && _connectionError == null) {
            _dragStartPosition = details.globalPosition;
          }
        },
        onVerticalDragUpdate: (details) {
          if (_dragStartPosition != null && !_isConnecting && _connectionError == null) {
            final dragDistance = _dragStartPosition!.dy - details.globalPosition.dy;
            
            if (dragDistance > 50 && !_isSwipingToSkip) {
              setState(() {
                _isSwipingToSkip = true;
                HapticFeedback.selectionClick();
              });
            }
            
            if (_isSwipingToSkip) {
              final screenHeight = MediaQuery.of(context).size.height;
              final progress = (dragDistance / (screenHeight * 0.2)).clamp(0.0, 1.0);
              
              setState(() {
                _swipeProgress = progress;
              });
            }
          }
        },
        onVerticalDragEnd: (details) {
          if (_isSwipingToSkip) {
            if (_swipeProgress > 0.5) {
              _completeSwipeToSkip();
            } else {
              _cancelSwipeToSkip();
            }
          }
          _dragStartPosition = null;
        },
        child: AnimatedBuilder(
          animation: _skipAnimationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                0,
                -MediaQuery.of(context).size.height * _skipAnimation.value,
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              // Video call layout
              Column(
                children: [
                  // Top video (remote user)
                  Expanded(
                    child: _buildVideoView(true),
                  ),
                  
                  // Bottom video (local user)
                  Expanded(
                    child: _buildVideoView(false),
                  ),
                ],
              ),
              
              // Swipe to skip overlay
              if (_isSwipingToSkip)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.7 * _swipeProgress),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white.withOpacity(_swipeProgress),
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Release to skip",
                            style: TextStyle(
                              color: Colors.white.withOpacity(_swipeProgress),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Displayed reactions
              ..._displayedReactions.map((reaction) => 
                ReactionEmoji(
                  emoji: reaction['emoji'],
                  position: reaction['position'],
                ),
              ),
              
              // Controls overlay
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top controls
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back button
                          GestureDetector(
                           onTap: () {
                              HapticUtils.mediumImpact();
                              _videoCallService.endCall();
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          
                          // Connection info
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isConnecting 
                                        ? Colors.amber 
                                        : _connectionError != null 
                                            ? Colors.redAccent 
                                            : Colors.greenAccent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isConnecting 
                                      ? "Connecting..." 
                                      : _connectionError != null 
                                          ? "Connection error" 
                                          : "Connected", // No username
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Report button
                          GestureDetector(
                            onTap: _isConnecting || _connectionError != null 
                                ? null 
                                : _showReportModal,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _isConnecting || _connectionError != null
                                    ? Colors.grey.withOpacity(0.3)
                                    : Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.flag_outlined,
                                color: _isConnecting || _connectionError != null
                                    ? Colors.grey
                                    : Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom controls
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent, 
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          // Reaction emoji row
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _reactions.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: GestureDetector(
                                    onTap: _isConnecting || _connectionError != null
                                        ? null
                                        : () => _sendReaction(_reactions[index]),
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: _isConnecting || _connectionError != null
                                            ? Colors.grey.withOpacity(0.2)
                                            : Colors.white.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _reactions[index]['emoji'],
                                          style: const TextStyle(
                                            fontSize: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Bottom action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Chat toggle button
                              _buildActionButton(
                                icon: _isChatVisible 
                                  ? Icons.chat_bubble 
                                  : Icons.chat_bubble_outline,
                                label: "Chat",
                                onTap: _toggleChat,
                                isDisabled: _isConnecting || _connectionError != null,
                                isPrimary: _isChatVisible,
                              ),
                              
                              // Skip button
                              _buildActionButton(
                                icon: Icons.skip_next,
                                label: "Skip",
                                onTap: _skipToNextUser,
                                isDisabled: _isConnecting,
                                isPrimary: true,
                                isLarge: true,
                              ),
                              
                              // End call button
                              _buildActionButton(
                                icon: Icons.call_end,
                                label: "End",
                                onTap: () {
                                  HapticUtils.mediumImpact();
                                  _videoCallService.endCall();
                                  Navigator.pop(context);
                                },
                                color: const Color(0xFFFF5252),
                              ),
                            ],
                          ),
                          
                          // Chat area (conditionally visible)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: _isChatVisible ? 200 : 0,
                            margin: EdgeInsets.only(
                              top: _isChatVisible ? 20 : 0,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: _isChatVisible ? Column(
                              children: [
                                // Chat messages
                                Expanded(
                                  child: _messages.isEmpty
                                    ? Center(
                                        child: Text(
                                          "No messages yet",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: _chatScrollController,
                                        padding: EdgeInsets.zero,
                                        itemCount: _messages.length,
                                        itemBuilder: (context, index) {
                                          final message = _messages[index];
                                          final isMe = message['isMe'] as bool;
                                          
                                          return Align(
                                            alignment: isMe 
                                                ? Alignment.centerRight 
                                                : Alignment.centerLeft,
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
                                                    : Colors.white.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                message['text'] as String,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Chat input
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(24),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _messageController,
                                          enabled: !_isConnecting && _connectionError == null,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: const InputDecoration(
                                            hintText: "Type a message...",
                                            hintStyle: TextStyle(color: Colors.white54),
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    GestureDetector(
                                      onTap: (!_isConnecting && _connectionError == null) 
                                          ? _sendMessage 
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: (!_isConnecting && _connectionError == null)
                                              ? LinearGradient(
                                                  colors: [
                                                    Theme.of(context).colorScheme.primary,
                                                    Theme.of(context).colorScheme.secondary,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                          color: (_isConnecting || _connectionError != null)
                                              ? Colors.grey.withOpacity(0.3)
                                              : null,
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: const Icon(
                                          Icons.send,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ) : const SizedBox(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Connection overlay
              if (_isConnecting)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Finding someone to connect with...",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Please wait a moment",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              // Connection error overlay
              if (_connectionError != null)
                Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Connection Error",
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _connectionError!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          GestureDetector(
                            onTap: _connectToUser,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(AppConstants.buttonCornerRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "Try Again",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAdScreen() {
    if (_currentAd == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onVerticalDragStart: (details) {
          _dragStartPosition = details.globalPosition;
        },
        onVerticalDragUpdate: (details) {
          if (_dragStartPosition != null) {
            final dragDistance = _dragStartPosition!.dy - details.globalPosition.dy;
            
            if (dragDistance > 80 && _currentAd!['canSkip']) {
              _dismissAd();
              _dragStartPosition = null;
            }
          }
        },
        onVerticalDragEnd: (details) {
          _dragStartPosition = null;
        },
        child: Stack(
          children: [
            // Ad Display Widget
            AdDisplay(
              ad: _currentAd!,
              onCTAPressed: _handleAdClick,
            ),
            
            // Skip button if allowed
            if (_currentAd!['canSkip'])
              Positioned(
                bottom: 40,
                right: 30,
                child: GestureDetector(
                  onTap: () => _dismissAd(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppConstants.buttonCornerRadius),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "Skip Ad",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Swipe up to skip indicator
            if (_currentAd!['canSkip'])
              Positioned(
                top: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.keyboard_arrow_up,
                          color: Colors.white70,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Swipe up to skip",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Ad timer
            if (_currentAd!['type'] == 'video' && !_currentAd!['canSkip'])
              Positioned(
                top: 40,
                right: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "${_currentAd!['duration']}s",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildVideoView(bool isRemoteUser) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: Colors.black,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Video renderer
          if (isRemoteUser)
            _isConnecting || _connectionError != null || _remoteRenderer.srcObject == null
              ? Container(
                  color: const Color(0xFF0D1117),
                )
              : RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
          else
            _localRenderer.srcObject == null
              ? Container(
                  color: const Color(0xFF16191F),
                )
              : RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
          
          // User info overlay
          if (!_isConnecting && _connectionError == null)
            Positioned(
              left: 16,
              top: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  isRemoteUser ? "User" : 'You',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            
          // Swipe indicator
          if (!_isConnecting && _connectionError == null && isRemoteUser)
            Positioned(
              top: 16,
              right: 0,
              left: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Swipe up to skip",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isLarge = false,
    bool isDisabled = false,
    Color? color,
  }) {
    final buttonSize = isLarge ? 64.0 : 54.0;
    
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              gradient: (!isDisabled && isPrimary && color == null) 
                  ? LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isDisabled
                  ? Colors.grey.withOpacity(0.3)
                  : color ?? (isPrimary ? null : Colors.white.withOpacity(0.15)),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: (!isDisabled && isPrimary) 
                ? [
                    BoxShadow(
                      color: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 5),
                    ),
                  ] 
                : null,
            ),
            child: Icon(
              icon,
              color: isDisabled ? Colors.grey.shade300 : Colors.white,
              size: isLarge ? 32 : 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey : Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
} 