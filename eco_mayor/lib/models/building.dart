enum BuildingCategory { industry, residential, green, infrastructure }

class BuildingType {
  final String id;
  final String name;
  final BuildingCategory category;
  final int cost;
  final int gemCost;
  final int revenuePerTurn;
  final int population;
  final double aqiDelta;
  final double waterDelta;
  final double soilDelta;
  final double noiseWasteDelta;
  final int width;
  final int height;
  final String spritePath;
  final String description;

  const BuildingType({
    required this.id,
    required this.name,
    required this.category,
    required this.cost,
    this.gemCost = 0,
    required this.revenuePerTurn,
    this.population = 0,
    required this.aqiDelta,
    required this.waterDelta,
    required this.soilDelta,
    required this.noiseWasteDelta,
    this.width = 1,
    this.height = 1,
    required this.spritePath,
    required this.description,
  });
}

class PlacedBuilding {
  final String id;
  final String buildingTypeId;
  final int gridX;
  final int gridY;

  const PlacedBuilding({
    required this.id,
    required this.buildingTypeId,
    required this.gridX,
    required this.gridY,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'buildingTypeId': buildingTypeId,
    'gridX': gridX,
    'gridY': gridY,
  };

  factory PlacedBuilding.fromJson(Map<String, dynamic> json) => PlacedBuilding(
    id: json['id'] as String,
    buildingTypeId: json['buildingTypeId'] as String,
    gridX: json['gridX'] as int,
    gridY: json['gridY'] as int,
  );
}
