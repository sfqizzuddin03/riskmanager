class RiskMetrics {
  final double portfolioValue;
  final double dailyVaR;
  final double portfolioVolatility;
  final double maxDrawdown;
  final double sharpeRatio;
  final double beta;
  final double correlation;

  RiskMetrics({
    required this.portfolioValue,
    required this.dailyVaR,
    required this.portfolioVolatility,
    required this.maxDrawdown,
    required this.sharpeRatio,
    required this.beta,
    required this.correlation,
  });
}