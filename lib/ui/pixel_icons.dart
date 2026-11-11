// GENERATED from the UI mockups' pixel icons. Shapes are lists of
// `x, y, w, h, color` rectangles on a small grid. Icons that can be tinted
// (navigation, skills, talents...) use [PixelIconData.mono] for their main
// color, so the screen decides it (state colors); small details keep their
// own palette color. Colors are palette names.
import '../core/palette.dart';

class PixelIconData {
  const PixelIconData(this.width, this.height, this.rects);

  final int width;
  final int height;

  /// Flat list of `x, y, w, h, argb` (argb is [mono] for the drawing color).
  final List<int> rects;

  /// Marker for "use the drawing color".
  static const int mono = -1;
}

const int _m = PixelIconData.mono;

abstract final class PixelIcons {
  static const coin = PixelIconData(8, 8, [
    2, 0, 4, 8, Palette.ink, 1, 1, 6, 6, Palette.ink,
    0, 2, 8, 4, Palette.ink, 2, 1, 4, 6, Palette.marigold,
    1, 2, 6, 4, Palette.marigold, 2, 2, 2, 1, Palette.sunYellow,
  ]);
  static const belt = PixelIconData(8, 8, [
    3, 0, 2, 1, Palette.ink, 2, 1, 4, 1, Palette.ink,
    1, 2, 6, 1, Palette.ink, 0, 3, 8, 2, Palette.ink,
    1, 5, 6, 1, Palette.ink, 2, 6, 4, 1, Palette.ink,
    3, 7, 2, 1, Palette.ink, 3, 1, 2, 1, Palette.aqua,
    2, 2, 4, 1, Palette.aqua, 1, 3, 6, 2, Palette.teal,
    2, 5, 4, 1, Palette.teal, 3, 6, 2, 1, Palette.teal,
    2, 2, 1, 1, Palette.white,
  ]);
  static const gear = PixelIconData(16, 16, [
    4, 2, 8, 12, _m, 2, 4, 12, 8, _m,
    7, 0, 2, 2, _m, 7, 14, 2, 2, _m,
    0, 7, 2, 2, _m, 14, 7, 2, 2, _m,
    6, 6, 4, 4, Palette.nightPurple,
  ]);
  static const skillBolt = PixelIconData(16, 16, [
    8, 1, 4, 2, _m, 7, 3, 4, 2, _m,
    5, 5, 6, 2, _m, 7, 7, 4, 2, _m,
    6, 9, 3, 2, _m, 5, 11, 3, 2, _m,
    4, 13, 2, 2, _m,
  ]);
  static const skillCoins = PixelIconData(16, 16, [
    5, 1, 6, 14, Palette.marigold, 3, 3, 10, 10, Palette.marigold,
    2, 5, 12, 6, Palette.marigold, 6, 4, 4, 8, Palette.sunYellow,
  ]);
  static const skillAuto = PixelIconData(16, 16, [
    7, 2, 2, 2, _m, 6, 4, 4, 2, _m,
    5, 6, 6, 2, _m, 7, 8, 2, 6, _m,
  ]);
  static const skillStar = PixelIconData(16, 16, [
    7, 1, 2, 3, _m, 5, 4, 6, 3, _m,
    1, 6, 14, 3, _m, 3, 9, 10, 3, _m,
    2, 12, 4, 3, _m, 10, 12, 4, 3, _m,
  ]);
  static const skillShout = PixelIconData(16, 16, [
    6, 2, 4, 2, _m, 4, 4, 8, 2, _m,
    2, 6, 12, 2, _m, 4, 8, 8, 2, _m,
    6, 10, 4, 2, _m, 7, 12, 2, 2, _m,
  ]);
  static const upgradeFist = PixelIconData(16, 16, [
    3, 3, 10, 10, Palette.luchaRed, 3, 3, 10, 2, Palette.coral,
    5, 6, 6, 5, Palette.skinLight, 2, 12, 12, 2, Palette.wine,
  ]);
  static const trainer = PixelIconData(16, 16, [
    4, 2, 8, 3, Palette.royal, 3, 5, 10, 7, Palette.skinDeep,
    5, 7, 2, 2, Palette.ink, 9, 7, 2, 2, Palette.ink,
    5, 10, 6, 1, Palette.ink,
  ]);
  static const navUpgrades = PixelIconData(16, 16, [
    7, 2, 2, 2, _m, 6, 4, 4, 2, _m,
    5, 6, 6, 2, _m, 7, 8, 2, 6, _m,
  ]);
  static const navSkills = PixelIconData(16, 16, [
    8, 1, 4, 2, _m, 7, 3, 4, 2, _m,
    5, 5, 6, 2, _m, 7, 7, 4, 2, _m,
    6, 9, 3, 2, _m, 5, 11, 3, 2, _m,
    4, 13, 2, 2, _m,
  ]);
  static const navMasks = PixelIconData(16, 16, [
    3, 4, 10, 8, _m, 5, 12, 6, 1, _m,
    4, 6, 3, 2, Palette.ink, 9, 6, 3, 2, Palette.ink,
  ]);
  static const navTalents = PixelIconData(16, 16, [
    7, 1, 2, 3, _m, 5, 4, 6, 3, _m,
    1, 6, 14, 3, _m, 3, 9, 10, 3, _m,
    2, 12, 4, 3, _m, 10, 12, 4, 3, _m,
  ]);
  static const navShop = PixelIconData(16, 16, [
    6, 2, 4, 2, _m, 4, 4, 8, 2, _m,
    2, 6, 12, 2, _m, 4, 8, 8, 2, _m,
    6, 10, 4, 2, _m, 7, 12, 2, 2, _m,
  ]);
  static const maskJaguar = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.skinMid,
    4, 3, 8, 1, Palette.skinMid, 3, 4, 10, 2, Palette.blush,
    4, 12, 8, 1, Palette.skinDeep, 3, 11, 10, 1, Palette.skinDeep,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.skinDeep,
  ]);
  static const maskBull = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.luchaRed,
    4, 3, 8, 1, Palette.luchaRed, 3, 4, 10, 2, Palette.coral,
    4, 12, 8, 1, Palette.wine, 3, 11, 10, 1, Palette.wine,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.wine,
  ]);
  static const maskBolt = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.royal,
    4, 3, 8, 1, Palette.royal, 3, 4, 10, 2, Palette.sky,
    4, 12, 8, 1, Palette.navy, 3, 11, 10, 1, Palette.navy,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.navy,
  ]);
  static const maskWolf = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.dust,
    4, 3, 8, 1, Palette.dust, 3, 4, 10, 2, Palette.fog,
    4, 12, 8, 1, Palette.slate, 3, 11, 10, 1, Palette.slate,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.slate,
  ]);
  static const maskLocked = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.slate,
    4, 3, 8, 1, Palette.slate, 3, 4, 10, 2, Palette.dust,
    4, 12, 8, 1, Palette.nightPurple, 3, 11, 10, 1, Palette.nightPurple,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.nightPurple,
  ]);
  static const adWatch = PixelIconData(8, 8, [
    1, 0, 2, 8, _m, 3, 1, 2, 6, _m,
    5, 2, 1, 4, _m,
  ]);
  static const shopRest = PixelIconData(16, 16, [
    8, 1, 4, 2, _m, 7, 3, 4, 2, _m,
    5, 5, 6, 2, _m, 7, 7, 4, 2, _m,
    6, 9, 3, 2, _m, 5, 11, 3, 2, _m,
    4, 13, 2, 2, _m,
  ]);
  static const shopDouble = PixelIconData(16, 16, [
    6, 2, 4, 2, _m, 4, 4, 8, 2, _m,
    2, 6, 12, 2, _m, 4, 8, 8, 2, _m,
    6, 10, 4, 2, _m, 7, 12, 2, 2, _m,
  ]);
  static const shopTimer = PixelIconData(16, 16, [
    7, 2, 2, 2, _m, 6, 4, 4, 2, _m,
    5, 6, 6, 2, _m, 7, 8, 2, 6, _m,
  ]);
  static const talentThrift = PixelIconData(16, 16, [
    3, 4, 10, 8, _m, 5, 12, 6, 1, _m,
    4, 6, 3, 2, _m, 9, 6, 3, 2, _m,
  ]);
  static const talentBelt = PixelIconData(16, 16, [
    7, 1, 2, 3, _m, 5, 4, 6, 3, _m,
    1, 6, 14, 3, _m, 3, 9, 10, 3, _m,
    2, 12, 4, 3, _m, 10, 12, 4, 3, _m,
  ]);
  static const talentNap = PixelIconData(16, 16, [
    7, 1, 2, 3, _m, 5, 4, 6, 3, _m,
    1, 6, 14, 3, _m, 3, 9, 10, 3, _m,
    2, 12, 4, 3, _m, 10, 12, 4, 3, _m,
  ]);
  static const locked = PixelIconData(16, 16, [
    5, 2, 6, 1, _m, 4, 3, 2, 5, _m,
    10, 3, 2, 5, _m, 3, 7, 10, 8, _m,
    7, 10, 2, 3, Palette.ink,
  ]);
  static const logoMask = PixelIconData(16, 16, [
    4, 2, 8, 1, Palette.ink, 3, 3, 10, 1, Palette.ink,
    2, 4, 12, 8, Palette.ink, 3, 12, 10, 1, Palette.ink,
    5, 13, 6, 1, Palette.ink, 3, 4, 10, 8, Palette.marigold,
    4, 3, 8, 1, Palette.marigold, 3, 4, 10, 2, Palette.sunYellow,
    4, 12, 8, 1, Palette.burntOrange, 3, 11, 10, 1, Palette.burntOrange,
    4, 6, 3, 3, Palette.ink, 9, 6, 3, 3, Palette.ink,
    5, 7, 1, 1, Palette.bone, 10, 7, 1, 1, Palette.bone,
    7, 10, 2, 1, Palette.burntOrange,
  ]);

  /// Icon for a data-file `icon` key (opponents, skills, upgrades, ...);
  /// null when the game has no art for it yet.
  static PixelIconData? byKey(String key) => _byKey[key];

  static const Map<String, PixelIconData> _byKey = {
    'up_puno_duro': upgradeFist,
    'up_golpe_certero': skillStar,
    'tr_don_chuy': trainer,
    'tr_chema_pesas': upgradeFist,
    'sk_plancha': skillBolt,
    'sk_furia': skillStar,
    'sk_suerte': skillCoins,
    'sk_grito': skillShout,
    'sk_llave': skillAuto,
    'tl_punos': upgradeFist,
    'tl_critico': skillStar,
    'tl_entrenamiento': trainer,
    'tl_siesta': talentNap,
    'tl_cartera': talentBelt,
    'tl_racha': skillCoins,
    'tl_ahorrito': talentThrift,
    'tl_descanso': talentThrift,
    'shop_rest': shopRest,
    'shop_double': shopDouble,
    'shop_timer': shopTimer,
    'belt': belt,
    'coin': coin,
    'mask_jaguar': maskJaguar,
    'mask_bull': maskBull,
    'mask_bolt': maskBolt,
    'mask_wolf': maskWolf,
  };
}
