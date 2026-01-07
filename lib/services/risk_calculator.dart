import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RiskCalculator {
  // 1. FETCH REAL HISTORICAL DATA (No more random numbers)
  static Future<Map<String, List<double>>> getHistoricalData(String symbol, int days) async {
    try {
      // Yahoo Finance API for historical candle data
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=${days + 20}d&interval=1d';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['chart']['result'][0];
        final quote = result['indicators']['quote'][0];
        
        // Parse High, Low, Close lists safely
        List<double> closes = _cleanList(quote['close']);
        List<double> highs = _cleanList(quote['high']);
        List<double> lows = _cleanList(quote['low']);

        return {'close': closes, 'high': highs, 'low': lows};
      }
    } catch (e) {
      print('Error fetching history: $e');
    }
    return {'close': [], 'high': [], 'low': []};
  }

  // Helper to remove nulls from API data
  static List<double> _cleanList(List<dynamic> raw) {
    return raw.where((e) => e != null).map((e) => (e as num).toDouble()).toList();
  }

  // 2. REAL RSI CALCULATION (Relative Strength Index)
  static Future<double> calculateRSI(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 15);
    final prices = data['close']!;
    
    if (prices.length < period + 1) return 50.0;

    double gain = 0.0;
    double loss = 0.0;

    // First average
    for (int i = 1; i <= period; i++) {
      double change = prices[i] - prices[i - 1];
      if (change > 0) gain += change;
      else loss += change.abs();
    }
    
    double avgGain = gain / period;
    double avgLoss = loss / period;

    // Smoothed averages
    for (int i = period + 1; i < prices.length; i++) {
      double change = prices[i] - prices[i - 1];
      double currentGain = change > 0 ? change : 0.0;
      double currentLoss = change < 0 ? change.abs() : 0.0;
      
      avgGain = ((avgGain * (period - 1)) + currentGain) / period;
      avgLoss = ((avgLoss * (period - 1)) + currentLoss) / period;
    }

    if (avgLoss == 0) return 100.0;
    double rs = avgGain / avgLoss;
    return 100 - (100 / (1 + rs));
  }

  // 3. REAL BOLLINGER BANDS
  static Future<Map<String, double>> calculateBollingerBands(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period);
    final prices = data['close']!;
    
    if (prices.length < period) return {'upper': 0, 'middle': 0, 'lower': 0};
    
    // Use the most recent 'period' days
    final segment = prices.sublist(prices.length - period);
    
    double sum = segment.reduce((a, b) => a + b);
    double mean = sum / period;
    
    double variance = segment.map((p) => pow(p - mean, 2)).reduce((a, b) => a + b) / period;
    double stdDev = sqrt(variance);
    
    return {
      'upper': mean + (2 * stdDev),
      'middle': mean,
      'lower': mean - (2 * stdDev),
    };
  }

  // 4. REAL VOLUME RATIO
  static Future<double> getVolumeRatio(String symbol) async {
    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=5d&interval=1d';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        
        // Get volume list
        List<dynamic> volumesRaw = result['indicators']['quote'][0]['volume'];
        List<double> volumes = _cleanList(volumesRaw);

        if (volumes.length < 2) return 1.0;

        double currentVol = volumes.last;
        double avgVol = volumes.reduce((a, b) => a + b) / volumes.length;

        return currentVol / avgVol;
      }
    } catch (_) {}
    return 1.0;
  }

  // 5. REAL MARKET SENTIMENT
  static Future<String> getMarketSentiment(String symbol) async {
    final rsi = await calculateRSI(symbol, 14);
    final vol = await getVolumeRatio(symbol);
    
    if (rsi > 70) return "Overbought"; // High risk of drop
    if (rsi < 30) return "Oversold";   // High chance of bounce
    if (vol > 1.5 && rsi > 50) return "Bullish"; // High volume buying
    if (vol > 1.5 && rsi < 50) return "Bearish"; // High volume selling
    return "Neutral";
  }

  // 6. REAL ATR (Average True Range) - Volatility Measure
  // Previously this was hardcoded to 2.5
  static Future<double> calculateRealATR(String symbol) async {
    final data = await getHistoricalData(symbol, 15);
    final closes = data['close']!;
    final highs = data['high']!;
    final lows = data['low']!;

    if (closes.length < 14) return 0.0;

    List<double> trValues = [];
    for (int i = 1; i < closes.length; i++) {
      double hl = highs[i] - lows[i]; // High - Low
      double hc = (highs[i] - closes[i-1]).abs(); // High - Prev Close
      double lc = (lows[i] - closes[i-1]).abs(); // Low - Prev Close
      trValues.add([hl, hc, lc].reduce(max));
    }

    // Average the TR values
    return trValues.reduce((a, b) => a + b) / trValues.length;
  }

  // 7. GET LIVE PRICE & CHANGE (Needed for Watchlist)
  static Future<Map<String, double>> getStockDetails(String symbol) async {
    try {
      // Fetch 1-day data to get the metadata
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final meta = json['chart']['result'][0]['meta'];
        
        // Extract exact price data
        final currentPrice = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['chartPreviousClose'] as num).toDouble();
        
        final changeAmount = currentPrice - prevClose;
        final changePercent = (changeAmount / prevClose) * 100;

        return {
          'price': currentPrice,
          'change': changeAmount,
          'percent': changePercent
        };
      }
    } catch (e) {
      print("Error fetching price for $symbol: $e");
    }
    return {}; 
  }
}