import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import 'arena_view.dart';
import 'art_icon.dart';
import 'ui_state.dart';
import 'kick_layer.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'panels.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'tutorial_overlay.dart';

const double opponentBarHeight = 16;
const double comboRowHeight = 24;
const double skillsRowHeight = 30;
const double _finisherWidth = 56;
const double _skillButtonSize = 30;

/// Height of everything on the fight screen except the arena.
const double fightFixedHeight =
    opponentBarHeight + comboRowHeight + skillsRowHeight + upgradesPanelHeight;

/// The main screen: opponent bar, arena, combo row, skills row and the
/// upgrades panel.
class FightView extends ConsumerWidget {
  const FightView({super.key, required this.height});

  /// Total height available, in virtual pixels.
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final arenaHeight = height - fightFixedHeight;
    return Column(
      children: [
        SizedBox(
          height: scale.px(opponentBarHeight),
          child: const TutorialTarget(id: 'opponentBar', child: _OpponentBar()),
        ),
        SizedBox(
          height: scale.px(arenaHeight),
          child: TutorialTarget(
            id: 'arena',
            child: Stack(
            children: [
              // A new arena is built when the window changes size.
              ArenaView(
                key: ValueKey('${scale.virtualWidth}x$arenaHeight'),
                virtualWidth: scale.virtualWidth,
                virtualHeight: arenaHeight,
              ),
              const KickCircles(),
              const _BossName(),
              const _NoticeBanner(),
              const KickPrompt(),
              const _BossButton(),
              const _BossLossPanel(),
              const _BossWinPanel(),
            ],
          ),
          ),
        ),
        SizedBox(
          height: scale.px(comboRowHeight),
          child: const TutorialTarget(id: 'comboRow', child: _ComboRow()),
        ),
        SizedBox(height: scale.px(skillsRowHeight), child: const _SkillsRow()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
          child: SizedBox(
            height: scale.px(upgradesPanelHeight),
            child: const TutorialTarget(
              id: 'upgradesPanel',
              child: UpgradesPanel(),
            ),
          ),
        ),
      ],
    );
  }
}

class _OpponentBar extends ConsumerWidget {
  const _OpponentBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final max = engine.enemyMaxHp;
    final fraction = max.isZero ? 0.0 : (state.enemyHp / max).toDouble();
    final hpBar = PixelBar(
      fraction: fraction,
      fill: Palette.coral,
      track: Palette.wine,
    );
    final Widget content;
    if (engine.isBossFight) {
      // Boss: health bar above, countdown bar below; the name moves to the arena.
      final left = state.bossTimeLeft ?? engine.bossTimerLength;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          hpBar,
          PixelBar(
            fraction: left / engine.bossTimerLength,
            fill: Palette.marigold,
            track: Palette.ink,
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: PixelText(engine.opponent.name)),
              PixelText(
                formatBigShort(state.enemyHp),
                color: Palette.fog.color,
              ),
            ],
          ),
          hpBar,
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
      child: content,
    );
  }
}

