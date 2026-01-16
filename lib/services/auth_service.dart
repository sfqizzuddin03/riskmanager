import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Sign In (Checks Real Firebase Database)
  Future<bool> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _saveUserLocally(email); // Save email for settings
      return true;
    } catch (e) {
      throw Exception('Login failed. Check your email/password.');
    }
  }

  // Register user 
  Future<bool> register(String email, String password, double initialCapital) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await _saveUserLocally(email);
      
      // Save initial capital locally 
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('initial_capital', initialCapital);
      
      return true;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}'); 
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
  }

  // 4. Check Login Status
  bool get isLoggedIn => _auth.currentUser != null;

  // Helper to save minimal info for the UI
  Future<void> _saveUserLocally(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_email', email);
    await prefs.setString('user_id', _auth.currentUser?.uid ?? '');
  }

  // Get user info for Settings Page
  static Future<Map<String, dynamic>> getUserPrefs() async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    return {
      'user_id': user?.uid ?? '',
      'user_email': user?.email ?? 'No Email',
      'initial_capital': prefs.getDouble('initial_capital') ?? 10000.0,
    };
  }
}