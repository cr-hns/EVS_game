import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart';

import '../data/buildings_data.dart';
import '../data/map_generator.dart';
import '../models/building.dart';

enum _FxKind { dust, debris, sparkle, floatText, ripple }

class _Fx {
  final _FxKind kind;
  final Offset pos;
  final double start;
  final double dur;
  final Color color;
  final String? text;
  final double angle;
  final double size;

  _Fx(
    this.kind,
    this.pos,
    this.start,
    this.dur,
    this.color, {
    this.text,
    this.angle = 0,
    this.size = 1,
  });
}

class _Car {
  double x, y; // position in cells (centre of cell = .5)
  int dx, dy;
  final Color color;
  final double speed; // cells per second

  _Car(this.x, this.y, this.dx, this.dy, this.color, this.speed);
}

/// All the life on the map: buildings popping in, demolition dust, sparkles
/// over green buildings, river glints, cars on the roads, cloud shadows,
/// floating cost text and tap ripples. Everything is in world coordinates
/// (1 cell = [tile] px) and drawn inside the map's camera transform.
class MapEffects {
  final double tile;
  MapEffects(this.tile);

  final _rnd = math.Random(7);
  final List<_Fx> _fx = [];
  final Map<String, double> _bornAt = {}; // building id -> time it appeared
  Map<String, PlacedBuilding> _known = {};
  List<PlacedBuilding>? _lastList;
  bool _primed = false;

  final List<_Car> _cars = [];
  List<List<String>>? _carTerrain;

  static const _sparkleGold = Color(0xFFFFE27A);
  static const _carColors = [
    Color(0xFFE5483B),
    Color(0xFF3D7DD8),
    Color(0xFFF2F2F2),
    Color(0xFFFFC93C),
    Color(0xFF4FA83A),
    Color(0xFF8E5BD0),
  ];

  // ------------------------------------------------------------ buildings

  /// Call every frame with the current buildings; spawns effects for any
  /// building that appeared or disappeared since last time.
  void syncBuildings(List<PlacedBuilding> list, double now) {
    if (identical(list, _lastList)) return;
    _lastList = list;
    final current = {for (final b in list) b.id: b};
    if (!_primed) {
      // Buildings already standing at game start don't animate in.
      _primed = true;
      _known = current;
      return;
    }
    for (final b in list) {
      if (!_known.containsKey(b.id)) _onBuilt(b, now);
    }
    for (final b in _known.values) {
      if (!current.containsKey(b.id)) _onDemolished(b, now);
    }
    _known = current;
  }

  /// Fresh start (new game): forget everything.
  void reset() {
    _primed = false;
    _lastList = null;
    _known = {};
    _bornAt.clear();
    _fx.clear();
  }

  Rect _rectOf(PlacedBuilding b) {
    final t = BuildingsData.all[b.buildingTypeId]!;
    return Rect.fromLTWH(
      b.gridX * tile,
      b.gridY * tile,
      t.width * tile,
      t.height * tile,
    );
  }

