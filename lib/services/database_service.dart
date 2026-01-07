import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  // Use the main Firestore instance
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- BUCKET 1: PORTFOLIO (The Money) ---
  static Future<void> savePortfolio(String userId, List<Map<String, dynamic>> portfolio) async {
    try {
      // SANITIZER: Only save valid items
      final validItems = portfolio.where((item) => 
        item['symbol'] != null && item['symbol'].toString().isNotEmpty
      ).toList();

      // Firestore saves Lists of Maps natively! No need for CSV strings.
      await _db.collection('users').doc(userId).set({
        'portfolio': validItems,
      }, SetOptions(merge: true)); // merge: true keeps other data safe
    } catch (e) {
      print("Error saving portfolio to Firestore: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> loadPortfolio(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('portfolio')) {
          // Convert generic List to List<Map>
          List<dynamic> rawList = data['portfolio'];
          return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      print("Error loading portfolio from Firestore: $e");
    }
    return []; // Return empty list if nothing found
  }

  // --- BUCKET 2: WATCHLIST (The Interest) ---
  static Future<void> saveWatchlist(String userId, List<String> symbols) async {
    try {
      // Remove duplicates and empty strings
      final cleanList = symbols
          .where((s) => s.isNotEmpty)
          .map((s) => s.toUpperCase())
          .toSet()
          .toList();
      
      await _db.collection('users').doc(userId).set({
        'watchlist': cleanList,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving watchlist: $e");
    }
  }

  static Future<List<String>> loadWatchlist(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('watchlist')) {
          return List<String>.from(data['watchlist']);
        }
      }
    } catch (e) {
      print("Error loading watchlist: $e");
    }
    return [];
  }

  // --- BUCKET 3: PROFILE (The User) ---
  // Note: We still save the path string, but in a real app you'd use Firebase Storage.
  // For this deadline, saving the path string to Firestore is fine.
  static Future<void> saveProfileImage(String userId, String path) async {
    await _db.collection('users').doc(userId).set({
      'profile_image': path,
    }, SetOptions(merge: true));
  }

  static Future<String?> loadProfileImage(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['profile_image'] as String?;
      }
    } catch (e) {
      print("Error loading profile image: $e");
    }
    return null;
  }

  // --- BUCKET 4: SETTINGS (The Preferences) ---
  static Future<void> saveSettings(String userId, Map<String, dynamic> settings) async {
    await _db.collection('users').doc(userId).set({
      'settings': settings,
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>> loadSettings(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('settings')) {
          return Map<String, dynamic>.from(data['settings']);
        }
      }
    } catch (e) {
      print("Error loading settings: $e");
    }
    
    // Default settings if none exist
    return {
      'darkMode': false,
      'currency': 'USD',
      'notifications': true,
    };
  }
}