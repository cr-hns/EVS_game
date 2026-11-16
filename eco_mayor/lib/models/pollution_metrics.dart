class PollutionMetrics {
  final double aqi; // 0 - 300 (Lower is better)
  final double waterPurity; // 0 - 100% (Higher is better)
  final double soilHealth; // 0 - 100% (Higher is better)
  final double noiseWaste; // 0 - 100 (Lower is better)

  const PollutionMetrics({
    required this.aqi,
    required this.waterPurity,
    required this.soilHealth,
    required this.noiseWaste,
  });

  PollutionMetrics copyWith({
    double? aqi,
    double? waterPurity,
    double? soilHealth,
    double? noiseWaste,
  }) {
    return PollutionMetrics(
      aqi: (aqi ?? this.aqi).clamp(0.0, 300.0),
      waterPurity: (waterPurity ?? this.waterPurity).clamp(0.0, 100.0),
      soilHealth: (soilHealth ?? this.soilHealth).clamp(0.0, 100.0),
      noiseWaste: (noiseWaste ?? this.noiseWaste).clamp(0.0, 100.0),
    );
  }

  bool isGreenZone() {
    return aqi <= 50.0 &&
        waterPurity >= 80.0 &&
        soilHealth >= 75.0 &&
        noiseWaste <= 30.0;
  }

  bool isCritical() {
    return aqi >= 250.0 ||
        waterPurity <= 15.0 ||
        soilHealth <= 15.0 ||
        noiseWaste >= 90.0;
  }

  Map<String, dynamic> toJson() => {
    'aqi': aqi,
    'waterPurity': waterPurity,
    'soilHealth': soilHealth,
    'noiseWaste': noiseWaste,
  };

  factory PollutionMetrics.fromJson(Map<String, dynamic> json) =>
      PollutionMetrics(
        aqi: (json['aqi'] as num).toDouble(),
        waterPurity: (json['waterPurity'] as num).toDouble(),
        soilHealth: (json['soilHealth'] as num).toDouble(),
        noiseWaste: (json['noiseWaste'] as num).toDouble(),
      );
}
