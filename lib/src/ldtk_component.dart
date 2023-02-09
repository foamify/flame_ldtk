import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/flame_ldtk.dart';
import 'package:flame_ldtk/src/renderable_tile_map.dart';
import 'package:meta/meta.dart';

/// {@template _ldtk_component}
///
/// A Flame [Component] to render a whole LDtk map.
///
///
/// Because this component is basically all levels mashed into one component,
/// use this component as-is only if the map uses GridVania or
/// Free World Layout and all levels don't overlap each other.
///
/// Other than that, use [tileMap.levelComponents] or
/// [tileMap.simpleModeLayers].
///
/// {@endtemplate}
class LdtkComponent<T extends FlameGame> extends PositionComponent
    with HasGameRef<T> {
  /// {@macro _ldtk_component}
  LdtkComponent(
    this.tileMap, {
    super.priority,
  }) {
    super.size = computeSize(tileMap);
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
    final worlds = tileMap.worldComponents ?? <LdtkWorld>[];
    final size = worlds.fold<Vector2>(worlds.isEmpty ? Vector2.zero() : worlds.first.size,
        (previousValue, element) {
      final imageTopLeft = Offset(
        min(previousValue.x, element.x),
        min(previousValue.y, element.y),
      );
      final imageBottomRight = Offset(
        max(
          previousValue.toRect().bottomRight.dx,
          element.toAbsoluteRect().bottomRight.dx,
        ),
        max(
          previousValue.toRect().bottomRight.dy,
          element.toAbsoluteRect().bottomRight.dy,
        ),
      );
      return Rect.fromPoints(imageTopLeft, imageBottomRight).toVector2();
    });
    return size;
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

  /// Loads [LdtkComponent] from '/assets/ldtk/<[fileName]>'
  ///
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
