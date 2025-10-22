import 'package:flutter/material.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';

class WeatherCard extends StatelessWidget {
  final double temperature;
  final String icon;
  final String description;
  final String date;
  // ✅ ADD: New required parameters
  final int humidity;
  final double windSpeed;

  const WeatherCard({
    super.key,
    required this.temperature,
    required this.icon,
    required this.description,
    required this.date,
    // ✅ ADD: Make them required in the constructor
    required this.humidity,
    required this.windSpeed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7986CB), Color(0xFF3F51B5)],
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Today's date
          Text(
            date,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),

          // Icon
          WeatherIconImage(iconUrl: icon, size: 60.0),
          const SizedBox(height: 5),

          // Temperature
          Text(
            "${temperature.toStringAsFixed(1)}°C", // Using your formatting
            style: const TextStyle(
              fontSize: 34,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),

          // Description
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15), // Space before the new details

          // ✅ --- ADDED: Humidity and Wind Speed Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the items
            children: [
              // Humidity Item
              Row(
                mainAxisSize: MainAxisSize.min, // Keep items close together
                children: [
                  Icon(Icons.water_drop_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "$humidity%",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20), // Space between humidity and wind

              // Wind Speed Item
              Row(
                mainAxisSize: MainAxisSize.min, // Keep items close together
                children: [
                  Icon(Icons.air, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "${windSpeed.round()} kph",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // ✅ --- END OF NEW ROW ---
        ],
      ),
    );
  }
}