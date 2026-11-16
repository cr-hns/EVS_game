import 'package:eco_mayor/data/buildings_data.dart';
import 'package:eco_mayor/data/map_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final d in ['easy', 'medium', 'hard']) {
    test('$d starting map is valid', () {
      final map = MapGenerator.build(d);
      expect(map.terrain.length, 20);
      final owner = <String, String>{};
      for (final b in map.buildings) {
        final t = BuildingsData.all[b.buildingTypeId]!;
        for (var y = b.gridY; y < b.gridY + t.height; y++) {
          for (var x = b.gridX; x < b.gridX + t.width; x++) {
            expect(x < 20 && y < 20, isTrue, reason: '${b.buildingTypeId} off map');
            final cell = map.terrain[y][x];
            expect(cell, isNot(Terrain.road), reason: '${b.buildingTypeId} on road at $x,$y');
            expect(cell, isNot(Terrain.river), reason: '${b.buildingTypeId} on river at $x,$y');
            expect(owner['$x,$y'], isNull,
                reason: '${b.buildingTypeId} overlaps ${owner['$x,$y']} at $x,$y');
            owner['$x,$y'] = b.buildingTypeId;
          }
        }
      }
      // River is one connected path from the top edge to the bottom edge.
      final path = MapGenerator.riverPath;
      expect(path.first.$2, 0);
      expect(path.last.$2, 19);
      for (var i = 1; i < path.length; i++) {
        final dx = (path[i].$1 - path[i - 1].$1).abs();
        final dy = (path[i].$2 - path[i - 1].$2).abs();
        expect(dx + dy, 1, reason: 'river gap at ${path[i]}');
      }
    });
  }
}
