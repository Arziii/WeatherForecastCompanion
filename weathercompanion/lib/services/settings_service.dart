// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'dart:developer' as developer; // For logging

// Enum for Temperature Unit
enum TemperatureUnit { celsius, fahrenheit }

// Enum for Wind Speed Unit
enum WindSpeedUnit { kph, mph }

class SettingsService {
  static const String _keyTempUnit = 'temperature_unit';
  static const String _keyWindUnit = 'wind_speed_unit';
  static const String _keySavedLocations = 'saved_locations';
  static const String _keyDefaultLocation = 'default_location'; // <-- NEW KEY

  // --- Temperature Unit ---

  Future<void> setTemperatureUnit(TemperatureUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTempUnit, unit.name);
    developer.log("SettingsService: Saved Temp Unit: ${unit.name}",
        name: 'SettingsService');
  }

  Future<TemperatureUnit> getTemperatureUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitName = prefs.getString(_keyTempUnit);
    developer.log("SettingsService: Loaded Temp Unit: $unitName",
        name: 'SettingsService');
    return TemperatureUnit.values.firstWhere(
      (e) => e.name == unitName,
      orElse: () => TemperatureUnit.celsius, // Default
    );
  }

  // --- Wind Speed Unit ---

  Future<void> setWindSpeedUnit(WindSpeedUnit unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWindUnit, unit.name);
    developer.log("SettingsService: Saved Wind Unit: ${unit.name}",
        name: 'SettingsService');
  }

  Future<WindSpeedUnit> getWindSpeedUnit() async {
    final prefs = await SharedPreferences.getInstance();
    final unitName = prefs.getString(_keyWindUnit);
    developer.log("SettingsService: Loaded Wind Unit: $unitName",
        name: 'SettingsService');
    return WindSpeedUnit.values.firstWhere(
      (e) => e.name == unitName,
      orElse: () => WindSpeedUnit.kph, // Default
    );
  }

  // --- Saved Locations ---

  Future<List<String>> getSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final locations = prefs.getStringList(_keySavedLocations) ?? [];
    developer.log("SettingsService: Loaded ${locations.length} locations.",
        name: 'SettingsService');
    return locations;
  }

  Future<void> addSavedLocation(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    final locations = await getSavedLocations();
    if (!locations.map((e) => e.toLowerCase()).contains(cityName.toLowerCase())) {
      locations.add(cityName);
      await prefs.setStringList(_keySavedLocations, locations);
      developer.log("SettingsService: Added location: $cityName",
          name: 'SettingsService');
    } else {
      developer.log("SettingsService: Location $cityName already exists.",
          name: 'SettingsService');
    }
  }

  Future<void> deleteSavedLocation(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    final locations = await getSavedLocations();
    locations
        .removeWhere((loc) => loc.toLowerCase() == cityName.toLowerCase());
    await prefs.setStringList(_keySavedLocations, locations);
    developer.log("SettingsService: Deleted location: $cityName",
        name: 'SettingsService');

    // --- NEW: Check if deleted location was the default ---
    final defaultLocation = await getDefaultLocation();
    if (defaultLocation != null &&
        defaultLocation.toLowerCase() == cityName.toLowerCase()) {
      await clearDefaultLocation();
      developer.log(
          "SettingsService: Deleted location was default. Clearing default.",
          name: 'SettingsService');
    }
    // --- END NEW ---
  }

  // --- NEW: Default Location ---

  /// Gets the saved default location. Returns null if none is set.
  Future<String?> getDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultLoc = prefs.getString(_keyDefaultLocation);
    developer.log("SettingsService: Loaded Default Location: $defaultLoc",
        name: 'SettingsService');
    return defaultLoc;
  }

  /// Sets a city name as the default location.
  Future<void> setDefaultLocation(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultLocation, cityName);
    developer.log("SettingsService: Set Default Location: $cityName",
        name: 'SettingsService');
  }

  /// Clears the default location.
  Future<void> clearDefaultLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDefaultLocation);
    developer.log("SettingsService: Cleared Default Location.",
        name: 'SettingsService');
  }

  // --- END NEW ---

  // --- Unit Conversion Helpers ---

  /// Converts Celsius to Fahrenheit
  double toFahrenheit(double celsius) {
    return (celsius * 9 / 5) + 32;
  }

  /// Converts kph to mph
  double toMph(double kph) {
    return kph * 0.621371;
  }
}