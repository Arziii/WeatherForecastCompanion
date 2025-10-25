// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weathercompanion/services/settings_service.dart';
import 'package:weathercompanion/services/theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _cityAddController = TextEditingController();

  // State variables for the settings
  TemperatureUnit _currentTempUnit = TemperatureUnit.celsius;
  WindSpeedUnit _currentWindUnit = WindSpeedUnit.kph;
  List<String> _savedLocations = [];
  String? _defaultLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  @override
  void dispose() {
    _cityAddController.dispose();
    super.dispose();
  }

  /// Load all settings from the service
  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);
    _currentTempUnit = await _settingsService.getTemperatureUnit();
    _currentWindUnit = await _settingsService.getWindSpeedUnit();
    _savedLocations = await _settingsService.getSavedLocations();
    _defaultLocation = await _settingsService.getDefaultLocation();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Add a new location and refresh the list
  Future<void> _addLocation() async {
    if (_cityAddController.text.isEmpty) return;

    final String newCity = _cityAddController.text;
    FocusScope.of(context).unfocus();
    _cityAddController.clear();

    await _settingsService.addSavedLocation(newCity);
    _loadAllSettings();
  }

  /// Delete a location and refresh the list
  Future<void> _deleteLocation(String cityName) async {
    await _settingsService.deleteSavedLocation(cityName);
    _loadAllSettings();
  }

  // --- Set a location as the default (Theme-Aware Snackbar) ---
  Future<void> _setDefaultLocation(String cityName) async {
    final theme = Theme.of(context);
    String? newDefault;

    if (_defaultLocation == cityName) {
      await _settingsService.clearDefaultLocation();
      newDefault = null;
    } else {
      await _settingsService.setDefaultLocation(cityName);
      newDefault = cityName;
    }

    if (mounted) {
      setState(() {
        _defaultLocation = newDefault;
      });

      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newDefault == null
                ? "Default location cleared."
                : "$newDefault set as default location.",
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
      );
    }
  }

  // --- Save the unit settings (Theme-Aware Snackbar) ---
  Future<void> _saveUnits() async {
    final theme = Theme.of(context);
    await _settingsService.setTemperatureUnit(_currentTempUnit);
    await _settingsService.setWindSpeedUnit(_currentWindUnit);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Units saved!",
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: theme.colorScheme.primaryContainer,
        ),
      );
    }
    print("Units saved");
  }

  /// Pop screen and send the selected city back to HomeScreen
  void _loadWeatherForCity(String cityName) {
    Navigator.pop(context, cityName);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final theme = Theme.of(context);
    final isDarkMode =
        theme.brightness == Brightness.dark; // <-- Check theme mode

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings & Locations'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: _isLoading
          ? Center(
              child:
                  CircularProgressIndicator(color: theme.colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- App Theme Settings ---
                Text(
                  'App Theme',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Card(
                  color: theme.cardColor,
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RadioListTile<ThemeModeSetting>(
                          title: Text('System Default',
                              style: theme.textTheme.bodyLarge),
                          value: ThemeModeSetting.system,
                          groupValue: themeService.themeModeSetting,
                          onChanged: (v) => themeService.setTheme(v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<ThemeModeSetting>(
                          title: Text('Light Mode',
                              style: theme.textTheme.bodyLarge),
                          value: ThemeModeSetting.light,
                          groupValue: themeService.themeModeSetting,
                          onChanged: (v) => themeService.setTheme(v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<ThemeModeSetting>(
                          title: Text('Dark Mode',
                              style: theme.textTheme.bodyLarge),
                          value: ThemeModeSetting.dark,
                          groupValue: themeService.themeModeSetting,
                          onChanged: (v) => themeService.setTheme(v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Unit Settings ---
                Text(
                  'Units',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Card(
                  color: theme.cardColor,
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Temperature Unit:',
                            style: theme.textTheme.labelLarge),
                        RadioListTile<TemperatureUnit>(
                          title: Text('Celsius (°C)',
                              style: theme.textTheme.bodyLarge),
                          value: TemperatureUnit.celsius,
                          groupValue: _currentTempUnit,
                          onChanged: (v) =>
                              setState(() => _currentTempUnit = v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<TemperatureUnit>(
                          title: Text('Fahrenheit (°F)',
                              style: theme.textTheme.bodyLarge),
                          value: TemperatureUnit.fahrenheit,
                          groupValue: _currentTempUnit,
                          onChanged: (v) =>
                              setState(() => _currentTempUnit = v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        Text('Wind Speed Unit:',
                            style: theme.textTheme.labelLarge),
                        RadioListTile<WindSpeedUnit>(
                          title: Text('kph', style: theme.textTheme.bodyLarge),
                          value: WindSpeedUnit.kph,
                          groupValue: _currentWindUnit,
                          onChanged: (v) =>
                              setState(() => _currentWindUnit = v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<WindSpeedUnit>(
                          title: Text('mph', style: theme.textTheme.bodyLarge),
                          value: WindSpeedUnit.mph,
                          groupValue: _currentWindUnit,
                          onChanged: (v) =>
                              setState(() => _currentWindUnit = v!),
                          activeColor: theme.colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            // --- MODIFIED: TextButton Color ---
                            child: Text(
                              'Save Units',
                              style: TextStyle(
                                  color: isDarkMode
                                      ? theme.colorScheme
                                          .onSurface // White in dark mode
                                      : theme.colorScheme
                                          .primary, // Blue in light mode
                                  fontWeight: FontWeight.bold),
                            ),
                            // --- END MODIFIED ---
                            onPressed: _saveUnits,
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Saved Locations ---
                Text(
                  'Saved Locations',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Card(
                  color: theme.cardColor,
                  elevation: 2.0,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Add Location Input
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _cityAddController,
                                style: TextStyle(
                                    color:
                                        theme.colorScheme.onSecondaryContainer),
                                decoration: InputDecoration(
                                  hintText: "Enter city name to add",
                                  hintStyle: TextStyle(
                                      color: theme
                                          .colorScheme.onSecondaryContainer
                                          .withOpacity(0.7)),
                                  filled: true,
                                  fillColor:
                                      theme.colorScheme.secondaryContainer,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                onSubmitted: (value) => _addLocation(),
                              ),
                            ),
                            IconButton(
                              // --- MODIFIED: IconButton Color ---
                              icon: Icon(
                                Icons.add_circle,
                                color: isDarkMode
                                    ? theme.colorScheme
                                        .onSurface // White in dark mode
                                    : theme.colorScheme
                                        .primary, // Blue in light mode
                              ),
                              // --- END MODIFIED ---
                              onPressed: _addLocation,
                              tooltip: 'Add Location',
                            )
                          ],
                        ),
                        const SizedBox(height: 10),
                        Divider(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.2)),
                        // Location List
                        if (_savedLocations.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Column(
                              children: [
                                Text(
                                  "No locations saved yet.",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodyMedium?.color
                                        ?.withOpacity(0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Tap the star to set a default location.",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color
                                        ?.withOpacity(0.5),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _savedLocations.length,
                            itemBuilder: (context, index) {
                              final location = _savedLocations[index];
                              final bool isDefault =
                                  _defaultLocation == location;

                              return ListTile(
                                leading: IconButton(
                                  icon: Icon(
                                    isDefault ? Icons.star : Icons.star_border,
                                    color: isDefault
                                        ? theme.colorScheme.primary
                                        : theme.iconTheme.color
                                            ?.withOpacity(0.6),
                                  ),
                                  onPressed: () =>
                                      _setDefaultLocation(location),
                                  tooltip: 'Set as Default Location',
                                ),
                                title: Text(location,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w500)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.redAccent),
                                  onPressed: () => _deleteLocation(location),
                                  tooltip: 'Delete Location',
                                ),
                                onTap: () => _loadWeatherForCity(location),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 0),
                                dense: true,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
