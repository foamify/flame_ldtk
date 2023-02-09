import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_ldtk/src/ldtk_entity.dart';
import 'package:flame_ldtk/src/ldtk_level.dart';

/// {@template _ldtk_world}
///
/// World [Component] in Ldtk
///
/// {@endtemplate}
class LdtkWorld extends PositionComponent {
  /// {@macro _ldtk_world}
  LdtkWorld(
    this.sprite,
    this.levels,
    this.entities, {
    super.priority,
  }) {
    size = sprite?.srcSize ??
        levels.fold<Rect>(levels.isEmpty ? Rect.zero : levels.first.toRect(),
            (previousValue, element) {
          final imageTopLeft = Offset(
            min(previousValue.topLeft.dx, element.x),
            min(previousValue.topLeft.dy, element.y),
          );
          final imageBottomRight = Offset(
            max(
              previousValue.bottomRight.dx,
              element.toRect().bottomRight.dx,
            ),
            max(
              previousValue.bottomRight.dy,
              element.toRect().bottomRight.dy,
            ),
          );
          return Rect.fromPoints(imageTopLeft, imageBottomRight);
        }).toVector2();
  }

  ///
  Sprite? sprite;

  ///
  final List<LdtkLevel> levels;

  ///
  final List<LdtkEntity> entities;

  /// Renders all level components at once
  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      canvas.drawImage(
        sprite!.image,
        Offset(sprite!.srcPosition.x, sprite!.srcPosition.y),
        Paint(),
      );
    } else {
      for (final level in levels) {
        canvas.drawImage(
          level.sprite.image,
          level.position.toOffset(),
          Paint(),
        );
      }
    }
  }
}
