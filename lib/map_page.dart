
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:google_fonts/google_fonts.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final ApiClient _apiClient = ApiClient();
  List<Marker> _markers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await _apiClient.get('/tasks/locations');
      if (response.statusCode == 200) {
        final List<dynamic> tasks = jsonDecode(response.body);
        final List<Marker> markers = tasks.map((task) {
          return Marker(
            point: LatLng(task['latitude'], task['longitude']),
            width: 80,
            height: 80,
            child: Column(
              children: [
                const Icon(Icons.location_on, color: Colors.red, size: 40),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task['title'],
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList();

        setState(() {
          _markers = markers;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'HARTA TACTICĂ',
          style: GoogleFonts.robotoSlab(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : FlutterMap(
              options: MapOptions(
                initialCenter: const LatLng(44.4268, 26.1025), // Bucharest default
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.task_manager_app',
                  // Dark mode tiles would be better, but standard OSM for now
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}
