import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/src/renderable_layers/renderable_layer.dart';
import 'package:ldtk/ldtk.dart';
import 'package:meta/meta.dart';

@internal
/// This was a combination GroupLayer and RenderableLayer from flame_tiled
class RenderableLevel<T extends Level> {
  final T level;
  final Ldtk ldtk;

  /// The parent [World] layer (when it finallly exists)
  final World? world;

  RenderableLevel(
    this.level,
    this.world,
    this.ldtk,
  );

  late num? offsetX = level.worldX;

  late num? offsetY = level.worldY;

  late final List<RenderableLayer> children;

  void refreshCache() {
    for (final child in children) {
      print(child.layer.identifier);
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
