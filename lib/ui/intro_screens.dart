import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import '../app_info.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

Duration _seconds(double s) =>
    Duration(microseconds: (s * Duration.microsecondsPerSecond).round());

/// Studio splash: "AM Studios Play presenta". Tap to skip.
///
/// Placeholder until the studio video is ready; the video replaces the
/// emblem and name here.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final seconds = ref.read(contentProvider).balance.ui.splashSeconds;
    _timer = Timer(_seconds(seconds), _next);
  }

  void _next() {
    if (mounted) ref.read(appStageProvider.notifier).show(AppStage.loading);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: ColoredBox(
        color: Palette.ink.color,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelIcon(PixelIcons.logoMask, size: 32),
              SizedBox(height: scale.px(12)),
              PixelText(
                strings.t('studio_name'),
                color: Palette.sunYellow.color,
                align: TextAlign.center,
              ),
              SizedBox(height: scale.px(6)),
              PixelText(
                strings.t('studio_presents'),
                color: Palette.fog.color,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading screen: logo, a progress bar and then a blinking "Toca para
/// continuar" (a tap is needed to start, so audio can begin on a user gesture).
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  static const Duration _step = Duration(milliseconds: 50);

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _blinkOn = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      if (!mounted) return;
      final ui = ref.read(contentProvider).balance.ui;
      setState(() {
        _elapsed += _step;
        if (_ready) {
          final since = _elapsed - _seconds(ui.loadingSeconds);
          _blinkOn =
              (since.inMicroseconds ~/ _seconds(ui.blinkSeconds).inMicroseconds)
                  .isEven;
        }
      });
    });
  }

  bool get _ready =>
      _elapsed >= _seconds(ref.read(contentProvider).balance.ui.loadingSeconds);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final total = _seconds(
      ref.watch(contentProvider).balance.ui.loadingSeconds,
    );
    final fraction = total == Duration.zero
        ? 1.0
        : (_elapsed.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _ready
          ? () => ref.read(appStageProvider.notifier).show(AppStage.game)
          : null,
      child: Stack(
        children: [
          CustomPaint(
            painter: _LoadingStripes(scale.scale),
            size: Size.infinite,
          ),
          Positioned.fill(
            child: Column(
            children: [
              SizedBox(height: scale.px(46)),
              const PixelIcon(PixelIcons.logoMask, size: 64),
              SizedBox(height: scale.px(10)),
              PixelText(
                strings.t('title_lucha'),
                size: 24,
                color: Palette.sunYellow.color,
                shadow: Palette.ink.color,
              ),
              SizedBox(height: scale.px(6)),
              PixelText(
                strings.t('title_tap'),
                size: 16,
                color: Palette.bone.color,
                shadow: Palette.luchaRed.color,
              ),
              const Spacer(),
              SizedBox(
                width: scale.px(140),
                child: PixelBar(
                  fraction: fraction,
                  fill: Palette.marigold,
                  track: Palette.ink,
                  height: 12,
                ),
              ),
              SizedBox(height: scale.px(10)),
              SizedBox(
                height: scale.px(8),
                child: _ready && _blinkOn
                    ? PixelText(
                        strings.t('loading_tap'),
                        shadow: Palette.ink.color,
                      )
                    : null,
              ),
              SizedBox(height: scale.px(12)),
              PixelText('v$appVersion', color: Palette.fog.color),
              SizedBox(height: scale.px(12)),
            ],
          ),
          ),
        ],
      ),
    );
  }
}

class _LoadingStripes extends CustomPainter {
  _LoadingStripes(this.scale);

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final band = 8 * scale;
    var y = 0.0;
    var i = 0;
    while (y < size.height) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, band),
        paint..color = (i.isEven ? Palette.wine : Palette.nightPurple).color,
      );
      y += band;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LoadingStripes old) => old.scale != scale;
}
