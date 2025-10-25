// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:weathercompanion/services/theme_service.dart'; // Import ThemeService
import 'package:provider/provider.dart'; // Import Provider
import 'dart:developer' as developer; // Import developer log


// Enum for Map Layer Types
enum MapLayerType { standard, precipitation, temperature }

class MapScreen extends StatefulWidget {
  final LatLng center;
  final String title;

  const MapScreen({super.key, required this.center, required this.title});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // --- OpenWeatherMap API Key ---
  //
  // 👇👇👇 PASTE THE "Default" KEY HERE (TRIPLE-CHECK IT!) 👇👇👇
  //
  final String _apiKey = "90d3406644f218d6030844d8931b8705"; // <-- Replace this string
  //
  // 👆👆👆 PASTE THE "Default" KEY HERE 👆👆👆
  //

  MapLayerType _currentLayer = MapLayerType.standard;
  final MapController _mapController = MapController();

  // Define URL templates
  final String _standardUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String _precipitationUrlTemplate =
      'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={apiKey}';
  final String _temperatureUrlTemplate =
      'https://tile.openweathermap.org/map/temp_new/{z}/{x}/{y}.png?appid={apiKey}';


  // --- Helper: Build Error Tile Widget ---
  Widget _buildErrorTileWidget(TileImage tile, Object error, StackTrace? stackTrace) {
    developer.log(
      'Error loading tile: ${tile.coordinates.toString()}, Error: $error',
      name: 'MapScreen',
      error: error,
      stackTrace: stackTrace,
    );
    // Simple grey tile as a placeholder on error
    return Container(
      color: Colors.grey.withOpacity(0.5),
      child: Center(
        child: Icon(Icons.error_outline, color: Colors.red.withOpacity(0.5), size: 16),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Access ThemeService via Provider
    final themeService = Provider.of<ThemeService>(context);
    final isDarkMode = themeService.themeMode == ThemeMode.dark;
    final theme = Theme.of(context); // Get current theme

    // --- ADDED Opacity Variables ---
    //
    // 👇👇👇 VIBE CHECK (Light Mode Opacity) 👇👇👇
    //
    const double lightModeOpacity = 0.6; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Light Mode Opacity) 👆👆👆
    //

    //
    // 👇👇👇 VIBE CHECK (Dark Mode Opacity) 👇👇👇
    //
    const double darkModeOpacity = 0.2; // <- YOUR VALUE
    //
    // 👆👆👆 VIBE CHECK (Dark Mode Opacity) 👆👆👆
    //
    // --- END ADDED ---


    return Scaffold(
      extendBodyBehindAppBar: true, // Make AppBar float
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: theme.appBarTheme.backgroundColor?.withOpacity(0.8),
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          _buildLayerPopupMenu(theme),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: 13.0,
          maxZoom: 18.0,
          minZoom: 3.0,
        ),
        children: [
          _buildMapLayers(isDarkMode, lightModeOpacity, darkModeOpacity), // Pass opacities
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.floatingActionButtonTheme.backgroundColor,
        foregroundColor: theme.floatingActionButtonTheme.foregroundColor,
        onPressed: () {
          _mapController.move(widget.center, 13.0);
        },
        tooltip: 'Center Map',
        child: const Icon(Icons.my_location),
      ),
    );
  }

