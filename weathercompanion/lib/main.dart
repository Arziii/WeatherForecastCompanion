// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
//
//  THIS IS THE FIX
//
import 'package:weathercompanion/screens/splash_screen.dart'; // Removed the extra 'package'

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

  runApp(const WeatherCompanionApp());
}

class WeatherCompanionApp extends StatelessWidget {
  const WeatherCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeatherCompanion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const SplashScreen(),
    );
  }
}