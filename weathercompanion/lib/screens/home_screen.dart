// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:weathercompanion/services/weather_services.dart';
import 'package:weathercompanion/widgets/weather_card.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';
import 'package:weathercompanion/widgets/ai_assistant_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';
import 'package:intl/intl.dart';
import 'package:weathercompanion/services/ai_greeting_service.dart';
import 'package:weathercompanion/widgets/forecast_detail_sheet.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:weathercompanion/services/settings_service.dart';
import 'package:weathercompanion/screens/settings_screen.dart';
import 'dart:developer' as developer;
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();
  final AiGreetingService _aiGreetingService = AiGreetingService();
  final SettingsService _settingsService = SettingsService();

  TemperatureUnit? _currentTempUnit;
  WindSpeedUnit? _currentWindUnit;

  String _aiGreeting = "";
  bool _greetingLoading = false;

  String cityName = "Loading...";
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "";
  List<dynamic> forecastDays = [];
  bool _isLoading = true;
  String? _errorMessage;

  double? _lastLat;
  double? _lastLon;

  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  bool _animationsReady = false;

  List<dynamic> forecastHours = [];

  double feelsLikeTemp = 0;
  double uvIndex = 0;
  int precipitationChance = 0;
  String sunriseTime = ""; // Keep as String from API (e.g., "05:49 AM")
  String sunsetTime = ""; // Keep as String from API (e.g., "05:31 PM")
  String localTime = "--:--"; // Keep as String (e.g., "10:03 PM")
  String timezoneId = "UTC";

  String _currentAnimation = 'assets/animations/default.json';
  bool _isContentLoaded = false;
  bool _isDay = true; // Default to day

  @override
  void initState() {
    super.initState();
    developer.log('[HomeScreen] initState started', name: 'HomeScreen');
    _initializeAnimations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSettingsAndInitialData();
      }
    });

    developer.log('[HomeScreen] initState finished', name: 'HomeScreen');
  }

  void _initializeAnimations() {
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      );
      _bounceAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationsReady = true;
      developer.log('[HomeScreen] Animations initialized successfully.',
          name: 'HomeScreen');
    } catch (e) {
      developer.log('[HomeScreen] Error initializing animations: $e',
          name: 'HomeScreen', error: e);
    }
  }

  Future<void> _loadSettingsAndInitialData() async {
    developer.log('[HomeScreen] Post-frame: Loading settings...',
        name: 'HomeScreen');
    try {
      await _loadSettings();
      developer.log(
          '[HomeScreen] Settings loaded. Checking for default location...',
          name: 'HomeScreen');

      final String? defaultLocation =
          await _settingsService.getDefaultLocation();

      if (defaultLocation != null && defaultLocation.isNotEmpty) {
        developer.log(
            '[HomeScreen] Default location found: $defaultLocation. Fetching data for default.',
            name: 'HomeScreen');
        await _fetchData(
            cityQueryOverride: defaultLocation, isInitialLoad: true);
      } else {
        developer.log(
            '[HomeScreen] No default location. Fetching initial data for current location.',
            name: 'HomeScreen');
        await _fetchData(useCurrentLocation: true, isInitialLoad: true);
      }
    } catch (e) {
      developer.log('[HomeScreen] Error during initial load sequence: $e',
          name: 'HomeScreen', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Initialization failed: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    }
  }

  Future<void> _loadSettings() async {
    try {
      _currentTempUnit = await _settingsService.getTemperatureUnit();
      _currentWindUnit = await _settingsService.getWindSpeedUnit();
      if (mounted) setState(() {});
      developer.log(
          '[HomeScreen] Settings values loaded: Temp=$_currentTempUnit, Wind=$_currentWindUnit',
          name: 'HomeScreen');
    } catch (e) {
      developer.log(
          '[HomeScreen] CRITICAL: Error loading settings from SharedPreferences: $e',
          name: 'HomeScreen',
          error: e);
      throw Exception('Failed to load preferences: $e');
    }
  }

  @override
  void dispose() {
    if (_animationsReady) {
      _animationController.dispose();
    }
    _cityController.dispose();
    developer.log('[HomeScreen] disposed', name: 'HomeScreen');
    super.dispose();
  }

  // --- Fetch Data ---
  Future<void> _fetchData({
    String? cityQueryOverride,
    bool useCurrentLocation = false,
    bool isInitialLoad = false,
  }) async {
    if (!mounted) return;
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }
    setState(() {
      _errorMessage = null;
      _isContentLoaded = false;
    });

    if (!isInitialLoad) {
      setState(() {
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }

    developer.log(
        '[HomeScreen] Starting _fetchData. CityQuery: $cityQueryOverride, UseCurrent: $useCurrentLocation, Initial: $isInitialLoad',
        name: 'HomeScreen');

    Map<String, dynamic>? weatherData;
    String locationNameToDisplay = "Loading...";
    double? lat;
    double? lon;

    try {
      // 1. Determine Coordinates & Location Name
      if (useCurrentLocation ||
          (cityQueryOverride == null &&
              _cityController.text.isEmpty &&
              _lastLat == null)) {
        developer.log(
            '[HomeScreen] Determining current location coordinates...',
            name: 'HomeScreen');
        final position = await _getCurrentLocationPosition();
        lat = position.latitude;
        lon = position.longitude;
        locationNameToDisplay = await _getCityNameFromCoordinates(lat, lon);
        developer.log(
            '[HomeScreen] Using Current Location: Lat=$lat, Lon=$lon, Name=$locationNameToDisplay',
            name: 'HomeScreen');
      } else {
        String query = cityQueryOverride ?? _cityController.text;
        if (query.isEmpty && _lastLat != null && _lastLon != null) {
          developer.log(
              '[HomeScreen] No query, using last known coordinates: Lat=$_lastLat, Lon=$_lastLon',
              name: 'HomeScreen');
          lat = _lastLat!;
          lon = _lastLon!;
          locationNameToDisplay =
              await _getCityNameFromCoordinates(lat, lon) ?? cityName;
        } else {
          developer.log('[HomeScreen] Geocoding city: $query...',
              name: 'HomeScreen');
          final coords = await _getCoordinatesFromCityName(query);
          if (coords != null) {
            lat = coords['lat'];
            lon = coords['lon'];
            locationNameToDisplay =
                await _getCityNameFromCoordinates(lat!, lon!) ?? query;
            developer.log(
                '[HomeScreen] Using Searched Location: Lat=$lat, Lon=$lon, Name=$locationNameToDisplay',
                name: 'HomeScreen');
          } else {
            throw Exception('Could not find coordinates for "$query".');
          }
        }
      }

      if (mounted) setState(() => cityName = locationNameToDisplay);

      // 2. Fetch Weather Data using coordinates
      if (lat != null && lon != null) {
        developer.log('[HomeScreen] Fetching Open-Meteo for Lat=$lat, Lon=$lon',
            name: 'HomeScreen');
        _lastLat = lat;
        _lastLon = lon;
        weatherData = await _weatherService.fetchWeatherOpenMeteo(lat, lon);
      } else {
        throw Exception('Could not determine coordinates for weather lookup.');
      }

      if (weatherData == null) {
        throw Exception('Failed to fetch weather data.');
      }
      developer.log('[HomeScreen] Weather data received successfully.',
          name: 'HomeScreen');

      // 3. Update State with Weather Data
      _updateStateWithWeatherData(weatherData,
          locationNameOverride: locationNameToDisplay);

      // 4. Fetch AI Greeting
      await _fetchAiGreeting(weatherData,
          locationNameOverride: locationNameToDisplay);
    } catch (e) {
      developer.log('[HomeScreen] Error during _fetchData: $e',
          name: 'HomeScreen', error: e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _greetingLoading = false;
          _errorMessage =
              'Failed to load data: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted && (_isLoading || _greetingLoading)) {
        developer.log(
            '[HomeScreen] FetchData Finally block: Turning off loading states.',
            name: 'HomeScreen');
        setState(() {
          _isLoading = false;
          _greetingLoading = false;
        });
      }
      developer.log('[HomeScreen] Finished _fetchData', name: 'HomeScreen');
    }
  }

  // --- Get Position ---
  Future<Position> _getCurrentLocationPosition() async {
    developer.log('[HomeScreen] Attempting to get current Position...',
        name: 'HomeScreen');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      developer.log(
          '[HomeScreen] Location Check - Service Enabled: $serviceEnabled, Permission: $permission',
          name: 'HomeScreen');

      if (!serviceEnabled) throw Exception('Location services are disabled.');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied)
          throw Exception('Location permissions denied.');
      }

      if (permission == LocationPermission.deniedForever)
        throw Exception('Location permissions permanently denied.');

      developer.log('[HomeScreen] Getting current position (timeout 15s)...',
          name: 'HomeScreen');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      ).catchError((e) async {
        developer.log(
            '[HomeScreen] GetCurrentPosition error: $e. Trying LastKnown...',
            name: 'HomeScreen',
            error: e);
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown == null)
          throw Exception('Failed to get current or last known location.');
        return lastKnown;
      });
      developer.log(
          '[HomeScreen] Position obtained: (${position.latitude}, ${position.longitude})',
          name: 'HomeScreen');
      return position;
    } on TimeoutException {
      developer.log('[HomeScreen] Location timeout.', name: 'HomeScreen');
      throw Exception('Getting location timed out.');
    } catch (e) {
      developer.log('[HomeScreen] Error getting position: $e',
          name: 'HomeScreen', error: e);
      if (e.toString().contains('Location permissions are denied')) {
        _showErrorSnackbar(
            'Location permission denied. Please enable it in settings.');
      } else if (e.toString().contains('Location services are disabled')) {
        _showErrorSnackbar(
            'Location services are off. Please turn on GPS/Location.');
      }
      if (e is Exception) throw e;
      throw Exception('Failed to get location: $e');
    }
  }

  // --- Get coordinates from city name (Nominatim Forward Geocoding) ---
  Future<Map<String, double>?> _getCoordinatesFromCityName(
      String cityName) async {
    // --- MODIFIED: Removed countrycodes=ph ---
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=jsonv2&limit=1&accept-language=en');
    // --- END MODIFIED ---
    developer.log('[HomeScreen] Nominatim Forward Geocoding URL: $url',
        name: 'HomeScreen');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'WeatherCompanionApp/2.0.2 (johnbalmedina30@gmail.com)'
      });
      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List;
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat'] ?? '');
          final lon = double.tryParse(results[0]['lon'] ?? '');
          if (lat != null && lon != null) {
            developer.log(
                '[HomeScreen] Geocoding success for "$cityName": Lat=$lat, Lon=$lon',
                name: 'HomeScreen');
            return {'lat': lat, 'lon': lon};
          }
        } else {
          developer.log(
              '[HomeScreen] Nominatim Forward Geocoding: No results found for "$cityName".',
              name: 'HomeScreen');
        }
      } else {
        developer.log(
            '[HomeScreen] Nominatim Forward Geocoding failed: ${response.statusCode}',
            name: 'HomeScreen');
      }
    } catch (e) {
      developer.log('[HomeScreen] Nominatim Forward Geocoding error: $e',
          name: 'HomeScreen', error: e);
    }
    return null; // Failed to get coordinates
  }

  // --- Get city name from coordinates (Nominatim Reverse Geocoding) ---
  Future<String> _getCityNameFromCoordinates(double lat, double lon) async {
    developer.log('[HomeScreen] Reverse geocoding coords: ($lat, $lon)...',
        name: 'HomeScreen');
    // --- MODIFIED: Removed countrycodes=ph ---
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=18&accept-language=en');
    // --- END MODIFIED ---
    developer.log('[HomeScreen] Nominatim Reverse URL: $url',
        name: 'HomeScreen');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'WeatherCompanionApp/2.0.2 (johnbalmedina30@gmail.com)'
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        developer.log('[HomeScreen] Nominatim Reverse Response: $data',
            name: 'HomeScreen');

        // --- IMPROVED NAME FINDING LOGIC ---
        String foundName = address['city'] ??
            address['town'] ??
            address['village'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            // Try county/state if city/town missing
            address['county'] ??
            address['state'] ??
            // Use display name's first part as last resort
            data['display_name']?.split(',').first ??
            "Current Location";

        // Append country for international context
        final String? country = address['country'];
        if (country != null &&
            !foundName.toLowerCase().contains(country.toLowerCase())) {
          foundName = '$foundName, $country';
        }
        // --- END IMPROVED LOGIC ---

        developer.log(
            '[HomeScreen] Nominatim Reverse success. Using name: $foundName',
            name: 'HomeScreen');
        return foundName;
      } else {
        developer.log(
            '[HomeScreen] Nominatim Reverse failed with status ${response.statusCode}.',
            name: 'HomeScreen');
        return "Lat: ${lat.toStringAsFixed(2)}, Lon: ${lon.toStringAsFixed(2)}";
      }
    } catch (e) {
      developer.log('[HomeScreen] Nominatim Reverse HTTP error: $e.',
          name: 'HomeScreen', error: e);
      return "Lat: ${lat.toStringAsFixed(2)}, Lon: ${lon.toStringAsFixed(2)}";
    }
  }

 // <-- MODIFIED HELPER FUNCTION TO USE AM/PM STRINGS -->
 bool _calculateIsDay(
     DateTime? localTime, String sunriseStrAMPM, String sunsetStrAMPM) {
   if (localTime == null || sunriseStrAMPM == 'N/A' || sunsetStrAMPM == 'N/A') {
     developer.log('[_calculateIsDay] localTime or sunrise/sunset missing, defaulting to day.',
         name: 'HomeScreen');
     return true; // Default to day if no time or astro data
   }

   try {
     // Parse sunrise/sunset strings (e.g., "06:01 AM", "05:45 PM") using h:mm a format
     final DateFormat format = DateFormat('h:mm a');
     DateTime sunrise = format.parseStrict(sunriseStrAMPM.trim());
     DateTime sunset = format.parseStrict(sunsetStrAMPM.trim());

     // Create DateTime objects for today (using the localTime's date)
     DateTime todaySunrise = DateTime(localTime.year, localTime.month,
         localTime.day, sunrise.hour, sunrise.minute);
     DateTime todaySunset = DateTime(localTime.year, localTime.month,
         localTime.day, sunset.hour, sunset.minute);

     // The check: is the local time *after* sunrise AND *before* sunset?
     bool isDay =
         localTime.isAfter(todaySunrise) && localTime.isBefore(todaySunset);

     developer.log(
         '[_calculateIsDay] Check:'
         '\n  Local Time: $localTime'
         '\n  Sunrise: $todaySunrise (from "$sunriseStrAMPM")'
         '\n  Sunset: $todaySunset (from "$sunsetStrAMPM")'
         '\n  Result (isDay): $isDay',
         name: 'HomeScreen');

     return isDay;
   } catch (e) {
     developer.log(
         '[_calculateIsDay] Error parsing AM/PM sunrise/sunset string: "$sunriseStrAMPM" or "$sunsetStrAMPM". Error: $e. Defaulting to day.',
         name: 'HomeScreen',
         error: e);
     return true; // Default to day on parse error
   }
 }

  // --- MODIFIED: Update State (Explicitly rebuild icon URL) ---
 void _updateStateWithWeatherData(Map<String, dynamic> data,
     {String? locationNameOverride}) {
   if (!mounted) return;
   developer.log('[HomeScreen] Updating UI state with weather data...',
       name: 'HomeScreen');

   // --- Extract Data (Keep this part) ---
   final current = data['current'] ?? {};
   final location = data['location'] ?? {};
   final forecast = data['forecast']?['forecastday'] ?? [];
   final todayForecast = (forecast.isNotEmpty) ? forecast[0] : null;
   final todayAstro = todayForecast?['astro'] ?? {};
   final todayDay = todayForecast?['day'] ?? {};

   // Timezone Handling (Keep this part)
   final String apiTimezoneId = location['tz_id'] ?? 'UTC';
   final int apiUtcOffsetSeconds = location['utc_offset_seconds'] ?? 0;
   final String localTimeString = location['localtime'] ?? "";
   String formattedLocalTime = "--:--";
   DateTime? parsedLocalTime;
   try {
     if (localTimeString.isNotEmpty) {
       parsedLocalTime = DateTime.parse(localTimeString).toLocal();
       formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
     } else {
       parsedLocalTime = DateTime.now();
       formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
     }
   } catch (e) {
     parsedLocalTime = DateTime.now();
     formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
   }

   // --- MODIFICATION: Limit hours shown on home screen ---
   final List<dynamic> allHours =
       (todayForecast != null && todayForecast['hour'] != null)
           ? (todayForecast['hour'] as List)
           : [];
   const int maxHoursToShow = 12; // Show up to 12 hours
   // --- END MODIFICATION ---

   final DateTime refTimeForHourly = parsedLocalTime ?? DateTime.now();
   final List<dynamic> newForecastHours = allHours.where((hour) {
     try {
       DateTime hourTime = DateTime.tryParse(hour['time'] ?? "")?.toLocal() ??
           refTimeForHourly;
       return !hourTime
           .isBefore(refTimeForHourly.subtract(const Duration(minutes: 30)));
     } catch (e) { return false; }
   }).toList();

   // Other Weather Data (Keep this part)
   final String newCityName =
       locationNameOverride ?? location['name'] ?? cityName;
   final double newTemp = (current['temp_c'] as num?)?.toDouble() ?? 0;
   final String newDesc = current['condition']?['text'] ?? "";
   // We'll rebuild the icon URL below
   final String originalIconUrlFromService = current['condition']?['icon'] ?? "";
   final int newHumidity = (current['humidity'] as num?)?.toInt() ?? 0;
   final double newWindSpeed = (current['wind_kph'] as num?)?.toDouble() ?? 0;
   final double newFeelsLike =
       (current['feelslike_c'] as num?)?.toDouble() ?? 0;
   final double newUvIndex = (current['uv'] as num?)?.toDouble() ?? 0;
   final int newPrecipChance =
       (todayDay['daily_chance_of_rain'] as num?)?.toInt() ?? 0;
   final String newSunrise = todayAstro['sunrise'] ?? "N/A";
   final String newSunset = todayAstro['sunset'] ?? "N/A";

   // --- *** CORE FIX AREA *** ---
   // 1. Calculate Day/Night Correctly
   final bool newIsDay = _calculateIsDay(parsedLocalTime, newSunrise, newSunset);
   developer.log(
       '[HomeScreen] RE-CALCULATED Day/Night using local time and astro: Parsed as: $newIsDay',
       name: 'HomeScreen');

   // 2. Rebuild the Icon URL using the CORRECT isDay value
   String correctedIconUrl = originalIconUrlFromService; // Start with the original
   try {
     // Example URL: https://openweathermap.org/img/wn/02d@2x.png
     // We need to replace the 'd' or 'n' before @2x.png
     RegExp regExp = RegExp(r"^(.*\/)(\d+[dn])(@2x\.png)$");
     Match? match = regExp.firstMatch(originalIconUrlFromService);

     if (match != null && match.groupCount == 3) {
       String baseUrl = match.group(1)!; // e.g., "https://openweathermap.org/img/wn/"
       String codeWithSuffix = match.group(2)!; // e.g., "02d"
       String suffix = match.group(3)!; // e.g., "@2x.png"

       // Extract the code (e.g., "02")
       String code = codeWithSuffix.substring(0, codeWithSuffix.length - 1);
       // Determine the correct day/night letter
       String dayNightSuffix = newIsDay ? 'd' : 'n';

       // Reconstruct the URL
       correctedIconUrl = "$baseUrl$code$dayNightSuffix$suffix";
       developer.log(
           '[HomeScreen] Corrected Icon URL: Original="$originalIconUrlFromService", Corrected="$correctedIconUrl" based on isDay=$newIsDay',
           name: 'HomeScreen');
     } else {
        developer.log(
           '[HomeScreen] Could not parse original icon URL format: "$originalIconUrlFromService". Using it as is.',
           name: 'HomeScreen');
     }
   } catch (e) {
     developer.log('[HomeScreen] Error correcting icon URL: $e. Using original URL.', name: 'HomeScreen', error: e);
     correctedIconUrl = originalIconUrlFromService; // Fallback
   }
   // --- *** END FIX AREA *** ---


   setState(() {
     // Set all state variables
     cityName = newCityName;
     temperature = newTemp;
     weatherDescription = newDesc;
     weatherIcon = correctedIconUrl; // <--- USE THE CORRECTED URL
     humidity = newHumidity;
     windSpeed = newWindSpeed;
     feelsLikeTemp = newFeelsLike;
     uvIndex = newUvIndex;
     precipitationChance = newPrecipChance;
     sunriseTime = newSunrise;
     sunsetTime = newSunset;
     localTime = formattedLocalTime;
     timezoneId = apiTimezoneId;
     forecastDays = forecast;
     // --- MODIFICATION: Apply the limit ---
     forecastHours = newForecastHours.take(maxHoursToShow).toList();
     // --- END MODIFICATION ---

     if (_cityController.text != newCityName &&
         !newCityName.startsWith('Lat:')) {
       _cityController.text = newCityName;
     }

     _isLoading = false;
     _errorMessage = null;

     _isDay = newIsDay; // Save the CORRECT day/night state
     _currentAnimation = _getWeatherAnimation(
         newDesc, _isDay); // Pass description and CORRECT isDay
     _isContentLoaded = true;

     if (_animationsReady && !_animationController.isAnimating) {
       _animationController.repeat(reverse: true);
       developer.log('[HomeScreen] Starting animations.', name: 'HomeScreen');
     }
   });
   developer.log('[HomeScreen] Weather UI state updated.', name: 'HomeScreen');
 }

  // --- Fetch AI Greeting ---
  Future<void> _fetchAiGreeting(Map<String, dynamic> weatherData,
      {String? locationNameOverride}) async {
    if (!mounted) return;
    developer.log('[HomeScreen] Fetching AI greeting...', name: 'HomeScreen');
    setState(() => _greetingLoading = true);

    try {
      final location = weatherData['location'];
      final current = weatherData['current'];
      final forecast = weatherData['forecast']?['forecastday'] ?? [];
      final String localTimeString = location['localtime'] ?? "";
      DateTime currentTime;
      try {
        currentTime = DateTime.parse(localTimeString).toLocal();
      } catch (e) {
        developer.log(
            '[HomeScreen] Error parsing greeting time: $e. Using DateTime.now().',
            name: 'HomeScreen');
        currentTime = DateTime.now();
      }

      final String nameForAI =
          locationNameOverride ?? location['name'] ?? "your location";

      final generatedGreeting = await _aiGreetingService.generateGreeting(
        current['condition']?['text'] ?? "",
        nameForAI,
        (current['temp_c'] as num?)?.toDouble() ?? 0,
        currentTime,
        forecast,
      );

      if (mounted) {
        setState(() {
          _aiGreeting = generatedGreeting;
          _greetingLoading = false;
        });
        developer.log('[HomeScreen] AI Greeting received and updated.',
            name: 'HomeScreen');
      }
    } catch (e) {
      developer.log('[HomeScreen] Error fetching AI greeting: $e',
          name: 'HomeScreen', error: e);
      if (mounted) {
        setState(() {
          _aiGreeting = "Couldn't fetch a friendly greeting right now!";
          _greetingLoading = false;
        });
      }
    }
  }

  // --- Try Get Current Device Location ---
  Future<Position?> _tryGetCurrentDeviceLocation() async {
    developer.log(
        '[HomeScreen] Map Button: Trying to get current device location...',
        name: 'HomeScreen');
    try {
      return await _getCurrentLocationPosition();
    } catch (e) {
      String errorMsg =
          'Failed to get location for map: ${e.toString().replaceFirst("Exception: ", "")}';
      developer.log(errorMsg, name: 'HomeScreen', error: e);
      _showErrorSnackbar(errorMsg);
      return null;
    }
  }

  // --- Month Name ---
  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "???";
  }

  // --- Show Error Snackbar ---
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- Get Weather Animation (Day/Night Logic) ---
  String _getWeatherAnimation(String description, bool isDay) {
    String desc = description.toLowerCase();

    if (isDay) {
      // --- DAY ANIMATIONS ---
      if (desc.contains('thunder') || desc.contains('storm')) {
        return 'assets/animations/day_thunderstorm.json';
      }
      if (desc.contains('rain') || desc.contains('drizzle')) {
        return 'assets/animations/day_rain.json';
      }
      if (desc.contains('wind') || desc.contains('squalls')) {
        return 'assets/animations/day_windy.json';
      }
      if (desc.contains('snow') || desc.contains('sleet')) {
        return 'assets/animations/day_snow.json';
      }
      if (desc.contains('cloud') ||
          desc.contains('overcast') ||
          desc.contains('fog') ||
          desc.contains('mist')) {
        return 'assets/animations/day_clouds.json';
      }
      if (desc.contains('sun') || desc.contains('clear')) {
        return 'assets/animations/day_flare.json'; // Your "flare"
      }
      // Fallback for day
      return 'assets/animations/day_flare.json';
    } else {
      // --- NIGHT ANIMATIONS ---
      if (desc.contains('thunder') || desc.contains('storm')) {
        return 'assets/animations/night_thunderstorm.json';
      }
      if (desc.contains('rain') || desc.contains('drizzle')) {
        return 'assets/animations/night_rain.json';
      }
      if (desc.contains('wind') || desc.contains('squalls')) {
        return 'assets/animations/night_windy.json';
      }
      if (desc.contains('snow') || desc.contains('sleet')) {
        return 'assets/animations/night_snow.json';
      }
      if (desc.contains('cloud') ||
          desc.contains('overcast') ||
          desc.contains('fog') ||
          desc.contains('mist')) {
        return 'assets/animations/night_clouds.json';
      }
      if (desc.contains('clear')) {
        return 'assets/animations/night_cloudless.json'; // Your "cloudless"
      }
      // Fallback for night
      return 'assets/animations/night_cloudless.json';
    }
  }

  // --- *** MODIFIED: Get Background Gradient (Brighter) *** ---
  LinearGradient _getBackgroundGradient(String description, bool isDay) {
    ThemeData theme = Theme.of(context);
    String desc = description.toLowerCase();

    // Opacity is kept so the Lottie animation shows through
    if (isDay) {
      // --- DAY GRADIENTS ---
      if (desc.contains('rain') ||
          desc.contains('drizzle') ||
          desc.contains('thunderstorm')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blueGrey.withOpacity(0.4), // Was 0.8
            Colors.indigo.withOpacity(0.5) // Was 0.9
          ],
        );
      } else if (desc.contains('sun') ||
          desc.contains('clear') ||
          desc.contains('windy')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.orange.shade300.withOpacity(0.5), // Was 0.7
            Colors.lightBlue.shade300.withOpacity(0.6) // Was 0.8
          ],
        );
      } else if (desc.contains('cloud') ||
          desc.contains('overcast') ||
          desc.contains('fog') ||
          desc.contains('mist')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade400.withOpacity(0.6), // Was 0.8
            Colors.blueGrey.shade400.withOpacity(0.7) // Was 0.9
          ],
        );
      } else if (desc.contains('snow') || desc.contains('sleet')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.lightBlue.shade100.withOpacity(0.6), // Was 0.8
            Colors.grey.shade300.withOpacity(0.7) // Was 0.9
          ],
        );
      }
    } else {
      // --- NIGHT GRADIENTS ---
      if (desc.contains('rain') ||
          desc.contains('drizzle') ||
          desc.contains('thunderstorm')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.indigo.shade900.withOpacity(0.7), // Was 0.8
            Colors.black.withOpacity(0.8) // Was 0.9
          ],
        );
      } else if (desc.contains('clear') || desc.contains('windy')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7), // Was 0.8
            Colors.indigo.shade900.withOpacity(0.8) // Was 0.9
          ],
        );
      } else if (desc.contains('cloud') ||
          desc.contains('overcast') ||
          desc.contains('fog') ||
          desc.contains('mist')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blueGrey.shade900.withOpacity(0.7), // Was 0.8
            Colors.black.withOpacity(0.8) // Was 0.9
          ],
        );
      } else if (desc.contains('snow') || desc.contains('sleet')) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade800.withOpacity(0.7), // Was 0.8
            Colors.black.withOpacity(0.8) // Was 0.9
          ],
        );
      }
    }

    // Default fallback gradient
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        theme.scaffoldBackgroundColor.withOpacity(0.6), // Was 0.7
        theme.primaryColor.withOpacity(0.7) // Was 0.8
      ],
    );
  }
  // --- *** END MODIFIED *** ---

  // --- WIDGET BUILD (THEME AWARE) ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final String formattedToday =
        "${_monthName(now.month)} ${now.day}, ${now.year}";
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final tempUnit = _currentTempUnit ?? TemperatureUnit.celsius;
    final windUnit = _currentWindUnit ?? WindSpeedUnit.kph;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Layer 1: Lottie Animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 1500),
            child: Lottie.asset(
              _currentAnimation,
              key: ValueKey<String>(_currentAnimation),
              fit: BoxFit.contain,
              alignment: Alignment.center, // <-- *** ADDED THIS LINE ***
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Layer 2: Gradient Overlay
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: _getBackgroundGradient(weatherDescription, _isDay),
            ),
          ),

          // Layer 3: Your Original Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                developer.log('[HomeScreen] Pull-to-refresh triggered.',
                    name: 'HomeScreen');
                if (_cityController.text.isNotEmpty) {
                  await _fetchData(cityQueryOverride: _cityController.text);
                } else {
                  final String? defaultLocation =
                      await _settingsService.getDefaultLocation();
                  if (defaultLocation != null && defaultLocation.isNotEmpty) {
                    await _fetchData(cityQueryOverride: defaultLocation);
                  } else {
                    await _fetchData(useCurrentLocation: true);
                  }
                }
              },
              color: theme.colorScheme.primary,
              backgroundColor: theme.appBarTheme.backgroundColor,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildSearchBar(),
                          const SizedBox(height: 25),
                          _buildBodyContent(
                              formattedToday, tempUnit, windUnit),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !isKeyboardOpen,
                    child: Positioned(
                      bottom: 5,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          "Weather Data: Open-Meteo.com | Geocoding: OpenStreetMap Nominatim",
                          style: TextStyle(
                              color: theme.colorScheme.onBackground
                                  .withOpacity(0.5),
                              fontSize: 8,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ),
                  ),
                  if (_animationsReady && !isKeyboardOpen) _buildMapButton(),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton:
          (_animationsReady && !isKeyboardOpen) ? _buildSettingsButton() : null,
    );
  }

  // --- Build Header (THEME AWARE) ---
  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("assets/images/logo.png",
            height: 28,
            width: 28,
            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const SizedBox(width: 8),
        Text(
          "WeatherCompanion v2.0.2", // Bumped version for clarity
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // --- Build Search Bar (THEME AWARE) ---
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cityController,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: "Enter city name (any country)", // Updated hint
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
              ),
              filled: true,
              fillColor: theme.colorScheme.secondaryContainer,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.search,
                  color: theme.colorScheme.onSecondaryContainer),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              isDense: true,
            ),
            onSubmitted: (v) {
              if (v.isNotEmpty) _fetchData(cityQueryOverride: v);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          icon: Icon(Icons.my_location,
              color: theme.iconTheme.color, size: 24),
          onPressed: () async {
            FocusScope.of(context).unfocus();
            _cityController.clear();
            await _fetchData(useCurrentLocation: true);
          },
          tooltip: "My Location",
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: theme.iconTheme.color, size: 24),
          onPressed: () {
            FocusScope.of(context).unfocus();
            _fetchData(
                cityQueryOverride: _cityController.text.isNotEmpty
                    ? _cityController.text
                    : null,
                useCurrentLocation:
                    _cityController.text.isEmpty && _lastLat == null);
          },
          tooltip: "Refresh",
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  // --- Build Body Content (THEME AWARE) ---
  Widget _buildBodyContent(
      String formattedToday, TemperatureUnit tempUnit, WindSpeedUnit windUnit) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return SizedBox(
          height: 400,
          child: Center(
              child: CircularProgressIndicator(
                  color: theme.colorScheme.primary)));
    }

    if (_errorMessage != null) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 40),
            const SizedBox(height: 15),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchData(
                  cityQueryOverride: _cityController.text.isNotEmpty
                      ? _cityController.text
                      : null,
                  useCurrentLocation:
                      _cityController.text.isEmpty && _lastLat == null),
              child: const Text('Try Again'),
            )
          ],
        )),
      );
    }

    return AnimatedOpacity(
      opacity: _isContentLoaded ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cityName,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          WeatherCard(
            displayTemperature: tempUnit == TemperatureUnit.celsius
                ? temperature
                : _settingsService.toFahrenheit(temperature),
            tempUnitSymbol: tempUnit == TemperatureUnit.celsius ? 'C' : 'F',
            icon: weatherIcon,
            description: weatherDescription,
            date: formattedToday,
            localTime: localTime,
            humidity: humidity,
            displayWindSpeed: windUnit == WindSpeedUnit.kph
                ? windSpeed
                : _settingsService.toMph(windSpeed),
            windUnitSymbol: windUnit == WindSpeedUnit.kph ? 'kph' : 'mph',
            feelsLikeTemp: tempUnit == TemperatureUnit.celsius
                ? feelsLikeTemp
                : _settingsService.toFahrenheit(feelsLikeTemp),
            uvIndex: uvIndex,
            precipitationChance: precipitationChance,
            sunriseTime: sunriseTime,
            sunsetTime: sunsetTime,
          ),
          const SizedBox(height: 25),
          _buildAiGreeting(),
          if (_greetingLoading || _aiGreeting.isNotEmpty)
            const SizedBox(height: 25),
          if (forecastHours.isNotEmpty) _buildHourlyForecast(tempUnit),
          if (forecastHours.isNotEmpty) const SizedBox(height: 25),
          if (forecastDays.length >= 1) _buildDailyForecast(tempUnit, windUnit),
          if (forecastDays.length >= 1) const SizedBox(height: 25),
          AiAssistantWidget(
            cityName: cityName,
            temperature: temperature,
            weatherDescription: weatherDescription,
            forecastDays: forecastDays,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  // --- Build AI Greeting (THEME AWARE with Opacity) ---
  Widget _buildAiGreeting() {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    //
    // 👇👇👇 VIBE CHECK (Light Mode) 👇👇👇
    //
    const double lightModeOpacity = 0.6; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Light Mode) 👆👆👆
    //

    //
    // 👇👇👇 VIBE CHECK (Dark Mode) 👇👇👇
    //
    const double darkModeOpacity = 0.2; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Dark Mode) 👆👆👆
    //

    if (_greetingLoading) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(
                  color: theme.colorScheme.primary, strokeWidth: 2.0)));
    }
    if (_aiGreeting.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          // --- APPLY OPACITY HERE ---
          color: isLightMode
              ? theme.cardColor.withOpacity(lightModeOpacity)
              : theme.cardColor.withOpacity(darkModeOpacity),
          // --- END OPACITY CHANGE ---
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: theme.colorScheme.onSurface.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 40, width: 40),
            const SizedBox(height: 10),
            Text(
              _aiGreeting,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  // --- Build Hourly Forecast (THEME AWARE with Opacity) ---
  Widget _buildHourlyForecast(TemperatureUnit tempUnit) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    //
    // 👇👇👇 VIBE CHECK (Light Mode) 👇👇👇
    //
    const double lightModeOpacity = 0.6; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Light Mode) 👆👆👆
    //

    //
    // 👇👇👇 VIBE CHECK (Dark Mode) 👇👇👇
    //
    const double darkModeOpacity = 0.2; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Dark Mode) 👆👆👆
    //

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: forecastHours.length,
        itemBuilder: (context, index) {
          final hourData = forecastHours[index];
          final timeStr = hourData['time'] ?? "";
          final tempC = (hourData['temp_c'] as num?)?.toDouble() ?? 0;
          final iconUrl = hourData['condition']?['icon'] ?? "";
          String formattedTime = "N/A";
          DateTime? parsedTime;
          try {
            parsedTime = DateTime.parse(timeStr).toLocal();
            formattedTime = DateFormat('h a').format(parsedTime);
          } catch (e) {
            developer.log(
                '[HomeScreen] Error parsing hour time: $timeStr. Error: $e',
                name: 'HomeScreen');
          }

          bool isNow = index == 0;

          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // --- APPLY OPACITY HERE ---
              color: isNow
                  ? theme.colorScheme.primary.withOpacity(0.3) // "Now" card
                  : isLightMode
                      ? theme.cardColor.withOpacity(lightModeOpacity)
                      : theme.cardColor.withOpacity(darkModeOpacity),
              // --- END OPACITY CHANGE ---
              borderRadius: BorderRadius.circular(12),
              border: isNow
                  ? Border.all(color: theme.colorScheme.primary, width: 0.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isNow ? "Now" : formattedTime,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                WeatherIconImage(iconUrl: iconUrl, size: 35.0),
                const SizedBox(height: 5),
                Text(
                  tempUnit == TemperatureUnit.celsius
                      ? "${tempC.round()}°"
                      : "${_settingsService.toFahrenheit(tempC).round()}°",
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Build Daily Forecast (THEME AWARE with Opacity) ---
  Widget _buildDailyForecast(TemperatureUnit tempUnit, WindSpeedUnit windUnit) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    //
    // 👇👇👇 VIBE CHECK (Light Mode) 👇👇👇
    //
    const double lightModeOpacity = 0.6; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Light Mode) 👆👆👆
    //

    //
    // 👇👇👇 VIBE CHECK (Dark Mode) 👇👇👇
    //
    const double darkModeOpacity = 0.2; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Dark Mode) 👆👆👆
    //

    final daysToShow =
        forecastDays.length > 1 ? forecastDays.sublist(1) : forecastDays;

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: daysToShow.length,
        itemBuilder: (context, index) {
          final day = daysToShow[index];
          final dateStr = day['date'] ?? "";
          DateTime parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
          final formattedDate = DateFormat('MMM d').format(parsed);
          final dayInfo = day['day'] ?? {};
          final condition = dayInfo['condition']?['text'] ?? "";
          final String forecastIconUrl = dayInfo['condition']?['icon'] ?? "";
          final minTempC = (dayInfo['mintemp_c'] as num?)?.toInt() ?? 0;
          final maxTempC = (dayInfo['maxtemp_c'] as num?)?.toInt() ?? 0;

          final String displayMin = tempUnit == TemperatureUnit.celsius
              ? "$minTempC"
              : "${_settingsService.toFahrenheit(minTempC.toDouble()).round()}";
          final String displayMax = tempUnit == TemperatureUnit.celsius
              ? "$maxTempC"
              : "${_settingsService.toFahrenheit(maxTempC.toDouble()).round()}";
          final String tempSymbol = "°";

          return InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ForecastDetailSheet(
                  dayData: day,
                  tempUnit: tempUnit,
                  windUnit: windUnit,
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 110,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                // --- APPLY OPACITY HERE ---
                color: isLightMode
                    ? theme.cardColor.withOpacity(lightModeOpacity)
                    : theme.cardColor.withOpacity(darkModeOpacity),
                // --- END OPACITY CHANGE ---
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  WeatherIconImage(iconUrl: forecastIconUrl, size: 40.0),
                  const SizedBox(height: 5),
                  Text(
                    "$displayMin$tempSymbol / $displayMax$tempSymbol",
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    condition,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  // --- Build Map Button (THEME AWARE) ---
  Widget _buildMapButton() {
    final theme = Theme.of(context);
    return Positioned(
      height: 55,
      width: 55,
      bottom: 16,
      left: 16,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, -_bounceAnimation.value), child: child),
        child: FloatingActionButton(
          heroTag: "map_fab",
          backgroundColor: theme.colorScheme.surface.withOpacity(0.25),
          elevation: 4.0,
          mini: true,
          onPressed: () async {
            developer.log(
                '[HomeScreen] Map Button Pressed. Attempting to get current device location first.',
                name: 'HomeScreen');
            Position? currentPosition = await _tryGetCurrentDeviceLocation();

            if (!mounted) return;

            LatLng centerPoint;
            String mapTitle;

            if (currentPosition != null) {
              centerPoint =
                  LatLng(currentPosition.latitude, currentPosition.longitude);
              mapTitle = await _getCityNameFromCoordinates(
                  currentPosition.latitude, currentPosition.longitude);
              developer.log(
                  '[HomeScreen] Map Button: Using current device location ($mapTitle): $centerPoint',
                  name: 'HomeScreen');
            } else if (_lastLat != null && _lastLon != null) {
              centerPoint = LatLng(_lastLat!, _lastLon!);
              mapTitle =
                  cityName.startsWith("Lat:") ? "Last Location" : cityName;
              developer.log(
                  '[HomeScreen] Map Button: Failed to get current. Falling back to last weather location ($mapTitle): $centerPoint',
                  name: 'HomeScreen');
              _showErrorSnackbar(
                  "Couldn't get current location, showing last known weather location.");
            } else {
              centerPoint = LatLng(14.474686, 121.001959); // Parañaque fallback
              mapTitle = "Default Location";
              developer.log(
                  '[HomeScreen] Map Button: Failed to get current and no last known. Falling back to default: $centerPoint',
                  name: 'HomeScreen');
              _showErrorSnackbar("Could not determine any location for map.");
            }

            Navigator.push(
              context,
              FadeRoute( // Using FadeRoute
                page: MapScreen(center: centerPoint, title: mapTitle),
              ),
            );
          },
          tooltip: 'Open Map',
          child: Icon(Icons.map, color: theme.colorScheme.primary, size: 24),
        ),
      ),
    );
  }

  // --- Build Settings Button (THEME AWARE) ---
  Widget _buildSettingsButton() {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) => Transform.translate(
          offset: Offset(0, -_bounceAnimation.value), child: child),
      child: FloatingActionButton(
        heroTag: "settings_fab",
        onPressed: () async {
          FocusScope.of(context).unfocus();

          final result = await Navigator.push(
            context,
            FadeRoute(page: const SettingsScreen()), // Using FadeRoute
          );

          developer.log('[HomeScreen] Returned from Settings. Result: $result',
              name: 'HomeScreen');
          await _loadSettings();

          if (result is String && result.isNotEmpty && mounted) {
            developer.log(
                '[HomeScreen] Received city from SettingsScreen: $result. Fetching...',
                name: 'HomeScreen');
            await _fetchData(cityQueryOverride: result);
          } else {
            developer.log(
                '[HomeScreen] No specific city selected OR units changed. Refreshing current view...',
                name: 'HomeScreen');
            if (_cityController.text.isNotEmpty) {
              await _fetchData(cityQueryOverride: _cityController.text);
            } else {
              final String? defaultLocation =
                  await _settingsService.getDefaultLocation();
              if (defaultLocation != null && defaultLocation.isNotEmpty) {
                await _fetchData(cityQueryOverride: defaultLocation);
              } else {
                await _fetchData(useCurrentLocation: true);
              }
            }
          }
        },
        backgroundColor: theme.colorScheme.surface.withOpacity(0.25),
        elevation: 6.0,
        tooltip: 'Settings',
        child:
            Icon(Icons.settings, color: theme.colorScheme.primary, size: 24),
      ),
    );
  }
}

// Helper class for Fade Transitions
class FadeRoute extends PageRouteBuilder {
  final Widget page;
  FadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        );
}