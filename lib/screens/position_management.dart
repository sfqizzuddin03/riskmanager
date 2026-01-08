import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/risk_calculator.dart';

class PositionManagementScreen extends StatefulWidget {
  const PositionManagementScreen({super.key});

  @override
  State<PositionManagementScreen> createState() => _PositionManagementScreenState();
}

class _PositionManagementScreenState extends State<PositionManagementScreen> {
  final TextEditingController _sharesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _selectedSymbol;
  bool _isLoading = false;

  final List<String> _commonStocks = [
    'AAPL', 'TSLA', 'GOOGL', 'MSFT', 'AMZN', 'NVDA', 'META', 'NFLX', 'AMD', 'INTC'
  ];

  Future<void> _onSymbolChanged(String? symbol) async {
    setState(() => _selectedSymbol = symbol);
    if (symbol != null) {
      final details = await RiskCalculator.getStockDetails(symbol);
      if (details.containsKey('price')) {
        _priceController.text = details['price'].toString();
      }
    }
  }

  Future<void> _addPosition() async {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final symbol = _selectedSymbol;
    final user = FirebaseAuth.instance.currentUser;

    if (symbol == null || shares <= 0 || price <= 0 || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check your inputs'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newPosition = {
        'symbol': symbol,
        'name': 'Stock Equity', 
        'shares': shares,
        'entryPrice': price,
        'averagePrice': price,
        'entryDate': DateTime.now().toIso8601String(),
        'isRealData': true, 
      };

      await DatabaseService.addStockToPortfolio(user.uid, newPosition);
      
      await DatabaseService.logTransaction(
        user.uid,
        symbol: symbol,
        type: "BUY",
        shares: shares,
        price: price,
      );

      _sharesController.clear();
      _priceController.clear();
      setState(() => _selectedSymbol = null);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bought $shares of $symbol'), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removePosition(Map<String, dynamic> position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await DatabaseService.removeStockFromPortfolio(user.uid, position);

    await DatabaseService.logTransaction(
      user.uid,
      symbol: position['symbol'],
      type: "SELL",
      shares: position['shares'] as int,
      price: (position['entryPrice'] as num).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- DARK MODE LOGIC ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.grey[100]!;
    final cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final inputFillColor = isDarkMode ? Colors.grey[800] : Colors.grey[50];
    // -----------------------

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Manage Assets", style: TextStyle(color: textColor)),
        backgroundColor: cardColor,
        foregroundColor: textColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      backgroundColor: bgColor,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final portfolio = List<Map<String, dynamic>>.from(data?['portfolio'] ?? []);

          return Column(
            children: [
              // Pass colors to sub-widgets
              _buildInputCard(cardColor, textColor, inputFillColor),
              
              if (_isLoading) const LinearProgressIndicator(),

              Expanded(
                child: portfolio.isEmpty 
                  ? _buildEmptyState(textColor)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: portfolio.length,
                      itemBuilder: (context, index) {
                        return _buildAssetItem(portfolio[index], cardColor, textColor);
                      },
                    ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildInputCard(Color cardColor, Color textColor, Color? fillColor) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Add New Asset", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 15),
          
          DropdownButtonFormField<String>(
            value: _selectedSymbol,
            dropdownColor: cardColor, // Fix dropdown menu color
            decoration: InputDecoration(
              labelText: "Select Symbol",
              labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
              filled: true,
              fillColor: fillColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixIcon: Icon(Icons.search, color: textColor),
            ),
            items: _commonStocks.map((s) => DropdownMenuItem(
              value: s, 
              child: Text(s, style: TextStyle(color: textColor)) // Fix dropdown text color
            )).toList(),
            onChanged: _onSymbolChanged,
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sharesController,
                  style: TextStyle(color: textColor),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Shares",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  style: TextStyle(color: textColor),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Price (\$)",
                    labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                    filled: true,
                    fillColor: fillColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _isLoading ? null : _addPosition,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey.shade900,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Buy Asset", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildAssetItem(Map<String, dynamic> pos, Color cardColor, Color textColor) {
    final symbol = pos['symbol'] as String;
    final shares = pos['shares'] as int;
    final price = (pos['entryPrice'] as num).toDouble();

    return Dismissible(
      key: Key(symbol + shares.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
      onDismissed: (_) => _removePosition(pos),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(symbol[0], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          title: Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text("$shares shares", style: TextStyle(color: textColor.withOpacity(0.6))),
          trailing: Text("\$${price.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: textColor.withOpacity(0.3)),
          const SizedBox(height: 10),
          Text("No assets in portfolio", style: TextStyle(color: textColor.withOpacity(0.5))),
        ],
      ),
    );
  }
}