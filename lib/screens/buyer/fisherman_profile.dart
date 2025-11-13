import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/fish_model.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../widgets/rating_stars.dart';
import '../chat/chat_screen.dart';

class FishermanProfileScreen extends StatefulWidget {
  final String fishermanId;
  const FishermanProfileScreen({super.key, required this.fishermanId});
  @override
  State<FishermanProfileScreen> createState() => _FishermanProfileScreenState();
}

class _FishermanProfileScreenState extends State<FishermanProfileScreen> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _auth = AuthService();
  final LocationService _loc = LocationService();
  AppUser? _user;
  AppUser? _currentUser;
  List<FishModel> _fish = [];
  List<Map<String, dynamic>> _ratings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    var u = await _fs.getUserById(widget.fishermanId);
    
    // Get current user from our Firestore-only auth session
    final currentUserData = AuthService.getCurrentUser();
    AppUser? currentU;
    if (currentUserData != null) {
      currentU = await _fs.getUserById(currentUserData['uid']);
    }
    
    _fs
        .streamFishByOwner(widget.fishermanId)
        .listen((list) => setState(() => _fish = list));
    
    // Load ratings for this fisherman
    _fs
        .streamRatingsFor(widget.fishermanId)
        .listen((list) => setState(() => _ratings = list));
    
    setState(() {
      _user = u;
      _currentUser = currentU;
    });
  }

  void _rateFisherman() async {
    final currentUserData = AuthService.getCurrentUser();
    if (currentUserData == null) {
      _showErrorNotification('Please log in to rate this fisherman', 'Authentication Required');
      return;
    }
    final buyer = await _fs.getUserById(currentUserData['uid']);
    if (buyer == null) {
      _showErrorNotification('Your profile could not be found. Please try logging in again.', 'Profile Error');
      return;
    }
    
    showDialog(
      context: context,
      builder: (_) => RatingDialog(
        fishermanName: _user!.name,
        onSubmit: (rating, review) async {
          // Show loading indicator
          _showLoadingNotification('Submitting your rating...');
          
          try {
            await _fs.addRating(
              widget.fishermanId,
              buyer.uid,
              rating,
              review.isNotEmpty ? review : null,
            );
            
            // Hide loading and show success
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            HapticFeedback.lightImpact();
            _showSuccessNotification('Your rating has been submitted successfully!');
            
          } catch (e) {
            // Hide loading and show error
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            HapticFeedback.heavyImpact();
            
            // Check if it's a cooldown error for special handling
            final errorMessage = e.toString();
            if (errorMessage.contains('You can only rate this fisherman once every 1 hour')) {
              _showCooldownNotification(_getErrorMessage(errorMessage));
            } else {
              _showErrorNotification(
                _getErrorMessage(errorMessage),
                'Rating Submission Failed'
              );
            }
          }
        },
      ),
    );
  }

  void _toggleVisibility(bool val) async {
    if (_currentUser?.uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID is missing. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    print('Toggling visibility for user: ${_currentUser!.uid} to $val');
    
    try {
      if (val) {
        // Show loading indicator
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
            duration: Duration(seconds: 2),
          ),
        );
        // Update location first when becoming visible
        await _loc.updateUserLocation(_currentUser!.uid);
      }
      
      // Update visibility in Firestore
      await _fs.updateUser(_currentUser!.uid, {'isVisible': val});
      
      // Update local state
      setState(() {
        _user = _user!.copyWith(isVisible: val);
      });
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(val ? 'You are now visible on the map' : 'You are now hidden from the map'),
          backgroundColor: val ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print('Error updating visibility: $e');
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

  void _openChat() async {
    final currentUserData = AuthService.getCurrentUser();
    if (currentUserData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login to chat')));
      return;
    }
    final me = await _fs.getUserById(currentUserData['uid']);
    if (me == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User profile not found')));
      return;
    }
    final chatId = await _fs.createOrGetChatId(me.uid, widget.fishermanId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, otherId: widget.fishermanId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
            child: Column(
              children: [
                // Header with Back Button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        _user!.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
                const SizedBox(height: 32),
                
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
                      const SizedBox(height: 20),
                      
                      // Contact Info
                      Text(
                        'Contact: ${_user!.email}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF0D47A1),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      
                      // Map Visibility Status/Toggle
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF90CAF9).withOpacity(0.3),
                              const Color(0xFF42A5F5).withOpacity(0.2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
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
                                        ? 'Visible to buyers on map'
                                        : 'Hidden from map',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF1565C0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Only show toggle if viewing own profile
                            if (_currentUser?.uid == widget.fishermanId)
                              Switch(
                                value: _user!.isVisible,
                                onChanged: (v) {
                                  print('Toggle pressed: $v, current user uid: ${_currentUser?.uid}');
                                  _toggleVisibility(v);
                                },
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.orange,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
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
                                onPressed: _openChat,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.message, color: Colors.white),
                                label: const Text(
                                  'Message',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 50,
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
                                onPressed: _rateFisherman,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.star, color: Colors.white),
                                label: const Text(
                                  'Rate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Fish for Sale Section
                Container(
                  width: double.infinity,
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
                      Text(
                        '🐟 Fish for Sale',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_fish.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF90CAF9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(
                            child: Text(
                              'No fish available at the moment',
                              style: TextStyle(
                                color: Color(0xFF0D47A1),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_fish.length, (i) {
                          var f = _fish[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7)],
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: f.imageUrl != null && f.imageUrl!.isNotEmpty
                                      ? _buildFishImage(f.imageUrl!)
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.set_meal,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        f.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '₱${f.price} • ${f.quantityKg}kg',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Ratings Section
                if (_ratings.isNotEmpty)
                  Container(
                    width: double.infinity,
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
                                'Ratings & Reviews',
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
                                      // Show edit and delete buttons if this is the current user's rating
                                      if (_isCurrentUserRating(rating)) ...[
                                        const SizedBox(width: 8),
                                        // Edit button
                                        GestureDetector(
                                          onTap: () => _editRating(rating),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.edit_outlined,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Delete button
                                        GestureDetector(
                                          onTap: () => _confirmDeleteRating(rating),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                  
                                  // Fisherman Reply Section
                                  if (rating['fishermanReply'] != null && rating['fishermanReply'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF42A5F5).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF42A5F5).withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                                  ),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons.reply,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Fisherman Reply',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (rating['replyTimestamp'] != null)
                                                Text(
                                                  _formatTimestamp(rating['replyTimestamp']),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            rating['fishermanReply'],
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF0D47A1),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  
                                  // Reply button for fisherman (only show if current user is the fisherman)
                                  if (_isCurrentUserFisherman() && (rating['fishermanReply'] == null || rating['fishermanReply'].toString().isEmpty)) ...[
                                    const SizedBox(height: 8),
                                    GestureDetector(
                                      onTap: () => _showReplyDialog(rating),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF42A5F5).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.reply,
                                              size: 14,
                                              color: Color(0xFF1976D2),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Reply',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF1976D2),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  
                                  // Edit/Delete reply buttons for fisherman
                                  if (_isCurrentUserFisherman() && rating['fishermanReply'] != null && rating['fishermanReply'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () => _editReply(rating),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.edit_outlined,
                                                  size: 12,
                                                  color: Colors.blue,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Edit Reply',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _deleteReply(rating),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_outline,
                                                  size: 12,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Delete Reply',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
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
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  // Show all ratings dialog
                                  _showAllRatings();
                                },
                                child: Text(
                                  'View all ${_ratings.length} ratings',
                                  style: const TextStyle(
                                    color: Color(0xFF42A5F5),
                                    fontWeight: FontWeight.w600,
                                  ),
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
    );
  }

  double _getAverageRating() {
    if (_ratings.isEmpty) return 0.0;
    double sum = _ratings.fold(0.0, (sum, rating) => sum + (rating['rating'] ?? 0));
    return sum / _ratings.length;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      DateTime date = (timestamp as Timestamp).toDate();
      Duration diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return '';
    }
  }

  void _showAllRatings() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'All Ratings for ${_user!.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _ratings.length,
                  itemBuilder: (context, i) {
                    var rating = _ratings[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF90CAF9).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              RatingStars(rating: rating['rating'] ?? 0),
                              const Spacer(),
                              Text(
                                _formatTimestamp(rating['timestamp']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              // Show edit and delete buttons if this is the current user's rating
                              if (_isCurrentUserRating(rating)) ...[
                                const SizedBox(width: 8),
                                // Edit button
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Close dialog first
                                    _editRating(rating);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Delete button
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Close dialog first
                                    _confirmDeleteRating(rating);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (rating['review'] != null && rating['review'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                rating['review'],
                                style: const TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          
                          // Fisherman Reply Section
                          if (rating['fishermanReply'] != null && rating['fishermanReply'].toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF42A5F5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF42A5F5).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.reply,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Fisherman Reply',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1976D2),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (rating['replyTimestamp'] != null)
                                        Text(
                                          _formatTimestamp(rating['replyTimestamp']),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    rating['fishermanReply'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0D47A1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          // Reply button for fisherman (only show if current user is the fisherman)
                          if (_isCurrentUserFisherman() && (rating['fishermanReply'] == null || rating['fishermanReply'].toString().isEmpty)) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context); // Close dialog first
                                _showReplyDialog(rating);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF42A5F5).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF42A5F5).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.reply,
                                      size: 12,
                                      color: Color(0xFF1976D2),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Reply',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF1976D2),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          
                          // Edit/Delete reply buttons for fisherman
                          if (_isCurrentUserFisherman() && rating['fishermanReply'] != null && rating['fishermanReply'].toString().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Close dialog first
                                    _editReply(rating);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          size: 10,
                                          color: Colors.blue,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Edit Reply',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context); // Close dialog first
                                    _deleteReply(rating);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 10,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Delete Reply',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: Color(0xFF42A5F5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced notification methods for better user experience
  void _showErrorNotification(String message, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 4),
        elevation: 8,
      ),
    );
  }

  void _showSuccessNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF388E3C),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
        elevation: 8,
      ),
    );
  }

  void _showLoadingNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1976D2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 30), // Long duration for loading
        elevation: 8,
      ),
    );
  }

  void _showCooldownNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Rating Cooldown Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFFFF9800), // Orange color for cooldown
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 6), // Longer duration for cooldown info
        elevation: 8,
      ),
    );
  }

  String _getErrorMessage(String error) {
    // Convert technical error messages to user-friendly ones
    if (error.contains('You can only rate this fisherman once every 1 hour')) {
      // Extract the remaining time from the error message
      final regex = RegExp(r'Try again in (\d+m \d+s)');
      final match = regex.firstMatch(error);
      if (match != null) {
        final timeLeft = match.group(1);
        return 'You can rate this fisherman again in $timeLeft.\n\nThis cooldown prevents spam and ensures fair ratings.';
      }
      return 'You can only rate this fisherman once per hour. Please wait before rating again.';
    } else if (error.contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (error.contains('permission')) {
      return 'You don\'t have permission to perform this action.';
    } else if (error.contains('timeout')) {
      return 'The request timed out. Please try again.';
    } else if (error.contains('firebase')) {
      return 'There was a problem with our servers. Please try again later.';
    } else if (error.contains('duplicate')) {
      return 'You have already rated this fisherman.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  void _confirmDeleteRating(Map<String, dynamic> rating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xFFD32F2F)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 12),
            const Text(
              'Delete Rating',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to delete this rating?',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF1565C0),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE3F2FD)),
              ),
              child: Column(
                children: [
                  RatingStars(rating: rating['rating'] ?? 0, size: 20),
                  if (rating['review'] != null && rating['review'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${rating['review']}"',
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF0D47A1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF1565C0)),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5722), Color(0xFFD32F2F)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteRating(rating);
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteRating(Map<String, dynamic> rating) async {
    final currentUserData = AuthService.getCurrentUser();
    if (currentUserData == null) {
      _showErrorNotification('Please log in to delete ratings', 'Authentication Required');
      return;
    }

    final ratingId = rating['id'];
    final currentUserId = currentUserData['uid'];
    
    print('DEBUG _deleteRating: Rating ID: $ratingId');
    print('DEBUG _deleteRating: Current User ID: $currentUserId');
    print('DEBUG _deleteRating: Rating data: $rating');

    // Show loading notification
    _showLoadingNotification('Deleting your rating...');

    try {
      await _fs.deleteRating(ratingId, currentUserId);
      
      // Hide loading and show success
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      HapticFeedback.lightImpact();
      _showSuccessNotification('Your rating has been deleted successfully!');
      
    } catch (e) {
      // Hide loading and show error
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      HapticFeedback.heavyImpact();
      print('DEBUG _deleteRating: Error occurred: $e');
      _showErrorNotification(
        _getDeleteErrorMessage(e.toString()),
        'Failed to Delete Rating'
      );
    }
  }

  String _getDeleteErrorMessage(String error) {
    if (error.contains('Rating not found')) {
      return 'This rating no longer exists.';
    } else if (error.contains('You can only delete your own ratings')) {
      return 'You can only delete your own ratings.';
    } else if (error.contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (error.contains('permission')) {
      return 'You don\'t have permission to delete this rating.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  void _editRating(Map<String, dynamic> rating) {
    showDialog(
      context: context,
      builder: (_) => EditRatingDialog(
        fishermanName: _user!.name,
        currentRating: rating['rating'] ?? 5,
        currentReview: rating['review'] ?? '',
        onSubmit: (newRating, newReview) async {
          final currentUserData = AuthService.getCurrentUser();
          if (currentUserData == null) {
            _showErrorNotification('Please log in to edit ratings', 'Authentication Required');
            return;
          }

          final ratingId = rating['id'];
          final currentUserId = currentUserData['uid'];
          
          print('DEBUG _editRating: Rating ID: $ratingId');
          print('DEBUG _editRating: Current User ID: $currentUserId');
          print('DEBUG _editRating: New rating: $newRating, New review: $newReview');

          // Show loading notification
          _showLoadingNotification('Updating your rating...');

          try {
            await _fs.updateRating(
              ratingId,
              currentUserId,
              newRating,
              newReview.isNotEmpty ? newReview : null,
            );
            
            // Hide loading and show success
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            HapticFeedback.lightImpact();
            _showSuccessNotification('Your rating has been updated successfully!');
            
          } catch (e) {
            // Hide loading and show error
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            HapticFeedback.heavyImpact();
            print('DEBUG _editRating: Error occurred: $e');
            _showErrorNotification(
              _getEditErrorMessage(e.toString()),
              'Failed to Update Rating'
            );
          }
        },
      ),
    );
  }

  String _getEditErrorMessage(String error) {
    if (error.contains('Rating not found')) {
      return 'This rating no longer exists.';
    } else if (error.contains('You can only edit your own ratings')) {
      return 'You can only edit your own ratings.';
    } else if (error.contains('network')) {
      return 'Please check your internet connection and try again.';
    } else if (error.contains('permission')) {
      return 'You don\'t have permission to edit this rating.';
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  bool _isCurrentUserFisherman() {
    return _currentUser?.uid == widget.fishermanId;
  }

  Widget _buildFishImage(String imageUrl) {
    try {
      // Check if it's a base64 data URI
      if (imageUrl.startsWith('data:image')) {
        // Extract base64 string from data URI
        final base64String = imageUrl.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
              ),
              child: const Icon(
                Icons.set_meal,
                color: Colors.white,
                size: 24,
              ),
            );
          },
        );
      } else {
        // Regular URL
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                ),
              ),
              child: const Icon(
                Icons.set_meal,
                color: Colors.white,
                size: 24,
              ),
            );
          },
        );
      }
    } catch (e) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
          ),
        ),
        child: const Icon(
          Icons.set_meal,
          color: Colors.white,
          size: 24,
        ),
      );
    }
  }

  bool _isCurrentUserRating(Map<String, dynamic> rating) {
    // Get current user data from AuthService
    final currentUserData = AuthService.getCurrentUser();
    if (currentUserData == null) {
      print('DEBUG: No current user data found');
      return false;
    }

    final currentUserId = currentUserData['uid'];
    final ratingBuyerId = rating['buyerId'];
    
    print('DEBUG: Current user ID: $currentUserId');
    print('DEBUG: Rating buyer ID: $ratingBuyerId');
    print('DEBUG: Rating data: $rating');
    
    // Check if the current user is the buyer who created this rating
    final isOwner = currentUserId == ratingBuyerId;
    print('DEBUG: Is owner: $isOwner');
    
    return isOwner;
  }

  void _showReplyDialog(Map<String, dynamic> rating) {
    final TextEditingController replyController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.reply, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Reply to Rating',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show the original rating
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < (rating['rating'] ?? 0) ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${rating['rating']}/5',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    if (rating['review'] != null && rating['review'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        rating['review'],
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Reply input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white30),
                ),
                child: TextField(
                  controller: replyController,
                  maxLines: 3,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Write your reply...',
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: isSubmitting ? null : () async {
                  if (replyController.text.trim().isEmpty) return;
                  
                  setState(() => isSubmitting = true);
                  
                  try {
                    await _fs.addRatingReply(
                      rating['id'],
                      widget.fishermanId,
                      replyController.text.trim(),
                    );
                    
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reply added successfully!'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  } catch (e) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to add reply. Please try again.'),
                        backgroundColor: Color(0xFFE53935),
                      ),
                    );
                  } finally {
                    setState(() => isSubmitting = false);
                  }
                },
                child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Reply',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editReply(Map<String, dynamic> rating) {
    final TextEditingController replyController = TextEditingController(
      text: rating['fishermanReply'] ?? '',
    );
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Reply',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white30),
            ),
            child: TextField(
              controller: replyController,
              maxLines: 3,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Edit your reply...',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: isSubmitting ? null : () async {
                  if (replyController.text.trim().isEmpty) return;
                  
                  setState(() => isSubmitting = true);
                  
                  try {
                    await _fs.updateRatingReply(
                      rating['id'],
                      widget.fishermanId,
                      replyController.text.trim(),
                    );
                    
                    Navigator.pop(context);
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reply updated successfully!'),
                        backgroundColor: Color(0xFF4CAF50),
                      ),
                    );
                  } catch (e) {
                    HapticFeedback.heavyImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update reply. Please try again.'),
                        backgroundColor: Color(0xFFE53935),
                      ),
                    );
                  } finally {
                    setState(() => isSubmitting = false);
                  }
                },
                child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteReply(Map<String, dynamic> rating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Reply',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this reply? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                try {
                  await _fs.deleteRatingReply(rating['id'], widget.fishermanId);
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reply deleted successfully!'),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                } catch (e) {
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete reply. Please try again.'),
                      backgroundColor: Color(0xFFE53935),
                    ),
                  );
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
