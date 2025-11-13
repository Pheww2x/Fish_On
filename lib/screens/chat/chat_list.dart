import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _auth = AuthService();
  String? uid;
  final Map<String, AppUser> _userCache = {};
  final Map<String, Map<String, dynamic>> _lastMessageCache = {};
  final Map<String, int> _unreadCountCache = {};

  @override
  void initState() {
    super.initState();
    // Get current user from our Firestore-only auth session
    final currentUser = AuthService.getCurrentUser();
    if (currentUser != null) {
      setState(() => uid = currentUser['uid']);
    }
  }

  Future<AppUser?> _getUser(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final user = await _fs.getUserById(userId);
    if (user != null) {
      _userCache[userId] = user;
    }
    return user;
  }

  Future<Map<String, dynamic>?> _getLastMessage(String chatId) async {
    if (_lastMessageCache.containsKey(chatId)) {
      return _lastMessageCache[chatId];
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final lastMsg = snapshot.docs.first.data();
        _lastMessageCache[chatId] = lastMsg;
        return lastMsg;
      }
    } catch (e) {
      print('Error getting last message: $e');
    }
    return null;
  }

  Future<int> _getUnreadCount(String chatId) async {
    if (_unreadCountCache.containsKey(chatId)) {
      return _unreadCountCache[chatId]!;
    }
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderId', isNotEqualTo: uid)
          .where('read', isEqualTo: false)
          .get();
      
      final count = snapshot.docs.length;
      _unreadCountCache[chatId] = count;
      return count;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: StreamBuilder(
        stream: _fs.streamChatsForUser(uid!),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No chats yet'));
          
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _sortChatsByLastMessage(docs),
            builder: (context, sortedSnapshot) {
              if (!sortedSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final sortedChats = sortedSnapshot.data!;
              
              return ListView.separated(
                itemCount: sortedChats.length,
                separatorBuilder: (c, _) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final chatData = sortedChats[i];
                  final d = chatData['doc'] as QueryDocumentSnapshot;
                  final lastMessage = chatData['lastMessage'] as Map<String, dynamic>?;
                  final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
                  
                  List members = d['members'];
                  String other = members.firstWhere((m) => m != uid);
                  
                  return FutureBuilder<AppUser?>(
                    future: _getUser(other),
                    builder: (context, userSnapshot) {
                      final otherUser = userSnapshot.data;
                      final displayName = otherUser?.name ?? other;
                      
                      return FutureBuilder<int>(
                        future: _getUnreadCount(d.id),
                        builder: (context, unreadSnapshot) {
                          final unreadCount = unreadSnapshot.data ?? 0;
                          final hasUnread = unreadCount > 0;
                          
                          String subtitle = 'Tap to open conversation';
                          if (lastMessage != null) {
                            final text = lastMessage['text'] ?? '';
                            final senderId = lastMessage['senderId'] ?? '';
                            final isMe = senderId == uid;
                            subtitle = isMe ? 'You: $text' : text;
                            if (subtitle.length > 50) {
                              subtitle = '${subtitle.substring(0, 50)}...';
                            }
                          }
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFBBDEFB),
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                                color: hasUnread ? Colors.black87 : Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (lastMessageTime != null)
                                  Text(
                                    _formatTime(lastMessageTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: hasUnread ? const Color(0xFF0D47A1) : Colors.grey[600],
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                if (hasUnread) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D47A1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              // Clear cache for this chat when opening
                              _unreadCountCache.remove(d.id);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(chatId: d.id, otherId: other),
                                ),
                              ).then((_) {
                                // Refresh the list when returning
                                setState(() {
                                  _lastMessageCache.clear();
                                  _unreadCountCache.clear();
                                });
                              });
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _sortChatsByLastMessage(List<QueryDocumentSnapshot> docs) async {
    final List<Map<String, dynamic>> chatsWithTime = [];
    
    for (var doc in docs) {
      final lastMessage = await _getLastMessage(doc.id);
      final timestamp = lastMessage?['timestamp'] as Timestamp?;
      
      chatsWithTime.add({
        'doc': doc,
        'lastMessage': lastMessage,
        'lastMessageTime': timestamp,
      });
    }
    
    // Sort by timestamp, newest first
    chatsWithTime.sort((a, b) {
      final timeA = a['lastMessageTime'] as Timestamp?;
      final timeB = b['lastMessageTime'] as Timestamp?;
      
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      
      return timeB.compareTo(timeA);
    });
    
    return chatsWithTime;
  }

  String _formatTime(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      // Today - show time
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
