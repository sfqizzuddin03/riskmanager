import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/portfolio.dart';
import '../providers/portfolio_provider.dart';

class PositionManagementScreen extends StatefulWidget {
  // We don't need to pass stocks anymore, we read from the Provider/Watchlist
  const PositionManagementScreen({super.key});

  @override
  State<PositionManagementScreen> createState() => _PositionManagementScreenState();
}

class _PositionManagementScreenState extends State<PositionManagementScreen> {
  final TextEditingController _sharesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  String? _selectedSymbol;

  // Curated list for the Dropdown (Simulating a search)
  final List<String> _commonStocks = [
    'AAPL', 'TSLA', 'GOOGL', 'MSFT', 'AMZN', 'NVDA', 'META', 'NFLX', 'AMD', 'INTC'
  ];

  void _addPosition() {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final symbol = _selectedSymbol;

    if (symbol == null || shares <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a stock and enter valid numbers'), backgroundColor: Colors.red),
      );
      return;
    }

    // Save to Global Provider
    final position = PortfolioPosition(
      symbol: symbol,
      companyName: symbol, // In a real app, fetch the name
      shares: shares,
      entryPrice: price,
      currentPrice: price, 
      entryDate: DateTime.now(),
    );

    Provider.of<PortfolioProvider>(context, listen: false).addPosition(position);

    // Reset UI
    _sharesController.clear();
    _priceController.clear();
    FocusScope.of(context).unfocus(); // Hide keyboard

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $shares shares of $symbol')));
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = Provider.of<PortfolioProvider>(context);

    // 1. SHOW "BUBBLE TOUR" IF EMPTY
    if (portfolio.positions.isEmpty) {
      return Stack(
        children: [
          _buildInputForm(),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))],
              ),
              child: Row(
                children: const [
                  Icon(Icons.lightbulb, color: Colors.yellow, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Start Here! Select a stock above, enter your shares, and tap Add to track your wealth.",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Top: Input Form
        _buildInputForm(),
        
        const Divider(thickness: 4, color: Colors.grey),

        // Bottom: List
        Expanded(
          child: ListView.builder(
            itemCount: portfolio.positions.length,
            itemBuilder: (context, index) {
              final pos = portfolio.positions[index];
              return Dismissible(
                key: Key(pos.symbol + index.toString()),
                background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) {
                  Provider.of<PortfolioProvider>(context, listen: false).removePosition(index);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(pos.symbol.substring(0, 1))),
                    title: Text(pos.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${pos.shares} shares @ \$${pos.entryPrice}"),
                    trailing: Text(
                      "\$${(pos.shares * pos.entryPrice).toStringAsFixed(0)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
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

  Widget _buildInputForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Add New Position", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          // DROPDOWN INSTEAD OF TEXT FIELD
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
            onPressed: _addPosition,
            icon: const Icon(Icons.add),
            label: const Text("Add to Portfolio"),
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
}