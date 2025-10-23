// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:weathercompanion/screens/home_screen.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6A82FB), // Lighter blue
              Color(0xFF3F51B5), // Indigo
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // *** Header Section Start ***
              Image.asset('assets/images/logo.png',
                  width: 110, height: 110), // Slightly larger logo
              const SizedBox(height: 25),
              // Main Title Style
              Text(
                'Weather Companion',
                textAlign: TextAlign.center, // Ensure center alignment
                style: TextStyle(
                  fontSize: 34, // Increased size
                  fontWeight: FontWeight.bold, // Keep bold
                  color: Colors.white,
                  // ✅ Add a subtle shadow for depth
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(2.0, 2.0),
                    ),
                  ],
                  letterSpacing: 1.2, // Add slight letter spacing
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle Style
              Text(
                'Weather Forecast with AI Integration',
                textAlign: TextAlign.left, // Ensure center alignment
                style: TextStyle(
                  fontSize: 12, // Slightly larger subtitle
                  color: Colors.white
                      .withOpacity(0.85), // Make it slightly brighter
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.8, // Add subtle letter spacing
                  // You could add a lighter shadow if desired
                  // shadows: [
                  //   Shadow(
                  //     blurRadius: 5.0,
                  //     color: Colors.black.withOpacity(0.2),
                  //     offset: Offset(1.0, 1.0),
                  //   ),
                  // ],
                ),
              ),
              // *** Header Section End ***

              const SizedBox(height: 50), // Increased space before indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3.0, // Slightly thinner indicator
              ),
            ],
          ),
        ),
      ),
    );
  }
}
