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
  List<Map<String, dynamic>> _userStocks = [];
  String? _selectedSymbol;
  Map<String, dynamic> _metrics = {};
  
  bool _isLoading = true;
  double _portfolioRiskScore = 0.0;

  // --- USER SETTINGS (All 6 Indicators) ---
  bool _showRSI = true;
  bool _showBollinger = true;
  bool _showMACD = true;
  bool _showATR = false; 
  bool _showSentiment = true; // RESTORED
  bool _showVolume = true;    // RESTORED

  @override
  void initState() {
    super.initState();
    _fetchDataAndInit();
  }

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initDashboard() {
    final validStocks = _userStocks.where((s) => s['symbol'] != null).toList();
    if (validStocks.isNotEmpty) {
      _selectedSymbol ??= validStocks.first['symbol'];
      _analyzeSelectedStock();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _analyzeSelectedStock() async {
    if (_selectedSymbol == null) return;
    setState(() => _isLoading = true);

    try {
      final symbol = _selectedSymbol!;

      // Calculate ALL 6 metrics at once
      final results = await Future.wait([
        RiskCalculator.calculateRSI(symbol, 14),           // 0
        RiskCalculator.calculateBollingerBands(symbol, 20),// 1
        RiskCalculator.calculateMACD(symbol),              // 2
        RiskCalculator.calculateRealATR(symbol),           // 3
        RiskCalculator.getMarketSentiment(symbol),         // 4
        RiskCalculator.getVolumeRatio(symbol),             // 5
      ]);

      if (mounted) {
        setState(() {
          _metrics = {
            'rsi': results[0],
            'bollinger': results[1],
            'macd': results[2],
            'atr': results[3],
            'sentiment': results[4],
            'volume': results[5],
          };
          _calculatePreciseScore();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Analysis Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
    double finalScore = totalShares > 0 ? totalWeightedRsi / totalShares : 50.0;
    if (mounted) setState(() => _portfolioRiskScore = finalScore);
  }

  void _showIndicatorSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows it to be taller
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              height: 600,
              child: ListView(
                children: [
                  Center(child: Container(width: 40, height: 5, color: Colors.grey[300])),
                  SizedBox(height: 20),
                  Text("Analysis Indicators", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Divider(),
                  SwitchListTile(
                    title: Text("Market Sentiment"),
                    value: _showSentiment,
                    onChanged: (val) { setModalState(() => _showSentiment = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: Text("Volume Ratio"),
                    value: _showVolume,
                    onChanged: (val) { setModalState(() => _showVolume = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: Text("RSI (Relative Strength)"),
                    value: _showRSI,
                    onChanged: (val) { setModalState(() => _showRSI = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: Text("MACD (Momentum)"),
                    value: _showMACD,
                    onChanged: (val) { setModalState(() => _showMACD = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: Text("Bollinger Bands"),
                    value: _showBollinger,
                    onChanged: (val) { setModalState(() => _showBollinger = val); setState(() {}); },
                  ),
                  SwitchListTile(
                    title: Text("ATR (Volatility)"),
                    value: _showATR,
                    onChanged: (val) { setModalState(() => _showATR = val); setState(() {}); },
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Risk Companion"),
        backgroundColor: Colors.blueGrey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.tune),
            onPressed: _showIndicatorSettings,
          )
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStockSelector(),
                  SizedBox(height: 20),
                  _buildRiskScoreCard(),
                  SizedBox(height: 20),
                  
                  Row(children: [
                      Icon(Icons.analytics_outlined, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text("Technical Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                  Divider(),
                  SizedBox(height: 10),

                  // Display All Selected Indicators
                  if (_showSentiment) _buildSentimentCard(),
                  if (_showVolume) _buildVolumeCard(),
                  if (_showRSI) _buildRsiCard(),
                  if (_showMACD) _buildMacdCard(),
                  if (_showBollinger) _buildBollingerCard(),
                  if (_showATR) _buildAtrCard(),
                  
                  if (!_showRSI && !_showMACD && !_showBollinger && !_showATR && !_showSentiment && !_showVolume)
                    Center(child: Text("Enable indicators from settings", style: TextStyle(color: Colors.grey))),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildStockSelector() {
    if (_userStocks.isEmpty) return SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border.all(color: Colors.grey.shade300), 
        borderRadius: BorderRadius.circular(8)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSymbol,
          hint: const Text("Select Stock"),
          // FIX: Added <DropdownMenuItem<String>> to the map function
          items: _userStocks.map<DropdownMenuItem<String>>((s) {
            return DropdownMenuItem<String>(
              value: s['symbol'] as String, // FIX: Explicitly cast to String
              child: Text(
                "${s['symbol']} - ${s['name'] ?? 'Stock'}", 
                style: const TextStyle(fontWeight: FontWeight.bold)
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

  Widget _buildRiskScoreCard() {
    Color color = _portfolioRiskScore > 70 ? Colors.red : (_portfolioRiskScore > 30 ? Colors.orange : Colors.green);
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.5)), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Portfolio Risk Score", style: TextStyle(color: Colors.black54)),
            Text("${_portfolioRiskScore.toStringAsFixed(1)}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          ])),
          SizedBox(height: 60, width: 60, child: CircularProgressIndicator(value: _portfolioRiskScore / 100, color: color, backgroundColor: Colors.white, strokeWidth: 8)),
        ],
      ),
    );
  }

  // --- CARDS ---

  Widget _buildSentimentCard() {
    String sentiment = _metrics['sentiment'] ?? "Neutral";
    Color color = (sentiment == "Bullish" || sentiment == "Oversold") ? Colors.green : ((sentiment == "Bearish" || sentiment == "Overbought") ? Colors.red : Colors.grey);
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.psychology, color: color),
        title: Text("Market Sentiment"),
        trailing: Text(sentiment, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildVolumeCard() {
    double vol = _metrics['volume'] ?? 1.0;
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.bar_chart, color: Colors.blue),
        title: Text("Volume Ratio"),
        subtitle: Text("vs 5-Day Average"),
        trailing: Text("${vol.toStringAsFixed(2)}x", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
      ),
    );
  }

  Widget _buildRsiCard() {
    double rsi = _metrics['rsi'] ?? 50.0;
    Color color = rsi > 70 ? Colors.red : (rsi < 30 ? Colors.green : Colors.orange);
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Text("RSI", style: TextStyle(color: color, fontSize: 10))),
        title: Text("Relative Strength Index"),
        trailing: Text(rsi.toStringAsFixed(1), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMacdCard() {
    final macdData = _metrics['macd'];
    if (macdData == null) return SizedBox.shrink();
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Row(children: [Icon(Icons.waterfall_chart, color: Colors.purple), SizedBox(width: 8), Text("MACD Momentum", style: TextStyle(fontWeight: FontWeight.bold))]),
          SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
             _subMetric("MACD", macdData['macd']),
             _subMetric("Signal", macdData['signal']),
             _subMetric("Hist", macdData['histogram'], color: (macdData['histogram'] ?? 0) > 0 ? Colors.green : Colors.red),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBollingerCard() {
    final b = _metrics['bollinger'];
    if (b == null) return SizedBox.shrink();
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           Row(children: [Icon(Icons.graphic_eq, color: Colors.orange), SizedBox(width: 8), Text("Bollinger Bands", style: TextStyle(fontWeight: FontWeight.bold))]),
           Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
             Text("Hi: ${b['upper']?.toStringAsFixed(2)}", style: TextStyle(color: Colors.red, fontSize: 12)),
             Text("Lo: ${b['lower']?.toStringAsFixed(2)}", style: TextStyle(color: Colors.green, fontSize: 12)),
           ]),
        ]),
      ),
    );
  }

  Widget _buildAtrCard() {
    return Card(
      elevation: 2, margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(Icons.show_chart, color: Colors.teal),
        title: Text("ATR (Volatility)"),
        trailing: Text("\$${(_metrics['atr'] ?? 0.0).toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _subMetric(String label, double? val, {Color? color}) {
    return Column(children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)), Text(val?.toStringAsFixed(2) ?? "-", style: TextStyle(fontWeight: FontWeight.bold, color: color))]);
  }
}