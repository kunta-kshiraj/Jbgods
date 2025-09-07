import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/toast.dart';
import '../../app_state.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  LatLng? _current;
  final defaultLatLng = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    // For demo: no real location, just use default
    _current = defaultLatLng;
  }

  @override
  Widget build(BuildContext context) {
    final mockPins = List.generate(
        5,
        (i) => Marker(
              point: LatLng(_current!.latitude + i * 0.01, _current!.longitude + i * 0.01),
              child: Icon(Icons.location_on, color: Colors.red, size: 32),
            ));
    return Scaffold(
      body: Stack(
        children: [
          // Full screen map
          Positioned.fill(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _current!,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(markers: mockPins),
              ],
            ),
          ),
          // Header with logo
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white.withValues(alpha: 0.9),
              child: const HeaderLogo(),
            ),
          ),
          // Share button positioned at bottom right
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: () => _showShareOptions(context),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.share, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Share Location",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            JBButton(
              label: "Share with ADMINS",
              onPressed: () {
                ref.read(appStateProvider.notifier).setShareScope("ADMINS");
                showJBToast(context, "Location shared with ADMINS");
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            JBButton(
              label: "Share with ALL users",
              outline: true,
              onPressed: () {
                ref.read(appStateProvider.notifier).setShareScope("ALL");
                showJBToast(context, "Location shared with ALL users");
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}