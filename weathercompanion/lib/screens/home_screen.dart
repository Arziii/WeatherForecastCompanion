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
import 'dart:async'; // Needed for TimeoutException and unawaited

// ✅ ADDED: Import for Nominatim
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

// Import the Settings Service and Screen
import 'package:weathercompanion/services/settings_service.dart';
import 'package:weathercompanion/screens/settings_screen.dart';

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

  TemperatureUnit _currentTempUnit = TemperatureUnit.celsius;
  WindSpeedUnit _currentWindUnit = WindSpeedUnit.kph;

  String _aiGreeting = "";
  bool _greetingLoading = false;

  String cityName = "Paranaque";
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "";
  List<dynamic> forecastDays = [];
  bool isLoading = true;

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
    unawaited(NominatimGeocoding.init());
    _loadSettings();
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat(reverse: true);
      _bounceAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationsReady = true;
      print("Animations initialized successfully.");
    } catch (e) {
      print("Error initializing animations: $e");
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialWeather();
    });
  }

  Future<void> _loadSettings() async {
    _currentTempUnit = await _settingsService.getTemperatureUnit();
    _currentWindUnit = await _settingsService.getWindSpeedUnit();
    if (mounted) setState(() {});
    print("Settings loaded: Temp=$_currentTempUnit, Wind=$_currentWindUnit");
  }

  @override
  void dispose() {
    if (_animationsReady) {
      _animationController.dispose();
    }
    _cityController.dispose();
    super.dispose();
  }

  //
  // ✅ --- THIS FUNCTION IS UPDATED WITH CORRECT PROPERTIES ---
  //
  Future<void> _loadInitialWeather() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position? position;
    String finalQuery = "Paranaque"; // Fallback

    if (!mounted) return;
    if (!isLoading) {
      setState(() {
        isLoading = true;
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }
    print("--- Starting _loadInitialWeather (Using Nominatim) ---");

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      permission = await Geolocator.checkPermission();
      print(
        "Startup Checks - Service Enabled: $serviceEnabled, Permission: $permission",
      );

      if (serviceEnabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always)) {
        print(
          "Startup CP: Attempting to get current position (timeout 15s)...",
        );
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 15),
          );
          print(
            "Startup CP: Got current position: (${position?.latitude}, ${position?.longitude})",
          );
        } on TimeoutException {
          print("Startup CP: Timed out... Trying Last Known...");
          position = await Geolocator.getLastKnownPosition();
          print(
            "Startup LKP after Timeout: (${position?.latitude}, ${position?.longitude})",
          );
        } catch (e) {
          print("Startup CP: Error: $e. Trying Last Known...");
          position = await Geolocator.getLastKnownPosition();
          print(
            "Startup LKP after Error: (${position?.latitude}, ${position?.longitude})",
          );
        }

        // --- HERE IS THE CORRECTED NOMINATIM LOGIC ---
        if (position != null) {
          print(
            "Startup: Position found. Attempting Nominatim reverse geocode...",
          );
          try {
            Coordinate coordinate = Coordinate(
              latitude: position.latitude,
              longitude: position.longitude,
            );
            Geocoding geo = await NominatimGeocoding.to.reverseGeoCoding(
              coordinate,
            );

            // ✅ FIX: Check for city, then suburb, then neighbourhood
            if (geo.address.city.isNotEmpty) {
              finalQuery = geo.address.city;
            } else if (geo.address.suburb.isNotEmpty) {
              // Use suburb
              finalQuery = geo.address.suburb;
            } else if (geo.address.neighbourhood.isNotEmpty) {
              // Use neighbourhood
              finalQuery = geo.address.neighbourhood;
            } else {
              print(
                "Nominatim couldn't find city/suburb/neighbourhood. Defaulting to 'Paranaque'.",
              );
            }
            print(
              "Startup: Nominatim reverse geocode success. Final query will be: '$finalQuery'",
            );
          } catch (e) {
            print(
              "Startup: Nominatim reverse geocode FAILED: $e. Defaulting to 'Paranaque'.",
            );
          }
        } else {
          print(
            "Startup: No position obtained. Final query defaults to '$finalQuery'.",
          );
        }
      } else {
        print(
          "Startup Checks Failed: Location off/denied. Final query defaults to '$finalQuery'.",
        );
      }
    } catch (e) {
      print(
        "Startup Error: Unexpected error: $e. Final query defaults to '$finalQuery'.",
      );
    }

    print(
      "--- Calling _fetchWeatherAndGreeting with final query: '$finalQuery' ---",
    );
    await _fetchWeatherAndGreeting(finalQuery);
  }

  Future<Position?> _tryGetCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position? position;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are permanently denied...'),
          ),
        );
      return null;
    }

    try {
      position = await Geolocator.getLastKnownPosition();
      if (position != null &&
          DateTime.now().difference(position.timestamp!).inMinutes < 5) {
        print("Map Button: Using recent last known location.");
        return position;
      } else {
        print(
          "Map Button: Last known location old/null. Getting current position.",
        );
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      }
    } catch (e) {
      String errorMsg = 'Failed to get location: $e';
      if (e is TimeoutException) {
        errorMsg = 'Could not get location fix in time.';
        print("Failed to get location: Timed out.");
      } else {
        print("Failed to get location: $e");
      }
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      return null;
    }
  }

  Future<void> _fetchWeatherAndGreeting([String? queryOverride]) async {
    if (!mounted) return;
    if (!isLoading && !_greetingLoading) {
      setState(() {
        isLoading = true;
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }

    final String query =
        queryOverride ??
        (_cityController.text.isNotEmpty ? _cityController.text : cityName);

    print("Fetching weather for query: $query");
    Map<String, dynamic>? data;

    try {
      data = await _weatherService.fetchWeather(query);
      print("Weather data received: ${data != null}");

      if (data != null && mounted) {
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
            return DateTime.parse(hour['time']).hour >= now.hour;
          } catch (e) {
            return false;
          }
        }).toList();

        final String newCityName = location['name'] ?? cityName;
        final double newTemp = (current['temp_c'] as num?)?.toDouble() ?? 0;
        final String newDesc = current['condition']?['text'] ?? "";
        final String newIcon = current['condition']?['icon'] ?? "";
        final int newHumidity = (current['humidity'] as num?)?.toInt() ?? 0;
        final double newWindSpeed =
            (current['wind_kph'] as num?)?.toDouble() ?? 0;
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

        final String localTimeString = location['localtime'] ?? "";
        DateTime currentTime;
        try {
          currentTime = DateTime.parse(localTimeString);
        } catch (e) {
          currentTime = DateTime.now();
        }
        final greetingFuture = _aiGreetingService.generateGreeting(
          newDesc,
          newCityName,
          newTemp,
          currentTime,
        );

        print("Updating UI state with weather...");
        if (mounted) {
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
            if (_cityController.text != newCityName) {
              _cityController.text = newCityName;
            }
            isLoading = false;
          });
        }
        print("Weather UI state updated.");

        final generatedGreeting = await greetingFuture;
        if (mounted) {
          setState(() {
            _aiGreeting = generatedGreeting;
            _greetingLoading = false;
          });
          print("AI Greeting received and updated.");
        }
      } else {
        print("Weather data was null.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("City not found or network issue.")),
          );
          if (mounted)
            setState(() {
              isLoading = false;
              _greetingLoading = false;
            });
        }
      }
    } catch (e) {
      print("Error in _fetchWeatherAndGreeting: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
        if (mounted)
          setState(() {
            isLoading = false;
            _greetingLoading = false;
          });
      }
    } finally {
      if (mounted && (isLoading || _greetingLoading)) {
        print("Finally block cleaning up loading states.");
        setState(() {
          isLoading = false;
          _greetingLoading = false;
        });
      }
    }
  }

  //
  // ✅ --- THIS FUNCTION IS UPDATED WITH CORRECT PROPERTIES ---
  //
  Future<void> _getUserLocationAndFetchWeather() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }
    final Position? position = await _tryGetCurrentLocation();
    if (position != null) {
      String query = "${position.latitude},${position.longitude}"; // Fallback
      print(
        "My Location Button: Position found. Attempting Nominatim reverse geocode...",
      );

      try {
        Coordinate coordinate = Coordinate(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        Geocoding geo = await NominatimGeocoding.to.reverseGeoCoding(
          coordinate,
        );

        String? foundName;
        // ✅ FIX: Check for city, then suburb, then neighbourhood
        if (geo.address.city.isNotEmpty) {
          foundName = geo.address.city;
        } else if (geo.address.suburb.isNotEmpty) {
          // Use suburb
          foundName = geo.address.suburb;
        } else if (geo.address.neighbourhood.isNotEmpty) {
          // Use neighbourhood
          foundName = geo.address.neighbourhood;
        }

        if (foundName != null) {
          query = foundName; // Overwrite query with city name
          print(
            "My Location Button: Nominatim success. Using name query: '$query'",
          );
        } else {
          print(
            "My Location Button: Nominatim found no specific name. Using coordinate query: '$query'",
          );
        }
      } catch (e) {
        print(
          "My Location Button: Nominatim failed: $e. Using coordinate query: '$query'",
        );
      }

      await _fetchWeatherAndGreeting(query);
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
          _greetingLoading = false;
        });
      }
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
      "Dec",
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return "???";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String formattedToday =
        "${_monthName(now.month)} ${now.day}, ${now.year}";
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFF3949AB),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/logo.png",
                          height: 28,
                          width: 28,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "WeatherCompanion • Beta v1.7.0", // Updated version
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Search Bar Row
                    Row(
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
                                borderSide: BorderSide.none,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.white,
                              ),
                            ),
                            onSubmitted: (v) {
                              if (v.isNotEmpty) _fetchWeatherAndGreeting();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.my_location,
                            color: Colors.white,
                          ),
                          onPressed: _getUserLocationAndFetchWeather,
                          tooltip: "My Location",
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => _fetchWeatherAndGreeting(null),
                          tooltip: "Refresh",
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // City Name
                    Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Weather Card or Loading
                    if (isLoading)
                      const Center(
                        child: SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    else
                      WeatherCard(
                        displayTemperature:
                            _currentTempUnit == TemperatureUnit.celsius
                            ? temperature
                            : _settingsService.toFahrenheit(temperature),
                        tempUnitSymbol:
                            _currentTempUnit == TemperatureUnit.celsius
                            ? 'C'
                            : 'F',
                        icon: weatherIcon,
                        description: weatherDescription,
                        date: formattedToday,
                        humidity: humidity,
                        displayWindSpeed: _currentWindUnit == WindSpeedUnit.kph
                            ? windSpeed
                            : _settingsService.toMph(windSpeed),
                        windUnitSymbol: _currentWindUnit == WindSpeedUnit.kph
                            ? 'kph'
                            : 'mph',
                        feelsLikeTemp:
                            _currentTempUnit == TemperatureUnit.celsius
                            ? feelsLikeTemp
                            : _settingsService.toFahrenheit(feelsLikeTemp),
                        uvIndex: uvIndex,
                        precipitationChance: precipitationChance,
                        sunriseTime: sunriseTime,
                        sunsetTime: sunsetTime,
                      ),
                    const SizedBox(height: 25),
                    // AI Greeting or Loading
                    if (_greetingLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.0),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        ),
                      )
                    else if (_aiGreeting.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 40,
                              width: 40,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _aiGreeting,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_greetingLoading || _aiGreeting.isNotEmpty)
                      const SizedBox(height: 25),
                    // Hourly Forecast
                    if (!isLoading && forecastHours.isNotEmpty) ...[
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: forecastHours.length,
                          itemBuilder: (context, index) {
                            final hourData = forecastHours[index];
                            final timeStr = hourData['time'] ?? "";
                            final tempC =
                                (hourData['temp_c'] as num?)?.toDouble() ?? 0;
                            final iconUrl =
                                hourData['condition']?['icon'] ?? "";
                            String formattedTime = "N/A";
                            DateTime? parsedTime;
                            try {
                              parsedTime = DateTime.parse(timeStr);
                              formattedTime = DateFormat(
                                'h a',
                              ).format(parsedTime);
                            } catch (e) {}
                            bool isNow =
                                index == 0 &&
                                parsedTime != null &&
                                parsedTime.hour == DateTime.now().hour;
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
                                border: isNow
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 0.5,
                                      )
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  WeatherIconImage(
                                    iconUrl: iconUrl,
                                    size: 35.0,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _currentTempUnit == TemperatureUnit.celsius
                                        ? "${tempC.round()}°"
                                        : "${_settingsService.toFahrenheit(tempC).round()}°",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                    // 7-Day Forecast
                    if (!isLoading && forecastDays.isNotEmpty) ...[
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: forecastDays.length > 0
                              ? forecastDays.length - 1
                              : 0,
                          itemBuilder: (context, index) {
                            final day = forecastDays[index + 1];
                            final dateStr = day['date'] ?? "";
                            DateTime parsed =
                                DateTime.tryParse(dateStr) ?? DateTime.now();
                            final formattedDate =
                                "${_monthName(parsed.month)} ${parsed.day}";
                            final dayInfo = day['day'] ?? {};
                            final condition =
                                dayInfo['condition']?['text'] ?? "";
                            final String forecastIconUrl =
                                dayInfo['condition']?['icon'] ?? "";
                            final minTempC =
                                (dayInfo['mintemp_c'] as num?)?.toInt() ?? 0;
                            final maxTempC =
                                (dayInfo['maxtemp_c'] as num?)?.toInt() ?? 0;
                            final String displayMin =
                                _currentTempUnit == TemperatureUnit.celsius
                                ? "$minTempC"
                                : "${_settingsService.toFahrenheit(minTempC.toDouble()).round()}";
                            final String displayMax =
                                _currentTempUnit == TemperatureUnit.celsius
                                ? "$maxTempC"
                                : "${_settingsService.toFahrenheit(maxTempC.toDouble()).round()}";
                            final String tempSymbol =
                                _currentTempUnit == TemperatureUnit.celsius
                                ? "°"
                                : "°";
                            return InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => ForecastDetailSheet(
                                    dayData: day,
                                    tempUnit: _currentTempUnit,
                                    windUnit: _currentWindUnit,
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      formattedDate,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    WeatherIconImage(
                                      iconUrl: forecastIconUrl,
                                      size: 40.0,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "$displayMin$tempSymbol / $displayMax$tempSymbol",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      condition,
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),
                    // AI Chat Box
                    AiAssistantWidget(
                      cityName: cityName,
                      temperature: temperature,
                      weatherDescription: weatherDescription,
                      forecastDays: forecastDays,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
            // Footer
            Visibility(
              visible: !isKeyboardOpen,
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    "Developed by Team WFC",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 8,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ),

            // Map Button
            if (_animationsReady)
              Positioned(
                bottom: 16,
                left: 16,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: FloatingActionButton(
                    backgroundColor: Colors.white.withOpacity(0.35),
                    elevation: 6.0,
                    onPressed: () async {
                      Position? position = await _tryGetCurrentLocation();
                      if (!mounted) return;
                      if (position != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              center: LatLng(
                                position.latitude,
                                position.longitude,
                              ),
                              title: "My Location",
                            ),
                          ),
                        );
                      } else {
                        final lat = _lastLat ?? 14.5995;
                        final lon = _lastLon ?? 120.9842;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              center: LatLng(lat, lon),
                              title: cityName,
                            ),
                          ),
                        );
                      }
                    },
                    child: const Icon(
                      Icons.map,
                      color: Color(0xFF3949AB),
                      size: 24,
                    ),
                    tooltip: 'Open Map',
                  ),
                ),
              ),
          ],
        ),
      ),
      // Settings Button
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _animationsReady
          ? AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_bounceAnimation.value),
                  child: child,
                );
              },
              child: FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );

                  await _loadSettings();

                  if (result is String && result.isNotEmpty && mounted) {
                    print("Received city from SettingsScreen: $result");
                    _cityController.text = result;
                    _fetchWeatherAndGreeting(result);
                  } else {
                    print(
                      "Returning from settings, refetching current weather.",
                    );
                    _fetchWeatherAndGreeting(null);
                  }
                },
                backgroundColor: Colors.white,
                elevation: 6.0,
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF3949AB),
                  size: 28,
                ),
                tooltip: 'Settings',
              ),
            )
          : null,
    );
  }
}
