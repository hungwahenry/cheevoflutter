//services/permission_service.dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  // Check if camera and microphone permissions are granted
  Future<bool> checkVideoChatPermissions() async {
    if (Platform.isIOS) {
      // iOS often asks for permissions when they're first used, so check individually
      final camera = await Permission.camera.status;
      final microphone = await Permission.microphone.status;
      
      // For iOS, consider "not determined" as needing permission request
      return (camera.isGranted || camera.isLimited) && 
             (microphone.isGranted || microphone.isLimited);
    } else {
      // Regular check for Android
      final camera = await Permission.camera.status;
      final microphone = await Permission.microphone.status;
      
      return camera.isGranted && microphone.isGranted;
    }
  }

  // Request camera and microphone permissions
  Future<bool> requestVideoChatPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    
    return statuses[Permission.camera]!.isGranted && 
           statuses[Permission.microphone]!.isGranted;
  }
}