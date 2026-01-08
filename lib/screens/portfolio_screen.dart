import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/risk_calculator.dart';
import 'position_management.dart'; 

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  // Data State
  List<Map<String, dynamic>> _portfolio = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  
  // Metrics
  double _totalValue = 0.0;
  double _totalCost = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPortfolioData();
  }

  Future<void> _loadPortfolioData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Load Data
    final data = await DatabaseService.loadPortfolio(user.uid);
    
    // 2. Fetch Live Prices
    double tempTotalValue = 0;
    double tempTotalCost = 0;
    Map<String, double> tempPrices = {};

    for (var item in data) {
      String symbol = item['symbol'];
      double shares = (item['shares'] as num).toDouble();
      
      // Handle entryPrice (new) vs averagePrice (old compatibility)
      double cost = (item['entryPrice'] as num?)?.toDouble() ?? 
                    (item['averagePrice'] as num?)?.toDouble() ?? 0.0;

      // Get Live Price
      final details = await RiskCalculator.getStockDetails(symbol);
      double currentPrice = details['price'] ?? cost;

      tempPrices[symbol] = currentPrice;
      tempTotalValue += (currentPrice * shares);
      tempTotalCost += (cost * shares);
    }

    if (mounted) {
      setState(() {
        _portfolio = data;
        _livePrices = tempPrices;
        _totalValue = tempTotalValue;
        _totalCost = tempTotalCost;
        _isLoading = false;
      });
    }
  }

  void _showGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.school, color: Colors.blue),
          SizedBox(width: 10),
          Text("Portfolio Guide")
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _GuideStep(icon: Icons.add_circle, text: "Tap 'Add / Manage' to buy assets."),
             SizedBox(height: 10),
             _GuideStep(icon: Icons.refresh, text: "Pull down to refresh live prices."),
             SizedBox(height: 10),
             _GuideStep(icon: Icons.trending_up, text: "Green = Profit. Red = Loss."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it!"))
        ],
      ),
    );
  }

@override
  Widget build(BuildContext context) {
    // 1. Detect Dark Mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // 2. Define colors based on mode
    // FIX: Added '!' to Colors.grey[...] to force them to be non-null
    final Color bgColor = isDarkMode ? Colors.black : Colors.grey[100]!; 
    final Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    double totalReturn = _totalValue - _totalCost;
    double returnPercent = _totalCost > 0 ? (totalReturn / _totalCost) * 100 : 0.0;

    return Scaffold(
      backgroundColor: bgColor, 
      appBar: AppBar(
        title: Text("My Portfolio", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: cardColor, 
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: subTextColor),
            onPressed: _showGuide,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPortfolioData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Summary Card
                    _buildSummaryCard(totalReturn, returnPercent),

                    if (_portfolio.isEmpty) 
                      _buildEmptyState(textColor)
                    else
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Your Assets", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: subTextColor)),
                            const SizedBox(height: 10),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _portfolio.length,
                              itemBuilder: (context, index) {
                                // Now this works because cardColor is definitely a Color (not Color?)
                                return _buildStockCard(_portfolio[index], cardColor, textColor, subTextColor);
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: isDarkMode ? Colors.blueGrey : Colors.blueGrey.shade900,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add / Manage", style: TextStyle(color: Colors.white)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PositionManagementScreen()),
          );
          _loadPortfolioData();
        },
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildSummaryCard(double totalReturn, double returnPercent) {
    Color profitColor = totalReturn >= 0 ? Colors.greenAccent : Colors.redAccent;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Total Equity", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            "\$${_totalValue.toStringAsFixed(2)}",
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: profitColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(totalReturn >= 0 ? Icons.arrow_upward : Icons.arrow_downward, color: profitColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "${totalReturn >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%",
                      style: TextStyle(color: profitColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "${totalReturn >= 0 ? '+' : ''}\$${totalReturn.abs().toStringAsFixed(2)}",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          )
        ],
      ),
    );
  }

  // UPDATED: Now accepts dynamic colors
  Widget _buildStockCard(Map<String, dynamic> stock, Color cardColor, Color textColor, Color subTextColor) {
    String symbol = stock['symbol'];
    double shares = (stock['shares'] as num).toDouble();
    double cost = (stock['entryPrice'] as num?)?.toDouble() ?? 
                  (stock['averagePrice'] as num?)?.toDouble() ?? 0.0;
    
    double currentPrice = _livePrices[symbol] ?? cost;
    double value = currentPrice * shares;
    double gain = value - (cost * shares);
    
    return Card(
      color: cardColor, // Uses passed color
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade50,
          child: Text(symbol[0], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade900)),
        ),
        title: Text(symbol, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        subtitle: Text("$shares shares @ \$${cost.toStringAsFixed(2)}", style: TextStyle(color: subTextColor)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("\$${value.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            Text(
              "${gain >= 0 ? '+' : ''}\$${gain.toStringAsFixed(2)}",
              style: TextStyle(
                color: gain >= 0 ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }

  // UPDATED: Now accepts dynamic colors
  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text("No assets yet", style: TextStyle(color: textColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// Helper Widget for Guide
class _GuideStep extends StatelessWidget {
  final IconData icon;
  final String text;
  const _GuideStep({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}