/// Boss name at the top of the arena, with the countdown as m:ss.
class _BossName extends ConsumerWidget {
  const _BossName();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    if (!engine.isBossFight || engine.awaitingBossStart) return const SizedBox.shrink();
    final left = (state.bossTimeLeft ?? engine.bossTimerLength).ceil();
    return Positioned(
      top: PixelScale.of(context).px(2),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            PixelText(
              engine.opponent.name,
              color: Palette.sunYellow.color,
              align: TextAlign.center,
            ),
            SizedBox(height: PixelScale.of(context).px(2)),
            PixelText(
              strings.t('boss_clock', {
                'm': left ~/ 60,
                's': (left % 60).toString().padLeft(2, '0'),
              }),
              color: Palette.marigold.color,
              align: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the boss wins: the fighters stay where they fell and a tip waits
/// for "Aceptar", which sends the player back to the farming fight.
class _BossLossPanel extends ConsumerWidget {
  const _BossLossPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    if (!controller.engine.awaitingBossLossAck) return const SizedBox.shrink();
    final strings = ref.watch(stringsProvider);
    // At the top of the arena, so the fighters on the floor stay in view.
    return Positioned(
      left: scale.px(sideMargin),
      right: scale.px(sideMargin),
      top: scale.px(2),
      child: PixelPanel(
        padding: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(
              strings.t('boss_lost_title'),
              color: Palette.coral.color,
              align: TextAlign.center,
            ),
            SizedBox(height: scale.px(2)),
            PixelText(
              strings.t('boss_lost_tip'),
              wrap: true,
              align: TextAlign.center,
            ),
            SizedBox(height: scale.px(3)),
            Center(
              child: PixelButton(
                label: strings.t('boss_lost_ok'),
                style: PixelButtonStyle.gold,
                width: 70,
                onPressed: controller.acknowledgeBossLoss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the player beats a boss: the player celebrates while the tip
/// waits for "Continuar".
class _BossWinPanel extends ConsumerWidget {
  const _BossWinPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final boss = controller.engine.bossWinOpponent;
    if (boss == null) return const SizedBox.shrink();
    final strings = ref.watch(stringsProvider);
    return Positioned(
      left: scale.px(sideMargin),
      right: scale.px(sideMargin),
      top: scale.px(2),
      child: PixelPanel(
        padding: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelText(
              strings.t('boss_win_title'),
              size: 16,
              color: Palette.sunYellow.color,
              shadow: Palette.ink.color,
              align: TextAlign.center,
            ),
            SizedBox(height: scale.px(2)),
            PixelText(
              strings.t('boss_win_text', {'name': boss.name}),
              wrap: true,
              align: TextAlign.center,
            ),
            SizedBox(height: scale.px(3)),
            Center(
              child: PixelButton(
                label: strings.t('boss_win_ok'),
                style: PixelButtonStyle.gold,
                width: 80,
                onPressed: controller.acknowledgeBossWin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¡JEFE!": appears while the player farms the fight before a boss; pressing
/// it is the player's choice to fight the boss.
class _BossButton extends ConsumerWidget {
  const _BossButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    if (!controller.engine.bossGateReady) return const SizedBox.shrink();
    final strings = ref.watch(stringsProvider);
    return Positioned(
      top: scale.px(2),
      right: scale.px(2),
      child: TutorialTarget(
        id: 'bossButton',
        child: PixelButton(
          label: strings.t('boss_button'),
          style: PixelButtonStyle.gold,
          width: 52,
          onPressed: controller.challengeBoss,
        ),
      ),
    );
  }
}

class _NoticeBanner extends ConsumerWidget {
  const _NoticeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ref.watch(noticeProvider);
    if (key == null) return const SizedBox.shrink();
    final strings = ref.watch(stringsProvider);
    return Center(
      child: IgnorePointer(
        child: PixelText(
          strings.t(key),
          color: Palette.coral.color,
          align: TextAlign.center,
          wrap: true,
        ),
      ),
    );
  }
}

class _ComboRow extends ConsumerWidget {
  const _ComboRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final fillPerTap = ref.watch(contentProvider).balance.combo.fillPerTap;
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final ready = engine.finisherReady;
    final hits = (state.comboMeter / fillPerTap).round();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
      child: Row(
        children: [
          Expanded(
            child: PixelBar(
              fraction: state.comboMeter,
              fill: ready ? Palette.sunYellow : Palette.violet,
              track: Palette.ink,
            ),
          ),
          SizedBox(width: scale.px(4)),
          SizedBox(
            width: scale.px(24),
            child: PixelText(
              strings.t('combo_count', {'n': hits}),
              color: ready ? Palette.sunYellow.color : Palette.fog.color,
            ),
          ),
          _FinisherBadge(ready: ready),
        ],
      ),
    );
  }
}

/// Shows whether the finisher is ready: "GOLPE" when the combo is filling and
/// "PATADA" when the circles can be tapped. It is not a button.
class _FinisherBadge extends ConsumerWidget {
  const _FinisherBadge({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final text = strings.t(ready ? 'combo_kick' : 'combo_button');
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: SizedBox(
        width: scale.px(_finisherWidth),
        height: scale.px(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (ready ? Palette.marigold : Palette.slate).color,
            border: Border.all(color: Palette.ink.color, width: scale.px(1)),
          ),
          child: Center(
            child: PixelText(
              text,
              color: (ready ? Palette.ink : Palette.fog).color,
              align: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillsRow extends ConsumerWidget {
  const _SkillsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < content.skills.length; i++) ...[
            if (i > 0) SizedBox(width: scale.px(4)),
            _SkillButton(
              skill: content.skills[i],
              state: state,
              engine: engine,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillButton extends ConsumerWidget {
  const _SkillButton({
    required this.skill,
    required this.state,
    required this.engine,
  });

  final SkillDef skill;
  final GameState state;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final level = state.skillLevel(skill.id);
    final cooldown = state.skillCooldownLeft(skill.id);
    final active = state.skillActiveLeft(skill.id) > 0;
    final learned = level > 0;
    final total = engine.cooldownOf(skill);
    final onCooldown = learned && cooldown > 0;
    final fill = !learned
        ? Palette.slate
        : onCooldown
        ? Palette.nightPurple
        : Palette.luchaRed;
    final icon = learned
        ? (PixelIcons.byKey(skill.icon) ?? PixelIcons.skillBolt)
        : PixelIcons.locked;
    // Final art for this skill's icon, when there is some.
    final art = learned ? ref.watch(spriteLibraryProvider).icon(skill.icon) : null;
    return Semantics(
      button: true,
      enabled: learned && !onCooldown,
      label: skill.name,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: learned && !onCooldown
            ? () => ref.read(gameControllerProvider.notifier).useSkill(skill.id)
            : null,
        child: SizedBox(
          width: scale.px(_skillButtonSize),
          height: scale.px(_skillButtonSize),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill.color,
              border: Border.all(
                color: (active ? Palette.sunYellow : Palette.ink).color,
                width: scale.px(1),
              ),
            ),
            child: Stack(
              children: [
                if (onCooldown)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: (cooldown / total).clamp(0.0, 1.0),
                      widthFactor: 1,
                      child: ColoredBox(color: Palette.slate.color),
                    ),
                  ),
                Center(
                  child: art != null
                      ? ArtIcon(art)
                      : PixelIcon(
                          icon,
                          color: (learned ? Palette.bone : Palette.fog).color,
                        ),
                ),
                if (onCooldown)
                  Positioned(
                    right: scale.px(2),
                    bottom: scale.px(2),
                    child: PixelText(
                      '${cooldown.ceil()}',
                      color: Palette.sunYellow.color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
