import 'dart:async';
import 'dart:io';

import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/src/extensions.dart';
import 'package:flame_ldtk/src/mutable_transform.dart';
import 'package:flame_ldtk/src/renderable_layers/renderable_layer.dart';
import 'package:flame_ldtk/src/renderable_layers/renderable_level.dart';
import 'package:flame_ldtk/src/renderable_layers/tiles_layer.dart';
import 'package:flame_ldtk/src/tile_atlas.dart';
import 'package:flame_ldtk/src/tile_stack.dart';
import 'package:flutter/painting.dart';
import 'package:ldtk/ldtk.dart';

/// {@template _renderable_ldtk_map}
/// This is a wrapper over LDtk's [LDtkMap] which can be rendered to a
/// canvas.
///
/// Internally each layer is wrapped with a [RenderableLayer] which handles
/// rendering and caching for supported layer types:
///  - [TilesLayer] is supported with pre-computed SpriteBatches
///  - [IntGridLayer] is supported with [paintImage]
///
/// This also supports the following properties:
///  - [LDtkMap.backgroundColor]
///  - [Layer.opacity]
///  - [Layer.offsetX]
///  - [Layer.offsetY]
///  - [Layer.parallaxX] (only supported if [Camera] is supplied)
///  - [Layer.parallaxY] (only supported if [Camera] is supplied)
///
/// {@endtemplate}
class RenderableLdtkMap {
  /// [LDtk] instance for this map.
  final Ldtk ldtk;

  /// Levels to be rendered
  final List<RenderableLevel> renderableLevels;

  /// The target size for each tile in the tiled map.
  final Vector2 destTileSize;

  /// Camera used for determining the current viewport for layer rendering.
  /// Optional, but required for parallax support
  Camera? camera;

  /// Local path for the main .ldtk file, used to get the path of tileset
  /// images, and will support external .ldtkl levels in the future
  Uri? ldtkPath;

  /// Paint for the map's background color, if there is one
  late final Paint? _backgroundPaint;

  // final Map<Tile, TileFrames> animationFrames;

  /// {@macro _renderable_ldtk_map}
  RenderableLdtkMap(this.ldtk, this.renderableLevels, this.destTileSize,
      {this.camera, this.ldtkPath}) {
    _refreshCache();

    final backgroundColor = ldtk.bgColor?.replaceFirst('#', '');
    if (backgroundColor != null) {
      _backgroundPaint = Paint();
      _backgroundPaint!.color = Color(int.parse(backgroundColor, radix: 16));
    } else {
      _backgroundPaint = null;
    }
  }

  /// Changes the visibility of the corresponding layer, if different
  void setLayerVisibility(int levelId, int layerId, bool visibility) {
    final layer = ldtk.levels
        ?.getLevelByIid(levelId)
        ?.layerInstances
        ?.getLayerByIid(layerId);
    if (layer?.visible != visibility && layer != null) {
      layer.visible = visibility;
      _refreshCache();
    }
  }

  /// Gets the visibility of the corresponding layer
  bool getLayerVisibility(int levelId, int layerId) {
    return ldtk.levels
            ?.getLevelByIid(levelId)
            ?.layerInstances
            ?.getLayerByIid(layerId)
            ?.visible ??
        false;
  }

  /// Gets the id  of the corresponding layer at the given position
  TileInstance? getTileData({
    required int layerId,
    required int x,
    required int y,
  }) {
    final layer = ldtk.getLayerByIid(layerId);
    if (layer?.type == 'Tiles') {
      return layer?.gridTiles?.singleWhere(
          (element) => element.px?.first == x && element.px?.last == y);
    }
    return null;
  }

  /// Select a group of tiles from the coordinates [x] and [y].
  ///
  /// If [all] is set to true, every renderable tile from the map is collected.
  ///
  /// If the [identifiers] or [iids] sets are not empty, any layer with matching
  /// name or id will have their renderable tiles collected. If the matching
  /// layer is a group layer, all layers in the group will have their tiles
  /// collected.
  TileStack tileStack(
    int x,
    int y, {
    Set<String> identifiers = const {},
    Set<String> iids = const {},
    bool all = false,
  }) {
    return TileStack(
      _tileStack(
        renderableLevels,
        x,
        y,
        identifiers: identifiers,
        iids: iids,
        all: all,
      ),
    );
  }

