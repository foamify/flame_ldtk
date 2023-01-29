import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_ldtk/flame_ldtk.dart';
import 'package:flame_ldtk/src/extensions.dart';
import 'package:flame_ldtk/src/mutable_rect.dart';
import 'package:flame_ldtk/src/mutable_transform.dart';
import 'package:flame_ldtk/src/renderable_layers/renderable_layer.dart';
import 'package:flame_ldtk/src/tile_atlas.dart';
import 'package:flutter/painting.dart';
import 'package:meta/meta.dart';

@internal
class TilesLayer extends RenderableLayer<LayerInstance> {
  late final _layerPaint = Paint();
  final TileAtlas? tileAtlas;
  late List<List<MutableRSTransform?>> indexes;
  final Uri? ldtkPath;

  TilesLayer(
    super.layer,
    super.parent,
    super.map,
    this.tileAtlas,
    this.ldtkPath,
  ) {
    _layerPaint.color = Color.fromRGBO(255, 255, 255, opacity);
  }

  @override
  void refreshCache() {
    indexes = List.generate(
      layer.cWid ?? 0,
      (index) => List.filled(layer.cHei ?? 0, null),
    );

    _cacheLayerTiles();
  }

  @override
  void update(double dt) {}

  void _cacheLayerTiles() {
    tileAtlas?.batch?.clear();

    final tileGridSize = layer.gridSize ?? 0;
    final tiles = layer.gridTiles;
    final size = Vector2(
      layer.gridSize?.toDouble() ?? 0,
      layer.gridSize?.toDouble() ?? 0,
    );
    final halfMapTile = Vector2(tileGridSize / 2, tileGridSize / 2);
    final batch = tileAtlas?.batch;
    if (batch == null || tiles == null) {
      return;
    }

    for (final tile in tiles) {
      final tx = (tile.px?.first ?? 0) ~/ (layer.gridSize ?? 0);
      final ty = (tile.px?.last ?? 0) ~/ (layer.gridSize ?? 0);

      final tileset =
          ldtk.defs?.tilesets.getTilesetByUid(layer.tilesetDefUid ?? -1);
      final imageRelPath = tileset?.relPath;
      final imagePath = TileAtlas.getPathFromRelPath(
        ldtkPath,
        imageRelPath ?? '',
      );

      if (imageRelPath == null || tileAtlas == null) {
        continue;
      }

      if (!tileAtlas!.contains(imagePath)) {
        return;
      }

      final spriteOffset = tileAtlas?.offsets[imagePath];
      final src = MutableRect.fromRect(
        tileset
                ?.computeDrawRect(tile)
                .toRect()
                .translate(spriteOffset?.dx ?? 0, spriteOffset?.dy ?? 0) ??
            Rect.zero,
      );

      final flips = SimpleFlips.fromFlipBits(tile.f ?? 0);
      final scale = size.x / tileGridSize;
      final anchorX = src.width - halfMapTile.x;
      final anchorY = src.height - halfMapTile.y;

      late double offsetX;
      late double offsetY;

      offsetX = (tx + .5) * size.x;
      offsetY = (ty + .5) * size.y;

      final scos = flips.cos * scale;
      final ssin = flips.sin * scale;

      indexes[ty][tx] = MutableRSTransform(
        scos,
        ssin,
        offsetX,
        offsetY,
        -scos * anchorX + ssin * anchorY,
        -ssin * anchorX - scos * anchorY,
      );
    }
    // print(
    //     '${layer.identifier} ${indexes.map((e) => e.map((e) => e?.position).toList()).toList()} \n');
  }

  @override
  void render(Canvas canvas, Camera? camera) {
    if (tileAtlas?.batch == null) {
      return;
    }

    canvas.save();

    canvas.translate(offsetX, offsetY);

    if (camera != null) {
      applyParallaxOffset(canvas, camera);
    }

    tileAtlas?.batch?.render(canvas, paint: _layerPaint);

    canvas.restore();
  }

  static Future<TilesLayer> load(
    LayerInstance layer,
    Level? parent,
    Ldtk ldtk,
    TileAtlas? atlas,
    Uri? ldtkPath,
  ) async {
    return TilesLayer(
      layer,
      parent,
      ldtk,
      atlas,
      ldtkPath,
    );
  }

  @override
  void handleResize(Vector2 canvasSize) {}
}
