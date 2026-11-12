import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/game_engine.dart';
import '../core/number_format.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import 'hud.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'rows.dart';
import 'tutorial_overlay.dart';
import 'ui_state.dart';

const double buySelectorHeight = 24;
const double upgradesPanelHeight = 80;

/// The panel under the skills row on the fight screen (the "Mejoras" tab):
/// the buy selector, then the upgrades and trainers.
class UpgradesPanel extends ConsumerWidget {
  const UpgradesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    // Costs and affordability change with the state, so rebuild with it.
    ref.watch(gameControllerProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final children = <Widget>[
      const _BuySelector(),
      for (final u in content.upgrades) _UpgradeRow(upgrade: u, engine: engine),
      for (final t in content.trainers) _TrainerRow(trainer: t, engine: engine),
    ];
    return PixelPanel(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final child in children) ...[
            child,
            SizedBox(height: scale.px(rowGap)),
          ],
        ],
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
      height: scale.px(buySelectorHeight),
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
                onPressed: () =>
                    ref.read(buyAmountProvider.notifier).select(options[i]),
              ),
            ),
          ],
        ],
      ),
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
    final milestones = ref.watch(contentProvider).balance.milestones;
    final next = milestones.nextAfter(level);
    return FlashOnIncrease(
      value: level,
      child: ListRow(
        icon: PixelIcons.byKey(upgrade.icon),
        onInfo: () => ref
            .read(infoTargetProvider.notifier)
            .show(InfoTarget(InfoKind.upgrade, upgrade.id)),
        infoLabel: '${strings.t('info_open')} ${upgrade.name}',
        title: upgrade.name,
        subtitle: next == null
            ? strings.t('row_level_short', {'n': level})
            : strings.t('row_level_next', {'n': level, 'next': next}),
        progress: next == null ? null : milestones.progressAt(level),
        trailing: TutorialTarget(
          id: 'upgrade:${upgrade.id}',
          child: CostButton(
            cost: formatBigShort(quote.cost),
            enabled: quote.canBuy,
            semanticLabel: upgrade.name,
            onPressed: () => ref
                .read(gameControllerProvider.notifier)
                .buyUpgrade(upgrade.id),
          ),
        ),
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
    if (!unlocked) {
      return ListRow(
        icon: PixelIcons.locked,
        onInfo: () => ref
            .read(infoTargetProvider.notifier)
            .show(InfoTarget(InfoKind.trainer, trainer.id)),
        infoLabel: '${strings.t('info_open')} ${strings.t('row_locked')}',
        title: strings.t('row_locked'),
        subtitle: strings.t('row_mystery'),
        trailing: PixelButton(
          label: strings.t('row_unlock_short', {'n': trainer.unlockFight}),
          width: 64,
          onPressed: null,
        ),
      );
    }
    final dps = Big.fromDouble(trainer.baseDps).mulDouble(level.toDouble());
    final milestones = ref.watch(contentProvider).balance.milestones;
    final next = milestones.nextAfter(level);
    return FlashOnIncrease(
      value: level,
      child: ListRow(
        icon: PixelIcons.byKey(trainer.portrait) ?? PixelIcons.trainer,
        onInfo: () => ref
            .read(infoTargetProvider.notifier)
            .show(InfoTarget(InfoKind.trainer, trainer.id)),
        infoLabel: '${strings.t('info_open')} ${trainer.name}',
        title: trainer.name,
        subtitle: level == 0
            ? strings.t('row_level_short', {'n': level})
            : strings.t('row_level_dps', {
                'n': level,
                'd': formatBigShort(dps),
              }),
        progress: next == null ? null : milestones.progressAt(level),
        trailing: CostButton(
          cost: formatBigShort(quote.cost),
          enabled: quote.canBuy,
          semanticLabel: trainer.name,
          onPressed: () =>
              ref.read(gameControllerProvider.notifier).buyTrainer(trainer.id),
        ),
      ),
    );
  }
}

/// Shared by the views that end in a detail panel.
class DetailPanel extends StatelessWidget {
  const DetailPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        scale.px(sideMargin),
        0,
        scale.px(sideMargin),
        scale.px(2),
      ),
      child: PixelPanel(
        padding: 4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}
