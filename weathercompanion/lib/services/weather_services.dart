import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = "61a7687ad34f459d9b372408250610";
  final String baseUrl = "https://api.weatherapi.com/v1/forecast.json";

  /// 🌤 Fetch weather by city name (7-day forecast)
  Future<Map<String, dynamic>?> fetchWeather(String cityName) async {
    final url = "$baseUrl?key=$apiKey&q=$cityName&days=7&aqi=no&alerts=no";
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("❌ Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("⚠️ Exception in fetchWeather: $e");
      return null;
    }
  }

  /// 📍 Fetch weather by GPS coordinates (latitude, longitude)
  Future<Map<String, dynamic>?> fetchWeatherByCoords(
    double lat,
    double lon,
  ) async {
    final url = "$baseUrl?key=$apiKey&q=$lat,$lon&days=7&aqi=no&alerts=no";
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print("❌ Error fetching by coordinates: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("⚠️ Exception in fetchWeatherByCoords: $e");
      return null;
    }
  }
}
