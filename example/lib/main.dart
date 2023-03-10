// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
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
      'linear.ldtk',  // for testing tile flips
      // 'third_map.ldtk',
      // 'map_4.ldtk',
      camera: camera,
      // simpleMode: true,
      // compositeAllLevels: true,
    );

    // add(mapComponent);
    // add(mapComponent.tileMap.worldComponents!.first);
    add(mapComponent.tileMap.worldComponents!.first.levels.first);  // for testing tile flips
    // add(mapComponent.tileMap.worldComponents!.first.levels.last);
    addAll(
      mapComponent.tileMap.worldComponents
              ?.map((e) => e.levels)
              .flattened
              .toList() ??
          <Component>[],
    );

    addAll(
      mapComponent.tileMap.worldComponents
              ?.map((e) => e.entities.reversed)
              .flattened
              .toList() ??
          <Component>[],
    );

    // final objGroup =
    //     mapComponent.tileMap.getLayer<ObjectGroup>('AnimatedCoins');
    // final coins = await Flame.images.load('coins.png');

    // camera.zoom = .5;
    camera.viewport = FixedResolutionViewport(Vector2(512, 256));

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

    time += dt;

    // Pan the camera down and right for 10 seconds, then reverse
    if (time % 20 < 10) {
      cameraTarget = mapComponent.size - camera.viewport.effectiveSize;
    } else {
      cameraTarget.setZero();
    }
    camera.moveTo(cameraTarget);
  }
}
