//screens/permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cheevo/services/permissions_service.dart';
import 'package:cheevo/widgets/gradient_button.dart';
import 'package:cheevo/widgets/animated_background.dart';
import 'package:cheevo/screens/video_call_screen.dart';
import 'package:cheevo/config/constants.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _isCameraGranted = false;
  bool _isMicrophoneGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    setState(() {
      _isCameraGranted = cameraStatus.isGranted;
      _isMicrophoneGranted = microphoneStatus.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _requestPermissions() async {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isLoading = true;
    });

    final granted = await _permissionsService.requestVideoChatPermissions();
    
    setState(() {
      _isCameraGranted = granted;
      _isMicrophoneGranted = granted;
      _isLoading = false;
    });
    
    if (granted) {
      // Delay slightly for the success state to be visible
      await Future.delayed(const Duration(milliseconds: 300));
      _navigateToVideoCall();
    }
  }

  void _navigateToVideoCall() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const VideoCallScreen(),
        transitionDuration: AppConstants.pageTransitionDuration,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allPermissionsGranted = _isCameraGranted && _isMicrophoneGranted;
    
    return Scaffold(
      body: Stack(
        children: [
          // Animated background
          const AnimatedBackground(),
          
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App logo at top
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Image.asset(
                      'assets/images/cheevo_logo.png',
                      width: 120,
                      height: 50,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Title
                  Text(
                    "Camera & Microphone Access",
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Description
                  Text(
                    "Cheevo needs access to your camera and microphone to enable video chats with other users.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const Spacer(),
                  
                  // Permissions status
                  _buildPermissionItem(
                    icon: Icons.camera_alt,
                    title: "Camera",
                    isGranted: _isCameraGranted,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildPermissionItem(
                    icon: Icons.mic,
                    title: "Microphone",
                    isGranted: _isMicrophoneGranted,
                  ),
                  
                  const Spacer(),
                  
                  // Action button
                  _isLoading
                    ? const CircularProgressIndicator()
                    : GradientButton(
                        onPressed: allPermissionsGranted ? _navigateToVideoCall : _requestPermissions,
                        width: double.infinity,
                        height: 56,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        child: Text(
                          allPermissionsGranted ? "Continue" : "Grant Access",
                          style: const TextStyle(
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
  
  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required bool isGranted,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isGranted ? Colors.green : Colors.orange,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isGranted
                      ? "Granted"
                      : "Required for video chats",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.arrow_forward_ios,
            color: isGranted ? Colors.green : Colors.white.withOpacity(0.5),
            size: isGranted ? 24 : 16,
          ),
        ],
      ),
    );
  }
}