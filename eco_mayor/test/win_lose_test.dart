import 'package:flutter_test/flutter_test.dart';
import 'package:eco_mayor/controllers/game_controller.dart';
import 'package:eco_mayor/models/pollution_metrics.dart';
import 'package:eco_mayor/models/city_state.dart';
import 'package:eco_mayor/utils/constants.dart';

const _green = PollutionMetrics(aqi: 20, waterPurity: 95, soilHealth: 90, noiseWaste: 10);

void main() {
  test('hard mode with no action collapses only after sustained critical days', () {
    final c = GameController()..startNewGame('Test', 'hard');
    int days = 0;
    while (!c.isGameOver && days < 50) {
      c.endDay();
      days++;
    }
    expect(c.isGameOver, isTrue);
    expect(c.gameOutcome!.isDefeat, isTrue);
    expect(c.state.criticalDays, GameConstants.collapseDaysToLose);
    expect(days, greaterThanOrEqualTo(GameConstants.collapseDaysToLose));
  });

  test('bankruptcy alone does not end the game', () {
    final c = GameController()..startNewGame('Test', 'easy');
    c.state = c.state.copyWith(funds: 0, buildings: []);
    c.endDay();
    expect(c.isGameOver, isFalse);
  });

  test('critical counter resets when conditions improve', () {
    final c = GameController()..startNewGame('Test', 'easy');
    c.state = c.state.copyWith(criticalDays: 3, buildings: []);
    c.endDay();
    expect(c.state.criticalDays, 0);
  });

  test('green zone wins, then infinite mode never re-triggers victory', () {
    final c = GameController()..startNewGame('Test', 'easy');
    c.state = c.state.copyWith(buildings: [], metrics: _green, funds: 5000, population: 300);
    c.endDay();
    expect(c.gameOutcome?.isVictory, isTrue);
    c.endDay(); // ignored while overlay is up
    expect(c.isGameOver, isTrue);

    c.continueInfiniteMode();
    expect(c.state.infiniteMode, isTrue);
    for (var i = 0; i < 5; i++) {
      c.endDay();
    }
    expect(c.isGameOver, isFalse);
  });

  test('restart resets outcome and keeps difficulty', () {
    final c = GameController()..startNewGame('Test', 'hard');
    while (!c.isGameOver && c.state.turn < 80) {
      c.endDay();
    }
    expect(c.gameOutcome?.isDefeat, isTrue);
    c.restart();
    expect(c.isGameOver, isFalse);
    expect(c.state.difficulty, 'hard');
    expect(c.state.turn, 1);
    expect(c.state.criticalDays, 0);
  });

  test('new fields survive JSON round trip and old saves default safely', () {
    final c = GameController()..startNewGame('Test', 'medium');
    final json = c.state.copyWith(criticalDays: 2, infiniteMode: true).toJson();
    final restored = CityState.fromJson(json);
    expect(restored.criticalDays, 2);
    expect(restored.infiniteMode, isTrue);

    json.remove('criticalDays');
    json.remove('infiniteMode');
    final legacy = CityState.fromJson(json);
    expect(legacy.criticalDays, 0);
    expect(legacy.infiniteMode, isFalse);
  });
}
