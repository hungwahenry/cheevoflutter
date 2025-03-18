//widgets/ad_display.dart
import 'package:flutter/material.dart';
import 'package:cheevo/config/constants.dart';
import 'package:cheevo/utils/haptics.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class AdDisplay extends StatefulWidget {
  final Map<String, dynamic> ad;
  final VoidCallback onCTAPressed;

  const AdDisplay({
    super.key,
    required this.ad,
    required this.onCTAPressed,
  });

  @override
  State<AdDisplay> createState() => _AdDisplayState();
}

class _AdDisplayState extends State<AdDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start animation
    _animationController.forward();
    
    // Setup countdown timer for video ads
    if (widget.ad['type'] == 'video' && !widget.ad['canSkip']) {
      _secondsRemaining = widget.ad['duration'] as int;
      _startCountdown();
    }
  }
  
  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _countdownTimer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0E21),
                const Color(0xFF1A1F38),
              ],
            ),
          ),
        ),
        
        // Ad content
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            );
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ad content container
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ad image/video
                      Container(
                        height: 250,
                        width: double.infinity,
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildAdMedia(),
                        ),
                      ),
                      
                      // Ad content
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.ad['title'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.ad['description'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // CTA button
                            GestureDetector(
                              onTap: () {
                               HapticUtils.mediumImpact();
                               widget.onCTAPressed();
                             },
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
                                     color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                     blurRadius: 12,
                                     offset: const Offset(0, 5),
                                   ),
                                 ],
                               ),
                               child: Center(
                                 child: Text(
                                   widget.ad['ctaText'],
                                   style: const TextStyle(
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
                   ],
                 ),
               ),
             ],
           ),
         ),
       ),
       
       // Ad label
       Positioned(
         top: 40,
         left: 40,
         child: Container(
           padding: const EdgeInsets.symmetric(
             horizontal: 12,
             vertical: 6,
           ),
           decoration: BoxDecoration(
             color: Colors.black.withOpacity(0.6),
             borderRadius: BorderRadius.circular(12),
           ),
           child: const Text(
             "AD",
             style: TextStyle(
               color: Colors.white,
               fontWeight: FontWeight.bold,
               fontSize: 12,
             ),
           ),
         ),
       ),
     ],
   );
 }
 
 Widget _buildAdMedia() {
   if (widget.ad['type'] == 'video') {
     // In a real app, you would use a video player here
     // This is a placeholder for simplicity
     return Stack(
       alignment: Alignment.center,
       children: [
         // Placeholder image or thumbnail
         if (widget.ad['imageUrl'].isNotEmpty)
           CachedNetworkImage(
             imageUrl: widget.ad['imageUrl'],
             fit: BoxFit.cover,
             width: double.infinity,
             height: double.infinity,
             placeholder: (context, url) => Center(
               child: CircularProgressIndicator(
                 valueColor: AlwaysStoppedAnimation<Color>(
                   Theme.of(context).colorScheme.primary
                 ),
               ),
             ),
             errorWidget: (context, url, error) => Container(
               color: Colors.grey.shade900,
               child: const Icon(
                 Icons.broken_image,
                 color: Colors.white54,
                 size: 50,
               ),
             ),
           )
         else
           Container(
             color: Colors.grey.shade900,
           ),
           
         // Play button overlay
         Container(
           width: 70,
           height: 70,
           decoration: BoxDecoration(
             color: Colors.black.withOpacity(0.6),
             shape: BoxShape.circle,
           ),
           child: const Icon(
             Icons.play_arrow,
             color: Colors.white,
             size: 40,
           ),
         ),
       ],
     );
   } else {
     // Image ad
     return widget.ad['imageUrl'].isNotEmpty
       ? CachedNetworkImage(
           imageUrl: widget.ad['imageUrl'],
           fit: BoxFit.cover,
           width: double.infinity,
           height: double.infinity,
           placeholder: (context, url) => Center(
             child: CircularProgressIndicator(
               valueColor: AlwaysStoppedAnimation<Color>(
                 Theme.of(context).colorScheme.primary
               ),
             ),
           ),
           errorWidget: (context, url, error) => Container(
             color: Colors.grey.shade900,
             child: const Icon(
               Icons.broken_image,
               color: Colors.white54,
               size: 50,
             ),
           ),
         )
       : Container(
           color: Colors.grey.shade900,
           child: const Center(
             child: Icon(
               Icons.image,
               color: Colors.white54,
               size: 50,
             ),
           ),
         );
   }
 }
}