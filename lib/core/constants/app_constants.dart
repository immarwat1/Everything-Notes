import 'package:flutter/material.dart';

class AppConstants {
  const AppConstants._();

  static const appName = 'Everything Notes Offline';
  static const tagline =
      'A powerful offline document editor and note-taking application.';

  static const primaryColor = Color(0xFF1565C0);
  static const accentColor = Color(0xFF00C853);
  static const darkBackground = Color(0xFF121212);
  static const errorColor = Color(0xFFD32F2F);

  static const autosaveInterval = Duration(seconds: 3);
}
