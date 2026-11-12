import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/palette.dart';
import 'package:lucha_tap_tap/game/mask_recolor.dart';

Uint8List px(int argb, {int alpha = 255}) =>
    Uint8List.fromList([(argb >> 16) & 255, (argb >> 8) & 255, argb & 255, alpha]);

void main() {
  final slots = [Palette.wine, Palette.luchaRed, Palette.coral];

  test('the three reserved colors become the mask slot colors', () {
    final src = Uint8List.fromList([
      ...px(Palette.nightPurple),
      ...px(Palette.violet),
      ...px(Palette.lilac),
    ]);
    final out = recolorMask(src, slotColors: slots);
    expect(out.sublist(0, 4), px(Palette.wine));
    expect(out.sublist(4, 8), px(Palette.luchaRed));
    expect(out.sublist(8, 12), px(Palette.coral));
  });

  test('other colors and transparent pixels are untouched', () {
    final src = Uint8List.fromList([...px(Palette.skinMid), ...px(Palette.violet, alpha: 0)]);
    final out = recolorMask(src, slotColors: slots);
    expect(out, src);
  });

  test('the source is not modified', () {
    final src = px(Palette.violet);
    recolorMask(src, slotColors: slots);
    expect(src, px(Palette.violet));
  });
}
