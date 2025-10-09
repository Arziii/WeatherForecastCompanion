import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:weathercompanion/services/weather_services.dart';
import 'package:weathercompanion/widgets/weather_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();

  String? cityName;
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "🌤";
  bool isLoading = true;
  bool isKeyboardVisible = false;

  // 🚫 List of banned or inappropriate words
  final List<String> bannedWords = [
    "tangina",
    "gago",
    "puta",
    "pakyu",
    "bobo",
    "ulol",
    "fuck",
    "shit",
    "asshole",
    "fucker",
    "idiot",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cityName = "Manila";
    _cityController.text = cityName!;
    _fetchWeather();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    setState(() => isKeyboardVisible = bottomInset > 0);
  }

  Future<void> _fetchWeather() async {
    final input = _cityController.text.toLowerCase().trim();

    // 🚫 Profanity check
    if (bannedWords.any((word) => input.contains(word))) {
      setState(() {
        cityName = null;
        weatherDescription = "";
        temperature = 0;
        humidity = 0;
        windSpeed = 0;
        weatherIcon = "❌";
        isLoading = false;
      });

      HapticFeedback.mediumImpact();
      _showSnackBar(
        "⚠️ Inappropriate input detected. Please use a valid city name.",
      );
      return;
    }

    setState(() => isLoading = true);
    final data = await _weatherService.fetchWeather(input);

    if (data != null && data.containsKey('current')) {
      final current = data['current'];
      final location = data['location'];

      setState(() {
        cityName = location['name'];
        temperature = current['temp_c']?.toDouble() ?? 0;
        humidity = current['humidity']?.toInt() ?? 0;
        windSpeed = current['wind_kph']?.toDouble() ?? 0;
        weatherDescription = current['condition']['text'] ?? "Unknown";
        weatherIcon = _mapWeatherToEmoji(weatherDescription);
        isLoading = false;
      });
    } else {
      setState(() {
        cityName = null;
        temperature = 0;
        humidity = 0;
        windSpeed = 0;
        weatherDescription = "";
        weatherIcon = "❌";
        isLoading = false;
      });

      HapticFeedback.mediumImpact();
      _showSnackBar(
        "⚠️ City not found. Please check your spelling or network connection.",
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _mapWeatherToEmoji(String condition) {
    final desc = condition.toLowerCase();
    if (desc.contains("cloud")) return "☁️";
    if (desc.contains("rain")) return "🌧";
    if (desc.contains("clear") || desc.contains("sun")) return "☀️";
    if (desc.contains("snow")) return "❄️";
    if (desc.contains("thunder")) return "⛈";
    return "🌤";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🌤 App Logo + Title (Compact)
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/logo.png', height: 35),
                            const SizedBox(width: 10),
                            const Text(
                              "WeatherCompanion • Beta v1.2",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),

                      // 🔍 Search Bar
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _cityController,
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.none,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "Enter city name",
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
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
                                  setState(() => cityName = value);
                                  _fetchWeather();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            onPressed: _fetchWeather,
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),

                      // 🧭 City name
                      if (cityName != null)
                        Text(
                          cityName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 30),

                      // 🌤 Weather Card or Loader
                      if (isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else if (cityName == null || weatherDescription.isEmpty)
                        const Center(
                          child: Text(
                            "No data available",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        WeatherCard(
                          temperature: temperature,
                          icon: weatherIcon,
                          description: weatherDescription,
                        ),

                      const SizedBox(height: 25),

                      // 🌡 Additional info
                      if (cityName != null && weatherDescription.isNotEmpty)
                        Column(
                          children: [
                            _buildWeatherInfoTile(
                              icon: Icons.water_drop,
                              label: "Humidity",
                              value: "$humidity%",
                            ),
                            _buildWeatherInfoTile(
                              icon: Icons.air,
                              label: "Wind Speed",
                              value: "${windSpeed.toStringAsFixed(1)} km/h",
                            ),
                          ],
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),

              // 👇 Fixed Footer
              AnimatedOpacity(
                opacity: isKeyboardVisible ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      "Developed by Team WFC",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Text(value, style: const TextStyle(color: Colors.white)),
    );
  }
}
