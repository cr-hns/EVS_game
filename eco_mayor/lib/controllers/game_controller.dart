import 'package:flutter/foundation.dart';
import '../models/city_state.dart';
import '../models/pollution_metrics.dart';
import '../models/building.dart';
import '../models/advisor_message.dart';
import '../simulation/turn_processor.dart';
import '../data/buildings_data.dart';
import '../data/map_generator.dart';

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
    final map = MapGenerator.build(difficulty);

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
    } else if (difficulty != 'medium') {
      // Hard
      startFunds = 3000;
      startGems = 5;
      initialMetrics = const PollutionMetrics(
        aqi: 180.0,
        waterPurity: 30.0,
        soilHealth: 35.0,
        noiseWaste: 75.0,
      );
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
      // Everyone who lives in the starting town's homes.
      population: map.buildings.fold<int>(
          0, (sum, b) => sum + (BuildingsData.all[b.buildingTypeId]?.population ?? 0)),
      happiness: 60.0,
      metrics: initialMetrics,
      buildings: map.buildings,
      terrain: map.terrain,
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
  static const double forestClearAqi = 4.0;
  static const double forestClearSoil = 3.0;

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
        final cell = state.terrain[ty][tx];
        if (cell == Terrain.river && bType.id != 'water_treatment') {
          showToast("Can't build on the river", error: true);
          return false;
        }
        if (Terrain.isBlocked(cell)) {
          showToast("Can't build on a road", error: true);
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
    // Building on forest clears it: an immediate hit to air and soil.
    var cleared = 0;
    final terrain = [for (final row in state.terrain) [...row]];
    for (int y = 0; y < bType.height; y++) {
      for (int x = 0; x < bType.width; x++) {
        if (terrain[gridY + y][gridX + x] == Terrain.forest) {
          terrain[gridY + y][gridX + x] = Terrain.grass;
          cleared++;
        }
      }
    }
    final m = state.metrics;
    state = state.copyWith(
      funds: state.funds - bType.cost,
      gems: state.gems - bType.gemCost,
      buildings: [...state.buildings, placed],
      terrain: terrain,
      metrics: cleared == 0
          ? m
          : m.copyWith(
              aqi: m.aqi + cleared * forestClearAqi,
              soilHealth: m.soilHealth - cleared * forestClearSoil,
            ),
    );
    if (cleared > 0) {
      showToast(
        'Cut down $cleared forest tile${cleared == 1 ? '' : 's'}: '
        'AQI +${(cleared * forestClearAqi).round()}, Soil -${(cleared * forestClearSoil).round()}',
        error: true,
      );
    } else {
      showToast('${bType.name} built  -\$${bType.cost}');
    }
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
