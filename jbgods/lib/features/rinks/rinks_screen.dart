import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'rink_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RinksScreen extends StatefulWidget {
  const RinksScreen({super.key});

  @override
  State<RinksScreen> createState() => _RinksScreenState();
}

class _RinksScreenState extends State<RinksScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  double _currentZoom = 4.5;
  static const LatLng _initialCenter = LatLng(39.8283, -98.5795); // Center of US
  bool _hasCentered = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rinksSubscription;
  Map<String, Map<String, dynamic>> _rinkData = {}; // Store rink data for display
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  String? _selectedRinkId;
  bool _showSearchResults = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _currentDocs = [];

  @override
  void initState() {
    super.initState();
    _listenToRinks();
  }

  @override
  void dispose() {
    _rinksSubscription?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToRinks() {
    debugPrint('Starting to listen to rinks collection...');
    _rinksSubscription = FirebaseFirestore.instance
        .collection('rinks')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen((snapshot) {
      debugPrint('Rinks stream update: ${snapshot.docs.length} documents, ${snapshot.docChanges.length} changes');
      for (final change in snapshot.docChanges) {
        debugPrint('Change type: ${change.type}, docId: ${change.doc.id}');
        if (change.type == DocumentChangeType.modified) {
          final data = change.doc.data();
          if (data != null) {
            debugPrint('Modified rink ${change.doc.id}: address=${data['address']}, lat=${data['latitude']}, lng=${data['longitude']}');
          }
        }
      }
      _currentDocs = snapshot.docs;
      _updateMarkersAsync(snapshot.docs);
      _updateSearchResults(); // Update search results when rinks change
    }, onError: (error) {
      debugPrint('Error listening to rinks: $error');
    });
  }

  void _updateSearchResults() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final results = <Map<String, dynamic>>[];
    for (final entry in _rinkData.entries) {
      final rinkName = (entry.value['rinkName'] ?? '').toLowerCase();
      final address = (entry.value['address'] ?? '').toLowerCase();
      
      if (rinkName.contains(query) || address.contains(query)) {
        results.add({
          'id': entry.key,
          ...entry.value,
        });
      }
    }

    setState(() {
      _searchResults = results;
      _showSearchResults = results.isNotEmpty;
    });
  }

  void _navigateToRink(String rinkId) {
    final rinkInfo = _rinkData[rinkId];
    if (rinkInfo == null) return;

    // Find the marker for this rink
    Marker? targetMarker;
    try {
      targetMarker = _markers.firstWhere(
        (m) => m.markerId.value == rinkId,
      );
    } catch (e) {
      debugPrint('Marker not found for rink $rinkId');
      return;
    }

    setState(() {
      _selectedRinkId = rinkId;
      _showSearchResults = false;
      _searchController.clear();
    });

    // Refresh markers to show selected state
    _refreshMarkers();

    if (_mapController != null && targetMarker != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(targetMarker.position, 15.0),
      );
      
      // Show the info window after camera animation
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_mapController != null && mounted) {
          _mapController!.showMarkerInfoWindow(MarkerId(rinkId));
        }
      });
      
      // Show the details bottom sheet
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          _showRinkDetails(rinkId);
        }
      });
    }
  }

  Future<bool> _hasActiveSubscription(String ownerUid) async {
    try {
      final subscriptionDoc = await FirebaseFirestore.instance
          .collection('rink_owner_subscriptions')
          .doc(ownerUid)
          .get();

      if (!subscriptionDoc.exists) {
        return false;
      }

      final data = subscriptionDoc.data()!;
      final status = data['status'] as String?;
      final expiresAt = data['expiresAt'] as Timestamp?;

      if (status != 'active') {
        return false;
      }

      if (expiresAt == null) {
        return false;
      }

      final isExpired = expiresAt.toDate().isBefore(DateTime.now());
      return !isExpired;
    } catch (e) {
      debugPrint('Error checking subscription for $ownerUid: $e');
      return false;
    }
  }

  Future<void> _updateMarkersAsync(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    debugPrint('_updateMarkers called with ${docs.length} rinks');
    final markers = <Marker>{};

    for (final doc in docs) {
      final data = doc.data();
      final address = data['address'] ?? '';
      final rinkName = data['rinkName'] ?? 'Unnamed Rink';
      final latitude = data['latitude'];
      final longitude = data['longitude'];
      final ownerUid = doc.id; // Rink doc ID is the owner UID

      debugPrint('Rink ${doc.id}: name=$rinkName, address=$address, lat=$latitude, lng=$longitude');

      // Use stored coordinates if available, otherwise skip
      if (latitude == null || longitude == null) {
        debugPrint('Rink ${doc.id} missing coordinates, skipping');
        continue;
      }

      // Check if owner has active subscription
      final hasActiveSub = await _hasActiveSubscription(ownerUid);
      if (!hasActiveSub) {
        debugPrint('Rink ${doc.id} owner does not have active subscription, skipping');
        continue;
      }

      try {
        final lat = latitude is double ? latitude : (latitude as num).toDouble();
        final lng = longitude is double ? longitude : (longitude as num).toDouble();
        
        debugPrint('Creating marker for ${doc.id} at ($lat, $lng)');
        
        // Store rink data for display when marker is tapped
        _rinkData[doc.id] = {
          'rinkName': rinkName,
          'address': address,
          'ownerName': data['ownerName'] ?? '',
          'email': data['email'] ?? '',
        };
        
        // Use different color for selected marker
        final isSelected = _selectedRinkId == doc.id;
        markers.add(
          Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: rinkName,
              snippet: address.isNotEmpty ? address : 'Location available',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueRed,
            ),
            onTap: () {
              setState(() => _selectedRinkId = doc.id);
              _showRinkDetails(doc.id);
            },
          ),
        );
      } catch (e) {
        debugPrint('Failed to create marker for rink ${doc.id}: $e');
        continue;
      }
    }

    debugPrint('Total markers created: ${markers.length}');

    if (mounted) {
      // Force marker update by clearing and setting new markers
      // This ensures Google Maps updates marker positions even if marker IDs are the same
      setState(() {
        _markers = markers;
      });
      
      debugPrint('Markers updated in state, current marker count: ${_markers.length}');
      
      // Center map on markers only once when first loaded
      if (markers.isNotEmpty && _mapController != null && !_hasCentered) {
        _hasCentered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerMapOnMarkers(markers);
        });
      }
    }
  }

  void _refreshMarkers() {
    // Force refresh markers to update selected state
    if (_currentDocs.isNotEmpty) {
      _updateMarkersAsync(_currentDocs);
    }
  }

  void _centerMapOnMarkers(Set<Marker> markers) {
    if (_mapController == null || markers.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    // Calculate appropriate zoom level based on bounds
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
    
    double zoom = 4.5;
    if (maxDiff < 0.1) zoom = 10;
    else if (maxDiff < 0.5) zoom = 8;
    else if (maxDiff < 1.0) zoom = 6;
    else if (maxDiff < 5.0) zoom = 5;

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(center, zoom),
    );
  }

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

  void _showRinkDetails(String rinkId) async {
  final rinkInfo = _rinkData[rinkId];
  if (rinkInfo == null) return;

  // Fetch the rink document
  final rinkDoc = await FirebaseFirestore.instance.collection('rinks').doc(rinkId).get();
  final ownerUid = rinkDoc.id; // assuming rink doc ID = owner UID

  // Check if the owner still exists
  final ownerExists = await FirebaseFirestore.instance
      .collection('users')
      .doc(ownerUid)
      .get()
      .then((doc) => doc.exists);

  // Check if the current user is master
  final currentUser = FirebaseAuth.instance.currentUser;
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser?.uid)
      .get();
  final userRole = userDoc.data()?['role'] ?? 'member';
  final isMaster = userRole == 'master';

  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final iconColor = isDark ? Colors.white70 : Colors.grey[600];
  final labelColor = isDark ? Colors.white70 : Colors.grey[600];

  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Rink name
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rinkInfo['rinkName'] ?? 'Unnamed Rink',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              // Delete icon for masters only
              if (isMaster)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          'Delete Rink',
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        ),
                        backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
                        content: Text(
                          'Are you sure you want to delete this rink? This action cannot be undone.',
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(
                              'Cancel',
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    try {
                      await FirebaseFirestore.instance
                          .collection('rinks')
                          .doc(rinkId)
                          .delete();

                      if (mounted) {
                        Navigator.pop(context); // close bottom sheet
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Rink deleted successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to delete rink: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'Delete rink',
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Address:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rinkInfo['address']?.isNotEmpty == true
                          ? rinkInfo['address']!
                          : 'Address not available',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (rinkInfo['ownerName']?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Owner:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rinkInfo['ownerName']!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skating Rinks'),
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
              // Center map on markers once map is ready (only if not already centered)
              if (_markers.isNotEmpty && !_hasCentered) {
                _hasCentered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _centerMapOnMarkers(_markers);
                });
              }
            },
            markers: _markers,
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
          ),
          // Search Bar
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Search rinks by name or address...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _updateSearchResults();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (_) => _updateSearchResults(),
                onSubmitted: (_) {
                  if (_searchResults.isNotEmpty) {
                    _navigateToRink(_searchResults.first['id']);
                  }
                },
              ),
            ),
          ),
          // Search Results List
          if (_showSearchResults)
            Positioned(
              top: 70,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final rink = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.red),
                      title: Text(
                        rink['rinkName'] ?? 'Unnamed Rink',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        rink['address'] ?? 'Address not available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      onTap: () => _navigateToRink(rink['id']),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            bottom: 20,
            right: 15,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomIn",
                  mini: true,
                  onPressed: _zoomIn,
                  backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
                  child: Icon(
                    Icons.add,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOut",
                  mini: true,
                  onPressed: _zoomOut,
                  backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
                  child: Icon(
                    Icons.remove,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          // Skating Rinks List — floating pill, centered above bottom nav
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Center(
              child: Material(
                color: isDark ? theme.colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(999),
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.2),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RinkListScreen()),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.list_alt,
                          size: 22,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Skating Rinks List',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
