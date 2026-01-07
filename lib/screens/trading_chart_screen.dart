import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TradingChartScreen extends StatefulWidget {
  final String symbol;
  const TradingChartScreen({super.key, required this.symbol});

  @override
  State<TradingChartScreen> createState() => _TradingChartScreenState();
}

class _TradingChartScreenState extends State<TradingChartScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    // Construct the TradingView Widget URL
    // This removes the headers/footers and just shows the candle chart
    final url = Uri.parse("https://www.tradingview.com/chart/?symbol=${widget.symbol}");

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.symbol} Analysis"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}