import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'tutorial_overlay.dart';

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
            final bottom =
                math.max(
                  config.edgeMargin,
                  controller.tutorialShowing
                      ? config.tutorialBottomMargin
                      : config.bottomMargin,
                ) *
                s;
            final width = math.max(0.0, box.maxWidth - 2 * left);
            final height = math.max(0.0, box.maxHeight - top - bottom);
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
    // Blue and white stand out on the orange burst behind.
    final ring = Palette.white.color;
    final body = (urgent ? Palette.luchaRed : Palette.royal).color;
    for (var j = -reach; j <= reach; j++) {
      for (var i = -reach; i <= reach; i++) {
        final d = math.sqrt(i * i + j * j);
        Color? color;
        if (d <= radius - 3) {
          color = body;
        } else if (d <= radius - 2) {
          color = ring;
        } else if (d <= radius) {
          color = Palette.ink.color; // a thick outline
        }
        if (color == null) continue;
        // A small highlight at the top left of the body.
        if (d <= radius - 3 && i < 0 && j < 0 && d > radius * 0.35 && d < radius * 0.6) {
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


/// The whole screen while the kick is on: a comic burst behind, the prompt
/// at the top and the circles anywhere. Taps outside the circles do nothing.
class KickScreen extends ConsumerWidget {
  const KickScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    if (!engine.finisherReady || engine.awaitingBossStart) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: TutorialTarget(
        id: 'kickScreen',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: const Stack(
            children: [
              Positioned.fill(child: _Burst()),
              KickCircles(),
              KickPrompt(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Comic-book rays from the middle of the screen in palette colors, with a
/// halftone of dots, built once per screen size at virtual resolution and
/// drawn with whole-pixel scaling.
class _Burst extends StatefulWidget {
  const _Burst();

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> {
  static final Map<String, ui.Image> _cache = {};
  ui.Image? _image;
  String? _key;

  void _build(int w, int h) {
    final key = '${w}x$h';
    if (_key == key) return;
    _key = key;
    final cached = _cache[key];
    if (cached != null) {
      _image = cached;
      return;
    }
    final bytes = Uint8List(w * h * 4);
    const rays = 22;
    final cx = w / 2, cy = h * 0.45;
    final maxR = math.sqrt(cx * cx + cy * cy);
    // Each ray a little wider or narrower, the same every time.
    final widths = [for (var i = 0; i < rays; i++) 0.6 + ((i * 37) % 9) / 10];
    final total = widths.reduce((a, b) => a + b);
    final edges = <double>[];
    var acc = 0.0;
    for (final wd in widths) {
      acc += wd / total * 2 * math.pi;
      edges.add(acc);
    }
    const light = Palette.sand, dark = Palette.burntOrange;
    const dots = Palette.marigold, glow = Palette.sunYellow, rim = Palette.coral;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final dx = x - cx, dy = y - cy;
        final r = math.sqrt(dx * dx + dy * dy) / maxR;
        var a = math.atan2(dy, dx);
        if (a < 0) a += 2 * math.pi;
        var ray = 0;
        while (ray < rays - 1 && a > edges[ray]) {
          ray++;
        }
        int c;
        if (r < 0.1) {
          c = glow;
        } else if (ray.isEven) {
          // Light rays get a sparse dot pattern near the middle.
          c = (r < 0.45 && x % 4 == 0 && y % 4 == 0) ? glow : light;
        } else {
          // Dark rays: dots that grow denser toward the edge.
          final step = r > 0.7 ? 2 : (r > 0.4 ? 3 : 4);
          c = (x % step == 0 && y % step == 0) ? dots : (r > 0.85 ? rim : dark);
        }
        final o = (y * w + x) * 4;
        bytes[o] = (c >> 16) & 0xFF;
        bytes[o + 1] = (c >> 8) & 0xFF;
        bytes[o + 2] = c & 0xFF;
        bytes[o + 3] = 0xFF;
      }
    }
    ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, (img) {
      _cache[key] = img;
      if (mounted && _key == key) setState(() => _image = img);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth / scale.scale).ceil();
        final h = (box.maxHeight / scale.scale).ceil();
        if (w > 0 && h > 0) _build(w, h);
        final image = _image;
        if (image == null) return ColoredBox(color: Palette.burntOrange.color);
        return CustomPaint(painter: _ImagePainter(image));
      },
    );
  }
}

class _ImagePainter extends CustomPainter {
  _ImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none,
  );

  @override
  bool shouldRepaint(_ImagePainter old) => old.image != image;
}
