// lib/services/weather_services.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:developer' as developer; // For logging
import 'package:intl/intl.dart';

class WeatherService {
  // Open-Meteo base URL
  final String _baseUrlOpenMeteo = "https://api.open-meteo.com/v1";

  // --- NEW: Open-Meteo Fetch ---
  Future<Map<String, dynamic>?> fetchWeatherOpenMeteo(
      double latitude, double longitude) async {
    final url = Uri.parse(
        '$_baseUrlOpenMeteo/forecast?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,uv_index'
        '&hourly=temperature_2m,precipitation_probability,weather_code,uv_index'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max'
        '&timezone=auto' // Automatically detect timezone
        );
    developer.log("Fetching Open-Meteo data from: $url",
        name: 'WeatherService');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        developer.log("Open-Meteo data received successfully.",
            name: 'WeatherService');

        // <-- ***** FIX FUNCTION CALL ***** -->
        // Only pass the decoded JSON map, not latitude and longitude
        return _transformOpenMeteoData(
            jsonDecode(response.body) as Map<String, dynamic>);
        // <-- ***** END FIX ***** -->

      } else {
        developer.log(
            "Failed to load Open-Meteo data: ${response.statusCode}. Body: ${response.body}",
            name: 'WeatherService');
        return null;
      }
    } catch (e) {
      developer.log("Error fetching Open-Meteo data: $e",
          name: 'WeatherService', error: e);
      return null;
    }
  }

 Map<String, dynamic> _transformOpenMeteoData(Map<String, dynamic> openMeteoData) {
    developer.log(
        '[WeatherService] Transforming Open-Meteo data...',
        name: 'WeatherService');

    final currentData = openMeteoData['current'] ?? {};
    final dailyData = openMeteoData['daily'] ?? {};
    final hourlyData = openMeteoData['hourly'] ?? {};

    // --- Timezone and Local Time Handling ---
    final String timezoneId = openMeteoData['timezone'] ?? 'UTC';
    final int utcOffsetSeconds = openMeteoData['utc_offset_seconds'] ?? 0;
    developer.log(
        '[WeatherService] Open-Meteo Raw Data: Timezone ID = $timezoneId, UTC Offset = $utcOffsetSeconds seconds',
        name: 'WeatherService');

    // Estimate local time based on current UTC and offset
    final DateTime currentUtcTime = DateTime.now().toUtc();
    final DateTime estimatedLocalTime =
        currentUtcTime.add(Duration(seconds: utcOffsetSeconds));
    final String estimatedLocalIsoString =
        estimatedLocalTime.toIso8601String(); // Keep as ISO string for parsing later
    developer.log(
        '[WeatherService] Calculated Estimated Local Time String: $estimatedLocalIsoString',
        name: 'WeatherService');
    // --- End Timezone Handling ---


    // --- Day/Night Calculation (used for icons) ---
    final List<String>? sunriseTimes = (dailyData['sunrise'] as List?)?.cast<String>();
    final List<String>? sunsetTimes = (dailyData['sunset'] as List?)?.cast<String>();
    bool isDay = true; // Default to day

    if (sunriseTimes != null && sunriseTimes.isNotEmpty && sunsetTimes != null && sunsetTimes.isNotEmpty) {
      try {
        DateTime sunriseUTC = DateTime.parse(sunriseTimes[0]).toUtc(); // Assuming first day's sunrise
        DateTime sunsetUTC = DateTime.parse(sunsetTimes[0]).toUtc();   // Assuming first day's sunset
        developer.log(
            '[WeatherService] Day Check: SunriseUTC=${sunriseUTC}, SunsetUTC=${sunsetUTC}, CurrentUTC=${currentUtcTime}',
            name: 'WeatherService');
        isDay = currentUtcTime.isAfter(sunriseUTC) && currentUtcTime.isBefore(sunsetUTC);
      } catch (e) {
        developer.log('[WeatherService] Error parsing sunrise/sunset UTC for Day Check: $e', name: 'WeatherService', error: e);
        // Keep default isDay = true on error
      }
    } else {
         developer.log('[WeatherService] Sunrise/Sunset data missing or invalid for Day Check.', name: 'WeatherService');
    }
    // --- End Day/Night Calculation ---


    // --- Weather Condition Mapping (WMO to Description and OpenWeatherMap Icon Code) ---
    final int weatherCode = (currentData['weather_code'] as num?)?.toInt() ?? 0;
    final Map<String, String> condition = _mapWeatherCode(weatherCode);


    // Construct the OpenWeatherMap icon URL using the calculated `isDay` and the mapped code
    String iconCode = condition['iconCode'] ?? '01'; // Default to clear sky
    String dayNightSuffix = isDay ? 'd' : 'n'; // Use 'd' for day, 'n' for night
    String iconUrl = 'https://openweathermap.org/img/wn/$iconCode$dayNightSuffix@2x.png';
    developer.log('[WeatherService] Icon Selection: Code=$weatherCode -> OWM Code=$iconCode, isDay=$isDay -> URL=$iconUrl', name: 'WeatherService');


    // Transform current weather
    final Map<String, dynamic> transformedCurrent = {
      'temp_c': (currentData['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      'condition': {
        'text': condition['description'] ?? 'Unknown',
        'icon': iconUrl, // Use the correctly constructed URL
        'code': weatherCode // Keep original WMO code if needed elsewhere
      },
      'wind_kph': (currentData['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      'humidity': (currentData['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      'feelslike_c': (currentData['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
      'uv': (currentData['uv_index'] as num?)?.toDouble() ?? 0.0,
      // Pass the service's potentially incorrect is_day flag, we override it in HomeScreen anyway
      'is_day': isDay ? 1 : 0,
    };

    // Transform hourly forecast
    final List<Map<String, dynamic>> transformedHourly = [];
    final List<String>? hourlyTimes = (hourlyData['time'] as List?)?.cast<String>();
    final List<num>? hourlyTemps = (hourlyData['temperature_2m'] as List?)?.cast<num>();
    final List<num>? hourlyPrecipProb = (hourlyData['precipitation_probability'] as List?)?.cast<num>();
    final List<num>? hourlyWeatherCodes = (hourlyData['weather_code'] as List?)?.cast<num>();

    if (hourlyTimes != null) {
      for (int i = 0; i < hourlyTimes.length; i++) {
         // Basic Day/Night check for hourly icon
         DateTime? hourlyTimeUTC = DateTime.tryParse(hourlyTimes[i])?.toUtc();
         bool hourlyIsDay = true; // Default
         if (hourlyTimeUTC != null && sunriseTimes != null && sunsetTimes != null && sunriseTimes.isNotEmpty && sunsetTimes.isNotEmpty) {
             try {
                DateTime sunriseUTC = DateTime.parse(sunriseTimes[0]).toUtc();
                DateTime sunsetUTC = DateTime.parse(sunsetTimes[0]).toUtc();
                // Simple check against today's sunrise/sunset
                hourlyIsDay = hourlyTimeUTC.isAfter(sunriseUTC) && hourlyTimeUTC.isBefore(sunsetUTC);
             } catch (_) { /* Ignore parse error for hourly */ }
         }

         final int hourlyCode = hourlyWeatherCodes?[i].toInt() ?? 0;
         final Map<String, String> hourlyConditionMap = _mapWeatherCode(hourlyCode);
         final String hourlyIconCode = hourlyConditionMap['iconCode'] ?? '01';
         final String hourlyDayNightSuffix = hourlyIsDay ? 'd' : 'n';
         final String hourlyIconUrl = 'https://openweathermap.org/img/wn/$hourlyIconCode$hourlyDayNightSuffix@2x.png';


        transformedHourly.add({
          'time': hourlyTimes[i],
          'temp_c': hourlyTemps?[i].toDouble() ?? 0.0,
          'condition': {
             'text': hourlyConditionMap['description'] ?? 'Unknown',
             'icon': hourlyIconUrl, // Use day/night specific icon
             'code': hourlyCode,
          },
          'precip_chance': hourlyPrecipProb?[i].toInt() ?? 0,
        });
      }
    }


    // Transform daily forecast
    final List<Map<String, dynamic>> transformedDaily = [];
    final List<String>? dailyDates = (dailyData['time'] as List?)?.cast<String>();
    final List<num>? dailyMaxTemps = (dailyData['temperature_2m_max'] as List?)?.cast<num>();
    final List<num>? dailyMinTemps = (dailyData['temperature_2m_min'] as List?)?.cast<num>();
    final List<num>? dailyWeatherCodes = (dailyData['weather_code'] as List?)?.cast<num>();
    final List<num>? dailyPrecipProbMax = (dailyData['precipitation_probability_max'] as List?)?.cast<num>();
    // Sunrise/Sunset times are already extracted


    if (dailyDates != null) {
        developer.log('[WeatherService] Building ${dailyDates.length} forecast days.', name: 'WeatherService');
      for (int i = 0; i < dailyDates.length; i++) {
        final int dailyCode = dailyWeatherCodes?[i].toInt() ?? 0;
        final Map<String, String> dailyConditionMap = _mapWeatherCode(dailyCode);

        // Daily forecast usually uses a 'day' icon regardless of current time
        final String dailyIconCode = dailyConditionMap['iconCode'] ?? '01';
        final String dailyIconUrl = 'https://openweathermap.org/img/wn/${dailyIconCode}d@2x.png'; // Force 'd'

        // Format sunrise/sunset to AM/PM for display
        String formattedSunrise = "N/A";
        String formattedSunset = "N/A";
        try {
            if (sunriseTimes != null && i < sunriseTimes.length) {
                // Parse UTC string, add offset, format
                DateTime sunriseDateTime = DateTime.parse(sunriseTimes[i]).add(Duration(seconds: utcOffsetSeconds));
                formattedSunrise = DateFormat('h:mm a').format(sunriseDateTime);
            }
             if (sunsetTimes != null && i < sunsetTimes.length) {
                 // Parse UTC string, add offset, format
                 DateTime sunsetDateTime = DateTime.parse(sunsetTimes[i]).add(Duration(seconds: utcOffsetSeconds));
                formattedSunset = DateFormat('h:mm a').format(sunsetDateTime);
             }
        } catch (e) {
             developer.log('[WeatherService] Error formatting daily sunrise/sunset: $e', name: 'WeatherService', error: e);
        }

        transformedDaily.add({
          'date': dailyDates[i],
          'day': {
            'maxtemp_c': dailyMaxTemps?[i].toDouble() ?? 0.0,
            'mintemp_c': dailyMinTemps?[i].toDouble() ?? 0.0,
            'condition': {
                'text': dailyConditionMap['description'] ?? 'Unknown',
                'icon': dailyIconUrl, // Use 'd' icon
                'code': dailyCode,
            },
            'daily_chance_of_rain': dailyPrecipProbMax?[i].toInt() ?? 0,
          },
          'astro': {
            'sunrise': formattedSunrise, // Use AM/PM formatted string
            'sunset': formattedSunset,   // Use AM/PM formatted string
          },
          // Include hourly data for today in the first daily entry
          // --- MODIFIED: Include HOURLY DATA FOR EACH DAY ---
         // Filter transformedHourly to only include hours for the current daily date
         'hour': transformedHourly.where((hour) {
          // Compare just the date part of the hour's time string
            // with the current daily date string
           return hour['time'] != null && hour['time'].startsWith(dailyDates[i]);
          }).toList(),
          // --- END MODIFIED ---
        });
      }
    } else {
         developer.log('[WeatherService] Daily dates data missing, cannot build forecast days.', name: 'WeatherService');
    }

    // Combine into the final structure expected by HomeScreen
    final Map<String, dynamic> result = {
      'location': {
        'tz_id': timezoneId,
        'localtime': estimatedLocalIsoString, // Use estimated local time
        'utc_offset_seconds': utcOffsetSeconds,
      },
      'current': transformedCurrent,
      'forecast': {
        'forecastday': transformedDaily,
      },
    };
     developer.log('[WeatherService] Transformed Open-Meteo Data contains keys: (${result.keys.join(', ')})', name: 'WeatherService');
    return result;
  }

  // Helper function to map WMO weather codes to descriptions and OpenWeatherMap icon codes
  Map<String, String> _mapWeatherCode(int code) {
    // WMO Code -> [Description, OpenWeatherMap Icon Code (without d/n)]
    const Map<int, List<String>> weatherCodeMap = {
      0: ['Clear sky', '01'],
      1: ['Mainly clear', '01'], // Often uses clear sky icon
      2: ['Partly cloudy', '02'],
      3: ['Overcast', '04'], // Often uses broken clouds icon
      45: ['Fog', '50'],
      48: ['Depositing rime fog', '50'],
      51: ['Drizzle: Light intensity', '09'],
      53: ['Drizzle: Moderate intensity', '09'],
      55: ['Drizzle: Dense intensity', '09'],
      56: ['Freezing Drizzle: Light intensity', '09'], // Use drizzle icon
      57: ['Freezing Drizzle: Dense intensity', '09'], // Use drizzle icon
      61: ['Rain: Slight intensity', '10'],
      63: ['Rain: Moderate intensity', '10'],
      65: ['Rain: Heavy intensity', '10'],
      66: ['Freezing Rain: Light intensity', '13'], // Use snow icon for freezing
      67: ['Freezing Rain: Heavy intensity', '13'], // Use snow icon for freezing
      71: ['Snow fall: Slight intensity', '13'],
      73: ['Snow fall: Moderate intensity', '13'],
      75: ['Snow fall: Heavy intensity', '13'],
      77: ['Snow grains', '13'],
      80: ['Rain showers: Slight intensity', '09'], // Use shower rain icon
      81: ['Rain showers: Moderate intensity', '09'],
      82: ['Rain showers: Violent intensity', '09'],
      85: ['Snow showers: Slight intensity', '13'], // Use snow icon
      86: ['Snow showers: Heavy intensity', '13'], // Use snow icon
      95: ['Thunderstorm: Slight or moderate', '11'],
      96: ['Thunderstorm with slight hail', '11'],
      99: ['Thunderstorm with heavy hail', '11'],
    };

    List<String> condition = weatherCodeMap[code] ?? ['Unknown', '01']; // Default to clear sky
    return {'description': condition[0], 'iconCode': condition[1]};
  }


 // --- Helper to check if it's currently daytime based on API data ---
  // (Note: This function might still be slightly inaccurate depending on API update frequency,
  // the calculation in HomeScreen using local time is generally more reliable now)
  bool _isCurrentlyDay(Map<String, dynamic> daily, int utcOffsetSeconds) {
    try {
      final sunriseTimes = daily['sunrise'] as List?;
      final sunsetTimes = daily['sunset'] as List?;
      if (sunriseTimes == null ||
          sunsetTimes == null ||
          sunriseTimes.isEmpty ||
          sunsetTimes.isEmpty) {
        return true; // Default to day if astro data missing
      }
      // Use the first day's sunrise/sunset
      final sunriseTodayStr = sunriseTimes[0] as String?;
      final sunsetTodayStr = sunsetTimes[0] as String?;

      if (sunriseTodayStr == null || sunsetTodayStr == null) return true;

      // Parse API times as UTC, compare with current UTC time
      final sunriseTimeUtc = DateTime.parse(sunriseTodayStr).toUtc();
      final sunsetTimeUtc = DateTime.parse(sunsetTodayStr).toUtc();
      final currentTimeUtc = DateTime.now().toUtc();

      developer.log(
          "Day Check (Service - potentially inaccurate): SunriseUTC=$sunriseTimeUtc, SunsetUTC=$sunsetTimeUtc, CurrentUTC=$currentTimeUtc",
          name: 'WeatherService');

      return currentTimeUtc.isAfter(sunriseTimeUtc) &&
          currentTimeUtc.isBefore(sunsetTimeUtc);
    } catch (e) {
      developer.log("Error determining day/night from astro data (Service): $e",
          name: 'WeatherService', error: e);
      return true; // Default to day on error
    }
  }

  // --- MODIFIED: Build Forecast Days (pass offset) ---
  // (This function seems to have been pasted incorrectly from an older version,
  // it's not actually used by fetchWeatherOpenMeteo which calls _transformOpenMeteoData directly.
  // We can leave it or remove it, but it's not causing the current error)
  List<Map<String, dynamic>> _buildForecastDays(Map<String, dynamic> daily,
      Map<String, dynamic> hourly, int utcOffsetSeconds) {
    developer.log("(_buildForecastDays called - This function might be unused)", name: 'WeatherService');
    List<Map<String, dynamic>> forecastDays = [];
    // ... (rest of the unused function) ...
    return forecastDays;
   }


  // --- Helper to check if a specific hour is during the day ---
  // (Also likely unused if _buildForecastDays is unused)
  bool _isHourDay(
      String hourIsoString, Map<String, dynamic> daily, int dayIndex) {
     developer.log("(_isHourDay called - This function might be unused)", name: 'WeatherService');
    // ... (rest of the unused function) ...
    return true; // Default day
   }

  // --- Simplified Weather Code Mapping ---
  // (Redundant if _mapWeatherCode is used)
  String _getWeatherDescription(dynamic code) {
     developer.log("(_getWeatherDescription called - This function might be unused)", name: 'WeatherService');
     int? intCode = (code is num) ? code.toInt() : int.tryParse(code?.toString() ?? '');
     if (intCode == null) return 'Unknown Code';
     return _mapWeatherCode(intCode)['description'] ?? 'Unknown Code';
   }

   // --- Simplified Icon URL getter ---
   // (Redundant if icon is built directly in _transformOpenMeteoData)
   String _getWeatherIconUrl(dynamic code, {bool isDay = true}) {
      developer.log("(_getWeatherIconUrl called - This function might be unused)", name: 'WeatherService');
     int? intCode = (code is num) ? code.toInt() : int.tryParse(code?.toString() ?? '');
     if (intCode == null) return 'https://openweathermap.org/img/wn/04d@2x.png'; // Default cloudy

     String iconCode = _mapWeatherCode(intCode)['iconCode'] ?? '01';
     String dayNightSuffix = isDay ? 'd' : 'n';
     return 'https://openweathermap.org/img/wn/$iconCode$dayNightSuffix@2x.png';
   }

} // End of WeatherService class