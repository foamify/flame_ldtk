import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/src/renderable_layers/renderable_layer.dart';
import 'package:flame_ldtk/src/tile_atlas.dart';
import 'package:flutter/painting.dart';
import 'package:ldtk/ldtk.dart';
import 'package:meta/meta.dart';

/// This was a combination GroupLayer and RenderableLayer from flame_tiled
@internal
class RenderableLevel<T extends Level> {
  late final _layerPaint = Paint();
  final T level;
  final Ldtk ldtk;

  /// The parent [World] layer (when it finallly exists)
  final World? world;

  late TileAtlas tileAtlas;

  RenderableLevel(
    this.level,
    this.world,
    this.ldtk,
  ) {
    _layerPaint.color = const Color.fromRGBO(255, 255, 255, 1);
  }

  late num? offsetX = level.worldX;

  late num? offsetY = level.worldY;

  late final List<RenderableLayer> children;

  late final Image image;

  void refreshCache() {
    for (final child in children) {
      child.refreshCache();
    }
  }

  void handleResize(Vector2 canvasSize) {
    for (final child in children) {
      child.handleResize(canvasSize);
    }
  }

  void render(Canvas canvas, Camera? camera) {
    for (final child in children) {
      child.render(canvas, camera);
    }
  }

  void update(double dt) {
      for (final child in children) {
        child.update(dt);
    }
  }

  /// Calculates the offset we need to apply to the canvas to compensate for
  /// the current camera position
  void applyParallaxOffset(Canvas canvas, Camera camera) {
    final cameraX = camera.position.x;
    final cameraY = camera.position.y;
    final vpCenterX = camera.viewport.effectiveSize.x / 2;
    final vpCenterY = camera.viewport.effectiveSize.y / 2;

    // Due to how Tiled treats the center of the view as the reference
    // point for parallax positioning (see Tiled docs), we need to offset the
    // entire layer
    var x = vpCenterX;
    var y = vpCenterY;
    // compensate the offset for zoom
    x /= camera.zoom;
    y /= camera.zoom;

    x += cameraX;
    y += cameraY;

    canvas.translate(x, y);
  }
}

@internal
class UnsupportedLevel extends RenderableLevel {
  UnsupportedLevel(
    super.layer,
    super.parent,
    super.map,
  );

  @override
  void render(Canvas canvas, Camera? camera) {}

  @override
  void handleResize(Vector2 canvasSize) {}

  @override
  void refreshCache() {}

  @override
  void update(double dt) {}
}
