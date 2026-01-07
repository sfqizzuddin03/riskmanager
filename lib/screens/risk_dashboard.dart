import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/risk_calculator.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDataAndInit();
  }

  // 1. FETCH DATA FROM FIRESTORE
  Future<void> _fetchDataAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('portfolio')) {
        final rawList = List<Map<String, dynamic>>.from(doc.data()!['portfolio']);
        
        if (mounted) {
          setState(() {
            _userStocks = rawList;
          });
          _initDashboard();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching portfolio: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 2. INITIALIZE DASHBOARD
  void _initDashboard() {
    final validStocks = _userStocks.where((s) => s['symbol'] != null).toList();

    if (validStocks.isNotEmpty) {
      _selectedSymbol ??= validStocks.first['symbol'];
      _analyzeSelectedStock(); // Trigger the analysis
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FIXED ANALYSIS FUNCTION ---
  Future<void> _analyzeSelectedStock() async {
    if (_selectedSymbol == null) return;

    setState(() => _isLoading = true);

    try {
      final symbol = _selectedSymbol!;

      // Run calculations in parallel
      // FIXED: Calling calculateRealATR() without the '14' argument
      final results = await Future.wait([
        RiskCalculator.calculateRSI(symbol, 14),           // Index 0
        RiskCalculator.calculateBollingerBands(symbol, 20),// Index 1
        RiskCalculator.getMarketSentiment(symbol),         // Index 2
        RiskCalculator.getVolumeRatio(symbol),             // Index 3
        RiskCalculator.calculateRealATR(symbol)            // Index 4 (FIXED NAME & ARGS)
      ]);

      if (mounted) {
        setState(() {
          _currentStockMetrics = {
            'rsi': results[0],
            'bollingerBands': results[1],
            'marketSentiment': results[2],
            'volumeRatio': results[3],
            'atr': results[4],
          };
          _analyzePortfolioScore(); // Recalculate total score
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error analyzing stock: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Calculate a rough portfolio risk score
  Future<void> _analyzePortfolioScore() async {
    double totalRsi = 0;
    int count = 0;

    for (var stock in _userStocks) {
      final symbol = stock['symbol'];
      if (symbol != null) {
        // Just use RSI for the quick portfolio score
        totalRsi += await RiskCalculator.calculateRSI(symbol, 14);
        count++;
      }
    }

    double avgRsi = count > 0 ? totalRsi / count : 50.0;
    
    // Simple Risk Logic
    double riskScore = 50;
    if (avgRsi > 70) riskScore = 85;      // Overbought = High Risk
    else if (avgRsi < 30) riskScore = 30; // Oversold = Low Risk (Opportunity)
    else riskScore = 55;

    if (mounted) {
      setState(() {
        _portfolioRiskScore = riskScore;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // EMPTY STATE
    if (!_isLoading && _userStocks.isEmpty) {
      return const Center(child: Text("No stocks in portfolio"));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Risk Dashboard"),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- STOCK SELECTOR ---
              if (_userStocks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedSymbol,
                      hint: const Text("Select a stock"),
                      items: _userStocks
                          .where((s) => s['symbol'] != null)
                          .map((stock) {
                        return DropdownMenuItem<String>(
                          value: stock['symbol'],
                          child: Text(
                            "${stock['symbol']} - ${stock['name'] ?? 'Stock'}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedSymbol = value;
                          });
                          _analyzeSelectedStock();
                        }
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                  : Column(
                      children: [
                        // --- PORTFOLIO SCORE ---
                        _buildRiskScoreCard(),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        // --- DETAILED METRICS ---
                        Text("Analysis for $_selectedSymbol",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        const SizedBox(height: 10),

                        _buildMetricCard(
                          "RSI (14 Days)",
                          _currentStockMetrics['rsi']?.toStringAsFixed(1) ?? "-",
                          _getRsiColor(_currentStockMetrics['rsi'] ?? 50),
                          _getRsiStatus(_currentStockMetrics['rsi'] ?? 50),
                        ),

                        _buildMetricCard(
                          "Market Sentiment",
                          _currentStockMetrics['marketSentiment'] ?? "-",
                          _getSentimentColor(_currentStockMetrics['marketSentiment'] ?? "Neutral"),
                          "Based on Volume & Price Action",
                        ),

                        _buildBollingerCard(),

                        _buildMetricCard(
                          "Real ATR (Volatility)",
                          "\$${_currentStockMetrics['atr']?.toStringAsFixed(2) ?? '-'}",
                          Colors.blueGrey,
                          "Avg True Range (15D)",
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildRiskScoreCard() {
    Color riskColor = _portfolioRiskScore > 75 ? Colors.red : (_portfolioRiskScore > 40 ? Colors.orange : Colors.green);
    String riskText = _portfolioRiskScore > 75 ? "HIGH RISK" : (_portfolioRiskScore > 40 ? "MODERATE" : "LOW RISK");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Portfolio Exposure", style: TextStyle(fontSize: 14, color: Colors.black54)),
              Text(riskText, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: riskColor)),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(
                  value: _portfolioRiskScore / 100,
                  color: riskColor,
                  backgroundColor: Colors.white,
                  strokeWidth: 6,
                ),
              ),
              Text("${_portfolioRiskScore.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, color: riskColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, String subtitle) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildBollingerCard() {
    final bands = _currentStockMetrics['bollingerBands'];
    if (bands == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.graphic_eq, color: Colors.blueGrey, size: 20),
                SizedBox(width: 8),
                Text("Bollinger Bands (20D)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _bandColumn("Upper", bands['upper'], Colors.red),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _bandColumn("Middle", bands['middle'], Colors.blue),
                Container(width: 1, height: 30, color: Colors.grey.shade300),
                _bandColumn("Lower", bands['lower'], Colors.green),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _bandColumn(String label, double? value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value?.toStringAsFixed(2) ?? "-", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  Color _getRsiColor(double rsi) {
    if (rsi > 70) return Colors.red;
    if (rsi < 30) return Colors.green;
    return Colors.orange;
  }

  String _getRsiStatus(double rsi) {
    if (rsi > 70) return "Overbought";
    if (rsi < 30) return "Oversold";
    return "Neutral";
  }

  Color _getSentimentColor(String sentiment) {
    if (sentiment == 'Bullish' || sentiment == 'Oversold') return Colors.green;
    if (sentiment == 'Bearish' || sentiment == 'Overbought') return Colors.red;
    return Colors.blueGrey;
  }
}