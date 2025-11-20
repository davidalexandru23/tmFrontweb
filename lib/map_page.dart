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
    _initLocation();
    _setupSocketListeners();
    _fetchInitialLocations();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _socketService.socket?.off('member_location_updated');
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
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
    // Fetch locations of members in my workspaces
    // Deoarece nu avem un endpoint dedicat "get all members locations" care să returneze tot,
    // putem folosi endpoint-ul de task locations sau să iterăm prin workspace-uri.
    // Pentru simplitate, ne bazăm pe socket updates și poate un endpoint nou dacă e critic.
    // Dar utilizatorul a cerut "sa vad membrii din grup live pe harti".
    // Putem face un request la /users/locations dacă ar exista, sau /workspaces/:id/members
    // Momentan, ne bazăm pe faptul că userii trimit locația când intră.
    
    // Putem implementa un "request_locations" pe socket?
    // Sau un endpoint GET /workspaces/members/locations
    
    // Implementare simplă: doar socket updates pentru "live".
  }

  void _sendLocationUpdate(double lat, double long) async {
    // Get user ID from storage or context?
    // We need userId. Let's fetch 'me' first or store it.
    try {
      final userResponse = await _apiClient.get('/users/me');
      if (userResponse.statusCode == 200) {
        final user = jsonDecode(userResponse.body);
        final userId = user['id'];
        
        // Send to all workspaces I am in?
        // Or just send to server and server broadcasts to my workspaces.
        // Server implementation:
        // socket.on('update_location', ... broadcasts to workspace_...
        
        // We need to join workspace rooms first!
        // Let's fetch workspaces and join rooms.
        final workspacesResponse = await _apiClient.get('/workspaces');
        if (workspacesResponse.statusCode == 200) {
           final workspaces = jsonDecode(workspacesResponse.body) as List;
           for (var ws in workspaces) {
             _socketService.socket?.emit('join_workspace', ws['id']);
             
             // Send update
             _socketService.socket?.emit('update_location', {
               'userId': userId,
               'latitude': lat,
               'longitude': long,
               'workspaceId': ws['id'], // Send for each workspace or server handles multiple?
               // Server implementation handles one workspaceId per event currently.
               // Ideally server should look up user's workspaces.
               // But for now, we emit for each workspace.
             });
           }
        }
      }
    } catch (e) {
      print('Error sending location update: $e');
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
