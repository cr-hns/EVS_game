import 'pollution_metrics.dart';
import 'building.dart';
import '../data/buildings_data.dart';

class CityState {
  final String cityName;
  final String difficulty; // easy, medium, hard
  final int turn;
  final int funds;
  final int gems;
  final int population;
  final double happiness; // 0 - 100%
  final PollutionMetrics metrics;
  final List<PlacedBuilding> buildings;
  final List<List<String>> terrain; // 20x20 terrain tile IDs ('grass', 'water', etc.)
  final int criticalDays; // consecutive days spent in critical pollution state
  final bool infiniteMode; // true after the player wins and keeps building

  const CityState({
    required this.cityName,
    required this.difficulty,
    required this.turn,
    required this.funds,
    required this.gems,
    required this.population,
    required this.happiness,
    required this.metrics,
    required this.buildings,
    required this.terrain,
    this.criticalDays = 0,
    this.infiniteMode = false,
  });

  CityState copyWith({
    String? cityName,
    String? difficulty,
    int? turn,
    int? funds,
    int? gems,
    int? population,
    double? happiness,
    PollutionMetrics? metrics,
    List<PlacedBuilding>? buildings,
    List<List<String>>? terrain,
    int? criticalDays,
    bool? infiniteMode,
  }) {
    return CityState(
      cityName: cityName ?? this.cityName,
      difficulty: difficulty ?? this.difficulty,
      turn: turn ?? this.turn,
      funds: funds ?? this.funds,
      gems: gems ?? this.gems,
      population: population ?? this.population,
      happiness: (happiness ?? this.happiness).clamp(0.0, 100.0),
      metrics: metrics ?? this.metrics,
      buildings: buildings ?? this.buildings,
      terrain: terrain ?? this.terrain,
      criticalDays: criticalDays ?? this.criticalDays,
      infiniteMode: infiniteMode ?? this.infiniteMode,
    );
  }

  bool canAfford(BuildingType building) {
    return funds >= building.cost && gems >= building.gemCost;
  }

  bool isCellOccupied(int x, int y) {
    for (final b in buildings) {
      final type = BuildingsData.all[b.buildingTypeId];
      if (type == null) continue;
      if (x >= b.gridX &&
          x < b.gridX + type.width &&
          y >= b.gridY &&
          y < b.gridY + type.height) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
        'cityName': cityName,
        'difficulty': difficulty,
        'turn': turn,
        'funds': funds,
        'gems': gems,
        'population': population,
        'happiness': happiness,
        'metrics': metrics.toJson(),
        'buildings': buildings.map((b) => b.toJson()).toList(),
        'terrain': terrain,
        'criticalDays': criticalDays,
        'infiniteMode': infiniteMode,
      };

  factory CityState.fromJson(Map<String, dynamic> json) => CityState(
        cityName: json['cityName'] as String,
        difficulty: json['difficulty'] as String,
        turn: json['turn'] as int,
        funds: json['funds'] as int,
        gems: json['gems'] as int,
        population: json['population'] as int,
        happiness: (json['happiness'] as num).toDouble(),
        metrics:
            PollutionMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
        buildings: (json['buildings'] as List)
            .map((b) => PlacedBuilding.fromJson(b as Map<String, dynamic>))
            .toList(),
        terrain: (json['terrain'] as List)
            .map((row) => (row as List).map((cell) => cell as String).toList())
            .toList(),
        criticalDays: (json['criticalDays'] as int?) ?? 0,
        infiniteMode: (json['infiniteMode'] as bool?) ?? false,
      );
}
