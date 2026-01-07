import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'trading_chart_screen.dart'; 

class WatchlistScreen extends StatelessWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text("Live Market"), backgroundColor: Colors.purple.shade800),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 1. Get the list of symbols from Firestore
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final watchlist = List<String>.from(data?['watchlist'] ?? []);

          if (watchlist.isEmpty) return const Center(child: Text("Watchlist is empty"));

          // 2. Build a list of "Smart Tiles" that fetch their own data
          return ListView.builder(
            itemCount: watchlist.length,
            itemBuilder: (context, index) {
              return StockTickerTile(symbol: watchlist[index]);
            },
          );
        },
      ),
    );
  }
}

// --- NEW COMPONENT: FETCHES REAL DATA FOR ONE STOCK ---
class StockTickerTile extends StatefulWidget {
  final String symbol;
  const StockTickerTile({super.key, required this.symbol});

  @override
  State<StockTickerTile> createState() => _StockTickerTileState();
}

class _StockTickerTileState extends State<StockTickerTile> {
  double price = 0.0;
  double percentChange = 0.0;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchLivePrice();
  }

  Future<void> _fetchLivePrice() async {
    // *** ENTER YOUR API KEY HERE ***
    const String apiKey = "cu2489pr01qmnc308060cu2489pr01qmnc30806g"; // Example: Finnhub Key
    
    try {
      // Using Finnhub API as an example (It's free and fast)
      final url = Uri.parse('https://finnhub.io/api/v1/quote?symbol=${widget.symbol}&token=$apiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            price = (data['c'] as num).toDouble(); // 'c' is Current Price
            percentChange = (data['dp'] as num).toDouble(); // 'dp' is Percent Change
            isLoading = false;
          });
        }
      } else {
        throw Exception("Failed to load");
      }
    } catch (e) {
      if (mounted) setState(() { hasError = true; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Text(widget.symbol[0]),
        ),
        title: Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
        
        // --- THE PRICE SECTION ---
        trailing: isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : hasError 
                ? const Icon(Icons.error, color: Colors.red)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("\$${price.toStringAsFixed(2)}", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        "${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(2)}%", 
                        style: TextStyle(
                          color: percentChange >= 0 ? Colors.green : Colors.red, 
                          fontSize: 12,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ],
                  ),

        // --- CLICK TO OPEN CHART ---
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TradingChartScreen(symbol: widget.symbol),
            ),
          );
        },
      ),
    );
  }
}