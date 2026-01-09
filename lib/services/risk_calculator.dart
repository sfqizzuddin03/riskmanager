import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RiskCalculator {
  
  // --- 1. DATA FETCHING (Optimized) ---
  static Future<Map<String, List<double>>> getHistoricalData(String symbol, int days) async {
    try {
      // Fetch enough data for the longest indicator (SMA 50 requires ~70 days buffer)
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=${days + 50}d&interval=1d';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['chart']['result'][0];
        final quote = result['indicators']['quote'][0];
        
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

  static List<double> _cleanList(List<dynamic> raw) {
    if (raw.isEmpty) return [];
    return raw.where((e) => e != null).map((e) => (e as num).toDouble()).toList();
  }

  // --- 2. RSI (Relative Strength Index) ---
  static Future<double> calculateRSI(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 20);
    final prices = data['close']!;
    if (prices.length < period + 1) return 50.0;

    double gain = 0.0, loss = 0.0;
    for (int i = 1; i <= period; i++) {
      double change = prices[i] - prices[i - 1];
      if (change > 0) gain += change; else loss += change.abs();
    }
    double avgGain = gain / period;
    double avgLoss = loss / period;

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

  // --- 3. BOLLINGER BANDS ---
  static Future<Map<String, double>> calculateBollingerBands(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 5);
    final prices = data['close']!;
    if (prices.length < period) return {'upper': 0, 'middle': 0, 'lower': 0};
    
    final segment = prices.sublist(prices.length - period);
    double mean = segment.reduce((a, b) => a + b) / period;
    double variance = segment.map((p) => pow(p - mean, 2)).reduce((a, b) => a + b) / period;
    double stdDev = sqrt(variance);
    
    return {'upper': mean + (2 * stdDev), 'middle': mean, 'lower': mean - (2 * stdDev)};
  }

  // --- 4. MACD ---
  static Future<Map<String, double>> calculateMACD(String symbol) async {
    final data = await getHistoricalData(symbol, 40); 
    final prices = data['close']!;
    if (prices.length < 26) return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};

    List<double> slice12 = prices.sublist(max(0, prices.length - 12));
    List<double> slice26 = prices.sublist(max(0, prices.length - 26));

    double ema12 = _calculateEMA(slice12, 12);
    double ema26 = _calculateEMA(slice26, 26);
    
    double macdLine = ema12 - ema26;
    double signalLine = macdLine * 0.9; 
    return {'macd': macdLine, 'signal': signalLine, 'histogram': macdLine - signalLine};
  }

  // --- 5. SMA (Simple Moving Average - 50 Day) ---
  static Future<double> calculateSMA(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 5);
    final prices = data['close']!;
    if (prices.length < period) return 0.0;
    
    final segment = prices.sublist(prices.length - period);
    return segment.reduce((a, b) => a + b) / period;
  }

  // --- 6. EMA (Exponential Moving Average - 20 Day) ---
  static Future<double> calculateEMA(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 10);
    final prices = data['close']!;
    if (prices.length < period) return 0.0;
    
    return _calculateEMA(prices.sublist(prices.length - period), period);
  }

  static double _calculateEMA(List<double> values, int period) {
    if (values.isEmpty) return 0.0;
    double k = 2 / (period + 1);
    double ema = values[0];
    for (int i = 1; i < values.length; i++) {
      ema = values[i] * k + ema * (1 - k);
    }
    return ema;
  }

  // --- 7. STOCHASTIC OSCILLATOR ---
  static Future<Map<String, double>> calculateStochastic(String symbol) async {
    final data = await getHistoricalData(symbol, 20);
    final closes = data['close']!;
    final highs = data['high']!;
    final lows = data['low']!;
    
    if (closes.length < 14) return {'k': 50.0, 'd': 50.0};

    // Calculate %K
    double currentClose = closes.last;
    double lowestLow = lows.sublist(lows.length - 14).reduce(min);
    double highestHigh = highs.sublist(highs.length - 14).reduce(max);
    
    double k = 50.0;
    if (highestHigh != lowestLow) {
      k = ((currentClose - lowestLow) / (highestHigh - lowestLow)) * 100;
    }

    // Calculate %D (3-day SMA of %K) - approximated here as just K for simplicity or smoothed
    double d = k; 
    return {'k': k, 'd': d};
  }

  // --- 8. CCI (Commodity Channel Index) ---
  static Future<double> calculateCCI(String symbol) async {
    final data = await getHistoricalData(symbol, 25);
    final closes = data['close']!;
    final highs = data['high']!;
    final lows = data['low']!;
    
    if (closes.length < 20) return 0.0;

    List<double> tp = [];
    for(int i=0; i<closes.length; i++) {
      tp.add((highs[i] + lows[i] + closes[i]) / 3);
    }
    
    List<double> recentTP = tp.sublist(tp.length - 20);
    double smaTP = recentTP.reduce((a,b) => a+b) / 20;
    
    double meanDev = 0.0;
    for(var p in recentTP) meanDev += (p - smaTP).abs();
    meanDev /= 20;
    
    if (meanDev == 0) return 0.0;
    return (tp.last - smaTP) / (0.015 * meanDev);
  }

  // --- 9. WILLIAMS %R ---
  static Future<double> calculateWilliamsR(String symbol) async {
    final data = await getHistoricalData(symbol, 20);
    final closes = data['close']!;
    final highs = data['high']!;
    final lows = data['low']!;

    if (closes.length < 14) return -50.0;

    double currentClose = closes.last;
    double highestHigh = highs.sublist(highs.length - 14).reduce(max);
    double lowestLow = lows.sublist(lows.length - 14).reduce(min);

    if (highestHigh == lowestLow) return -50.0;
    return ((highestHigh - currentClose) / (highestHigh - lowestLow)) * -100;
  }

  // --- 10. ATR & HELPERS ---
  static Future<double> calculateRealATR(String symbol) async {
    final data = await getHistoricalData(symbol, 15);
    final closes = data['close']!;
    final highs = data['high']!;
    final lows = data['low']!;

    if (closes.length < 14) return 0.0;
    List<double> trValues = [];
    for (int i = 1; i < closes.length; i++) {
      double hl = highs[i] - lows[i];
      double hc = (highs[i] - closes[i-1]).abs();
      double lc = (lows[i] - closes[i-1]).abs();
      trValues.add([hl, hc, lc].reduce(max));
    }
    if (trValues.isEmpty) return 0.0;
    return trValues.reduce((a, b) => a + b) / trValues.length;
  }

  // Volume & Sentiment Helpers
  static Future<double> getVolumeRatio(String symbol) async {
    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=5d&interval=1d';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['chart']['result'][0];
        List<dynamic> volRaw = result['indicators']['quote'][0]['volume'];
        List<double> vols = _cleanList(volRaw);
        if (vols.length < 2) return 1.0;
        return vols.last / (vols.reduce((a,b)=>a+b)/vols.length);
      }
    } catch (_) {}
    return 1.0;
  }

  static Future<String> getMarketSentiment(String symbol) async {
    final rsi = await calculateRSI(symbol, 14);
    if (rsi > 70) return "Bearish (Overbought)";
    if (rsi < 30) return "Bullish (Oversold)";
    return "Neutral";
  }

  static Future<Map<String, double>> getStockDetails(String symbol) async {
    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final meta = json['chart']['result'][0]['meta'];
        final currentPrice = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['chartPreviousClose'] as num).toDouble();
        return {'price': currentPrice, 'change': currentPrice - prevClose, 'percent': prevClose!=0?((currentPrice-prevClose)/prevClose)*100:0.0};
      }
    } catch (_) {}
    return {}; 
  }
}