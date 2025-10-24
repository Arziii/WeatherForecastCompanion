// lib/services/weather_services.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:developer' as developer; // For logging
import 'package:intl/intl.dart';

// ❌ MAKE SURE THERE IS NO LINE LIKE THIS:
// import 'package:weathercompanion/widgets/weather_card.dart';

class WeatherService {
  // WeatherAPI Key (keep for now, might switch back)
  final String _apiKey = "2a0ed89b3c6945dbbbd134308252110";
  final String _baseUrlWeatherAPI = "https://api.weatherapi.com/v1";

  // Open-Meteo base URL
  final String _baseUrlOpenMeteo = "https://api.open-meteo.com/v1";

  // --- WeatherAPI Fetch (Original) ---
  Future<Map<String, dynamic>?> fetchWeather(String city) async {
    final url =
        '$_baseUrlWeatherAPI/forecast.json?key=$_apiKey&q=$city&days=7&aqi=no&alerts=no';
    developer.log("Fetching WeatherAPI data from: $url", name: 'WeatherService');

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        developer.log("WeatherAPI data received successfully.", name: 'WeatherService');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        developer.log("Failed to load WeatherAPI data: ${response.statusCode}. Body: ${response.body}", name: 'WeatherService');
        return null;
      }
    } catch (e) {
      developer.log("Error fetching WeatherAPI data: $e", name: 'WeatherService', error: e);
      return null;
    }
  }

  // --- NEW: Open-Meteo Fetch ---
  Future<Map<String, dynamic>?> fetchWeatherOpenMeteo(double latitude, double longitude) async {
    final url = Uri.parse(
        '$_baseUrlOpenMeteo/forecast?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,uv_index'
        '&hourly=temperature_2m,precipitation_probability,weather_code,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max'
        '&timezone=auto' // Automatically detect timezone
    );
    developer.log("Fetching Open-Meteo data from: $url", name: 'WeatherService');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        developer.log("Open-Meteo data received successfully.", name: 'WeatherService');
        // We'll need to transform this data slightly to fit our app structure better
        return _transformOpenMeteoData(jsonDecode(response.body) as Map<String, dynamic>, latitude, longitude);
      } else {
         developer.log("Failed to load Open-Meteo data: ${response.statusCode}. Body: ${response.body}", name: 'WeatherService');
        return null;
      }
    } catch (e) {
       developer.log("Error fetching Open-Meteo data: $e", name: 'WeatherService', error: e);
      return null;
    }
  }

  // --- MODIFIED: Helper to Transform Open-Meteo Data ---
  Map<String, dynamic> _transformOpenMeteoData(Map<String, dynamic> data, double latitude, double longitude) {
    final current = data['current'] ?? {};
    final daily = data['daily'] ?? {};
    final hourly = data['hourly'] ?? {};
    final int utcOffsetSeconds = data['utc_offset_seconds'] ?? 0;
    // ✅ GET TIMEZONE ID
    final String timezoneId = data['timezone'] ?? 'UTC';

    developer.log("Open-Meteo Raw Data: Timezone ID = $timezoneId, UTC Offset = $utcOffsetSeconds seconds", name: 'WeatherService');

    // Calculate estimated local time string based on offset
    // This uses the device's UTC time + the offset from the API
    String estimatedLocalTimeString = DateTime.now().toUtc().add(Duration(seconds: utcOffsetSeconds)).toIso8601String();
    developer.log("Calculated Estimated Local Time String: $estimatedLocalTimeString", name: 'WeatherService');


    final Map<String, dynamic> transformed = {
      'location': {
        'name': 'Lat: ${latitude.toStringAsFixed(2)}, Lon: ${longitude.toStringAsFixed(2)}',
        'lat': latitude,
        'lon': longitude,
        // Provide the estimated local time string
        'localtime': estimatedLocalTimeString,
        // ✅ INCLUDE TIMEZONE ID
        'tz_id': timezoneId,
        'utc_offset_seconds': utcOffsetSeconds,
      },
      'current': {
        'temp_c': current['temperature_2m'],
        'condition': {
          'text': _getWeatherDescription(current['weather_code']),
          'icon': _getWeatherIconUrl(
              current['weather_code'],
              isDay: _isCurrentlyDay(daily, utcOffsetSeconds)
          ),
        },
        'humidity': current['relative_humidity_2m'],
        'wind_kph': current['wind_speed_10m'],
        'feelslike_c': current['apparent_temperature'],
        'uv': current['uv_index'],
        'precip_mm': current['precipitation'] ?? 0.0,
      },
      'forecast': {
        'forecastday': _buildForecastDays(daily, hourly, utcOffsetSeconds)
      }
    };
    developer.log("Transformed Open-Meteo Data contains keys: ${transformed.keys}", name: 'WeatherService');
    return transformed;
  }

  // --- Helper to check if it's currently daytime based on API data ---
   bool _isCurrentlyDay(Map<String, dynamic> daily, int utcOffsetSeconds) {
    // ... (rest of the function is the same) ...
     try {
      final sunriseTimes = daily['sunrise'] as List?;
      final sunsetTimes = daily['sunset'] as List?;
      if (sunriseTimes == null || sunsetTimes == null || sunriseTimes.isEmpty || sunsetTimes.isEmpty) {
        return true; // Default to day ifastro data missing
      }
      // Use the first day's sunrise/sunset
      final sunriseTodayStr = sunriseTimes[0] as String?;
      final sunsetTodayStr = sunsetTimes[0] as String?;

      if (sunriseTodayStr == null || sunsetTodayStr == null) return true;

      // Parse API times as UTC, compare with current UTC time
      final sunriseTimeUtc = DateTime.parse(sunriseTodayStr).toUtc();
      final sunsetTimeUtc = DateTime.parse(sunsetTodayStr).toUtc();
      final currentTimeUtc = DateTime.now().toUtc();

      developer.log("Day Check: SunriseUTC=$sunriseTimeUtc, SunsetUTC=$sunsetTimeUtc, CurrentUTC=$currentTimeUtc", name: 'WeatherService');

      return currentTimeUtc.isAfter(sunriseTimeUtc) && currentTimeUtc.isBefore(sunsetTimeUtc);
    } catch (e) {
      developer.log("Error determining day/night from astro data: $e", name: 'WeatherService', error: e);
      return true; // Default to day on error
    }
  }


  // --- MODIFIED: Build Forecast Days (pass offset) ---
  List<Map<String, dynamic>> _buildForecastDays(Map<String, dynamic> daily, Map<String, dynamic> hourly, int utcOffsetSeconds) {
     // ... (rest of the function is the same) ...
     List<Map<String, dynamic>> forecastDays = [];
    final dailyTimes = daily['time'] as List? ?? [];
    final hourlyTimes = hourly['time'] as List? ?? [];

    for (int i = 0; i < dailyTimes.length; i++) {
      String dateStr = dailyTimes[i];
      List<Map<String, dynamic>> dayHourlyData = [];

      // Find corresponding hourly data for this day
      for (int h = 0; h < hourlyTimes.length; h++) {
        if ((hourlyTimes[h] as String?)?.startsWith(dateStr) ?? false) {
          // Determine if the hour is day or night based on daily sunrise/sunset
          bool isHourDay = _isHourDay(hourlyTimes[h], daily, i);

          dayHourlyData.add({
            'time': hourlyTimes[h], // Keep original ISO string for parsing later
            'temp_c': (hourly['temperature_2m'] as List?)?[h],
            'chance_of_rain': (hourly['precipitation_probability'] as List?)?[h],
             'uv': (hourly['uv_index'] as List?)?[h],
            'condition': {
              'text': _getWeatherDescription((hourly['weather_code'] as List?)?[h]),
              'icon': _getWeatherIconUrl((hourly['weather_code'] as List?)?[h], isDay: isHourDay), // Use calculated day/night
            },
            // Add other hourly fields if needed
          });
        }
      }

       // Format sunrise/sunset to HH:MM (assuming API gives ISO string)
      String formattedSunrise = "N/A";
      String formattedSunset = "N/A";
      try {
        final sunriseStr = (daily['sunrise'] as List?)?[i] as String?;
        final sunsetStr = (daily['sunset'] as List?)?[i] as String?;
         // ✅ USE DateFormat HERE - Use local time conversion
        if (sunriseStr != null) formattedSunrise = DateFormat('HH:mm').format(DateTime.parse(sunriseStr).toLocal());
        // ✅ USE DateFormat HERE - Use local time conversion
        if (sunsetStr != null) formattedSunset = DateFormat('HH:mm').format(DateTime.parse(sunsetStr).toLocal());
      } catch (e) {
         developer.log("Error parsing sunrise/sunset for forecast day $i: $e", name: 'WeatherService');
      }


      forecastDays.add({
        'date': dateStr,
        'day': {
          'maxtemp_c': (daily['temperature_2m_max'] as List?)?[i],
          'mintemp_c': (daily['temperature_2m_min'] as List?)?[i],
          'daily_chance_of_rain': (daily['precipitation_probability_max'] as List?)?[i],
           'uv': (daily['uv_index_max'] as List?)?[i],
          'condition': {
            'text': _getWeatherDescription((daily['weather_code'] as List?)?[i]),
             // For daily icon, assume it represents the general condition for the day
            'icon': _getWeatherIconUrl((daily['weather_code'] as List?)?[i], isDay: true),
          },
          // Add other daily fields if needed (e.g., avgtemp_c, maxwind_kph)
           'avgtemp_c': ((daily['temperature_2m_max'] as List?)?[i] + (daily['temperature_2m_min'] as List?)?[i]) / 2.0, // Estimate avg temp
           // Note: Open-Meteo daily wind speed needs separate request parameter if needed
        },
        'astro': {
          'sunrise': formattedSunrise, // Use formatted HH:MM
          'sunset': formattedSunset,   // Use formatted HH:MM
        },
        'hour': dayHourlyData,
      });
    }
     developer.log("Built ${forecastDays.length} forecast days.", name: 'WeatherService');
    return forecastDays;
  }

 // --- Helper to check if a specific hour is during the day ---
 bool _isHourDay(String hourIsoString, Map<String, dynamic> daily, int dayIndex) {
    // ... (rest of the function is the same) ...
     try {
     final sunriseTimes = daily['sunrise'] as List?;
     final sunsetTimes = daily['sunset'] as List?;
     if (sunriseTimes == null || sunsetTimes == null || sunriseTimes.length <= dayIndex || sunsetTimes.length <= dayIndex) {
       return true; // Default to day if data missing
     }
     final sunriseStr = sunriseTimes[dayIndex] as String?;
     final sunsetStr = sunsetTimes[dayIndex] as String?;
     if (sunriseStr == null || sunsetStr == null) return true;

     final hourTimeUtc = DateTime.parse(hourIsoString).toUtc();
     final sunriseTimeUtc = DateTime.parse(sunriseStr).toUtc();
     final sunsetTimeUtc = DateTime.parse(sunsetStr).toUtc();

     return hourTimeUtc.isAfter(sunriseTimeUtc) && hourTimeUtc.isBefore(sunsetTimeUtc);
   } catch (e) {
     developer.log("Error checking if hour is day ($hourIsoString): $e", name: 'WeatherService');
     return true; // Default to day on error
   }
 }


  // --- NEW: Weather Code Mapping (Simplified) ---
  String _getWeatherDescription(dynamic code) {
     // ... (rest of the function is the same) ...
       // Ensure code is int
    int? intCode = (code is num) ? code.toInt() : int.tryParse(code?.toString() ?? '');
    if (intCode == null) return 'Unknown Code';

    switch (intCode) {
      case 0: return 'Clear sky';
      case 1: return 'Mainly clear';
      case 2: return 'Partly cloudy';
      case 3: return 'Overcast';
      case 45: return 'Fog';
      case 48: return 'Depositing rime fog';
      case 51: return 'Light drizzle';
      case 53: return 'Moderate drizzle';
      case 55: return 'Dense drizzle';
      case 56: return 'Light freezing drizzle';
      case 57: return 'Dense freezing drizzle';
      case 61: return 'Slight rain';
      case 63: return 'Moderate rain';
      case 65: return 'Heavy rain';
      case 66: return 'Light freezing rain';
      case 67: return 'Heavy freezing rain';
      case 71: return 'Slight snow fall';
      case 73: return 'Moderate snow fall';
      case 75: return 'Heavy snow fall';
      case 77: return 'Snow grains';
      case 80: return 'Slight rain showers';
      case 81: return 'Moderate rain showers';
      case 82: return 'Violent rain showers';
      case 85: return 'Slight snow showers';
      case 86: return 'Heavy snow showers';
      case 95: return 'Thunderstorm';
      case 96: return 'Thunderstorm, Slight hail';
      case 99: return 'Thunderstorm, Heavy hail';
      default: return 'Weather Code: $intCode'; // Show code if unknown
    }
  }

  // --- MODIFIED: Placeholder Icon URL using WeatherAPI CDN ---
   String _getWeatherIconUrl(dynamic code, {bool isDay = true}) {
     // ... (rest of the function is the same) ...
       String base = "//cdn.weatherapi.com/weather/64x64/"; // Keep protocol-relative
    base += isDay ? "day/" : "night/";

     // Ensure code is int
    int? intCode = (code is num) ? code.toInt() : int.tryParse(code?.toString() ?? '');
    if (intCode == null) return base + "119.png"; // Default cloudy


    switch (intCode) {
      // Clear / Sunny
      case 0: case 1: return base + "113.png";
      // Partly Cloudy
      case 2: return base + "116.png";
      // Cloudy / Overcast
      case 3: return base + "119.png";
       // Mist / Fog
      case 45: case 48: return base + "143.png"; // Or 248?
      // Drizzle / Light Rain
      case 51: case 53: case 55: case 56: case 57: return base + "176.png"; // Or 266?
      // Rain
      case 61: case 63: case 65: case 66: case 67: return base + "182.png"; // Or 296, 302, 308?
      // Snow
      case 71: case 73: case 75: case 77: return base + "227.png"; // Or 326, 332, 338?
      // Showers
      case 80: case 81: case 82: return base + "353.png"; // Rain shower
      case 85: case 86: return base + "368.png"; // Snow shower
      // Thunderstorm
      case 95: case 96: case 99: return base + "200.png"; // Or 386, 389?

      default: return base + "119.png"; // Default cloudy
    }
   }
} // End of WeatherService class