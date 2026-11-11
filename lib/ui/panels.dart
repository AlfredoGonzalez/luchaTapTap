import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/game_engine.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_bundle.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

// Panel sizes in virtual pixels (Visual Style Guide).
const double buySelectorHeight = 24;
const double rowHeight = 26;
const double rowGap = 2;
const double sectionHeaderHeight = 10;

String _percent(double fraction) {
  final value = fraction * 100;
  return value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
}

String _plain(double value) =>
    value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

/// The scrolling area under the skills row: one list per tab.
class TabPanel extends ConsumerWidget {
  const TabPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    // Costs and affordability change with the state, so rebuild with it.
    ref.watch(gameControllerProvider);
    final tab = ref.watch(panelTabProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final strings = ref.watch(stringsProvider);

    final children = switch (tab) {
      PanelTab.upgrades => _upgradeChildren(content, engine),
      PanelTab.skills => [for (final s in content.skills) _SkillRow(skill: s, engine: engine)],
      PanelTab.masks => [for (final m in content.masks) _MaskRow(mask: m, engine: engine)],
      PanelTab.talents => _talentChildren(content, engine, strings),
    };
    return PixelPanel(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          for (final child in children) ...[child, SizedBox(height: scale.px(rowGap))],
        ],
      ),
    );
  }

  List<Widget> _upgradeChildren(ContentBundle content, GameEngine engine) => [
        const _BuySelector(),
        for (final u in content.upgrades) _UpgradeRow(upgrade: u, engine: engine),
        for (final t in content.trainers) _TrainerRow(trainer: t, engine: engine),
      ];

  List<Widget> _talentChildren(ContentBundle content, GameEngine engine, Strings strings) => [
        _PrestigeHeader(engine: engine),
        for (final branch in content.talentBranches) ...[
          _SectionHeader(branch.name),
          for (final t in branch.nodes) _TalentRow(talent: t, engine: engine),
        ],
      ];
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return SizedBox(
      height: scale.px(sectionHeaderHeight),
      child: Align(
        alignment: Alignment.centerLeft,
        child: PixelText(text, color: Palette.marigold.color),
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
      height: scale.px(rowHeight),
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
  const _CostButton({required this.label, required this.enabled, required this.onPressed});

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      PixelButton(label: label, width: 52, onPressed: enabled ? onPressed : null);
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
    final effect = switch (upgrade.effect) {
      UpgradeEffect.tapDamage =>
        strings.t('upgrade_tap_damage', {'n': formatBig(Big.fromDouble(upgrade.perLevelValue))}),
      UpgradeEffect.critChance =>
        strings.t('talent_critChance', {'n': _percent(upgrade.perLevelValue)}),
    };
    return _RowFrame(
      iconColor: Palette.marigold,
      title: '${upgrade.name}  ${strings.t('row_level', {'n': level})}',
      subtitle: effect,
      button: _CostButton(
        label: formatBig(quote.cost),
        enabled: quote.canBuy,
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
        label: formatBig(quote.cost),
        enabled: quote.canBuy,
        onPressed: () => ref.read(gameControllerProvider.notifier).buyTrainer(trainer.id),
      ),
    );
  }
}

/// Text describing a skill's effect at [level] (level 1 when not learned).
String skillEffectText(Strings strings, SkillDef skill, int level) {
  final value = _plain(skill.valueAt(level < 1 ? 1 : level));
  return strings.t('skill_${skill.effect.name}', {'n': value, 'd': _plain(skill.duration)});
}

class _SkillRow extends ConsumerWidget {
  const _SkillRow({required this.skill, required this.engine});

  final SkillDef skill;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final level = engine.state.skillLevel(skill.id);
    final quote = engine.quoteSkill(skill.id);
    final locked = level == 0 && quote.failure == BuyFailure.locked;
    final maxed = quote.failure == BuyFailure.maxed;
    return _RowFrame(
      iconColor: Palette.burntOrange,
      title: locked
          ? strings.t('skill_locked')
          : '${skill.name}  ${strings.t('skill_level', {'n': level, 'max': skill.maxLevel})}',
      subtitle: locked
          ? strings.t('skill_unlock_fight', {'n': skill.unlockFight})
          : skillEffectText(strings, skill, level),
      button: _CostButton(
        label: maxed ? strings.t('talent_maxed') : formatBig(quote.cost),
        enabled: quote.canBuy,
        onPressed: () => ref.read(gameControllerProvider.notifier).buySkill(skill.id),
      ),
    );
  }
}

