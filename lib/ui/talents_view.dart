import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_engine.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import 'art_icon.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'panels.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

const double _nodeHeight = 30;

String _plain(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

String talentEffectText(Strings strings, TalentDef t) {
  final isFlat =
      t.effect == TalentEffect.offlineCapHours ||
      t.effect == TalentEffect.startingCoins;
  final value = isFlat
      ? _plain(t.valuePerLevel)
      : _plain(t.valuePerLevel * 100);
  return strings.t('talent_${t.effect.name}', {'n': value});
}

enum _NodeState { maxed, owned, available, locked }

/// "TALENTOS": Belts, the three branches as columns of nodes, and a detail
/// panel with the upgrade button.
class TalentsView extends ConsumerWidget {
  const TalentsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final selectedId =
        ref.watch(selectedTalentProvider) ?? content.talents.first.id;
    final selected = content.talent(selectedId);
    return Column(
      children: [
        ViewTitleBar(
          title: strings.t('view_talents'),
          trailing: Row(
            children: [
              const PixelIcon(PixelIcons.belt),
              SizedBox(width: scale.px(3)),
              PixelText(formatBigShort(state.belts), color: Palette.aqua.color),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(scale.px(sideMargin)),
          child: SizedBox(
            width: double.infinity,
            child: PixelButton(
              label: strings.t('prestige_button'),
              onPressed: () =>
                  ref.read(dialogProvider.notifier).open(GameDialog.prestige),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < content.talentBranches.length; i++) ...[
                  if (i > 0) SizedBox(width: scale.px(2)),
                  Expanded(
                    child: _Branch(
                      branch: content.talentBranches[i],
                      engine: engine,
                      selectedId: selectedId,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DetailPanel(
          children: [_Detail(talent: selected, engine: engine)],
        ),
      ],
    );
  }
}

class _Branch extends ConsumerWidget {
  const _Branch({
    required this.branch,
    required this.engine,
    required this.selectedId,
  });

  final TalentBranchDef branch;
  final GameEngine engine;
  final String selectedId;

  _NodeState _stateOf(TalentDef t) {
    final level = engine.state.talentLevel(t.id);
    if (level >= t.maxLevel) return _NodeState.maxed;
    if (level > 0) return _NodeState.owned;
    final parent = t.parent;
    if (parent != null && engine.state.talentLevel(parent) == 0) {
      return _NodeState.locked;
    }
    return _NodeState.available;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    return Column(
      children: [
        SizedBox(
          height: scale.px(12),
          child: Center(
            child: PixelText(
              branch.name.toUpperCase(),
              color: Palette.marigold.color,
            ),
          ),
        ),
        for (final t in branch.nodes) ...[
          SizedBox(height: scale.px(2)),
          SizedBox(
            height: scale.px(_nodeHeight),
            child: _Node(
              talent: t,
              art: ref.watch(spriteLibraryProvider).icon(t.icon),
              state: _stateOf(t),
              level: engine.state.talentLevel(t.id),
              selected: t.id == selectedId,
              label: strings.t('talent_node_level', {
                'a': engine.state.talentLevel(t.id),
                'b': t.maxLevel,
              }),
              onTap: () =>
                  ref.read(selectedTalentProvider.notifier).select(t.id),
            ),
          ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.talent,
    required this.art,
    required this.state,
    required this.level,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final TalentDef talent;
  final ui.Image? art;
  final _NodeState state;
  final int level;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final border = switch (state) {
      _NodeState.maxed => Palette.sunYellow,
      _NodeState.owned => Palette.nopal,
      _NodeState.available => Palette.royal,
      _NodeState.locked => Palette.ink,
    };
    final locked = state == _NodeState.locked;
    return Semantics(
      button: true,
      selected: selected,
      label: '${talent.name} $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color:
                (selected
                        ? Palette.slate
                        : (locked ? Palette.ink : Palette.nightPurple))
                    .color,
            border: Border.all(
              color: (selected ? Palette.marigold : border).color,
              width: scale.px(1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (art != null && !locked)
                ArtIcon(art!)
              else
                PixelIcon(
                  locked
                      ? PixelIcons.locked
                      : (PixelIcons.byKey(talent.icon) ?? PixelIcons.skillStar),
                  color: switch (state) {
                    _NodeState.maxed => Palette.sunYellow,
                    _NodeState.owned => Palette.bone,
                    _NodeState.available => Palette.fog,
                    _NodeState.locked => Palette.dust,
                  }.color,
                ),
              SizedBox(height: scale.px(2)),
              PixelText(
                label,
                color: (locked ? Palette.dust : Palette.fog).color,
                align: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.talent, required this.engine});

  final TalentDef talent;
  final GameEngine engine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final level = engine.state.talentLevel(talent.id);
    final quote = engine.quoteTalent(talent.id);
    final maxed = quote.failure == BuyFailure.maxed;
    final locked = quote.failure == BuyFailure.locked;
    final parentName = talent.parent == null
        ? ''
        : engine.content.talent(talent.parent!).name;
    final String button;
    if (maxed) {
      button = strings.t('talent_maxed');
    } else {
      button = strings.t('talent_upgrade');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: PixelText(talent.name, color: Palette.sunYellow.color),
            ),
            PixelText(
              strings.t('skill_row_level', {
                'n': level,
                'max': talent.maxLevel,
              }),
              color: Palette.fog.color,
            ),
          ],
        ),
        SizedBox(height: scale.px(3)),
        PixelText(
          locked
              ? strings.t('talent_locked', {'name': parentName})
              : talentEffectText(strings, talent),
          wrap: true,
        ),
        SizedBox(height: scale.px(3)),
        SizedBox(
          width: double.infinity,
          child: PixelButton(
            label: maxed ? button : '$button ${formatBigShort(quote.cost)}',
            icon: maxed ? null : PixelIcons.belt,
            semanticLabel: '$button ${talent.name}',
            style: PixelButtonStyle.confirm,
            onPressed: quote.canBuy
                ? () => ref
                      .read(gameControllerProvider.notifier)
                      .buyTalent(talent.id)
                : null,
          ),
        ),
      ],
    );
  }
}
