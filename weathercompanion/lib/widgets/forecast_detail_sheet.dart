// lib/widgets/forecast_detail_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:intl/intl.dart';
import 'package:weathercompanion/services/settings_service.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';
import 'dart:developer' as developer;

class ForecastDetailSheet extends StatefulWidget {
  final Map<String, dynamic> dayData;
  final TemperatureUnit tempUnit;
  final WindSpeedUnit windUnit;

  const ForecastDetailSheet({
    super.key,
    required this.dayData,
    required this.tempUnit,
    required this.windUnit,
  });

  @override
  State<ForecastDetailSheet> createState() => _ForecastDetailSheetState();
}

class _ForecastDetailSheetState extends State<ForecastDetailSheet> {
  String _aiTip = "";
  bool _isLoadingTip = true;
  final SettingsService _settingsService = SettingsService(); // For conversions
  // ✅ Using gemini-pro, compatible with v1beta used by flutter_gemini 2.0.5
  final String _modelName = 'gemini-pro';

  @override
  void initState() {
    super.initState();
    _fetchAiTip();
  }

  String _buildAiPrompt() {
    final day = widget.dayData['day'] ?? {};
    final astro = widget.dayData['astro'] ?? {};
    final date = widget.dayData['date'] ?? 'this day';

    final condition = day['condition']?['text'] ?? 'varied';
    final maxTempC = (day['maxtemp_c'] as num?)?.round() ?? 0;
    final minTempC = (day['mintemp_c'] as num?)?.round() ?? 0;
    final precip = (day['totalprecip_mm'] as num?)?.toDouble() ?? 0.0;
    final snow = (day['totalsnow_cm'] as num?)?.toDouble() ?? 0.0;
    final uv = (day['uv'] as num?)?.toDouble() ?? 0;
    final sunrise = astro['sunrise'] ?? 'N/A';
    final sunset = astro['sunset'] ?? 'N/A';

    return """
    You are a friendly weather companion.
    Based on this forecast for $date:
    - Condition: $condition
    - Max Temp: $maxTempC°C
    - Min Temp: $minTempC°C
    - Precipitation: ${precip}mm
    - Snow: ${snow}cm
    - UV Index: $uv
    - Sunrise: $sunrise
    - Sunset: $sunset

    Provide a 2-3 sentence, conversational tip or piece of advice for the day. Be friendly and helpful.
    """;
  }

  void _fetchAiTip() async {
    if (!mounted) return;
    setState(() => _isLoadingTip = true);

    final prompt = _buildAiPrompt();
    try {
      // ✅ FIX: Switched from Gemini.instance.chat() to Gemini.instance.text()
      final response = await Gemini.instance.text(
        prompt,
        modelName: _modelName,
      );
      if (mounted) {
        setState(() {
           // ✅ FIX: Access output differently for .text() (using .output is simpler here)
          _aiTip = response?.output ?? "Couldn't generate a tip for this day.";
          _isLoadingTip = false;
        });
      }
    } catch (e) {
      developer.log('AI Tip Error: $e', name: 'ForecastDetailSheet');
      if (mounted) {
        setState(() {
          _aiTip = "Sorry, couldn't fetch a tip right now.";
          _isLoadingTip = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.dayData['day'] ?? {};
    final astro = widget.dayData['astro'] ?? {};
    final hourly = (widget.dayData['hour'] as List?) ?? [];

    // Conversions based on passed-in settings
    final isCelsius = widget.tempUnit == TemperatureUnit.celsius;
    final isKph = widget.windUnit == WindSpeedUnit.kph;

    final String maxTemp = isCelsius
        ? "${(day['maxtemp_c'] as num?)?.round() ?? 0}°"
        : "${_settingsService.toFahrenheit((day['maxtemp_c'] as num?)?.toDouble() ?? 0).round()}°";
    final String minTemp = isCelsius
        ? "${(day['mintemp_c'] as num?)?.round() ?? 0}°"
        : "${_settingsService.toFahrenheit((day['mintemp_c'] as num?)?.toDouble() ?? 0).round()}°";
    final String windSpeed = isKph
        ? "${(day['maxwind_kph'] as num?)?.round() ?? 0} kph"
        : "${_settingsService.toMph((day['maxwind_kph'] as num?)?.toDouble() ?? 0).round()} mph";

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF3949AB), // Dark blue background
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handlebar
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                Text(
                  DateFormat.yMMMEd()
                      .format(DateTime.parse(widget.dayData['date'] ?? '')),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    WeatherIconImage(
                        iconUrl: day['condition']?['icon'] ?? '', size: 50),
                    const SizedBox(width: 15),
                    Text(
                      '$maxTemp / $minTemp',
                      style: const TextStyle(color: Colors.white, fontSize: 24),
                    ),
                  ],
                ),
                Text(
                  day['condition']?['text'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 20, indent: 20, endIndent: 20),

          // Main Details Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDetailItem(Icons.wind_power, "Wind", windSpeed),
                _buildDetailItem(Icons.water_drop, "Precip.",
                    "${(day['totalprecip_mm'] as num?)?.toStringAsFixed(1) ?? 0} mm"),
                _buildDetailItem(Icons.wb_sunny_outlined, "UV Index",
                    (day['uv'] as num?)?.toString() ?? 'N/A'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _buildDetailItem(Icons.wb_twilight_outlined, "Sunrise", astro['sunrise'] ?? 'N/A'),
                 _buildDetailItem(Icons.wb_twilight_outlined, "Sunset", astro['sunset'] ?? 'N/A'),
                 _buildDetailItem(Icons.thermostat, "Avg Temp",
                      isCelsius
                          ? "${(day['avgtemp_c'] as num?)?.round() ?? 0}°"
                          : "${_settingsService.toFahrenheit((day['avgtemp_c'] as num?)?.toDouble() ?? 0).round()}°"),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 20, indent: 20, endIndent: 20),

          // AI Tip
          _buildAiTipWidget(),
          const Divider(color: Colors.white24, height: 20, indent: 20, endIndent: 20),

          // Hourly List Title
          const Text("Hourly Forecast",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Hourly List
          Expanded(
            child: ListView.builder(
              itemCount: hourly.length,
              itemBuilder: (context, index) {
                final hour = hourly[index];
                final String time =
                    DateFormat.j().format(DateTime.parse(hour['time'] ?? ''));
                final String temp = isCelsius
                    ? "${(hour['temp_c'] as num?)?.round() ?? 0}°"
                    : "${_settingsService.toFahrenheit((hour['temp_c'] as num?)?.toDouble() ?? 0).round()}°";
                final String precipChance =
                    "${(hour['chance_of_rain'] as num?)?.round() ?? 0}%";

                return ListTile(
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(time,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WeatherIconImage(
                          iconUrl: hour['condition']?['icon'] ?? '', size: 30),
                      const SizedBox(width: 10),
                      Text(hour['condition']?['text'] ?? '',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  trailing: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(temp,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                       Text(precipChance, style: const TextStyle(color: Colors.blueAccent, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiTipWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset('assets/images/logo.png', width: 30, height: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Mr. WFC's Tip",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                _isLoadingTip
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.0),
                      )
                    : Text(
                        _aiTip,
                        style: const TextStyle(
                            color: Colors.white70, fontStyle: FontStyle.italic),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}