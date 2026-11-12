import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'pixel_scale.dart';

/// A full-color 16 x 16 icon picture (`assets/icons/<key>.png`), drawn crisp at
/// a whole number of device pixels per icon pixel.
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.image, {super.key, this.size = 16});

  final ui.Image image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final side = PixelScale.of(context).px(size);
    return CustomPaint(size: Size(side, side), painter: _ArtIconPainter(image));
  }
}

class _ArtIconPainter extends CustomPainter {
  _ArtIconPainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Offset.zero & size,
    Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none,
  );

  @override
  bool shouldRepaint(_ArtIconPainter old) => old.image != image;
}
