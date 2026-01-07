import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'watchlist_screen.dart';
import 'risk_dashboard.dart';
import 'position_management.dart';
import 'settings_screen.dart'; 
import '../services/stock_services.dart';
import '../services/database_service.dart';

class MainScreen extends StatefulWidget {
  // FIX: This definition must be here for the code to work
  final List<Map<String, dynamic>> selectedStocks;

  const MainScreen({super.key, required this.selectedStocks});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<Map<String, dynamic>> _userStocks = [];
  bool _isLoading = true;
  String? _profileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Load Profile Picture
    final imagePath = await DatabaseService.loadProfileImage(user.uid);

    // 2. Load Watchlist
    List<String> savedSymbols = await DatabaseService.loadWatchlist(user.uid);
    
    // If no saved watchlist, use the ones passed from previous screen
    if (savedSymbols.isEmpty && widget.selectedStocks.isNotEmpty) {
      savedSymbols = widget.selectedStocks.map((s) => s['symbol'] as String).toList();
      await DatabaseService.saveWatchlist(user.uid, savedSymbols);
    }

    if (savedSymbols.isNotEmpty) {
      try {
        final realStockData = await StockService.getMultipleStockQuotes(savedSymbols);
        _userStocks = realStockData;
      } catch (e) {
        print("Error loading stocks: $e");
      }
    }

    if (mounted) {
      setState(() {
        _profileImagePath = imagePath;
        _isLoading = false;
      });
    }
  }

  void _addNewStock() async {
    TextEditingController symbolController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add to Watchlist"),
        content: TextField(
          controller: symbolController,
          decoration: const InputDecoration(labelText: "Stock Symbol (e.g. AAPL)", border: OutlineInputBorder()),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final symbol = symbolController.text.trim().toUpperCase();
              if (symbol.isNotEmpty) {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  final newStock = await StockService.getMultipleStockQuotes([symbol]);
                  if (newStock.isNotEmpty) {
                    setState(() => _userStocks.add(newStock.first));
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final allSymbols = _userStocks.map((s) => s['symbol'] as String).toList();
                      await DatabaseService.saveWatchlist(user.uid, allSymbols);
                    }
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Symbol")));
                }
                setState(() => _isLoading = false);
              }
            },
            child: const Text("Add"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(_currentIndex)),
        centerTitle: true,
        actions: [
          if (_currentIndex == 0)
            IconButton(icon: const Icon(Icons.add), onPressed: _addNewStock),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadUserData,
          ),
          
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => setState(() => _currentIndex = 3),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: _profileImagePath != null 
                    ? FileImage(File(_profileImagePath!)) 
                    : null,
                child: _profileImagePath == null 
                    ? const Icon(Icons.person, color: Colors.grey) 
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed, 
        // FIX: 'items' parameter was likely missing or broken in your previous code
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Watchlist'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Risk'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Portfolio'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0: return 'Watchlist';
      case 1: return 'Risk Dashboard';
      case 2: return 'Portfolio';
      case 3: return 'Settings';
      default: return 'Investive';
    }
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      // FIX 1: Remove (userStocks: _userStocks)
      case 0: return const WatchlistScreen(); 

      // FIX 2: Do the same for RiskDashboard (unless you explicitly changed it)
      case 1: return const RiskDashboard(); 

      case 2: return const PositionManagementScreen();
      case 3: return const SettingsScreen();
      default: return const SizedBox.shrink();
    }
}
}