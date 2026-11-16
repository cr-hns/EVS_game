import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../controllers/game_controller.dart';
import '../data/buildings_data.dart';
import '../data/map_generator.dart';
import 'map_effects.dart';
import 'terrain_painter.dart';
import '../utils/constants.dart';

/// Renders the 20x20 city map. Handles pan / pinch-zoom (touch), wheel zoom
/// and hover preview (mouse), and turns taps into build / demolish actions.
class EcoMayorFlameGame extends FlameGame
    with TapCallbacks, ScaleDetector, ScrollDetector, MouseMovementDetector {
  final GameController controller;

  EcoMayorFlameGame({required this.controller});

  // Camera
  Vector2 mapOffset = Vector2.zero();
  double zoom = 1.0;
  double _minZoom = 0.5;
  double _maxZoom = 4.0;
  bool _fitted = false;
  bool _userMoved = false; // once true, never auto-refit the camera

  // Screen space covered by HUD panels, so the map fits between them.
  double topInset = 0;
  double bottomInset = 0;

  // Gesture state
  double _zoomAtGestureStart = 1.0;

  // Mouse hover cell for build preview (desktop only)
  math.Point<int>? _hoverCell;

  double _time = 0;
  late final MapEffects _effects = MapEffects(_tile);
  int _gameId = -1;
  final Map<String, Sprite> _sprites = {};
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  static const double _tile = GameConstants.tileSize;
  static const double _mapPx = _tile * GameConstants.gridCols;

  @override
  Color backgroundColor() => const Color(0xFF16231A);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    const terrain = [
      'tiles/grass.png',
      'tiles/grass_dead.png',
      'tiles/dirt.png',
      'tiles/water_clean.png',
      'tiles/water_polluted.png',
      'tiles/sand.png',
      'tiles/concrete.png',
    ];
    for (final key in terrain) {
      _sprites[key] = await loadSprite(key);
    }
    // Connected map tiles; any missing piece falls back to TerrainPainter.
    final mapTiles = [
      for (final v in ['a', 'b', 'c', 'edge']) ...[
        'tiles/forest_$v.png',
        'tiles/forest_dead_$v.png',
      ],
      for (final m in ['tb', 'rl', 'tr', 'rb', 'bl', 'tl']) ...[
        'tiles/river_$m.png',
        'tiles/river_${m}_polluted.png',
      ],
      for (final m in [
        'tb',
        'rl',
        'tr',
        'rb',
        'bl',
        'tl',
        'trb',
        'rbl',
        'tbl',
        'trl',
        'trbl',
        't',
        'r',
        'b',
        'l',
      ])
        'tiles/road_$m.png',
    ];
    for (final key in mapTiles) {
      try {
        _sprites[key] = await loadSprite(key);
      } catch (_) {
        // not generated yet: procedural fallback is used
      }
    }
    for (final b in BuildingsData.all.values) {
      _sprites[b.spritePath] = await loadSprite(b.spritePath);
    }
  }

  // ---------------------------------------------------------------- camera

  void setInsets({required double top, required double bottom}) {
    final changed = top != topInset || bottom != bottomInset;
    topInset = top;
    bottomInset = bottom;
    if (changed && _fitted && !_userMoved) fitToScreen();
  }

  void fitToScreen() {
    final availW = size.x - 16;
    final availH = size.y - topInset - bottomInset - 16;
    if (availW <= 0 || availH <= 0) return;
    final fit = math.min(availW / _mapPx, availH / _mapPx);
    _minZoom = fit * 0.8;
    _maxZoom = fit * 4;
    zoom = fit;
    mapOffset = Vector2(
      (size.x - _mapPx * zoom) / 2,
      topInset + (availH + 16 - _mapPx * zoom) / 2,
    );
    _fitted = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_userMoved) {
      _clampPan();
    } else {
      fitToScreen();
    }
  }

  void _zoomAround(Vector2 focus, double newZoom) {
    newZoom = newZoom.clamp(_minZoom, _maxZoom);
    final world = (focus - mapOffset) / zoom;
    zoom = newZoom;
    mapOffset = focus - world * zoom;
    _clampPan();
  }

  void _clampPan() {
    // Keep at least a quarter of the map on screen.
    final mapW = _mapPx * zoom;
    final keep = mapW * 0.25;
    mapOffset.x = mapOffset.x.clamp(keep - mapW, size.x - keep);
    mapOffset.y = mapOffset.y.clamp(
      topInset + keep - mapW,
      size.y - bottomInset - keep,
    );
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _zoomAtGestureStart = zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    _userMoved = true;
    final scale = info.raw.scale;
    if ((scale - 1).abs() > 0.01) {
      _zoomAround(info.eventPosition.widget, _zoomAtGestureStart * scale);
    }
    mapOffset += info.delta.global;
    _clampPan();
  }

  @override
  void onScroll(PointerScrollInfo info) {
    _userMoved = true;
    final dy = info.scrollDelta.global.y;
    _zoomAround(info.eventPosition.widget, zoom * (dy > 0 ? 0.9 : 1.1));
  }

  // ---------------------------------------------------------------- input

  math.Point<int>? _cellAt(Vector2 screen) {
    final lx = (screen.x - mapOffset.x) / (_tile * zoom);
    final ly = (screen.y - mapOffset.y) / (_tile * zoom);
    if (lx < 0 ||
        ly < 0 ||
        lx >= GameConstants.gridCols ||
        ly >= GameConstants.gridRows) {
      return null;
    }
    return math.Point(lx.floor(), ly.floor());
  }

  @override
  void onTapUp(TapUpEvent event) {
    final cell = _cellAt(event.canvasPosition);
    if (cell == null) return;
    _effects.tap(
      Offset(
        (event.canvasPosition.x - mapOffset.x) / zoom,
        (event.canvasPosition.y - mapOffset.y) / zoom,
      ),
      _time,
    );
    final b = controller.selectedBuilding;
    if (b != null && !controller.isDemolishMode) {
      // Centre multi-tile buildings on the tapped cell.
      final gx = (cell.x - (b.width - 1) ~/ 2).clamp(
        0,
        GameConstants.gridCols - b.width,
      );
      final gy = (cell.y - (b.height - 1) ~/ 2).clamp(
        0,
        GameConstants.gridRows - b.height,
      );
      controller.placeBuildingAt(gx, gy);
    } else {
      controller.placeBuildingAt(cell.x, cell.y);
    }
  }

  @override
  void onMouseMove(PointerHoverInfo info) {
    _hoverCell = _cellAt(info.eventPosition.widget);
  }

  // ---------------------------------------------------------------- render

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (controller.gameId != _gameId) {
      _gameId = controller.gameId;
      _effects.reset();
    }
    _effects.update(dt, controller.state.terrain);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final state = controller.state;
    final m = state.metrics;

    canvas.save();
    canvas.translate(mapOffset.x, mapOffset.y);
    canvas.scale(zoom);

    // Map frame + drop shadow so the board reads as a game board.
    final board = Rect.fromLTWH(0, 0, _mapPx, _mapPx);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        board.shift(const Offset(0, 6)).inflate(4),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(board.inflate(4), const Radius.circular(6)),
      Paint()..color = const Color(0xFF120D09),
    );

    // 1. Terrain
    final waterBad = m.waterPurity < 40.0;
    final painter = TerrainPainter(state.terrain, _tile);
    final soilBad = m.soilHealth < 40.0;
    for (int y = 0; y < GameConstants.gridRows; y++) {
      for (int x = 0; x < GameConstants.gridCols; x++) {
        final base = state.terrain[y][x];
        // Grass under everything except bare dirt.
        var key = base == Terrain.dirt
            ? 'tiles/dirt.png'
            : (soilBad ? 'tiles/grass_dead.png' : 'tiles/grass.png');
        (_sprites[key] ?? _sprites['tiles/grass.png'])?.render(
          canvas,
          position: Vector2(x * _tile, y * _tile),
          size: Vector2.all(_tile + 0.5), // overlap hides seams when zoomed
          overridePaint: _spritePaint,
        );
        final pos = Vector2(x * _tile, y * _tile);
        final sz = Vector2.all(_tile + 0.5);
        if (base == Terrain.river) {
          final bridge = painter.isBridge(x, y);
          final mask = bridge ? 'tb' : painter.riverMask(x, y);
          final sprite =
              _sprites['tiles/river_$mask${waterBad ? '_polluted' : ''}.png'];
          if (sprite != null) {
            sprite.render(
              canvas,
              position: pos,
              size: sz,
              overridePaint: _spritePaint,
            );
            if (bridge) painter.paintBridgeDeck(canvas, x, y);
          } else {
            painter.paintRiver(canvas, x, y, polluted: waterBad, time: _time);
          }
        } else if (base == Terrain.road) {
          final sprite = _sprites['tiles/road_${painter.roadMask(x, y)}.png'];
          if (sprite != null) {
            sprite.render(
              canvas,
              position: pos,
              size: sz,
              overridePaint: _spritePaint,
            );
          } else {
            painter.paintRoad(canvas, x, y);
          }
        } else if (base == Terrain.forest) {
          final v = painter.forestVariant(x, y);
          final sprite =
              _sprites['tiles/forest_${soilBad ? 'dead_' : ''}$v.png'];
          if (sprite != null) {
            sprite.render(
              canvas,
              position: pos,
              size: sz,
              overridePaint: _spritePaint,
            );
          } else {
            painter.paintForest(canvas, x, y, dead: soilBad);
          }
        }
      }
    }

    // Build-mode grid
    final building =
        controller.selectedBuilding != null || controller.isDemolishMode;
    if (building) {
      final grid = Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 0.6 / zoom.clamp(0.5, 2);
      for (int i = 0; i <= GameConstants.gridCols; i++) {
        canvas.drawLine(Offset(i * _tile, 0), Offset(i * _tile, _mapPx), grid);
        canvas.drawLine(Offset(0, i * _tile), Offset(_mapPx, i * _tile), grid);
      }
    }

    // Cars drive on the roads, under everything else.
    _effects.syncBuildings(state.buildings, _time);
    _effects.drawCars(canvas);

    // 2. Buildings (with a soft shadow), sorted top-to-bottom
    final placed = [...state.buildings]
      ..sort((a, b) => a.gridY.compareTo(b.gridY));
    final shadow = Paint()..color = const Color(0x55000000);
    for (final p in placed) {
      final t = BuildingsData.all[p.buildingTypeId];
      if (t == null) continue;
      final r = Rect.fromLTWH(
        p.gridX * _tile,
        p.gridY * _tile,
        t.width * _tile,
        t.height * _tile,
      );
      final (sx, sy) = _effects.popScale(p.id, _time);
      canvas.save();
      // Pop in from the bottom centre (squash and stretch).
      canvas.translate(r.center.dx, r.bottom);
      canvas.scale(sx, sy);
      canvas.translate(-r.center.dx, -r.bottom);
      if (p.buildingTypeId != 'wind_turbine') {
        canvas.drawRect(r.shift(const Offset(2, 2.5)), shadow);
      }
      if (p.buildingTypeId == 'wind_turbine') {
        // Grass pad, then spinning blades.
        canvas.save();
        canvas.translate(r.center.dx, r.center.dy);
        canvas.rotate(_time * 2.4 + p.gridX);
        canvas.translate(-r.center.dx, -r.center.dy);
        _sprites[t.spritePath]?.render(
          canvas,
          position: Vector2(r.left, r.top),
          size: Vector2(r.width, r.height),
          overridePaint: _spritePaint,
        );
        canvas.restore();
      } else {
        _sprites[t.spritePath]?.render(
          canvas,
          position: Vector2(r.left, r.top),
          size: Vector2(r.width, r.height),
          overridePaint: _spritePaint,
        );
      }
      canvas.restore();
    }

    // 3. Smoke from polluters
    for (final p in placed) {
      if (p.buildingTypeId == 'coal_plant' ||
          p.buildingTypeId == 'factory' ||
          p.buildingTypeId == 'oil_refinery') {
        _drawSmoke(
          canvas,
          Offset((p.gridX + 0.8) * _tile, (p.gridY + 0.5) * _tile),
          p.gridX * 7.0 + p.gridY,
        );
      }
    }

    _effects.drawAmbient(
      canvas,
      state.buildings,
      state.terrain,
      _time,
      waterClean: !waterBad,
    );
    _effects.drawFx(canvas, _time);

    // 4. Hover / placement preview (desktop)
    final hc = _hoverCell;
    if (hc != null && building) {
      final b = controller.selectedBuilding;
      int w = 1, h = 1, gx = hc.x, gy = hc.y;
      bool ok = true;
      if (b != null && !controller.isDemolishMode) {
        w = b.width;
        h = b.height;
        gx = (hc.x - (w - 1) ~/ 2).clamp(0, GameConstants.gridCols - w);
        gy = (hc.y - (h - 1) ~/ 2).clamp(0, GameConstants.gridRows - h);
        for (int y = 0; y < h && ok; y++) {
          for (int x = 0; x < w && ok; x++) {
            if (state.isCellOccupied(gx + x, gy + y) ||
                Terrain.isBlocked(state.terrain[gy + y][gx + x]) ||
                (state.terrain[gy + y][gx + x] == Terrain.river &&
                    b.id != 'water_treatment')) {
              ok = false;
            }
          }
        }
        ok = ok && state.canAfford(b);
        _sprites[b.spritePath]?.render(
          canvas,
          position: Vector2(gx * _tile, gy * _tile),
          size: Vector2(w * _tile, h * _tile),
          overridePaint: Paint()
            ..filterQuality = FilterQuality.medium
            ..color = const Color(0x99FFFFFF),
        );
      } else {
        ok = state.isCellOccupied(gx, gy);
      }
      final rect = Rect.fromLTWH(gx * _tile, gy * _tile, w * _tile, h * _tile);
      final col = controller.isDemolishMode
          ? const Color(0xFFE5483B)
          : (ok ? const Color(0xFF7CD34B) : const Color(0xFFE5483B));
      canvas.drawRect(rect, Paint()..color = col.withValues(alpha: 0.25));
      canvas.drawRect(
        rect,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    _effects.drawClouds(canvas, board, _time);

    // 5. Smog haze over the whole board when AQI is high
    if (m.aqi > 100.0) {
      final a = ((m.aqi - 100) / 200).clamp(0.0, 0.45);
      canvas.drawRect(board, Paint()..color = Color.fromRGBO(110, 95, 55, a));
    }

    canvas.restore();
  }

  void _drawSmoke(Canvas canvas, Offset origin, double seed) {
    const puffs = 4;
    for (int i = 0; i < puffs; i++) {
      final t = ((_time * 0.35 + i / puffs + seed * 0.13) % 1.0);
      final pos =
          origin + Offset(math.sin((t + seed) * 6) * 3 + t * 6, -t * 26);
      final radius = 3 + t * 7;
      canvas.drawCircle(
        pos,
        radius,
        Paint()..color = Color.fromRGBO(70, 66, 60, (1 - t) * 0.55),
      );
    }
  }
}
