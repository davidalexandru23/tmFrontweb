import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

class LocationPickerDialog extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const LocationPickerDialog({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  late LatLng _selectedLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(widget.initialLat, widget.initialLng);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: Colors.black,
            title: Text(
              'Selectează Locația',
              style: GoogleFonts.robotoSlab(color: Colors.red),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.red),
                onPressed: () {
                  Navigator.pop(context, {
                    'lat': _selectedLocation.latitude,
                    'lng': _selectedLocation.longitude,
                  });
                },
              ),
            ],
          ),
          SizedBox(
            height: 400,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _selectedLocation,
                initialZoom: 13.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.task_manager_app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Lat: ${_selectedLocation.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation.longitude.toStringAsFixed(4)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
