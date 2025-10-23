// lib/services/ai_greeting_service.dart

import 'dart:developer' as developer;
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';

class AiGreetingService {
  final Gemini _gemini = Gemini.instance;
  // ✅ Using gemini-pro, compatible with v1beta used by flutter_gemini 2.0.5
  final String _modelName = 'gemini-pro';

  String _getHourGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 4) return "early morning"; // 12 AM - 3:59 AM
    if (hour < 12) return "morning"; // 4 AM - 11:59 AM
    if (hour < 13) return "midday"; // 12 PM - 12:59 PM
    if (hour < 17) return "afternoon"; // 1 PM - 4:59 PM
    if (hour < 21) return "evening"; // 5 PM - 8:59 PM
    return "night"; // 9 PM - 11:59 PM
  }

  String _buildPrompt(String weather, String city, double temp, DateTime localTime) {
    // Format the time
    final String timeOfDay = _getHourGreeting(localTime); // e.g., "afternoon"
    final String formattedTime = DateFormat('h:mm a').format(localTime); // e.g., "1:40 PM"
    final String dayOfWeek = DateFormat('EEEE').format(localTime); // e.g., "Thursday"
    developer.log("Raw DateTime object received: $localTime");

    final String fullPrompt = """
    You are WeatherCompanion, a friendly AI buddy.

    **CRITICAL TASK:** Generate a 2-3 sentence, conversational greeting for your friend in $city.

    **CRITICAL DATA (You MUST use this):**
    - Location: $city
    - Temperature: ${temp.round()}°C
    - Weather: $weather
    - Current Time: $formattedTime ($timeOfDay) on $dayOfWeek

    **RULES (You MUST follow these):**
    1.  **Your greeting MUST be 100% appropriate for the time ($formattedTime ($timeOfDay)).** For example, if the time is "11:23 PM (PHT)", you MUST say "Good evening" or "Getting late." You MUST NOT say "Good afternoon."
    2.  Casually mention the city ($city) AND the weather ($weather or ${temp.round()}°C).
    3.  Sound like a real, caring friend. Vary your opening and sentence structure.
    4.  Give a brief, *time-appropriate* piece of advice.
    5.  Address the user as "Companion" at least once.
    6.  Don't make just a weather report—make it friendly and engaging!
    7. ALWAYS use the temperature in °C.
    8. NEVER mention "weather data" or "context".
    """;
    developer.log("Sending full AI prompt: $fullPrompt");
    return fullPrompt;
  }

  Future<String> generateGreeting(String weather, String city, double temp, DateTime localTime) async {
    final fullPrompt = _buildPrompt(weather, city, temp, localTime);
    try {
      // ✅ FIX: Switched from gemini.chat() to gemini.text()
      final response = await _gemini.text(
        fullPrompt,
        modelName: _modelName,
      );

      // ✅ FIX: Access output differently for .text() (using .output is simpler here)
      final greeting = response?.output ?? "Hello! Have a great day.";

      developer.log("AI Greeting received: $greeting");
      return greeting;
    } catch (e) {
      developer.log('Gemini Greeting Error: $e', name: 'AiGreetingService');
      return "Hello, Companion! Having trouble fetching a friendly greeting, but I hope you have a great day!";
    }
  }
}