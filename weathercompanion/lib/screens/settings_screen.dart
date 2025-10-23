// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:weathercompanion/services/settings_service.dart';

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
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Add a new location and refresh the list
  Future<void> _addLocation() async {
    if (_cityAddController.text.isEmpty) return;

    final String newCity = _cityAddController.text;
    FocusScope.of(context).unfocus(); // Hide keyboard
    _cityAddController.clear();
    
    await _settingsService.addSavedLocation(newCity);
    _loadAllSettings(); // Reload settings and locations
  }

  /// Delete a location and refresh the list
  Future<void> _deleteLocation(String cityName) async {
    await _settingsService.deleteSavedLocation(cityName);
    _loadAllSettings(); // Reload settings and locations
  }
  
  /// Save the unit settings
  Future<void> _saveUnits() async {
    await _settingsService.setTemperatureUnit(_currentTempUnit);
    await _settingsService.setWindSpeedUnit(_currentWindUnit);
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Units saved!"),
          backgroundColor: Colors.green,
        )
      );
    }
    print("Units saved");
  }

  /// Pop screen and send the selected city back to HomeScreen
  void _loadWeatherForCity(String cityName) {
    Navigator.pop(context, cityName); // Send the city name back
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3949AB), // Match theme
      appBar: AppBar(
        title: const Text('Settings & Locations'),
        backgroundColor: const Color(0xFF3F51B5), // Slightly darker AppBar
        foregroundColor: Colors.white, // Make title/icon white
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView( // Use ListView for scrolling
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- Unit Settings ---
                Text('Units', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Card(
                   color: Colors.white.withOpacity(0.1),
                   elevation: 2.0,
                   child: Padding(
                     padding: const EdgeInsets.all(12.0),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const Text('Temperature Unit:', style: TextStyle(color: Colors.white70)),
                           RadioListTile<TemperatureUnit>(
                             title: const Text('Celsius (°C)', style: TextStyle(color: Colors.white)),
                             value: TemperatureUnit.celsius,
                             groupValue: _currentTempUnit,
                             onChanged: (v) => setState(() => _currentTempUnit = v!),
                             activeColor: Colors.white, contentPadding: EdgeInsets.zero,
                           ),
                           RadioListTile<TemperatureUnit>(
                             title: const Text('Fahrenheit (°F)', style: TextStyle(color: Colors.white)),
                             value: TemperatureUnit.fahrenheit,
                             groupValue: _currentTempUnit,
                             onChanged: (v) => setState(() => _currentTempUnit = v!),
                             activeColor: Colors.white, contentPadding: EdgeInsets.zero,
                           ),
                           const SizedBox(height: 10),
                           const Text('Wind Speed Unit:', style: TextStyle(color: Colors.white70)),
                           RadioListTile<WindSpeedUnit>(
                             title: const Text('kph', style: TextStyle(color: Colors.white)),
                             value: WindSpeedUnit.kph,
                             groupValue: _currentWindUnit,
                             onChanged: (v) => setState(() => _currentWindUnit = v!),
                             activeColor: Colors.white, contentPadding: EdgeInsets.zero,
                           ),
                           RadioListTile<WindSpeedUnit>(
                             title: const Text('mph', style: TextStyle(color: Colors.white)),
                             value: WindSpeedUnit.mph,
                             groupValue: _currentWindUnit,
                             onChanged: (v) => setState(() => _currentWindUnit = v!),
                             activeColor: Colors.white, contentPadding: EdgeInsets.zero,
                           ),
                           Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                 child: const Text('Save Units', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                 onPressed: _saveUnits,
                              ),
                           )
                        ],
                     ),
                   ),
                ),
                const SizedBox(height: 24),

                // --- Saved Locations ---
                Text('Saved Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                 Card(
                   color: Colors.white.withOpacity(0.1),
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
                                 style: const TextStyle(color: Colors.white),
                                 decoration: InputDecoration(
                                   hintText: "Enter city name to add",
                                   hintStyle: const TextStyle(color: Colors.white70),
                                   filled: true, fillColor: Colors.black.withOpacity(0.2),
                                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                   contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                   isDense: true,
                                 ),
                                 onSubmitted: (value) => _addLocation(),
                               ),
                             ),
                             IconButton(
                               icon: const Icon(Icons.add_circle, color: Colors.white), // Solid icon
                               onPressed: _addLocation,
                               tooltip: 'Add Location',
                             )
                           ],
                         ),
                         const SizedBox(height: 10),
                         Divider(color: Colors.white.withOpacity(0.2)),
                         // Location List
                         if (_savedLocations.isEmpty)
                           const Padding(
                             padding: EdgeInsets.symmetric(vertical: 20.0),
                             child: Text("No locations saved yet.", style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                           )
                         else
                           ListView.builder(
                             shrinkWrap: true,
                             physics: const NeverScrollableScrollPhysics(),
                             itemCount: _savedLocations.length,
                             itemBuilder: (context, index) {
                               final location = _savedLocations[index];
                               return ListTile(
                                 title: Text(location, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                 trailing: IconButton(
                                   icon: const Icon(Icons.delete, color: Colors.redAccent),
                                   onPressed: () => _deleteLocation(location),
                                   tooltip: 'Delete Location',
                                 ),
                                 onTap: () => _loadWeatherForCity(location), // Tap to load weather
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 4),
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