import 'dart:math' as math;
import 'dart:ui';

import '../data/map_generator.dart';

/// Draws terrain that connects to its neighbours (narrow river, road network)
/// and forests, procedurally, in a chunky pixel-art style. Used until (or
/// instead of) dedicated tile art.
class TerrainPainter {
  final List<List<String>> terrain;
  final double tile;

  TerrainPainter(this.terrain, this.tile);

  int get _n => terrain.length;

  String? _at(int x, int y) =>
      (x < 0 || y < 0 || x >= _n || y >= _n) ? null : terrain[y][x];

  bool _isRiver(int x, int y) {
    final t = _at(x, y);
    // The river flows off the top and bottom edges of the map.
    if (t == null) return false;
    return t == Terrain.river;
  }

  /// A river cell with road on both sides (left/right or up/down) is a bridge.
  bool isBridge(int x, int y) =>
      _isRiver(x, y) &&
      ((_at(x - 1, y) == Terrain.road && _at(x + 1, y) == Terrain.road) ||
          (_at(x, y - 1) == Terrain.road && _at(x, y + 1) == Terrain.road));

  bool _roadLike(int x, int y) => _at(x, y) == Terrain.road || isBridge(x, y);

  // ------------------------------------------------------------------ river

  void paintRiver(Canvas c, int x, int y, {required bool polluted, required double time}) {
    final r = Rect.fromLTWH(x * tile, y * tile, tile, tile);
    final up = y == 0 || _isRiver(x, y - 1);
    final down = y == _n - 1 || _isRiver(x, y + 1);
    final left = _isRiver(x - 1, y);
    final right = _isRiver(x + 1, y);

    final w = tile * 0.42; // river width
    final bank = tile * 0.08;
    final sand = polluted ? const Color(0xFF9C8A5A) : const Color(0xFFE8D69A);
    final water = polluted ? const Color(0xFF4F6B2E) : const Color(0xFF2FB8E6);
    final light = polluted ? const Color(0xFF6E7F3A) : const Color(0xFF8BE3FF);

    _arms(c, r, up, down, left, right, w + bank * 2, Paint()..color = sand);
    _arms(c, r, up, down, left, right, w, Paint()..color = water);

    // Ripples drift along the flow.
    final ripple = Paint()
      ..color = light
      ..strokeWidth = tile * 0.04;
    final phase = (time * 0.6 + x * 0.37 + y * 0.21) % 1.0;
    final cx = r.center.dx, cy = r.center.dy;
    for (var i = 0; i < 2; i++) {
      final t = (phase + i * 0.5) % 1.0;
      if (up || down) {
        final yy = r.top + t * tile;
        c.drawLine(Offset(cx - w * 0.25, yy), Offset(cx + w * 0.05, yy), ripple);
      } else {
        final xx = r.left + t * tile;
        c.drawLine(Offset(xx, cy - w * 0.15), Offset(xx, cy + w * 0.15), ripple);
      }
    }

    if (isBridge(x, y)) {
      final horizontal = _at(x - 1, y) == Terrain.road;
      final deck = horizontal
          ? Rect.fromCenter(center: r.center, width: tile + 1, height: tile * 0.5)
          : Rect.fromCenter(center: r.center, width: tile * 0.5, height: tile + 1);
      c.drawRect(deck.inflate(tile * 0.05), Paint()..color = const Color(0xFF6B5B4B));
      c.drawRect(deck, Paint()..color = const Color(0xFF55585F));
      final rail = Paint()..color = const Color(0xFFCFC3A8);
      if (horizontal) {
        c.drawRect(Rect.fromLTWH(deck.left, deck.top, deck.width, tile * 0.05), rail);
        c.drawRect(Rect.fromLTWH(deck.left, deck.bottom - tile * 0.05, deck.width, tile * 0.05), rail);
      } else {
        c.drawRect(Rect.fromLTWH(deck.left, deck.top, tile * 0.05, deck.height), rail);
        c.drawRect(Rect.fromLTWH(deck.right - tile * 0.05, deck.top, tile * 0.05, deck.height), rail);
      }
    }
  }

  // ------------------------------------------------------------------ roads

