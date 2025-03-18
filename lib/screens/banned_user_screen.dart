//screens/banned_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cheevo/widgets/animated_background.dart';
import 'package:cheevo/widgets/gradient_button.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'package:cheevo/services/firebase/auth_service.dart';
import 'package:intl/intl.dart';

class BannedUserScreen extends StatefulWidget {
  const BannedUserScreen({super.key});

  @override
  State<BannedUserScreen> createState() => _BannedUserScreenState();
}

class _BannedUserScreenState extends State<BannedUserScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _banInfo;

  @override
  void initState() {
    super.initState();
    _fetchBanInfo();
  }

  Future<void> _fetchBanInfo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final userId = FirebaseService().currentUserId;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final banDoc = await FirebaseService().firestore.collection('bans').doc(userId).get();
      
      if (banDoc.exists) {
        setState(() {
          _banInfo = banDoc.data();
          _isLoading = false;
        });
      } else {
        // If no specific ban document, check user document
        final userDoc = await FirebaseService().firestore.collection('users').doc(userId).get();
        if (userDoc.exists && userDoc.data()?['isBanned'] == true) {
          setState(() {
            _banInfo = {
              'reason': userDoc.data()?['banReason'] ?? 'Violation of community guidelines',
              'isPermanent': userDoc.data()?['banExpiresAt'] == null,
              'expiresAt': userDoc.data()?['banExpiresAt'],
            };
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching ban info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.signOut();
      
      // Navigate back to splash screen which will handle auth flow
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      print('Error signing out: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatExpiryDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Permanent';
    
    final date = timestamp.toDate();
    
    // If expired, show as expired
    if (date.isBefore(DateTime.now())) {
      return 'Expired';
    }
    
    return DateFormat('MMM d, yyyy - h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const AnimatedBackground(),
          
          // Content
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Ban icon and title
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block_rounded,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Account Suspended",
                          style: Theme.of(context).textTheme.displayMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Ban reason
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Reason for Suspension",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _banInfo?['reason'] ?? 'Violation of community guidelines',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Ban expiry info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    color: Colors.cyan,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _banInfo?['isPermanent'] == true
                                          ? "Permanent Suspension"
                                          : "Temporary Suspension",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_banInfo?['isPermanent'] != true) 
                                Text(
                                  "Your account will be restored on:\n${_formatExpiryDate(_banInfo?['expiresAt'])}",
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              if (_banInfo?['isPermanent'] == true)
                                Text(
                                  "Your account has been permanently suspended and cannot be restored.",
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Appeal info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email_outlined,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "Appeal Process",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "If you believe this suspension was made in error, you can submit an appeal by emailing support@cheevo.app with your user ID.",
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
                                "User ID: ${FirebaseService().currentUserId ?? 'Unknown'}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Sign out button
                        GradientButton(
                          onPressed: _signOut,
                          width: double.infinity,
                          height: 56,
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade700,
                              Colors.grey.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          child: const Text(
                            "Sign Out",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}