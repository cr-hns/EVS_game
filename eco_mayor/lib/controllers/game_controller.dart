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

  /// Set when a turn ends in victory or defeat; the gameplay screen shows
  /// an end-of-game overlay while this is non-null.
  SimulationResult? gameOutcome;
  bool get isGameOver => gameOutcome != null;

  /// Short on-screen message (e.g. why a placement failed). [toastId] changes
  /// every time so the UI can restart its fade animation.
  String? toast;
  bool toastIsError = false;
  int toastId = 0;

  void showToast(String message, {bool error = false}) {
    toast = message;
    toastIsError = error;
    toastId++;
    notifyListeners();
  }

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

    gameOutcome = null;
    lastResult = null;
    activeAdvisorDialog = null;
    selectedBuilding = null;
    isDemolishMode = false;
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
    selectedBuilding = selectedBuilding?.id == type?.id ? null : type;
    activeAdvisorDialog = null;
    isDemolishMode = false;
    notifyListeners();
  }

  void toggleDemolish() {
    isDemolishMode = !isDemolishMode;
    activeAdvisorDialog = null;
    selectedBuilding = null;
    notifyListeners();
  }

  static const int demolishCost = 50;

  /// Handles a tap on map cell (gridX, gridY): demolishes or places the
  /// selected building. Returns true if the city changed.
  bool placeBuildingAt(int gridX, int gridY) {
    if (isGameOver) return false;

    if (isDemolishMode) {
      PlacedBuilding? target;
      for (final b in state.buildings) {
        final type = BuildingsData.all[b.buildingTypeId];
        if (type == null) continue;
        if (gridX >= b.gridX &&
            gridX < b.gridX + type.width &&
            gridY >= b.gridY &&
            gridY < b.gridY + type.height) {
          target = b;
          break;
        }
      }
      if (target == null) {
        showToast('Nothing to demolish here', error: true);
        return false;
      }
      if (state.funds < demolishCost) {
        showToast('Demolition costs \$$demolishCost', error: true);
        return false;
      }
      final name = BuildingsData.all[target.buildingTypeId]?.name ?? 'Building';
      final kept = state.buildings.where((b) => b.id != target!.id).toList();
      state = state.copyWith(funds: state.funds - demolishCost, buildings: kept);
      showToast('$name demolished  -\$$demolishCost');
      return true;
    }

    final bType = selectedBuilding;
    if (bType == null) return false;

    if (gridX + bType.width > 20 || gridY + bType.height > 20) {
      showToast('Not enough room at the map edge', error: true);
      return false;
    }
    if (state.funds < bType.cost) {
      showToast('Need \$${bType.cost - state.funds} more', error: true);
      return false;
    }
    if (state.gems < bType.gemCost) {
      showToast('Need ${bType.gemCost - state.gems} more Eco-Gems', error: true);
      return false;
    }
    for (int y = 0; y < bType.height; y++) {
      for (int x = 0; x < bType.width; x++) {
        final tx = gridX + x;
        final ty = gridY + y;
        if (state.isCellOccupied(tx, ty)) {
          showToast('That spot is taken', error: true);
          return false;
        }
        if (state.terrain[ty][tx] == 'water_clean' && bType.id != 'water_treatment') {
          showToast("Can't build on the river", error: true);
          return false;
        }
      }
    }

    final placed = PlacedBuilding(
      id: 'b_${DateTime.now().microsecondsSinceEpoch}',
      buildingTypeId: bType.id,
      gridX: gridX,
      gridY: gridY,
    );
    state = state.copyWith(
      funds: state.funds - bType.cost,
      gems: state.gems - bType.gemCost,
      buildings: [...state.buildings, placed],
    );
    showToast('${bType.name} built  -\$${bType.cost}');
    return true;
  }

  void endDay() {
    if (isGameOver) return;
    final result = TurnProcessor.processTurn(state);
    lastResult = result;
    state = result.nextState;
    activeAdvisorDialog =
        result.messages.isNotEmpty ? result.messages.first : null;
    if (result.isVictory || result.isDefeat) {
      gameOutcome = result;
      activeAdvisorDialog = null;
    }
    notifyListeners();
  }

  /// After a win, keep playing with no further victory checks.
  void continueInfiniteMode() {
    state = state.copyWith(infiniteMode: true);
    gameOutcome = null;
    notifyListeners();
  }

  /// Start over on the same difficulty (used after a defeat).
  void restart() {
    startNewGame(state.cityName, state.difficulty);
  }

  void dismissAdvisor() {
    activeAdvisorDialog = null;
    notifyListeners();
  }
}