  void paintRoad(Canvas c, int x, int y) {
    final r = Rect.fromLTWH(x * tile, y * tile, tile, tile);
    final up = _roadLike(x, y - 1);
    final down = _roadLike(x, y + 1);
    final left = _roadLike(x - 1, y) || x == 0;
    final right = _roadLike(x + 1, y) || x == _n - 1;
    final w = tile * 0.56;

    _arms(c, r, up, down, left, right, w + tile * 0.1, Paint()..color = const Color(0xFFB9BCC4));
    _arms(c, r, up, down, left, right, w, Paint()..color = const Color(0xFF4A4D55));

    // Dashed centre line on straight sections only.
    final dash = Paint()..color = const Color(0xFFE7C04A);
    final arms = [up, down, left, right].where((a) => a).length;
    if (arms == 2 && (left && right)) {
      for (var i = 0; i < 2; i++) {
        c.drawRect(Rect.fromLTWH(r.left + tile * (0.1 + i * 0.5), r.center.dy - tile * 0.02, tile * 0.28, tile * 0.04), dash);
      }
    } else if (arms == 2 && (up && down)) {
      for (var i = 0; i < 2; i++) {
        c.drawRect(Rect.fromLTWH(r.center.dx - tile * 0.02, r.top + tile * (0.1 + i * 0.5), tile * 0.04, tile * 0.28), dash);
      }
    }
  }

  // ------------------------------------------------------------------ forest

  void paintForest(Canvas c, int x, int y, {required bool dead}) {
    final r = Rect.fromLTWH(x * tile, y * tile, tile, tile);
    final rnd = math.Random(x * 73856093 ^ y * 19349663);
    // Five crowns on a jittered layout so neighbouring tiles blend together.
    const spots = [(0.25, 0.25), (0.75, 0.22), (0.5, 0.55), (0.22, 0.8), (0.78, 0.78)];
    final shadow = Paint()..color = const Color(0x40000000);
    final outline = Paint()..color = dead ? const Color(0xFF3A2C1E) : const Color(0xFF173D17);
    final crowns = dead
        ? const [Color(0xFF7A6248), Color(0xFF8E7A5E), Color(0xFF6B5A47)]
        : const [Color(0xFF2E7D32), Color(0xFF388E3C), Color(0xFF2B6E2E)];
    final hi = Paint()..color = dead ? const Color(0xFFA89272) : const Color(0xFF6BBF4E);

    for (final (sx, sy) in spots) {
      final cx = r.left + (sx + (rnd.nextDouble() - 0.5) * 0.12) * tile;
      final cy = r.top + (sy + (rnd.nextDouble() - 0.5) * 0.12) * tile;
      final rad = tile * (dead ? 0.13 : 0.19) * (0.85 + rnd.nextDouble() * 0.3);
      c.drawCircle(Offset(cx + tile * 0.04, cy + tile * 0.06), rad, shadow);
      c.drawCircle(Offset(cx, cy), rad + tile * 0.025, outline);
      c.drawCircle(Offset(cx, cy), rad, Paint()..color = crowns[rnd.nextInt(3)]);
      c.drawCircle(Offset(cx - rad * 0.3, cy - rad * 0.3), rad * 0.4, hi);
      if (dead) {
        // bare branches poking out
        final br = Paint()
          ..color = const Color(0xFF3A2C1E)
          ..strokeWidth = tile * 0.03;
        c.drawLine(Offset(cx, cy), Offset(cx - rad * 1.3, cy - rad * 0.9), br);
        c.drawLine(Offset(cx, cy), Offset(cx + rad * 1.2, cy - rad * 1.1), br);
      }
    }
  }

  // ------------------------------------------------------------------ helper

  /// Centre square plus an arm towards every connected side.
  void _arms(Canvas c, Rect r, bool up, bool down, bool left, bool right, double w, Paint p) {
    final cx = r.center.dx, cy = r.center.dy, h = w / 2;
    c.drawRect(Rect.fromLTRB(cx - h, cy - h, cx + h, cy + h), p);
    if (up) c.drawRect(Rect.fromLTRB(cx - h, r.top - 0.3, cx + h, cy), p);
    if (down) c.drawRect(Rect.fromLTRB(cx - h, cy, cx + h, r.bottom + 0.3), p);
    if (left) c.drawRect(Rect.fromLTRB(r.left - 0.3, cy - h, cx, cy + h), p);
    if (right) c.drawRect(Rect.fromLTRB(cx, cy - h, r.right + 0.3, cy + h), p);
  }
}
