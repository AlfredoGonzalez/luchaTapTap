import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

/// The kick's circles over the arena: one at a time, at a random place, each
/// shrinking until it vanishes. Tapping it counts for the kick and does not
/// reach the arena (the layer is opaque only where the circle is).
class KickCircles extends ConsumerWidget {
  const KickCircles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pixel = PixelScale.of(context);
    final controller = ref.read(gameControllerProvider.notifier);
    final config = ref.watch(contentProvider).balance.kick;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) => ValueListenableBuilder<KickView?>(
          valueListenable: controller.kickView,
          builder: (context, view, _) {
            if (view == null) return const SizedBox.shrink();
            final s = pixel.scale;
            final left = config.edgeMargin * s;
            final top = config.topMargin * s;
            final width = math.max(0.0, box.maxWidth - 2 * left);
            final height = math.max(0.0, box.maxHeight - top - left);
            // Whole virtual pixels, so the circle sits on the pixel grid.
            final cx = (left + view.x * width) / s;
            final cy = (top + view.y * height) / s;
            final radius = config.circleRadius * view.remaining;
            final hit = math.max(2 * radius, config.minHitSize);
            return Stack(
              children: [
                Positioned(
                  left: (cx.floorToDouble() - hit / 2).floorToDouble() * s,
                  top: (cy.floorToDouble() - hit / 2).floorToDouble() * s,
                  width: hit.ceilToDouble() * s,
                  height: hit.ceilToDouble() * s,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (_) => controller.kickCircleTapped(),
                    child: CustomPaint(
                      painter: _CirclePainter(
                        radius: radius,
                        cell: s,
                        urgent: view.remaining < 0.35,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A disc drawn in whole virtual pixels: Ink outline, a bright ring, a filled
/// body and a highlight. It turns red when little time is left.
class _CirclePainter extends CustomPainter {
  _CirclePainter({
    required this.radius,
    required this.cell,
    required this.urgent,
  });

  final double radius;
  final double cell;
  final bool urgent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final cx = size.width / 2 / cell;
    final cy = size.height / 2 / cell;
    final reach = radius.ceil() + 1;
    final ring = (urgent ? Palette.luchaRed : Palette.sunYellow).color;
    final body = (urgent ? Palette.coral : Palette.marigold).color;
    for (var j = -reach; j <= reach; j++) {
      for (var i = -reach; i <= reach; i++) {
        final d = math.sqrt(i * i + j * j);
        Color? color;
        if (d <= radius - 2) {
          color = body;
        } else if (d <= radius - 1) {
          color = ring;
        } else if (d <= radius) {
          color = Palette.ink.color;
        }
        if (color == null) continue;
        // A small highlight at the top left of the body.
        if (d <= radius - 2 && i < 0 && j < 0 && d > radius * 0.35 && d < radius * 0.6) {
          color = Palette.bone.color;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            (cx + i - 0.5).floorToDouble() * cell,
            (cy + j - 0.5).floorToDouble() * cell,
            cell,
            cell,
          ),
          paint..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.radius != radius || old.cell != cell || old.urgent != urgent;
}

/// Shown while the combo bar is full: one square per circle (green when
/// tapped) and "¡PATADA!". It is not a button.
class KickPrompt extends ConsumerWidget {
  const KickPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    if (!controller.engine.finisherReady ||
        controller.engine.awaitingBossStart) {
      return const SizedBox.shrink();
    }
    final strings = ref.watch(stringsProvider);
    final targets = ref.watch(contentProvider).balance.kick.targets;
    return Positioned(
      top: scale.px(22),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.ink.color,
              border: Border.all(
                color: Palette.slate.color,
                width: scale.px(1),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(scale.px(3)),
              child: ValueListenableBuilder<int>(
                valueListenable: controller.kickHits,
                builder: (context, done, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < targets; i++) ...[
                      SizedBox(
                        width: scale.px(6),
                        height: scale.px(6),
                        child: ColoredBox(
                          color: (i < done ? Palette.nopal : Palette.dust)
                              .color,
                        ),
                      ),
                      SizedBox(width: scale.px(2)),
                    ],
                    SizedBox(width: scale.px(2)),
                    PixelText(
                      strings.t('kick_prompt'),
                      color: Palette.sunYellow.color,
                    ),
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
