//comfig/theme.dart
import 'package:flutter/material.dart';

// Modern playful color scheme that isn't too Material UI
final cheevoTheme = ThemeData(
  fontFamily: 'Poppins',
  primaryColor: const Color(0xFF5E60CE), // Vibrant purple
  scaffoldBackgroundColor: const Color(0xFF0A0E21), // Dark deep blue
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF5E60CE), // Vibrant purple
    secondary: Color(0xFF64DFDF), // Bright teal
    tertiary: Color(0xFFFF7477), // Dark deep blue
    surface: Color(0xFF1A1F38), // Slightly lighter blue
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 16,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 14,
      color: Colors.white70,
    ),
  ),
  useMaterial3: true,
);