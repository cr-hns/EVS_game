import 'package:flutter/foundation.dart';
import '../models/city_state.dart';
import '../models/pollution_metrics.dart';
import '../models/building.dart';
import '../models/advisor_message.dart';
import '../simulation/turn_processor.dart';
import '../data/buildings_data.dart';

class GameController extends ChangeNotifier {
  late CityState state;
  BuildingType? selectedBuilding;
  bool isDemolishMode = false;
  SimulationResult? lastResult;
  AdvisorMessage? activeAdvisorDialog;

  GameController() {
    startNewGame('Eco City', 'medium');
  }

  void startNewGame(String name, String difficulty) {
    // Generate 20x20 terrain (with river cutting through middle)
    final grid = List.generate(20, (y) {
      return List.generate(20, (x) {
        if (x == 9 || x == 10) return 'water_clean';
        if (x == 8 || x == 11) return 'sand';
        return 'grass';
      });
    });

    final prePlaced = <PlacedBuilding>[];
    int startFunds = 5000;
    int startGems = 10;
    PollutionMetrics initialMetrics = const PollutionMetrics(
      aqi: 120.0,
      waterPurity: 45.0,
      soilHealth: 50.0,
      noiseWaste: 60.0,
    );

    if (difficulty == 'easy') {
      startFunds = 8000;
      startGems = 20;
      initialMetrics = const PollutionMetrics(
        aqi: 70.0,
        waterPurity: 65.0,
        soilHealth: 65.0,
        noiseWaste: 40.0,
      );
      prePlaced.add(const PlacedBuilding(id: 'c1', buildingTypeId: 'coal_plant', gridX: 4, gridY: 4));
      prePlaced.add(const PlacedBuilding(id: 'h1', buildingTypeId: 'house', gridX: 13, gridY: 6));
      prePlaced.add(const PlacedBuilding(id: 'h2', buildingTypeId: 'house', gridX: 14, gridY: 6));
    } else if (difficulty == 'medium') {
      prePlaced.add(const PlacedBuilding(id: 'c1', buildingTypeId: 'coal_plant', gridX: 3, gridY: 3));
      prePlaced.add(const PlacedBuilding(id: 'f1', buildingTypeId: 'factory', gridX: 5, gridY: 6));
      prePlaced.add(const PlacedBuilding(id: 'l1', buildingTypeId: 'landfill', gridX: 2, gridY: 14));
      prePlaced.add(const PlacedBuilding(id: 'a1', buildingTypeId: 'apartment', gridX: 14, gridY: 5));
    } else {
      // Hard
      startFunds = 3000;
      startGems = 5;
      initialMetrics = const PollutionMetrics(
        aqi: 180.0,
        waterPurity: 30.0,
        soilHealth: 35.0,
        noiseWaste: 75.0,
      );
      prePlaced.add(const PlacedBuilding(id: 'c1', buildingTypeId: 'coal_plant', gridX: 3, gridY: 3));
      prePlaced.add(const PlacedBuilding(id: 'c2', buildingTypeId: 'coal_plant', gridX: 5, gridY: 3));
      prePlaced.add(const PlacedBuilding(id: 'f1', buildingTypeId: 'factory', gridX: 3, gridY: 7));
      prePlaced.add(const PlacedBuilding(id: 'o1', buildingTypeId: 'oil_refinery', gridX: 6, gridY: 10));
      prePlaced.add(const PlacedBuilding(id: 'l1', buildingTypeId: 'landfill', gridX: 2, gridY: 15));
    }

    state = CityState(
      cityName: name,
      difficulty: difficulty,
      turn: 1,
      funds: startFunds,
      gems: startGems,
      population: 150,
      happiness: 60.0,
      metrics: initialMetrics,
      buildings: prePlaced,
      terrain: grid,
    );
    notifyListeners();
  }

  void selectBuilding(BuildingType? type) {
    selectedBuilding = type;
    isDemolishMode = false;
    notifyListeners();
  }

  void toggleDemolish() {
    isDemolishMode = !isDemolishMode;
    selectedBuilding = null;
    notifyListeners();
  }

  bool placeBuildingAt(int gridX, int gridY) {
    if (isDemolishMode) {
      // Find building that covers this cell
      PlacedBuilding? toRemove;
      for (final b in state.buildings) {
        final type = BuildingsData.all[b.buildingTypeId];
        if (type == null) continue;
        if (gridX >= b.gridX &&
            gridX < b.gridX + type.width &&
            gridY >= b.gridY &&
            gridY < b.gridY + type.height) {
          toRemove = b;
          break;
        }
      }
      if (toRemove != null) {
        final newBuildings = List<PlacedBuilding>.from(state.buildings)..remove(toRemove);
        state = state.copyWith(
          funds: state.funds - 50, // demolition fee
          buildings: newBuildings,
        );
        notifyListeners();
        return true;
      }
      return false;
    }

    if (selectedBuilding == null) return false;
    final bType = selectedBuilding!;

    // Boundary check
    if (gridX + bType.width > 20 || gridY + bType.height > 20) return false;

    // Affordability check
    if (!state.canAfford(bType)) return false;

    // Collision check
    for (int y = 0; y < bType.height; y++) {
      for (int x = 0; x < bType.width; x++) {
        final targetX = gridX + x;
        final targetY = gridY + y;
        if (state.isCellOccupied(targetX, targetY)) return false;
        // Don't build directly on water unless water treatment
        if (state.terrain[targetY][targetX] == 'water_clean' && bType.id != 'water_treatment') {
          return false;
        }
      }
    }

    final placed = PlacedBuilding(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      buildingTypeId: bType.id,
      gridX: gridX,
      gridY: gridY,
    );

    final newBuildings = List<PlacedBuilding>.from(state.buildings)..add(placed);
    state = state.copyWith(
      funds: state.funds - bType.cost,
      gems: state.gems - bType.gemCost,
      buildings: newBuildings,
    );
    notifyListeners();
    return true;
  }

  void endDay() {
    final result = TurnProcessor.processTurn(state);
    lastResult = result;
    state = result.nextState;
    if (result.messages.isNotEmpty) {
      activeAdvisorDialog = result.messages.first;
    }
    notifyListeners();
  }

  void dismissAdvisor() {
    activeAdvisorDialog = null;
    notifyListeners();
  }
}
