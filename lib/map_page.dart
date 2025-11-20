
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
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final List<Marker> allMarkers = [];

      // 1. Fetch Task Locations
      final tasksResponse = await _apiClient.get('/tasks/locations');
      if (tasksResponse.statusCode == 200) {
        final List<dynamic> tasks = jsonDecode(tasksResponse.body);
        allMarkers.addAll(tasks.map((task) {
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
        }));
      }

      // 2. Fetch Member Locations (via Workspaces)
      // Presupunem că membrii au locație în obiectul lor din workspace
      final workspacesResponse = await _apiClient.get('/workspaces');
      if (workspacesResponse.statusCode == 200) {
        final List<dynamic> workspaces = jsonDecode(workspacesResponse.body);
        final Set<String> processedMemberIds = {};

        for (var workspace in workspaces) {
          // Fetch detailed workspace info to get members if not included in list
          // De obicei /workspaces returnează lista simplă, deci luăm detalii
          final detailResponse = await _apiClient.get('/workspaces/${workspace['id']}');
          if (detailResponse.statusCode == 200) {
            final detail = jsonDecode(detailResponse.body);
            final List<dynamic> members = detail['members'] ?? [];

            for (var member in members) {
              final memberId = member['id'];
              if (memberId != null && !processedMemberIds.contains(memberId)) {
                processedMemberIds.add(memberId);
                
                // Verificăm dacă membrul are locație
                // Dacă nu are, putem simula pentru demo (sau ignorăm)
                // Voi simula pentru demo dacă nu există, ca să vadă userul funcționalitatea
                // În producție, am afișa doar dacă există.
                
                double? lat = member['latitude'];
                double? lng = member['longitude'];
                
                // MOCK: Dacă nu are locație, punem una random lângă București pentru demo
                // DOAR PENTRU DEMO - eliminați în producție
                if (lat == null || lng == null) {
                   // lat = 44.4268 + (0.01 * (processedMemberIds.length));
                   // lng = 26.1025 + (0.01 * (processedMemberIds.length));
                   // Comentat pentru a nu induce în eroare, dar lăsat ca idee.
                   // Voi afișa doar dacă există.
                }

                if (lat != null && lng != null) {
                  allMarkers.add(Marker(
                    point: LatLng(lat, lng),
                    width: 80,
                    height: 80,
                    child: Column(
                      children: [
                        const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            member['name'] ?? 'Membru',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ));
                }
              }
            }
          }
        }
      }

      setState(() {
        _markers = allMarkers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching map data: $e');
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
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}
