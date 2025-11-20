import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:location/location.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../auth/login.dart';
import 'fisherman_profile.dart';
import 'search_fish.dart';
import '../tutorial/tutorial_screen.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});
  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final FirestoreService _fs = FirestoreService();
  final Location _location = Location();
  bool _isDisposed = false;

  final Map<String, Marker> _markers = {};
  bool _isLoading = true;
  String? _error;
  bool _hasLocationPermission = false;
  bool _isLoggingOut = false;
  StreamSubscription? _fishermenSub;
  ll.LatLng? _buyerLocation;
  Marker? _buyerMarker;
  String _locationName = 'Biliran Island';
  // Biliran Island, Philippines (default center)
  ll.LatLng _center = const ll.LatLng(11.54, 124.52);
  Key _mapKey = UniqueKey();
  final LatLngBounds _biliranBounds = LatLngBounds.fromPoints([
    const ll.LatLng(11.38, 124.27), // SW approx
    const ll.LatLng(11.72, 124.76), // NE approx
  ]);

  @override
  void initState() {
    super.initState();
    _ensureLocationPermission();
    _getBuyerLocation();
    _listenFishermen();
    // Safety timeout so the UI never hangs on loading forever
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_isLoading) setState(() => _isLoading = false);
    });
  }

  void _listenFishermen() {
    print('Starting to listen for fishermen...'); // Debug print
    _fishermenSub = _fs.streamVisibleFishermen().listen(
      (list) {
        print('Received ${list.length} fishermen'); // Debug print
        if (!mounted) return;
        
        _markers.clear();
        for (var f in list) {
          if (f.location == null) {
            print('Fisherman ${f.name} has no location'); // Debug print
            continue;
          }
          print('Fisherman ${f.name} photoUrl: ${f.photoUrl}'); // Debug print
          final id = f.uid;
          
          // Get fisherman position
          var fishermanLat = f.location!.latitude;
          var fishermanLng = f.location!.longitude;
          
          // If buyer location exists and is very close to fisherman, offset the fisherman marker slightly
          if (_buyerLocation != null) {
            final distance = _calculateDistance(
              _buyerLocation!.latitude,
              _buyerLocation!.longitude,
              fishermanLat,
              fishermanLng,
            );
            
            // If within 50 meters, offset the fisherman marker slightly to the right
            if (distance < 0.0005) { // approximately 50 meters
              fishermanLng += 0.0003; // Small offset to the east
              print('Offsetting fisherman ${f.name} marker to prevent overlap');
            }
          }
          
          final marker = Marker(
            point: ll.LatLng(fishermanLat, fishermanLng),
            width: 70,
            height: 80,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FishermanProfileScreen(fishermanId: f.uid),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: f.photoUrl != null && f.photoUrl!.isNotEmpty
                          ? _buildProfileImage(f.photoUrl!)
                          : Container(
                              color: const Color(0xFF4CAF50),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Text(
                      '🎣',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
          _markers[id] = marker;
        }
        setState(() {
          _isLoading = false;
        });
      },
      onError: (error) {
        print('Error listening to fishermen: $error'); // Debug print
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _error = error.toString();
        });
      },
    );
  }

  Future<void> _getBuyerLocation() async {
    try {
      print('Getting buyer location...'); // Debug
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
          
          if (!mounted) return;
          setState(() {
            _buyerLocation = buyerPos;
            _center = buyerPos;
            _locationName = _getLocationName(buyerPos);
            _mapKey = UniqueKey(); // Force map to rebuild with new center
            _buyerMarker = Marker(
              point: buyerPos,
              width: 50,
              height: 60,
              alignment: Alignment.topCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
            _hasLocationPermission = true;
          });
          
          print('Buyer location set to: ${buyerPos.latitude}, ${buyerPos.longitude}'); // Debug
        }
      }
    } catch (e) {
      print('Error getting buyer location: $e'); // Debug
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = false;
      });
    }
  }

  String _getLocationName(ll.LatLng position) {
    // Simple location name mapping based on coordinates
    // This is a basic implementation - in production you'd use reverse geocoding
    double lat = position.latitude;
    double lng = position.longitude;
    
    // Biliran Island municipalities approximate coordinates
    if (lat >= 11.45 && lat <= 11.65 && lng >= 124.45 && lng <= 124.65) {
      if (lat >= 11.55 && lng >= 124.50) return 'Naval, Biliran';
      if (lat >= 11.50 && lng <= 124.50) return 'Caibiran, Biliran';
      if (lat <= 11.50 && lng >= 124.55) return 'Almeria, Biliran';
      if (lat <= 11.45) return 'Kawayan, Biliran';
      return 'Maripipi, Biliran';
    }
    
    return 'Your Location';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance for small distances
    // For more accuracy, use Haversine formula
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return (dLat * dLat + dLon * dLon);
  }

  // Removed _centerOnBuyerLocation since we no longer control MapController
  // Map centers automatically via initialCenter in MapOptions

  Future<void> _ensureLocationPermission() async {
    try {
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) serviceEnabled = await _location.requestService();
      var permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
      }
      if (!mounted) return;
      setState(() {
        _hasLocationPermission =
            serviceEnabled && permission == PermissionStatus.granted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasLocationPermission = false;
      });
    }
  }

  Widget _buildProfileImage(String photoUrl) {
    try {
      // Check if it's a base64 data URI
      if (photoUrl.startsWith('data:image')) {
        // Extract base64 string from data URI
        final base64String = photoUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.blue,
              child: const Icon(Icons.person, color: Colors.white, size: 30),
            );
          },
        );
      } else {
        // Regular URL
        return CachedNetworkImage(
          imageUrl: photoUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.blue[100],
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.blue,
            child: const Icon(Icons.person, color: Colors.white, size: 30),
          ),
        );
      }
    } catch (e) {
      print('Error loading profile image: $e');
      return Container(
        color: Colors.blue,
        child: const Icon(Icons.person, color: Colors.white, size: 30),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _fishermenSub?.cancel();
    // Don't manually dispose MapController - let Flutter handle it naturally
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoggingOut
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1),
                    Color(0xFF1976D2),
                    Color(0xFF42A5F5),
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
                      'Signing out...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D47A1), // Deep blue
                    Color(0xFF1565C0), // Medium blue
                    Color(0xFF1976D2), // Lighter blue
                    Color(0xFF42A5F5), // Light blue
                    Color(0xFF90CAF9), // Very light blue
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
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
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
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
                        Color(0xFF0D47A1), // Deep blue
                        Color(0xFF1565C0), // Medium blue
                        Color(0xFF1976D2), // Lighter blue
                        Color(0xFF42A5F5), // Light blue
                        Color(0xFF90CAF9), // Very light blue
                      ],
                      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Unable to load map',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error: $_error',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF42A5F5).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _listenFishermen();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                      children: [
                        // Map (flutter_map manages its own controller internally)
                        FlutterMap(
                          key: _mapKey,
                          options: MapOptions(
                        initialCenter: _buyerLocation ?? _center,
                        initialZoom: _buyerLocation != null ? 15.0 : 11.0,
                        minZoom: 9,
                        maxZoom: 18,
                        cameraConstraint: CameraConstraint.contain(
                          bounds: _biliranBounds,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.maptiler.com/maps/hybrid/{z}/{x}/{y}.jpg?key=iUvY31rVUkSuHFoAAxHu',
                          userAgentPackageName: 'com.example.fishon',
                        ),
                        MarkerLayer(
                          markers: [
                            ..._markers.values.toList(),
                            if (_buyerMarker != null) _buyerMarker!,
                          ],
                        ),
                      ],
                    ),
                    
                    // Top Header Card
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
                              // Logout Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () async {
                                    print('Logout button pressed'); // Debug
                                    
                                    // Set logging out state to remove map from tree
                                    if (!mounted) {
                                      print('Widget not mounted, returning'); // Debug
                                      return;
                                    }
                                    
                                    print('Cancelling fishermen subscription...'); // Debug
                                    await _fishermenSub?.cancel();
                                    
                                    print('Setting _isLoggingOut to true'); // Debug
                                    setState(() {
                                      _isLoggingOut = true;
                                    });
                                    
                                    // Wait longer for rebuild to complete and map to be removed from tree
                                    print('Waiting for rebuild and map disposal...'); // Debug
                                    await Future.delayed(const Duration(milliseconds: 300));
                                    
                                    // Sign out
                                    print('Attempting to sign out...'); // Debug
                                    try {
                                      await AuthService().signOut();
                                      print('Sign out successful'); // Debug
                                    } catch (e) {
                                      print('Sign out error: $e');
                                    }
                                    
                                    if (!mounted) {
                                      print('Widget not mounted after signout, returning'); // Debug
                                      return;
                                    }
                                    
                                    // Navigate to login screen using direct navigation
                                    print('Navigating to login screen...'); // Debug
                                    try {
                                      await Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                                        (route) => false,
                                      );
                                      print('Navigation completed'); // Debug
                                    } catch (e) {
                                      print('Navigation error: $e'); // Debug
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Sign out',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    if (_buyerLocation != null) {
                                      setState(() {
                                        _center = _buyerLocation!;
                                        _mapKey = UniqueKey();
                                      });
                                    }
                                  },
                                  icon: Icon(
                                    Icons.my_location,
                                    color: Theme.of(context).primaryColor,
                                    size: 20,
                                  ),
                                  tooltip: 'Go to my location',
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
                              Row(
                                children: [
                                  // Tutorial Button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      onPressed: () => Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, __, ___) => const TutorialScreen(userRole: 'buyer'),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.help_outline,
                                        color: Colors.orange,
                                      ),
                                      tooltip: 'Tutorial',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom Info Card
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tap any marker to view fisherman',
                                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Profile pictures show active fishermen with fresh catch',
                                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
