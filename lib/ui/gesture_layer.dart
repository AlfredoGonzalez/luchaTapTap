import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

/// Watches the fingers over the arena and feeds the finisher gesture. It only
/// observes: taps still reach the arena, so short touches keep fighting.
class FinisherGestureLayer extends ConsumerWidget {
  const FinisherGestureLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context).scale;
    final controller = ref.read(gameControllerProvider.notifier);
    return Listener(
      behavior: HitTestBehavior.translucent,
      // Positions are turned into virtual pixels, which the recognizer uses.
      onPointerDown: (e) =>
          controller.gesturePointerDown(e.localPosition.dx / scale, e.localPosition.dy / scale),
      onPointerMove: (e) =>
          controller.gesturePointerMove(e.localPosition.dx / scale, e.localPosition.dy / scale),
      onPointerUp: (_) => controller.gesturePointerUp(),
      onPointerCancel: (_) => controller.gesturePointerUp(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: ValueListenableBuilder<List<Offset>>(
              valueListenable: controller.gestureTrail,
              builder: (context, points, _) =>
                  CustomPaint(painter: _TrailPainter(points, scale)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The drawn path as 2 x 2 virtual-pixel dots.
class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points, this.scale);

  final List<Offset> points;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = Palette.sunYellow.color;
    for (final p in points) {
      final x = (p.dx.floor() - 1) * scale;
      final y = (p.dy.floor() - 1) * scale;
      canvas.drawRect(Rect.fromLTWH(x, y, 2 * scale, 2 * scale), paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => true;
}

/// Shown while the combo is full: two circular arrows, in the order and
/// direction to draw them, and "¡DIBUJA!".
class FinisherPrompt extends ConsumerWidget {
  const FinisherPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    if (!controller.engine.finisherReady || controller.engine.awaitingBossStart) {
      return const SizedBox.shrink();
    }
    final strings = ref.watch(stringsProvider);
    final firstClockwise = ref.watch(contentProvider).balance.gesture.firstClockwise;
    return Positioned(
      top: scale.px(22),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.ink.color,
              border: Border.all(color: Palette.slate.color, width: scale.px(1)),
            ),
            child: Padding(
              padding: EdgeInsets.all(scale.px(3)),
              child: ValueListenableBuilder<int>(
                valueListenable: controller.gestureCircles,
                builder: (context, done, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Ring(clockwise: firstClockwise, done: done >= 1),
                    SizedBox(width: scale.px(2)),
                    _Ring(clockwise: !firstClockwise, done: done >= 2),
                    SizedBox(width: scale.px(4)),
                    PixelText(strings.t('gesture_prompt'), color: Palette.sunYellow.color),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.clockwise, required this.done});

  final bool clockwise;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return CustomPaint(
      size: Size(scale.px(16), scale.px(16)),
      painter: _RingPainter(
        clockwise: clockwise,
        color: (done ? Palette.nopal : Palette.bone).color,
        cell: scale.scale,
      ),
    );
  }
}

/// A 16 x 16 pixel ring with an arrowhead at the top showing the direction.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.clockwise, required this.color, required this.cell});

  final bool clockwise;
  final Color color;
  final double cell;

  static const int _grid = 16;
  static const double _radius = 6;
  static const double _thickness = 0.8;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = color;
    for (var i = 0; i < _grid; i++) {
      for (var j = 0; j < _grid; j++) {
        final dx = i + 0.5 - _grid / 2;
        final dy = j + 0.5 - _grid / 2;
        final d = (dx * dx + dy * dy);
        if ((d - _radius * _radius).abs() <= _radius * 2 * _thickness) {
          canvas.drawRect(Rect.fromLTWH(i * cell, j * cell, cell, cell), paint);
        }
      }
    }
    // Arrowhead at the top: pointing right for clockwise, left otherwise.
    final head = clockwise
        ? const [(10, 0, 1, 5), (11, 1, 1, 3), (12, 2, 1, 1)]
        : const [(5, 0, 1, 5), (4, 1, 1, 3), (3, 2, 1, 1)];
    for (final (x, y, w, h) in head) {
      canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, w * cell, h * cell), paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.clockwise != clockwise || old.color != color || old.cell != cell;
}
