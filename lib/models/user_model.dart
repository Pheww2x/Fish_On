import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // 'fisherman' or 'buyer'
  final bool isVisible;
  final GeoPoint? location;
  final String? photoUrl;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.isVisible = false,
    this.location,
    this.photoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'isVisible': isVisible,
      'location': location,
      'photoUrl': photoUrl,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'buyer',
      isVisible: map['isVisible'] ?? false,
      location: map['location'],
      photoUrl: map['photoUrl'],
    );
  }

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    String? role,
    bool? isVisible,
    GeoPoint? location,
    String? photoUrl,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      isVisible: isVisible ?? this.isVisible,
      location: location ?? this.location,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
