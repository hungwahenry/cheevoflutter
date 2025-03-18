//widgets/animated_background.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  
  @override
  void initState() {
    super.initState();
    
    _controller1 = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _controller2 = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base gradient background
        // Base gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF0A0E21),
                const Color(0xFF121638),
              ],
            ),
          ),
        ),
        
        // Animated wave patterns
        AnimatedBuilder(
          animation: _controller1,
          builder: (context, child) {
            return CustomPaint(
              painter: WavePatternPainter(
                animation: _controller1.value,
                color1: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                color2: Theme.of(context).colorScheme.secondary.withOpacity(0.05),
              ),
              size: Size.infinite,
            );
          },
        ),
        
        // Animated dots
        AnimatedBuilder(
          animation: _controller2,
          builder: (context, child) {
            return CustomPaint(
              painter: DotPatternPainter(
                animation: _controller2.value,
                color: Colors.white.withOpacity(0.1),
              ),
              size: Size.infinite,
            );
          },
        ),
      ],
    );
  }
}

class WavePatternPainter extends CustomPainter {
  final double animation;
  final Color color1;
  final Color color2;
  
  WavePatternPainter({
    required this.animation,
    required this.color1,
    required this.color2,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // First wave
    final paint1 = Paint()
      ..color = color1
      ..style = PaintingStyle.fill;
    
    final path1 = Path();
    
    path1.moveTo(0, size.height * 0.5);
    
    for (double x = 0; x <= size.width; x += 1) {
      final y = math.sin((x / size.width * 4 * math.pi) + (animation * 2 * math.pi)) * 
                size.height * 0.1 + size.height * 0.5;
      path1.lineTo(x, y);
    }
    
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    
    canvas.drawPath(path1, paint1);
    
    // Second wave
    final paint2 = Paint()
      ..color = color2
      ..style = PaintingStyle.fill;
    
    final path2 = Path();
    
    path2.moveTo(0, size.height * 0.7);
    
    for (double x = 0; x <= size.width; x += 1) {
      final y = math.cos((x / size.width * 3 * math.pi) + (animation * 2 * math.pi)) * 
                size.height * 0.08 + size.height * 0.7;
      path2.lineTo(x, y);
    }
    
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    
    canvas.drawPath(path2, paint2);
  }
  
  @override
  bool shouldRepaint(WavePatternPainter oldDelegate) => 
      oldDelegate.animation != animation;
}

class DotPatternPainter extends CustomPainter {
  final double animation;
  final Color color;
  
  DotPatternPainter({
    required this.animation,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    final dotCount = 50;
    final baseRadius = 2.0;
    
    for (int i = 0; i < dotCount; i++) {
      final progress = (animation + i / dotCount) % 1.0;
      final x = math.sin(i * 0.15) * size.width * 0.4 + size.width * 0.5;
      final y = (progress * size.height * 1.2) - size.height * 0.1;
      
      final radius = baseRadius * (1 - (y / size.height));
      
      if (y >= 0 && y <= size.height) {
        canvas.drawCircle(
          Offset(x, y),
          radius,
          paint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(DotPatternPainter oldDelegate) => 
      oldDelegate.animation != animation;
}