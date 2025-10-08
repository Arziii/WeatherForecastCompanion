import 'package:flutter/material.dart';
import 'package:weathercompanion/services/weather_services.dart';
import 'package:weathercompanion/widgets/weather_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final WeatherService _weatherService = WeatherService();
  final TextEditingController _cityController = TextEditingController();

  String cityName = "Manila";
  double temperature = 0;
  String weatherDescription = "";
  int humidity = 0;
  double windSpeed = 0;
  String weatherIcon = "🌤";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cityController.text = cityName;
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() => isLoading = true);
    final data = await _weatherService.fetchWeather(cityName);

    if (data != null) {
      final current = data['current'];
      final location = data['location'];

      setState(() {
        cityName = location['name'] ?? cityName;
        temperature = current['temp_c']?.toDouble() ?? 0;
        humidity = current['humidity']?.toInt() ?? 0;
        windSpeed = current['wind_kph']?.toDouble() ?? 0;
        weatherDescription = current['condition']['text'] ?? "Unknown";
        weatherIcon = _mapWeatherToEmoji(weatherDescription);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("City not found or network issue.")),
      );
    }
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
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🌤 App Title / Version Label
                Center(
                  child: Text(
                    'WeatherCompanion • Beta v1.0',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                // 🔍 Search Bar
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
                            setState(() {
                              cityName = value;
                            });
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

                // 🧭 City name and description
                Text(
                  cityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  weatherDescription,
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 30),

                // 🌤 Weather Card or Loader
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

                // 🌡 Additional info
                Expanded(
                  child: ListView(
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
                ),

                //Developer Label
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Developed by Cervantes,Balmedina,Robiego',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
