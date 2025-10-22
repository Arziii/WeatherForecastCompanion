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
import 'dart:async'; // Needed for TimeoutException
// Removed http and dart:convert imports as Nominatim function is removed

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  // <<< Ensure this mixin is present
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();
  final AiGreetingService _aiGreetingService = AiGreetingService();

  String _aiGreeting = "";
  bool _greetingLoading = false;

  String cityName = "Manila"; // Default city
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "";
  List<dynamic> forecastDays = [];
  bool isLoading = true; // Overall loading state for weather data

  double? _lastLat;
  double? _lastLon;

  // Animation Variables
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;
  bool _animationsReady = false;

  List<dynamic> forecastHours = [];

  // Detailed current conditions
  double feelsLikeTemp = 0;
  double uvIndex = 0;
  int precipitationChance = 0;
  String sunriseTime = "";
  String sunsetTime = "";

  @override
  void initState() {
    super.initState();

    // Initialize animations safely
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

    // Schedule the async weather load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitialWeather();
    });
  }

  @override
  void dispose() {
    if (_animationsReady) {
      _animationController.dispose();
    }
    _cityController.dispose();
    super.dispose();
  }

  /// Fetches weather on startup using Coordinates directly (No Nominatim).
  /// THIS IS THE ONLY VERSION OF THIS FUNCTION
  Future<void> _loadInitialWeather() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position? position;
    String finalQuery = "Manila"; // Default query

    if (!mounted) return;
    setState(() {
      isLoading = true;
      _greetingLoading = true;
      _aiGreeting = "";
    });
    print("--- Starting _loadInitialWeather (Using Coordinates Only) ---");

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
          print(
            "Startup CP: Timed out getting current position. Trying Last Known...",
          );
          position =
              await Geolocator.getLastKnownPosition(); // Fallback to LKP on timeout
          print(
            "Startup LKP after Timeout: (${position?.latitude}, ${position?.longitude})",
          );
        } catch (e) {
          print(
            "Startup CP: Error getting current position: $e. Trying Last Known...",
          );
          position =
              await Geolocator.getLastKnownPosition(); // Fallback to LKP on error
          print(
            "Startup LKP after Error: (${position?.latitude}, ${position?.longitude})",
          );
        }

        // Use coordinates directly if position was obtained
        if (position != null) {
          finalQuery = "${position.latitude},${position.longitude}";
          print(
            "Startup Position Found. Final query will be Coordinates: '$finalQuery'",
          );
        } else {
          print(
            "Startup: No position obtained. Final query defaults to '$finalQuery'.",
          );
          // finalQuery remains "Manila"
        }
      } else {
        print(
          "Startup Checks Failed: Location off/denied. Final query defaults to '$finalQuery'.",
        );
        // finalQuery remains "Manila"
      }
    } catch (e) {
      print(
        "Startup Error: Unexpected error: $e. Final query defaults to '$finalQuery'.",
      );
      // finalQuery remains "Manila"
    }

    print(
      "--- Calling _fetchWeatherAndGreeting with final query: '$finalQuery' ---",
    );
    await _fetchWeatherAndGreeting(finalQuery);
  }

  /// Tries to get the current location for Map Button (tries LKP first).
  Future<Position?> _tryGetCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    Position? position;

    // Check Service Enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return null;
    }

    // Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
      }
      return null;
    }

    // If permissions okay, proceed
    try {
      // 1. Try LKP first
      position = await Geolocator.getLastKnownPosition();
      if (position != null &&
          DateTime.now().difference(position.timestamp!).inMinutes < 5) {
        print("Map Button: Using recent last known location.");
        return position;
      } else {
        // 2. If LKP fails or is old, get CP
        print(
          "Map Button: Last known location old/null. Getting current position.",
        );
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(
            seconds: 10,
          ), // Shorter timeout for button press OK
        );
      }
    } catch (e) {
      // Handle errors
      String errorMsg = 'Failed to get location: $e';
      if (e is TimeoutException) {
        errorMsg = 'Could not get location fix in time.';
        print("Failed to get location: Timed out.");
      } else {
        print("Failed to get location: $e");
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
      return null;
    }
  }

  // <<< REMOVED the _getCityNameFromCoords function definition >>>

  /// Fetches Weather and AI Greeting. Accepts city name OR coordinates string.
  Future<void> _fetchWeatherAndGreeting([String? queryOverride]) async {
    if (!mounted) return;
    // Set loading states only if not already loading
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
        // ... (Parsing logic remains the same)
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

        // --- Generate Greeting ---
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

        // --- Update UI State ---
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
            isLoading = false; // Main loading done
          });
        }
        print("Weather UI state updated.");

        // --- Wait for greeting ---
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

  /// Handles the "My Location" button press (Uses coordinates directly).
  Future<void> _getUserLocationAndFetchWeather() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        _greetingLoading = true;
        _aiGreeting = "";
      });
    }

    final Position? position =
        await _tryGetCurrentLocation(); // Tries LKP first

    if (position != null) {
      // ✅ Directly use coordinates
      String query = "${position.latitude},${position.longitude}";
      print("My Location Button: Using Coordinates query: $query");
      await _fetchWeatherAndGreeting(query);
    } else {
      // Failed (snackbar already shown)
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
                    // Header Row...
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
                          "WeatherCompanion • Beta v1.5.9", // Update version as needed
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
                    // Search Bar Row...
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
                            onSubmitted: (value) {
                              if (value.isNotEmpty) _fetchWeatherAndGreeting();
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
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: () => _fetchWeatherAndGreeting(null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // City Name Text...
                    Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Weather Card or Loading...
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
                        temperature: temperature,
                        icon: weatherIcon,
                        description: weatherDescription,
                        date: formattedToday,
                        humidity: humidity,
                        windSpeed: windSpeed,
                        feelsLikeTemp: feelsLikeTemp,
                        uvIndex: uvIndex,
                        precipitationChance: precipitationChance,
                        sunriseTime: sunriseTime,
                        sunsetTime: sunsetTime,
                      ),
                    const SizedBox(height: 25),
                    // AI Greeting or Loading...
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
                            ), // Use correct mascot image path
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
                    // Hourly Forecast...
                    if (!isLoading && forecastHours.isNotEmpty) ...[
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: forecastHours.length,
                          itemBuilder: (context, index) {
                            final hourData = forecastHours[index];
                            final timeStr = hourData['time'] ?? "";
                            final temp =
                                (hourData['temp_c'] as num?)?.round() ?? 0;
                            final iconUrl =
                                hourData['condition']?['icon'] ?? "";
                            String formattedTime = "N/A";
                            DateTime? parsedTime;
                            try {
                              parsedTime = DateTime.parse(timeStr);
                              formattedTime = DateFormat(
                                'h a',
                              ).format(parsedTime);
                            } catch (e) {
                              /* keep N/A */
                            }
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
                                    "$temp°",
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
                    // 7-Day Forecast...
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
                            final minTemp =
                                (dayInfo['mintemp_c'] as num?)?.toInt() ?? 0;
                            final maxTemp =
                                (dayInfo['maxtemp_c'] as num?)?.toInt() ?? 0;
                            return InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) =>
                                      ForecastDetailSheet(dayData: day),
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
                                      "$minTemp° / $maxTemp°",
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
                    // AI Chat Box...
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
            // Footer...
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
          ],
        ),
      ),
      // Map Button...
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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
                backgroundColor: Colors.white,
                elevation: 6.0,
                onPressed: () async {
                  Position? position = await _tryGetCurrentLocation();
                  if (!mounted) return;
                  if (position != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          center: LatLng(position.latitude, position.longitude),
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
              ),
            )
          : null,
    );
  }
}
