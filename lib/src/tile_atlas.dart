import 'dart:ui';

import 'package:flame/flame.dart';
import 'package:flame/image_composition.dart';
import 'package:flame/sprite.dart';
import 'package:flame_ldtk/flame_ldtk.dart';
import 'package:flame_ldtk/src/rectangle_bin_packer.dart';
import 'package:meta/meta.dart';

/// One image atlas for all Tiled image sets in a map.
class TileAtlas {
  /// Single atlas for all renders.
  // Retain this as SpriteBatch can dispose of the original image for flips.
  final Image? atlas;

  /// Map of all source images to their new offset.
  final Map<String, Offset> offsets;

  /// The single batch operation for this atlas.
  final SpriteBatch? batch;

  /// Image key for this atlas.
  final String key;

  ///
  final Uri? ldtkPath;

  /// Track one atlas for all images in the Tiled map.
  ///
  /// See [fromLdtk] for asynchronous loading.
  TileAtlas._(this.atlas, this.offsets, this.key, this.ldtkPath)
      : batch = atlas == null ? null : SpriteBatch(atlas, imageKey: key);

  /// Returns whether or not this atlas contains [source].
  bool contains(String? source) => offsets.containsKey(source);

  /// Create a new atlas from this object with the intent of getting a new
  /// [SpriteBatch].
  TileAtlas clone() => TileAtlas._(atlas?.clone(), offsets, key, ldtkPath);

  /// Maps of tilesets compiled to [TileAtlas].
  @visibleForTesting
  static final atlasMap = <String, TileAtlas>{};

  @visibleForTesting
  static String atlasKey(Iterable<String> imageRelPaths) {
    final files = ([...imageRelPaths]..sort()).join(',');
    return 'atlas{$files}';
  }

  /// Collect images that we'll use in tiles - exclude image layers.
  static Set<String> _onlyTileImages(Ldtk ldtk, Uri? path) {
    final imageSet = <String>{};
    for (final tileset in ldtk.defs?.tilesets ?? <TilesetDefinition>[]) {
      final imageRelPath = tileset.relPath;
      if (imageRelPath != null) {
        imageSet.add(getPathFromRelPath(path, imageRelPath));
      }
    }
    return imageSet;
  }

  static Future<TileAtlas> fromSimple(
    String ldtkProjectName,
    Level level,
  ) async {
    final levelName = level.identifier!;
    final key = atlasKey([levelName]);
    if (atlasMap.containsKey(key)) {
      return atlasMap[key]!.clone();
    }

    // The map contains one image, so its either an atlas already, or a
    // really boring map.
    final image = (await (Flame.images..prefix = '').load(
      'assets/ldtk/$ldtkProjectName/simplified/$levelName/_composite.png',
      key: key,
    ))
        .clone();

    return atlasMap[key] ??= TileAtlas._(
      image,
      {
        levelName: Offset(
          level.worldX?.toDouble() ?? 0,
          level.worldY?.toDouble() ?? 0,
        )
      },
      key,
      null,
    );
  }

  /// Loads all the tileset images for the [ldtk] into one [TileAtlas].
  static Future<TileAtlas> fromLdtk(Ldtk ldtk, Uri? ldtkPath) async {
    final imageList = _onlyTileImages(ldtk, ldtkPath).toList();

    if (imageList.isEmpty) {
      // so this map has no tiles... Ok.
      return TileAtlas._(null, {}, 'atlas{empty}', null);
    }

    final key = atlasKey(imageList);
    if (atlasMap.containsKey(key)) {
      return atlasMap[key]!.clone();
    }

    if (imageList.length == 1) {
      // The map contains one image, so its either an atlas already, or a
      // really boring map.
      final imageRelPath = imageList.first;
      final image =
          (await (Flame.images..prefix = '').load(imageRelPath, key: key))
              .clone();

      return atlasMap[key] ??=
          TileAtlas._(image, {imageRelPath: Offset.zero}, key, ldtkPath);
    }

    final bin = RectangleBinPacker();
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final _emptyPaint = Paint();

    final offsetMap = <String, Offset>{};

    var pictureRect = Rect.zero;

    // imageList.sort((b, a) {
    //   final height = a.height! - b.height!;
    //   return height != 0 ? height : a.width! - b.width!;
    // });

    // parallelize the download of images.
    await Future.wait(
      [...imageList.map((imagePath) => Flame.images.load(imagePath))],
    );

    for (final imagePath in imageList) {
      final image = await Flame.images.load(imagePath);
      final rect = bin.pack(image.width.toDouble(), image.height.toDouble());

      pictureRect = pictureRect.expandToInclude(rect);

      final offset = offsetMap[imagePath] = Offset(rect.left, rect.top);

      canvas.drawImage(image, offset, _emptyPaint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImageSafe(
      pictureRect.width.toInt(),
      pictureRect.height.toInt(),
    );
    Flame.images.add(key, image);
    return atlasMap[key] = TileAtlas._(image, offsetMap, key, ldtkPath);
  }

  static String getPathFromRelPath(Uri? ldtkPath, String imageRelPath) =>
      ldtkPath?.resolve(imageRelPath).toFilePath() ?? '';
}
