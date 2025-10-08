import 'package:flutter/material.dart';

class WeatherCard extends StatelessWidget {
  final double temperature;
  final String icon;
  final String description;

  const WeatherCard({
    super.key,
    required this.temperature,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
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
          Text(
            icon,
            style: const TextStyle(fontSize: 60),
          ),
          const SizedBox(height: 10),
          Text(
            "${temperature.toStringAsFixed(1)}°C",
            style: const TextStyle(
              fontSize: 42,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
