import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/fish_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Users
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      print('FirestoreService: Updating user $uid with data: $data'); // Debug
      
      // Check if document exists first
      var docRef = _db.collection('users').doc(uid);
      var docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        await docRef.update(data);
        print('FirestoreService: User updated successfully'); // Debug
      } else {
        print('FirestoreService: Document does not exist, creating new one'); // Debug
        // If document doesn't exist, create it with the data
        await docRef.set(data, SetOptions(merge: true));
      }
    } catch (e) {
      print('FirestoreService: Error updating user: $e'); // Debug
      rethrow;
    }
  }

  Stream<List<AppUser>> streamVisibleFishermen() {
    print('FirestoreService: Starting to stream visible fishermen'); // Debug
    return _db
        .collection('users')
        .where('role', isEqualTo: 'fisherman')
        .where('isVisible', isEqualTo: true)
        .snapshots()
        .map(
          (snap) {
            print('FirestoreService: Received ${snap.docs.length} visible fishermen'); // Debug
            var users = <AppUser>[];
            for (var doc in snap.docs) {
              try {
                var user = AppUser.fromMap(doc.data());
                print('FirestoreService: User ${user.name} - visible: ${user.isVisible}, location: ${user.location}'); // Debug
                users.add(user);
              } catch (e) {
                print('FirestoreService: Error parsing user ${doc.id}: $e'); // Debug
              }
            }
            return users;
          },
        );
  }

  Future<AppUser?> getUserById(String uid) async {
    try {
      var doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap(doc.data()!);
      }
      print('FirestoreService: User document $uid does not exist');
      return null;
    } catch (e) {
      print('FirestoreService: Error getting user $uid: $e');
      return null;
    }
  }

  Stream<List<AppUser>> streamAllUsers() {
    return _db
        .collection('users')
        .snapshots()
        .map(
          (snap) {
            var users = <AppUser>[];
            for (var doc in snap.docs) {
              try {
                var user = AppUser.fromMap(doc.data());
                users.add(user);
              } catch (e) {
                print('FirestoreService: Error parsing user ${doc.id}: $e');
              }
            }
            return users;
          },
        );
  }

  // Fish CRUD
  Future<void> addFish(FishModel fish) async {
    await _db.collection('fish').doc(fish.id).set(fish.toMap());
  }

  Future<void> updateFish(FishModel fish) async {
    await _db.collection('fish').doc(fish.id).update(fish.toMap());
  }

  Future<void> deleteFish(String id) async {
    await _db.collection('fish').doc(id).delete();
  }

  Stream<List<FishModel>> streamFishByOwner(String ownerId) {
    return _db
        .collection('fish')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((s) => s.docs.map((d) => FishModel.fromMap(d.data())).toList());
  }

  Stream<List<FishModel>> streamFishByName(String nameQuery) {
    return _db
        .collection('fish')
        .where('name', isEqualTo: nameQuery)
        .snapshots()
        .map((s) => s.docs.map((d) => FishModel.fromMap(d.data())).toList());
  }

  Stream<List<FishModel>> streamAllFish() {
    return _db
        .collection('fish')
        .snapshots()
        .map((s) => s.docs.map((d) => FishModel.fromMap(d.data())).toList());
  }

  // Ratings
  Future<void> addRating(
    String fishermanId,
    String buyerId,
    int rating,
    String? review,
  ) async {
    // Enforce 1-hour cooldown per (buyer,fisherman)
    // Find all ratings from this buyer for this fisherman
    final recentQuery = await _db
        .collection('ratings')
        .where('buyerId', isEqualTo: buyerId)
        .where('fishermanId', isEqualTo: fishermanId)
        .get();

    if (recentQuery.docs.isNotEmpty) {
      // Sort by timestamp in memory to find the most recent
      final ratings = recentQuery.docs.map((d) => d.data()).toList();
      ratings.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending
      });
      
      final mostRecent = ratings.first;
      final ts = mostRecent['timestamp'];
      if (ts != null && ts is Timestamp) {
        final last = ts.toDate();
        final now = DateTime.now();
        final diff = now.difference(last);
        const cooldown = Duration(hours: 1);
        if (diff < cooldown) {
          final remaining = cooldown - diff;
          final mins = remaining.inMinutes;
          final secs = remaining.inSeconds % 60;
          throw Exception('You can only rate this fisherman once every 1 hour. Try again in ${mins}m ${secs}s.');
        }
      }
    }

    var id = _uuid.v4();
    await _db.collection('ratings').doc(id).set({
      'id': id,
      'fishermanId': fishermanId,
      'buyerId': buyerId,
      'rating': rating,
      'review': review,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> streamRatingsFor(String fishermanId) {
    return _db
        .collection('ratings')
        .where('fishermanId', isEqualTo: fishermanId)
        .snapshots()
        .map((s) {
          // Sort by timestamp in memory (newest first)
          final list = s.docs.map((d) => d.data()).toList();
          list.sort((a, b) {
            final aTime = a['timestamp'] as Timestamp?;
            final bTime = b['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime); // descending
          });
          return list;
        });
  }

  Future<void> deleteRating(String ratingId, String buyerId) async {
    try {
      print('FirestoreService: Attempting to delete rating $ratingId for buyer $buyerId');
      
      // First verify that the rating exists and belongs to the buyer
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final storedBuyerId = ratingData['buyerId'];
      
      print('FirestoreService: Rating data: $ratingData');
      print('FirestoreService: Stored buyer ID: $storedBuyerId');
      print('FirestoreService: Provided buyer ID: $buyerId');
      print('FirestoreService: IDs match: ${storedBuyerId == buyerId}');
      
      if (storedBuyerId != buyerId) {
        print('FirestoreService: Buyer ID mismatch - permission denied');
        throw Exception('You can only delete your own ratings.');
      }
      
      // Delete the rating
      print('FirestoreService: Deleting rating document');
      await _db.collection('ratings').doc(ratingId).delete();
      print('FirestoreService: Rating deleted successfully');
    } catch (e) {
      print('FirestoreService: Error deleting rating: $e');
      rethrow;
    }
  }

  Future<void> deleteRatingCustomAuth(String ratingId, String buyerId) async {
    try {
      print('FirestoreService: Custom auth delete - rating $ratingId for buyer $buyerId');
      
      // First verify that the rating exists and belongs to the buyer
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final storedBuyerId = ratingData['buyerId'];
      
      print('FirestoreService: Rating data: $ratingData');
      print('FirestoreService: Stored buyer ID: $storedBuyerId');
      print('FirestoreService: Provided buyer ID: $buyerId');
      
      if (storedBuyerId != buyerId) {
        print('FirestoreService: Buyer ID mismatch - permission denied');
        throw Exception('You can only delete your own ratings.');
      }
      
      // Since your rules have `allow delete: if true` for most operations,
      // and you're using custom auth, we'll delete directly
      print('FirestoreService: Deleting rating document (custom auth)');
      await _db.collection('ratings').doc(ratingId).delete();
      print('FirestoreService: Rating deleted successfully (custom auth)');
    } catch (e) {
      print('FirestoreService: Error deleting rating (custom auth): $e');
      rethrow;
    }
  }

  Future<void> updateRating(
    String ratingId,
    String buyerId,
    int newRating,
    String? newReview,
  ) async {
    try {
      print('FirestoreService: Attempting to update rating $ratingId for buyer $buyerId');
      
      // First verify that the rating exists and belongs to the buyer
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final storedBuyerId = ratingData['buyerId'];
      
      print('FirestoreService: Stored buyer ID: $storedBuyerId');
      print('FirestoreService: Provided buyer ID: $buyerId');
      
      if (storedBuyerId != buyerId) {
        print('FirestoreService: Buyer ID mismatch - permission denied');
        throw Exception('You can only edit your own ratings.');
      }
      
      // Update the rating
      final updateData = {
        'rating': newRating,
        'review': newReview,
        'timestamp': FieldValue.serverTimestamp(), // Update timestamp to show it was edited
      };
      
      print('FirestoreService: Updating rating with data: $updateData');
      await _db.collection('ratings').doc(ratingId).update(updateData);
      print('FirestoreService: Rating updated successfully');
    } catch (e) {
      print('FirestoreService: Error updating rating: $e');
      rethrow;
    }
  }

  // Add reply to rating
  Future<void> addRatingReply(String ratingId, String fishermanId, String reply) async {
    try {
      print('FirestoreService: Adding reply to rating $ratingId');
      
      // First verify that the rating exists and the fisherman owns the fish
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final fishermanIdFromRating = ratingData['fishermanId'];
      
      print('FirestoreService: Rating fisherman ID: $fishermanIdFromRating');
      print('FirestoreService: Current fisherman ID: $fishermanId');
      
      if (fishermanIdFromRating != fishermanId) {
        print('FirestoreService: Fisherman ID mismatch - permission denied');
        throw Exception('You can only reply to ratings for your own fish.');
      }
      
      // Add the reply
      await _db.collection('ratings').doc(ratingId).update({
        'fishermanReply': reply,
        'replyTimestamp': FieldValue.serverTimestamp(),
      });
      
      print('FirestoreService: Reply added successfully');
    } catch (e) {
      print('FirestoreService: Error adding reply: $e');
      rethrow;
    }
  }

  // Update rating reply
  Future<void> updateRatingReply(String ratingId, String fishermanId, String reply) async {
    try {
      print('FirestoreService: Updating reply for rating $ratingId');
      
      // First verify that the rating exists and the fisherman owns the fish
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final fishermanIdFromRating = ratingData['fishermanId'];
      
      if (fishermanIdFromRating != fishermanId) {
        print('FirestoreService: Fisherman ID mismatch - permission denied');
        throw Exception('You can only update replies to ratings for your own fish.');
      }
      
      // Update the reply
      await _db.collection('ratings').doc(ratingId).update({
        'fishermanReply': reply,
        'replyTimestamp': FieldValue.serverTimestamp(),
      });
      
      print('FirestoreService: Reply updated successfully');
    } catch (e) {
      print('FirestoreService: Error updating reply: $e');
      rethrow;
    }
  }

  // Delete rating reply
  Future<void> deleteRatingReply(String ratingId, String fishermanId) async {
    try {
      print('FirestoreService: Deleting reply for rating $ratingId');
      
      // First verify that the rating exists and the fisherman owns the fish
      final ratingDoc = await _db.collection('ratings').doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        print('FirestoreService: Rating document not found');
        throw Exception('Rating not found.');
      }
      
      final ratingData = ratingDoc.data()!;
      final fishermanIdFromRating = ratingData['fishermanId'];
      
      if (fishermanIdFromRating != fishermanId) {
        print('FirestoreService: Fisherman ID mismatch - permission denied');
        throw Exception('You can only delete replies to ratings for your own fish.');
      }
      
      // Remove the reply fields
      await _db.collection('ratings').doc(ratingId).update({
        'fishermanReply': FieldValue.delete(),
        'replyTimestamp': FieldValue.delete(),
      });
      
      print('FirestoreService: Reply deleted successfully');
    } catch (e) {
      print('FirestoreService: Error deleting reply: $e');
      rethrow;
    }
  }

  // Chat
  Stream<QuerySnapshot> streamChatsForUser(String uid) {
    return _db
        .collection('chats')
        .where('members', arrayContains: uid)
        .snapshots();
  }

  Stream<QuerySnapshot> streamChatMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<String> createOrGetChatId(String a, String b) async {
    // ensure consistent id (sort the two ids)
    var members = [a, b]..sort();
    var query =
        await _db
            .collection('chats')
            .where('members', isEqualTo: members)
            .limit(1)
            .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    } else {
      var doc = await _db.collection('chats').add({
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }
  }

  Future<void> sendMessage(String chatId, String senderId, String text) async {
    var docRef =
        _db.collection('chats').doc(chatId).collection('messages').doc();
    await docRef.set({
      'id': docRef.id,
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
