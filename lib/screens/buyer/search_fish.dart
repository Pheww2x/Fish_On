import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/fish_model.dart';
import '../../models/user_model.dart';
import '../chat/chat_screen.dart';

class SearchFishScreen extends StatefulWidget {
  const SearchFishScreen({super.key});
  @override
  State<SearchFishScreen> createState() => _SearchFishScreenState();
}

class _SearchFishScreenState extends State<SearchFishScreen> {
  final _query = TextEditingController();
  final FirestoreService _fs = FirestoreService();
  List<FishModel> _fishResults = [];
  List<AppUser> _fishermanResults = [];
  List<FishModel> _recommendations = [];
  List<AppUser> _allFishermen = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _searchType = 'fish'; // 'fish' or 'fisherman'

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    _loadFishermen();
  }

  void _loadRecommendations() async {
    setState(() => _isLoading = true);
    _fs.streamAllFish().listen((list) {
      if (mounted) {
        setState(() {
          _recommendations = list.take(6).toList(); // Show top 6 as recommendations
          _isLoading = false;
        });
      }
    });
  }

  void _loadFishermen() async {
    _fs.streamAllUsers().listen((users) {
      if (mounted) {
        setState(() {
          _allFishermen = users.where((user) => user.role == 'fisherman').toList();
        });
      }
    });
  }

  void _search() {
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _fishResults = [];
        _fishermanResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    if (_searchType == 'fish') {
      _fs.streamAllFish().listen((list) {
        if (mounted) {
          final filtered = list.where((f) => 
            f.name.toLowerCase().contains(query) ||
            f.description.toLowerCase().contains(query)
          ).toList();
          setState(() {
            _fishResults = filtered;
            _isLoading = false;
          });
        }
      });
    } else {
      final filtered = _allFishermen.where((fisherman) => 
        fisherman.name.toLowerCase().contains(query) ||
        fisherman.email.toLowerCase().contains(query)
      ).toList();
      setState(() {
        _fishermanResults = filtered;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToChat(String fishermanId) async {
    try {
      // Get current user
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to start a chat'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final buyerId = currentUser['uid'];
      
      // Create or get existing chat ID
      final chatId = await _fs.createOrGetChatId(buyerId, fishermanId);
      
      // Navigate to chat screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              otherId: fishermanId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          child: Padding(
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
                        'Search & Discover',
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
                
                // Search Card
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
                    children: [
                      // Search Input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF42A5F5).withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _query,
                          style: const TextStyle(
                            color: Color(0xFF0D47A1),
                            fontSize: 16,
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              _search();
                            } else {
                              setState(() {
                                _fishResults = [];
                                _fishermanResults = [];
                                _hasSearched = false;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: _searchType == 'fish' ? 'Search fish...' : 'Search fishermen...',
                            labelStyle: TextStyle(
                              color: const Color(0xFF0D47A1).withOpacity(0.7),
                            ),
                            prefixIcon: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.search, color: Colors.white),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Search Type Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchType = 'fish';
                                    _query.clear();
                                    _fishResults = [];
                                    _fishermanResults = [];
                                    _hasSearched = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: _searchType == 'fish' 
                                      ? const LinearGradient(
                                          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                        )
                                      : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.set_meal,
                                        color: _searchType == 'fish' ? Colors.white : const Color(0xFF0D47A1),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Fish',
                                        style: TextStyle(
                                          color: _searchType == 'fish' ? Colors.white : const Color(0xFF0D47A1),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchType = 'fisherman';
                                    _query.clear();
                                    _fishResults = [];
                                    _fishermanResults = [];
                                    _hasSearched = false;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: _searchType == 'fisherman' 
                                      ? const LinearGradient(
                                          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                        )
                                      : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person,
                                        color: _searchType == 'fisherman' ? Colors.white : const Color(0xFF0D47A1),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Fishermen',
                                        style: TextStyle(
                                          color: _searchType == 'fisherman' ? Colors.white : const Color(0xFF0D47A1),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Search Button
                      Container(
                        width: double.infinity,
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
                          onPressed: _search,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(Icons.search, color: Colors.white),
                          label: const Text(
                            'Search',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Results
                Expanded(
                  child: Container(
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildResultsContent(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
      );
    }

    if (!_hasSearched) {
      // Recommendations
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.recommend, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recommended Fish',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _recommendations.isEmpty
            ? const SliverFillRemaining(
                child: Center(
                  child: Text('Loading recommendations...', 
                    style: TextStyle(color: Color(0xFF0D47A1))),
                ),
              )
            : SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildFishCard(_recommendations[index]),
                  childCount: _recommendations.length,
                ),
              ),
        ],
      );
    }

    if (_searchType == 'fish') {
      if (_fishResults.isEmpty) {
        return const Center(
          child: Text('No fish found', 
            style: TextStyle(color: Color(0xFF0D47A1), fontSize: 16)),
        );
      }
      // Fish results
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.set_meal, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Found ${_fishResults.length} fish',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFishCard(_fishResults[index]),
              childCount: _fishResults.length,
            ),
          ),
        ],
      );
    } else {
      if (_fishermanResults.isEmpty) {
        return const Center(
          child: Text('No fishermen found', 
            style: TextStyle(color: Color(0xFF0D47A1), fontSize: 16)),
        );
      }
      // Fisherman results
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Found ${_fishermanResults.length} fishermen',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildFishermanCard(_fishermanResults[index]),
              childCount: _fishermanResults.length,
            ),
          ),
        ],
      );
    }
  }


  Widget _buildFishCard(FishModel fish) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
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
            child: fish.imageUrl != null && fish.imageUrl!.isNotEmpty
              ? _buildFishImage(fish.imageUrl!)
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
        title: Text(
          fish.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '₱${fish.price} • ${fish.quantityKg}kg',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: () => _navigateToChat(fish.ownerId),
      ),
    );
  }

  Widget _buildFishermanCard(AppUser fisherman) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF4CAF50)],
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          fisherman.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Fisherman • ${fisherman.location ?? 'Location not set'}',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
        onTap: () => _navigateToChat(fisherman.uid),
      ),
    );
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
}
