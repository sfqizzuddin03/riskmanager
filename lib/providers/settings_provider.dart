import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Default States
  bool _isDarkMode = false;
  String _currency = 'USD';
  bool _notificationsEnabled = true;
  double _conversionRate = 1.0;

  // Getters
  bool get isDarkMode => _isDarkMode;
  String get currency => _currency;
  bool get notificationsEnabled => _notificationsEnabled;
  double get conversionRate => _conversionRate;

  SettingsProvider() {
    _loadFromPrefs();
  }

  // Load saved settings
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;
    _currency = prefs.getString('currency') ?? 'USD';
    _notificationsEnabled = prefs.getBool('notifications') ?? true;
    _updateConversionRate();
    notifyListeners();
  }

  // Toggle Dark Mode (Real)
  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    notifyListeners();
  }

  // Change Currency (Real-ish: Uses fixed rates for demo)
  void setCurrency(String value) async {
    _currency = value;
    _updateConversionRate();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', value);
    notifyListeners();
  }

  // Toggle Notifications
  void toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    notifyListeners();
  }

  // Helper to set conversion rate
  void _updateConversionRate() {
    switch (_currency) {
      case 'EUR': _conversionRate = 0.92; break;
      case 'GBP': _conversionRate = 0.79; break;
      case 'MYR': _conversionRate = 4.72; break; // Malaysian Ringgit
      default: _conversionRate = 1.0;
    }
  }
}