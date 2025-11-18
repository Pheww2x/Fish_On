import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/fish_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherId;
  final FishModel? quotedFish;
  const ChatScreen({super.key, required this.chatId, required this.otherId, this.quotedFish});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _auth = AuthService();
  final _ctrl = TextEditingController();
  String? uid;
  FishModel? _quotedFish;

  @override
  void initState() {
    super.initState();
    // Get current user from our Firestore-only auth session
    final currentUser = AuthService.getCurrentUser();
    if (currentUser != null) {
      setState(() => uid = currentUser['uid']);
    }
    // Initialize quoted fish if provided
    _quotedFish = widget.quotedFish;
  }

  void _send() async {
    if (_ctrl.text.trim().isEmpty || uid == null) return;
    
    String messageText = _ctrl.text.trim();
    
    // If there's a quoted fish, format the message with fish info and image
    if (_quotedFish != null) {
      // Create a structured message with fish data
      final fishData = {
        'type': 'fish_quote',
        'fish': {
          'name': _quotedFish!.name,
          'price': _quotedFish!.price,
          'quantityKg': _quotedFish!.quantityKg,
          'imageUrl': _quotedFish!.imageUrl,
        },
        'message': messageText,
      };
      
      // Send as JSON string that can be parsed later (preserves full base64/URL)
      messageText = "FISH_QUOTE:${jsonEncode(fishData)}||$messageText";
    }
    
    await _fs.sendMessage(widget.chatId, uid!, messageText);
    _ctrl.clear();
    
    // Clear the quoted fish after sending
    setState(() {
      _quotedFish = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
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
          child: Column(
            children: [
              // Header with Back Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        'Chat',
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
              ),
              
              // Messages Area
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
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
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
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
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _fs.streamChatMessages(widget.chatId),
                    builder: (c, snap) {
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF42A5F5),
                          ),
                        );
                      }
                      var docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return Center(
                          child: Text(
                            'Start a conversation!',
                            style: TextStyle(
                              color: const Color(0xFF0D47A1).withOpacity(0.7),
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          var d = docs[i].data() as Map<String, dynamic>;
                          bool mine = d['senderId'] == uid;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: mine
                                      ? [const Color(0xFF42A5F5), const Color(0xFF1976D2)]
                                      : [const Color(0xFF90CAF9), const Color(0xFF64B5F6)],
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: mine ? const Radius.circular(18) : const Radius.circular(6),
                                  bottomRight: mine ? const Radius.circular(6) : const Radius.circular(18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF42A5F5).withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _buildMessageContent(d['text'] ?? ''),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              
              // Input Area
              Container(
                margin: const EdgeInsets.all(16),
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
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF42A5F5).withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Quoted Fish Display
                    if (_quotedFish != null)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF90CAF9).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Fish Image
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _quotedFish!.imageUrl != null && _quotedFish!.imageUrl!.isNotEmpty
                                  ? _buildFishImage(_quotedFish!.imageUrl!)
                                  : Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.set_meal,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Fish Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _quotedFish!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D47A1),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '₱${_quotedFish!.price} • ${_quotedFish!.quantityKg}kg',
                                    style: TextStyle(
                                      color: const Color(0xFF0D47A1).withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Close button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _quotedFish = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Text Input Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ctrl,
                              style: const TextStyle(
                                color: Color(0xFF0D47A1),
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: _quotedFish != null 
                                  ? 'Reply to ${_quotedFish!.name}...' 
                                  : 'Type a message...',
                                hintStyle: TextStyle(
                                  color: const Color(0xFF0D47A1).withOpacity(0.5),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF42A5F5).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _send,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Icon(Icons.send, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildMessageContent(String messageText) {
    // Check if this is a fish quote message
    if (messageText.startsWith('FISH_QUOTE:')) {
      try {
        // Extract the parts
        final parts = messageText.split('||');
        if (parts.length >= 2) {
          final fishDataStr = parts[0].substring('FISH_QUOTE:'.length);
          final userMessage = parts.sublist(1).join('||');
          
          // Parse fish data – first try JSON (new format), fall back to legacy parsing
          String fishName = '';
          String fishPrice = '';
          String fishQuantity = '';
          String fishImageUrl = '';

          try {
            // New format: JSON encoded fish data
            final decoded = jsonDecode(fishDataStr) as Map<String, dynamic>;
            final fishMap = (decoded['fish'] as Map<String, dynamic>?);
            if (fishMap != null) {
              fishName = (fishMap['name'] ?? '').toString();
              fishPrice = (fishMap['price'] ?? '').toString();
              fishQuantity = (fishMap['quantityKg'] ?? '').toString();
              fishImageUrl = (fishMap['imageUrl'] ?? '').toString();
            }
          } catch (_) {
            // Legacy format: Map.toString() with manual parsing
            fishName = _extractValue(fishDataStr, 'name');
            fishPrice = _extractValue(fishDataStr, 'price');
            fishQuantity = _extractValue(fishDataStr, 'quantityKg');
            fishImageUrl = _extractValue(fishDataStr, 'imageUrl');
          }
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fish quote section
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Fish image
                    if (fishImageUrl.isNotEmpty)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildFishImage(fishImageUrl),
                        ),
                      ),
                    const SizedBox(width: 8),
                    // Fish info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fishName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '₱$fishPrice • ${fishQuantity}kg',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // User message
              if (userMessage.isNotEmpty)
                Text(
                  userMessage,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          );
        }
      } catch (e) {
        // Fallback to regular message if parsing fails
        return Text(
          messageText,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        );
      }
    }
    
    // Regular message
    return Text(
      messageText,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _extractValue(String data, String key) {
    try {
      final keyPattern = '$key: ';
      final startIndex = data.indexOf(keyPattern);
      if (startIndex == -1) return '';
      
      final valueStart = startIndex + keyPattern.length;
      final nextComma = data.indexOf(',', valueStart);
      final nextBrace = data.indexOf('}', valueStart);
      
      int endIndex;
      if (nextComma == -1 && nextBrace == -1) {
        endIndex = data.length;
      } else if (nextComma == -1) {
        endIndex = nextBrace;
      } else if (nextBrace == -1) {
        endIndex = nextComma;
      } else {
        endIndex = nextComma < nextBrace ? nextComma : nextBrace;
      }
      
      return data.substring(valueStart, endIndex).trim();
    } catch (e) {
      return '';
    }
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
                size: 20,
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
                size: 20,
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
          size: 20,
        ),
      );
    }
  }
}
