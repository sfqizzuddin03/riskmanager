import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseService {
  // Use the main Firestore instance
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ... inside DatabaseService class ...

  // --- BUCKET 0: USER METADATA (The "Legit" Fields) ---
  static Future<void> syncUserData(User user) async {
    final userDoc = _db.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();
    
    if (!snapshot.exists) {
      // New User: Create full profile
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? 'Trader',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'accountStatus': 'active', 
        'role': 'user',            
      });
    } else {
      // Existing User: Just update login time
      await userDoc.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==============================================================================
  // 1. PORTFOLIO (The Money)
  // ==============================================================================
  
  // NEW: Add a single stock (Cleaner than doing it in the UI)
  static Future<void> addStockToPortfolio(String userId, Map<String, dynamic> stockData) async {
    try {
      await _db.collection('users').doc(userId).update({
        'portfolio': FieldValue.arrayUnion([stockData])
      });
    } catch (e) {
      print("Error adding stock: $e");
      throw e; // Throw so UI knows it failed
    }
  }

  // NEW: Remove a single stock
  static Future<void> removeStockFromPortfolio(String userId, Map<String, dynamic> stockData) async {
    try {
      await _db.collection('users').doc(userId).update({
        'portfolio': FieldValue.arrayRemove([stockData])
      });
    } catch (e) {
      print("Error removing stock: $e");
    }
  }

  // Load all stocks
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
          .collection('transactions')
          .add({
        'symbol': symbol,
        'type': type,
        'shares': shares,
        'price': price,
        'totalValue': shares * price,
        'date': FieldValue.serverTimestamp(),
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
  // 4. RISK SETTINGS (Preferences)
  // ==============================================================================
    static Future<void> saveRiskSettings(String userId, {
      required bool showRSI,
      required bool showMACD,
      required bool showBollinger,
      required bool showATR,
      required bool showSMA,
      required bool showEMA,
      required bool showStoch,
      required bool showCCI,
      required bool showWilliams,
    }) async {
      try {
        await _db
            .collection('users')
            .doc(userId)
            .collection('settings')
            .doc('risk_prefs')
            .set({
          'showRSI': showRSI,
          'showMACD': showMACD,
          'showBollinger': showBollinger,
          'showATR': showATR,
          'showSMA': showSMA,
          'showEMA': showEMA,
          'showStoch': showStoch,
          'showCCI': showCCI,
          'showWilliams': showWilliams,
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
  // 5. PROFILE & SETTINGS
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
        final data = doc.data() as Map<String, dynamic>?;
        return data?['profile_image'] as String?;
      }
    } catch (e) {
      print("Error loading profile image: $e");
    }
    return null;
  }


  // --- BUCKET 6: GLOBAL ASSETS (The "Legit" Data Fetcher) ---
  // Returns a list of stocks supported by the app
  static Future<List<String>> getSupportedAssets() async {
    try {
      // 1. Try to fetch from the "Legit" Firestore collection first
      final snapshot = await _db.collection('assets').get();
      
      if (snapshot.docs.isNotEmpty) {
        // Return the list of Document IDs (AAPL, TSLA, etc.)
        return snapshot.docs.map((d) => d.id).toList();
      }
    } catch (e) {
      print("Error loading assets from DB: $e");
    }
    
    // 2. Fallback: If DB is empty or fails, use this hardcoded list so app doesn't crash
    return ['AAPL', 'TSLA', 'GOOGL', 'MSFT', 'AMZN', 'NVDA', 'META', 'NFLX', 'AMD', 'INTC'];
  }

  




}