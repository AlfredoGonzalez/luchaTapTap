import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/palette.dart';
import 'palette_color.dart';

/// Virtual canvas width in pixels (Visual Style Guide: 180 x 320, portrait).
const int virtualWidth = 180;
const int virtualMinHeight = 320;

/// Tall phones grow the canvas up to this height; the extra space goes to the
/// arena, never to stretching.
const int virtualMaxHeight = 390;

/// Size of one virtual pixel on screen, always a whole number of logical
/// pixels so every virtual pixel stays a sharp square.
class PixelScale extends InheritedWidget {
  const PixelScale({
    super.key,
    required this.scale,
    required this.virtualHeight,
    required super.child,
  });

  final int scale;
  final int virtualHeight;

  /// Logical pixels for [virtualPixels].
  double px(num virtualPixels) => (virtualPixels * scale).toDouble();

  static PixelScale of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<PixelScale>();
    assert(result != null, 'No PixelScale above this widget');
    return result!;
  }

  @override
  bool updateShouldNotify(PixelScale oldWidget) =>
      scale != oldWidget.scale || virtualHeight != oldWidget.virtualHeight;
}

/// Fits the game into the screen at an integer scale and fills the leftover
/// border with Ink.
class PixelCanvas extends StatelessWidget {
  const PixelCanvas({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.ink.color,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final byWidth = constraints.maxWidth ~/ virtualWidth;
          final byHeight = constraints.maxHeight ~/ virtualMinHeight;
          final scale = math.max(1, math.min(byWidth, byHeight));
          final height = math.min(
            virtualMaxHeight,
            math.max(virtualMinHeight, constraints.maxHeight ~/ scale),
          );
          return Center(
            child: SizedBox(
              width: (virtualWidth * scale).toDouble(),
              height: (height * scale).toDouble(),
              child: PixelScale(
                scale: scale,
                virtualHeight: height,
                child: Builder(builder: builder),
              ),
            ),
          );
        },
      ),
    );
  }
}
