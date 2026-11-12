import 'dart:typed_data';

import '../core/palette.dart';

/// Swaps the three reserved mask colors (Night Purple = shadow, Violet = base,
/// Lilac = light) in RGBA pixels for a mask's three slot colors. Everything
/// else is untouched. Palette-swapping is done here, once per mask, not per
/// frame.
Uint8List recolorMask(Uint8List rgba, {required List<int> slotColors}) {
  assert(slotColors.length == 3);
  final out = Uint8List.fromList(rgba);
  final from = [Palette.nightPurple, Palette.violet, Palette.lilac];
  for (var i = 0; i + 3 < out.length; i += 4) {
    if (out[i + 3] == 0) continue;
    final packed = (out[i] << 16) | (out[i + 1] << 8) | out[i + 2];
    for (var s = 0; s < 3; s++) {
      if (packed == (from[s] & 0xFFFFFF)) {
        final to = slotColors[s];
        out[i] = (to >> 16) & 0xFF;
        out[i + 1] = (to >> 8) & 0xFF;
        out[i + 2] = to & 0xFF;
        break;
      }
    }
  }
  return out;
}
