import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import 'arena_view.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'panels.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

const double opponentBarHeight = 16;
const double comboRowHeight = 24;
const double skillsRowHeight = 30;
const double _finisherWidth = 48;
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
          child: const _OpponentBar(),
        ),
        SizedBox(
          height: scale.px(arenaHeight),
          child: Stack(
            children: [
              ArenaView(virtualHeight: arenaHeight),
              const _BossName(),
              const _NoticeBanner(),
            ],
          ),
        ),
        SizedBox(height: scale.px(comboRowHeight), child: const _ComboRow()),
        SizedBox(height: scale.px(skillsRowHeight), child: const _SkillsRow()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
          child: SizedBox(
            height: scale.px(upgradesPanelHeight),
            child: const UpgradesPanel(),
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
          PixelButton(
            label: strings.t('combo_button'),
            width: _finisherWidth,
            onPressed: ready
                ? ref.read(gameControllerProvider.notifier).finisher
                : null,
          ),
        ],
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
                  child: PixelIcon(
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
