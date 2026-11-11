import 'package:flutter/widgets.dart';

import 'pixel_icons.dart';
import 'pixel_scale.dart';

/// Draws a pixel icon at a whole number of screen pixels per icon pixel.
///
/// Monochrome icons take [color]; [recolor] swaps palette colors (masks use it
/// to turn their three reserved colors into the mask's own slot colors).
class PixelIcon extends StatelessWidget {
  const PixelIcon(
    this.data, {
    super.key,
    this.color,
    this.recolor = const {},
    this.size,
  });

  final PixelIconData data;
  final Color? color;
  final Map<int, int> recolor;

  /// Size in virtual pixels per side; defaults to the icon's own grid.
  final int? size;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final cell = (size ?? data.width) / data.width;
    return CustomPaint(
      size: Size(scale.px(data.width * cell), scale.px(data.height * cell)),
      painter: _IconPainter(data, color, recolor, scale.px(cell)),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.data, this.color, this.recolor, this.cell);

  final PixelIconData data;
  final Color? color;
  final Map<int, int> recolor;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final r = data.rects;
    for (var i = 0; i < r.length; i += 5) {
      final argb = r[i + 4];
      paint.color = argb == PixelIconData.mono
          ? (color ?? const Color(0xFFFFFFFF))
          : Color(recolor[argb] ?? argb);
      canvas.drawRect(
        Rect.fromLTWH(
          r[i] * cell,
          r[i + 1] * cell,
          r[i + 2] * cell,
          r[i + 3] * cell,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.data != data ||
      old.color != color ||
      old.cell != cell ||
      old.recolor != recolor;
}
