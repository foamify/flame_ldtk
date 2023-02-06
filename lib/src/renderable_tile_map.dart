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
import 'package:flame_ldtk/src/ldtk_layer.dart';
import 'package:ldtk/ldtk.dart';

/// {@template _renderable_ldtk_map}
///
/// {@endtemplate}
class RenderableLdtkMap {
  /// {@macro _renderable_ldtk_map}
  RenderableLdtkMap(
    this.ldtk, {
    this.camera,
    this.ldtkPath,
    this.simpleMode = false,
    this.compositeLevels,
    this.simpleModeLayers,
    this.tilesetDefinitions = const {},
    this.entities = const [],
    this.entityDefinitions = const {},
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

  /// prerendered layers
  final List<LdtkLayer>? compositeLevels;

  final Map<int, Image> tilesetDefinitions;

  final List<LdtkEntity> entities;
  final Map<String, Sprite> entityDefinitions;

  static Future<RenderableLdtkMap> fromFile(
    String fileName, {
    bool simpleMode = false,
    bool compositeAllLevels = false,
  }) async {
    final ldtkString = await Flame.bundle.loadString('assets/ldtk/$fileName');
    return fromString(
      ldtkString,
      fileName,
      simpleMode: simpleMode,
      compositeAllLevels: compositeAllLevels,
    );
  }

  static Future<RenderableLdtkMap> fromString(
    String ldtkString,
    String fileName, {
    bool simpleMode = false,
    bool compositeAllLevels = false,
  }) async {
    return fromLdtk(
      Ldtk.fromRawJson(ldtkString),
      fileName,
      simpleMode: simpleMode,
      compositeAllLevels: compositeAllLevels,
    );
  }

  static Future<RenderableLdtkMap> fromLdtk(
    Ldtk ldtk,
    String fileName, {
    bool simpleMode = false,
    bool compositeAllLevels = false,
  }) async {
    final ldtkPath = Uri.file(
      'assets/ldtk/$fileName',
      windows: Platform.isWindows,
    );
    final ldtkProjectName = fileName.substring(0, fileName.length - 5);
    List<Sprite>? simpleModeLayers;
    List<LdtkLayer>? compositeLevels;

    /// get tilesets definition and sprite
    final tilesetsDefinitions = <int, Image>{};

    for (final tileset in ldtk.defs?.tilesets ?? <TilesetDefinition>[]) {
      final tilesetImagePath = ldtkPath.resolve(tileset.relPath ?? '');
      final image = await (Flame.images..prefix = '').load(
        tilesetImagePath.toFilePath(windows: Platform.isWindows),
      );
      tilesetsDefinitions[tileset.uid ?? -1] = image;
    }

    if (simpleMode) {
      simpleModeLayers = await makeSimpleModeLayers(ldtk, ldtkProjectName);
      if (compositeAllLevels) {
        simpleModeLayers = [Sprite(makeSingleImage(simpleModeLayers))];
      }
    } else {
      compositeLevels = [];
      // TODO(damywise): prerender tiles as one image (all layers at once or per layer)
      for (final level in ldtk.levels ?? <Level>[]) {
        for (final layer
            in level.layerInstances?.reversed ?? <LayerInstance>[]) {
          final recorder = PictureRecorder();
          final canvas = Canvas(recorder);
          final imageSize = Size(
            layer.cWid! * layer.gridSize!.toDouble(),
            layer.cHei! * layer.gridSize!.toDouble(),
          );

          List<TileInstance>? tiles;
          if ((layer.gridTiles ?? []).isNotEmpty) {
            tiles = layer.gridTiles;
          } else if ((layer.autoLayerTiles ?? []).isNotEmpty) {
            tiles = layer.autoLayerTiles;
          }

          for (final tile in tiles ?? <TileInstance>[]) {
            Sprite(
              tilesetsDefinitions[layer.tilesetDefUid!]!,
              srcPosition: Vector2(
                tile.src!.first.toDouble(),
                tile.src!.last.toDouble(),
              ),
              srcSize: Vector2(
                layer.gridSize!.toDouble(),
                layer.gridSize!.toDouble(),
              ),
            ).render(
              canvas,
              position: Vector2(
                tile.px!.first.toDouble(),
                tile.px!.last.toDouble(),
              ),
            );
          }
          final picture = recorder.endRecording();
          final compiledLevelImage = picture.toImageSync(
            imageSize.width.round(),
            imageSize.height.round(),
          );
          compositeLevels.add(
            LdtkLayer(
              Sprite(compiledLevelImage),
              Vector2(
                level.worldX!.toDouble(),
                level.worldY!.toDouble(),
              ),
            ),
          );
          picture.dispose();
        }
      }

      if (compositeAllLevels) {
        compositeLevels = [
          LdtkLayer(
            Sprite(
              makeSingleImage(
                compositeLevels
                    .map((e) => Sprite(e.sprite.image, srcPosition: e.position))
                    .toList(),
              ),
            ),
            Vector2.zero(),
          )
        ];
      }
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

    final entities = ldtk.levels!
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
        // converts List<List<List<T>>> into List<T>
        .flattened
        .flattened
        .toList();

    return RenderableLdtkMap(
      ldtk,
      ldtkPath: ldtkPath,
      simpleMode: true,
      simpleModeLayers: simpleModeLayers,
      compositeLevels: compositeLevels,
      entityDefinitions: entitiesDefinitions,
      entities: entities,
      tilesetDefinitions: tilesetsDefinitions,
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

  static Image makeSingleImage(List<Sprite> sprites) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    var imageTopLeft = sprites.first.srcPosition.toOffset();
    var imageBottomRight = sprites.first.srcPosition.toOffset();
    for (final sprite in sprites) {
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
    final imageTopLeft = sprite.srcPosition.toOffset();
    final imageBottomRight = (sprite.srcPosition + sprite.srcSize).toOffset();
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
  void render(Canvas canvas) {
    if (_backgroundPaint != null) {
      canvas.drawPaint(_backgroundPaint!);
    }

    final sprites =
        simpleModeLayers ?? compositeLevels?.map((e) => e.sprite);

    for (final sprite in sprites ?? <Sprite>[]) {
      canvas.drawImage(
        sprite.image,
        Offset(sprite.srcPosition.x, sprite.srcPosition.y),
        Paint(),
      );
    }
  }

  void update(double dt) {}
}
