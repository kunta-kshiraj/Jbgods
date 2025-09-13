import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../widgets/header_logo.dart';
import '../../widgets/jb_button.dart';
import '../../widgets/toast.dart';
import '../../data/auth_providers.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _map = MapController();
  double _zoom = 13;
  LatLng? _center;

  // For demo we’ll use a static position.
  static const LatLng _demoStart = LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _center = _demoStart;
  }

  Future<void> _setShareScope(String? scope) async {
    final fs = ref.read(firestoreProvider);
    final me = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider);

    if (me == null) return;

    final doc = fs.collection('userLocations').doc(me.uid);

    if (scope == null) {
      // stop sharing
      await doc.delete();
      if (mounted) showJBToast(context, "Stopped sharing location");
      return;
    }

    // share with ADMINS or ALL
    final lat = _center!.latitude;
    final lng = _center!.longitude;

    await doc.set({
      'uid': me.uid,
      'username': (profile?['username'] ?? ''),
      'lat': lat,
      'lng': lng,
      'shareScope': scope, // "ADMINS" | "ALL"
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) {
      showJBToast(
        context,
        scope == "ALL" ? "Location shared with ALL users" : "Location shared with ADMINS",
      );
    }
  }

  void _showShareOptions({required String? currentScope}) {
    // currentScope is null, "ADMINS", or "ALL"
    showModalBottomSheet(
      context: context,
      builder: (_) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Share Location",
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              if (currentScope == null) ...[
                JBButton(
                  label: "Share with ADMINS",
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope("ADMINS");
                  },
                ),
                const SizedBox(height: 12),
                JBButton(
                  label: "Share with ALL users",
                  outline: true,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope("ALL");
                  },
                ),
              ] else if (currentScope == "ADMINS") ...[
                JBButton(
                  label: "Stop sharing",
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope(null);
                  },
                ),
                const SizedBox(height: 12),
                JBButton(
                  label: "Share with ALL users",
                  outline: true,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope("ALL");
                  },
                ),
              ] else if (currentScope == "ALL") ...[
                JBButton(
                  label: "Stop sharing",
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope(null);
                  },
                ),
                const SizedBox(height: 12),
                JBButton(
                  label: "Share with ADMINS",
                  outline: true,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _setShareScope("ADMINS");
                  },
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = ref.watch(firestoreProvider);
    final role = ref.watch(userRoleProvider);
    final me = ref.watch(currentUserProvider);

    // Stream: my own location doc (to know what to show in the share sheet)
    final myLocationStream = me == null
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>?>.empty()
        : fs.collection('userLocations').doc(me.uid).snapshots();

    // Stream: markers to show (admins see ALL, members see only shareScope == ALL)
    final markersStream = (role == 'admin' || role == 'master')
        ? fs.collection('userLocations').snapshots()
        : fs.collection('userLocations').where('shareScope', isEqualTo: 'ALL').snapshots();

    return Scaffold(
      body: Stack(
        children: [
          // Map
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center!,
                initialZoom: _zoom,
                onMapEvent: (e) {
                  if (e.camera.center != null) {
                    _center = e.camera.center!;
                  }
                  _zoom = e.camera.zoom;
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: NetworkTileProvider(),
                ),

                // All shared markers
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: markersStream,
                  builder: (_, snap) {
                    if (!snap.hasData) return const MarkerLayer(markers: []);
                    final markers = <Marker>[];
                    for (final d in snap.data!.docs) {
                      final data = d.data();
                      final lat = (data['lat'] as num?)?.toDouble();
                      final lng = (data['lng'] as num?)?.toDouble();
                      if (lat == null || lng == null) continue;
                      markers.add(
                        Marker(
                          point: LatLng(lat, lng),
                          width: 36,
                          height: 36,
                          child: const Icon(Icons.location_on, size: 32, color: Colors.red),
                        ),
                      );
                    }
                    return MarkerLayer(markers: markers);
                  },
                ),
              ],
            ),
          ),

          // Header with logo (semi-transparent bg)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
              child: const HeaderLogo(),
            ),
          ),

          // Zoom controls
          Positioned(
            right: 20,
            bottom: 180,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    _zoom = (_zoom + 1).clamp(1.0, 19.0);
                    _map.move(_center!, _zoom);
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    _zoom = (_zoom - 1).clamp(1.0, 19.0);
                    _map.move(_center!, _zoom);
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Share / Stop / Switch button
          Positioned(
            bottom: 100,
            right: 20,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: myLocationStream,
              builder: (context, snap) {
                final myScope = (snap.data?.data()?['shareScope'] as String?);
                return FloatingActionButton.extended(
                  heroTag: 'share_toggle',
                  onPressed: () => _showShareOptions(currentScope: myScope),
                  icon: const Icon(Icons.share),
                  label: Text(
                    myScope == null
                        ? 'Share'
                        : (myScope == "ALL" ? 'Sharing: ALL' : 'Sharing: ADMINS'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
