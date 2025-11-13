import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/user_model.dart';
import '../../widgets/rating_stars.dart';
import 'profile_edit.dart';
import 'add_fish.dart';
import 'manage_fish.dart';
import '../buyer/map_view.dart';
import '../chat/chat_list.dart';

class FishermanDashboard extends StatefulWidget {
  final AppUser? initialUser;
  const FishermanDashboard({super.key, this.initialUser});
  @override
  State<FishermanDashboard> createState() => _FishermanDashboardState();
}

class _FishermanDashboardState extends State<FishermanDashboard> {
  final AuthService _auth = AuthService();
  final FirestoreService _fs = FirestoreService();
  final LocationService _loc = LocationService();
  AppUser? _user;
  bool _loading = true;
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    print('Dashboard _loadProfile called'); // Debug print
    print('Initial user: ${widget.initialUser}'); // Debug print
    
    try {
      // If initial user is passed, use it directly first, then refresh
      if (widget.initialUser != null && widget.initialUser!.uid.isNotEmpty) {
        print('Using initial user: ${widget.initialUser!.uid}'); // Debug print
        setState(() {
          _user = widget.initialUser;
          _loading = false;
        });
        
        // Load ratings
        _loadRatings();
        
        // Then refresh from Firestore in background
        try {
          final fresh = await _fs.getUserById(widget.initialUser!.uid);
          if (mounted) {
            setState(() {
              _user = fresh;
            });
          }
        } catch (e) {
          print('Error refreshing user data: $e'); // Debug print
          // Keep using initial user if refresh fails
        }
        return;
      }

      // Try to read arguments and refresh from Firestore using uid
      final args = ModalRoute.of(context)?.settings.arguments;
      print('Route arguments: $args'); // Debug print
      print('About to check session storage...'); // Debug print
      if (args is Map<String, dynamic>) {
        print('Found route args as Map'); // Debug print
        try {
          // Create AppUser from route arguments directly
          final user = AppUser.fromMap(args);
          if (user.uid.isNotEmpty) {
            print('Successfully created user from route args: ${user.name}'); // Debug print
            setState(() {
              _user = user;
              _loading = false;
            });
            
            // Load ratings
            _loadRatings();
            
            // Optionally refresh from Firestore in background
            try {
              final fresh = await _fs.getUserById(user.uid);
              if (mounted) {
                setState(() {
                  _user = fresh;
                });
              }
            } catch (e) {
              print('Error refreshing user from Firestore: $e'); // Debug print
            }
            return;
          }
        } catch (e) {
          print('Error creating user from route args: $e'); // Debug print
        }
      } else {
        print('No route args found or not a Map'); // Debug print
      }

      // As last resort, try to get current user from AuthService session
      print('No route args found, checking AuthService session...'); // Debug print
      final sessionUser = AuthService.getCurrentUser();
      print('Session user result: $sessionUser'); // Debug print
      if (sessionUser != null) {
        print('Found user in session: ${sessionUser['name']}'); // Debug print
        try {
          // Handle GeoPoint conversion issue by creating a safe copy
          Map<String, dynamic> safeUserData = Map<String, dynamic>.from(sessionUser);
          
          // Convert GeoPoint to a safe format if needed
          if (safeUserData['location'] != null && safeUserData['location'] is GeoPoint) {
            // Keep the GeoPoint as is - AppUser.fromMap should handle it
            print('Location is GeoPoint: ${safeUserData['location']}'); // Debug
          }
          
          final user = AppUser.fromMap(safeUserData);
          print('Successfully created user from session: ${user.name}'); // Debug
          setState(() {
            _user = user;
            _loading = false;
          });
          return;
        } catch (e) {
          print('Error creating user from session: $e'); // Debug print
          print('Session data causing error: $sessionUser'); // Debug print
        }
      } else {
        print('Session user is null'); // Debug print
      }
      
      print('No user data found anywhere, setting user to null'); // Debug print
      setState(() {
        _user = null;
        _loading = false;
      });
    } catch (e) {
      print('Unexpected error in _loadProfile: $e');
      print('Stack trace: $e'); // Debug
      setState(() {
        _user = null;
        _loading = false;
      });
    }
  }

  void _loadRatings() {
    if (_user == null) return;
    
    _fs.streamRatingsFor(_user!.uid).listen((list) {
      if (mounted) {
        setState(() {
          _ratings = list;
        });
      }
    });
  }

  double _getAverageRating() {
    if (_ratings.isEmpty) return 0.0;
    int sum = _ratings.fold(0, (prev, r) => prev + (r['rating'] as int? ?? 0));
    return sum / _ratings.length;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime dt = (timestamp as Timestamp).toDate();
      return '${dt.month}/${dt.day}/${dt.year}';
    } catch (e) {
      return '';
    }
  }

  Future<void> _toggleVisibility(bool val) async {
    print('Toggle called - User: $_user, UID: ${_user?.uid}'); // Debug print
    
    if (_user == null) {
      print('User is null!'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data not available. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_user!.uid.isEmpty) {
      print('User UID is empty!'); // Debug print
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID is missing. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('Toggling visibility for user: ${_user!.uid} to $val'); // Debug print
    
    try {
      // First update visibility in Firestore without location dependency
      print('Updating Firestore visibility to $val...'); // Debug
      await _fs.updateUser(_user!.uid, {'isVisible': val});
      print('Firestore update successful'); // Debug
      
      // Update local state immediately
      setState(() {
        _user = _user!.copyWith(isVisible: val);
      });
      print('Local state updated to $val'); // Debug
      
      if (val) {
        // Show loading indicator for location update
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('Updating location...'),
              ],
            ),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Try to update location, but don't fail if it doesn't work
        try {
          print('Attempting to update location...'); // Debug
          await _loc.updateUserLocation(_user!.uid);
          print('Location update successful'); // Debug
        } catch (locationError) {
          print('Location update failed: $locationError'); // Debug
          // Show warning but don't revert visibility
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visible on map, but location update failed. Please check location permissions.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          return; // Don't show success message if location failed
        }
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'You are now visible on the map' : 'You are now hidden from the map'),
          backgroundColor: val ? Colors.green : Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error updating visibility: $e'); // Debug print
      // Show error message and revert toggle
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update visibility: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // Revert the toggle state
      setState(() {
        _user = _user!.copyWith(isVisible: !val);
      });
    }
  }

  Widget _buildProfileImage(String photoUrl, String name) {
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
            print('Error displaying base64 image: $error');
            return _buildFallbackAvatar(name);
          },
        );
      } else {
        // Regular URL
        return Image.network(
          photoUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFE3F2FD),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $error');
            return _buildFallbackAvatar(name);
          },
        );
      }
    } catch (e) {
      print('Error processing image: $e');
      return _buildFallbackAvatar(name);
    }
  }

  Widget _buildFallbackAvatar(String name) {
    return Container(
      color: const Color(0xFF0D47A1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
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
                  'Loading your dashboard...',
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
        ),
      );
    }
    
    if (_user == null) {
      return Scaffold(
        body: Container(
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
            child: Text(
              'No user data. Please log in again.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header with Logo and Logout
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // White container (smaller)
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF), // Pure white
                                  Color(0xFFF8F9FA), // Off white
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          // Logo (larger than container)
                          Image.asset(
                            'assets/icons/app_icon.png',
                            width: 90,
                            height: 90,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await _auth.signOut();
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                          tooltip: 'Sign out',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Welcome Text
                  Column(
                    children: [
                      Text(
                        "Welcome, ${_user!.name.split(' ').first}",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Fisherman Dashboard",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.9),
                          const Color(0xFFF8F9FA).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Profile Picture
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF42A5F5),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _user!.photoUrl != null && _user!.photoUrl!.isNotEmpty
                                ? _buildProfileImage(_user!.photoUrl!, _user!.name)
                                : Container(
                                    color: const Color(0xFF0D47A1),
                                    child: Center(
                                      child: Text(
                                        _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _user!.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0D47A1),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _user!.email,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF1565C0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Visibility Toggle Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.9),
                          const Color(0xFFF8F9FA).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _user!.isVisible ? Icons.visibility : Icons.visibility_off,
                              color: _user!.isVisible ? Colors.green : Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Map Visibility',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0D47A1),
                                    ),
                                  ),
                                  Text(
                                    _user!.isVisible 
                                        ? 'You are visible to buyers'
                                        : 'You are hidden from buyers',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _user!.isVisible,
                              onChanged: (v) async {
                                print('Toggle pressed: $v, current user uid: ${_user?.uid}'); // Debug
                                
                                // Immediately update UI to show responsiveness
                                setState(() {
                                  _user = _user!.copyWith(isVisible: v);
                                });
                                
                                // Then update backend
                                try {
                                  // First, let's verify the user document exists and check its current state
                                  print('Dashboard: Checking user document before update...');
                                  var currentUser = await _fs.getUserById(_user!.uid);
                                  print('Dashboard: Current user data: ${currentUser?.toMap()}');
                                  
                                  // Ensure role is set correctly and update visibility
                                  Map<String, dynamic> updateData = {
                                    'isVisible': v,
                                    'role': 'fisherman', // Ensure role is set
                                    'uid': _user!.uid, // Ensure UID is set
                                    'name': _user!.name, // Ensure name is set
                                    'email': _user!.email, // Ensure email is set
                                  };
                                  
                                  print('Dashboard: Updating user ${_user!.uid} with data: $updateData');
                                  await _fs.updateUser(_user!.uid, updateData);
                                  
                                  // Verify the update worked
                                  print('Dashboard: Verifying update...');
                                  var updatedUser = await _fs.getUserById(_user!.uid);
                                  print('Dashboard: Updated user data: ${updatedUser?.toMap()}');
                                  
                                  // Update location if becoming visible
                                  if (v) {
                                    try {
                                      print('Dashboard: Updating location for visible user');
                                      await _loc.updateUserLocation(_user!.uid);
                                      print('Dashboard: Location updated successfully');
                                    } catch (e) {
                                      print('Location update failed: $e');
                                      // Show warning but don't fail the visibility update
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Visible on map, but location update failed. Please check location permissions.'),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                  
                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(v ? 'Now visible on map' : 'Hidden from map'),
                                      backgroundColor: v ? Colors.green : Colors.orange,
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  
                                } catch (e) {
                                  print('Firestore update failed: $e');
                                  // Revert UI change
                                  setState(() {
                                    _user = _user!.copyWith(isVisible: !v);
                                  });
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Ratings Section
                  if (_ratings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.95),
                            Colors.white.withOpacity(0.9),
                            const Color(0xFFF8F9FA).withOpacity(0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withOpacity(0.2),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your Ratings & Reviews',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D47A1),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Text(
                                  '${_getAverageRating().toStringAsFixed(1)} ★',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_ratings.length} ${_ratings.length == 1 ? 'review' : 'reviews'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Show latest 3 ratings
                          ...List.generate(
                            _ratings.length > 3 ? 3 : _ratings.length,
                            (i) {
                              var rating = _ratings[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFE3F2FD),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        RatingStars(
                                          rating: rating['rating'] ?? 0,
                                          size: 16,
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimestamp(rating['timestamp']),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rating['review'] != null && rating['review'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        rating['review'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                          
                          if (_ratings.length > 3)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '+ ${_ratings.length - 3} more ${_ratings.length - 3 == 1 ? 'review' : 'reviews'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (_ratings.isNotEmpty) const SizedBox(height: 24),
                  
                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.9),
                          const Color(0xFFF8F9FA).withOpacity(0.95),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withOpacity(0.2),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Edit Profile Button
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 16),
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
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProfileEditScreen(user: _user!),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.person_outline, color: Colors.white),
                            label: const Text(
                              "Edit Profile",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                        // Messages Button
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChatListScreen(),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.message_outlined, color: Colors.white),
                            label: const Text(
                              "Messages",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                        // Add Fish Button
                        Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CAF50).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddFishScreen(ownerId: _user!.uid),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              "Add Fish Listing",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        
                        // Manage Fish Listings Button
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1976D2).withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManageFishScreen(ownerId: _user!.uid),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.inventory_outlined, color: Colors.white),
                            label: const Text(
                              "Manage Listings",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}
