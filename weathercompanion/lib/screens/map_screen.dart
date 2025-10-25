// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final LatLng center;
  final String title;

  const MapScreen({
    super.key,
    required this.center,
    this.title = "Weather Map",
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Base map layers
  final String _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String _osmUserAgent = 'com.example.weathercompanion';

  // Weather map layers from OpenWeatherMap
  // IMPORTANT: You would need an OpenWeatherMap API key for this
  // This is just a placeholder URL.
  // For a real implementation, you'd replace {API_KEY}
  final String _precipitationLayerUrl =
      'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={API_KEY}';
  final String _tempLayerUrl =
      'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={API_KEY}';

  // State for selected layer
  String _selectedLayerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  bool _isWeatherLayer = false;
  int _selectedLayerIndex = 0; // 0: OSM, 1: Rain, 2: Temp

  void _changeMapLayer(int index) {
    setState(() {
      _selectedLayerIndex = index;
      if (index == 1) {
        _selectedLayerUrl = _precipitationLayerUrl;
        _isWeatherLayer = true;
      } else if (index == 2) {
        _selectedLayerUrl = _tempLayerUrl;
        _isWeatherLayer = true;
      } else {
        // Default to OSM
        _selectedLayerUrl = _osmUrl;
        _isWeatherLayer = false;
        _selectedLayerIndex = 0; // Ensure index is 0
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedLayerUrl = _osmUrl; // Start with default OSM
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        // These will now be set by the main.dart ThemeService
        actions: [
          // Layer selection dropdown
          PopupMenuButton<int>(
            icon: const Icon(Icons.layers), // Icon color will be from theme
            onSelected: _changeMapLayer,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              const PopupMenuItem<int>(
                value: 0,
                child: Text('Standard Map'),
              ),
              const PopupMenuItem<int>(
                value: 1,
                child: Text('Precipitation'),
              ),
              const PopupMenuItem<int>(
                value: 2,
                child: Text('Temperature'),
              ),
            ],
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: 13.0,
        ),
        children: [
          // Base Layer (Always OSM)
          TileLayer(
            urlTemplate: _osmUrl,
            userAgentPackageName: _osmUserAgent,
          ),

          // Weather Overlay (if selected)
          if (_isWeatherLayer)
            // ✅ FIX: Wrap the TileLayer in an Opacity widget
            Opacity(
              opacity: 0.6, // Make it semi-transparent
              child: TileLayer(
                urlTemplate: _selectedLayerUrl,
                // Note: You MUST replace {API_KEY}
                // This will likely fail without a valid OWM API key
                additionalOptions: const {
                  'apiKey':
                      'YOUR_OPENWEATHERMAP_API_KEY_HERE' // <-- IMPORTANT
                },
                userAgentPackageName: _osmUserAgent,
                // opacity: 0.6, <-- REMOVED FROM HERE
              ),
            ),

          // Marker for the location
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: widget.center,
                child: Icon(
                  Icons.location_pin,
                  color: theme.colorScheme.primary, // THEME AWARE
                  size: 40.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}