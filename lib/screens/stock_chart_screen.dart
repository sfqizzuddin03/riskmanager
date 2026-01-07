import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class StockChartScreen extends StatelessWidget {
  final String symbol;
  final String companyName;

  const StockChartScreen({super.key, required this.symbol, required this.companyName});

  Future<void> _openTradingView() async {
    final url = 'https://www.tradingview.com/chart/?symbol=$symbol';
    if (!await launchUrl(Uri.parse(url))) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$symbol Chart'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.candlestick_chart,
              size: 64,
              color: Colors.blueGrey,
            ),
            const SizedBox(height: 20),
            const Text(
              'Professional Chart',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Open $symbol chart in TradingView',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _openTradingView,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              child: const Text('Open TradingView Chart'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text('• Real candlestick charts'),
            const Text('• Multiple timeframes'),
            const Text('• Technical indicators'),
            const Text('• Zoom & drawing tools'),
          ],
        ),
      ),
    );
  }
}