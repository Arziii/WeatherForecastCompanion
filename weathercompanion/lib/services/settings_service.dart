// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer; // For logging

// Enum for Temperature Units
enum TemperatureUnit { celsius, fahrenheit }

// Enum for Wind Speed Units
enum WindSpeedUnit { kph, mph }

class SettingsService {
  static const String _tempUnitKey = 'temperature_unit';
  static const String _windUnitKey = 'wind_speed_unit';
  static const String _locationsKey = 'saved_locations';

  // Helper to safely get SharedPreferences instance
  Future<SharedPreferences?> _getPrefsInstance() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (e) {
       developer.log('CRITICAL: Failed to get SharedPreferences instance: $e', name: 'SettingsService', error: e);
       return null;
    }
  }


  // --- Temperature Unit ---
  Future<TemperatureUnit> getTemperatureUnit() async {
    final prefs = await _getPrefsInstance();
    if (prefs == null) return TemperatureUnit.celsius; // Default on error

    final unitString = prefs.getString(_tempUnitKey) ?? TemperatureUnit.celsius.name;
    return TemperatureUnit.values.firstWhere(
          (e) => e.name == unitString,
          orElse: () => TemperatureUnit.celsius,
    );
  }

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await _getPrefsInstance();
    if (prefs == null) return;
    await prefs.setString(_tempUnitKey, unit.name);
  }

  // --- Wind Speed Unit ---
  Future<WindSpeedUnit> getWindSpeedUnit() async {
    final prefs = await _getPrefsInstance();
     if (prefs == null) return WindSpeedUnit.kph; // Default on error

    final unitString = prefs.getString(_windUnitKey) ?? WindSpeedUnit.kph.name;
    return WindSpeedUnit.values.firstWhere(
          (e) => e.name == unitString,
          orElse: () => WindSpeedUnit.kph,
    );
  }

  Future<void> setWindSpeedUnit(WindSpeedUnit unit) async {
    final prefs = await _getPrefsInstance();
     if (prefs == null) return;
    await prefs.setString(_windUnitKey, unit.name);
  }

  // --- Conversion Helpers ---
  double toFahrenheit(double celsius) => (celsius * 9 / 5) + 32;
  double toMph(double kph) => kph / 1.60934;

  //
  // --- SAVED LOCATIONS LOGIC ---
  //
  Future<List<String>> getSavedLocations() async {
    final prefs = await _getPrefsInstance();
    if (prefs == null) return []; // Default on error
    // Return the saved list, or an empty list if none exists
    return prefs.getStringList(_locationsKey) ?? [];
  }

  Future<void> addSavedLocation(String cityName) async {
    final prefs = await _getPrefsInstance();
    if (prefs == null || cityName.isEmpty) return;

    List<String> locations = await getSavedLocations(); // Use the getter which handles potential null prefs
    // Add to list only if it's not already there (case-insensitive check)
    if (!locations.any((loc) => loc.toLowerCase() == cityName.toLowerCase())) {
      locations.add(cityName);
      await prefs.setStringList(_locationsKey, locations);
      developer.log("Location saved: $cityName", name: 'SettingsService');
    } else {
      developer.log("Location already exists: $cityName", name: 'SettingsService');
    }
  }

  Future<void> deleteSavedLocation(String cityName) async {
     final prefs = await _getPrefsInstance();
     if (prefs == null) return;

    List<String> locations = await getSavedLocations(); // Use the getter
    // Remove from list (case-insensitive check)
    locations.removeWhere((loc) => loc.toLowerCase() == cityName.toLowerCase());
    await prefs.setStringList(_locationsKey, locations);
     developer.log("Location deleted: $cityName", name: 'SettingsService');
  }
}