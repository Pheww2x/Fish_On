import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Convert image to base64 for Firestore storage (Free plan alternative)
  /// Compresses image to keep within Firestore document limits
  Future<String> convertImageToBase64(File imageFile) async {
    try {
      print('Converting image to base64...');
      
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      
      // Decode and resize the image to reduce size
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Resize to max 400x400 to keep base64 string small
      final resized = img.copyResize(
        originalImage,
        width: 400,
        height: 400,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode as JPEG with 75% quality
      final compressedBytes = img.encodeJpg(resized, quality: 75);
      
      // Convert to base64
      final base64String = base64Encode(compressedBytes);
      
      print('Image converted to base64. Size: ${base64String.length} chars');
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      print('Error converting image to base64: $e');
      throw Exception('Failed to process image: ${e.toString()}');
    }
  }

  /// Upload profile picture to Firebase Storage
  /// Returns the download URL of the uploaded image
  /// Throws exception with detailed error message on failure
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    try {
      print('Starting profile picture upload for user: $userId');
      print('File path: ${imageFile.path}');
      print('File exists: ${await imageFile.exists()}');
      
      // Create a reference to the storage location
      final ref = _storage.ref().child('profile_pictures/$userId.jpg');
      
      // Upload the file
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'userId': userId},
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Profile picture uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (e.toString().contains('permission-denied') || e.toString().contains('unauthorized')) {
        throw Exception('Firebase Storage permission denied. Please configure Storage rules in Firebase Console.');
      } else if (e.toString().contains('network')) {
        throw Exception('Network error. Please check your internet connection.');
      } else {
        throw Exception('Upload failed: ${e.toString()}');
      }
    }
  }

  /// Delete profile picture from Firebase Storage
  Future<bool> deleteProfilePicture(String userId) async {
    try {
      final ref = _storage.ref().child('profile_pictures/$userId.jpg');
      await ref.delete();
      print('Profile picture deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting profile picture: $e');
      return false;
    }
  }

  /// Upload fish image to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String?> uploadFishImage(String fishId, File imageFile) async {
    try {
      final ref = _storage.ref().child('fish_images/$fishId.jpg');
      
      final uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'fishId': fishId},
        ),
      );

      final snapshot = await uploadTask.whenComplete(() => null);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Fish image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Error uploading fish image: $e');
      return null;
    }
  }
}
