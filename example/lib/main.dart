import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/flame_ldtk.dart';
import 'package:flutter/widgets.dart' hide Animation, Image;

void main() {
  runApp(GameWidget(game: LdtkGame()));
}

class LdtkGame extends FlameGame {
  late LdtkComponent mapComponent;

  double time = 0;
  Vector2 cameraTarget = Vector2.zero();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    add(FpsTextComponent());

    mapComponent = await LdtkComponent.load(
      'third_map.ldtk',
      camera: camera,
      simpleMode: true,
      // compositeAllLevels: true,
    );
    add(mapComponent);

    final entities = mapComponent.tileMap.entities.reversed;
    addAll(entities);

    // final objGroup =
    //     mapComponent.tileMap.getLayer<ObjectGroup>('AnimatedCoins');
    // final coins = await Flame.images.load('coins.png');

    camera.zoom = 1;
    camera.viewport = FixedResolutionViewport(Vector2(256, 256));

    // We are 100% sure that an object layer named `AnimatedCoins`
    // exists in the example `map.tmx`.
    //   for (final obj in objGroup!.objects) {
    //     add(
    //       SpriteAnimationComponent(
    //         size: Vector2.all(20.0),
    //         position: Vector2(obj.x, obj.y),
    //         animation: SpriteAnimation.fromFrameData(
    //           coins,
    //           SpriteAnimationData.sequenced(
    //             amount: 8,
    //             stepTime: .15,
    //             textureSize: Vector2.all(20),
    //           ),
    //         ),
    //       ),
    //     );
    //   }
    // }
  }

  @override
  void update(double dt) {
    super.update(dt);

    camera.moveTo(Vector2(.2, 0));

    time += dt;
    var imageTopLeft = Offset.zero;
    var imageBottomRight = Offset.zero;

    for (final level in mapComponent.tileMap.ldtk.levels!) {
      imageTopLeft = Offset(
        min(imageTopLeft.dx, level.worldX!.toDouble()),
        min(imageTopLeft.dy, level.worldY!.toDouble()),
      );
      imageBottomRight = Offset(
        max(imageBottomRight.dx, level.pxWid! + level.worldX!.toDouble()),
        max(imageBottomRight.dy, level.pxHei! + level.worldY!.toDouble()),
      );
    }

    // final imageSize = Rect.fromPoints(imageTopLeft, imageBottomRight).size;
    // Pan the camera down and right for 10 seconds, then reverse
    if (time % 20 < 10) {
      cameraTarget.x = imageBottomRight.dx;
      cameraTarget.y = imageBottomRight.dy;
    } else {
      cameraTarget.setZero();
    }
    camera.moveTo(cameraTarget);
  }
}
