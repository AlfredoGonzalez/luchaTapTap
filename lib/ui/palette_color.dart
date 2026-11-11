import 'dart:ui';

/// Turns a `Palette` ARGB int into a Flutter [Color]: `Palette.ink.color`.
extension PaletteColor on int {
  Color get color => Color(this);
}
