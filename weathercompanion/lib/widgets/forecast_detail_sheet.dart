// lib/widgets/forecast_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:weathercompanion/widgets/weather_icon_image.dart';
import 'package:intl/intl.dart';
// ✅ Import Settings Service and Enums
import 'package:weathercompanion/services/settings_service.dart';

class ForecastDetailSheet extends StatefulWidget {
  final Map<String, dynamic> dayData;
  // ✅ ADD Current unit settings
  final TemperatureUnit tempUnit;
  final WindSpeedUnit windUnit;

  const ForecastDetailSheet({
    super.key,
    required this.dayData,
    // ✅ Make them required
    required this.tempUnit,
    required this.windUnit,
  });

  @override
  State<ForecastDetailSheet> createState() => _ForecastDetailSheetState();
}

class _ForecastDetailSheetState extends State<ForecastDetailSheet> {
  final Gemini _gemini = Gemini.instance;
  // ✅ Need SettingsService instance for conversions
  final SettingsService _settingsService = SettingsService();
  String _aiAdvice = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateAiAdvice();
  }

  Future<void> _generateAiAdvice() async {
    final day = widget.dayData['day'] ?? {};
    final condition = day['condition']?['text'] ?? "clear";
    // Get temps in Celsius first
    final int minTempC = (widget.dayData['day']?['mintemp_c'] as num?)?.round() ?? 0;
    final int maxTempC = (widget.dayData['day']?['maxtemp_c'] as num?)?.round() ?? 0;
    final date = widget.dayData['date'] ?? "this day";

    // ✅ Convert temps for the AI prompt based on settings
    final String tempPrompt = widget.tempUnit == TemperatureUnit.celsius
        ? "High: ${maxTempC}°C, Low: ${minTempC}°C"
        : "High: ${_settingsService.toFahrenheit(maxTempC.toDouble()).round()}°F, Low: ${_settingsService.toFahrenheit(minTempC.toDouble()).round()}°F";


    final String prompt = """
    You are a friendly and helpful weather assistant.
    Your friend is looking at the forecast for $date.

    The forecast is:
    - Condition: $condition
    - $tempPrompt

    Give them a short, helpful, and friendly tip (2-3 sentences) based on this forecast.
    Focus on what to wear, what to expect, or a good activity.
    """;

    try {
      final response = await _gemini.chat(
        [Content(parts: [Part.text(prompt)], role: 'user')],
        modelName: 'gemini-1.5-flash-latest',
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
    // Extract data
    final dayInfo = widget.dayData['day'] ?? {};
    final String dateStr = widget.dayData['date'] ?? "";
    final List<dynamic> hourlyData = widget.dayData['hour'] as List? ?? [];

    String formattedDate = "Forecast";
    try {
      final parsedDate = DateTime.parse(dateStr);
      formattedDate = "Forecast for ${DateFormat('EEEE, MMM d').format(parsedDate)}";
    } catch (e) { /* fallback */ }

    final String condition = dayInfo['condition']?['text'] ?? "N/A";
    final String iconUrl = dayInfo['condition']?['icon'] ?? "";
    // Get standard units
    final int minTempC = (dayInfo['mintemp_c'] as num?)?.toInt() ?? 0;
    final int maxTempC = (dayInfo['maxtemp_c'] as num?)?.toInt() ?? 0;
    final int humidity = (dayInfo['avghumidity'] as num?)?.toInt() ?? 0;
    final double windKph = (dayInfo['maxwind_kph'] as num?)?.toDouble() ?? 0;

    // ✅ Convert for display
    final String displayMaxTemp = widget.tempUnit == TemperatureUnit.celsius
       ? "$maxTempC" : "${_settingsService.toFahrenheit(maxTempC.toDouble()).round()}";
    final String displayMinTemp = widget.tempUnit == TemperatureUnit.celsius
       ? "$minTempC" : "${_settingsService.toFahrenheit(minTempC.toDouble()).round()}";
    final String tempSymbol = widget.tempUnit == TemperatureUnit.celsius ? "°" : "°";

    final String displayWind = widget.windUnit == WindSpeedUnit.kph
       ? "${windKph.round()}" : "${_settingsService.toMph(windKph).round()}";
    final String windSymbol = widget.windUnit == WindSpeedUnit.kph ? "kph" : "mph";


    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF3949AB),
        borderRadius: BorderRadius.only( topLeft: Radius.circular(20), topRight: Radius.circular(20), ),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center( child: Text( formattedDate, style: const TextStyle( color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, ), ), ),
          const SizedBox(height: 20),
          // Main Info
          Row( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              WeatherIconImage(iconUrl: iconUrl, size: 70),
              Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text( "$displayMaxTemp$tempSymbol / $displayMinTemp$tempSymbol", style: const TextStyle( color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600, ), ),
                  Text( condition, style: const TextStyle( color: Colors.white70, fontSize: 18, ), ),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 15),
          // Extra Details
          Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _DetailItem( icon: Icons.water_drop_outlined, label: "Humidity", value: "$humidity%", ),
              _DetailItem( icon: Icons.air, label: "Wind", value: "$displayWind $windSymbol", ),
            ],
          ),
          const SizedBox(height: 15),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          // Hourly Forecast Section
          const Text( "Hourly Details", style: TextStyle( color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, ), ),
          const SizedBox(height: 10),
          if (hourlyData.isEmpty)
             const Text( "Hourly data not available.", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic), )
          else
            SizedBox( height: 100,
              child: ListView.builder( scrollDirection: Axis.horizontal, itemCount: hourlyData.length,
                itemBuilder: (context, index) {
                  final hour = hourlyData[index];
                  final timeStr = hour['time'] ?? "";
                  // Get Celsius Temp
                  final double tempC = (hour['temp_c'] as num?)?.toDouble() ?? 0.0;
                  final hourIconUrl = hour['condition']?['icon'] ?? "";

                  // ✅ Convert Hour Temp
                   final String displayHourTemp = widget.tempUnit == TemperatureUnit.celsius
                        ? "${tempC.round()}" : "${_settingsService.toFahrenheit(tempC).round()}";

                  String formattedHour = "";
                  try { final parsedTime = DateTime.parse(timeStr); formattedHour = DateFormat('h a').format(parsedTime); } catch (e) { /* Ignore */ }

                  return Container( width: 70, margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration( color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(10), ),
                    child: Column( mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        Text( formattedHour, style: const TextStyle( color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500, ), ),
                        WeatherIconImage(iconUrl: hourIconUrl, size: 30),
                        Text( "$displayHourTemp$tempSymbol", style: const TextStyle( color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, ), ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 20),
          // AI Advice Section
          const Text( "Companion's Advice", style: TextStyle( color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, ), ),
          const SizedBox(height: 10),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: Colors.white))
          else Container( width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration( color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(10), ),
              child: Text( _aiAdvice, style: const TextStyle( color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic, height: 1.4, ), ),
            ),
          const SizedBox(height: 20), // Bottom padding
        ],
      ),
    );
  }
}

// Detail Item Helper Widget
class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  // Use const constructor
  const _DetailItem({ required this.icon, required this.label, required this.value, });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white70, size: 28),
        const SizedBox(height: 4),
        Text( value, style: const TextStyle( color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, ), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,),
        Text( label, style: const TextStyle( color: Colors.white70, fontSize: 14, ), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,),
      ],
    );
  }
}