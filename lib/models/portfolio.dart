class PortfolioPosition {
  final String symbol;
  final String companyName;
  final int shares;
  final double entryPrice;
  final double currentPrice;
  final DateTime entryDate;

  PortfolioPosition({
    required this.symbol,
    required this.companyName,
    required this.shares,
    required this.entryPrice,
    required this.currentPrice,
    required this.entryDate,
  });

  double get marketValue => shares * currentPrice;
  double get costBasis => shares * entryPrice;
  double get unrealizedPnL => marketValue - costBasis;
  double get unrealizedPnLPercent => (unrealizedPnL / costBasis) * 100;
  bool get isProfit => unrealizedPnL >= 0;
}