import 'dart:ui';

import '../core/palette.dart';
import '../ui/palette_color.dart';

/// Placeholder wrestler drawn with rectangles: body block, head block and a
/// 1-pixel Ink outline. Used by the arena and by the boss intro, so final art
/// replaces both in one place.
void paintFighter(
  Canvas canvas,
  Size size, {
  required int bodyColor,
  required int accentColor,
  bool flashing = false,
}) {
  final paint = Paint()..isAntiAlias = false;
  final w = size.width;
  final h = size.height;
  final headSize = (w * 0.42).roundToDouble();
  final bodyTop = headSize - 2;

  void block(Rect rect, int color) {
    canvas.drawRect(rect, paint..color = Palette.ink.color);
    canvas.drawRect(
      rect.deflate(1),
      paint..color = (flashing ? Palette.white : color).color,
    );
  }

  // Legs, torso, head (the head uses the accent color: the mask).
  block(Rect.fromLTWH(w * 0.22, h * 0.72, w * 0.22, h * 0.28), bodyColor);
  block(Rect.fromLTWH(w * 0.56, h * 0.72, w * 0.22, h * 0.28), bodyColor);
  block(
    Rect.fromLTWH(w * 0.16, bodyTop, w * 0.68, h * 0.72 - bodyTop),
    bodyColor,
  );
  block(Rect.fromLTWH((w - headSize) / 2, 0, headSize, headSize), accentColor);
}
