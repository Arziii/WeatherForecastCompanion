// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';

// Enum for Temperature Units
enum TemperatureUnit { celsius, fahrenheit }

// Enum for Wind Speed Units
enum WindSpeedUnit { kph, mph }

class SettingsService {
  static const String _tempUnitKey = 'temperature_unit';
  static const String _windUnitKey = 'wind_speed_unit';
  // ✅ ADD New key for saved locations
  static const String _locationsKey = 'saved_locations';


  // --- Temperature Unit ---
  Future<TemperatureUnit> getTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(_tempUnitKey) ?? TemperatureUnit.celsius.name;
    return TemperatureUnit.values.firstWhere(
          (e) => e.name == unitString,
          orElse: () => TemperatureUnit.celsius,
    );
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tempUnitKey, unit.name);
  }

  // --- Wind Speed Unit ---
  Future<WindSpeedUnit> getWindSpeedUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitString = prefs.getString(_windUnitKey) ?? WindSpeedUnit.kph.name;
    return WindSpeedUnit.values.firstWhere(
          (e) => e.name == unitString,
          orElse: () => WindSpeedUnit.kph,
    );
  }

  Future<void> setWindSpeedUnit(WindSpeedUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_windUnitKey, unit.name);
  }

  // --- Conversion Helpers ---
  double toFahrenheit(double celsius) => (celsius * 9 / 5) + 32;
  double toMph(double kph) => kph / 1.60934;

  //
  // ✅ --- ADDED SAVED LOCATIONS LOGIC ---
  //
  Future<List<String>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    // Return the saved list, or an empty list if none exists
    return prefs.getStringList(_locationsKey) ?? [];
  }

  Future<void> addSavedLocation(String cityName) async {
    if (cityName.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> locations = await getSavedLocations();
    // Add to list only if it's not already there (case-insensitive check)
    if (!locations.any((loc) => loc.toLowerCase() == cityName.toLowerCase())) {
      locations.add(cityName);
      await prefs.setStringList(_locationsKey, locations);
      print("Location saved: $cityName");
    } else {
      print("Location already exists: $cityName");
    }
  }

  Future<void> deleteSavedLocation(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> locations = await getSavedLocations();
    // Remove from list (case-insensitive check)
    locations.removeWhere((loc) => loc.toLowerCase() == cityName.toLowerCase());
    await prefs.setStringList(_locationsKey, locations);
    print("Location deleted: $cityName");
  }
}