import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import '../app_info.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

Duration _seconds(double s) =>
    Duration(microseconds: (s * Duration.microsecondsPerSecond).round());

/// Background color of the studio video (it is part of the file, not a game
/// color), so the screen around the video matches it.
const Color _videoBackground = Color(0xFF0E0F12);

/// Studio splash: plays the studio video, then goes on. Tap to skip. If the
/// video cannot play (no codec, a test), it moves on after `splashSeconds`.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  VideoPlayerController? _video;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final seconds = ref.read(contentProvider).balance.ui.splashSeconds;
    // Safety net: if the video never starts, the still splash times out.
    _timer = Timer(_seconds(seconds), _next);
    _startVideo();
  }

  Future<void> _startVideo() async {
    try {
      final controller = VideoPlayerController.asset('assets/video/studio.mp4');
      _video = controller;
      await controller.initialize();
      if (!mounted) return;
      // Browsers only allow autoplay without sound.
      await controller.setVolume(kIsWeb ? 0 : 1);
      controller.addListener(_onVideo);
      await controller.play();
      if (!mounted) return;
      // The video is playing: replace the safety timer by its own length.
      _timer?.cancel();
      _timer = Timer(
        controller.value.duration + const Duration(seconds: 2),
        _next,
      );
      setState(() {});
    } catch (e) {
      debugPrint('Studio video not available: $e');
    }
  }

  void _onVideo() {
    final v = _video?.value;
    if (v != null && v.isInitialized && v.position >= v.duration) _next();
  }

  void _next() {
    if (_done || !mounted) return;
    _done = true;
    ref.read(appStageProvider.notifier).show(AppStage.loading);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _video?.removeListener(_onVideo);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final ui = ref.watch(contentProvider).balance.ui;
    if (video != null && video.value.isInitialized) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _next,
        child: ColoredBox(
          color: _videoBackground,
          child: LayoutBuilder(
            builder: (context, box) {
              // Size the video so the logo inside it spans at most
              // `splashLogoMaxFraction` of the screen width (and the video
              // still fits the screen height).
              final aspect = video.value.aspectRatio;
              final width = math.min(
                box.maxWidth *
                    ui.splashLogoMaxFraction /
                    ui.splashVideoLogoFraction,
                box.maxHeight * aspect,
              );
              return Center(
                child: SizedBox(
                  width: width,
                  height: width / aspect,
                  // In a browser the video is a native element that would swallow
                  // the tap meant to skip it.
                  child: IgnorePointer(child: VideoPlayer(video)),
                ),
              );
            },
          ),
        ),
      );
    }
    // The video has not started yet (or cannot play): just the video's own
    // background; the safety timer moves on.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      child: const ColoredBox(
        color: _videoBackground,
        child: SizedBox.expand(),
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
    final ui = ref.watch(contentProvider).balance.ui;
    final frame =
        (_elapsed.inMicroseconds *
            ui.loadingFps ~/
            Duration.microsecondsPerSecond) %
        ui.loadingFrames;
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
          _LoadingBackground(frame: frame, scale: scale),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: scale.px(40)),
                _LoadingLogo(scale: scale, strings: strings),
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

/// The animated loading picture (270 x 480, frames baked by
/// `tools/build_backgrounds.py`), drawn at a whole number of device pixels per
/// picture pixel and cropped to the canvas. Without the files the stripes
/// behind it show.
class _LoadingBackground extends StatelessWidget {
  const _LoadingBackground({required this.frame, required this.scale});

  final int frame;
  final PixelScale scale;

  static const double _width = 270;
  static const double _height = 480;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        maxWidth: scale.px(_width),
        maxHeight: scale.px(_height),
        child: Image.asset(
          'assets/backgrounds/loading_$frame.png',
          width: scale.px(_width),
          height: scale.px(_height),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          isAntiAlias: false,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// The game logo (`assets/ui/logo.png`); without the file, the old text title.
class _LoadingLogo extends StatelessWidget {
  const _LoadingLogo({required this.scale, required this.strings});

  final PixelScale scale;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/logo.png',
      width: scale.px(150),
      fit: BoxFit.fitWidth,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      errorBuilder: (_, _, _) => Column(
        children: [
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
