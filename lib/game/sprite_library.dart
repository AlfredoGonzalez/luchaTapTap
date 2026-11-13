import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../data/balance.dart';
import '../data/content_bundle.dart';
import 'mask_recolor.dart';

/// Key of the player's sprite sheet (`player.png`).
const String playerSpriteKey = 'player';

/// A decoded sprite sheet: one row per clip, one column per frame, square
/// cells of [cell] pixels.
class SpriteSheet {
  const SpriteSheet({
    required this.image,
    required this.cell,
    required this.animations,
  });

  final ui.Image image;
  final int cell;
  final AnimationConfig animations;

  /// Whether the sheet has a row for [clip] (the kick row is optional).
  bool has(String clip) {
    final row = animations.rowOf(clip);
    return row >= 0 && (row + 1) * cell <= image.height;
  }

  /// The part of the sheet that holds [frame] of [clip].
  ui.Rect frameRect(String clip, int frame) => ui.Rect.fromLTWH(
    (frame * cell).toDouble(),
    (animations.rowOf(clip) * cell).toDouble(),
    cell.toDouble(),
    cell.toDouble(),
  );
}

/// One row of frames for a skill animation (the plancha), cells of
/// [cellWidth] x [cellHeight].
class SkillStrip {
  const SkillStrip({
    required this.image,
    required this.cellWidth,
    required this.cellHeight,
    required this.config,
  });

  final ui.Image image;
  final int cellWidth;
  final int cellHeight;
  final SkillClipConfig config;

  ui.Rect frameRect(int frame) => ui.Rect.fromLTWH(
    (frame * cellWidth).toDouble(),
    0,
    cellWidth.toDouble(),
    cellHeight.toDouble(),
  );
}

/// Sprite sheets by key. Final art lives in `assets/sprites/<key>.png`; until
/// it exists the same name is loaded from `assets/sprites/placeholder/`, and if
/// neither exists the arena draws its rectangle fallback. Swapping art in needs
/// no code change.
class SpriteLibrary {
  SpriteLibrary._(
    this._opponents,
    this._players, [
    this._arenas = const {},
    this._strips = const {},
    this._icons = const {},
  ]);

  /// No sprites at all (tests, and builds that skip art): every fighter falls
  /// back to the rectangle drawing.
  factory SpriteLibrary.empty() => SpriteLibrary._({}, {});

  final Map<String, SpriteSheet> _opponents;

  /// Arena backgrounds by file name (`arena_<league>_<width>`).
  final Map<String, ui.Image> _arenas;

  /// Skill strips by `<name>:<maskId>` (empty mask id = colors as drawn).
  final Map<String, SkillStrip> _strips;

  /// Skill icons by their `icon` key (`assets/icons/<key>.png`).
  final Map<String, ui.Image> _icons;

  /// The player's sheet per equipped mask id; the empty-string key is the sheet
  /// with the colors as drawn (no mask equipped).
  final Map<String, SpriteSheet> _players;

  SpriteSheet? opponent(String spriteKey) => _opponents[spriteKey];

  SpriteSheet? player(String? maskId) => _players[maskId ?? ''];

  /// The strip of skill animation [name] with the equipped mask's colors.
  SkillStrip? skillStrip(String name, String? maskId) =>
      _strips['$name:${maskId ?? ''}'] ?? _strips['$name:'];

  /// The picture of an icon (skill, trainer, upgrade, talent or mask), or null
  /// (the generic glyph is drawn).
  ui.Image? icon(String key) => _icons[key];

  /// Key of the big (info pop-up) picture of the trainer portrait [portrait].
  static String portraitBigKey(String portrait) => '${portrait}_big';

  /// Key of mask [maskId]'s icon in [icon] (already in the mask's colors).
  static String maskIconKey(String maskId) => 'mask_$maskId';

  /// The arena picture of league [order] for a canvas [virtualWidth] pixels
  /// wide: the 270-wide variant on wide canvases, otherwise the 180 one. Null
  /// when that league has no picture (the arena then draws flat colors).
  ui.Image? arenaBackground(int order, double virtualWidth) =>
      _arenas['arena_${order}_${virtualWidth > _wideCanvas ? 270 : 180}'] ??
      _arenas['arena_${order}_180'];

  /// Canvases wider than this use the 270-pixel picture.
  static const double _wideCanvas = 225;

  bool get isEmpty => _opponents.isEmpty && _players.isEmpty && _arenas.isEmpty;

