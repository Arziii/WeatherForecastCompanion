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
  String _aiSummary = ""; // Renamed from _aiTip to _aiSummary
  bool _isLoadingSummary = true; // Renamed from _isLoadingTip
  final SettingsService _settingsService = SettingsService(); // For conversions
  // ✅ Using gemini-pro, compatible with v1beta used by flutter_gemini 3.0.0
  // Or 'gemini-flash-latest' if preferred and available/working
  final String _modelName = 'gemini-pro';
  // final String _modelName = 'gemini-flash-latest'; // Keep if this was intended

  @override
  void initState() {
    super.initState();
    _fetchAiSummary(); // Renamed function call
  }

  String _buildAiPrompt() {
    final day = widget.dayData['day'] ?? {};
    final astro = widget.dayData['astro'] ?? {};
    final dateStr = widget.dayData['date'] ?? 'this day';
    String formattedDate = dateStr;
    try {
      // Format the date nicely for the AI
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        formattedDate = DateFormat('EEEE, MMM d')
            .format(parsedDate); // e.g., "Sunday, Oct 26"
      }
    } catch (e) {
      developer.log("Error formatting date for AI prompt: $e",
          name: 'ForecastDetailSheet');
    }

    final condition = day['condition']?['text'] ?? 'varied conditions';
    final maxTempC = (day['maxtemp_c'] as num?)?.round() ?? 'N/A';
    final minTempC = (day['mintemp_c'] as num?)?.round() ?? 'N/A';
    // Use precip probability instead of total amount for recommendation
    final precipChance = (day['daily_chance_of_rain'] as num?)?.round() ??
        (day['daily_chance_of_snow'] as num?)?.round() ??
        0;
    final uv =
        (day['uv'] as num?)?.toDouble() ?? 0; // Keep UV as double for context
    final sunrise = astro['sunrise'] ?? 'N/A'; // Already HH:MM
    final sunset = astro['sunset'] ?? 'N/A'; // Already HH:MM

    // Adjusted Prompt for Summary and Recommendation
    final prompt = """
    You are a friendly weather companion.
    A user is looking at the detailed forecast for $formattedDate.

    Here is the data for that day:
    - Condition: $condition
    - Max Temp: $maxTempC°C
    - Min Temp: $minTempC°C
    - Chance of Rain: $precipChance%
    - Max UV Index: $uv
    - Sunrise: $sunrise
    - Sunset: $sunset

    Based *only* on this data, write a 2-3 sentence friendly and helpful summary.
    Give a clear recommendation (e.g., "it's a good day for a walk," "don't forget sunscreen," or "you'll definitely need an umbrella").
    Be conversational and encouraging. Do not mention "context" or "data provided".
    """;
    developer.log(
        "[ForecastDetailSheet] Fetching AI forecast summary with prompt: $prompt",
        name: 'ForecastDetailSheet');
    return prompt;
  }

  void _fetchAiSummary() async {
    // Renamed function
    if (!mounted) return;
    setState(() => _isLoadingSummary = true);

    final prompt = _buildAiPrompt();
    try {
      // 🚀 *** FIX: Switched from Gemini.instance.chat() to Gemini.instance.text() ***
      final response = await Gemini.instance.text(
        prompt,
        // modelName: _modelName, // Optional for .text()
      );
      if (mounted) {
        setState(() {
          // 🚀 *** FIX: Access output differently for .text() ***
          _aiSummary =
              response?.output ?? "Couldn't generate a summary for this day.";
          _isLoadingSummary = false;
        });
        developer.log("[ForecastDetailSheet] AI Summary received: $_aiSummary",
            name: 'ForecastDetailSheet');
      }
    } catch (e) {
      developer.log('AI Summary Error: $e',
          name: 'ForecastDetailSheet', error: e);
      if (mounted) {
        setState(() {
          _aiSummary = "Sorry, couldn't fetch a summary right now.";
          _isLoadingSummary = false;
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

    // Use null-aware operators and provide defaults
    final double maxTempC = (day['maxtemp_c'] as num?)?.toDouble() ?? 0.0;
    final double minTempC = (day['mintemp_c'] as num?)?.toDouble() ?? 0.0;
    final double avgTempC = (day['avgtemp_c'] as num?)?.toDouble() ?? 0.0;
    final double maxWindKph = (day['maxwind_kph'] as num?)?.toDouble() ?? 0.0;
    final double totalPrecipMm =
        (day['totalprecip_mm'] as num?)?.toDouble() ?? 0.0;
    final double uvIndex = (day['uv'] as num?)?.toDouble() ?? 0.0;

    final String maxTempDisplay = isCelsius
        ? "${maxTempC.round()}°"
        : "${_settingsService.toFahrenheit(maxTempC).round()}°";
    final String minTempDisplay = isCelsius
        ? "${minTempC.round()}°"
        : "${_settingsService.toFahrenheit(minTempC).round()}°";
    final String avgTempDisplay = isCelsius
        ? "${avgTempC.round()}°"
        : "${_settingsService.toFahrenheit(avgTempC).round()}°";
    final String windSpeedDisplay = isKph
        ? "${maxWindKph.round()} kph"
        : "${_settingsService.toMph(maxWindKph).round()} mph";
    final String precipDisplay = "${totalPrecipMm.toStringAsFixed(1)} mm";
    final String uvDisplay =
        uvIndex.toStringAsFixed(1); // Show one decimal for UV
    final String sunriseDisplay = astro['sunrise'] ?? 'N/A';
    final String sunsetDisplay = astro['sunset'] ?? 'N/A';
    final String conditionText =
        day['condition']?['text'] ?? 'No condition data';
    final String conditionIcon = day['condition']?['icon'] ?? '';
    final String dateString = widget.dayData['date'] ?? '';
    String formattedHeaderDate = 'Forecast Details';
    try {
      final parsedDate = DateTime.tryParse(dateString);
      if (parsedDate != null) {
        formattedHeaderDate =
            DateFormat.yMMMEd().format(parsedDate); // e.g., "Wed, Oct 25, 2025"
      }
    } catch (e) {/* Use default */}

    return Container(
      // Allow slightly more height
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            // Use gradient for consistency
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6A82FB), Color(0xFF3F51B5)]),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25), // Slightly larger radius
          topRight: Radius.circular(25),
        ),
      ),
      child: ClipRRect(
        // Clip content to rounded corners
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: Column(
          children: [
            // Handlebar
            Container(
              width: 50, // Slightly wider
              height: 6, // Slightly thicker
              margin: const EdgeInsets.symmetric(
                  vertical: 12), // More vertical margin
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4), // Less opaque
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Text(
                    formattedHeaderDate,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      WeatherIconImage(
                          iconUrl: conditionIcon,
                          size: 45), // Slightly smaller icon
                      const SizedBox(width: 15),
                      Text(
                        '$maxTempDisplay / $minTempDisplay',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22), // Slightly smaller temp
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conditionText,
                    // 🚀 *** FIX: Removed 'const' ***
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 16), // Brighter text
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Divider(
                color: Colors.white24,
                height: 25,
                indent: 20,
                endIndent: 20), // More spacing

            // Main Details Grid
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 15.0), // Reduced horizontal padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailItem(
                      Icons.air, "Max Wind", windSpeedDisplay), // Changed Icon
                  _buildDetailItem(Icons.water_drop_outlined, "Precip.",
                      precipDisplay), // Changed Icon
                  _buildDetailItem(Icons.wb_sunny_outlined, "Max UV",
                      uvDisplay), // Added "Max"
                ],
              ),
            ),
            const SizedBox(height: 12), // Increased spacing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDetailItem(
                      Icons.wb_twilight_outlined, "Sunrise", sunriseDisplay),
                  _buildDetailItem(Icons.dark_mode_outlined, "Sunset",
                      sunsetDisplay), // Changed Icon
                  _buildDetailItem(Icons.device_thermostat, "Avg Temp",
                      avgTempDisplay), // Changed Icon
                ],
              ),
            ),
            const Divider(
                color: Colors.white24, height: 25, indent: 20, endIndent: 20),

            // AI Summary
            _buildAiSummaryWidget(), // Use the specific build method
            const Divider(
                color: Colors.white24, height: 25, indent: 20, endIndent: 20),

            // Hourly List Title
            const Padding(
              // Added padding
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Text("Hourly Breakdown",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8), // Reduced space before list

            // 🚀 *** FIX: Wrap the ListView.builder in an Expanded ***
            // This tells the ListView to take up the remaining available space
            // in the Column, resolving the overflow.
            Expanded(
              child: hourly.isEmpty
                  ? const Center(
                      child: Text("No hourly data available.",
                          style: TextStyle(color: Colors.white70)))
                  : ListView.builder(
                      padding: const EdgeInsets.only(
                          bottom: 10), // Add padding at the bottom
                      itemCount: hourly.length,
                      itemBuilder: (context, index) {
                        final hour = hourly[index];
                        String time = "--:--";
                        try {
                          final parsedTime =
                              DateTime.tryParse(hour['time'] ?? '');
                          if (parsedTime != null) {
                            time = DateFormat.j()
                                .format(parsedTime.toLocal()); // Use local time
                          }
                        } catch (e) {/* Keep default */}

                        final String temp = isCelsius
                            ? "${(hour['temp_c'] as num?)?.round() ?? '-'}°"
                            : "${_settingsService.toFahrenheit((hour['temp_c'] as num?)?.toDouble() ?? 0.0).round()}°";
                        final String precipChance =
                            "${(hour['chance_of_rain'] as num?)?.round() ?? (hour['chance_of_snow'] as num?)?.round() ?? '-'}%";
                        final String hourConditionText =
                            hour['condition']?['text'] ?? '';
                        final String hourConditionIcon =
                            hour['condition']?['icon'] ?? '';

                        return ListTile(
                          dense: true, // Make list items slightly smaller
                          visualDensity: VisualDensity.compact,
                          leading: SizedBox(
                            // Give time fixed width
                            width: 50,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(time,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.start, // Align left
                            children: [
                              WeatherIconImage(
                                  iconUrl: hourConditionIcon,
                                  size: 28), // Smaller icon
                              const SizedBox(width: 8),
                              Expanded(
                                // Allow text to wrap or ellipsis
                                child: Text(
                                  hourConditionText,
                                  // 🚀 *** FIX: Removed 'const' ***
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          trailing: SizedBox(
                            // Give temp/precip fixed width
                            width: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(temp,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15, // Slightly smaller
                                        fontWeight: FontWeight.bold)),
                                Text(precipChance,
                                    style: TextStyle(
                                        color: Colors.lightBlue[100],
                                        fontSize: 12)), // Lighter blue
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Extracted AI Summary Widget
  Widget _buildAiSummaryWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Added padding to align icon better
            padding: const EdgeInsets.only(top: 2.0),
            child: Image.asset('assets/images/logo.png', width: 26, height: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Mr. WFC's Summary", // Changed title
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14, // Slightly smaller title
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                _isLoadingSummary
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white70,
                            strokeWidth: 2.0), // Dimmed loader
                      )
                    : Text(
                        _aiSummary,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontStyle: FontStyle.italic,
                            fontSize: 14), // Slightly smaller text
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated Detail Item Widget
  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Expanded(
      // Ensure items take equal space
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              color: Colors.white.withOpacity(0.8), size: 22), // Brighter icon
          const SizedBox(height: 5), // More space
          Text(
            label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 11), // Brighter label, smaller text
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3), // Less space
          Text(
            value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14), // Slightly smaller value text
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
