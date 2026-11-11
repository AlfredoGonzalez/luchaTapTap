import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../game/fighter_shape.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

/// Bands of the striped background, in virtual pixels.
const int _stripe = 8;

class _StripePainter extends CustomPainter {
  _StripePainter(this.scale);

  final int scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final band = (_stripe * scale).toDouble();
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
  bool shouldRepaint(_StripePainter old) => old.scale != scale;
}

class _BossFigure extends CustomPainter {
  _BossFigure({required this.body, required this.accent});

  final int body;
  final int accent;

  @override
  void paint(Canvas canvas, Size size) =>
      paintFighter(canvas, size, bodyColor: body, accentColor: accent);

  @override
  bool shouldRepaint(_BossFigure old) =>
      old.body != body || old.accent != accent;
}

/// Full-screen reveal before a boss: the boss at exactly 2x, its name, the time
/// limit and "¡A PELEAR!", which starts the countdown.
class BossIntro extends ConsumerWidget {
  const BossIntro({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    ref.watch(gameControllerProvider);
    final engine = controller.engine;
    final info = engine.fightInfo;
    final boss = info.opponent;
    final color = Palette.byId[boss.placeholderColor]!;
    final seconds =
        (boss.bossTimerSeconds ?? engine.content.balance.bossTimerSeconds)
            .round();
    final figure = boss.size * 2; // the only allowed scaling: exactly 2x

    return Stack(
      children: [
        CustomPaint(painter: _StripePainter(scale.scale), size: Size.infinite),
        Positioned.fill(
          child: Column(
          children: [
            SizedBox(height: scale.px(32)),
            PixelText(
              strings.t('boss_intro_title'),
              size: 16,
              color: Palette.marigold.color,
              shadow: Palette.ink.color,
            ),
            SizedBox(height: scale.px(6)),
            PixelText(
              strings.t('boss_intro_where', {
                'l': info.league.order,
                'n': info.fight,
              }),
              shadow: Palette.ink.color,
            ),
            SizedBox(height: scale.px(10)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.ink.color,
                border: Border.all(
                  color: Palette.slate.color,
                  width: scale.px(1),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(scale.px(6)),
                child: CustomPaint(
                  size: Size(scale.px(figure), scale.px(figure)),
                  painter: _BossFigure(body: color, accent: color),
                ),
              ),
            ),
            SizedBox(height: scale.px(8)),
            SizedBox(
              width: double.infinity,
              height: scale.px(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.ink.color,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: Palette.marigold.color,
                      width: scale.px(1),
                    ),
                  ),
                ),
                child: Center(
                  child: PixelText(
                    boss.name,
                    color: Palette.sunYellow.color,
                    align: TextAlign.center,
                  ),
                ),
              ),
            ),
            SizedBox(height: scale.px(6)),
            PixelText(
              strings.t('boss_intro_time', {'s': seconds}),
              align: TextAlign.center,
              wrap: true,
              shadow: Palette.ink.color,
            ),
            const Spacer(),
            PixelButton(
              label: strings.t('boss_intro_go'),
              style: PixelButtonStyle.gold,
              width: 120,
              height: 28,
              onPressed: controller.startBoss,
            ),
            SizedBox(height: scale.px(12)),
          ],
        ),
        ),
      ],
    );
  }
}
