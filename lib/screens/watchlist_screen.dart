import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/risk_calculator.dart';
import 'trading_chart_screen.dart'; // <--- CRITICAL IMPORT

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<Map<String, dynamic>> _watchlistData = [];
  List<String> _rawSymbols = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
  }

  Future<void> _fetchWatchlist() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final symbols = await DatabaseService.loadWatchlist(user.uid);
    _rawSymbols = symbols;

    List<Map<String, dynamic>> tempList = [];

    for (String symbol in symbols) {
      final details = await RiskCalculator.getStockDetails(symbol);
      
      tempList.add({
        'symbol': symbol,
        'price': details['price'] ?? 0.0,
        'change': details['change'] ?? 0.0,
        'percent': details['percent'] ?? 0.0,
        'isReal': true, // Assuming RiskCalculator returns live data
      });
    }

    if (mounted) {
      setState(() {
        _watchlistData = tempList;
        _isLoading = false;
      });
    }
  }

  Future<void> _addSymbol(String symbol) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || symbol.isEmpty) return;
    if (_rawSymbols.contains(symbol.toUpperCase())) return;

    setState(() => _isLoading = true);
    _rawSymbols.add(symbol.toUpperCase());
    await DatabaseService.saveWatchlist(user.uid, _rawSymbols);
    await _fetchWatchlist();
  }

  Future<void> _removeSymbol(String symbol) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _rawSymbols.remove(symbol);
    await DatabaseService.saveWatchlist(user.uid, _rawSymbols);
    
    setState(() {
      _watchlistData.removeWhere((item) => item['symbol'] == symbol);
    });
  }

  void _showAddDialog() {
    String inputSymbol = "";
    // Dark mode logic for dialog
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDarkMode ? Colors.grey[900] : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey[500] : Colors.grey[400];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text("Add to Watchlist", style: TextStyle(color: textColor)),
        content: TextField(
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: "e.g. NVDA",
            hintStyle: TextStyle(color: hintColor),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueGrey)),
          ),
          onChanged: (val) => inputSymbol = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
            onPressed: () {
              Navigator.pop(context);
              if (inputSymbol.isNotEmpty) _addSymbol(inputSymbol);
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- DARK MODE COLORS ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final Color bgColor = isDarkMode ? Colors.black : Colors.grey[100]!;
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Market Watch", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: textColor),
            onPressed: _showAddDialog,
            tooltip: "Add Stock",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _watchlistData.isEmpty
              ? _buildEmptyState(textColor)
              : RefreshIndicator(
                  onRefresh: _fetchWatchlist,
                  child: ListView.builder(
                    itemCount: _watchlistData.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final stock = _watchlistData[index];
                      return _buildWatchlistCard(stock, cardColor, textColor, subTextColor);
                    },
                  ),
                ),
    );
  }

  Widget _buildWatchlistCard(Map<String, dynamic> stock, Color cardColor, Color textColor, Color subTextColor) {
    String symbol = stock['symbol'];
    double price = stock['price'];
    double percent = stock['percent'];
    bool isPositive = percent >= 0;

    return Dismissible(
      key: Key(symbol),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeSymbol(symbol),
      child: Card(
        color: cardColor,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          
          // --- 1. LEFT: SYMBOL & LIVE BADGE ---
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text("LIVE", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              const SizedBox(height: 4),
              Text(
                symbol.substring(0, 1), 
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)
              ),
            ],
          ),

          // --- 2. MIDDLE: NAME ---
          title: Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          subtitle: Text("Real-time Data", style: TextStyle(fontSize: 10, color: subTextColor)),

          // --- 3. RIGHT: PRICE ---
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("\$${price.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${percent.toStringAsFixed(2)}%",
                    style: TextStyle(
                      color: isPositive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // --- 4. TAP TO OPEN CHART (RESTORED) ---
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TradingChartScreen(symbol: symbol),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility_off_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 20),
          Text("Watchlist is empty", style: TextStyle(color: textColor, fontSize: 18)),
          TextButton(onPressed: _showAddDialog, child: const Text("Add a stock to watch"))
        ],
      ),
    );
  }
}