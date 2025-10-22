// lib/services/ai_greeting_service.dart
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class AiGreetingService {
  final Gemini _gemini = Gemini.instance;

  Future<String> generateGreeting(
    String weatherDescription,
    String city,
    double temp,
    DateTime currentTime,
  ) async {
    //
    // ✅ --- HERE IS THE FIX ---
    //
    // 1. Explicitly get the local DateTime object
    final DateTime localTime = currentTime.toLocal();

    // 2. Format the local time AND include the timezone abbreviation (zzzz)
    final String formattedTime = DateFormat(
      'h:mm a (zzzz)',
    ).format(localTime); // e.g., "11:23 PM (PHT)"
    final String dayOfWeek = DateFormat(
      'EEEE',
    ).format(localTime); // e.g., "Tuesday"
    //
    // ✅ --- END OF FIX ---
    //

    final String fullPrompt =
        """
    You are WeatherCompanion, a friendly AI buddy.

    **CRITICAL TASK:** Generate a 2-3 sentence, conversational greeting for your friend in $city.

    **CRITICAL DATA (You MUST use this):**
    - Location: $city
    - Temperature: ${temp.round()}°C
    - Weather: $weatherDescription
    - Current Time: $formattedTime on $dayOfWeek 
      
    **RULES (You MUST follow these):**
    1.  **Your greeting MUST be 100% appropriate for the time ($formattedTime).** For example, if the time is "11:23 PM (PHT)", you MUST say "Good evening" or "Getting late." You MUST NOT say "Good afternoon."
    2.  Casually mention the city ($city) AND the weather ($weatherDescription or ${temp.round()}°C).
    3.  Sound like a real, caring friend. Vary your opening and sentence structure.
    4.  Give a brief, *time-appropriate* piece of advice.
    5.  Address the user as "Companion" at least once.
    6.  Don't make just a weather report—make it friendly and engaging!
    7. ALWAYS use the temperature in °C.
    8. NEVER mention "weather forecast" or "weather report."
    9. Dont necessarily start with "Hello" or "Hi", be more creative.
    10. Use contractions to sound more natural (e.g., "it's" instead of "it is").
    11. Don't repeat the time or day of the week in the greeting.
    12. Don't repeat what the user already knows.
    13. Don't mention the City as the location only, use it naturally in the conversation.
    **Example for 11:23 PM (PHT):**
    "Hey $city! Getting late, isn't it? It's a mild ${temp.round()}°C out there with $weatherDescription. Hope you're winding down for the night!"

    Now, generate the greeting based on the critical data.
    """;

    if (kDebugMode) {
      // ✅ Added a new debug print so you can see the raw object
      print("Raw DateTime object received: $currentTime");
      print("Sending full AI prompt: $fullPrompt");
    }

    try {
      final response = await _gemini.chat([
        Content(parts: [Part.text(fullPrompt)], role: 'user'),
      ], modelName: 'gemini-1.5-flash-latest');

      String? greeting = response?.output;

      if (greeting != null && greeting.isNotEmpty) {
        if (kDebugMode) {
          print("AI Greeting received: $greeting");
        }
        return greeting.replaceAll('"', '').trim();
      } else {
        if (kDebugMode) {
          print("AI returned null or empty response.");
        }
        return "Hey! Seeing ${weatherDescription.toLowerCase()} in $city right now ($formattedTime). Have a good one!";
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error getting AI greeting: $e");
      }
      return "Hey there! My time circuits are down for $city ($formattedTime), but stay safe!";
    }
  }
}
