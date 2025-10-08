import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // 🔑 Replace with your WeatherAPI key
  final String apiKey = "61a7687ad34f459d9b372408250610";
  final String baseUrl = "https://api.weatherapi.com/v1/current.json";

  Future<Map<String, dynamic>?> fetchWeather(String cityName) async {
    try {
      final url = Uri.parse('$baseUrl?key=$apiKey&q=$cityName&aqi=no');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        print("❌ Failed to load weather data: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("⚠️ Error fetching weather: $e");
      return null;
    }
  }
}
