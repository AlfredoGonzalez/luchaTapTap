import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import 'arena_view.dart';
import 'dialogs.dart';
import 'palette_color.dart';
import 'panels.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

// Layout bands in virtual pixels (Visual Style Guide, main fight screen).
const double _topSafe = 12;
const double _hudHeight = 24;
const double _opponentBarHeight = 16;
const double _comboRowHeight = 24;
const double _skillsRowHeight = 30;
const double _panelHeight = 80;
const double _navHeight = 24;
const double _bottomSafe = 8;
const double _sideMargin = 4;
const double _finisherWidth = 48;
const double _skillButtonSize = 30;

/// Everything on the screen except the arena itself.
const double _fixedHeight = _topSafe +
    _hudHeight +
    _opponentBarHeight +
    _comboRowHeight +
    _skillsRowHeight +
    _panelHeight +
    _navHeight +
    _bottomSafe;

/// The fight screen: HUD, opponent bar, arena, combo row, skills row, the
/// tabbed panel and navigation. Pop-ups sit on top of it.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final dialog = ref.watch(dialogProvider);
    final hasOffline = ref.watch(gameControllerProvider.select((s) => s.pendingOffline != null));
    final arenaHeight = scale.virtualHeight - _fixedHeight;

    return PopScope(
      // The Android back button closes pop-ups; the offline pop-up collects the
      // base amount (it never blocks the reward).
      canPop: dialog == null && !hasOffline,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (dialog != null) {
          ref.read(dialogProvider.notifier).close();
        } else if (hasOffline) {
          ref.read(gameControllerProvider.notifier).collectOffline();
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: scale.px(_topSafe)),
              SizedBox(height: scale.px(_hudHeight), child: const _Hud()),
              SizedBox(height: scale.px(_opponentBarHeight), child: const _OpponentBar()),
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
              SizedBox(height: scale.px(_comboRowHeight), child: const _ComboRow()),
              SizedBox(height: scale.px(_skillsRowHeight), child: const _SkillsRow()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
                child: SizedBox(height: scale.px(_panelHeight), child: const TabPanel()),
              ),
              SizedBox(height: scale.px(_navHeight), child: const _NavBar()),
              SizedBox(height: scale.px(_bottomSafe)),
            ],
          ),
          if (dialog == GameDialog.prestige) const PrestigeDialog(),
          if (dialog == GameDialog.debug) const DebugDialog(),
          if (hasOffline) const OfflineDialog(),
        ],
      ),
    );
  }
}

class _Hud extends ConsumerWidget {
  const _Hud();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final dps = ref.read(gameControllerProvider.notifier).engine.damagePerSecond;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(strings.t('hud_coins'), color: Palette.fog.color),
                PixelText(formatBig(state.coins), color: Palette.sunYellow.color),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Debug builds only: long-press the fight number for the panel.
              onLongPress: debugToolsEnabled
                  ? () => ref.read(dialogProvider.notifier).open(GameDialog.debug)
                  : null,
              child: Center(
                child: PixelText(
                  strings.t('hud_fight', {'n': state.fightNumber}),
                  size: 16,
                ),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: PixelText(
                strings.t('hud_per_second', {'n': formatBig(dps)}),
                color: Palette.marigold.color,
              ),
            ),
          ),
        ],
      ),
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
    final hpBar = PixelBar(fraction: fraction, fill: Palette.coral, track: Palette.wine);
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
              PixelText('${formatBig(state.enemyHp)} / ${formatBig(max)}', color: Palette.fog.color),
            ],
          ),
          hpBar,
        ],
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: content,
    );
  }
}

/// Boss name at the top of the arena, with the countdown in seconds.
class _BossName extends ConsumerWidget {
  const _BossName();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    if (!engine.isBossFight) return const SizedBox.shrink();
    final left = state.bossTimeLeft ?? engine.bossTimerLength;
    return Positioned(
      top: PixelScale.of(context).px(2),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Column(
          children: [
            PixelText(engine.opponent.name, size: 16, align: TextAlign.center),
            PixelText(
              '${strings.t('boss_label')}  ${strings.t('boss_timer', {'n': left.ceil()})}',
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
        child: PixelText(strings.t(key), size: 16, color: Palette.coral.color, align: TextAlign.center),
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
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final ready = engine.finisherReady;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
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
          PixelButton(
            label: strings.t('combo_button'),
            width: _finisherWidth,
            onPressed: ready ? ref.read(gameControllerProvider.notifier).finisher : null,
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
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < content.skills.length; i++) ...[
            if (i > 0) SizedBox(width: scale.px(4)),
            _SkillButton(skill: content.skills[i], state: state, engine: engine),
          ],
        ],
      ),
    );
  }
}

class _SkillButton extends ConsumerWidget {
  const _SkillButton({required this.skill, required this.state, required this.engine});

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
    return GestureDetector(
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
                child: PixelText(
                  learned ? skill.shortName : '?',
                  color: (learned ? Palette.bone : Palette.fog).color,
                  align: TextAlign.center,
                ),
              ),
              if (onCooldown)
                Align(
                  alignment: Alignment.topCenter,
                  child: PixelText('${cooldown.ceil()}', color: Palette.sunYellow.color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBar extends ConsumerWidget {
  const _NavBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final selected = ref.watch(panelTabProvider);
    const labels = {
      PanelTab.upgrades: 'tab_upgrades',
      PanelTab.skills: 'tab_skills',
      PanelTab.masks: 'tab_masks',
      PanelTab.talents: 'tab_talents',
    };
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: Row(
        children: [
          for (final tab in PanelTab.values) ...[
            if (tab != PanelTab.values.first) SizedBox(width: scale.px(2)),
            Expanded(
              child: PixelButton(
                label: strings.t(labels[tab]!),
                style: PixelButtonStyle.secondary,
                selected: tab == selected,
                onPressed: () => ref.read(panelTabProvider.notifier).select(tab),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
