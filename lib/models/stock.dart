class Stock {
  final String symbol;
  final String companyName;
  final double currentPrice;
  final double change;
  final double changePercent;

  const Stock({
    required this.symbol,
    required this.companyName,
    required this.currentPrice,
    required this.change,
    required this.changePercent,
  });

  // Demo data factory - made const
  factory Stock.demo(String symbol, String companyName, double price, double percent) {
    return Stock(
      symbol: symbol,
      companyName: companyName,
      currentPrice: price,
      change: price * percent / 100,
      changePercent: percent,
    );
  }
}