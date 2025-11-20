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
  
  // Store workspaces and userId to avoid repeated fetching
  String? _currentUserId;
  List<String> _workspaceIds = [];

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
      _log('Starting map initialization...');
      // 1. Setup listeners immediately
      _setupSocketListeners();
      
      // 2. Get user/workspace info (critical)
      await _initializeUserAndWorkspaces();

      // 3. Start fetching other data in parallel
      // Don't await _initLocation strictly if it takes too long
      _initLocation().then((_) => _log('Location initialized')).catchError((e) => _log('Location init error: $e'));
      
      // 4. Fetch markers (members/tasks)
      await _fetchInitialLocations();

    } catch (e) {
      _log('Map initialization error: $e');
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
      _log('Initializing location...');
      
      // Web specific handling or skip
      if (kIsWeb) {
        _log('Running on Web. Attempting single location request...');
        // On web, we just try to get the location once
        final locationData = await _location.getLocation().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
             _log('Web location timeout');
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
          _log('Location service disabled');
          return;
        }
      }

      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          _log('Location permission denied');
          return;
        }
      }

      // Get current location
      final locationData = await _location.getLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
           _log('Mobile location timeout');
           throw Exception('Mobile location timeout');
        }
      );
      _updateLocation(locationData);

      // Listen for updates
      _locationSubscription = _location.onLocationChanged.listen((LocationData currentLocation) {
        _updateLocation(currentLocation);
      });

    } catch (e) {
      _log('Error initializing location: $e');
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
        
        _sendLocationUpdate(data.latitude!, data.longitude!);
      }
    }
  }

  void _sendLocationUpdate(double lat, double lng) {
    // Send to all workspaces
    for (var wsId in _workspaceIds) {
      _socketService.socket?.emit('update_location', {
        'userId': _currentUserId,
        'latitude': lat,
        'longitude': lng,
        'workspaceId': wsId,
      });
    }
  }

  void _setupSocketListeners() {
    _socketService.socket?.on('member_location_updated', (data) {
      _log('Member location updated: $data');
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

  Future<void> _fetchInitialLocations() async {
    try {
      _log('Fetching initial locations...');
      
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
        _log('Fetching data for workspace: $workspaceId');
        
        // Join room
        _socketService.socket?.emit('join_workspace', workspaceId);

        // 1. Members
        try {
          final locationsResponse = await _apiClient.get('/locations/workspaces/$workspaceId/members');
          if (locationsResponse.statusCode == 200) {
            final locations = jsonDecode(locationsResponse.body) as List;
            _log('Received ${locations.length} member locations');
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
          _log('Error fetching member locations: $e');
        }

        // 2. Tasks
        try {
          final tasksResponse = await _apiClient.get('/tasks/workspace/$workspaceId');
          if (tasksResponse.statusCode == 200) {
             final tasks = jsonDecode(tasksResponse.body) as List;
             _log('Received ${tasks.length} tasks for workspace $workspaceId');
             
             if (mounted) {
               setState(() {
                 for (var task in tasks) {
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
          _log('Error fetching tasks: $e');
        }
      }
    } catch (e) {
      _log('Error in _fetchInitialLocations: $e');
    }
  }



  // Debug logs list
  final List<String> _debugLogs = [];

  void _log(String message) {
    print(message);
    if (mounted) {
      setState(() {
        _debugLogs.add("${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $message");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Harta Echipei', style: GoogleFonts.robotoSlab(color: Colors.red)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.red),
        actions: [
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Debug Logs"),
                    content: SizedBox(
                      width: double.maxFinite,
                      height: 300,
                      child: ListView.builder(
                        itemCount: _debugLogs.length,
                        itemBuilder: (context, index) => Text(_debugLogs[index]),
                      ),
                    ),
                  ),
                );
              },
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation ?? const LatLng(44.4268, 26.1025), // Default Bucharest
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              MarkerLayer(
                markers: [
                  // My Location Marker
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 80,
                      height: 80,
                      child: const Column(
                        children: [
                          Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                          Text('Eu', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  
                  // Member Markers
                  ..._memberLocations.values.map((member) {
                    return Marker(
                      point: LatLng(member['latitude'], member['longitude']),
                      width: 80,
                      height: 80,
                      child: Column(
                        children: [
                          const Icon(Icons.person, color: Colors.blue, size: 30),
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              member['name'] ?? 'Unknown',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Task Markers
                  ..._taskLocations.values.map((task) {
                    return Marker(
                      point: LatLng(task['latitude'], task['longitude']),
                      width: 100,
                      height: 100,
                      child: GestureDetector(
                        onTap: () {
                           showDialog(
                             context: context,
                             builder: (context) => AlertDialog(
                               title: Text(task['title']),
                               content: Text("Status: ${task['status']}"),
                             ),
                           );
                        },
                        child: Column(
                          children: [
                            const Icon(Icons.assignment_turned_in, color: Colors.orange, size: 30),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                task['title'] ?? 'Task',
                                style: const TextStyle(color: Colors.orange, fontSize: 10),
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
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 16),
                    const Text("Se încarcă harta...", style: TextStyle(color: Colors.white)),
                    const SizedBox(height: 8),
                    // Show last log
                    if (_debugLogs.isNotEmpty)
                      Text(
                        _debugLogs.last,
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
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
