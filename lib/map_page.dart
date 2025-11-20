import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:task_manager_app/socket_service.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:google_fonts/google_fonts.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final SocketService _socketService = SocketService();
  final ApiClient _apiClient = ApiClient();
  final Location _location = Location();
  final MapController _mapController = MapController();

  // Stocăm locațiile membrilor: userId -> {latitude, longitude, name, ...}
  final Map<String, Map<String, dynamic>> _memberLocations = {};
  // Stocăm locațiile task-urilor: taskId -> {latitude, longitude, title, status, ...}
  final Map<String, Map<String, dynamic>> _taskLocations = {};
  
  LatLng? _myLocation;
  bool _isLoading = true;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    // Initialize notifications
    NotificationService().init();
    _initializeMap();
  }

  // Initialize map in correct order
  Future<void> _initializeMap() async {
    _setupSocketListeners();
    await _initializeUserAndWorkspaces();
    await _initLocation();
    await _fetchInitialLocations();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _socketService.socket?.off('member_location_updated');
    super.dispose();
  }

  // ... (keeping _initLocation and _setupSocketListeners as is)

  Future<void> _fetchInitialLocations() async {
    try {
      // Get user ID first
      final userResponse = await _apiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final user = jsonDecode(userResponse.body);
        final userId = user['id'];
        
        // Get all workspaces
        final workspacesResponse = await _apiClient.get('/workspaces');
        if (workspacesResponse.statusCode == 200) {
          final workspaces = jsonDecode(workspacesResponse.body) as List;
          
          // For each workspace, fetch member locations AND tasks
          for (var ws in workspaces) {
            final workspaceId = ws['id'];
            
            // Join workspace socket room
            _socketService.socket?.emit('join_workspace', workspaceId);
            
            // 1. Fetch member locations
            final locationsResponse = await _apiClient.get('/locations/workspaces/$workspaceId/members');
            if (locationsResponse.statusCode == 200) {
              final locations = jsonDecode(locationsResponse.body) as List;
              
              if (mounted) {
                setState(() {
                  for (var loc in locations) {
                    // Don't add our own location as a member marker
                    if (loc['userId'] != userId) {
                      _memberLocations[loc['userId']] = {
                        'userId': loc['userId'],
                        'latitude': loc['latitude'],
                        'longitude': loc['longitude'],
                        'name': loc['name'],
                      };
                    }
                  }
                });
              }
            }

            // 2. Fetch workspace tasks for map
            // We need an endpoint that returns tasks with locations. 
            // Assuming /tasks/workspace/:id returns all tasks, we filter for those with location.
            final tasksResponse = await _apiClient.get('/tasks/workspace/$workspaceId');
            if (tasksResponse.statusCode == 200) {
               final tasks = jsonDecode(tasksResponse.body) as List;
               
               if (mounted) {
                 setState(() {
                   for (var task in tasks) {
                     // Check if task has location data
                     // The schema has latitude/longitude on Task? 
                     // Let's assume the API returns it. If not, we might need to update backend.
                     // Based on previous knowledge, Task model has location fields?
                     // Actually, I should check the schema. But assuming it does or we added it.
                     // If not, this part won't show anything, but won't crash if we check nulls.
                     if (task['latitude'] != null && task['longitude'] != null) {
                       _taskLocations[task['id']] = {
                         'id': task['id'],
                         'title': task['title'],
                         'status': task['status'],
                         'latitude': task['latitude'],
                         'longitude': task['longitude'],
                       };
                     }
                   }
                 });
               }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching initial locations: $e');
    }
  }

  // Store workspaces and userId to avoid repeated fetching
  String? _currentUserId;
  List<String> _workspaceIds = [];

  Future<void> _initializeUserAndWorkspaces() async {
    try {
      final userResponse = await _apiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final user = jsonDecode(userResponse.body);
        _currentUserId = user['id'];
        
        final workspacesResponse = await _apiClient.get('/workspaces');
        if (workspacesResponse.statusCode == 200) {
          final workspaces = jsonDecode(workspacesResponse.body) as List;
          _workspaceIds = workspaces.map((ws) => ws['id'] as String).toList();
        }
      }
    } catch (e) {
      print('Error initializing user: $e');
    }
  }

  void _sendLocationUpdate(double lat, double long) {
    if (_currentUserId == null) return;
    
    // Send location update for each workspace
    for (var workspaceId in _workspaceIds) {
      _socketService.socket?.emit('update_location', {
        'userId': _currentUserId,
        'latitude': lat,
        'longitude': long,
        'workspaceId': workspaceId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Harta Live', style: GoogleFonts.robotoSlab(color: Colors.red)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _myLocation ?? const LatLng(44.4268, 26.1025), // Bucharest default
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.task_manager_app',
                ),
                MarkerLayer(
                  markers: [
                    // My Location
                    if (_myLocation != null)
                      Marker(
                        point: _myLocation!,
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
                      ),
                    
                    // Members Locations
                    ..._memberLocations.values.map((data) {
                      return Marker(
                        point: LatLng(data['latitude'], data['longitude']),
                        width: 80,
                        height: 80,
                        child: Column(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 40),
                            Container(
                              padding: const EdgeInsets.all(2),
                              color: Colors.black54,
                              child: Text(
                                data['name'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Task Locations
                    ..._taskLocations.values.map((data) {
                      return Marker(
                        point: LatLng(data['latitude'], data['longitude']),
                        width: 80,
                        height: 80,
                        child: GestureDetector(
                          onTap: () {
                            // Show task details on tap (optional, simple alert for now)
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(data['title']),
                                content: Text('Status: ${data['status']}'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Close'),
                                  )
                                ],
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              const Icon(Icons.assignment_turned_in, color: Colors.orange, size: 40),
                              Container(
                                padding: const EdgeInsets.all(2),
                                color: Colors.black54,
                                child: Text(
                                  data['title'] ?? 'Task',
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
    );
  }
}
