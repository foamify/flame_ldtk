import 'dart:ui';

import 'package:flame/components.dart';

/// {@template ldtk_entity}
/// Layer [Component] in Ldtk
///
/// {@endtemplate}
class LdtkLayer extends PositionComponent {
  /// {@macro ldtk_entity}
  LdtkLayer(this.sprite, this.levelOffset) {
    size = sprite.srcSize;
    position = Vector2(
      levelOffset.x,
      levelOffset.y,
    );
  }

  Sprite sprite;

  /// Level offset relative to its world
  final Vector2 levelOffset;

  @override
  void render(Canvas canvas) {
    sprite.render(
      canvas,
    );
    // c.drawImage(sprite.image, Offset.zero, Paint());
  }
}
