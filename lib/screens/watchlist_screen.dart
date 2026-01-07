import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/risk_calculator.dart';
import 'trading_chart_screen.dart'; 

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<Map<String, dynamic>> _stockData = [];
  bool _isLoading = true;
  int _realDataCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchWatchlistData();
  }

  Future<void> _fetchWatchlistData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Get Symbols from Firestore
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final watchlist = List<String>.from(data['watchlist'] ?? []);
    
    List<Map<String, dynamic>> tempList = [];
    int successCount = 0;

    // 2. Fetch Live Data for each symbol
    for (String symbol in watchlist) {
      final details = await RiskCalculator.getStockDetails(symbol);
      
      bool isReal = details.isNotEmpty;
      if (isReal) successCount++;

      tempList.add({
        'symbol': symbol,
        'name': 'Stock Equity', // Yahoo doesn't give names easily, so we use generic
        'price': details['price'] ?? 0.0,
        'changePercent': details['percent'] ?? 0.0,
        'isRealData': isReal,
      });
    }

    if (mounted) {
      setState(() {
        _stockData = tempList;
        _realDataCount = successCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_stockData.isEmpty) {
      return const Scaffold(body: Center(child: Text("Watchlist is empty")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Watchlist"),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- HEADER SHOWING DATA STATUS (From your code) ---
          Container(
            padding: const EdgeInsets.all(12),
            color: _realDataCount > 0 ? Colors.green[50] : Colors.orange[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _realDataCount > 0 ? Icons.wifi : Icons.signal_wifi_off,
                  color: _realDataCount > 0 ? Colors.green : Colors.orange,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _realDataCount > 0 
                    ? 'LIVE DATA: $_realDataCount/${_stockData.length} stocks'
                    : 'DEMO DATA: Check internet connection',
                  style: TextStyle(
                    color: _realDataCount > 0 ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // --- STOCK LIST ---
          Expanded(
            child: ListView.builder(
              itemCount: _stockData.length,
              itemBuilder: (context, index) {
                final stock = _stockData[index];
                
                final changePercent = stock['changePercent'] as double;
                final isPositive = changePercent >= 0;
                final isRealData = stock['isRealData'] as bool;
                final price = stock['price'] as double;
                final symbol = stock['symbol'] as String;
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPositive ? Colors.green.shade100 : Colors.red.shade100,
                      child: Text(
                        symbol.length > 2 ? symbol.substring(0, 2) : symbol,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        if (isRealData) 
                          const Icon(Icons.wifi, size: 14, color: Colors.green),
                        if (!isRealData)
                          const Icon(Icons.computer, size: 14, color: Colors.orange),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stock['name']),
                        Text(
                          isRealData ? 'Live Market Data' : 'Demo Data',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRealData ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: isPositive ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                    
                    // --- NAVIGATION TO TRADINGVIEW ---
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TradingChartScreen(
                            symbol: symbol,
                          ),
                        ),
                      );
                    },
                  ), 
                ); 
              },
            ),
          ),
        ],
      ),
    );
  }
}