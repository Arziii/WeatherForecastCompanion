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
// import 'package:nominatim_geocoding/nominatim_geocoding.dart'; // <-- REMOVED
import 'package:http/http.dart' as http; // <-- ADDED
import 'dart:convert'; // <-- ADDED
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

  @override
  void initState() {
    super.initState();
    developer.log('[HomeScreen] initState started', name: 'HomeScreen');
    // unawaited(NominatimGeocoding.init()); // <-- REMOVED
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

  Future<void> _loadSettingsAndInitialData() async {
    developer.log('[HomeScreen] Post-frame: Loading settings...',
        name: 'HomeScreen');
    try {
      await _loadSettings();
      developer.log('[HomeScreen] Settings loaded. Fetching initial data...',
          name: 'HomeScreen');
      await _fetchData(isInitialLoad: true);
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

  Future<void> _fetchData(
      {String? queryOverride, bool isInitialLoad = false}) async {
    if (!mounted) return;
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }
    setState(() {
      _errorMessage = null;
    });

    if (!isInitialLoad) {
      setState(() {
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }

    developer.log(
        '[HomeScreen] Starting _fetchData. QueryOverride: $queryOverride, InitialLoad: $isInitialLoad',
        name: 'HomeScreen');

    String locationQuery;
    Map<String, dynamic>? weatherData;
    String locationNameToUse; // To store the accurate name

    try {
      // 1. Determine Location Query
      if (queryOverride != null) {
        locationQuery = queryOverride;
        locationNameToUse = queryOverride; // Use query as the name
        developer.log('[HomeScreen] Using query override: $locationQuery',
            name: 'HomeScreen');
      } else {
        final savedLocations = await _settingsService.getSavedLocations();
        if ((isInitialLoad || _cityController.text.isEmpty) &&
            savedLocations.isNotEmpty) {
          locationQuery = savedLocations.first;
          locationNameToUse = savedLocations.first; // Use saved name
          developer.log(
              '[HomeScreen] Using first saved location: $locationQuery',
              name: 'HomeScreen');
        } else if (_cityController.text.isNotEmpty) {
          locationQuery = _cityController.text;
          locationNameToUse = _cityController.text; // Use text field name
          developer.log(
              '[HomeScreen] Using text controller location: $locationQuery',
              name: 'HomeScreen');
        } else {
          developer.log(
              '[HomeScreen] No override/saved/controller text. Getting current location...',
              name: 'HomeScreen');

          final locationDetails = await _determineCurrentLocationQuery();

          // ✅ --- FIX IS HERE --- ✅
          // Provide default values in case keys are missing
          locationQuery = locationDetails['query'] ??
              "14.474686,121.001959"; // Default to Parañaque coords
          locationNameToUse = locationDetails['name'] ??
              "Parañaque"; // Default to Parañaque name
          // -------------------------
        }
      }

      // Update city name optimistically
      if (mounted) {
        setState(() => cityName = locationNameToUse);
      }

      // 2. Fetch Weather Data
      developer.log('[HomeScreen] Fetching weather for query: $locationQuery',
          name: 'HomeScreen');
      weatherData = await _weatherService.fetchWeather(locationQuery);

      if (weatherData == null) {
        throw Exception('Failed to fetch weather data or city not found.');
      }
      developer.log('[HomeScreen] Weather data received successfully.',
          name: 'HomeScreen');

      // 3. Update State with Weather Data
      _updateStateWithWeatherData(weatherData,
          locationNameOverride: locationNameToUse);

      // 4. Fetch AI Greeting
      await _fetchAiGreeting(weatherData,
          locationNameOverride: locationNameToUse);
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

  // ✅ MODIFIED: Now returns a Map with 'name' and 'query'
  Future<Map<String, String>> _determineCurrentLocationQuery() async {
    developer.log('[HomeScreen] Attempting to determine current location...',
        name: 'HomeScreen');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();

      developer.log(
          '[HomeScreen] Location Check - Service Enabled: $serviceEnabled, Permission: $permission',
          name: 'HomeScreen');

      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied.');
      }

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
        if (lastKnown == null) {
          throw Exception('Failed to get current or last known location.');
        }
        return lastKnown;
      });

      developer.log(
          '[HomeScreen] Position obtained: (${position.latitude}, ${position.longitude}). Reverse geocoding...',
          name: 'HomeScreen');

      // --- ✅ NEW: Direct Nominatim API Call ---
      try {
        final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&countrycodes=ph&zoom=21&accept-language=en');

        developer.log('[HomeScreen] Nominatim URL: $url', name: 'HomeScreen');

        final response = await http.get(url, headers: {
          'User-Agent': 'WeatherCompanionApp/1.7.1 (johnbalmedina30@gmail.com)'
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final address = data['address'];
          developer.log('[HomeScreen] Nominatim Response: $data',
              name: 'HomeScreen');

          String foundName = address['neighbourhood'] ??
              address['suburb'] ??
              address['village'] ??
              address['town'] ??
              address['city'] ??
              "Current Location";

          developer.log(
              '[HomeScreen] Nominatim success. Using name: $foundName',
              name: 'HomeScreen');

          return {
            'name': foundName,
            'query': "${position.latitude},${position.longitude}"
          };
        } else {
          developer.log(
              '[HomeScreen] Nominatim failed with status ${response.statusCode}. Using coordinate query.',
              name: 'HomeScreen');
          return {
            'name': 'Current Location',
            'query': "${position.latitude},${position.longitude}"
          };
        }
      } catch (e) {
        developer.log(
            '[HomeScreen] Nominatim HTTP error: $e. Using coordinate query.',
            name: 'HomeScreen',
            error: e);
        return {
          'name': 'Current Location',
          'query': "${position.latitude},${position.longitude}"
        };
      }
      // --- End Nominatim ---
    } on TimeoutException {
      developer.log('[HomeScreen] Location timeout. Falling back to default.',
          name: 'HomeScreen');
      throw Exception('Getting location timed out.');
    } catch (e) {
      developer.log(
          '[HomeScreen] Error getting location: $e. Falling back to default "Paranaque".',
          name: 'HomeScreen',
          error: e);
      _showErrorSnackbar(e.toString().replaceFirst("Exception: ", ""));
      return {'name': "Paranaque", 'query': "Paranaque"}; // Default fallback
    }
  }

  void _updateStateWithWeatherData(Map<String, dynamic> data,
      {String? locationNameOverride}) {
    if (!mounted) return;
    developer.log('[HomeScreen] Updating UI state with weather data...',
        name: 'HomeScreen');

    final current = data['current'];
    final location = data['location'];
    final forecast = data['forecast']?['forecastday'] ?? [];
    final todayForecast = (forecast.isNotEmpty) ? forecast[0] : null;
    final todayAstro = todayForecast?['astro'] ?? {};
    final todayDay = todayForecast?['day'] ?? {};

    final List<dynamic> allHours =
        (todayForecast != null && todayForecast['hour'] != null)
            ? (todayForecast['hour'] as List)
            : [];
    final now = DateTime.now();
    final List<dynamic> newForecastHours = allHours.where((hour) {
      try {
        DateTime hourTime = DateTime.tryParse(hour['time'] ?? "") ?? now;
        return hourTime.hour >= now.hour;
      } catch (e) {
        return false;
      }
    }).toList();

    final String newCityName =
        locationNameOverride ?? location['name'] ?? cityName;

    final double newTemp = (current['temp_c'] as num?)?.toDouble() ?? 0;
    final String newDesc = current['condition']?['text'] ?? "";
    final String newIcon = current['condition']?['icon'] ?? "";
    final int newHumidity = (current['humidity'] as num?)?.toInt() ?? 0;
    final double newWindSpeed = (current['wind_kph'] as num?)?.toDouble() ?? 0;
    final double? newLat = (location['lat'] as num?)?.toDouble();
    final double? newLon = (location['lon'] as num?)?.toDouble();
    final double newFeelsLike =
        (current['feelslike_c'] as num?)?.toDouble() ?? 0;
    final double newUvIndex = (current['uv'] as num?)?.toDouble() ?? 0;
    final int newPrecipChance =
        (todayDay['daily_chance_of_rain'] as num?)?.toInt() ??
            (todayDay['daily_chance_of_snow'] as num?)?.toInt() ??
            0;
    final String newSunrise = todayAstro['sunrise'] ?? "N/A";
    final String newSunset = todayAstro['sunset'] ?? "N/A";

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
      forecastDays = forecast;
      forecastHours = newForecastHours;
      _lastLat = newLat;
      _lastLon = newLon;
      if (_cityController.text != newCityName && !newCityName.contains(',')) {
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

  Future<void> _fetchAiGreeting(Map<String, dynamic> weatherData,
      {String? locationNameOverride}) async {
    if (!mounted) return;
    developer.log('[HomeScreen] Fetching AI greeting...', name: 'HomeScreen');
    setState(() => _greetingLoading = true);

    try {
      final location = weatherData['location'];
      final current = weatherData['current'];
      final String localTimeString = location['localtime'] ?? "";
      DateTime currentTime;
      try {
        currentTime = DateTime.parse(localTimeString);
      } catch (e) {
        currentTime = DateTime.now();
      }

      final String nameForAI =
          locationNameOverride ?? location['name'] ?? "your city";

      final generatedGreeting = await _aiGreetingService.generateGreeting(
        current['condition']?['text'] ?? "",
        nameForAI,
        (current['temp_c'] as num?)?.toDouble() ?? 0,
        currentTime,
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

  Future<Position?> _tryGetCurrentLocation() async {
    developer.log('[HomeScreen] Map Button: Trying to get current location...',
        name: 'HomeScreen');
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied.');
      }

      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp!).inMinutes < 5) {
        developer.log(
            '[HomeScreen] Map Button: Using recent last known location.',
            name: 'HomeScreen');
        return lastKnown;
      } else {
        developer.log(
            '[HomeScreen] Map Button: Last known old/null. Getting current (10s timeout)...',
            name: 'HomeScreen');
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      String errorMsg =
          'Failed to get location for map: ${e.toString().replaceFirst("Exception: ", "")}';
      developer.log(errorMsg, name: 'HomeScreen', error: e);
      _showErrorSnackbar(errorMsg);
      return null;
    }
  }

  String _monthName(int month) {
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

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // --- WIDGET BUILD ---
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String formattedToday =
        "${_monthName(now.month)} ${now.day}, ${now.year}";
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final tempUnit = _currentTempUnit ?? TemperatureUnit.celsius;
    final windUnit = _currentWindUnit ?? WindSpeedUnit.kph;

    return Scaffold(
      backgroundColor: const Color(0xFF3949AB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchData(),
          color: Colors.white,
          backgroundColor: const Color(0xFF3F51B5),
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
                child: const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text("Developed by Team WFC",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 8,
                            fontStyle: FontStyle.italic)),
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

  // --- Refactored Build Methods ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset("assets/images/logo.png",
            height: 28,
            width: 28,
            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        const SizedBox(width: 8),
        const Text("WeatherCompanion • Beta v1.7.1",
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter city name",
              hintStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: Colors.white.withOpacity(0.2),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              isDense: true,
            ),
            onSubmitted: (v) {
              if (v.isNotEmpty) _fetchData(queryOverride: v);
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        const SizedBox(width: 5),
        IconButton(
          icon: const Icon(Icons.my_location, color: Colors.white, size: 24),
          onPressed: () async {
            FocusScope.of(context).unfocus();
            _cityController.clear();
            await _fetchData();
          },
          tooltip: "My Location",
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
          onPressed: () {
            FocusScope.of(context).unfocus();
            _fetchData();
          },
          tooltip: "Refresh",
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildBodyContent(
      String formattedToday, TemperatureUnit tempUnit, WindSpeedUnit windUnit) {
    if (_isLoading) {
      return const SizedBox(
        height: 400,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_errorMessage != null) {
      return Container(
        height: 400,
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 15),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _fetchData(),
              child: const Text('Try Again'),
            )
          ],
        )),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cityName,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        WeatherCard(
          displayTemperature: tempUnit == TemperatureUnit.celsius
              ? temperature
              : _settingsService.toFahrenheit(temperature),
          tempUnitSymbol: tempUnit == TemperatureUnit.celsius ? 'C' : 'F',
          icon: weatherIcon,
          description: weatherDescription,
          date: formattedToday,
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
        if (forecastDays.length > 1) _buildDailyForecast(tempUnit, windUnit),
        if (forecastDays.length > 1) const SizedBox(height: 25),
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

  Widget _buildAiGreeting() {
    if (_greetingLoading) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.0)));
    }
    if (_aiGreeting.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 40, width: 40),
            const SizedBox(height: 10),
            Text(_aiGreeting,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.4)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHourlyForecast(TemperatureUnit tempUnit) {
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
            parsedTime = DateTime.parse(timeStr);
            formattedTime = DateFormat('h a').format(parsedTime.toLocal());
          } catch (e) {
            developer.log('[HomeScreen] Error parsing hour time: $e',
                name: 'HomeScreen');
          }

          bool isNow = index == 0 &&
              parsedTime != null &&
              parsedTime.toLocal().hour == DateTime.now().hour;
          if (isNow) formattedTime = "Now";

          return Container(
            width: 80,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isNow
                  ? Colors.white.withOpacity(0.35)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border:
                  isNow ? Border.all(color: Colors.white, width: 0.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formattedTime,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 5),
                WeatherIconImage(iconUrl: iconUrl, size: 35.0),
                const SizedBox(height: 5),
                Text(
                  tempUnit == TemperatureUnit.celsius
                      ? "${tempC.round()}°"
                      : "${_settingsService.toFahrenheit(tempC).round()}°",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyForecast(TemperatureUnit tempUnit, WindSpeedUnit windUnit) {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: forecastDays.length - 1,
        itemBuilder: (context, index) {
          final day = forecastDays[index + 1];
          final dateStr = day['date'] ?? "";
          DateTime parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
          final formattedDate = "${_monthName(parsed.month)} ${parsed.day}";
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
          final String tempSymbol =
              tempUnit == TemperatureUnit.celsius ? "°" : "°";

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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formattedDate,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  WeatherIconImage(iconUrl: forecastIconUrl, size: 40.0),
                  const SizedBox(height: 5),
                  Text("$displayMin$tempSymbol / $displayMax$tempSymbol",
                      style: const TextStyle(color: Colors.white)),
                  Text(condition,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapButton() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, -_bounceAnimation.value), child: child),
        child: FloatingActionButton(
          heroTag: "map_fab", // Added heroTag
          backgroundColor: Colors.white.withOpacity(0.35),
          elevation: 4.0,
          mini: true,
          onPressed: () async {
            Position? position = await _tryGetCurrentLocation();
            if (!mounted) return;

            LatLng centerPoint;
            String mapTitle;

            if (position != null) {
              centerPoint = LatLng(position.latitude, position.longitude);
              mapTitle = "My Location";
              developer.log(
                  '[HomeScreen] Opening map for My Location: $centerPoint',
                  name: 'HomeScreen');
            } else {
              centerPoint =
                  LatLng(_lastLat ?? 14.474686, _lastLon ?? 121.001959);
              mapTitle = cityName;
              developer.log(
                  '[HomeScreen] Opening map for last known weather location ($cityName): $centerPoint',
                  name: 'HomeScreen');
            }

            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        MapScreen(center: centerPoint, title: mapTitle)));
          },
          tooltip: 'Open Map',
          child: const Icon(Icons.map, color: Color(0xFF3F51B5), size: 24),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) => Transform.translate(
          offset: Offset(0, -_bounceAnimation.value), child: child),
      child: FloatingActionButton(
        heroTag: "settings_fab", // Added heroTag
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
            _cityController.text = result;
            await _fetchData(queryOverride: result);
          } else {
            developer.log(
                '[HomeScreen] No specific city selected or units changed. Refreshing current view...',
                name: 'HomeScreen');
            await _fetchData();
          }
        },
        backgroundColor: Colors.white.withOpacity(0.35),
        elevation: 6.0,
        tooltip: 'Settings',
        child: const Icon(Icons.settings, color: Color(0xFF3F51B5), size: 24),
      ),
    );
  }
}
