// lib/widgets/weather_card.dart
import 'package:flutter/material.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';

class WeatherCard extends StatelessWidget {
  final double displayTemperature;
  final String tempUnitSymbol;
  final String icon;
  final String description;
  final String date;
  final String localTime;
  final int humidity;
  final double displayWindSpeed;
  final String windUnitSymbol;
  final double feelsLikeTemp;
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
    // Get the current theme
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final secondaryColor = textTheme.bodyMedium?.color?.withOpacity(0.7);

    // --- ADDED FOR VIBE CHECK ---
    final isLightMode = theme.brightness == Brightness.light;

    //
    // 👇👇👇 VIBE CHECK (Light Mode) 👇👇👇
    //
    const double lightModeOpacity = 0.6; // Try 0.5, 0.6, 0.8, etc.
    //
    // 👆👆👆 VIBE CHECK (Light Mode) 👆👆👆
    //

    //
    // 👇👇👇 VIBE CHECK (Dark Mode) 👇👇👇
    //
    const double darkModeOpacity = 0.2; // 1.0 = solid.
    //
    // 👆👆👆 VIBE CHECK (Dark Mode) 👆👆👆
    //
    // --- END ADDED SECTION ---

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        //
        // --- MODIFIED THIS LINE ---
        //
        color: isLightMode
            ? theme.cardColor.withOpacity(lightModeOpacity)
            : theme.cardColor.withOpacity(darkModeOpacity),
        //
        // --- END MODIFIED LINE ---
        //
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Temp, Icon, Date/Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Temp and Description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${displayTemperature.round()}°$tempUnitSymbol',
                      style: textTheme.displayLarge?.copyWith(
                        // THEME AWARE
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: textTheme.titleMedium, // THEME AWARE
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Icon and Date/Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  WeatherIconImage(iconUrl: icon, size: 70.0),
                  const SizedBox(height: 10),
                  Text(
                    date,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: secondaryColor), // THEME AWARE
                  ),
                  Text(
                    'Local Time: $localTime',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: secondaryColor), // THEME AWARE
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(
              color:
                  theme.colorScheme.onSurface.withOpacity(0.3)), // THEME AWARE
          const SizedBox(height: 15),

          // Bottom Row: Details Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                context,
                Icons.thermostat,
                'Feels Like',
                '${feelsLikeTemp.round()}°$tempUnitSymbol',
              ),
              _buildDetailItem(
                context,
                Icons.water_drop_outlined,
                'Humidity',
                '$humidity%',
              ),
              _buildDetailItem(
                context,
                Icons.air,
                'Wind',
                '${displayWindSpeed.round()} $windUnitSymbol',
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(
                context,
                Icons.wb_sunny_outlined,
                'UV Index',
                '$uvIndex',
              ),
              _buildDetailItem(
                context,
                Icons.umbrella_outlined,
                'Rain Chance',
                '$precipitationChance%',
              ),
              _buildDetailItem(
                context,
                Icons.brightness_6_outlined,
                'Sunrise',
                sunriseTime,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
      BuildContext context, IconData icon, String label, String value) {
    // Get theme data inside the helper
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final secondaryColor = textTheme.bodySmall?.color?.withOpacity(0.7);

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: secondaryColor), // THEME AWARE
              const SizedBox(width: 4),
              Text(
                label,
                style: textTheme.bodySmall
                    ?.copyWith(color: secondaryColor), // THEME AWARE
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600), // THEME AWARE
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}