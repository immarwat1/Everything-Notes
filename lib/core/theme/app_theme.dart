import 'package:everything_notes_offline/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(Color accent) {
    return _base(
      ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        secondary: accent,
        error: AppConstants.errorColor,
        brightness: Brightness.light,
      ),
    );
  }

  static ThemeData dark(Color accent) {
    return _base(
      ColorScheme.fromSeed(
        seedColor: AppConstants.primaryColor,
        secondary: accent,
        error: AppConstants.errorColor,
        brightness: Brightness.dark,
      ).copyWith(surface: AppConstants.darkBackground),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
