//widgets/gradient_button.dart
import 'package:flutter/material.dart';
import 'package:cheevo/config/constants.dart';

class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed; // Change to nullable VoidCallback
  final Widget child;
  final double width;
  final double height;
  final Gradient gradient;
  final BorderRadius? borderRadius;
  
  const GradientButton({
    super.key,
    required this.onPressed, // Now accepts nullable callback
    required this.child,
    this.width = double.infinity,
    this.height = 56.0,
    required this.gradient,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed, // GestureDetector naturally handles null callbacks
      child: Opacity(
        opacity: onPressed == null ? 0.6 : 1.0, // Add opacity when disabled
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: borderRadius ?? BorderRadius.circular(AppConstants.buttonCornerRadius),
            boxShadow: onPressed != null ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ] : null, // Remove shadow when disabled
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}