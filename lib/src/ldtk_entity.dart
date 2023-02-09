import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_ldtk/flame_ldtk.dart';

/// {@template _ldtk_entity}
/// Entity [Component] in Ldtk
///
/// It also has an entityInstance property that contains custom fields
/// {@endtemplate}
class LdtkEntity extends PositionComponent {
  /// {@macro _ldtk_entity}
  LdtkEntity(
    this.sprite,
    this.instance,
    this.levelOffset, {
    super.position,
    super.scale,
    super.angle,
    super.anchor,
    super.children,
    super.priority,
  }) {
    size = sprite?.srcSize ?? Vector2.zero();
    position = Vector2(
      instance.px!.first + levelOffset.x,
      instance.px!.last + levelOffset.y,
    );
  }

  ///
  Sprite? sprite;

  /// Contains custom fields that are stored in the fieldInstances property
  final EntityInstance instance;

  /// Level offset relative to its world
  final Vector2 levelOffset;

  @override
  void render(Canvas canvas) {
    sprite?.render(
      canvas,
      position: Vector2(
        instance.pivot!.first * -instance.width!,
        instance.pivot!.last * -instance.height!,
      ),
    );
    // c.drawImage(sprite.image, Offset.zero, Paint());
  }
}
