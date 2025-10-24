// lib/widgets/weather_card.dart
import 'package:flutter/material.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';

class WeatherCard extends StatelessWidget {
  // Use display-ready values
  final double displayTemperature;
  final String tempUnitSymbol; // 'C' or 'F'
  final String icon;
  final String description;
  final String date;
  // ✅ ADDED THIS LINE
  final String localTime;
  final int humidity;
  final double displayWindSpeed;
  final String windUnitSymbol; // 'kph' or 'mph'
  final double feelsLikeTemp; // Already converted if needed
  final double uvIndex;
  final int precipitationChance;
  final String sunriseTime;
  final String sunsetTime;

  const WeatherCard({
    super.key,
    required this.displayTemperature,
    required this.tempUnitSymbol,
    required this.icon,
    required this.description,
    required this.date,
    // ✅ ADDED THIS REQUIRED PARAMETER
    required this.localTime,
    required this.humidity,
    required this.displayWindSpeed,
    required this.windUnitSymbol,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Display Date and Time side-by-side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              // ✅ USE THE localTime PARAMETER
              Text("Local Time: $localTime",
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WeatherIconImage(iconUrl: icon, size: 70),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${displayTemperature.round()}°$tempUnitSymbol",
                      style: const TextStyle(
                          fontSize: 42,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                    Text(
                      // Display feelsLike temp without symbol again, as units match display temp
                      "Feels like ${feelsLikeTemp.round()}°",
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 5),
                    Text(description,
                        textAlign: TextAlign.right,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 10),
          Row(
            // Row 1
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem(
                  icon: Icons.water_drop_outlined,
                  value: "$humidity%",
                  label: "Humidity"),
              _buildDetailItem(
                  icon: Icons.air,
                  value: "${displayWindSpeed.round()} $windUnitSymbol",
                  label: "Wind"),
              _buildDetailItem(
                  icon: Icons.umbrella_outlined,
                  value: "$precipitationChance%",
                  label: "Precip"),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            // Row 2
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailItem(
                  icon: Icons.wb_sunny_outlined,
                  value: uvIndex.toStringAsFixed(0),
                  label: "UV Index"),
              _buildDetailItem(
                  icon: Icons.wb_twilight_outlined,
                  value: sunriseTime,
                  label: "Sunrise"),
              _buildDetailItem(
                  icon: Icons.dark_mode_outlined,
                  value: sunsetTime,
                  label: "Sunset"),
            ],
          ),
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
    return SizedBox(
      width: 75, // Constrain width
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Prevent overflow
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Prevent overflow
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
