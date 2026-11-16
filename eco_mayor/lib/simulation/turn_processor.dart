import 'dart:math';
import '../models/city_state.dart';
import '../models/pollution_metrics.dart';
import '../models/advisor_message.dart';
import '../data/buildings_data.dart';
import '../data/advisor_dialogues.dart';
import '../utils/constants.dart';
import '../data/map_generator.dart';

class SimulationResult {
  final CityState nextState;
  final int deltaFunds;
  final int deltaPopulation;
  final double deltaHappiness;
  final PollutionMetrics deltaMetrics;
  final List<AdvisorMessage> messages;
  final bool isVictory;
  final bool isDefeat;
  final String? endReason;

  const SimulationResult({
    required this.nextState,
    required this.deltaFunds,
    required this.deltaPopulation,
    required this.deltaHappiness,
    required this.deltaMetrics,
    required this.messages,
    required this.isVictory,
    required this.isDefeat,
    this.endReason,
  });
}

class TurnProcessor {
  // Daily effect of one forest tile (before the 0.35 dampening below).
  static const double forestAqi = -0.5;
  static const double forestWater = 0.2;
  static const double forestSoil = 0.3;
  static const double forestNoise = -0.3;

  static SimulationResult processTurn(CityState current) {
    // 1. Calculate Economy & Maintenance
    int netRevenue = 0;
    int baseResidentialPop = 0;

    double netAqiDelta = 0.0;
    double netWaterDelta = 0.0;
    double netSoilDelta = 0.0;
    double netNoiseWasteDelta = 0.0;

    bool hasHospital = false;
    bool hasSchool = false;
    int greenBuildingCount = 0;
    int heavyPolluterCount = 0;

    for (final placed in current.buildings) {
      final b = BuildingsData.all[placed.buildingTypeId];
      if (b == null) continue;

      netRevenue += b.revenuePerTurn;
      baseResidentialPop += b.population;

      netAqiDelta += b.aqiDelta;
      netWaterDelta += b.waterDelta;
      netSoilDelta += b.soilDelta;
      netNoiseWasteDelta += b.noiseWasteDelta;

      if (b.id == 'hospital') hasHospital = true;
      if (b.id == 'school') hasSchool = true;
      if (b.category.name == 'green') greenBuildingCount++;
      if (b.id == 'coal_plant' || b.id == 'factory' || b.id == 'oil_refinery') {
        heavyPolluterCount++;
      }
    }

    // Forests: trees absorb pollutants, hold soil, filter water, damp noise.
    var forestTiles = 0;
    for (final row in current.terrain) {
      for (final cell in row) {
        if (cell == Terrain.forest) forestTiles++;
      }
    }
    netAqiDelta += forestTiles * forestAqi;
    netWaterDelta += forestTiles * forestWater;
    netSoilDelta += forestTiles * forestSoil;
    netNoiseWasteDelta += forestTiles * forestNoise;

    // Taxes from population
    final taxIncome = (current.population * 0.5).round();
    final totalFundsDelta = netRevenue + taxIncome;
    final nextFunds = max(0, current.funds + totalFundsDelta);

    // 2. Calculate Environmental Metrics with natural baseline dissipation
    final targetAqi = (current.metrics.aqi + netAqiDelta * 0.35).clamp(10.0, 300.0);
    final targetWater = (current.metrics.waterPurity + netWaterDelta * 0.35).clamp(5.0, 100.0);
    final targetSoil = (current.metrics.soilHealth + netSoilDelta * 0.35).clamp(5.0, 100.0);
    final targetNoiseWaste = (current.metrics.noiseWaste + netNoiseWasteDelta * 0.35).clamp(5.0, 100.0);

    final updatedMetrics = PollutionMetrics(
      aqi: targetAqi,
      waterPurity: targetWater,
      soilHealth: targetSoil,
      noiseWaste: targetNoiseWaste,
    );

    // 3. Happiness and Population Dynamics
    // Ideal: AQI < 50, Water > 80, Soil > 75, Noise < 30
    double penalty = 0.0;
    if (updatedMetrics.aqi > 100) penalty += (updatedMetrics.aqi - 100) * 0.15;
    if (updatedMetrics.waterPurity < 60) penalty += (60 - updatedMetrics.waterPurity) * 0.25;
    if (updatedMetrics.soilHealth < 50) penalty += (50 - updatedMetrics.soilHealth) * 0.15;
    if (updatedMetrics.noiseWaste > 50) penalty += (updatedMetrics.noiseWaste - 50) * 0.2;

    double bonus = (greenBuildingCount * 2.0);
    if (hasHospital) bonus += 10.0;
    if (hasSchool) bonus += 8.0;

    final targetHappiness = (75.0 + bonus - penalty).clamp(5.0, 100.0);
    final deltaHappiness = targetHappiness - current.happiness;

    // Population migration based on happiness
    int deltaPop = 0;
    if (targetHappiness > 70) {
      deltaPop = (current.population * 0.05).round() + 5;
    } else if (targetHappiness < 40) {
      deltaPop = -((current.population * 0.08).round() + 6);
    }
    final nextPop = max(10, current.population + deltaPop);

    // 4. Gem rewards for clean streaks
    int nextGems = current.gems;
    if (updatedMetrics.aqi < 70 && updatedMetrics.waterPurity > 70) {
      nextGems += 2;
      if (hasSchool) nextGems += 1; // education eco dividend
    }

    // 5. Check Victory / Defeat Conditions
    // Defeat only on sustained ecological collapse. Low funds or population
    // trigger advisor warnings instead of ending the game.
    final nextCriticalDays =
        updatedMetrics.isCritical() ? current.criticalDays + 1 : 0;
    bool isVictory = false;
    bool isDefeat = false;
    String? endReason;

    if (nextCriticalDays >= GameConstants.collapseDaysToLose) {
      isDefeat = true;
      endReason =
          'Ecological Collapse: The city stayed in a critical pollution state for ${GameConstants.collapseDaysToLose} days straight. Citizens have evacuated and the ecosystem can no longer recover.';
    } else if (!current.infiniteMode &&
        updatedMetrics.isGreenZone() &&
        nextFunds > 1000 &&
        nextPop >= 100) {
      isVictory = true;
      endReason =
          'Outstanding Leadership! Your city has entered the sustainable Green Zone while maintaining economic stability!';
    }

    // 6. Advisor Intelligence
    final messages = <AdvisorMessage>[];
    if (nextCriticalDays > 0 && !isDefeat) {
      messages.add(AdvisorDialogues.collapseWarning(
          GameConstants.collapseDaysToLose - nextCriticalDays));
    }
    if (updatedMetrics.aqi > 150) {
      messages.add(AdvisorDialogues.highAqiWarning(updatedMetrics.aqi));
    }
    if (updatedMetrics.waterPurity < 35) {
      messages.add(AdvisorDialogues.dirtyWaterWarning(updatedMetrics.waterPurity));
    }
    if (nextFunds < 400) {
      messages.add(AdvisorDialogues.financialWarning(nextFunds));
    }
    if (greenBuildingCount > 4 && messages.isEmpty) {
      messages.add(AdvisorDialogues.greenPraise());
    }

    final nextCity = current.copyWith(
      turn: current.turn + 1,
      funds: nextFunds,
      gems: nextGems,
      population: nextPop,
      happiness: targetHappiness,
      metrics: updatedMetrics,
      criticalDays: nextCriticalDays,
    );

    return SimulationResult(
      nextState: nextCity,
      deltaFunds: totalFundsDelta,
      deltaPopulation: deltaPop,
      deltaHappiness: deltaHappiness,
      deltaMetrics: PollutionMetrics(
        aqi: targetAqi - current.metrics.aqi,
        waterPurity: targetWater - current.metrics.waterPurity,
        soilHealth: targetSoil - current.metrics.soilHealth,
        noiseWaste: targetNoiseWaste - current.metrics.noiseWaste,
      ),
      messages: messages,
      isVictory: isVictory,
      isDefeat: isDefeat,
      endReason: endReason,
    );
  }
}
