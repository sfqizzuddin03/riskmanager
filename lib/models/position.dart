class Position {
  final String symbol;
  final int quantity;
  final double entryPrice;
  final double currentPrice;
  final double stopLoss;
  final double positionSizePercent;

  Position({
    required this.symbol,
    required this.quantity,
    required this.entryPrice,
    required this.currentPrice,
    required this.stopLoss,
    required this.positionSizePercent,
  });

  double get marketValue => quantity * currentPrice;
  double get pnl => (currentPrice - entryPrice) * quantity;
  double get pnlPercent => ((currentPrice - entryPrice) / entryPrice) * 100;
  bool get isStopLossHit => currentPrice <= stopLoss;
}