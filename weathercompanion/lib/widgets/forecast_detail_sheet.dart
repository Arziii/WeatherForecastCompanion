// lib/widgets/forecast_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';
import 'package:intl/intl.dart';

class ForecastDetailSheet extends StatefulWidget {
  // We pass in the 'day' map from your forecast list
  final Map<String, dynamic> dayData;

  const ForecastDetailSheet({super.key, required this.dayData});

  @override
  State<ForecastDetailSheet> createState() => _ForecastDetailSheetState();
}

class _ForecastDetailSheetState extends State<ForecastDetailSheet> {
  final Gemini _gemini = Gemini.instance;
  String _aiAdvice = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateAiAdvice();
  }

  /// This calls the AI to get specific advice for *this* day
  Future<void> _generateAiAdvice() async {
    final day = widget.dayData['day'] ?? {};
    final condition = day['condition']?['text'] ?? "clear";
    final minTemp = (day['mintemp_c'] as num?)?.round() ?? 0;
    final maxTemp = (day['maxtemp_c'] as num?)?.round() ?? 0;
    final date = widget.dayData['date'] ?? "this day";

    final String prompt = """
    You are a friendly and helpful weather assistant.
    Your friend is looking at the forecast for $date.

    The forecast is:
    - Condition: $condition
    - High: $maxTemp°C
    - Low: $minTemp°C

    Give them a short, helpful, and friendly tip (2-3 sentences) based on this forecast.
    Focus on what to wear, what to expect, or a good activity.

    Example: "With a high of $maxTemp°C and $condition, it looks like a great day for a walk! It might get cool in the evening, so a light jacket isn't a bad idea."
    """;

    try {
      final response = await _gemini.chat(
        [Content(parts: [Part.text(prompt)], role: 'user')],
        modelName: 'gemini-1.5-flash-latest', // Fast model for quick advice
      );

      if (mounted) {
        setState(() {
          _aiAdvice = response?.output ?? "Could not get AI advice.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAdvice = "An error occurred while getting AI advice.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extracting all data
    final dayInfo = widget.dayData['day'] ?? {};
    final String dateStr = widget.dayData['date'] ?? "";
    // ✅ Get the list of hours for this specific day
    final List<dynamic> hourlyData = widget.dayData['hour'] as List? ?? [];


    String formattedDate = "Forecast";
    try {
      final parsedDate = DateTime.parse(dateStr);
      // Format to "Forecast for Friday, May 17"
      formattedDate = "Forecast for ${DateFormat('EEEE, MMM d').format(parsedDate)}";
    } catch (e) {
      // fallback
    }

    final String condition = dayInfo['condition']?['text'] ?? "N/A";
    final String iconUrl = dayInfo['condition']?['icon'] ?? "";
    final int minTemp = (dayInfo['mintemp_c'] as num?)?.toInt() ?? 0;
    final int maxTemp = (dayInfo['maxtemp_c'] as num?)?.toInt() ?? 0;
    final int humidity = (dayInfo['avghumidity'] as num?)?.toInt() ?? 0;
    final double wind = (dayInfo['maxwind_kph'] as num?)?.toDouble() ?? 0;

    return Container(
      // This makes it look like a bottom sheet
      decoration: const BoxDecoration(
        color: Color(0xFF3949AB),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Make the sheet only as tall as needed
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Main Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              WeatherIconImage(iconUrl: iconUrl, size: 70),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$maxTemp° / $minTemp°",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    condition,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 15),

          // Extra Details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DetailItem(
                icon: Icons.water_drop_outlined,
                label: "Humidity",
                value: "$humidity%",
              ),
              _DetailItem(
                icon: Icons.air,
                label: "Wind",
                value: "${wind.round()} kph",
              ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),

          //
          // ✅ --- ADDED HOURLY FORECAST SECTION ---
          //
          const Text(
            "Hourly Details",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (hourlyData.isEmpty)
             const Text(
              "Hourly data not available for this day.",
              style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
            )
          else
            SizedBox(
              height: 100, // Adjust height as needed
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: hourlyData.length,
                itemBuilder: (context, index) {
                  final hour = hourlyData[index];
                  final timeStr = hour['time'] ?? "";
                  final temp = (hour['temp_c'] as num?)?.round() ?? 0;
                  final hourIconUrl = hour['condition']?['icon'] ?? "";

                  String formattedHour = "";
                  try {
                    final parsedTime = DateTime.parse(timeStr);
                    // Format like "1 AM", "11 PM" etc.
                    formattedHour = DateFormat('h a').format(parsedTime);
                  } catch (e) { /* Ignore parsing errors */ }

                  return Container(
                    width: 70, // Slightly narrower than main screen hourly cards
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          formattedHour,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        WeatherIconImage(iconUrl: hourIconUrl, size: 30),
                        Text(
                          "$temp°",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20), // Space after hourly list
          // ✅ --- END OF HOURLY FORECAST SECTION ---
          //

          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),

          // AI Advice Section
          const Text(
            "Companion's Advice",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _aiAdvice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          const SizedBox(height: 20), // For bottom safe area
        ],
      ),
    );
  }
}

// A small helper widget for the detail items (No changes needed here)
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}