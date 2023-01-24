import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flame_ldtk/flame_ldtk.dart';

extension GetById on Ldtk {
  Level? getLevelByIid(int iid) =>
      levels?.singleWhereOrNull((element) => element.iid == iid);

  LayerInstance? getLayerByIid(int iid) =>
      levels?.map((e) => e.layerInstances?.getLayerByIid(iid)).first;

  TilesetDefinition? getTilesetByUid(int uid) =>
      defs?.tilesets?.singleWhereOrNull((element) => element.uid == uid);
}

extension GetLevelById on List<Level>? {
  // Level? getLevelByUid(int uid) => this?.singleWhereOrNull((element) => element.uid == uid);
  Level? getLevelByIid(int iid) =>
      this?.singleWhereOrNull((element) => element.iid == iid);

  LayerInstance? getLayerByIid(int iid) =>
      this?.map((e) => e.layerInstances?.getLayerByIid(iid)).first;
}

extension GetLayerById on List<LayerInstance>? {
  // LayerInstance? getLayerByUid(int uid) => this?.singleWhereOrNull((element) => element.layerDefUid == uid);
  LayerInstance? getLayerByIid(int iid) =>
      this?.singleWhereOrNull((element) => element.layerDefUid == iid);
}

extension GetTilesetById on List<TilesetDefinition>? {
  TilesetDefinition? getTilesetByUid(int uid) =>
      this?.singleWhereOrNull((element) => element.uid == uid);
}

extension ComputeDrawRect on TilesetDefinition {
  Rectangle computeDrawRect(TileInstance tile) {
    return Rectangle(
      tile.src?.first ?? 0,
      tile.src?.last ?? 0,
      tileGridSize ?? 0,
      tileGridSize ?? 0,
    );
  }
}