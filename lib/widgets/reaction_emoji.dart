//widgets/reaction_emoji.dart
import 'package:flutter/material.dart';
import 'package:cheevo/config/constants.dart';

class ReactionEmoji extends StatefulWidget {
  final String emoji;
  final Offset position;

  const ReactionEmoji({
    super.key,
    required this.emoji,
    required this.position,
  });

  @override
  State<ReactionEmoji> createState() => _ReactionEmojiState();
}

class _ReactionEmojiState extends State<ReactionEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: AppConstants.reactionDisplayDuration,
      vsync: this,
    );
    
    // Scale animation - more gentle
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.5, end: 1.2).chain(
          CurveTween(curve: Curves.easeOutCubic), // Smoother curve
        ),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8).chain(
          CurveTween(curve: Curves.easeInOut),
        ),
        weight: 20,
      ),
    ]).animate(_controller);
    
    // Opacity animation - more fluid fade out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeInCubic), // Smoother fade out
        ),
        weight: 30,
      ),
    ]).animate(_controller);
    
    // Position animation - smoother upward float
    _positionAnimation = Tween<Offset>(
      begin: widget.position,
      end: Offset(widget.position.dx, widget.position.dy - 80), // Less movement
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad, // Smoother curve
      ),
    );
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _positionAnimation.value.dx,
          top: _positionAnimation.value.dy,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.emoji,
                style: const TextStyle(
                  fontSize: 50,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}