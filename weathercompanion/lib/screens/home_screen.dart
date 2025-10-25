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
  String sunriseTime = "";
  String sunsetTime = "";
  String localTime = "--:--"; // State variable for formatted local time
  String timezoneId = "UTC"; // <-- ADDED: State variable for timezone ID

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
        duration: const Duration(seconds: 2),
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

  // --- MODIFIED: Load settings and check for default location ---
  Future<void> _loadSettingsAndInitialData() async {
    developer.log('[HomeScreen] Post-frame: Loading settings...',
        name: 'HomeScreen');
    try {
      await _loadSettings();
      developer.log(
          '[HomeScreen] Settings loaded. Checking for default location...',
          name: 'HomeScreen');

      // --- NEW: Check for a default location ---
      final String? defaultLocation =
          await _settingsService.getDefaultLocation();

      if (defaultLocation != null && defaultLocation.isNotEmpty) {
        developer.log(
            '[HomeScreen] Default location found: $defaultLocation. Fetching data for default.',
            name: 'HomeScreen');
        // Load weather for the default location
        await _fetchData(
            cityQueryOverride: defaultLocation, isInitialLoad: true);
      } else {
        developer.log(
            '[HomeScreen] No default location. Fetching initial data for current location.',
            name: 'HomeScreen');
        // Use current location for initial load (original behavior)
        await _fetchData(useCurrentLocation: true, isInitialLoad: true);
      }
      // --- END NEW ---
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
  // --- END MODIFIED ---

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
    setState(() => _errorMessage = null);

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
      // --- MODIFIED: Ensure cityQueryOverride is prioritized even if _cityController is empty ---
      if (useCurrentLocation ||
          (cityQueryOverride == null &&
              _cityController.text.isEmpty &&
              _lastLat == null)) {
        // --- END MODIFIED ---
        developer.log(
            '[HomeScreen] Determining current location coordinates...',
            name: 'HomeScreen');
        final position =
            await _getCurrentLocationPosition(); // Get Position object
        lat = position.latitude;
        lon = position.longitude;
        locationNameToDisplay =
            await _getCityNameFromCoordinates(lat, lon); // Get name from coords
        developer.log(
            '[HomeScreen] Using Current Location: Lat=$lat, Lon=$lon, Name=$locationNameToDisplay',
            name: 'HomeScreen');
      } else {
        String query = cityQueryOverride ?? _cityController.text;
        // --- NEW: Handle case where query is still empty but we have a _lastLat
        if (query.isEmpty && _lastLat != null && _lastLon != null) {
          developer.log(
              '[HomeScreen] No query, using last known coordinates: Lat=$_lastLat, Lon=$_lastLon',
              name: 'HomeScreen');
          lat = _lastLat!;
          lon = _lastLon!;
          locationNameToDisplay =
              await _getCityNameFromCoordinates(lat, lon) ?? cityName;
        }
        // --- END NEW ---
        else {
          developer.log('[HomeScreen] Geocoding city: $query...',
              name: 'HomeScreen');
          final coords = await _getCoordinatesFromCityName(
              query); // Get coords from city name
          if (coords != null) {
            lat = coords['lat'];
            lon = coords['lon'];
            locationNameToDisplay = await _getCityNameFromCoordinates(
                    lat!, lon!) ??
                query; // Verify name via reverse geocode or use original query
            developer.log(
                '[HomeScreen] Using Searched Location: Lat=$lat, Lon=$lon, Name=$locationNameToDisplay',
                name: 'HomeScreen');
          } else {
            throw Exception('Could not find coordinates for "$query".');
          }
        }
      }

      // Update UI optimistically with name
      if (mounted) setState(() => cityName = locationNameToDisplay);

      // 2. Fetch Weather Data using coordinates
      if (lat != null && lon != null) {
        developer.log('[HomeScreen] Fetching Open-Meteo for Lat=$lat, Lon=$lon',
            name: 'HomeScreen');
        // --- NEW: Store last used coordinates ---
        _lastLat = lat;
        _lastLon = lon;
        // --- END NEW ---
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
    // ... (rest of the function is the same) ...
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
    // ... (rest of the function is the same) ...
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cityName)}&format=jsonv2&limit=1&countrycodes=ph&accept-language=en');
    developer.log('[HomeScreen] Nominatim Forward Geocoding URL: $url',
        name: 'HomeScreen');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'WeatherCompanionApp/1.7.1 (johnbalmedina30@gmail.com)'
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
    // ... (rest of the function is the same) ...
    developer.log('[HomeScreen] Reverse geocoding coords: ($lat, $lon)...',
        name: 'HomeScreen');
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&countrycodes=ph&zoom=18&accept-language=en');
    developer.log('[HomeScreen] Nominatim Reverse URL: $url',
        name: 'HomeScreen');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'WeatherCompanionApp/2.0.0 (johnbalmedina30@gmail.com)'
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        developer.log('[HomeScreen] Nominatim Reverse Response: $data',
            name: 'HomeScreen');

        String foundName = address['neighbourhood'] ??
            address['suburb'] ??
            address['village'] ??
            address['town'] ??
            address['city'] ??
            data['display_name']?.split(',').first ??
            "Current Location";

        if (address['city'] != null && foundName != address['city']) {
          if (!foundName
              .toLowerCase()
              .contains(address['city'].toLowerCase())) {
            foundName = '$foundName, ${address['city']}';
          }
        }

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

  // --- MODIFIED: Update State (Added Timezone Logging/Handling) ---
  void _updateStateWithWeatherData(Map<String, dynamic> data,
      {String? locationNameOverride}) {
    if (!mounted) return;
    developer.log('[HomeScreen] Updating UI state with weather data...',
        name: 'HomeScreen');

    final current = data['current'] ?? {};
    final location = data['location'] ?? {};
    final forecast = data['forecast']?['forecastday'] ?? [];
    final todayForecast = (forecast.isNotEmpty) ? forecast[0] : null;
    final todayAstro = todayForecast?['astro'] ?? {};
    final todayDay = todayForecast?['day'] ?? {};

    // <-- TIMEZONE HANDLING -->
    final String apiTimezoneId =
        location['tz_id'] ?? 'UTC'; // Get timezone from transformed data
    final int apiUtcOffsetSeconds = location['utc_offset_seconds'] ?? 0;
    final String localTimeString =
        location['localtime'] ?? ""; // Use the estimated ISO string
    developer.log(
        '[HomeScreen] Time Update: API Timezone ID = $apiTimezoneId, Offset = $apiUtcOffsetSeconds s, Estimated Local ISO = $localTimeString',
        name: 'HomeScreen');

    String formattedLocalTime = "--:--";
    DateTime? parsedLocalTime;
    try {
      if (localTimeString.isNotEmpty) {
        // Parse the ISO string, treat it as local time
        parsedLocalTime = DateTime.parse(localTimeString).toLocal();
        formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
        developer.log(
            '[HomeScreen] Parsed local time: $parsedLocalTime, Formatted: $formattedLocalTime',
            name: 'HomeScreen');
      } else {
        developer.log(
            '[HomeScreen] Local time string empty. Falling back to device time.',
            name: 'HomeScreen');
        // Fallback to device time if API didn't provide it
        parsedLocalTime = DateTime.now();
        formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
      }
    } catch (e) {
      developer.log(
          '[HomeScreen] Error parsing local time string: $localTimeString. Error: $e. Falling back to device time.',
          name: 'HomeScreen',
          error: e);
      // Fallback on error
      parsedLocalTime = DateTime.now();
      formattedLocalTime = DateFormat('h:mm a').format(parsedLocalTime);
    }
    // <-- END TIMEZONE HANDLING -->

    // Hourly data processing
    final List<dynamic> allHours =
        (todayForecast != null && todayForecast['hour'] != null)
            ? (todayForecast['hour'] as List)
            : [];
    // Use the parsed local time for filtering
    final DateTime refTimeForHourly = parsedLocalTime ?? DateTime.now();
    final List<dynamic> newForecastHours = allHours.where((hour) {
      try {
        DateTime hourTime = DateTime.tryParse(hour['time'] ?? "")?.toLocal() ??
            refTimeForHourly;
        return !hourTime
            .isBefore(refTimeForHourly.subtract(const Duration(minutes: 30)));
      } catch (e) {
        developer.log(
            '[HomeScreen] Error parsing hour time for filtering: ${hour['time']}. Error: $e',
            name: 'HomeScreen');
        return false;
      }
    }).toList();

    // Use provided location name or the one from the transformed data
    final String newCityName =
        locationNameOverride ?? location['name'] ?? cityName;

    final double newTemp = (current['temp_c'] as num?)?.toDouble() ?? 0;
    final String newDesc = current['condition']?['text'] ?? "";
    final String newIcon = current['condition']?['icon'] ?? "";
    final int newHumidity = (current['humidity'] as num?)?.toInt() ?? 0;
    final double newWindSpeed = (current['wind_kph'] as num?)?.toDouble() ?? 0;

    // --- MODIFIED: Use _lastLat and _lastLon ---
    final double? newLat = _lastLat;
    final double? newLon = _lastLon;
    // --- END MODIFIED ---

    final double newFeelsLike =
        (current['feelslike_c'] as num?)?.toDouble() ?? 0;
    final double newUvIndex = (current['uv'] as num?)?.toDouble() ?? 0;

    final int newPrecipChance =
        (todayDay['daily_chance_of_rain'] as num?)?.toInt() ?? 0;
    final String newSunrise =
        todayAstro['sunrise'] ?? "N/A"; // Already formatted HH:MM
    final String newSunset =
        todayAstro['sunset'] ?? "N/A"; // Already formatted HH:MM

    setState(() {
      cityName = newCityName;
      temperature = newTemp;
      weatherDescription = newDesc;
      weatherIcon = newIcon;
      humidity = newHumidity;
      windSpeed = newWindSpeed;
      feelsLikeTemp = newFeelsLike;
      uvIndex = newUvIndex;
      precipitationChance = newPrecipChance;
      sunriseTime = newSunrise;
      sunsetTime = newSunset;
      localTime = formattedLocalTime; // Update state with formatted time
      timezoneId = apiTimezoneId; // <-- Store timezone ID
      forecastDays = forecast;
      forecastHours = newForecastHours;
      // _lastLat and _lastLon are already set in _fetchData
      // _lastLat = newLat; // No need to set them again here
      // _lastLon = newLon;

      if (_cityController.text != newCityName &&
          !newCityName.startsWith('Lat:')) {
        _cityController.text = newCityName;
      }

      _isLoading = false;
      _errorMessage = null;

      if (_animationsReady && !_animationController.isAnimating) {
        _animationController.repeat(reverse: true);
        developer.log('[HomeScreen] Starting animations.', name: 'HomeScreen');
      }
    });
    developer.log('[HomeScreen] Weather UI state updated.', name: 'HomeScreen');
  }

  // --- Fetch AI Greeting ---
  // ✅ MODIFIED TO PASS FORECAST DATA
  Future<void> _fetchAiGreeting(Map<String, dynamic> weatherData,
      {String? locationNameOverride}) async {
    if (!mounted) return;
    developer.log('[HomeScreen] Fetching AI greeting...', name: 'HomeScreen');
    setState(() => _greetingLoading = true);

    try {
      final location = weatherData['location'];
      final current = weatherData['current'];
      // ✅ GET FORECAST DAYS FROM THE ALREADY TRANSFORMED DATA
      final forecast = weatherData['forecast']?['forecastday'] ?? [];
      final String localTimeString = location['localtime'] ?? "";
      DateTime currentTime;
      try {
        currentTime =
            DateTime.parse(localTimeString).toLocal(); // Ensure it's local
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
        forecast, // ✅ PASS THE FORECAST DAYS HERE
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
    // ... (rest of the function is the same) ...
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
    // ... (rest of the function is the same) ...
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "???";
  }

  // --- Show Error Snackbar ---
  void _showErrorSnackbar(String message) {
    // ... (rest of the function is the same) ...
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- WIDGET BUILD (THEME AWARE) ---
  @override
  Widget build(BuildContext context) {
    // Get the current theme from the context
    final theme = Theme.of(context);

    final now = DateTime.now();
    final String formattedToday =
        "${_monthName(now.month)} ${now.day}, ${now.year}";
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final tempUnit = _currentTempUnit ?? TemperatureUnit.celsius;
    final windUnit = _currentWindUnit ?? WindSpeedUnit.kph;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // THEME AWARE
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // --- MODIFIED: Refresh logic ---
            developer.log('[HomeScreen] Pull-to-refresh triggered.',
                name: 'HomeScreen');
            // Check if a city is entered in the search bar
            if (_cityController.text.isNotEmpty) {
              await _fetchData(cityQueryOverride: _cityController.text);
            } else {
              // No city in search bar, check for default
              final String? defaultLocation =
                  await _settingsService.getDefaultLocation();
              if (defaultLocation != null && defaultLocation.isNotEmpty) {
                // Refresh default location
                await _fetchData(cityQueryOverride: defaultLocation);
              } else {
                // No default, refresh current location
                await _fetchData(useCurrentLocation: true);
              }
            }
            // --- END MODIFIED ---
          },
          color: theme.colorScheme.primary, // THEME AWARE
          backgroundColor: theme.appBarTheme.backgroundColor, // THEME AWARE
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                      _buildBodyContent(formattedToday, tempUnit, windUnit),
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
                              .withOpacity(0.5), // THEME AWARE
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
          "WeatherCompanion v2.0.0",
          style: theme.textTheme.titleMedium?.copyWith(
            // THEME AWARE
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
            style: theme.textTheme.bodyLarge, // THEME AWARE (text color)
            decoration: InputDecoration(
              hintText: "Enter city name",
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSecondaryContainer
                    .withOpacity(0.7), // THEME AWARE
              ),
              filled: true,
              fillColor: theme.colorScheme.secondaryContainer, // THEME AWARE
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.search,
                  color: theme.colorScheme.onSecondaryContainer), // THEME AWARE
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
              color: theme.iconTheme.color, size: 24), // THEME AWARE
          onPressed: () async {
            FocusScope.of(context).unfocus();
            _cityController.clear();
            await _fetchData(useCurrentLocation: true);
          },
          tooltip: "My Location",
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: Icon(Icons.refresh,
              color: theme.iconTheme.color, size: 24), // THEME AWARE
          onPressed: () {
            FocusScope.of(context).unfocus();
            // --- MODIFIED: Refresh button logic ---
            _fetchData(
                cityQueryOverride: _cityController.text.isNotEmpty
                    ? _cityController.text
                    : null,
                useCurrentLocation:
                    _cityController.text.isEmpty && _lastLat == null);
            // --- END MODIFIED ---
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
                  color: theme.colorScheme.primary))); // THEME AWARE
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
                color: Colors.redAccent, size: 40), // Error color is fine
            const SizedBox(height: 15),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                // THEME AWARE
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchData(
                  cityQueryOverride: _cityController.text.isNotEmpty
                      ? _cityController.text
                      : null,
                  // --- MODIFIED: Check _lastLat as well ---
                  useCurrentLocation:
                      _cityController.text.isEmpty && _lastLat == null),
              child: const Text('Try Again'),
            )
          ],
        )),
      );
    }

    // --- Main Content Display ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cityName,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold), // THEME AWARE
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
          localTime: localTime, // Passes the state variable
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
    );
  }

  // --- Build AI Greeting (THEME AWARE) ---
  Widget _buildAiGreeting() {
    final theme = Theme.of(context);
    if (_greetingLoading) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 2.0))); // THEME AWARE
    }
    if (_aiGreeting.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: theme.cardColor, // THEME AWARE
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color:
                  theme.colorScheme.onSurface.withOpacity(0.2)), // THEME AWARE
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
                // THEME AWARE
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

  // --- Build Hourly Forecast (THEME AWARE) ---
  Widget _buildHourlyForecast(TemperatureUnit tempUnit) {
    final theme = Theme.of(context);
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
              color: isNow
                  ? theme.colorScheme.primary.withOpacity(0.3)
                  : theme.cardColor, // THEME AWARE
              borderRadius: BorderRadius.circular(12),
              border: isNow
                  ? Border.all(color: theme.colorScheme.primary, width: 0.5)
                  : null, // THEME AWARE
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isNow ? "Now" : formattedTime,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600), // THEME AWARE
                ),
                const SizedBox(height: 5),
                WeatherIconImage(iconUrl: iconUrl, size: 35.0),
                const SizedBox(height: 5),
                Text(
                  tempUnit == TemperatureUnit.celsius
                      ? "${tempC.round()}°"
                      : "${_settingsService.toFahrenheit(tempC).round()}°",
                  style: theme.textTheme.bodyLarge, // THEME AWARE
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Build Daily Forecast (THEME AWARE) ---
  Widget _buildDailyForecast(TemperatureUnit tempUnit, WindSpeedUnit windUnit) {
    final theme = Theme.of(context);
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
                backgroundColor:
                    Colors.transparent, // Sheet itself defines color
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
                color: theme.cardColor, // THEME AWARE
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formattedDate,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600), // THEME AWARE
                  ),
                  const SizedBox(height: 5),
                  WeatherIconImage(iconUrl: forecastIconUrl, size: 40.0),
                  const SizedBox(height: 5),
                  Text(
                    "$displayMin$tempSymbol / $displayMax$tempSymbol",
                    style: theme.textTheme.bodyMedium, // THEME AWARE
                  ),
                  Text(
                    condition,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      // THEME AWARE
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
          backgroundColor:
              theme.colorScheme.surface.withOpacity(0.25), // THEME AWARE
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
                MaterialPageRoute(
                    builder: (_) =>
                        MapScreen(center: centerPoint, title: mapTitle)));
          },
          tooltip: 'Open Map',
          child: Icon(Icons.map,
              color: theme.colorScheme.primary, size: 24), // THEME AWARE
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

          final result = await Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()));

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
            // --- MODIFIED: Refresh logic after settings close ---
            // If a city is in the controller, refresh that.
            // Otherwise, check for a default.
            // Otherwise, use current location.
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
            // --- END MODIFIED ---
          }
        },
        backgroundColor:
            theme.colorScheme.surface.withOpacity(0.25), // THEME AWARE
        elevation: 6.0,
        tooltip: 'Settings',
        child: Icon(Icons.settings,
            color: theme.colorScheme.primary, size: 24), // THEME AWARE
      ),
    );
  }
} // End of _HomeScreenState
