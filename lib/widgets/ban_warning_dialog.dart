//widgets/ban_warning_dialog.dart
import 'package:flutter/material.dart';
import 'package:cheevo/config/constants.dart';

class BanWarningDialog extends StatelessWidget {
  final int reportCount;
  final VoidCallback onAcknowledge;
  
  const BanWarningDialog({
    super.key,
    required this.reportCount,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Color(0xFF1F2547),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
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
            // Warning icon
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              "Warning: Risk of Ban",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Content
            Text(
              "Your account has received $reportCount ${reportCount == 1 ? 'report' : 'reports'} recently. Continued violation of our community guidelines may result in a temporary or permanent ban.",
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Guidelines reminder
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    "Please remember:",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "• Be respectful to other users\n• No inappropriate content\n• No harassment or hate speech",
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Acknowledge button
            GestureDetector(
              onTap: onAcknowledge,
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
                child: const Center(
                  child: Text(
                    "I Understand",
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
    );
  }
}