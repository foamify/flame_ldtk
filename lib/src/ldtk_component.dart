import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/src/renderable_tile_map.dart';
import 'package:meta/meta.dart';

/// {@template _ldtk_component}
/// A Flame [Component] to render an LDtk map.
///
/// It uses a [RenderableLdtkMap] that prerenders levels into one single
/// [Sprite].
/// {@endtemplate}
class LdtkComponent<T extends FlameGame> extends PositionComponent
    with HasGameRef<T> {
  /// {@macro _ldtk_component}
  LdtkComponent(
    this.tileMap, {
    super.position,
    super.scale,
    super.angle,
    super.anchor,
    super.children,
    super.priority,
  }) {
    size = computeSize(tileMap);
  }

  /// Map instance of this component.
  RenderableLdtkMap tileMap;

  /// This property **cannot** be reassigned at runtime. To make the
  /// [PositionComponent] larger or smaller, change its [scale].
  @override
  set size(Vector2 size) {
    // Intentionally left empty.
  }

  /// This property **cannot** be reassigned at runtime. To make the
  /// [PositionComponent] larger or smaller, change its [scale].
  @override
  set width(double w) {
    // Intentionally left empty.
  }

  /// This property **cannot** be reassigned at runtime. To make the
  /// [PositionComponent] larger or smaller, change its [scale].
  @override
  set height(double h) {
    // Intentionally left empty.
  }

  /// Iterate all levels, find the farthest topleft and bottomright point,
  /// and then use those to make [Rect];
  @visibleForTesting
  static Vector2 computeSize(RenderableLdtkMap tileMap) {
    final topLeft = Vector2.zero();
    final bottomRight = Vector2.zero();
    tileMap.ldtk.levels?.forEach((element) {
      topLeft
        ..x = min(topLeft.x, element.worldX?.toDouble() ?? 0)
        ..y = min(topLeft.y, element.worldY?.toDouble() ?? 0);
      bottomRight
        ..x = max(
          bottomRight.x,
          (element.worldX?.toDouble() ?? 0) + (element.pxWid ?? 0),
        )
        ..y = max(
          bottomRight.y,
          (element.worldY?.toDouble() ?? 0) + (element.pxHei ?? 0),
        );
    });
    final rect = Rect.fromPoints(topLeft.toOffset(), bottomRight.toOffset());
    return rect.size.toVector2();
  }

  @override
  Future<void>? onLoad() async {
    super.onLoad();
    // Automatically use the FlameGame camera if it's not already set.
    tileMap.camera ??= gameRef.camera;
  }

  @override
  void update(double dt) {
    tileMap.update(dt);
  }

  @override
  void render(Canvas canvas) {
    tileMap.render(canvas);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    tileMap.handleResize(size);
  }

  static Future<LdtkComponent> load(
    String fileName, {
    int? priority,
    Camera? camera,
    bool simpleMode = false,
    bool compositeAllLevels = false,
  }) async {
    return LdtkComponent(
      await RenderableLdtkMap.fromFile(
        fileName,
        simpleMode: simpleMode,
        compositeAllLevels: compositeAllLevels,
      ),
      priority: priority,
    );
  }
}
