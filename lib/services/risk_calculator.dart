import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RiskCalculator {
  
  // --- CORE: FETCH REAL DATA ---
  static Future<Map<String, List<double>>> getHistoricalData(String symbol, int days) async {
    // Fetch extra data for indicators like MACD/EMA that need "warm up"
    final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?range=${days + 50}d&interval=1d';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['chart']['result'];
        
        if (result == null || result.isEmpty) return {};

        final quote = result[0]['indicators']['quote'][0];
        
        return {
          'close': _cleanList(quote['close']),
          'high': _cleanList(quote['high']),
          'low': _cleanList(quote['low']),
          'volume': _cleanList(quote['volume']),
        };
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
    return {};
  }

  // --- HELPER: GET LIVE PRICE (For Watchlist) ---
  static Future<Map<String, double>> getStockDetails(String symbol) async {
    try {
      final url = 'https://query1.finance.yahoo.com/v8/finance/chart/$symbol?interval=1d&range=1d';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['chart']['result'];
        if (result == null || result.isEmpty) return {};

        final meta = result[0]['meta'];
        final currentPrice = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0.0;
        final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ?? 0.0;
        
        double changePercent = 0.0;
        if (prevClose != 0) {
           changePercent = ((currentPrice - prevClose) / prevClose) * 100;
        }

        return {'price': currentPrice, 'percent': changePercent};
      }
    } catch (e) {
      print("Error fetching price for $symbol: $e");
    }
    return {}; 
  }

  static List<double> _cleanList(List<dynamic> raw) {
    return raw.where((e) => e != null).map((e) => (e as num).toDouble()).toList();
  }

  // --- 1. RSI ---
  static Future<double> calculateRSI(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period + 20);
    final prices = data['close'] ?? [];
    if (prices.length < period + 1) return 50.0;

    double gain = 0.0;
    double loss = 0.0;

    for (int i = 1; i <= period; i++) {
      double change = prices[i] - prices[i - 1];
      if (change > 0) gain += change;
      else loss += change.abs();
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

  // --- 2. MACD (The Professional Indicator) ---
  static Future<Map<String, double>> calculateMACD(String symbol) async {
    final data = await getHistoricalData(symbol, 60); 
    final prices = data['close'] ?? [];
    
    if (prices.length < 26) return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};

    List<double> ema12 = _calculateEMA(prices, 12);
    List<double> ema26 = _calculateEMA(prices, 26);
    List<double> macdLine = [];
    int minLength = min(ema12.length, ema26.length);
    int offset12 = ema12.length - minLength;
    int offset26 = ema26.length - minLength;

    for(int i=0; i<minLength; i++) {
      macdLine.add(ema12[i + offset12] - ema26[i + offset26]);
    }

    List<double> signalLine = _calculateEMA(macdLine, 9);

    if (macdLine.isEmpty || signalLine.isEmpty) return {'macd': 0.0, 'signal': 0.0, 'histogram': 0.0};
    
    return {
      'macd': macdLine.last,
      'signal': signalLine.last,
      'histogram': macdLine.last - signalLine.last
    };
  }

  static List<double> _calculateEMA(List<double> prices, int period) {
    if (prices.isEmpty) return [];
    List<double> ema = [];
    double multiplier = 2 / (period + 1);
    double sum = 0;
    int initialSlice = min(period, prices.length);
    for(int i=0; i<initialSlice; i++) sum += prices[i];
    double prevEma = sum / initialSlice;
    
    for (int i = initialSlice; i < prices.length; i++) {
      double currentVal = (prices[i] - prevEma) * multiplier + prevEma;
      ema.add(currentVal);
      prevEma = currentVal;
    }
    return ema;
  }

  // --- 3. BOLLINGER BANDS ---
  static Future<Map<String, double>> calculateBollingerBands(String symbol, int period) async {
    final data = await getHistoricalData(symbol, period);
    final prices = data['close'] ?? [];
    if (prices.length < period) return {'upper': 0, 'middle': 0, 'lower': 0};

    final segment = prices.sublist(prices.length - period);
    double mean = segment.reduce((a, b) => a + b) / period;
    double variance = segment.map((p) => pow(p - mean, 2)).reduce((a, b) => a + b) / period;
    double stdDev = sqrt(variance);

    return {
      'upper': mean + (2 * stdDev),
      'middle': mean,
      'lower': mean - (2 * stdDev),
    };
  }

  // --- 4. REAL ATR (Volatility) ---
  static Future<double> calculateRealATR(String symbol) async {
    final data = await getHistoricalData(symbol, 20);
    final closes = data['close'] ?? [];
    final highs = data['high'] ?? [];
    final lows = data['low'] ?? [];

    if (closes.length < 15) return 0.0;

    List<double> trValues = [];
    for (int i = 1; i < closes.length; i++) {
      double hl = highs[i] - lows[i]; 
      double hc = (highs[i] - closes[i-1]).abs(); 
      double lc = (lows[i] - closes[i-1]).abs(); 
      trValues.add([hl, hc, lc].reduce(max));
    }
    return trValues.reduce((a,b) => a+b) / trValues.length;
  }

  // --- 5. MARKET SENTIMENT (RESTORED) ---
  static Future<String> getMarketSentiment(String symbol) async {
    // We can reuse RSI logic here for speed
    double rsi = await calculateRSI(symbol, 14);
    if (rsi > 70) return "Overbought";
    if (rsi < 30) return "Oversold";
    
    // Check recent trend
    final data = await getHistoricalData(symbol, 5);
    final prices = data['close'] ?? [];
    if(prices.length >= 2) {
      if (prices.last > prices[prices.length - 2]) return "Bullish";
      return "Bearish";
    }
    return "Neutral";
  }

  // --- 6. VOLUME RATIO (RESTORED) ---
  static Future<double> getVolumeRatio(String symbol) async {
    final data = await getHistoricalData(symbol, 10);
    final vols = data['volume'] ?? [];
    if (vols.length < 5) return 1.0;

    double current = vols.last;
    // Average of previous 5 days
    double sum = 0;
    for(int i=vols.length-6; i<vols.length-1; i++) {
       if (i >= 0) sum += vols[i];
    }
    double avg = sum / 5;
    
    if (avg == 0) return 1.0;
    return current / avg;
  }
}