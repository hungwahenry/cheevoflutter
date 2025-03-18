//screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:cheevo/screens/video_call_screen.dart';
import 'package:cheevo/screens/permissions_screen.dart';
import 'package:cheevo/screens/banned_user_screen.dart';
import 'package:cheevo/widgets/animated_background.dart';
import 'package:cheevo/widgets/gradient_button.dart';
import 'package:cheevo/widgets/ban_warning_dialog.dart';
import 'package:cheevo/config/constants.dart';
import 'package:cheevo/services/firebase/auth_service.dart';
import 'package:cheevo/services/firebase/firebase_service.dart';
import 'package:cheevo/services/video_call_service.dart';
import 'package:cheevo/services/permissions_service.dart';
import 'package:cheevo/utils/haptics.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _buttonController;
  late Animation<double> _buttonScaleAnimation;
  
  final VideoCallService _videoCallService = VideoCallService();
  final AuthService _authService = AuthService();
  final PermissionsService _permissionsService = PermissionsService();
  
  int _onlineUsers = 0;
  bool _isInitializing = true;
  bool _checkingBanStatus = true;
  
  @override
  void initState() {
    super.initState();
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _buttonController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initializeServices();
  }
  
  Future<void> _initializeServices() async {
    try {
      // Check if user is banned (in case they got banned while app was running)
      await _checkBanStatus();
      
      // Initialize video call service
      await _videoCallService.initialize();
      
      // Subscribe to online users count
      _videoCallService.getOnlineUsersCount().listen((count) {
        if (mounted) {
          setState(() {
            _onlineUsers = count;
            _isInitializing = false;
          });
        }
      });
      
      // Check for warning dialog (if user has reports)
      _checkForWarnings();
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _isInitializing = false;
        _checkingBanStatus = false;
      });
    }
  }
  
  Future<void> _checkBanStatus() async {
    final userId = FirebaseService().currentUserId;
    if (userId != null) {
      final isBanned = await _authService.checkIfUserIsBanned(userId);
      
      if (isBanned && mounted) {
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
    }
   if (mounted) {
     setState(() {
       _checkingBanStatus = false;
     });
   }
 }
 
 Future<void> _checkForWarnings() async {
   final userId = FirebaseService().currentUserId;
   if (userId == null) return;
   
   try {
     final userDoc = await FirebaseService().firestore.collection('users').doc(userId).get();
     final userData = userDoc.data();
     
     if (userData != null) {
       final int reportCount = userData['reportCount'] ?? 0;
       
       // Show warning dialog if user has reports
       if (reportCount >= 2 && mounted) {
         // Small delay to ensure UI is ready
         await Future.delayed(const Duration(milliseconds: 500));
         
         showDialog(
           context: context,
           barrierDismissible: false,
           builder: (context) => BanWarningDialog(
             reportCount: reportCount,
             onAcknowledge: () {
               Navigator.of(context).pop();
             },
           ),
         );
       }
     }
   } catch (e) {
     print('Error checking for warnings: $e');
   }
 }
 
 @override
 void dispose() {
   _buttonController.dispose();
   super.dispose();
 }

 Future<void> _navigateToVideoCall(BuildContext context) async {
   HapticUtils.mediumImpact();

   final hasPermissions = await _permissionsService.checkVideoChatPermissions();
   
   if (!hasPermissions) {
     // Navigate to permissions screen instead
     if (mounted) {
       Navigator.of(context).push(
         PageRouteBuilder(
           pageBuilder: (_, __, ___) => const PermissionsScreen(),
           transitionDuration: AppConstants.pageTransitionDuration,
           transitionsBuilder: (_, animation, __, child) {
             return FadeTransition(opacity: animation, child: child);
           },
         ),
       );
     }
   } else {
     // Permissions already granted, go to video call screen
     if (mounted) {
       Navigator.of(context).push(
         PageRouteBuilder(
           pageBuilder: (_, __, ___) => const VideoCallScreen(),
           transitionDuration: AppConstants.pageTransitionDuration,
           transitionsBuilder: (_, animation, __, child) {
             return FadeTransition(opacity: animation, child: child);
           },
         ),
       );
     }
   }
 }

 void _showTermsDialog() {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       backgroundColor: Theme.of(context).colorScheme.surface,
       shape: RoundedRectangleBorder(
         borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
       ),
       title: const Text('Terms & Privacy Policy'),
       content: const SingleChildScrollView(
         child: Text(
           'By using Cheevo, you agree to our Terms of Service and Privacy Policy. '
           'We prioritize your privacy and secure your data with industry-standard encryption. '
           'You must be 18 years or older to use this service. '
           'Inappropriate content, harassment, and illegal activities are prohibited and may result in permanent ban.',
           style: TextStyle(height: 1.5),
         ),
       ),
       actions: [
         TextButton(
           onPressed: () => Navigator.pop(context),
           child: const Text('Close'),
         ),
       ],
     ),
   );
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
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.center,
             children: [
               // App logo at top
               Padding(
                 padding: const EdgeInsets.only(top: 40),
                 child: Image.asset(
                   'assets/images/cheevo_logo.png',
                   width: 140,
                   height: 60,
                 ),
               ),
               
               // Users online indicator
               Container(
                 margin: const EdgeInsets.only(top: 12),
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(20),
                   border: Border.all(
                     color: Colors.white.withOpacity(0.1),
                     width: 1,
                   ),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Container(
                       width: 8,
                       height: 8,
                       decoration: const BoxDecoration(
                         color: Colors.greenAccent,
                         shape: BoxShape.circle,
                       ),
                     ),
                     const SizedBox(width: 8),
                     _isInitializing
                         ? const SizedBox(
                             width: 12,
                             height: 12,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                             ),
                           )
                         : Text(
                             "$_onlineUsers users online",
                             style: const TextStyle(
                               color: Colors.white,
                               fontSize: 13,
                             ),
                           ),
                   ],
                 ),
               ),
               
               // Main content area
               Expanded(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 30),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       // Illustration
                       Container(
                         width: double.infinity,
                         height: 240,
                         margin: const EdgeInsets.only(bottom: 40),
                         decoration: BoxDecoration(
                           color: Colors.white.withOpacity(0.05),
                           borderRadius: BorderRadius.circular(AppConstants.cornerRadius),
                           border: Border.all(
                             color: Colors.white.withOpacity(0.1),
                             width: 1,
                           ),
                         ),
                         child: CustomPaint(
                           painter: ConnectionIllustrationPainter(),
                           child: Center(
                             child: Column(
                               mainAxisAlignment: MainAxisAlignment.center,
                               children: [
                                 Container(
                                   padding: const EdgeInsets.all(20),
                                   decoration: BoxDecoration(
                                     color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                     shape: BoxShape.circle,
                                   ),
                                   child: const Icon(
                                     Icons.video_call_rounded,
                                     color: Colors.white,
                                     size: 40,
                                   ),
                                 ),
                                 const SizedBox(height: 24),
                                 Text(
                                   "Random Video Chats",
                                   style: Theme.of(context).textTheme.displayMedium,
                                 ),
                                 const SizedBox(height: 8),
                                 Text(
                                   "Connect with new people instantly",
                                   style: Theme.of(context).textTheme.bodyMedium,
                                   textAlign: TextAlign.center,
                                 ),
                               ],
                             ),
                           ),
                         ),
                       ),
                       
                       // Description
                       Text(
                         "Meet people from around the world through instant video calls. No sign-up required!",
                         style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                           fontSize: 16,
                           height: 1.5,
                         ),
                         textAlign: TextAlign.center,
                       ),
                     ],
                   ),
                 ),
               ),
               
               // Start button
               Padding(
                 padding: const EdgeInsets.only(bottom: 30),
                 child: AnimatedBuilder(
                   animation: _buttonController,
                   builder: (context, child) {
                     return Transform.scale(
                       scale: _buttonScaleAnimation.value,
                       child: GradientButton(
                         onPressed: _checkingBanStatus 
                             ? null 
                             : () => _navigateToVideoCall(context),
                         width: 220,
                         height: 60,
                         gradient: LinearGradient(
                           colors: [
                             Theme.of(context).colorScheme.primary,
                             Theme.of(context).colorScheme.secondary,
                           ],
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                         ),
                         child: _checkingBanStatus
                             ? const SizedBox(
                                 width: 24,
                                 height: 24,
                                 child: CircularProgressIndicator(
                                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                   strokeWidth: 2,
                                 ),
                               )
                             : Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: const [
                                   Icon(Icons.video_call_rounded, color: Colors.white, size: 28),
                                   SizedBox(width: 12),
                                   Text(
                                     "Start Video Chat",
                                     style: TextStyle(
                                       color: Colors.white,
                                       fontSize: 16,
                                       fontWeight: FontWeight.bold,
                                       letterSpacing: 0.5,
                                     ),
                                   ),
                                 ],
                               ),
                       ),
                     );
                   },
                 ),
               ),
               
               // Terms and conditions text
               GestureDetector(
                 onTap: _showTermsDialog,
                 child: Padding(
                   padding: const EdgeInsets.only(bottom: 16, left: 30, right: 30),
                   child: Text(
                     "By using Cheevo, you accept our Privacy Policy and Terms of Use",
                     style: TextStyle(
                       color: Colors.white.withOpacity(0.5),
                       fontSize: 11,
                     ),
                     textAlign: TextAlign.center,
                   ),
                 ),
               ),
             ],
           ),
         ),
       ],
     ),
   );
 }
}

