import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/game_engine.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import 'arena_view.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

// Layout bands in virtual pixels (Visual Style Guide, main fight screen).
const double _topSafe = 12;
const double _hudHeight = 24;
const double _opponentBarHeight = 16;
const double _buySelectorHeight = 24;
const double _rowHeight = 26;
const double _panelGap = 2;
const double _bottomSafe = 8;
const double _sideMargin = 4;

/// Main fight screen for M1: HUD, opponent bar, arena, buy selector and the
/// upgrade and trainer rows. Combo, skills and tabs arrive in later milestones.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    const panelHeight = _buySelectorHeight + _rowHeight * 2 + _panelGap * 3 + 4;
    final arenaHeight = scale.virtualHeight -
        (_topSafe + _hudHeight + _opponentBarHeight + panelHeight + _bottomSafe);
    return Column(
      children: [
        SizedBox(height: scale.px(_topSafe)),
        SizedBox(height: scale.px(_hudHeight), child: const _Hud()),
        SizedBox(height: scale.px(_opponentBarHeight), child: const _OpponentBar()),
        SizedBox(
          height: scale.px(arenaHeight),
          child: ArenaView(virtualHeight: arenaHeight),
        ),
        SizedBox(height: scale.px(panelHeight), child: const _BuyPanel()),
        SizedBox(height: scale.px(_bottomSafe)),
      ],
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
                PixelText(formatBig(state.coins), size: 8, color: Palette.sunYellow.color),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: PixelText(
                strings.t('hud_fight', {'n': state.fightNumber}),
                size: 16,
                color: Palette.bone.color,
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: PixelText(engine.opponent.name)),
              PixelText('${formatBig(state.enemyHp)} / ${formatBig(max)}', color: Palette.fog.color),
            ],
          ),
          PixelBar(fraction: fraction, fill: Palette.coral, track: Palette.wine),
        ],
      ),
    );
  }
}

class _BuyPanel extends ConsumerWidget {
  const _BuyPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    // Rebuild on every state change: costs and affordability depend on it.
    ref.watch(gameControllerProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final rows = <Widget>[
      for (final upgrade in content.upgrades) _UpgradeRow(upgrade: upgrade, engine: engine),
      for (final trainer in content.trainers) _TrainerRow(trainer: trainer, engine: engine),
    ];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: scale.px(_sideMargin)),
      child: PixelPanel(
        child: Column(
          children: [
            const _BuySelector(),
            for (final row in rows) ...[SizedBox(height: scale.px(_panelGap)), row],
          ],
        ),
      ),
    );
  }
}

class _BuySelector extends ConsumerWidget {
  const _BuySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final selected = ref.watch(buyAmountProvider);
    final options = <BuyAmount>[
      for (final n in content.balance.buyFixedAmounts) BuyAmount.fixed(n),
      const BuyAmount.max(),
    ];
    return SizedBox(
      height: scale.px(_buySelectorHeight),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: scale.px(4)),
            Expanded(
              child: PixelButton(
                label: options[i].isMax
                    ? strings.t('buy_max')
                    : strings.t('buy_x', {'n': options[i].count!}),
                style: PixelButtonStyle.secondary,
                selected: options[i] == selected,
                onPressed: () => ref.read(buyAmountProvider.notifier).select(options[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RowFrame extends StatelessWidget {
  const _RowFrame({
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.button,
  });

  final int iconColor;
  final String title;
  final String subtitle;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return SizedBox(
      height: scale.px(_rowHeight),
      child: Row(
        children: [
          // 16 x 16 placeholder icon.
          SizedBox(
            width: scale.px(16),
            height: scale.px(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: iconColor.color,
                border: Border.all(color: Palette.ink.color, width: scale.px(1)),
              ),
            ),
          ),
          SizedBox(width: scale.px(4)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(title),
                PixelText(subtitle, color: Palette.fog.color),
              ],
            ),
          ),
          button,
        ],
      ),
    );
  }
}

class _CostButton extends StatelessWidget {
  const _CostButton({required this.quote, required this.onPressed});

  final BuyQuote quote;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PixelButton(
      label: formatBig(quote.cost),
      width: 52,
      onPressed: quote.canBuy ? onPressed : null,
    );
  }
}

class _UpgradeRow extends ConsumerWidget {
  const _UpgradeRow({required this.upgrade, required this.engine});

  final UpgradeDef upgrade;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final amount = ref.watch(buyAmountProvider);
    final level = engine.state.upgradeLevel(upgrade.id);
    final quote = engine.quoteUpgrade(upgrade.id, amount);
    return _RowFrame(
      iconColor: Palette.marigold,
      title: '${upgrade.name}  ${strings.t('row_level', {'n': level})}',
      subtitle: strings.t('upgrade_tap_damage', {'n': formatBig(Big.fromDouble(upgrade.perLevelValue))}),
      button: _CostButton(
        quote: quote,
        onPressed: () => ref.read(gameControllerProvider.notifier).buyUpgrade(upgrade.id),
      ),
    );
  }
}

class _TrainerRow extends ConsumerWidget {
  const _TrainerRow({required this.trainer, required this.engine});

  final TrainerDef trainer;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final amount = ref.watch(buyAmountProvider);
    final level = engine.state.trainerLevel(trainer.id);
    final quote = engine.quoteTrainer(trainer.id, amount);
    final unlocked = engine.isTrainerUnlocked(trainer);
    return _RowFrame(
      iconColor: Palette.royal,
      title: unlocked
          ? '${trainer.name}  ${strings.t('row_level', {'n': level})}'
          : strings.t('row_locked'),
      subtitle: unlocked
          ? strings.t('trainer_dps', {'n': formatBig(Big.fromDouble(trainer.baseDps))})
          : strings.t('row_unlock_fight', {'n': trainer.unlockFight}),
      button: _CostButton(
        quote: quote,
        onPressed: () => ref.read(gameControllerProvider.notifier).buyTrainer(trainer.id),
      ),
    );
  }
}
