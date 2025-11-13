// lib/models/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  // When writing to Firestore, store a Timestamp for consistency
  Map<String, dynamic> toMap() => {
    'id': id,
    'senderId': senderId,
    'text': text,
    'timestamp': Timestamp.fromDate(timestamp.toUtc()),
  };

  // Read from a Firestore document map safely (handles Timestamp, DateTime, int, String, or null)
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final dynamic ts = map['timestamp'];

    DateTime parsedTimestamp;
    if (ts is Timestamp) {
      parsedTimestamp = ts.toDate();
    } else if (ts is DateTime) {
      parsedTimestamp = ts;
    } else if (ts is int) {
      // assume milliseconds since epoch
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(ts);
    } else if (ts is String) {
      parsedTimestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      // fallback to now if not present or unrecognized
      parsedTimestamp = DateTime.now();
    }

    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: parsedTimestamp,
    );
  }
}
