import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:task_manager_app/socket_service.dart';
import 'package:task_manager_app/api_client.dart';
import 'package:task_manager_app/notification_service.dart'; // Added import
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

  // Initialize map in correct order with safeguards
  Future<void> _initializeMap() async {
    try {
      // 1. Setup listeners immediately
      _setupSocketListeners();
      
      // 2. Get user/workspace info (critical)
      await _initializeUserAndWorkspaces();

      // 3. Start fetching other data in parallel
      // Don't await _initLocation strictly if it takes too long
      _initLocation().then((_) => print('Location initialized')).catchError((e) => print('Location init error: $e'));
      
      // 4. Fetch markers (members/tasks)
      await _fetchInitialLocations();

    } catch (e) {
      print('Map initialization error: $e');
    } finally {
      // Always stop loading after a short delay to ensure UI shows up
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initLocation() async {
    try {
      print('Initializing location...');
      
      // Web specific handling or skip
      if (kIsWeb) {
        // On web, we just try to get the location once
        final locationData = await _location.getLocation().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
             print('Web location timeout');
             throw Exception('Web location timeout');
          },
        );
        _updateLocation(locationData);
        return;
      }

      // Mobile handling
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print('Location service disabled');
          return;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print('Location permission denied');
          return;
        }
      }

      // Get current location
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
           print('Mobile location timeout');
           throw Exception('Mobile location timeout');
        }
      );
      _updateLocation(locationData);

      // Listen for updates
      _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
        _updateLocation(currentLocation);
      });

    } catch (e) {
      print('Error initializing location: $e');
      // Fallback to default if we haven't set a location yet
      if (_myLocation == null && mounted) {
         setState(() {
           _myLocation = const LatLng(44.4268, 26.1025); // Bucharest
         });
      }
    }
  }

  void _updateLocation(LocationData data) {
    if (data.latitude != null && data.longitude != null) {
      if (mounted) {
        setState(() {
          _myLocation = LatLng(data.latitude!, data.longitude!);
        });
        // Move map only on first update or if tracking is enabled (optional)
        // _mapController.move(_myLocation!, 15); 
        
        _sendLocationUpdate(data.latitude!, data.longitude!);
      }
    }
  }

  void _setupSocketListeners() {
    _socketService.socket?.on('member_location_updated', (data) {
      print('Member location updated: $data');
      if (mounted) {
        setState(() {
          final userId = data['userId'];
          if (userId != null) {
            _memberLocations[userId] = {
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'userId': userId,
              'name': data['name'] ?? 'Membru', 
            };
          }
        });
      }
    });
  }

  Future<void> _fetchInitialLocations() async {
    try {
      print('Fetching initial locations...');
      // ... existing logic for fetching members ...
      // We'll reuse the existing logic but add logging
      
      // Get user ID first if not already set
      if (_currentUserId == null) {
         final userResponse = await _apiClient.get('/users/me');
         if (userResponse.statusCode == 200) {
           final user = jsonDecode(userResponse.body);
           _currentUserId = user['id'];
         }
      }
      
      // Get workspaces if not already set
      if (_workspaceIds.isEmpty) {
        final workspacesResponse = await _apiClient.get('/workspaces');
        if (workspacesResponse.statusCode == 200) {
          final workspaces = jsonDecode(workspacesResponse.body) as List;
          _workspaceIds = workspaces.map((ws) => ws['id'] as String).toList();
        }
      }

      for (var workspaceId in _workspaceIds) {
        print('Fetching data for workspace: $workspaceId');
        
        // Join room
        _socketService.socket?.emit('join_workspace', workspaceId);

        // 1. Members
        try {
          final locationsResponse = await _apiClient.get('/locations/workspaces/$workspaceId/members');
          if (locationsResponse.statusCode == 200) {
            final locations = jsonDecode(locationsResponse.body) as List;
            print('Received ${locations.length} member locations');
            if (mounted) {
              setState(() {
                for (var loc in locations) {
                  if (loc['userId'] != _currentUserId) {
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
        } catch (e) {
          print('Error fetching member locations: $e');
        }

        // 2. Tasks
        try {
          final tasksResponse = await _apiClient.get('/tasks/workspace/$workspaceId');
          if (tasksResponse.statusCode == 200) {
             final tasks = jsonDecode(tasksResponse.body) as List;
             print('Received ${tasks.length} tasks for workspace $workspaceId');
             
             if (mounted) {
               setState(() {
                 for (var task in tasks) {
                   // Log task location data
                   // print('Task ${task['title']}: ${task['latitude']}, ${task['longitude']}');
                   
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
        } catch (e) {
          print('Error fetching tasks: $e');
        }
      }
    } catch (e) {
      print('Error in _fetchInitialLocations: $e');
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
