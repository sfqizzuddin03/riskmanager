class PortfolioManager {
  double portfolioValue;
  double riskPerTrade; // As decimal (0.02 = 2%)
  double maxPortfolioRisk; // As decimal (0.10 = 10%)

  PortfolioManager({
    required this.portfolioValue,
    this.riskPerTrade = 0.02,
    this.maxPortfolioRisk = 0.10,
  });

  // Simple position size calculation
  Map<String, dynamic> calculateSimplePosition(double entryPrice, double stopLossPrice) {
    final stopLossPercent = ((entryPrice - stopLossPrice).abs() / entryPrice) * 100;
    final riskAmount = portfolioValue * riskPerTrade;
    final maxShares = (riskAmount / (entryPrice * (stopLossPercent / 100))).floorToDouble();
    final positionValue = maxShares * entryPrice;

    return {
      'maxShares': maxShares,
      'positionValue': positionValue,
      'portfolioPercentage': (positionValue / portfolioValue) * 100,
      'riskAmount': riskAmount,
      'stopLossPercent': stopLossPercent,
    };
  }

  // Simple risk validation
  Map<String, dynamic> validateSimplePosition(double positionValue, double stopLossPercent) {
    final positionRisk = positionValue * (stopLossPercent / 100);
    final portfolioRiskPercentage = (positionRisk / portfolioValue) * 100;
    final isWithinLimits = portfolioRiskPercentage <= (riskPerTrade * 100);

    return {
      'isWithinLimits': isWithinLimits,
      'currentRisk': portfolioRiskPercentage,
      'allowedRisk': riskPerTrade * 100,
      'suggestedAdjustment': isWithinLimits ? null : 'Reduce position',
    };
  }

  // Simple portfolio metrics
  Map<String, dynamic> calculateSimpleMetrics(List<Map<String, dynamic>> positions) {
    double totalRisk = 0.0;
    int warningCount = 0;

    for (final position in positions) {
      final positionValue = position['currentPrice'] * position['quantity'];
      final stopLossPercent = ((position['entryPrice'] - position['stopLoss']).abs() / position['entryPrice']) * 100;
      final positionRisk = positionValue * (stopLossPercent / 100);
      totalRisk += positionRisk;

      if (position['currentPrice'] <= position['stopLoss'] * 1.02) {
        warningCount++;
      }
    }

    final portfolioRiskPercent = (totalRisk / portfolioValue) * 100;

    return {
      'totalValue': portfolioValue,
      'totalRisk': totalRisk,
      'portfolioRiskPercent': portfolioRiskPercent,
      'warningCount': warningCount,
      'riskStatus': portfolioRiskPercent > (maxPortfolioRisk * 100) ? 'HIGH RISK' : 'WITHIN LIMITS',
    };
  }
}