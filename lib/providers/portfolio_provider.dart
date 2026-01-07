import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase
import '../models/portfolio.dart';
import '../services/database_service.dart';

class PortfolioProvider with ChangeNotifier {
  List<PortfolioPosition> _positions = [];

  List<PortfolioPosition> get positions => _positions;

  // Get current User ID safely
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  Future<void> loadPortfolio() async {
    // Pass the User ID to load ONLY this user's data
    final data = await DatabaseService.loadPortfolio(_userId);
    
    _positions = data.map((item) => PortfolioPosition(
      symbol: item['symbol'],
      companyName: item['symbol'], 
      shares: item['shares'],
      entryPrice: item['entryPrice'],
      currentPrice: item['entryPrice'], 
      entryDate: DateTime.now(),
    )).toList();
    notifyListeners();
  }

  void addPosition(PortfolioPosition position) {
    _positions.add(position);
    _saveToStorage();
    notifyListeners();
  }

  void removePosition(int index) {
    _positions.removeAt(index);
    _saveToStorage();
    notifyListeners();
  }

  void _saveToStorage() {
    final List<Map<String, dynamic>> data = _positions.map((p) => {
      'symbol': p.symbol,
      'shares': p.shares,
      'entryPrice': p.entryPrice,
    }).toList();
    // Pass User ID to save
    DatabaseService.savePortfolio(_userId, data);
  }
  
  // Clear data (useful when logging out)
  void clearData() {
    _positions = [];
    notifyListeners();
  }
}