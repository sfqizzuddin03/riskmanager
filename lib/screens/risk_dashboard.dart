import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/risk_calculator.dart';
import 'position_management.dart'; // Import this so we can link to it

class RiskDashboard extends StatefulWidget {
  const RiskDashboard({super.key});

  @override
  State<RiskDashboard> createState() => _RiskDashboardState();
}

class _RiskDashboardState extends State<RiskDashboard> {
  // Local storage for the data
  List<Map<String, dynamic>> _userStocks = [];
  String? _selectedSymbol;

  // Analysis Metrics
  Map<String, dynamic> _currentStockMetrics = {};
  double _portfolioRiskScore = 0.0;
  bool _isLoading = true;

  // Settings Toggles
  bool _showRSI = true;
  bool _showBollinger = true;
  bool _showMACD = true;
  bool _showATR = false;

  @override
  void initState() {
    super.initState();
    _fetchDataAndInit();
  }

  // 1. FETCH DATA
  Future<void> _fetchDataAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
      // Strict check: Does the portfolio exist AND is it not empty?
      if (doc.exists && doc.data()!.containsKey('portfolio')) {
        final rawList = List<Map<String, dynamic>>.from(doc.data()!['portfolio']);
        
        // Filter out bad data (empty symbols)
        final validList = rawList.where((s) => s['symbol'] != null && s['symbol'].toString().isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _userStocks = validList;
          });
          
          // Only init dashboard if we actually have stocks
          if (validList.isNotEmpty) {
            _initDashboard();
          } else {
             setState(() => _isLoading = false);
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching portfolio: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initDashboard() {
    if (_userStocks.isNotEmpty) {
      _selectedSymbol ??= _userStocks.first['symbol'];
      _analyzeSelectedStock();
    }
  }

  // 2. ANALYZE STOCK
  Future<void> _analyzeSelectedStock() async {
    if (_selectedSymbol == null) return;
    setState(() => _isLoading = true);

    try {
      final symbol = _selectedSymbol!;

      final results = await Future.wait([
        RiskCalculator.calculateRSI(symbol, 14),           // 0
        RiskCalculator.calculateBollingerBands(symbol, 20),// 1
        RiskCalculator.calculateMACD(symbol),              // 2
        RiskCalculator.calculateRealATR(symbol)            // 3
      ]);

      if (mounted) {
        setState(() {
          _currentStockMetrics = {
            'rsi': results[0],
            'bollinger': results[1],
            'macd': results[2],
            'atr': results[3],
          };
          _calculatePreciseScore(); // Recalculate total score
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error analyzing stock: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. CALCULATE SCORE
  Future<void> _calculatePreciseScore() async {
    double totalWeightedRsi = 0;
    double totalShares = 0;

    for (var stock in _userStocks) {
      final symbol = stock['symbol'];
      final shares = (stock['shares'] as num?)?.toDouble() ?? 0.0; 

      if (symbol != null && shares > 0) {
        double rsi = await RiskCalculator.calculateRSI(symbol, 14);
        totalWeightedRsi += (rsi * shares);
        totalShares += shares;
      }
    }

    // FIXED: If total shares is 0, score is 0 (Unknown), NOT 50 (Neutral)
    double finalScore = totalShares > 0 ? totalWeightedRsi / totalShares : 0.0;
    
    if (mounted) {
      setState(() => _portfolioRiskScore = finalScore);
    }
  }

  // 4. SETTINGS MODAL
  void _showIndicatorSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Analysis Indicators", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  SwitchListTile(
                    title: const Text("RSI"),
                    value: _showRSI,
                    onChanged: (val) { setModalState(() => _showRSI = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: const Text("MACD"),
                    value: _showMACD,
                    onChanged: (val) { setModalState(() => _showMACD = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: const Text("Bollinger Bands"),
                    value: _showBollinger,
                    onChanged: (val) { setModalState(() => _showBollinger = val); setState(() {}); },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dark Mode Logic
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : Colors.grey[50]!;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    // --- 1. EMPTY STATE CHECK (The Critical Fix) ---
    if (!_isLoading && _userStocks.isEmpty) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: const Text("Risk Dashboard"),
          backgroundColor: Colors.blueGrey.shade900,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.analytics_outlined, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text(
                "No Portfolio Data",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 10),
              Text(
                "Add assets to your portfolio to\nunlock risk analysis.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Assets Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                ),
                onPressed: () async {
                   // Link to your Position Management Screen
                   await Navigator.push(context, MaterialPageRoute(builder: (c) => const PositionManagementScreen()));
                   // Refresh when back
                   _fetchDataAndInit();
                },
              )
            ],
          ),
        ),
      );
    }

    // --- 2. MAIN DASHBOARD ---
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Risk Companion"),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showIndicatorSettings)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStockSelector(isDarkMode),
                  const SizedBox(height: 20),
                  _buildRiskScoreCard(isDarkMode),
                  const SizedBox(height: 20),
                  
                  Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Text("Technical Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 10),

                  if (_showRSI) _buildRsiCard(isDarkMode),
                  if (_showMACD) _buildMacdCard(isDarkMode),
                  if (_showBollinger) _buildBollingerCard(isDarkMode),
                  if (_showATR) _buildAtrCard(isDarkMode),
                ],
              ),
            ),
          ),
    );
  }