  // Helper to build the layers based on selection and theme
  Widget _buildMapLayers(bool isDarkMode, double lightOpacity, double darkOpacity) { // Added opacities as params
    List<Widget> layers = [];

    // Base Layer
    String currentStandardUrl = _standardUrlTemplate;
    if (isDarkMode) {
      currentStandardUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
    }

    layers.add(
      TileLayer(
        urlTemplate: currentStandardUrl,
        subdomains: isDarkMode ? ['a', 'b', 'c', 'd'] : const [],
        userAgentPackageName: 'com.example.weathercompanion',
        errorTileCallback: (tile, error, stackTrace) {
           developer.log(
             'Error loading BASE tile: ${tile.coordinates.toString()}, Error: $error',
             name: 'MapScreen',
             error: error,
             stackTrace: stackTrace,
           );
         },
         errorImage: const AssetImage('assets/images/map_error.png'),
      ),
    );

    // Optional Overlay Layer
    String? overlayUrlTemplate;
    Key? overlayKey;

    if (_currentLayer == MapLayerType.precipitation) {
      overlayUrlTemplate = _precipitationUrlTemplate;
      overlayKey = const Key('precipitation');
    } else if (_currentLayer == MapLayerType.temperature) {
      overlayUrlTemplate = _temperatureUrlTemplate;
       overlayKey = const Key('temperature');
    }

    if (overlayUrlTemplate != null) {
      // --- FIX: Wrap TileLayer in Opacity Widget ---
      layers.add(
        Opacity(
          opacity: isDarkMode ? darkOpacity : lightOpacity, // Apply conditional opacity HERE
          child: TileLayer(
            key: overlayKey,
            urlTemplate: overlayUrlTemplate,
            additionalOptions: {'apiKey': _apiKey},
            // --- FIX: REMOVED opacity parameter ---
            // opacity: 0.6, // REMOVED THIS LINE
            userAgentPackageName: 'com.example.weathercompanion',
            errorTileCallback: (tile, error, stackTrace) {
               _buildErrorTileWidget(tile, error, stackTrace);
             },
             errorImage: const AssetImage('assets/images/map_error.png'),
          ),
        ),
        // --- END FIX ---
      );
    }

    // Marker Layer (Added from your reference)
     layers.add(
       MarkerLayer(
         markers: [
           Marker(
             width: 80.0,
             height: 80.0,
             point: widget.center,
             child: Icon(
               Icons.location_pin,
               color: Theme.of(context).colorScheme.primary, // Use Theme.of(context) here
               size: 40.0,
             ),
           ),
         ],
       ),
     );


    return Stack(children: layers); // Use Stack to overlay layers + marker
  }


   // Helper to build the layer selection popup menu
  Widget _buildLayerPopupMenu(ThemeData theme) {
    return PopupMenuButton<MapLayerType>(
      initialValue: _currentLayer,
      icon: Icon(Icons.layers, color: theme.colorScheme.onPrimary), // Adjusted for potential AppBar contrast
      onSelected: (MapLayerType result) {
        if (_currentLayer != result) {
           developer.log('Map layer changed to: $result', name: 'MapScreen');
           // --- FIX: Use correct URL based on _apiKey ---
           String newUrl;
           bool isWeather = true;
           if (result == MapLayerType.precipitation) {
              newUrl = _precipitationUrlTemplate;
           } else if (result == MapLayerType.temperature) {
              newUrl = _temperatureUrlTemplate;
           } else {
              newUrl = _standardUrlTemplate; // Use the standard one defined above
              isWeather = false;
           }
           setState(() {
             _currentLayer = result;
             _selectedLayerUrl = newUrl; // Update selected URL state if needed (though _buildMapLayers uses _currentLayer)
             _isWeatherLayer = isWeather; // Update weather layer flag
             // Layer rebuild is handled by setState triggering _buildMapLayers
           });
           // --- END FIX ---
        }
      },
      color: theme.popupMenuTheme.color,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<MapLayerType>>[
        PopupMenuItem<MapLayerType>(
          value: MapLayerType.standard,
          child: Text('Standard Map', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        ),
        PopupMenuItem<MapLayerType>(
          value: MapLayerType.precipitation,
          child: Text('Precipitation', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        ),
        PopupMenuItem<MapLayerType>(
          value: MapLayerType.temperature,
          child: Text('Temperature', style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        ),
      ],
    );
  }
}

// --- Placeholder Error Image ---
// Create a simple error image in your assets, e.g., 'assets/images/map_error.png'
// Make sure 'assets/images/' is listed in your pubspec.yaml
// ---