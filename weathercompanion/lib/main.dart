// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:weathercompanion/screens/splash_screen.dart';
import 'package:weathercompanion/services/theme_service.dart'; // Import ThemeService

//
//  PASTE YOUR API KEY HERE
//
const String geminikey = "AIzaSyDRXmCeqy9QuFihb28GqVN_z3JNRX95Dms";
//
//

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ADD THIS
  Gemini.init(
      apiKey: geminikey,
      // ✅ FIX: Removed the model/modelName parameter. It's not in v2.0.5
      enableDebugging: true // We can turn this off later
      );

  // Wrap the app in our new ThemeService provider
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const WeatherCompanionApp(),
    ),
  );
}

class WeatherCompanionApp extends StatelessWidget {
  const WeatherCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the service to get theme updates
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'WeatherCompanion',
          debugShowCheckedModeBanner: false,

          // Use the themes defined in our service
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeService.themeMode,

          home: const SplashScreen(),
        );
      },
    );
  }
}
