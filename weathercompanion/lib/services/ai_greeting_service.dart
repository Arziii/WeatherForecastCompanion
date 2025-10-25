// lib/services/ai_greeting_service.dart

import 'dart:developer' as developer;
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';

class AiGreetingService {
  final Gemini _gemini = Gemini.instance;
  // Using gemini-pro, compatible with v1beta used by flutter_gemini 3.0.0
  // final String _modelName = 'gemini-pro'; // Not needed for gemini.text

  String _getHourGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 4) return "early morning"; // 12 AM - 3:59 AM
    if (hour < 12) return "morning"; // 4 AM - 11:59 AM
    if (hour < 13) return "midday"; // 12 PM - 12:59 PM
    if (hour < 17) return "afternoon"; // 1 PM - 4:59 PM
    if (hour < 21) return "evening"; // 5 PM - 8:59 PM
    return "night"; // 9 PM - 11:59 PM
  }

  // ✅ MODIFIED: Added forecastDays parameter and context
  String _buildPrompt(String weather, String city, double temp,
      DateTime localTime, List<dynamic> forecastDays) {
    final String timeOfDay = _getHourGreeting(localTime);
    final String formattedTime = DateFormat('h:mm a').format(localTime);
    final String dayOfWeek = DateFormat('EEEE').format(localTime);

    // Build forecast summary
    String forecastSummary = "";
    if (forecastDays.isNotEmpty) {
      forecastSummary = "\n- Upcoming Forecast Summary:\n";
      // Use sublist(1) to skip today, take up to 3 days
      final daysToSummarize = forecastDays.length > 1
          ? forecastDays.sublist(1)
          : forecastDays; // If only 1 day, show it
      for (var dayData in daysToSummarize.take(3)) {
        // Limit to next 3 days for brevity
        final day = dayData['day'] ?? {};
        final date = dayData['date'] ?? 'Unknown Date';
        final condition = day['condition']?['text'] ?? 'No condition';
        final maxTemp = (day['maxtemp_c'] as num?)?.round() ?? 'N/A';
        final minTemp = (day['mintemp_c'] as num?)?.round() ?? 'N/A';
        forecastSummary +=
            "  - ${DateFormat('EEE, MMM d').format(DateTime.parse(date))}: $condition ($maxTemp°C/$minTemp°C)\n";
      }
    }

    final String fullPrompt = """
    You are WeatherCompanion, a friendly AI buddy.

    **CRITICAL TASK:** Generate a 2-3 sentence, conversational greeting for your friend.

    **CRITICAL DATA (You MUST use this):**
    - Location: $city
    - Temperature: ${temp.round()}°C
    - Weather: $weather
    - Current Time: $formattedTime ($timeOfDay) on $dayOfWeek
    $forecastSummary

    **RULES (You MUST follow these):**
    1.  **Your greeting MUST be 100% appropriate for the time ($formattedTime ($timeOfDay)).** For example, if the time is "2:54 PM (PST)", you MUST say "Good afternoon." You MUST NOT say "Good morning."
    2.  Casually mention the city ($city) AND the current weather ($weather or ${temp.round()}°C).
    3.  Sound like a real, caring friend. Vary your opening and sentence structure.
    4.  Give a brief, *time-appropriate* piece of advice, maybe referencing the current conditions or the near-term forecast summary.
    5.  Address the user as "Companion" at least once.
    6.  Don't make just a weather report—make it friendly and engaging!
    7. ALWAYS use the temperature in °C.
    8. NEVER mention "weather data", "context", or "forecast summary".
    """;
    developer.log("Sending full AI prompt for greeting: $fullPrompt");
    return fullPrompt;
  }

  // ✅ MODIFIED: Added forecastDays parameter
  Future<String> generateGreeting(String weather, String city, double temp,
      DateTime localTime, List<dynamic> forecastDays) async {
    final fullPrompt =
        _buildPrompt(weather, city, temp, localTime, forecastDays); // Pass forecast data
    try {
      final response = await _gemini.text(
        fullPrompt,
        // modelName: _modelName, // Not needed
      );

      final greeting = response?.output?.trim() ?? "Hello! Have a great day.";

      developer.log("AI Greeting received: $greeting");
      return greeting;
    } catch (e) {
      developer.log('Gemini Greeting Error: $e', name: 'AiGreetingService');
      return "Hello, Companion! Having trouble fetching a friendly greeting, but I hope you have a great day!";
    }
  }
}