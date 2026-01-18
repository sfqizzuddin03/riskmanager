import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/risk_calculator.dart';
import '../logic/risk_engine.dart'; 
import '../services/notification_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchDataAndInit();
  }

  Future<void> _fetchDataAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final portfolio = await DatabaseService.loadPortfolio(user.uid);
      if (mounted) {
        setState(() => _userStocks = portfolio);
        _initDashboard();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initDashboard() {
    if (_userStocks.isNotEmpty) {
      final valid = _userStocks.where((s) => s['symbol'] != null).toList();
      if (valid.isNotEmpty) {
        _selectedSymbol ??= valid.first['symbol'];
        _analyzeSelectedStock();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /*Future<void> _analyzeSelectedStock() async {
    if (_selectedSymbol == null) return;
    setState(() => _isLoading = true);

    try {
      final symbol = _selectedSymbol!;

      // Calculate ALL indicators
      final results = await Future.wait([
        RiskCalculator.calculateRSI(symbol, 14),           // 0
        RiskCalculator.calculateBollingerBands(symbol, 20),// 1
        RiskCalculator.getVolumeRatio(symbol),             // 2
        RiskCalculator.calculateRealATR(symbol),           // 3
        RiskCalculator.calculateSMA(symbol, 50),           // 4 (SMA)
        RiskCalculator.calculateEMA(symbol, 20),           // 5 (EMA)
        RiskCalculator.calculateMACD(symbol),              // 6 (MACD)
      ]);

      if (mounted) {
        setState(() {
          _metrics = {
            'rsi': results[0],
            'bollinger': results[1],
            'volume': results[2],
            'atr': results[3],
            'sma': results[4],
            'ema': results[5],
            'macd': results[6],      
          };
          
          _portfolioRiskScore = (results[0] as double); 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }*/

  Future<void> _analyzeSelectedStock() async {
    if (_selectedSymbol == null) return;
    setState(() => _isLoading = true);

    try {
      final symbol = _selectedSymbol!;

      // 1. Fetch ALL Indicators
      final results = await Future.wait([
        RiskCalculator.calculateRSI(symbol, 14),           // 0
        RiskCalculator.calculateBollingerBands(symbol, 20),// 1
        RiskCalculator.getVolumeRatio(symbol),             // 2
        RiskCalculator.calculateRealATR(symbol),           // 3
        RiskCalculator.calculateSMA(symbol, 50),           // 4
        RiskCalculator.calculateEMA(symbol, 20),           // 5
        RiskCalculator.calculateMACD(symbol),              // 6
        RiskCalculator.getStockDetails(symbol),            // 7 (Price)
      ]);

      // 2. Extract Data variables
      final rsi = results[0] as double;
      final bands = results[1] as Map<String, double>;
      final volRatio = results[2] as double;
      final atr = results[3] as double;
      final sma50 = results[4] as double;
      final ema20 = results[5] as double;
      final macd = results[6] as Map<String, double>;
      final priceData = results[7] as Map<String, double>;
      final currentPrice = priceData['price'] ?? 0.0;

      // ====================================================
      // 🔔 NOTIFICATION LOGIC (RESTORED)
      // ====================================================
      
      // Step A: Ask the Risk Engine "Is this stock dangerous?"
      List<String> warnings = RiskEngine().evaluateRisk(
        symbol: symbol,
        currentPrice: currentPrice,
        sma50: sma50,
        liveATR: atr,
        historicalATR: 3.902, // Using the fixed benchmark for now
        volumeRatio: volRatio,
      );

      // Step B: If the engine returns warnings, fire the notification
      if (warnings.isNotEmpty) {
        // We trigger the notification using the FIRST warning in the list
        // e.g., Title: "Risk Alert: TSLA", Body: "Volatility Spike Detected!"
        NotificationService.showNotification(
          title: "Risk Alert: $symbol",
          body: warnings.first, 
        );
        print("--- NOTIFICATION SENT: ${warnings.first} ---");
      }
      // ====================================================

      if (mounted) {
        setState(() {
          _metrics = {
            'rsi': rsi,
            'bollinger': bands,
            'volume': volRatio,
            'atr': atr,
            'sma': sma50,
            'ema': ema20,
            'macd': macd,      
          };
          
          _portfolioRiskScore = rsi; 
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error analyzing stock: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // INSIGHT POP-UP LOGIC 
  void _showInsight(String title, String definition, String strategy) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 28),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 30),
              const Text("WHAT IS IT?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 5),
              Text(definition, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              const Text("HOW TO TRADE IT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)),
              const SizedBox(height: 5),
              Text(strategy, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it!"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text("Risk Dashboard", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_userStocks.isNotEmpty) 
                  _buildStockSelector(isDark)
                else 
                  const Center(child: Text("Add stocks in Portfolio to see analysis")),

                const SizedBox(height: 20),

                // --- RISK SCORE ---
                _buildRiskScoreCard(context),
                
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                Text("Technical Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 15),

                // 1. RSI
                _buildMetricCard(
                  context, 
                  "RSI (14-Day)", 
                  (_metrics['rsi'] ?? 0).toStringAsFixed(1), 
                  _getRsiColor(_metrics['rsi']), 
                  _getRsiStatus(_metrics['rsi']),
                  "RSI Insight",
                  "Measures the speed of price changes (The 'Greed Meter').",
                  "• Above 70 (Red): Overbought. Be careful, price might drop.\n• Below 30 (Green): Oversold. Good chance for a bargain buy."
                ),

                // 2. BOLLINGER BANDS
                _buildBollingerCard(context),

                // 3. VOLUME
                _buildMetricCard(
                  context, 
                  "Volume Ratio", 
                  "${(_metrics['volume'] ?? 0).toStringAsFixed(2)}x", 
                  (_metrics['volume'] ?? 0) > 1.5 ? Colors.purple : Colors.blueGrey, 
                  "Relative to 5-Day Avg",
                  "Volume Insight",
                  "Compares today's trading activity to the average of the last 5 days.",
                  "• High Ratio (> 2.0): Big news or big move happening.\n• Low Ratio (< 1.0): Quiet day, price moves might be fake."
                ),

                // 4. ATR
                _buildMetricCard(
                  context, 
                  "Real ATR (Volatility)", 
                  "\$${(_metrics['atr'] ?? 0).toStringAsFixed(2)}", 
                  Colors.teal, 
                  "Expected Daily Move",
                  "ATR Insight",
                  "Average True Range. Tells you how many dollars this stock moves in a day.",
                  "• Use this for Stop Losses.\n• Example: If ATR is \$5, set your stop loss \$5 below your buy price."
                ),

                // 5. SMA (Simple Moving Average)
                _buildMetricCard(
                  context,
                  "SMA (50-Day)",
                  "\$${(_metrics['sma'] ?? 0).toStringAsFixed(2)}",
                  Colors.blue,
                  "Long-Term Baseline",
                  "SMA Insight",
                  "The average price over the last 50 days. It smooths out noise.",
                  "• Price ABOVE SMA: The long-term trend is UP (Bullish).\n• Price BELOW SMA: The long-term trend is DOWN (Bearish)."
                ),

                // 6. EMA (Exponential Moving Average)
                _buildMetricCard(
                  context,
                  "EMA (20-Day)",
                  "\$${(_metrics['ema'] ?? 0).toStringAsFixed(2)}",
                  Colors.purple,
                  "Short-Term Trend",
                  "EMA Insight",
                  "Reacts faster to recent price changes than the SMA.",
                  "• Watch for the 'Crossover': If the EMA crosses above the SMA, it is often a strong BUY signal (Golden Cross)."
                ),

                // 7. MACD (Momentum)
                _buildMacdCard(context),

              ],
            ),
          ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildStockSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedSymbol,
          dropdownColor: isDark ? Colors.grey[900] : Colors.white,
          items: _userStocks.map<DropdownMenuItem<String>>((s) {
            return DropdownMenuItem<String>(
              value: s['symbol'].toString(),
              child: Text(s['symbol'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
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

  Widget _buildRiskScoreCard(BuildContext context) {
    Color color = _portfolioRiskScore > 70 ? Colors.red : (_portfolioRiskScore < 30 ? Colors.green : Colors.orange);
    String label = _portfolioRiskScore > 70 ? "High Risk" : (_portfolioRiskScore < 30 ? "Oversold" : "Neutral");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text("Technical Exposure", style: TextStyle(fontSize: 14)),
                  GestureDetector(
                    onTap: () => _showInsight(
                      "Technical Exposure", 
                      "An overall summary of the stock's current state based on RSI and Momentum.", 
                      "• High Risk (>70): The stock is expensive. Consider selling.\n• Oversold (<30): The stock is cheap. Good buying opportunity."
                    ),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    ),
                  )
                ],
              ),
              Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60, height: 60,
                child: CircularProgressIndicator(value: _portfolioRiskScore / 100, color: color, strokeWidth: 6),
              ),
              Text(_portfolioRiskScore.toInt().toString(), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, Color color, String subtitle, String insightTitle, String def, String strat) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
            GestureDetector(
              onTap: () => _showInsight(insightTitle, def, strat),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade400),
              ),
            ),
          ],
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildBollingerCard(BuildContext context) {
    final bands = _metrics['bollinger'];
    if (bands == null) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(children: [
              const Icon(Icons.graphic_eq, color: Colors.blueGrey), 
              const SizedBox(width: 8), 
              const Text("Bollinger Bands (20D)", style: TextStyle(fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => _showInsight(
                  "Bollinger Bands", 
                  "Elastic bands around the price. Prices hate being outside these bands.", 
                  "• Price hits Upper Band: Overextended (Sell).\n• Price hits Lower Band: Overextended (Buy)."
                ),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade400),
                ),
              ),
            ]),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _bandColumn("Upper", bands['upper'], Colors.red, isDark),
                _bandColumn("Middle", bands['middle'], Colors.blue, isDark),
                _bandColumn("Lower", bands['lower'], Colors.green, isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMacdCard(BuildContext context) {
    final macdData = _metrics['macd'];
    if (macdData == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    double histogram = macdData['histogram'] ?? 0.0;
    bool isBullish = histogram > 0;

    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.waterfall_chart, color: Colors.purple),
                const SizedBox(width: 8),
                const Text("MACD Momentum", style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showInsight(
                    "MACD",
                    "Moving Average Convergence Divergence. Spots reversals.",
                    "Green Histogram = Bullish Momentum. Red = Bearish."
                  ),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _bandColumn("MACD", macdData['macd'], Colors.purple, isDark),
                _bandColumn("Signal", macdData['signal'], Colors.orange, isDark),
                _bandColumn("Hist", histogram, isBullish ? Colors.green : Colors.red, isDark),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _bandColumn(String label, double? value, Color color, bool isDark) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value?.toStringAsFixed(2) ?? "-", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }

  Color _getRsiColor(double? rsi) {
    if (rsi == null) return Colors.grey;
    if (rsi > 70) return Colors.red;
    if (rsi < 30) return Colors.green;
    return Colors.orange;
  }

  String _getRsiStatus(double? rsi) {
    if (rsi == null) return "-";
    if (rsi > 70) return "Overbought";
    if (rsi < 30) return "Oversold";
    return "Neutral";
  }
}