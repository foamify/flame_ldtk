import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_ldtk/flame_ldtk.dart';

/// {@template _ldtk_level}
///
/// Level [Component] in Ldtk
///
/// {@endtemplate}
class LdtkLevel extends PositionComponent {
  /// {@macro _ldtk_level}
  LdtkLevel(
    this.sprite,
    this.level, {
    super.priority,
  }) {
    size = sprite.srcSize;
    position = Vector2(
      level?.worldX?.toDouble() ?? sprite.srcPosition.x,
      level?.worldY?.toDouble() ?? sprite.srcPosition.y,
    );
  }

  /// Level layers
  Sprite sprite;

  /// [Level] information
  Level? level;

  /// Renders all layers at once
  @override
  void render(Canvas canvas) {
    sprite.render(canvas);
  }
}