  void _onBuilt(PlacedBuilding b, double now) {
    _bornAt[b.id] = now;
    final r = _rectOf(b);
    final type = BuildingsData.all[b.buildingTypeId]!;
    // Ring of dust around the footprint
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      _fx.add(
        _Fx(
          _FxKind.dust,
          r.center + Offset(math.cos(a), math.sin(a)) * r.width * 0.45,
          now,
          0.6 + _rnd.nextDouble() * 0.3,
          const Color(0xFFD9C9A3),
          angle: a,
          size: 0.8 + _rnd.nextDouble() * 0.5,
        ),
      );
    }
    if (type.category == BuildingCategory.green) {
      for (var i = 0; i < 14; i++) {
        final a = _rnd.nextDouble() * math.pi * 2;
        _fx.add(
          _Fx(
            _FxKind.sparkle,
            r.center,
            now + _rnd.nextDouble() * 0.15,
            0.9 + _rnd.nextDouble() * 0.5,
            i.isEven ? _sparkleGold : const Color(0xFFB8FF8A),
            angle: a,
            size: 0.7 + _rnd.nextDouble() * 0.7,
          ),
        );
      }
    }
    _fx.add(
      _Fx(
        _FxKind.floatText,
        Offset(r.center.dx, r.top),
        now,
        1.4,
        const Color(0xFFFFC93C),
        text: '-\$${type.cost}',
      ),
    );
  }

  void _onDemolished(PlacedBuilding b, double now) {
    final r = _rectOf(b);
    for (var i = 0; i < 16; i++) {
      final p = Offset(
        r.left + _rnd.nextDouble() * r.width,
        r.top + _rnd.nextDouble() * r.height,
      );
      _fx.add(
        _Fx(
          _FxKind.dust,
          p,
          now + _rnd.nextDouble() * 0.2,
          0.8 + _rnd.nextDouble() * 0.5,
          const Color(0xFF8C8273),
          angle: -math.pi / 2 + (_rnd.nextDouble() - 0.5),
          size: 1 + _rnd.nextDouble(),
        ),
      );
    }
    for (var i = 0; i < 10; i++) {
      _fx.add(
        _Fx(
          _FxKind.debris,
          r.center,
          now,
          0.7 + _rnd.nextDouble() * 0.3,
          const Color(0xFF5B5148),
          angle: _rnd.nextDouble() * math.pi * 2,
          size: 0.6 + _rnd.nextDouble() * 0.6,
        ),
      );
    }
  }

  /// Squash-and-stretch pop for a building that was just placed.
  /// Returns (scaleX, scaleY); (1, 1) once settled.
  (double, double) popScale(String id, double now) {
    final born = _bornAt[id];
    if (born == null) return (1, 1);
    final t = (now - born) / 0.55;
    if (t >= 1) {
      _bornAt.remove(id);
      return (1, 1);
    }
    final s = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
    return (0.3 + 0.7 * s, 0.3 + 0.7 * s + math.sin(t * math.pi) * 0.12);
  }

  void tap(Offset world, double now) {
    _fx.add(_Fx(_FxKind.ripple, world, now, 0.45, const Color(0xFFFFFFFF)));
  }

  // ------------------------------------------------------------ cars

  bool _road(List<List<String>> t, int x, int y) {
    if (x < 0 || y < 0 || y >= t.length || x >= t.length) return false;
    final c = t[y][x];
    if (c == Terrain.road) return true;
    if (c != Terrain.river) return false;
    bool r(int xx, int yy) =>
        xx >= 0 &&
        yy >= 0 &&
        yy < t.length &&
        xx < t.length &&
        t[yy][xx] == Terrain.road;
    return (r(x - 1, y) && r(x + 1, y)) ||
        (r(x, y - 1) && r(x, y + 1)); // bridge
  }

  void _spawnCars(List<List<String>> t) {
    _cars.clear();
    final roads = <(int, int)>[];
    for (var y = 0; y < t.length; y++) {
      for (var x = 0; x < t.length; x++) {
        if (t[y][x] == Terrain.road) roads.add((x, y));
      }
    }
    if (roads.isEmpty) return;
    final count = math.min(9, roads.length ~/ 6);
    for (var i = 0; i < count; i++) {
      final (x, y) = roads[_rnd.nextInt(roads.length)];
      final dirs = _dirs(t, x, y);
      final (dx, dy) = dirs.isEmpty ? (1, 0) : dirs[_rnd.nextInt(dirs.length)];
      _cars.add(
        _Car(
          x + 0.5,
          y + 0.5,
          dx,
          dy,
          _carColors[i % _carColors.length],
          1.1 + _rnd.nextDouble() * 0.9,
        ),
      );
    }
  }

  List<(int, int)> _dirs(List<List<String>> t, int x, int y) => [
    for (final d in const [(1, 0), (-1, 0), (0, 1), (0, -1)])
      if (_road(t, x + d.$1, y + d.$2)) d,
  ];

  void update(double dt, List<List<String>> terrain) {
    if (!identical(terrain, _carTerrain)) {
      _carTerrain = terrain;
      if (_cars.isEmpty) _spawnCars(terrain);
    }
    for (final c in _cars) {
      final cx = c.x.floor(), cy = c.y.floor();
      final before = (c.x - cx - 0.5) * c.dx + (c.y - cy - 0.5) * c.dy;
      c.x += c.dx * c.speed * dt;
      c.y += c.dy * c.speed * dt;
      final after = (c.x - cx - 0.5) * c.dx + (c.y - cy - 0.5) * c.dy;
      if (before < 0 && after >= 0) {
        // Crossed the centre of a cell: choose where to go next.
        var options = _dirs(
          terrain,
          cx,
          cy,
        ).where((d) => !(d.$1 == -c.dx && d.$2 == -c.dy)).toList();
        if (options.isEmpty) options = [(-c.dx, -c.dy)]; // dead end: U-turn
        // Prefer going straight.
        final straight = options.any((d) => d.$1 == c.dx && d.$2 == c.dy);
        final pick = straight && _rnd.nextDouble() < 0.6
            ? (c.dx, c.dy)
            : options[_rnd.nextInt(options.length)];
        c.x = cx + 0.5;
        c.y = cy + 0.5;
        c.dx = pick.$1;
        c.dy = pick.$2;
      }
      // Driven off the map edge: wrap round to a random road.
      if (c.x < 0 ||
          c.y < 0 ||
          c.x >= terrain.length ||
          c.y >= terrain.length) {
        c.x = c.x.clamp(0.5, terrain.length - 0.5);
        c.y = c.y.clamp(0.5, terrain.length - 0.5);
        c.dx = -c.dx;
        c.dy = -c.dy;
      }
    }
  }

  void drawCars(Canvas canvas) {
    for (final c in _cars) {
      // Drive on the right-hand side of the road.
      final lane = 0.12;
      final px = (c.x - c.dy * lane) * tile;
      final py = (c.y + c.dx * lane) * tile;
      final horizontal = c.dx != 0;
      final w = tile * (horizontal ? 0.3 : 0.17);
      final h = tile * (horizontal ? 0.17 : 0.3);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(px, py), width: w, height: h),
        Radius.circular(tile * 0.04),
      );
      canvas.drawRRect(
        body.shift(Offset(tile * 0.03, tile * 0.04)),
        Paint()..color = const Color(0x55000000),
      );
      canvas.drawRRect(
        body.inflate(tile * 0.015),
        Paint()..color = const Color(0xFF1A1A1A),
      );
      canvas.drawRRect(body, Paint()..color = c.color);
      // windscreen at the front
      final f = Offset(px + c.dx * w * 0.22, py + c.dy * h * 0.22);
      canvas.drawRect(
        Rect.fromCenter(
          center: f,
          width: horizontal ? w * 0.18 : w * 0.7,
          height: horizontal ? h * 0.7 : h * 0.18,
        ),
        Paint()..color = const Color(0xFF9FD8F0),
      );
    }
  }

  // ------------------------------------------------------------ ambient

  /// Twinkles over green buildings and glints on clean water.
  void drawAmbient(
    Canvas canvas,
    List<PlacedBuilding> buildings,
    List<List<String>> terrain,
    double now, {
    required bool waterClean,
  }) {
    for (final b in buildings) {
      final type = BuildingsData.all[b.buildingTypeId];
      if (type == null || type.category != BuildingCategory.green) continue;
      final r = _rectOf(b);
      final seed = b.gridX * 31 + b.gridY * 17;
      for (var i = 0; i < 2; i++) {
        final cycle = 2.2 + (seed % 5) * 0.2;
        final t = ((now + seed * 0.37 + i * cycle / 2) % cycle) / cycle;
        if (t > 0.35) continue;
        final k = math.sin(t / 0.35 * math.pi);
        final hx = ((seed * (i + 3) * 7919) % 100) / 100;
        final hy = ((seed * (i + 5) * 104729) % 100) / 100;
        _star(
          canvas,
          Offset(
            r.left + r.width * (0.15 + hx * 0.7),
            r.top + r.height * (0.15 + hy * 0.7),
          ),
          tile * 0.16 * k,
          _sparkleGold.withValues(alpha: k),
        );
      }
    }
    if (!waterClean) return;
    for (var y = 0; y < terrain.length; y++) {
      for (var x = 0; x < terrain.length; x++) {
        if (terrain[y][x] != Terrain.river) continue;
        final seed = x * 13 + y * 29;
        final t = ((now * 0.8 + seed * 0.21) % 3.0) / 3.0;
        if (t > 0.2) continue;
        final k = math.sin(t / 0.2 * math.pi);
        _star(
          canvas,
          Offset((x + 0.5) * tile, (y + 0.3 + (seed % 4) * 0.12) * tile),
          tile * 0.09 * k,
          const Color(0xFFFFFFFF).withValues(alpha: k * 0.9),
        );
      }
    }
  }

  /// Soft cloud shadows drifting across the board.
  void drawClouds(Canvas canvas, Rect board, double now) {
    canvas.save();
    canvas.clipRect(board);
    final p = Paint()..color = const Color(0x1F000000);
    for (var i = 0; i < 3; i++) {
      final speed = 6.0 + i * 2.5;
      final w = board.width * (0.35 + i * 0.08);
      final x =
          ((now * speed + i * board.width * 0.55) % (board.width + w * 2)) - w;
      final y = board.height * (0.15 + i * 0.32);
      for (final (ox, oy, s) in const [
        (0.0, 0.0, 1.0),
        (0.3, -0.12, 0.75),
        (-0.28, 0.08, 0.7),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(board.left + x + ox * w, board.top + y + oy * w),
            width: w * s,
            height: w * 0.45 * s,
          ),
          p,
        );
      }
    }
    canvas.restore();
  }

  // ------------------------------------------------------------ one-shot fx

  void drawFx(Canvas canvas, double now) {
    _fx.removeWhere((f) => now - f.start > f.dur);
    for (final f in _fx) {
      final t = (now - f.start) / f.dur;
      if (t < 0) continue;
      switch (f.kind) {
        case _FxKind.dust:
          final d =
              Offset(math.cos(f.angle), math.sin(f.angle)) *
              tile *
              0.35 *
              Curves.easeOut.transform(t);
          canvas.drawCircle(
            f.pos + d,
            tile * 0.12 * f.size * (0.6 + t),
            Paint()..color = f.color.withValues(alpha: (1 - t) * 0.8),
          );
        case _FxKind.debris:
          final v =
              Offset(math.cos(f.angle), math.sin(f.angle)) *
              tile *
              0.9 *
              f.size;
          final pos = f.pos + v * t + Offset(0, tile * 1.2 * t * t);
          canvas.drawRect(
            Rect.fromCenter(
              center: pos,
              width: tile * 0.08,
              height: tile * 0.08,
            ),
            Paint()..color = f.color.withValues(alpha: 1 - t),
          );
        case _FxKind.sparkle:
          final pos =
              f.pos +
              Offset(math.cos(f.angle), math.sin(f.angle)) *
                  tile *
                  0.9 *
                  f.size *
                  Curves.easeOut.transform(t) +
              Offset(0, -tile * 0.4 * t);
          _star(
            canvas,
            pos,
            tile * 0.14 * f.size * math.sin(t * math.pi),
            f.color.withValues(alpha: 1 - t * t),
          );
        case _FxKind.floatText:
          final tp = TextPainter(
            text: TextSpan(
              text: f.text,
              style: TextStyle(
                fontFamily: 'Silkscreen',
                fontSize: tile * 0.42,
                fontWeight: FontWeight.w700,
                color: f.color.withValues(alpha: t < 0.7 ? 1 : (1 - t) / 0.3),
                shadows: [
                  Shadow(
                    color: const Color(0xFF120D09).withValues(alpha: 1 - t),
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            f.pos +
                Offset(
                  -tp.width / 2,
                  -tile * 0.5 - tile * 0.9 * Curves.easeOut.transform(t),
                ),
          );
        case _FxKind.ripple:
          canvas.drawCircle(
            f.pos,
            tile * (0.15 + 0.5 * t),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = tile * 0.06 * (1 - t)
              ..color = f.color.withValues(alpha: (1 - t) * 0.9),
          );
      }
    }
  }

  /// Four-point twinkle star.
  void _star(Canvas canvas, Offset c, double r, Color color) {
    if (r <= 0.2) return;
    final p = Paint()..color = color;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.22, c.dy - r * 0.22)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + r * 0.22, c.dy + r * 0.22)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.22, c.dy + r * 0.22)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - r * 0.22, c.dy - r * 0.22)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawCircle(
      c,
      r * 0.18,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: color.a),
    );
  }
}
