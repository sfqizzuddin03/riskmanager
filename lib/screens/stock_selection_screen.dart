import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_layout.dart'; // ✅ Point to the correct MainLayout
import '../services/database_service.dart'; // ✅ Import your database service

class StockSelectionScreen extends StatefulWidget {
  const StockSelectionScreen({super.key});

  @override
  State<StockSelectionScreen> createState() => _StockSelectionScreenState();
}

class _StockSelectionScreenState extends State<StockSelectionScreen> {
  bool _isSaving = false; // To show a loading spinner while saving

  final List<Map<String, dynamic>> _availableStocks = [
    {'symbol': 'AAPL', 'name': 'Apple Inc.', 'selected': false},
    {'symbol': 'MSFT', 'name': 'Microsoft Corporation', 'selected': false},
    {'symbol': 'GOOGL', 'name': 'Alphabet Inc.', 'selected': false},
    {'symbol': 'TSLA', 'name': 'Tesla, Inc.', 'selected': false},
    {'symbol': 'AMZN', 'name': 'Amazon.com Inc.', 'selected': false},
    {'symbol': 'META', 'name': 'Meta Platforms Inc.', 'selected': false},
    {'symbol': 'NVDA', 'name': 'NVIDIA Corporation', 'selected': false},
    {'symbol': 'JPM', 'name': 'JPMorgan Chase & Co.', 'selected': false},
  ];

  void _toggleStock(int index) {
    setState(() {
      _availableStocks[index]['selected'] = !_availableStocks[index]['selected'];
    });
  }

  // --- UPDATED LOGIC ---
  Future<void> _proceedToDashboard() async {
    final selectedStocks = _availableStocks.where((stock) => stock['selected']).toList();
    
    if (selectedStocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one stock')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Save directly to Firestore using your Service
        // We extract just the symbol strings ['AAPL', 'MSFT']
        List<String> symbols = selectedStocks.map((s) => s['symbol'] as String).toList();
        await DatabaseService.saveWatchlist(user.uid, symbols);
      }

      // 2. Navigate to MainLayout (The new Home)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()), 
        );
      }
    } catch (e) {
      print(e);
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Stocks to Monitor')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Choose stocks for your risk management portfolio',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _availableStocks.length,
              itemBuilder: (context, index) {
                final stock = _availableStocks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: stock['selected'] ? Colors.blue[50] : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(stock['symbol'].substring(0, 2)),
                    ),
                    title: Text(stock['symbol']),
                    subtitle: Text(stock['name']),
                    trailing: Icon(
                      stock['selected'] ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: stock['selected'] ? Colors.blue : Colors.grey,
                    ),
                    onTap: () => _toggleStock(index),
                  ),
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _proceedToDashboard, // Disable if saving
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Start Risk Management'),
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}