import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../data/tutorial_models.dart';
import '../game/fighter_shape.dart';
import '../services/game_controller.dart';
import '../services/tutorial_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

/// One key per target id, so the overlay can find where an element is drawn.
final Map<String, GlobalKey> _targetKeys = {};

/// Marks [child] as a tutorial target called [id] (see `tutorial.json`).
class TutorialTarget extends StatelessWidget {
  const TutorialTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: _targetKeys.putIfAbsent(
      id,
      () => GlobalKey(debugLabel: 'tutorial:$id'),
    ),
    child: child,
  );
}

/// The tutorial: the whole screen is dark except the lit targets; taps outside
/// them do nothing; the coach explains the step.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay> {
  Rect? _hole;
  Timer? _timer;

  /// Time since the overlay appeared (the frame blinks) and since the current
  /// step began (the coach's text types out).
  final Stopwatch _clock = Stopwatch()..start();
  final Stopwatch _talk = Stopwatch()..start();
  String? _talkStep;

  /// The step whose targets were already scrolled into view.
  String? _scrolledFor;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (mounted) setState(() {});
    });
    _track();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Looks for the targets after every frame (screens scroll and resize).
  void _track() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _measure();
      if (next != _hole) setState(() => _hole = next);
      _track();
    });
  }

  Rect? _measure() {
    final step = ref.read(tutorialProvider).step;
    final me = context.findRenderObject();
    if (step == null || me is! RenderBox || !me.attached) return null;
    // A target inside a list (a trainer row) may be scrolled out of sight.
    if (_scrolledFor != step.id) {
      final ctx = _targetKeys[step.targets.first]?.currentContext;
      if (ctx != null && ctx.mounted) {
        _scrolledFor = step.id;
        Scrollable.maybeOf(ctx) == null
            ? null
            : Scrollable.ensureVisible(ctx, alignment: 0.5);
      }
    }
    Rect? union;
    for (final id in step.targets) {
      final target = _targetKeys[id]?.currentContext?.findRenderObject();
      if (target is! RenderBox || !target.attached || !target.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        target.getTransformTo(me),
        Offset.zero & target.size,
      );
      union = union == null ? rect : union.expandToInclude(rect);
    }
    return union;
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(tutorialProvider);
    final step = progress.step;
    final hole = _hole;
    if (step == null || hole == null) return const SizedBox.shrink();
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final margin = scale.px(2);
    final lit = Rect.fromLTRB(
      (hole.left - margin).floorToDouble(),
      (hole.top - margin).floorToDouble(),
      (hole.right + margin).ceilToDouble(),
      (hole.bottom + margin).ceilToDouble(),
    );
    final isOk = step.advance == TutorialAdvance.ok;
    final coach = content.tutorial;
    final blinkOn = (_clock.elapsedMilliseconds ~/ 400).isEven;

    // The coach types the text out, with the mouth moving while it does.
    if (_talkStep != step.id) {
      _talkStep = step.id;
      _talk
        ..reset()
        ..start();
    }
    final text = strings.t(step.textKey);
    final typed = (_talk.elapsedMilliseconds * coach.charsPerSecond / 1000)
        .floor();
    final talking = typed < text.length;
    final mouthOpen = talking && (typed ~/ coach.mouthEveryChars).isOdd;

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        // The card goes on the far side of the lit area from the screen center.
        final cardOnTop = lit.center.dy > size.height / 2;
        Widget blocker(Rect r) => Positioned.fromRect(
          rect: r,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _nothing,
            onPanDown: _nothingDown,
            child: const SizedBox.expand(),
          ),
        );
        return Stack(
          children: [
            // The dark layer and the frame around the lit area.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DimPainter(
                    lit: lit,
                    frame: scale.px(1),
                    frameColor: blinkOn
                        ? Palette.marigold.color
                        : Palette.sunYellow.color,
                  ),
                ),
              ),
            ),
            // Four blockers around the lit area: taps inside it reach the game.
            blocker(Rect.fromLTRB(0, 0, size.width, lit.top)),
            blocker(Rect.fromLTRB(0, lit.bottom, size.width, size.height)),
            blocker(Rect.fromLTRB(0, lit.top, lit.left, lit.bottom)),
            blocker(Rect.fromLTRB(lit.right, lit.top, size.width, lit.bottom)),
            Positioned(
              left: scale.px(6),
              right: scale.px(6),
              top: cardOnTop ? scale.px(40) : null,
              bottom: cardOnTop ? null : scale.px(60),
              child: PixelPanel(
                padding: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CoachPortrait(
                          body: Palette.byId[coach.coachBodyColor]!,
                          accent: Palette.byId[coach.coachAccentColor]!,
                          mouthOpen: mouthOpen,
                        ),
                        SizedBox(width: scale.px(5)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PixelText(
                                coach.coachName,
                                color: Palette.sunYellow.color,
                              ),
                              SizedBox(height: scale.px(3)),
                              PixelText(text, wrap: true, visibleChars: typed),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: scale.px(5)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PixelButton(
                          label: strings.t('tut_skip'),
                          style: PixelButtonStyle.secondary,
                          width: 56,
                          onPressed: ref.read(tutorialProvider.notifier).skip,
                        ),
                        if (isOk)
                          PixelButton(
                            label: strings.t('tut_ok'),
                            style: PixelButtonStyle.gold,
                            width: 80,
                            onPressed: ref.read(tutorialProvider.notifier).ok,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

void _nothing() {}
void _nothingDown(DragDownDetails _) {}

/// The coach's portrait: `assets/ui/coach_0.png` (mouth closed) and
/// `coach_1.png` (mouth open) when the art exists, otherwise a placeholder
/// wrestler.
class _CoachPortrait extends StatelessWidget {
  const _CoachPortrait({
    required this.body,
    required this.accent,
    required this.mouthOpen,
  });

  final int body;
  final int accent;
  final bool mouthOpen;

  /// 40 x 40 picture plus the 1-pixel frame.
  static const double _size = 42;

  Widget _frame(String name, Widget Function() fallback) => Image.asset(
    'assets/ui/$name.png',
    fit: BoxFit.fill,
    filterQuality: FilterQuality.none,
    isAntiAlias: false,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => fallback(),
  );

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    Widget placeholder() =>
        CustomPaint(painter: _PlaceholderCoach(body, accent));
    return SizedBox(
      width: scale.px(_size),
      height: scale.px(_size),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.ink.color,
          border: Border.all(color: Palette.slate.color, width: scale.px(1)),
        ),
        // Both frames stay in the tree so the swap never shows a blank.
        child: Stack(
          fit: StackFit.expand,
          children: [
            _frame('coach_0', placeholder),
            Visibility(
              visible: mouthOpen,
              maintainState: true,
              maintainSize: true,
              maintainAnimation: true,
              child: _frame('coach_1', () => const SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCoach extends CustomPainter {
  _PlaceholderCoach(this.body, this.accent);

  final int body;
  final int accent;

  @override
  void paint(Canvas canvas, Size size) =>
      paintFighter(canvas, size, bodyColor: body, accentColor: accent);

  @override
  bool shouldRepaint(_PlaceholderCoach old) =>
      old.body != body || old.accent != accent;
}

/// Darkens everything but [lit], and draws a [frame]-thick border around it.
class _DimPainter extends CustomPainter {
  _DimPainter({
    required this.lit,
    required this.frame,
    required this.frameColor,
  });

  final Rect lit;
  final double frame;
  final Color frameColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..color = Palette.ink.color.withAlpha(0xCC);
    final all = Offset.zero & size;
    canvas.drawRect(Rect.fromLTRB(0, 0, all.right, lit.top), paint);
    canvas.drawRect(Rect.fromLTRB(0, lit.bottom, all.right, all.bottom), paint);
    canvas.drawRect(Rect.fromLTRB(0, lit.top, lit.left, lit.bottom), paint);
    canvas.drawRect(
      Rect.fromLTRB(lit.right, lit.top, all.right, lit.bottom),
      paint,
    );
    final border = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.stroke
      ..strokeWidth = frame
      ..color = frameColor;
    canvas.drawRect(lit.deflate(frame / 2), border);
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.lit != lit || old.frame != frame || old.frameColor != frameColor;
}
