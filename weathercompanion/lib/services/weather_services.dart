// lib/services/weather_services.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode

class WeatherService {
  // 🔴 IMPORTANT: Make sure your API key is in here!
  final String _apiKey = "2a0ed89b3c6945dbbbd134308252110";
  final String _baseUrl = "https://api.weatherapi.com/v1";

  Future<Map<String, dynamic>?> fetchWeather(String city) async {
    //
    // ✅ HERE IS THE CHANGE: We set `days=7`
    //
    final url =
        '$_baseUrl/forecast.json?key=$_apiKey&q=$city&days=7&aqi=no&alerts=no';

    if (kDebugMode) {
      print("Fetching weather from: $url");
    }

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print("Failed to load weather: ${response.statusCode}");
          print("Response body: ${response.body}");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("An error occurred: $e");
      }
      return null;
    }
  }

  // ... any other functions you have in this file ...
}