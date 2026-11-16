import '../models/building.dart';
import 'buildings_data.dart';

/// Terrain tile ids stored in [CityState.terrain].
class Terrain {
  static const grass = 'grass';
  static const forest = 'forest';
  static const river = 'water_clean'; // id kept for older saves
  static const road = 'road';
  static const dirt = 'dirt';

  /// Cells you can't build on at all (the river accepts water treatment only).
  static bool isBlocked(String t) => t == road;
}

/// Starting map for a difficulty: terrain plus the buildings already standing.
class StartingMap {
  final List<List<String>> terrain;
  final List<PlacedBuilding> buildings;

  const StartingMap(this.terrain, this.buildings);
}

/// Builds the hand-designed starting town: a narrow river winding down the
/// west side, a road grid with neighbourhoods east of it, forests around the
/// edges, and an industrial strip on the riverbank that grows with difficulty.
class MapGenerator {
  static const int size = 20;

  // The river, as a connected path of cells from the top edge to the bottom.
  static const List<(int, int)> riverPath = [
    (4, 0), (4, 1), (4, 2), (4, 3), (5, 3), (6, 3), (6, 4), (6, 5), (6, 6),
    (6, 7), (6, 8), (6, 9), (6, 10), (5, 10), (4, 10), (4, 11), (4, 12),
    (4, 13), (3, 13), (3, 14), (3, 15), (3, 16), (3, 17), (3, 18), (3, 19),
  ];

  static StartingMap build(String difficulty) {
    final t = List.generate(size, (_) => List.filled(size, Terrain.grass));
    final b = <PlacedBuilding>[];
    var id = 0;

    void put(String type, int x, int y) => b.add(PlacedBuilding(
          id: 'start_${id++}',
          buildingTypeId: type,
          gridX: x,
          gridY: y,
        ));

    for (final (x, y) in riverPath) {
      t[y][x] = Terrain.river;
    }

    // Roads: a main street crossing the river, an avenue, and side streets.
    void road(int x0, int y0, int x1, int y1) {
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          if (t[y][x] != Terrain.river) t[y][x] = Terrain.road;
        }
      }
    }

    road(0, 9, 19, 9); // main street (bridges the river at x=6)
    road(12, 1, 12, 18); // avenue
    road(13, 4, 19, 4); // north street
    road(13, 14, 19, 14); // south street
    road(8, 9, 8, 17); // road to the riverside district

    // Forests: thickest on easy, mostly cleared on hard.
    final forest = switch (difficulty) {
      'easy' => _forestEasy,
      'hard' => _forestHard,
      _ => _forestMedium,
    };
    for (final (x0, y0, x1, y1) in forest) {
      for (var y = y0; y <= y1; y++) {
        for (var x = x0; x <= x1; x++) {
          if (t[y][x] == Terrain.grass) t[y][x] = Terrain.forest;
        }
      }
    }

    // Neighbourhoods (same on every difficulty).
    for (var x = 13; x <= 19; x++) {
      put('house', x, 3); // houses facing north street
      put('house', x, 8); // houses facing main street
      put('house', x, 10);
    }
    put('apartment', 13, 5);
    put('apartment', 15, 5);
    put('park', 17, 6);
    put('apartment', 13, 11);
    put('apartment', 15, 11);
    put('park', 17, 12);
    put('school', 13, 15);
    for (var x = 9; x <= 11; x++) {
      put('house', x, 8);
      put('house', x, 10);
    }

    // Industry and services by difficulty.
    switch (difficulty) {
      case 'easy':
        put('hospital', 16, 15);
        put('coal_plant', 9, 11);
        break;
      case 'medium':
        put('hospital', 16, 15);
        put('coal_plant', 9, 11);
        put('factory', 9, 14);
        put('landfill', 0, 16);
        break;
      default: // hard
        put('coal_plant', 9, 11);
        put('coal_plant', 9, 14);
        put('factory', 16, 15);
        put('oil_refinery', 9, 1);
        put('landfill', 0, 16);
        put('landfill', 0, 11);
        break;
    }

    // Anything standing on forest replaces it.
    for (final p in b) {
      final type = BuildingsData.all[p.buildingTypeId]!;
      for (var y = p.gridY; y < p.gridY + type.height; y++) {
        for (var x = p.gridX; x < p.gridX + type.width; x++) {
          if (t[y][x] == Terrain.forest) t[y][x] = Terrain.grass;
        }
      }
    }
    // Hard: cleared land around industry is bare dirt.
    if (difficulty == 'hard') {
      for (var y = 0; y < size; y++) {
        for (var x = 7; x <= 11; x++) {
          if (t[y][x] == Terrain.grass && (y < 8 || y > 10)) t[y][x] = Terrain.dirt;
        }
      }
    }
    return StartingMap(t, b);
  }

  // Forest rectangles (x0, y0, x1, y1), inclusive.
  static const _forestEasy = [
    (0, 0, 3, 8), (5, 0, 11, 2), (7, 4, 11, 7), (0, 10, 2, 15), (13, 0, 19, 2),
    (4, 14, 7, 19), (9, 16, 11, 19), (13, 17, 19, 19), (5, 11, 7, 13), (0, 17, 2, 19),
  ];
  static const _forestMedium = [
    (0, 0, 3, 7), (7, 0, 11, 2), (13, 0, 19, 1), (0, 10, 2, 14),
    (4, 16, 7, 19), (13, 17, 19, 19), (10, 17, 11, 19),
  ];
  static const _forestHard = [
    (0, 0, 2, 5), (13, 0, 16, 1), (5, 17, 7, 19), (17, 17, 19, 19),
  ];
}