  // --- WIDGETS ---

  Widget _buildStockSelector(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSymbol,
          dropdownColor: isDarkMode ? Colors.grey[900] : Colors.white,
          items: _userStocks.map((s) {
            return DropdownMenuItem<String>(
              value: s['symbol'],
              child: Text(
                "${s['symbol']}", 
                style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedSymbol = val);
              _analyzeSelectedStock();
            }
          },
        ),
      ),
    );
  }

  Widget _buildRiskScoreCard(bool isDarkMode) {
    Color color = _portfolioRiskScore > 70 ? Colors.red : (_portfolioRiskScore > 30 ? Colors.orange : Colors.green);
    String label = _portfolioRiskScore > 70 ? "High Exposure" : (_portfolioRiskScore > 30 ? "Moderate" : "Safe Zone");
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Portfolio Risk Score", style: TextStyle(color: textColor.withOpacity(0.7))),
                const SizedBox(height: 5),
                Text("${_portfolioRiskScore.toStringAsFixed(1)}", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
          SizedBox(
            height: 60, width: 60,
            child: CircularProgressIndicator(
              value: _portfolioRiskScore / 100, 
              color: color, 
              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
              strokeWidth: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRsiCard(bool isDarkMode) {
    double rsi = _metrics('rsi') as double? ?? 50.0;
    String status = rsi > 70 ? "Overbought" : (rsi < 30 ? "Oversold" : "Neutral");
    Color color = rsi > 70 ? Colors.red : (rsi < 30 ? Colors.green : Colors.orange);
    Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Text("RSI", style: TextStyle(color: color, fontSize: 10))),
        title: Text("Relative Strength", style: TextStyle(color: textColor)),
        subtitle: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        trailing: Text(rsi.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
      ),
    );
  }

  Widget _buildMacdCard(bool isDarkMode) {
    final macdData = _metrics('macd'); 
    if (macdData == null) return const SizedBox.shrink();

    double histogram = macdData['histogram'];
    bool bullish = histogram > 0;
    Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
               Text("MACD Momentum", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
               Text(bullish ? "BULLISH" : "BEARISH", 
                style: TextStyle(fontWeight: FontWeight.bold, color: bullish ? Colors.green : Colors.red))
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBollingerCard(bool isDarkMode) {
    final b = _metrics('bollinger');
    if (b == null) return const SizedBox.shrink();
    
    Color cardColor = isDarkMode ? Colors.grey[900]! : Colors.white;
    Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Bollinger Bands", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor)),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text("Upper: ${b['upper']?.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontSize: 12)),
              Text("Lower: ${b['lower']?.toStringAsFixed(2)}", style: const TextStyle(color: Colors.green, fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAtrCard(bool isDarkMode) {
     return const SizedBox.shrink(); // Simplify for brevity if not selected
  }

  // Helper to safely get metrics
  dynamic _metrics(String key) {
    return _currentStockMetrics[key];
  }
}