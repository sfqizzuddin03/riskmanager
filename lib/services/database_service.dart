import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  // Use the main Firestore instance
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==============================================================================
  // 1. PORTFOLIO (The Money)
  // ==============================================================================
  static Future<void> savePortfolio(String userId, List<Map<String, dynamic>> portfolio) async {
    try {
      final validItems = portfolio.where((item) => 
        item['symbol'] != null && item['symbol'].toString().isNotEmpty
      ).toList();

      await _db.collection('users').doc(userId).set({
        'portfolio': validItems,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error saving portfolio: $e");
    }
  }

  static Future<List<Map<String, dynamic>>> loadPortfolio(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('portfolio')) {
          List<dynamic> rawList = data['portfolio'];
          return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
        }
      }
    } catch (e) {
      print("Error loading portfolio: $e");
    }
    return [];
  }

  // ==============================================================================
  // 2. TRANSACTIONS (The History - NEW PROFESSIONAL FEATURE)
  // ==============================================================================
  // This creates a separate sub-collection so your history can grow forever
  static Future<void> logTransaction(String userId, {
    required String symbol,
    required String type, // "BUY" or "SELL"
    required int shares,
    required double price,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('transactions') // Sub-collection
          .add({
        'symbol': symbol,
        'type': type,
        'shares': shares,
        'price': price,
        'totalValue': shares * price,
        'date': FieldValue.serverTimestamp(), // Server time is accurate
      });
    } catch (e) {
      print("Error logging transaction: $e");
    }
  }

  // ==============================================================================
  // 3. WATCHLIST (The Interest)
  // ==============================================================================
  static Future<void> saveWatchlist(String userId, List<String> symbols) async {
    try {
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

  // ==============================================================================
  // 4. RISK SETTINGS (The Preferences - NEW PROFESSIONAL FEATURE)
  // ==============================================================================
  // Saves your Dashboard toggles (RSI, MACD, etc.) so they persist
  static Future<void> saveRiskSettings(String userId, {
    required bool showRSI,
    required bool showMACD,
    required bool showBollinger,
    required bool showATR,
    required bool showSentiment,
    required bool showVolume,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(userId)
          .collection('settings') // Sub-collection for cleaner organization
          .doc('risk_prefs')
          .set({
        'showRSI': showRSI,
        'showMACD': showMACD,
        'showBollinger': showBollinger,
        'showATR': showATR,
        'showSentiment': showSentiment,
        'showVolume': showVolume,
      });
    } catch (e) {
      print("Error saving risk settings: $e");
    }
  }

  static Future<Map<String, dynamic>> getRiskSettings(String userId) async {
    try {
      final doc = await _db
          .collection('users')
          .doc(userId)
          .collection('settings')
          .doc('risk_prefs')
          .get();
      return doc.data() ?? {};
    } catch (e) {
      print("Error loading risk settings: $e");
    }
    return {};
  }

  // ==============================================================================
  // 5. PROFILE & APP SETTINGS (General)
  // ==============================================================================
  static Future<void> saveProfileImage(String userId, String path) async {
    await _db.collection('users').doc(userId).set({
      'profile_image': path,
    }, SetOptions(merge: true));
  }

  static Future<String?> loadProfileImage(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?; // Safety check
        return data?['profile_image'] as String?;
      }
    } catch (e) {
      print("Error loading profile image: $e");
    }
    return null;
  }

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
    
    // Default settings
    return {
      'darkMode': false,
      'currency': 'USD',
      'notifications': true,
    };
  }
}