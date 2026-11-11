/// The 32-color master palette (Visual Style Guide v0). Defined once here and
/// used by name everywhere. No other color may appear in code or assets.
///
/// Values are ARGB ints so this file stays free of Flutter imports; the UI
/// turns them into `Color` with the extension in `ui/palette_color.dart`.
abstract final class Palette {
  static const int ink = 0xFF1B1230;
  static const int nightPurple = 0xFF2E1F4A;
  static const int slate = 0xFF4A3B6B;
  static const int dust = 0xFF7C7396;
  static const int fog = 0xFFB8B2CC;
  static const int bone = 0xFFF6F0E4;
  static const int white = 0xFFFFFFFF;
  static const int wine = 0xFF5E1230;
  static const int luchaRed = 0xFFC8283A;
  static const int coral = 0xFFF2545B;
  static const int pink = 0xFFFF8FB1;
  static const int blush = 0xFFFFD0DC;
  static const int chocolate = 0xFF4B2A1E;
  static const int skinDeep = 0xFF8F5A3C;
  static const int skinMid = 0xFFD9915E;
  static const int skinLight = 0xFFF7C9A0;
  static const int sand = 0xFFE8D3A2;
  static const int burntOrange = 0xFFE2661B;
  static const int marigold = 0xFFFFB627;
  static const int sunYellow = 0xFFFFE066;
  static const int forest = 0xFF1F5A3A;
  static const int nopal = 0xFF2E9E5B;
  static const int lime = 0xFF8FD14F;
  static const int mint = 0xFFC5F0A4;
  static const int navy = 0xFF1D2F6F;
  static const int royal = 0xFF2F5BEA;
  static const int sky = 0xFF5BB8FF;
  static const int teal = 0xFF1FA6A0;
  static const int aqua = 0xFF8FF0E0;
  static const int violet = 0xFF7A3FD1;
  static const int lilac = 0xFFB993F5;
  static const int magenta = 0xFFD12FA0;

  /// Lookup by snake_case id, as used in the JSON data files.
  static const Map<String, int> byId = {
    'ink': ink,
    'night_purple': nightPurple,
    'slate': slate,
    'dust': dust,
    'fog': fog,
    'bone': bone,
    'white': white,
    'wine': wine,
    'lucha_red': luchaRed,
    'coral': coral,
    'pink': pink,
    'blush': blush,
    'chocolate': chocolate,
    'skin_deep': skinDeep,
    'skin_mid': skinMid,
    'skin_light': skinLight,
    'sand': sand,
    'burnt_orange': burntOrange,
    'marigold': marigold,
    'sun_yellow': sunYellow,
    'forest': forest,
    'nopal': nopal,
    'lime': lime,
    'mint': mint,
    'navy': navy,
    'royal': royal,
    'sky': sky,
    'teal': teal,
    'aqua': aqua,
    'violet': violet,
    'lilac': lilac,
    'magenta': magenta,
  };

  /// Colors reserved for masks (runtime palette swap). Characters other than
  /// the mask itself must never use them.
  static const Set<String> maskReservedIds = {
    'night_purple',
    'violet',
    'lilac',
  };
}
