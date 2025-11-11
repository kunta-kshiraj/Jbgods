import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RinksScreen extends StatefulWidget {
  const RinksScreen({super.key});

  @override
  State<RinksScreen> createState() => _RinksScreenState();
}

class _RinksScreenState extends State<RinksScreen> {
  GoogleMapController? _mapController;

  static const LatLng _initialCenter = LatLng(39.8283, -98.5795); // Center of US
  double _currentZoom = 4.5;

  void _zoomIn() {
    if (_mapController != null) {
      setState(() => _currentZoom += 1);
      _mapController!.animateCamera(CameraUpdate.zoomTo(_currentZoom));
    }
  }

  void _zoomOut() {
    if (_mapController != null) {
      setState(() => _currentZoom -= 1);
      _mapController!.animateCamera(CameraUpdate.zoomTo(_currentZoom));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skating Rinks'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: _currentZoom,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            zoomControlsEnabled: false,   // disable built-in zoom controls
            myLocationEnabled: false,     // ✅ disable the blue location button
            myLocationButtonEnabled: false, // ✅ remove that "target" button
          ),

          // Custom zoom buttons
          Positioned(
            bottom: 20,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
