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
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'rows.dart';
import 'ui_state.dart';

String _number(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

/// What [skill] does at [level] (level 1 when it is not learned): its
/// `description` from skills.json with the value and duration filled in.
String skillDescription(SkillDef skill, int level) => skill.description
    .replaceAll('{n}', _number(skill.valueAt(level < 1 ? 1 : level)))
    .replaceAll('{d}', _number(skill.duration));

/// "HABILIDADES": every skill with its level and cooldown, a buy button and a
/// detail panel for the selected one.
class SkillsView extends ConsumerWidget {
  const SkillsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final selectedId =
        ref.watch(selectedSkillProvider) ?? content.skills.first.id;
    final selected = content.skill(selectedId);
    return Column(
      children: [
        ViewTitleBar(title: strings.t('view_skills')),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
            children: [
              for (final skill in content.skills)
                _SkillRow(
                  skill: skill,
                  engine: engine,
                  selected: skill.id == selectedId,
                ),
            ],
          ),
        ),
        DetailPanel(children: _detail(strings, engine, selected)),
      ],
    );
  }

  List<Widget> _detail(Strings strings, GameEngine engine, SkillDef skill) {
    final level = engine.state.skillLevel(skill.id);
    final lines = <Widget>[
      PixelText(skill.name, color: Palette.sunYellow.color),
      const _Gap(),
      PixelText(skillDescription(skill, level), wrap: true),
    ];
    if (level > 0 && level < skill.maxLevel) {
      final next = level + 1;
      final value = _number(skill.valueAt(next));
      lines
        ..add(const _Gap())
        ..add(
          PixelText(
            strings.t(
              skill.effect == SkillEffect.bossTimerExtend
                  ? 'skill_next_s'
                  : 'skill_next_x',
              {'n': next, 'v': value},
            ),
            color: Palette.fog.color,
          ),
        );
    } else if (level >= skill.maxLevel) {
      lines
        ..add(const _Gap())
        ..add(
          PixelText(strings.t('skill_maxed_line'), color: Palette.fog.color),
        );
    }
    return lines;
  }
}

class _Gap extends StatelessWidget {
  const _Gap();

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: PixelScale.of(context).px(3));
}

class _SkillRow extends ConsumerWidget {
  const _SkillRow({
    required this.skill,
    required this.engine,
    required this.selected,
  });

  final SkillDef skill;
  final GameEngine engine;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final level = engine.state.skillLevel(skill.id);
    final quote = engine.quoteSkill(skill.id);
    final locked = level == 0 && quote.failure == BuyFailure.locked;
    final maxed = quote.failure == BuyFailure.maxed;
    final cooldown = _number(engine.cooldownOf(skill));
    final art = ref.watch(spriteLibraryProvider).icon(skill.icon);
    return FlashOnIncrease(
      value: level,
      child: ListRow(
        selected: selected,
        onTap: () => ref.read(selectedSkillProvider.notifier).select(skill.id),
        icon: locked
            ? PixelIcons.locked
            : (PixelIcons.byKey(skill.icon) ?? PixelIcons.skillBolt),
        iconWidget: art == null || locked ? null : ArtIcon(art),
        title: locked ? strings.t('skill_locked') : skill.name,
        subtitle: locked
            ? strings.t('row_unlock_short', {'n': skill.unlockFight})
            : strings.t('skill_row_sub', {'n': level, 's': cooldown}),
        trailing: locked || maxed
            ? PixelButton(
                label: locked
                    ? strings.t('row_unlock_short', {'n': skill.unlockFight})
                    : strings.t('buy_max'),
                width: 64,
                onPressed: null,
              )
            : CostButton(
                cost: formatBigShort(quote.cost),
                enabled: quote.canBuy,
                semanticLabel: skill.name,
                onPressed: () {
                  ref.read(selectedSkillProvider.notifier).select(skill.id);
                  ref.read(gameControllerProvider.notifier).buySkill(skill.id);
                },
              ),
      ),
    );
  }
}
