// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:weathercompanion/services/weather_services.dart';
import 'package:weathercompanion/widgets/weather_card.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';
import 'package:weathercompanion/widgets/ai_assistant_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';

// ADD: Import the new greeting service
import 'package:weathercompanion/services/ai_greeting_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();

  // ADD: Instantiate the new service
  final AiGreetingService _aiGreetingService = AiGreetingService();

  // ADD: State variable for the greeting text
  String _aiGreeting = "";
  bool _greetingLoading = false; // Flag to show loading for greeting

  String cityName = "Manila";
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "";
  List<dynamic> forecastDays = [];
  bool isLoading = true; // Overall loading state

  double? _lastLat;
  double? _lastLon;

  late final AnimationController _animationController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _cityController.text = cityName;

    // This correctly calls your combined function after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWeatherAndGreeting();
    });

    // Animation setup
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // UPDATED: Renamed and combined fetch logic
  Future<void> _fetchWeatherAndGreeting([String? queryOverride]) async {
    // Show main loading spinner only on initial load or location fetch
    if (!mounted) return; // Prevent state updates if widget is disposed
    if (isLoading == false || _aiGreeting.isEmpty) {
      setState(() {
        isLoading = true;
        _greetingLoading = true; // Also indicate greeting is loading
        _aiGreeting = ""; // Clear old greeting
      });
    }

    final query =
        queryOverride ??
        (_cityController.text.isNotEmpty ? _cityController.text : cityName);

    if (queryOverride != null) {
      _cityController.clear();
    }

    print("Fetching weather for query: $query");
    Map<String, dynamic>? data; // Declare data here

    try {
      data = await _weatherService.fetchWeather(query);
      print("Weather data received: ${data != null}");

      if (data != null && mounted) {
        // Check mounted again before state updates
        final current = data['current'];
        final location = data['location'];
        final forecast = data['forecast']?['forecastday'] ?? [];

        final String newCityName = location['name'] ?? cityName;
        final double newTemp = (current['temp_c'] != null)
            ? (current['temp_c'] as num).toDouble()
            : 0;
        final String newDesc = current['condition']?['text'] ?? "";
        final String newIcon = current['condition']?['icon'] ?? "";
        final int newHumidity = (current['humidity'] is num)
            ? (current['humidity'] as num).toInt()
            : 0;
        final double newWindSpeed = (current['wind_kph'] != null)
            ? (current['wind_kph'] as num).toDouble()
            : 0;
        final double? newLat = (location['lat'] is num)
            ? (location['lat'] as num).toDouble()
            : null;
        final double? newLon = (location['lon'] is num)
            ? (location['lon'] as num).toDouble()
            : null;

        // Inside _fetchWeatherAndGreeting() in home_screen.dart...

        // --- Generate Greeting ---
        //
        // ✅ THE REAL FIX: Use the local time from the API, NOT DateTime.now()
        //
        final String localTimeString = location['localtime'] ?? "";
        DateTime currentTime;

        try {
          // Parse the local time string from the API (e.g., "2024-05-16 23:27")
          currentTime = DateTime.parse(localTimeString);
        } catch (e) {
          // Fallback if parsing fails
          print(
            "Could not parse API localtime string '$localTimeString', falling back to DateTime.now()",
          );
          currentTime = DateTime.now();
        }

        print("Attempting to get AI greeting for $currentTime...");

        // Generate greeting in parallel, but don't await yet
        final greetingFuture = _aiGreetingService.generateGreeting(
          newDesc,
          newCityName,
          newTemp,
          currentTime, // ✅ PASS the *correct* local time from the API
        );

        // --- Update UI with Weather First ---
        print("Updating UI state with weather...");
        // ... the rest of your function continues here ...

        // --- Update UI with Weather First ---
        print("Updating UI state with weather...");
        setState(() {
          cityName = newCityName;
          temperature = newTemp;
          weatherDescription = newDesc;
          weatherIcon = newIcon;
          humidity = newHumidity;
          windSpeed = newWindSpeed;
          forecastDays = forecast;
          _lastLat = newLat;
          _lastLon = newLon;
          _cityController.text = newCityName;
          isLoading = false; // Hide main spinner once weather is ready
        });
        print("Weather UI state updated.");

        // --- Now wait for greeting and update ---
        final generatedGreeting = await greetingFuture;
        if (mounted) {
          // Check mounted again
          setState(() {
            _aiGreeting = generatedGreeting;
            _greetingLoading = false; // Hide greeting loading indicator
          });
          print("AI Greeting received and updated: $_aiGreeting");
        }
      } else {
        print("Weather data was null.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("City not found or network issue.")),
          );
        }
      }
    } catch (e) {
      print("Error in _fetchWeatherAndGreeting: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("An error occurred: $e")));
      }
    } finally {
      print("Finally block reached. Setting all loading states to false.");
      // Ensure all loading flags are false in the finally block
      if (mounted) {
        setState(() {
          isLoading = false;
          _greetingLoading = false;
        });
      }
    }
  }

  Future<void> _getUserLocationAndFetchWeather() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
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
      return;
    }
    try {
      // Show both loading indicators when fetching location
      if (mounted) {
        setState(() {
          isLoading = true;
          _greetingLoading = true;
          _aiGreeting = ""; // Clear greeting
        });
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      final latLonQuery = "${position.latitude},${position.longitude}";
      await _fetchWeatherAndGreeting(latLonQuery); // Call the combined function
    } catch (e) {
      if (mounted) {
        setState(() {
          // Hide both indicators on error
          isLoading = false;
          _greetingLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
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
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String formattedToday =
        "${_monthName(now.month)} ${now.day}, ${now.year}";

    // ✅ ADD: This detects if the keyboard is open
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      // ✅ REMOVED: resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF3949AB),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SingleChildScrollView(
                // This padding ensures content can scroll above the map button
                padding: const EdgeInsets.only(bottom: 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
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
                          "WeatherCompanion • Beta v1.5.0",
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

                    // Search Bar + Buttons
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
                              if (value.isNotEmpty) {
                                _fetchWeatherAndGreeting();
                              }
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
                          onPressed: _fetchWeatherAndGreeting,
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // City name
                    Text(
                      cityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Weather Card (or Loading)
                    if (isLoading)
                      const Center(
                        child: SizedBox(
                          height: 160,
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
                      ),
                    const SizedBox(height: 20),

                    // AI Greeting Widget (or Loading)
                    if (_greetingLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.7),
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
                        child: Text(
                          _aiGreeting,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                            height: 1.4,
                          ),
                        ),
                      ),
                    const SizedBox(height: 25),

                    // 7-Day Forecast
                    if (!isLoading && forecastDays.isNotEmpty) ...[
                      SizedBox(
                        height: 130,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: forecastDays.length,
                          itemBuilder: (context, index) {
                            final day = forecastDays[index];
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
                            final minTemp = (dayInfo['mintemp_c'] is num)
                                ? (dayInfo['mintemp_c'] as num).toInt()
                                : 0;
                            final maxTemp = (dayInfo['maxtemp_c'] is num)
                                ? (dayInfo['maxtemp_c'] as num).toInt()
                                : 0;

                            final bool isToday =
                                parsed.day == DateTime.now().day &&
                                parsed.month == DateTime.now().month &&
                                parsed.year == DateTime.now().year;

                            return Container(
                              width: 110,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: isToday
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
                                    isToday ? "Today" : formattedDate,
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
                                    style: const TextStyle(color: Colors.white),
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
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),

                    // AI Chat box
                    const AiAssistantWidget(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ✅ MODIFIED: Footer is now wrapped in Visibility
            Visibility(
              visible: !isKeyboardOpen, // Hides when keyboard is open
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

      // ✅ ADDED: The map button is now in its proper place
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: AnimatedBuilder(
        animation: _bounceAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -_bounceAnimation.value),
            child: child,
          );
        },
        //
        // ✅ --- THIS IS THE UPDATED BUTTON ---
        //
        child: FloatingActionButton(
          backgroundColor: Colors.white.withOpacity(
            0.35,
          ), // Solid white background
          elevation: 6.0, // Adds a shadow to "pop"
          onPressed: () {
            final lat = _lastLat ?? 14.5995;
            final lon = _lastLon ?? 120.9842;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MapScreen(center: LatLng(lat, lon), title: cityName),
              ),
            );
          },
          child: const Icon(
            Icons.map,
            color: Color(0xFF3949AB), // Blue icon to contrast
            size: 24, // Slightly larger
          ),
        ),
        //
        // ✅ --- END OF UPDATED BUTTON ---
        //
      ),
    );
  }
}
