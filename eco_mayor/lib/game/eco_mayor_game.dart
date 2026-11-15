import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../controllers/game_controller.dart';
import '../data/buildings_data.dart';
import '../utils/constants.dart';

class EcoMayorFlameGame extends FlameGame with TapCallbacks, PanDetector {
  final GameController controller;
  late Vector2 mapOffset;
  double zoom = 1.0;

  // Cached Sprites
  final Map<String, Sprite> _spriteCache = {};

  EcoMayorFlameGame({required this.controller});

  @override
  Color backgroundColor() => const Color(0xFF1E242B);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    mapOffset = Vector2(20, 40);

    // Preload terrain sprites
    final terrainKeys = [
      'tiles/grass.png',
      'tiles/grass_dead.png',
      'tiles/dirt.png',
      'tiles/water_clean.png',
      'tiles/water_polluted.png',
      'tiles/sand.png',
      'tiles/concrete.png',
    ];
    for (final key in terrainKeys) {
      _spriteCache[key] = await loadSprite(key);
    }

    // Preload buildings
    for (final b in BuildingsData.all.values) {
      _spriteCache[b.spritePath] = await loadSprite(b.spritePath);
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    mapOffset += info.delta.global;
  }

  @override
  void onTapDown(TapDownEvent event) {
    final localX = (event.localPosition.x - mapOffset.x) / (GameConstants.tileSize * zoom);
    final localY = (event.localPosition.y - mapOffset.y) / (GameConstants.tileSize * zoom);

    if (localX >= 0 && localX < GameConstants.gridCols && localY >= 0 && localY < GameConstants.gridRows) {
      final gridX = localX.floor();
      final gridY = localY.floor();
      controller.placeBuildingAt(gridX, gridY);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(mapOffset.x, mapOffset.y);
    canvas.scale(zoom);

    final tileSize = GameConstants.tileSize;

    // 1. Render Terrain Tiles
    final isWaterPolluted = controller.state.metrics.waterPurity < 40.0;
    final isSoilDead = controller.state.metrics.soilHealth < 40.0;

    for (int y = 0; y < GameConstants.gridRows; y++) {
      for (int x = 0; x < GameConstants.gridCols; x++) {
        String baseTile = controller.state.terrain[y][x];
        String assetPath = 'tiles/$baseTile.png';

        if (baseTile == 'water_clean' && isWaterPolluted) {
          assetPath = 'tiles/water_polluted.png';
        } else if (baseTile == 'grass' && isSoilDead) {
          assetPath = 'tiles/grass_dead.png';
        }

        final sprite = _spriteCache[assetPath] ?? _spriteCache['tiles/grass.png'];
        sprite?.render(
          canvas,
          position: Vector2(x * tileSize, y * tileSize),
          size: Vector2(tileSize, tileSize),
        );
      }
    }

    // 2. Render Placed Buildings
    for (final placed in controller.state.buildings) {
      final type = BuildingsData.all[placed.buildingTypeId];
      if (type == null) continue;

      final sprite = _spriteCache[type.spritePath];
      sprite?.render(
        canvas,
        position: Vector2(placed.gridX * tileSize, placed.gridY * tileSize),
        size: Vector2(type.width * tileSize, type.height * tileSize),
      );
    }

    // 3. Render Smog/Haze Overlay if AQI is high
    if (controller.state.metrics.aqi > 100.0) {
      final smogAlpha = ((controller.state.metrics.aqi - 100) / 200).clamp(0.0, 0.5);
      final smogPaint = Paint()..color = Color.fromRGBO(90, 80, 50, smogAlpha);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, GameConstants.gridCols * tileSize, GameConstants.gridRows * tileSize),
        smogPaint,
      );
    }

    canvas.restore();
  }
}