class ConnectionIllustrationPainter extends CustomPainter {
 @override
 void paint(Canvas canvas, Size size) {
   // Create a subtle gradient background
   final gradientPaint = Paint()
     ..shader = RadialGradient(
       colors: [
         Colors.white.withOpacity(0.08),
         Colors.white.withOpacity(0.02),
       ],
       center: Alignment.center,
       radius: size.width * 0.7,
     ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
   
   canvas.drawRect(
     Rect.fromLTWH(0, 0, size.width, size.height),
     gradientPaint
   );
   
   // Add subtle accents - just a few soft circles
   final accentPaint = Paint()
     ..style = PaintingStyle.stroke
     ..strokeWidth = 0.5
     ..color = Colors.white.withOpacity(0.1);
     
   // Draw a couple of subtle accent circles
   canvas.drawCircle(
     Offset(size.width * 0.25, size.height * 0.6),
     size.width * 0.1,
     accentPaint,
   );
   
   canvas.drawCircle(
     Offset(size.width * 0.75, size.height * 0.3),
     size.width * 0.15,
     accentPaint,
   );
   
   // Draw a slightly larger accent
   final accentPaint2 = Paint()
     ..style = PaintingStyle.stroke
     ..strokeWidth = 0.3
     ..color = Colors.white.withOpacity(0.07);
     
   canvas.drawCircle(
     Offset(size.width * 0.5, size.height * 0.5),
     size.width * 0.3,
     accentPaint2,
   );
 }
 
 @override
 bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}