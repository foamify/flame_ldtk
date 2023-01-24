import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:ldtk/ldtk.dart';
import 'package:meta/meta.dart';

@internal
abstract class RenderableLayer<T extends LayerInstance> {
  final T layer;
  final Ldtk ldtk;

  /// The parent [Level] layer (if it exists)
  final Level? parent;

  RenderableLayer(
    this.layer,
    this.parent,
    this.ldtk,
  );

  bool get visible => layer.visible ?? false;

  void render(Canvas canvas, Camera? camera);

  void handleResize(Vector2 canvasSize);

  void refreshCache();

  void update(double dt);

  late double offsetX = layer.pxOffsetX?.toDouble() ?? 0;

  late double offsetY = layer.pxOffsetY?.toDouble() ?? 0;

  late double opacity = layer.opacity ?? 0;

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
class UnsupportedLayer extends RenderableLayer {
  UnsupportedLayer(
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
