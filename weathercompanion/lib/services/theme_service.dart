// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Enum to represent theme options
enum ThemeModeSetting { system, light, dark }

// Defines our app's light and dark themes
class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: Colors.indigo,
    scaffoldBackgroundColor: const Color(0xFFF0F2F5), // A light grey
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
    ),
    cardColor: Colors.white,
    colorScheme: ColorScheme.light(
      primary: Colors.indigo,
      secondary: Colors.indigoAccent,
      onBackground: Colors.black, // Main text
      onSurface: Colors.black, // Text on cards
      surface: Colors.white, // Card background
      onSecondaryContainer: Colors.black87, // Text in textfield
      secondaryContainer: Colors.grey.shade200, // Textfield fill
    ),
    textTheme: Typography.blackMountainView.apply(
      bodyColor: Colors.black87,
      displayColor: Colors.black,
    ),
    iconTheme: const IconThemeData(color: Colors.black87),
    dialogBackgroundColor: Colors.white,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF3F51B5), // Existing AppBar color
    scaffoldBackgroundColor: const Color(0xFF3949AB), // Existing background
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF3F51B5),
      foregroundColor: Colors.white,
    ),
    cardColor: Colors.white.withOpacity(0.1), // Existing card color
    colorScheme: ColorScheme.dark(
      primary: const Color(0xFF3F51B5),
      secondary: Colors.indigoAccent,
      onBackground: Colors.white, // Main text
      onSurface: Colors.white, // Text on cards
      surface: Colors.white.withOpacity(0.1), // Card background
      onSecondaryContainer: Colors.white, // Text in textfield
      secondaryContainer: Colors.white.withOpacity(0.2), // Textfield fill
    ),
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    dialogBackgroundColor: const Color(0xFF3949AB),
  );
}

// Service to manage loading/saving the theme preference
class ThemeService with ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  ThemeModeSetting _themeModeSetting = ThemeModeSetting.system;

  ThemeService() {
    loadTheme();
  }

  // Gets the Flutter ThemeMode from our setting
  ThemeMode get themeMode {
    switch (_themeModeSetting) {
      case ThemeModeSetting.light:
        return ThemeMode.light;
      case ThemeModeSetting.dark:
        return ThemeMode.dark;
      case ThemeModeSetting.system:
      default:
        return ThemeMode.system;
    }
  }

  // Gets our raw enum value
  ThemeModeSetting get themeModeSetting => _themeModeSetting;

  // Loads the saved preference from SharedPreferences
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString =
        prefs.getString(_themeKey) ?? ThemeModeSetting.system.name;
    _themeModeSetting = ThemeModeSetting.values.firstWhere(
      (e) => e.name == themeString,
      orElse: () => ThemeModeSetting.system,
    );
    notifyListeners();
  }

  // Saves the new theme preference
  Future<void> setTheme(ThemeModeSetting mode) async {
    if (mode == _themeModeSetting) return;
    _themeModeSetting = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
    notifyListeners();
  }
}
