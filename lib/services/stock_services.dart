import 'dart:convert';
import 'package:http/http.dart' as http;

class StockService {
  // Yahoo Finance API 
  static const String _baseUrl = 'https://query1.finance.yahoo.com/v8/finance/chart';

  static Future<Map<String, dynamic>> getRealStockQuote(String symbol) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$symbol'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['chart']?['result'] != null && data['chart']['result'].isNotEmpty) {
          final result = data['chart']['result'][0];
          final meta = result['meta'];
          
          final currentPrice = meta['regularMarketPrice'] ?? 0.0;
          final previousClose = meta['previousClose'] ?? currentPrice;
          final change = currentPrice - previousClose;
          final changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0.0;
          
          return {
            'symbol': symbol,
            'price': currentPrice.toDouble(),
            'change': change.toDouble(),
            'changePercent': changePercent.toDouble(),
            'volume': meta['regularMarketVolume']?.toInt() ?? 0,
            'isRealData': true,
          };
        }
      }
    } catch (e) {
      print('Error fetching $symbol: $e');
    }
    
    // Fallback to demo data only if API fails
    return _getDemoStockData(symbol);
  }

  static Future<List<Map<String, dynamic>>> getMultipleStockQuotes(List<String> symbols) async {
    List<Map<String, dynamic>> results = [];
    
    for (String symbol in symbols) {
      final stockData = await getRealStockQuote(symbol);
      results.add(stockData);
    }
    
    return results;
  }

  static Map<String, dynamic> _getDemoStockData(String symbol) {
    final demoData = {
      'AAPL': {'price': 172.35, 'change': 2.10, 'changePercent': 1.24},
      'MSFT': {'price': 415.50, 'change': -2.20, 'changePercent': -0.53},
      'GOOGL': {'price': 151.65, 'change': 3.22, 'changePercent': 2.17},
      'TSLA': {'price': 175.79, 'change': -6.22, 'changePercent': -3.42},
      'AMZN': {'price': 178.22, 'change': 1.50, 'changePercent': 0.85},
      'META': {'price': 485.75, 'change': 9.18, 'changePercent': 1.92},
      'NVDA': {'price': 950.02, 'change': 38.75, 'changePercent': 4.25},
      'JPM': {'price': 198.34, 'change': -2.31, 'changePercent': -1.15},
    };
    
    final data = demoData[symbol] ?? {'price': 100.0, 'change': 0.0, 'changePercent': 0.0};
    return {
      'symbol': symbol,
      'price': data['price']!,
      'change': data['change']!,
      'changePercent': data['changePercent']!,
      'volume': 0,
      'isRealData': false,
    };
  }
}