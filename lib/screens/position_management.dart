import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';

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

  // Common stocks for the dropdown
  final List<String> _commonStocks = [
    'AAPL', 'TSLA', 'GOOGL', 'MSFT', 'AMZN', 'NVDA', 'META', 'NFLX', 'AMD', 'INTC'
  ];

  Future<void> _addPosition() async {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final symbol = _selectedSymbol;
    final user = FirebaseAuth.instance.currentUser;

    if (symbol == null || shares <= 0 || price <= 0 || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a stock and enter valid numbers'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create the new position object
      final newPosition = {
        'symbol': symbol,
        'name': 'Stock Equity', 
        'shares': shares,
        'entryPrice': price,
        'entryDate': DateTime.now().toIso8601String(),
        'isRealData': true, 
      };

      // 2. Save directly to Firestore (The "Real" Database)
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      await userRef.update({
        'portfolio': FieldValue.arrayUnion([newPosition])
      });

      // 3. NEW: Log the Transaction (The "Pro" Way)
      // This creates the permanent history record in the sub-collection
      await DatabaseService.logTransaction(
        user.uid,
        symbol: symbol,
        type: "BUY",
        shares: shares,
        price: price,
      );

      // 4. Success UI updates
      _sharesController.clear();
      _priceController.clear();
      FocusScope.of(context).unfocus();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bought $shares shares of $symbol!'), backgroundColor: Colors.green)
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding stock: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to remove a stock from Firebase
  Future<void> _removePosition(Map<String, dynamic> position) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'portfolio': FieldValue.arrayRemove([position])
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      // Listen to the Database in Real-Time
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final portfolio = List<Map<String, dynamic>>.from(data?['portfolio'] ?? []);

        return Column(
          children: [
            // Top: Input Form
            _buildInputForm(),
            
            if (_isLoading) const LinearProgressIndicator(),

            const Divider(thickness: 4, color: Colors.grey),

            // Bottom: List of Owned Stocks
            Expanded(
              child: portfolio.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: portfolio.length,
                  itemBuilder: (context, index) {
                    final pos = portfolio[index];
                    final shares = pos['shares'] as int;
                    final price = (pos['entryPrice'] as num).toDouble();
                    final symbol = pos['symbol'] as String;

                    return Dismissible(
                      key: Key(symbol + index.toString()),
                      background: Container(
                        color: Colors.red, 
                        alignment: Alignment.centerRight, 
                        padding: const EdgeInsets.only(right: 20), 
                        child: const Icon(Icons.delete, color: Colors.white)
                      ),
                      onDismissed: (_) => _removePosition(pos),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(symbol.substring(0, 1), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("$shares shares @ \$${price.toStringAsFixed(2)}"),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "\$${(shares * price).toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                              ),
                              const Text("Total Value", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Buy / Add New Position", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          DropdownButtonFormField<String>(
            value: _selectedSymbol,
            decoration: const InputDecoration(
              labelText: "Select Stock",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            items: _commonStocks.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) => setState(() => _selectedSymbol = val),
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sharesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Shares", border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Buy Price", border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _addPosition,
            icon: const Icon(Icons.add),
            label: const Text("Buy Stock"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.account_balance_wallet, color: Colors.blueAccent, size: 40),
            SizedBox(height: 10),
            Text(
              "Your Portfolio is Empty",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            SizedBox(height: 5),
            Text(
              "Use the form above to add stocks you own.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}