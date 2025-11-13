import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Register a new user (Firestore only - bypass Firebase Auth type casting issue)
  Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      print('AuthService: Starting Firestore-only registration for $email'); // Debug
      
      // Check if user already exists in Firestore first
      print('AuthService: Checking if user already exists...'); // Debug
      QuerySnapshot existingUsers = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (existingUsers.docs.isNotEmpty) {
        print('AuthService: User already exists in Firestore'); // Debug
        return 'User already exists';
      }
      
      // Create user directly in Firestore (bypass Firebase Auth)
      print('AuthService: Creating user document in Firestore...'); // Debug
      String uid = 'user_${DateTime.now().millisecondsSinceEpoch}';
      
      // Normalize role to lowercase for consistency
      String normalizedRole = role.toLowerCase().trim();
      
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': normalizedRole,
        'isVisible': false,
        'createdAt': FieldValue.serverTimestamp(),
        'password': password, // Store password temporarily (in production, hash this)
      });

      print('AuthService: User registration completed successfully'); // Debug
      return null; // success
    } catch (e) {
      print('AuthService: Registration error: $e'); // Debug
      return 'Registration failed: ${e.toString()}';
    }
  }

  /// Create test user directly in Firestore
  Future<String?> createTestUser({
    required String name,
    required String email,
    required String role,
  }) async {
    try {
      print('AuthService: Creating test user in Firestore for $email'); // Debug
      
      String uid = 'test_${DateTime.now().millisecondsSinceEpoch}';
      
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'role': role,
        'isVisible': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('AuthService: Test user created successfully'); // Debug
      return null; // success
    } catch (e) {
      print('AuthService: Failed to create test user: $e'); // Debug
      return 'Failed to create test user: $e';
    }
  }

  /// Login user (Firestore only - bypass Firebase Auth type casting issue)
  Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('AuthService: Starting Firestore-only login for $email'); // Debug
      
      // Query Firestore directly for user with matching email
      QuerySnapshot userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        print('AuthService: No user found with email $email'); // Debug
        return null;
      }

      var userData = userQuery.docs.first.data() as Map<String, dynamic>;
      print('AuthService: Found user in Firestore: ${userData['name']}'); // Debug
      
      // Check password if it exists in the document
      if (userData.containsKey('password')) {
        String storedPassword = userData['password'] ?? '';
        if (storedPassword != password) {
          print('AuthService: Password mismatch'); // Debug
          return null;
        }
      }
      
      print('AuthService: Login successful'); // Debug
      print('AuthService: User role from Firestore: ${userData['role']}'); // Debug role
      
      // Remove password from returned data for security
      userData.remove('password');
      
      return userData;
    } catch (e) {
      print("AuthService: Firestore login error: $e");
      return null;
    }
  }

  /// Get the current user profile (Firestore-only approach)
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      // Since we're using Firestore-only auth, we need to store the current user ID somewhere
      // For now, we'll return null and handle authentication differently in the UI
      // In a production app, you'd store the current user ID in SharedPreferences or similar
      print("AuthService: getCurrentUserProfile called - using Firestore-only auth");
      return null;
    } catch (e) {
      print("AuthService: Error getting current user: $e");
      return null;
    }
  }

  /// Store current user session (for Firestore-only auth)
  static Map<String, dynamic>? _currentUser;
  
  static void setCurrentUser(Map<String, dynamic> user) {
    _currentUser = user;
  }
  
  static Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }
  
  static void clearCurrentUser() {
    _currentUser = null;
  }

  /// 🔹 Sign out (clear session)
  Future<void> signOut() async {
    try {
      // If you still use FirebaseAuth for session, sign out from it:
      await _auth.signOut();

      // If you only use Firestore (no FirebaseAuth),
      // you can just clear any local session storage here.
      print("User signed out successfully");
    } catch (e) {
      print("Sign out error: $e");
    }
  }
}
