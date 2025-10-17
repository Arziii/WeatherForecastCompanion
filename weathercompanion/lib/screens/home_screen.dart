// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:weathercompanion/services/weather_services.dart';
import 'package:weathercompanion/widgets/weather_card.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();

  String cityName = "Manila";
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "🌤";
  List<dynamic> forecastDays = [];
  bool isLoading = true;

  double? _lastLat;
  double? _lastLon;

  // Animation for map button bounce
  late final AnimationController _animationController;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    _cityController.text = cityName;
    _fetchWeather();

    // animation initialization
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

  Future<void> _fetchWeather() async {
    final query = _cityController.text.isNotEmpty
        ? _cityController.text
        : cityName;

    setState(() => isLoading = true);
    final data = await _weatherService.fetchWeather(query);

    if (data != null) {
      final current = data['current'];
      final location = data['location'];
      final forecast = data['forecast']?['forecastday'] ?? [];

      setState(() {
        cityName = location['name'] ?? cityName;
        temperature = (current['temp_c'] != null)
            ? (current['temp_c'] as num).toDouble()
            : 0;
        humidity = (current['humidity'] is num)
            ? (current['humidity'] as num).toInt()
            : 0;
        windSpeed = (current['wind_kph'] != null)
            ? (current['wind_kph'] as num).toDouble()
            : 0;
        weatherDescription = current['condition']?['text'] ?? "";
        forecastDays = forecast;
        _lastLat = (location['lat'] is num)
            ? (location['lat'] as num).toDouble()
            : null;
        _lastLon = (location['lon'] is num)
            ? (location['lon'] as num).toDouble()
            : null;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("City not found or network issue.")),
      );
    }
  }

  String _monthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // ✅ Keeps footer & map fixed when keyboard opens
      backgroundColor: const Color(0xFF3949AB),
      body: SafeArea(
        child: Stack(
          children: [
            // Main scrollable content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: SingleChildScrollView(
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
                          "WeatherCompanion • Beta v1.3.2",
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

                    // Search bar
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
                                _fetchWeather();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _fetchWeather,
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

                    // Weather Card
                    if (isLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else
                      WeatherCard(
                        temperature: temperature,
                        icon: weatherIcon,
                        description: weatherDescription,
                      ),

                    const SizedBox(height: 25),

                    // 7-day forecast horizontal
                    if (forecastDays.isNotEmpty)
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
                            final minTemp = (dayInfo['mintemp_c'] is num)
                                ? (dayInfo['mintemp_c'] as num).toInt()
                                : 0;
                            final maxTemp = (dayInfo['maxtemp_c'] is num)
                                ? (dayInfo['maxtemp_c'] as num).toInt()
                                : 0;

                            return Container(
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
                                  const Icon(
                                    Icons.wb_sunny,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "$minTemp° / $maxTemp°",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  Text(
                                    condition,
                                    textAlign: TextAlign.center,
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
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Map Button (fixed)
            Positioned(
              bottom: 0,
              left: 25,
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_bounceAnimation.value),
                    child: child,
                  );
                },
                child: FloatingActionButton(
                  backgroundColor: Colors.white.withOpacity(0.25),
                  elevation: 0,
                  onPressed: () {
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
                  },
                  child: const Icon(Icons.map, color: Colors.white, size: 20),
                ),
              ),
            ),

            // Footer (fixed)
            Positioned(
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
          ],
        ),
      ),
    );
  }
}
