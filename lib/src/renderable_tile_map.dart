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
import 'package:flame_ldtk/src/ldtk_level.dart';
import 'package:flame_ldtk/src/ldtk_world.dart';
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
    this.simpleModeLevels,
    this.worldComponents,
    this.tilesetDefinitions = const {},
    this.entities = const [],
    this.entityDefinitions = const {},
  });

  /// [Ldtk] instance for this map.
  final Ldtk ldtk;

  /// Camera used for determining the current viewport for layer rendering.
  /// Optional, but required for parallax support
  Camera? camera;

  /// Local path for the main .ldtk file, used to get the path of tileset
  /// images, and will support external .ldtkl levels in the future
  Uri? ldtkPath;

  // final Map<Tile, TileFrames> animationFrames;
  final bool simpleMode;

  final List<Sprite>? simpleModeLevels;

  final List<LdtkWorld>? worldComponents;

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
    final isMultiWorld = ldtk.worldLayout == null;

    final ldtkPath = Uri.file(
      'assets/ldtk/$fileName',
      windows: Platform.isWindows,
    );
    final ldtkProjectName = fileName.substring(0, fileName.length - 5);

    final worlds = isMultiWorld
        ? ldtk.worlds?.map((e) => e.levels ?? []).toList() ?? <List<Level>>[]
        : [ldtk.levels ?? <Level>[]];

    List<Sprite>? simpleModeLayers;
    final worldComponents = <LdtkWorld>[];

    /// get tilesets definition and sprite
    final tilesetsDefinitions = <int, Image>{};

    for (final tileset in ldtk.defs?.tilesets ?? <TilesetDefinition>[]) {
      final tilesetImagePath = ldtkPath.resolve(tileset.relPath ?? '');
      Image? image;
      if (tileset.embedAtlas != EmbedAtlas.LDTK_ICONS) {
        image = await (Flame.images..prefix = '').load(
          tilesetImagePath.toFilePath(windows: Platform.isWindows),
        );
        tilesetsDefinitions[tileset.uid ?? -1] = image;
      }
    }

    /// get entities definition and sprite
    final entitiesDefinitions = <String, Sprite>{};
    for (final entity in ldtk.defs?.entities ?? <EntityDefinition>[]) {
      if (tilesetsDefinitions[entity.tilesetId!] != null) {
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
    }

    for (final levels in worlds) {
      final entities = levels
          .map(
            (level) => level.layerInstances!.map(
              (layer) => layer.entityInstances!.map(
                (entity) => LdtkEntity(
                  entitiesDefinitions[entity.identifier!],
                  entity,
                  Vector2(level.worldX!.toDouble(), level.worldY!.toDouble()),
                ),
              ),
            ),
          )
          // converts Iterable<Iterable<Iterable<T>>> into List<T>
          .flattened
          .flattened
          .toList();

      List<LdtkLevel>? ldtkLevels;
      if (simpleMode) {
        simpleModeLayers = await makeSimpleModeLayers(levels, ldtkProjectName);
        if (compositeAllLevels) {
          simpleModeLayers = [Sprite(makeSingleImage(simpleModeLayers))];
        }
      } else {
        ldtkLevels = [];
        // TODO(damywise): prerender tiles as one image (all layers at once or per layer)
        for (final level in levels) {
          for (final layer
              in level.layerInstances?.reversed ?? <LayerInstance>[]) {
            final recorder = PictureRecorder();
            final canvas = Canvas(recorder);
            final imageSize = ldtk.worldLayout == WorldLayout.GRID_VANIA
                ? Size(
                    level.pxWid!.toDouble(),
                    level.pxHei!.toDouble(),
                  )
                : Size(
                    layer.cWid! * layer.gridSize!.toDouble(),
                    layer.cHei! * layer.gridSize!.toDouble(),
                  );

            List<TileInstance>? layerTiles;
            if ((layer.gridTiles ?? []).isNotEmpty) {
              layerTiles = layer.gridTiles;
            } else if ((layer.autoLayerTiles ?? []).isNotEmpty) {
              layerTiles = layer.autoLayerTiles;
            }

            for (final tile in layerTiles ?? <TileInstance>[]) {
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
            ldtkLevels.add(
              LdtkLevel(
                Sprite(
                  compiledLevelImage,
                  srcPosition: ldtk.worldLayout == WorldLayout.GRID_VANIA
                      ? Vector2(
                          level.worldX!.toDouble(),
                          level.worldY!.toDouble(),
                        )
                      : null,
                ),
                level,
              ),
            );
            picture.dispose();
          }
        }
      }
      Sprite? sprite;

      if (compositeAllLevels && ldtkLevels != null) {
        sprite = Sprite(
          makeSingleImage(
            ldtkLevels
                .map(
                  (e) => Sprite(e.sprite.image, srcPosition: e.position),
                )
                .toList(),
          ),
        );
        for (final level in ldtkLevels) {
          level.sprite.image.dispose();
        }
      }
      worldComponents.add(LdtkWorld(sprite, ldtkLevels ?? [], entities));
    }

    return RenderableLdtkMap(
      ldtk,
      ldtkPath: ldtkPath,
      simpleMode: true,
      simpleModeLevels: simpleModeLayers,
      worldComponents: worldComponents,
      entityDefinitions: entitiesDefinitions,
      tilesetDefinitions: tilesetsDefinitions,
    );
  }

  static Future<List<Sprite>> makeSimpleModeLayers(
    List<Level> levels,
    String ldtkProjectName,
  ) async {
    final simpleModeLayers = <Sprite>[];
    for (final level in levels) {
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

  /// Combine a list of sprites into one single image
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

  /// Renders all world components at once
  void render(Canvas canvas) {
    if (simpleModeLevels != null) {
      for (final sprite in simpleModeLevels ?? <Sprite>[]) {
        canvas.drawImage(
          sprite.image,
          Offset(sprite.srcPosition.x, sprite.srcPosition.y),
          Paint(),
        );
      }
    } else {
      for (final world in worldComponents ?? <LdtkWorld>[]) {
        world.render(canvas);
      }
    }
  }

  void update(double dt) {}
}
