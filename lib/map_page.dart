import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
  
  LatLng? _myLocation;
  bool _isLoading = true;
  StreamSubscription<LocationData>? _locationSubscription;

  @override
  void initState() {
    super.initState();
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

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled;
      PermissionStatus permissionGranted;

      serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          // Service disabled, show default location
          if (mounted) {
            setState(() {
              _myLocation = const LatLng(44.4268, 26.1025); // Bucharest default
              _isLoading = false;
            });
          }
          return;
        }
      }

      permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          // Permission denied, show default location
          if (mounted) {
            setState(() {
              _myLocation = const LatLng(44.4268, 26.1025); // Bucharest default
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Get current location
      final locationData = await _location.getLocation();
      if (mounted) {
        setState(() {
          _myLocation = LatLng(locationData.latitude!, locationData.longitude!);
          _isLoading = false;
        });
        _mapController.move(_myLocation!, 15);
      }

      // Listen for updates
      _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          setState(() {
            _myLocation = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          });
          
          // Send update to server
          _sendLocationUpdate(currentLocation.latitude!, currentLocation.longitude!);
        }
      });
    } catch (e) {
      print('Error initializing location: $e');
      // On error, show default location
      if (mounted) {
        setState(() {
          _myLocation = const LatLng(44.4268, 26.1025); // Bucharest default
          _isLoading = false;
        });
      }
    }
  }

  void _setupSocketListeners() {
    _socketService.socket?.on('member_location_updated', (data) {
      if (mounted) {
        setState(() {
          final userId = data['userId'];
          _memberLocations[userId] = {
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'userId': userId,
            // Putem adăuga nume dacă vine din socket sau îl luăm din altă parte
            'name': data['name'] ?? 'Membru', 
          };
        });
      }
    });
  }

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
          
          // For each workspace, fetch member locations and join the room
          for (var ws in workspaces) {
            final workspaceId = ws['id'];
            
            // Join workspace socket room
            _socketService.socket?.emit('join_workspace', workspaceId);
            
            // Fetch member locations
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
                  ],
                ),
              ],
            ),
    );
  }
}
