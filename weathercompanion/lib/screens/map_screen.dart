// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatelessWidget {
  final LatLng center;
  final String title;

  const MapScreen({super.key, required this.center, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Map: $title"),
        backgroundColor: const Color(0xFF3F51B5),
      ),
      body: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: 13.0),
        children: [
          TileLayer(
            // UPDATED: Removed the {s} subdomain part
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.weathercompanion',
            // REMOVED: The subdomains property
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: center,
                child: const Column(
                  children: [
                    Icon(Icons.location_pin, color: Colors.red, size: 40),
                    // Text(title)
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
