

class RiskEngine {
  List<String> evaluateRisk({
    required String symbol,
    required double currentPrice,
    required double sma50,
    required double liveATR,
    required double historicalATR,
    required double volumeRatio,
  }) {
    List<String> warnings = [];

    // RULE 1: Trend Breakdown (Price < SMA50)
    // If price is below the 50-day average, the long-term trend is broken.
    if (currentPrice < sma50) {
      warnings.add("Trend Breakdown: Price is below 50-day SMA.");
    }

    // RULE 2: Volatility Spike (Live ATR > Historical ATR)
    // If today's volatility is much higher than normal, it's risky.
    if (liveATR > (historicalATR * 1.5)) {
      warnings.add("Volatility Spike: Market is moving too fast.");
    }

    // RULE 3: Weak Buying Pressure (Low Volume)
    // If volume is half of normal, the move might be fake.
    if (volumeRatio < 0.5) {
      warnings.add("Low Volume: Weak buying interest.");
    }

    return warnings;
  }
}