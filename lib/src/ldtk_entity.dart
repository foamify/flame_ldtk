import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_ldtk/flame_ldtk.dart';

class LdtkEntity extends PositionComponent {
  LdtkEntity(this.sprite, this.instance, this.levelOffset) {
    size = sprite.srcSize;
    position = Vector2(
      instance.px!.first + levelOffset.x,
      instance.px!.last + levelOffset.y,
    );
  }

  final Sprite sprite;

  final EntityInstance instance;

  final Vector2 levelOffset;

  void render(Canvas c) {
    sprite.render(
      c,
      position: Vector2(
        instance.pivot!.first * -instance.width!,
        instance.pivot!.last * -instance.height!,
      ),
    );
    // c.drawImage(sprite.image, Offset.zero, Paint());
  }
}