  /// Loads every sheet the content refers to, plus the player recolored for
  /// each mask. Missing files are skipped (placeholder rectangles stay).
  static Future<SpriteLibrary> load(
    ContentBundle content, {
    AssetBundle? bundle,
  }) async {
    final assets = bundle ?? rootBundle;
    // Ask the asset list first: probing missing files is slow and, in a
    // browser, fills the console with 404 errors.
    Set<String>? listed;
    try {
      listed = (await AssetManifest.loadFromAssetBundle(assets))
          .listAssets()
          .toSet();
    } catch (_) {
      listed = null; // no manifest (tests): fall back to probing
    }
    final animations = content.balance.animations;
    final opponents = <String, SpriteSheet>{};
    for (final o in content.opponents) {
      final bytes = await _readSheet(assets, o.sprite, listed);
      if (bytes == null) continue;
      final sheet = await _decode(bytes, o.size, animations);
      if (sheet != null) opponents[o.sprite] = sheet;
    }
    final players = <String, SpriteSheet>{};
    final raw = await _readSheet(assets, playerSpriteKey, listed);
    if (raw != null) {
      final plain = await _decode(raw, _playerCell, animations);
      if (plain != null) players[''] = plain;
      final rgba = await _rgba(raw);
      if (rgba != null) {
        for (final mask in content.masks) {
          final colors = [for (final id in mask.slotColors) _argb(id)];
          final recolored = recolorMask(rgba.bytes, slotColors: colors);
          final image = await _fromRgba(recolored, rgba.width, rgba.height);
          players[mask.id] = SpriteSheet(
            image: image,
            cell: _playerCell,
            animations: animations,
          );
        }
      }
    }
    final strips = <String, SkillStrip>{};
    for (final entry in animations.skillClips.entries) {
      final strip = await _readSheet(assets, 'player_${entry.key}', listed);
      final rgba = strip == null ? null : await _rgba(strip);
      if (rgba == null) continue;
      final cfg = entry.value;
      Future<void> add(String maskId, Uint8List bytes) async {
        strips['${entry.key}:$maskId'] = SkillStrip(
          image: await _fromRgba(bytes, rgba.width, rgba.height),
          cellWidth: cfg.cellWidth,
          cellHeight: cfg.cellHeight,
          config: cfg,
        );
      }

      if (rgba.width != cfg.cellWidth * cfg.frames ||
          rgba.height != cfg.cellHeight) {
        debugPrint('Skill strip ${entry.key} has the wrong size; skipped.');
        continue;
      }
      await add('', rgba.bytes);
      for (final mask in content.masks) {
        final colors = [for (final id in mask.slotColors) _argb(id)];
        await add(mask.id, recolorMask(rgba.bytes, slotColors: colors));
      }
    }
    // 16 x 16 icon pictures: skills, trainers, upgrades, talents and masks.
    final icons = <String, ui.Image>{};
    Future<Uint8List?> iconFile(String key) async {
      final path = 'assets/icons/$key.png';
      if (listed != null && !listed.contains(path)) return null;
      try {
        final data = await assets.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (_) {
        return null;
      }
    }

    final plainKeys = {
      for (final s in content.skills) s.icon,
      for (final t in content.trainers) t.portrait,
      for (final t in content.trainers) portraitBigKey(t.portrait),
      for (final u in content.upgrades) u.icon,
      for (final t in content.talents) t.icon,
    };
    for (final key in plainKeys) {
      final file = await iconFile(key);
      if (file == null) continue;
      try {
        final codec = await ui.instantiateImageCodec(file);
        icons[key] = (await codec.getNextFrame()).image;
      } catch (_) {}
    }
    // Mask icons are drawn in the three mask tones, then recolored per mask.
    for (final mask in content.masks) {
      final key = maskIconKey(mask.id);
      final file = await iconFile(key);
      final rgba = file == null ? null : await _rgba(file);
      if (rgba == null) continue;
      final colors = [for (final id in mask.slotColors) _argb(id)];
      icons[key] = await _fromRgba(
        recolorMask(rgba.bytes, slotColors: colors),
        rgba.width,
        rgba.height,
      );
    }
    final arenas = <String, ui.Image>{};
    for (final league in content.leagues) {
      for (final width in const [180, 270]) {
        final name = 'arena_${league.order}_$width';
        final path = 'assets/backgrounds/$name.png';
        if (listed != null && !listed.contains(path)) continue;
        try {
          final data = await assets.load(path);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          arenas[name] = (await codec.getNextFrame()).image;
        } catch (_) {
          // No picture for this league: flat colors.
        }
      }
    }
    return SpriteLibrary._(opponents, players, arenas, strips, icons);
  }

  /// Cell size of the player sheet; 48 x 48 by the style guide.
  static const int _playerCell = 48;

  static int _argb(String paletteId) => Palette.byId[paletteId]!;

  static Future<Uint8List?> _readSheet(
    AssetBundle assets,
    String key,
    Set<String>? listed,
  ) async {
    for (final path in [
      'assets/sprites/$key.png',
      'assets/sprites/placeholder/$key.png',
    ]) {
      if (listed != null && !listed.contains(path)) continue;
      try {
        final data = await assets.load(path);
        return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (_) {
        // Not there: try the next place.
      }
    }
    return null;
  }

  static Future<SpriteSheet?> _decode(
    Uint8List png,
    int cell,
    AnimationConfig animations,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final columns = animations.columns;
      // Five required rows, plus the optional ones (kick).
      final rows = image.height ~/ cell;
      if (image.width != cell * columns ||
          image.height != cell * rows ||
          rows < AnimationConfig.requiredClips.length ||
          rows > animations.order.length) {
        debugPrint(
          'Sprite sheet has the wrong size (${image.width}x${image.height}, '
          'expected ${cell * columns} wide and 5 to ${animations.order.length} rows of $cell): '
          'using the placeholder drawing.',
        );
        return null;
      }
      return SpriteSheet(image: image, cell: cell, animations: animations);
    } catch (e) {
      debugPrint('Could not read a sprite sheet: $e');
      return null;
    }
  }

  static Future<({Uint8List bytes, int width, int height})?> _rgba(
    Uint8List png,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return (
        bytes: data.buffer.asUint8List(),
        width: image.width,
        height: image.height,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image> _fromRgba(Uint8List rgba, int w, int h) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: w,
      height: h,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final codec = await descriptor.instantiateCodec();
    return (await codec.getNextFrame()).image;
  }
}