String maskBonusText(Strings strings, MaskDef mask) {
  final isPercent = mask.bonusType != MaskBonusType.offlineCapHours;
  final value = isPercent ? _percent(mask.bonusValue) : _plain(mask.bonusValue);
  return strings.t('mask_bonus_${mask.bonusType.name}', {'n': value});
}

class _MaskRow extends ConsumerWidget {
  const _MaskRow({required this.mask, required this.engine});

  final MaskDef mask;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final owned = engine.ownsMask(mask.id);
    final equipped = engine.state.equippedMask == mask.id;
    final controller = ref.read(gameControllerProvider.notifier);
    final color = Palette.byId[mask.slotColors[1]]!;

    final Widget button;
    String subtitle;
    if (owned) {
      subtitle = maskBonusText(strings, mask);
      button = PixelButton(
        label: equipped ? strings.t('mask_equipped') : strings.t('mask_equip'),
        width: 52,
        style: PixelButtonStyle.confirm,
        selected: equipped,
        onPressed: equipped ? null : () => controller.equipMask(mask.id),
      );
    } else {
      switch (mask.unlockRule) {
        case MaskUnlockRule.belts:
          final quote = engine.quoteMask(mask.id);
          subtitle = strings.t('mask_unlock_belts', {'n': _plain(mask.unlockValue)});
          button = _CostButton(
            label: formatBig(quote.cost),
            enabled: quote.canBuy,
            onPressed: () => controller.buyMask(mask.id),
          );
        case MaskUnlockRule.league:
          subtitle = strings.t('mask_unlock_league', {'n': _plain(mask.unlockValue)});
          button = _CostButton(label: strings.t('mask_locked'), enabled: false, onPressed: () {});
        case MaskUnlockRule.shop:
          subtitle = strings.t('mask_unlock_shop');
          button = _CostButton(label: strings.t('mask_locked'), enabled: false, onPressed: () {});
        case MaskUnlockRule.starter:
          subtitle = maskBonusText(strings, mask);
          button = _CostButton(label: strings.t('mask_locked'), enabled: false, onPressed: () {});
      }
    }
    return _RowFrame(
      iconColor: owned ? color : Palette.slate,
      title: owned ? mask.name : strings.t('mask_locked'),
      subtitle: subtitle,
      button: button,
    );
  }
}

class _PrestigeHeader extends ConsumerWidget {
  const _PrestigeHeader({required this.engine});

  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final belts = engine.state.belts;
    return SizedBox(
      height: scale.px(buySelectorHeight),
      child: Row(
        children: [
          Expanded(
            child: PixelText(strings.t('talent_belts', {'n': formatBig(belts)}),
                color: Palette.sunYellow.color),
          ),
          PixelButton(
            label: strings.t('prestige_button'),
            width: 84,
            onPressed: () => ref.read(dialogProvider.notifier).open(GameDialog.prestige),
          ),
        ],
      ),
    );
  }
}

String talentEffectText(Strings strings, TalentDef t) {
  final String value;
  switch (t.effect) {
    case TalentEffect.offlineCapHours:
    case TalentEffect.startingCoins:
      value = _plain(t.valuePerLevel);
    case TalentEffect.tapDamageMultiplier:
    case TalentEffect.trainerDamageMultiplier:
    case TalentEffect.coinGainMultiplier:
    case TalentEffect.critChance:
    case TalentEffect.skillCooldownReduction:
    case TalentEffect.luckyRateMultiplier:
      value = _percent(t.valuePerLevel);
  }
  return strings.t('talent_${t.effect.name}', {'n': value});
}

class _TalentRow extends ConsumerWidget {
  const _TalentRow({required this.talent, required this.engine});

  final TalentDef talent;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final level = engine.state.talentLevel(talent.id);
    final quote = engine.quoteTalent(talent.id);
    final maxed = quote.failure == BuyFailure.maxed;
    final locked = quote.failure == BuyFailure.locked;
    final parentName = talent.parent == null ? '' : engine.content.talent(talent.parent!).name;
    return _RowFrame(
      iconColor: locked ? Palette.slate : Palette.nopal,
      title: '${talent.name}  ${strings.t('skill_level', {'n': level, 'max': talent.maxLevel})}',
      subtitle: locked
          ? strings.t('talent_locked', {'name': parentName})
          : talentEffectText(strings, talent),
      button: _CostButton(
        label: maxed ? strings.t('talent_maxed') : formatBig(quote.cost),
        enabled: quote.canBuy,
        onPressed: () => ref.read(gameControllerProvider.notifier).buyTalent(talent.id),
      ),
    );
  }
}
