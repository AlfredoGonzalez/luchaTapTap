import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';

/// Base size of the virtual canvas in pixels (Visual Style Guide): 180 wide
/// and at least 320 tall, portrait.
const int baseVirtualWidth = 180;
const int baseVirtualHeight = 320;

/// How the game fits a window: every virtual pixel is a square of a whole
/// number of *device* pixels, and the canvas grows (up to the limits in
/// balance.json) to use the rest of the window, so nothing is stretched or
/// blurred and little space is wasted.
class PixelLayout {
  const PixelLayout({
    required this.pixelsPerVirtual,
    required this.virtualWidth,
    required this.virtualHeight,
    required this.offsetX,
    required this.offsetY,
    required this.devicePixelRatio,
  });

  /// Device pixels per virtual pixel (a whole number, at least 1).
  final int pixelsPerVirtual;

  /// Size of the canvas in virtual pixels.
  final int virtualWidth;
  final int virtualHeight;

  /// Border left around the canvas, in logical pixels (whole device pixels).
  final double offsetX;
  final double offsetY;
  final double devicePixelRatio;

  /// Logical pixels of one virtual pixel (`pixelsPerVirtual / devicePixelRatio`).
  double get scale => pixelsPerVirtual / devicePixelRatio;

  /// Logical size of the canvas.
  Size get size => Size(virtualWidth * scale, virtualHeight * scale);

  /// Works out the layout for a window of [width] x [height] logical pixels.
  factory PixelLayout.compute({
    required double width,
    required double height,
    required double devicePixelRatio,
    required int maxVirtualWidth,
    required int maxVirtualHeight,
  }) {
    // Small epsilon: 360.0 * 3.0 must not become 1079.9999.
    final deviceW = (width * devicePixelRatio + 1e-6).floor();
    final deviceH = (height * devicePixelRatio + 1e-6).floor();
    final k = math.max(1, math.min(deviceW ~/ baseVirtualWidth, deviceH ~/ baseVirtualHeight));
    final vw = math.max(baseVirtualWidth, math.min(maxVirtualWidth, deviceW ~/ k));
    final vh = math.max(baseVirtualHeight, math.min(maxVirtualHeight, deviceH ~/ k));
    return PixelLayout(
      pixelsPerVirtual: k,
      virtualWidth: vw,
      virtualHeight: vh,
      offsetX: math.max(0, (deviceW - vw * k) ~/ 2) / devicePixelRatio,
      offsetY: math.max(0, (deviceH - vh * k) ~/ 2) / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }
}

/// Size of one virtual pixel on screen, and of the canvas, for the widgets
/// below it.
class PixelScale extends InheritedWidget {
  const PixelScale({
    super.key,
    required this.scale,
    required this.virtualWidth,
    required this.virtualHeight,
    required super.child,
  });

  /// Logical pixels per virtual pixel.
  final double scale;
  final int virtualWidth;
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
      scale != oldWidget.scale ||
      virtualWidth != oldWidget.virtualWidth ||
      virtualHeight != oldWidget.virtualHeight;
}

/// Fits the game into the window (see [PixelLayout]) and fills the leftover
/// border with Ink.
class PixelCanvas extends ConsumerWidget {
  const PixelCanvas({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(contentProvider).balance.ui;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ColoredBox(
      color: Palette.ink.color,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = PixelLayout.compute(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            devicePixelRatio: dpr,
            maxVirtualWidth: ui.maxVirtualWidth,
            maxVirtualHeight: ui.maxVirtualHeight,
          );
          return Padding(
            padding: EdgeInsets.only(left: layout.offsetX, top: layout.offsetY),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: layout.size.width,
                height: layout.size.height,
                child: PixelScale(
                  scale: layout.scale,
                  virtualWidth: layout.virtualWidth,
                  virtualHeight: layout.virtualHeight,
                  child: Builder(builder: builder),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
