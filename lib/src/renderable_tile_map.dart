import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/src/ldtk_entity.dart';
import 'package:ldtk/ldtk.dart';

/// {@template _renderable_ldtk_map}
///
/// {@endtemplate}
class RenderableLdtkMap {
  /// [Ldtk] instance for this map.
  final Ldtk ldtk;

  /// Camera used for determining the current viewport for layer rendering.
  /// Optional, but required for parallax support
  Camera? camera;

  /// Local path for the main .ldtk file, used to get the path of tileset
  /// images, and will support external .ldtkl levels in the future
  Uri? ldtkPath;

  /// Paint for the map's background color, if there is one
  late final Paint? _backgroundPaint;

  // final Map<Tile, TileFrames> animationFrames;
  final bool simpleMode;

  final List<Sprite>? simpleModeLayers;

  final Sprite? simpleModeSingleImage;

  final Map<int, Image> tilesetsDefinitions;

  final List<LdtkEntity> entities;
  final Map<String, Sprite> entitiesDefinitions;

  /// {@macro _renderable_ldtk_map}
  RenderableLdtkMap(
    this.ldtk, {
    this.camera,
    this.ldtkPath,
    this.simpleMode = false,
    this.simpleModeLayers,
    this.simpleModeSingleImage,
    this.tilesetsDefinitions = const {},
    this.entities = const [],
    this.entitiesDefinitions = const {},
  }) {
    _refreshCache();

    final backgroundColor = ldtk.bgColor?.replaceFirst('#', '');
    if (backgroundColor != null) {
      _backgroundPaint = Paint();
      _backgroundPaint!.color = Color(int.parse(backgroundColor, radix: 16));
    } else {
      _backgroundPaint = null;
    }
  }

  static Future<RenderableLdtkMap> fromSimple(
    String fileName, {
    Camera? camera,
  }) async {
    final ldtkPath = Uri.file(
      'assets/ldtk/$fileName',
      windows: Platform.isWindows,
    );
    final contents = await Flame.bundle.loadString(ldtkPath.path);
    final ldtk = Ldtk.fromRawJson(contents);
    final ldtkProjectName = fileName.substring(0, fileName.length - 5);

    final simpleModeLayers = await makeSimpleModeLayers(ldtk, ldtkProjectName);
    final singleImage = makeSingleImage(simpleModeLayers);

    /// get tilesets definition and sprite
    final tilesetsDefinitions = <int, Image>{};

    for (final tileset in ldtk.defs?.tilesets ?? <TilesetDefinition>[]) {
      final tilesetImagePath = ldtkPath.resolve(tileset.relPath ?? '');
      final image = await (Flame.images..prefix = '').load(
        tilesetImagePath.toFilePath(windows: Platform.isWindows),
      );
      tilesetsDefinitions[tileset.uid!] = image;
    }

    /// get objects definition and sprite
    final entitiesDefinitions = <String, Sprite>{};
    for (final entity in ldtk.defs?.entities ?? <EntityDefinition>[]) {
      entitiesDefinitions[entity.identifier!] = makeEntityImage(
        Sprite(
          tilesetsDefinitions[entity.tilesetId!]!,
          srcPosition: Vector2(
            entity.tileRect!.x!.toDouble(),
            entity.tileRect!.y!.toDouble(),
          ),
          srcSize: Vector2(
            entity.tileRect!.w!.toDouble(),
            entity.tileRect!.h!.toDouble(),
          ),
        ),
      );
    }

    var entities = ldtk.levels!
        .map(
          (level) => level.layerInstances!.map(
            (layer) => layer.entityInstances!.map(
              (entity) => LdtkEntity(
                entitiesDefinitions[entity.identifier!]!,
                entity,
                Vector2(level.worldX!.toDouble(), level.worldY!.toDouble()),
              ),
            ),
          ),
        )
        .flattened
        .toList()
        .map(
          (e) => e.map((e) => e),
        )
        .flattened
        .toList();

    return RenderableLdtkMap(
      ldtk,
      ldtkPath: ldtkPath,
      simpleMode: true,
      simpleModeLayers: simpleModeLayers,
      simpleModeSingleImage: Sprite(singleImage),
      entitiesDefinitions: entitiesDefinitions,
      entities: entities,
      tilesetsDefinitions: tilesetsDefinitions,
    );
  }

  static Future<List<Sprite>> makeSimpleModeLayers(
    Ldtk ldtk,
    String ldtkProjectName,
  ) async {
    final simpleModeLayers = <Sprite>[];
    for (final level in ldtk.levels ?? <Level>[]) {
      final levelName = level.identifier;

      final image = await (Flame.images..prefix = '').load(
        'assets/ldtk/$ldtkProjectName/simplified/$levelName/_composite.png',
        key: levelName,
      );
      // print(levelName);
      simpleModeLayers.add(
        Sprite(
          image,
          srcPosition: Vector2(
            level.worldX?.toDouble() ?? 0,
            level.worldY?.toDouble() ?? 0,
          ),
        ),
      );
    }
    return simpleModeLayers;
  }

  static Image makeSingleImage(List<Sprite> simpleModeLayers) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    var imageTopLeft = simpleModeLayers.first.srcPosition.toOffset();
    var imageBottomRight = simpleModeLayers.first.srcPosition.toOffset();
    for (final sprite in simpleModeLayers) {
      canvas.drawImage(
        sprite.image,
        Offset(sprite.srcPosition.x, sprite.srcPosition.y),
        Paint(),
      );
      imageTopLeft = Offset(
        min(imageTopLeft.dx, sprite.srcPosition.x),
        min(imageTopLeft.dy, sprite.srcPosition.y),
      );
      imageBottomRight = Offset(
        max(imageBottomRight.dx, sprite.srcSize.x + sprite.srcPosition.x),
        max(imageBottomRight.dy, sprite.srcSize.y + sprite.srcPosition.y),
      );
    }
    final imageSize = Rect.fromPoints(imageTopLeft, imageBottomRight).size;
    final picture = recorder.endRecording();
    final compiledImage = picture.toImageSync(
      imageSize.width.round(),
      imageSize.height.round(),
    );
    picture.dispose();
    return compiledImage;
  }

  static Sprite makeEntityImage(Sprite sprite) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    var imageTopLeft = sprite.srcPosition.toOffset();
    var imageBottomRight = (sprite.srcPosition + sprite.srcSize).toOffset();
    final imageSize = Rect.fromPoints(imageTopLeft, imageBottomRight).size;
    sprite.render(canvas);
    final picture = recorder.endRecording();
    final compiledImage = picture.toImageSync(
      imageSize.width.round(),
      imageSize.height.round(),
    );
    picture.dispose();
    return Sprite(compiledImage);
  }

  /// Handle game resize and propagate it to renderable layers
  void handleResize(Vector2 canvasSize) {}

  /// Rebuilds the cache for rendering
  void _refreshCache() {}

  /// Renders each renderable layer in the same order specified by the LDtk map
  void render(Canvas c) {
    if (_backgroundPaint != null) {
      c.drawPaint(_backgroundPaint!);
    }

    // for (final sprite in simpleModeLayers ?? <Sprite>[]) {
    //   c.drawImage(
    //     sprite.image,
    //     Offset(sprite.srcPosition.x, sprite.srcPosition.y),
    //     Paint(),
    //   );
    // }

    if (simpleModeSingleImage != null) {
      c.drawImage(simpleModeSingleImage!.image, Offset.zero, Paint());
      // if (simpleModeLayers != null) {
      //   c.drawImage(makeSingleImage(simpleModeLayers!), Offset.zero, Paint());
    }
  }

  void update(double dt) {}
}