  /// Recursive support for [tileStack]
  List<MutableRSTransform> _tileStack(
    List<RenderableLevel> levels,
    int x,
    int y, {
    Set<String> identifiers = const {},
    Set<String> iids = const {},
    bool all = false,
  }) {
    final tiles = <MutableRSTransform>[];
    for (final level in levels) {
      for (final layer in level.children) {
        if (layer is TilesLayer) {
          if (!(all ||
              identifiers.contains(layer.layer.identifier) ||
              iids.contains(layer.layer.iid))) {
            continue;
          }

          if (layer.layer.gridTiles != null) {
            tiles.add(layer.indexes[x][y]!);
          }
        }
      }
    }
    return tiles;
  }

  /// Parses a file returning a [RenderableLdtkMap].
  ///
  /// NOTE: this method looks for files under the path "assets/ldtk/".
  static Future<RenderableLdtkMap> fromFile(
    String fileName, {
    Camera? camera,
  }) async {
    final ldtkPath = Uri.file(
      'assets/ldtk/$fileName',
      windows: Platform.isWindows,
    );
    final contents = await Flame.bundle.loadString(ldtkPath.path);
    return fromString(contents, camera: camera, path: ldtkPath);
  }

  /// Parses a string returning a [RenderableLdtkMap].
  static Future<RenderableLdtkMap> fromString(
    String contents, {
    Camera? camera,
    Uri? path,
  }) async {
    final ldtk = Ldtk.fromRawJson(contents);
    return fromLdtk(ldtk, camera: camera, path: path);
  }

  /// Parses an [Ldtk] returning a [RenderableLdtkMap].
  static Future<RenderableLdtkMap> fromLdtk(
    Ldtk ldtk, {
    Camera? camera,
    Uri? path,
  }) async {
    // map.tilesets.sort((l, r) => (l.firstGid ?? 0) - (r.firstGid ?? 0));

    final renderableLevels = await _renderableLevels(
      ldtk.levels,
      null,
      ldtk,
      camera,
      path,
    );

    return RenderableLdtkMap(
      ldtk,
      renderableLevels,
      Vector2(ldtk.defaultGridSize?.toDouble() ?? 0,
          ldtk.defaultGridSize?.toDouble() ?? 0),
      camera: camera,
      ldtkPath: path,
    );
  }

  static Future<List<RenderableLevel<Level>>> _renderableLevels(
    List<Level>? levels,
    World? parent,
    Ldtk ldtk,
    Camera? camera,
    Uri? ldtkPath,
  ) async {
    final levelLayers = <RenderableLevel<Level>>[];
    if (levels != null) {
      for (final level in levels) {
        final renderableLevel = RenderableLevel(
          level,
          parent,
          ldtk,
        );
        renderableLevel.children = await _renderableLayers(
          level.layerInstances,
          level,
          ldtk,
          camera,
          atlas: await TileAtlas.fromLdtk(ldtk, ldtkPath),
          ldtkPath: ldtkPath,
        );
        levelLayers.add(renderableLevel);
      }
    }
    return levelLayers;
  }

  static Future<List<RenderableLayer<LayerInstance>>> _renderableLayers(
    List<LayerInstance>? layers,
    Level? parent,
    Ldtk map,
    Camera? camera, {
    required TileAtlas atlas,
    Uri? ldtkPath,
  }) async {
    final renderLayers = <RenderableLayer<LayerInstance>>[];
    if (layers != null) {
      for (final layer in layers.where((layer) => layer.visible ?? false)) {
        renderLayers.add(
          await TilesLayer.load(
            layer,
            parent,
            map,
            atlas.clone(),
            ldtkPath,
          ),
        );
      }
    }
    return renderLayers;
  }

  /// Handle game resize and propagate it to renderable layers
  void handleResize(Vector2 canvasSize) {
    for (final layer in renderableLevels) {
      layer.handleResize(canvasSize);
    }
  }

  /// Rebuilds the cache for rendering
  void _refreshCache() {
    for (final level in renderableLevels) {
      level.refreshCache();
    }
  }

  /// Renders each renderable layer in the same order specified by the LDtk map
  void render(Canvas c) {
    if (_backgroundPaint != null) {
      c.drawPaint(_backgroundPaint!);
    }

    // Paint each layer in reverse order, because the last layers should be
    // rendered beneath the first layers
    for (final level in renderableLevels) {
      level.render(c, camera);
    }
  }

  void update(double dt) {
    // Then every layer.
    for (final layer in renderableLevels) {
      layer.update(dt);
    }
  }
}
