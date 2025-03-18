//screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cheevo/screens/home_screen.dart';
import 'package:cheevo/screens/banned_user_screen.dart';
import 'package:cheevo/config/constants.dart';
import 'package:cheevo/services/firebase/auth_service.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _backgroundAnimation;
  
  final AuthService _authService = AuthService();
  bool _isProcessingAuth = true;
  
  @override
  void initState() {
    super.initState();
    
    // Setup background animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _backgroundController,
        curve: Curves.easeOut,
      ),
    );
    
    // Setup logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.1).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 40,
      ),
    ]).animate(_logoController);
    
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    
    // Start animations
    _backgroundController.forward();
    
    // Slight delay before starting logo animation
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _logoController.forward();
      }
    });
    
    // Check authentication and ban status
    _checkAuthAndBanStatus();
  }
  
  Future<void> _checkAuthAndBanStatus() async {
    try {
      // Ensure minimum splash display time
      await Future.delayed(const Duration(milliseconds: 2000));
      
      if (FirebaseService().isUserSignedIn) {
        // User is already signed in, check if banned
        await _checkBanStatus();
      } else {
        // Sign in anonymously
        final user = await _authService.signInAnonymously();
        
        if (user == null) {
          // Sign in failed or user is banned
          setState(() {
            _isProcessingAuth = false;
          });
          
          if (mounted) {
            // Check if ban is the reason
            final isBanned = await _authService.checkIfUserIsBanned(user?.uid ?? '');
            if (isBanned) {
              // Navigate to banned screen
              _navigateToBannedScreen();
            } else {
              // Navigate to home screen anyway
              _navigateToHomeScreen();
            }
          }
        } else {
          // Check ban status after successful sign in
          await _checkBanStatus();
        }
      }
    } catch (e) {
      print('Error during auth check: $e');
      // Navigate to home screen on error
      if (mounted) {
        _navigateToHomeScreen();
      }
    }
  }
  
  Future<void> _checkBanStatus() async {
    final userId = FirebaseService().currentUserId;
    
    if (userId != null) {
      // Check and update ban status (in case it has expired)
      await _authService.checkAndUpdateBanStatus(userId);
      
      // Check current ban status
      final isBanned = await _authService.checkIfUserIsBanned(userId);
      
      setState(() {
        _isProcessingAuth = false;
      });
      
      if (isBanned) {
        // Navigate to banned screen
        _navigateToBannedScreen();
      } else {
        // Navigate to home screen
        _navigateToHomeScreen();
      }
    } else {
      setState(() {
        _isProcessingAuth = false;
      });
      
      // Navigate to home screen if no user ID
      _navigateToHomeScreen();
    }
  }
  
  void _navigateToHomeScreen() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: AppConstants.pageTransitionDuration,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }
  
  void _navigateToBannedScreen() {
    if (mounted) {
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
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return CustomPaint(
                painter: SplashBackgroundPainter(
                  animation: _backgroundAnimation.value,
                  colorScheme: Theme.of(context).colorScheme,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // Logo animation
          Center(
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacityAnimation.value,
                  child: Transform.scale(
                    scale: _logoScaleAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // App logo
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Image.asset(
                            'assets/images/cheevo_logo.png',
                            width: 120,
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 30),
                        
                        // Tagline
                        Text(
                          "Connect in an instant",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            letterSpacing: 1.0,
                          ),
                        ),
                        
                        // Loading indicator
                        if (_isProcessingAuth)
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SplashBackgroundPainter extends CustomPainter {
  final double animation;
  final ColorScheme colorScheme;
  
  SplashBackgroundPainter({
    required this.animation,
    required this.colorScheme,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Background fill
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0A0E21),
          const Color(0xFF121638),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    
    // Create circular glow effect
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width * 0.6 * animation;
    
    // Draw radial gradient
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colorScheme.primary.withOpacity(0.3 * animation),
          colorScheme.primary.withOpacity(0.15 * animation),
          colorScheme.primary.withOpacity(0.05 * animation),
          Colors.transparent,
        ],
        stops: const [0.2, 0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: radius,
      ));
    
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      radialPaint,
    );
    
    // Add some circular accents
    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
      
    for (int i = 0; i < 3; i++) {
      final progress = animation * (1 - i * 0.2);
      if (progress > 0) {
        accentPaint.color = colorScheme.secondary.withOpacity(0.15 * progress);
        canvas.drawCircle(
          Offset(centerX, centerY),
          radius * (0.7 + i * 0.15) * progress,
          accentPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(SplashBackgroundPainter oldDelegate) => 
      oldDelegate.animation != animation;
}