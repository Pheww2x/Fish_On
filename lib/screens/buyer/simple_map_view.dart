import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:location/location.dart';
import '../../services/firestore_service.dart';
import 'fisherman_profile.dart';
import 'search_fish.dart';

class SimpleMapViewScreen extends StatefulWidget {
  const SimpleMapViewScreen({super.key});
  @override
  State<SimpleMapViewScreen> createState() => _SimpleMapViewScreenState();
}

class _SimpleMapViewScreenState extends State<SimpleMapViewScreen> {
  final FirestoreService _fs = FirestoreService();
  final Location _location = Location();
  
  final List<Marker> _markers = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription? _fishermenSub;
  ll.LatLng? _buyerLocation;
  String _locationName = 'Biliran Island';
  ll.LatLng _center = const ll.LatLng(11.54, 124.52);
  
  final LatLngBounds _biliranBounds = LatLngBounds.fromPoints([
    const ll.LatLng(11.38, 124.27), // SW approx
    const ll.LatLng(11.72, 124.76), // NE approx
  ]);

  @override
  void initState() {
    super.initState();
    _getBuyerLocation();
    _listenFishermen();
    
    // Safety timeout
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
      }
    });
  }

  void _listenFishermen() {
    _fishermenSub = _fs.streamVisibleFishermen().listen(
      (list) {
        if (!mounted) return;
        
        final newMarkers = <Marker>[];
        for (var f in list) {
          if (f.location == null) continue;
          
          final marker = Marker(
            point: ll.LatLng(f.location!.latitude, f.location!.longitude),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FishermanProfileScreen(fishermanId: f.uid),
                ),
              ),
              child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            ),
          );
          newMarkers.add(marker);
        }
        
        if (mounted) {
          setState(() {
            _markers.clear();
            _markers.addAll(newMarkers);
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = error.toString();
          });
        }
      },
    );
  }

  Future<void> _getBuyerLocation() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      
      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      
      if (permission == PermissionStatus.granted && serviceEnabled) {
        final locationData = await _location.getLocation();
        if (locationData.latitude != null && locationData.longitude != null) {
          final buyerPos = ll.LatLng(locationData.latitude!, locationData.longitude!);
          
          if (mounted) {
            setState(() {
              _buyerLocation = buyerPos;
              _center = buyerPos;
              _locationName = _getLocationName(buyerPos);
            });
          }
        }
      }
    } catch (e) {
      // Handle location error silently
    }
  }

  String _getLocationName(ll.LatLng position) {
    double lat = position.latitude;
    double lng = position.longitude;
    
    if (lat >= 11.45 && lat <= 11.65 && lng >= 124.45 && lng <= 124.65) {
      if (lat >= 11.55 && lng >= 124.50) return 'Naval, Biliran';
      if (lat >= 11.50 && lng <= 124.50) return 'Caibiran, Biliran';
      if (lat <= 11.50 && lng >= 124.55) return 'Almeria, Biliran';
      if (lat <= 11.45) return 'Kawayan, Biliran';
      return 'Maripipi, Biliran';
    }
    
    return 'Your Location';
  }

  @override
  void dispose() {
    _fishermenSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1565C0),
                    Color(0xFF1976D2),
                    Color(0xFF42A5F5),
                    Color(0xFF90CAF9),
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading fishermen locations...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _error != null
              ? Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF0D47A1),
                        Color(0xFF1565C0),
                        Color(0xFF1976D2),
                        Color(0xFF42A5F5),
                        Color(0xFF90CAF9),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.white),
                        const SizedBox(height: 24),
                        const Text(
                          'Unable to load map',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error: $_error',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _listenFishermen();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    // Simple Map without MapController
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _buyerLocation != null ? 14.0 : 11.0,
                        minZoom: 9,
                        maxZoom: 18,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: _biliranBounds,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.fishon',
                        ),
                        MarkerLayer(
                          markers: [
                            ..._markers,
                            if (_buyerLocation != null)
                              Marker(
                                point: _buyerLocation!,
                                width: 40,
                                height: 40,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: const Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Back Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  tooltip: 'Back to dashboard',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _locationName,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${_markers.length} fishermen available',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Search Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const SearchFishScreen()),
                                  ),
                                  icon: Icon(
                                    Icons.search,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  tooltip: 'Search fish',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom Info
                    if (_markers.isNotEmpty)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          child: Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.info_outline,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Tap any marker to view fisherman',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Red pins show active fishermen with fresh catch',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}