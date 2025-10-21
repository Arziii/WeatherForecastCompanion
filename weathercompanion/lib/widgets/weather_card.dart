import 'package:flutter/material.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';

class WeatherCard extends StatelessWidget {
  final double temperature;
  final String icon;
  final String description;
  final String date;

  const WeatherCard({
    super.key,
    required this.temperature,
    required this.icon,
    required this.description,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      // UPDATED: Reduced padding from 20 to 15
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
              fontSize: 12, // UPDATED: Reduced font size from 14
            ),
          ),
          // UPDATED: Reduced spacing from 10 to 8
          const SizedBox(height: 8),

          // UPDATED: Reduced icon size from 70.0 to 60.0
          WeatherIconImage(iconUrl: icon, size: 60.0),
          // UPDATED: Reduced spacing from 8 to 5
          const SizedBox(height: 5),
          Text(
            "${temperature.toStringAsFixed(1)}°C",
            style: const TextStyle(
              fontSize: 34, // UPDATED: Reduced font size from 38
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          // UPDATED: Reduced spacing from 8 to 5
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14, // UPDATED: Reduced font size from 16
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}