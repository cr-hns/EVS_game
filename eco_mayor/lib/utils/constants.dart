class GameConstants {
  // Grid & Map Dimensions
  static const int gridCols = 20;
  static const int gridRows = 20;
  static const double tileSize = 32.0;

  // Green Zone Thresholds (Win Conditions)
  static const double maxGreenAqi = 50.0;
  static const double minGreenWater = 80.0;
  static const double minGreenSoil = 75.0;
  static const double maxGreenNoiseWaste = 30.0;

  // Critical Failure Limits
  static const double criticalMaxAqi = 250.0;
  static const double criticalMinWater = 15.0;
  static const double criticalMinSoil = 15.0;
  static const double criticalMaxNoiseWaste = 90.0;
  static const int minSustainablePopulation = 50;

  // Currencies & Starting Values
  static const int streakGemBonus = 5;
}
