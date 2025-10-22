// lib/widgets/weather_card.dart
import 'package:flutter/material.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';

class WeatherCard extends StatelessWidget {
  final double temperature;
  final String icon;
  final String description;
  final String date;
  final int humidity;
  final double windSpeed;
  // ✅ ADD New parameters
  final double feelsLikeTemp;
  final double uvIndex;
  final int precipitationChance;
  final String sunriseTime;
  final String sunsetTime;

  const WeatherCard({
    super.key,
    required this.temperature,
    required this.icon,
    required this.description,
    required this.date,
    required this.humidity,
    required this.windSpeed,
    // ✅ ADD New parameters to constructor
    required this.feelsLikeTemp,
    required this.uvIndex,
    required this.precipitationChance,
    required this.sunriseTime,
    required this.sunsetTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 15,
      ), // Back to original padding
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7986CB), Color(0xFF3F51B5)], // Your gradient
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align date to start
        children: [
          // Date
          Text(
            date,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14, // Original size
            ),
          ),
          const SizedBox(height: 10),

          // Main Row: Icon, Temp, Desc
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeatherIconImage(iconUrl: icon, size: 70), // Original size
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${temperature.round()}°C", // Rounded actual temp
                      style: const TextStyle(
                        fontSize: 42, // Adjusted size
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // ✅ ADD Feels Like Temp
                    Text(
                      "Feels like ${feelsLikeTemp.round()}°",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Colors.white, // Brighter description
                        fontSize: 16, // Original size
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 10), // Reduced space after divider
          // ✅ --- UPDATED: Detail Rows ---
          // Row 1: Humidity, Wind, Precip Chance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem(
                icon: Icons.water_drop_outlined,
                value: "$humidity%",
                label: "Humidity",
              ),
              _buildDetailItem(
                icon: Icons.air,
                value: "${windSpeed.round()} kph",
                label: "Wind",
              ),
              _buildDetailItem(
                icon: Icons
                    .umbrella_outlined, // Or Icons.ac_unit for snow if needed
                value: "$precipitationChance%",
                label: "Precip",
              ),
            ],
          ),
          const SizedBox(height: 15), // Space between detail rows
          // Row 2: UV Index, Sunrise, Sunset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem(
                icon: Icons.wb_sunny_outlined,
                value: uvIndex.toStringAsFixed(0), // No decimal needed
                label: "UV Index",
              ),
              _buildDetailItem(
                icon: Icons.wb_twilight_outlined, // Sunrise icon
                value: sunriseTime,
                label: "Sunrise",
              ),
              _buildDetailItem(
                icon: Icons.dark_mode_outlined, // Sunset icon
                value: sunsetTime,
                label: "Sunset",
              ),
            ],
          ),
          // ✅ --- END OF DETAIL ROWS ---
        ],
      ),
    );
  }

  // Helper widget for the detail items
  Widget _buildDetailItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    // Wrap in a SizedBox to constrain width and ensure wrapping
    return SizedBox(
      width: 75, // Adjust width as needed for your layout
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 22), // Slightly larger icon
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15, // Slightly larger value
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12, // Smaller label
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
