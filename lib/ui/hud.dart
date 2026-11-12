import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/palette.dart';
import '../services/game_controller.dart';
import 'dialogs.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'tutorial_overlay.dart';
import 'ui_state.dart';

const double topSafeHeight = 12;
const double hudHeight = 24;
const double titleBarHeight = 18;
const double navHeight = 24;
const double bottomSafeHeight = 8;
const double sideMargin = 4;

/// Coins on the left, fight number in the middle, Belts and the settings gear
/// on the right. Long-press the fight number for the debug panel (debug builds).
class HudBar extends ConsumerWidget {
  const HudBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    return SizedBox(
      height: scale.px(hudHeight),
      child: ColoredBox(
        color: Palette.nightPurple.color,
        child: Padding(
          padding: EdgeInsets.only(left: scale.px(sideMargin)),
          child: Row(
            children: [
              Expanded(
                child: TutorialTarget(
                  id: 'hudCoins',
                  child: Row(
                  children: [
                    const PixelIcon(PixelIcons.coin),
                    SizedBox(width: scale.px(3)),
                    Flexible(
                      child: PixelText(
                        formatBigShort(state.coins),
                        color: Palette.sunYellow.color,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: debugToolsEnabled
                    ? () => ref
                          .read(dialogProvider.notifier)
                          .open(GameDialog.debug)
                    : null,
                child: PixelText(
                  strings.t('hud_fight', {'n': state.fightNumber}),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const PixelIcon(PixelIcons.belt),
                    SizedBox(width: scale.px(3)),
                    Flexible(
                      child: PixelText(
                        formatBigShort(state.belts),
                        color: Palette.aqua.color,
                      ),
                    ),
                    PixelButton(
                      label: '',
                      icon: PixelIcons.gear,
                      width: 24,
                      semanticLabel: strings.t('view_settings'),
                      style: PixelButtonStyle.flat,
                      onPressed: () => ref
                          .read(viewProvider.notifier)
                          .show(GameView.settings),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Title strip of a full view, with optional text on the right.
class ViewTitleBar extends StatelessWidget {
  const ViewTitleBar({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return SizedBox(
      height: scale.px(titleBarHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.nightPurple.color,
          border: Border(
            bottom: BorderSide(color: Palette.slate.color, width: scale.px(1)),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PixelText(title, color: Palette.sunYellow.color),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation: five icon tabs. The selected tab sits on Night Purple
/// with a Marigold line on top.
class NavBar extends ConsumerWidget {
  const NavBar({super.key});

  static const _tabs = [
    (GameView.fight, PixelIcons.navUpgrades, 'tab_upgrades'),
    (GameView.skills, PixelIcons.navSkills, 'tab_skills'),
    (GameView.masks, PixelIcons.navMasks, 'tab_masks'),
    (GameView.talents, PixelIcons.navTalents, 'tab_talents'),
    (GameView.shop, PixelIcons.navShop, 'tab_shop'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final selected = ref.watch(viewProvider);
    final strings = ref.watch(stringsProvider);
    return SizedBox(
      height: scale.px(navHeight),
      child: Row(
        children: [
          for (final (view, icon, labelKey) in _tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: view == selected,
                label: strings.t(labelKey),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(viewProvider.notifier).show(view),
                  child: ColoredBox(
                    color:
                        (view == selected ? Palette.nightPurple : Palette.ink)
                            .color,
                    child: Stack(
                      children: [
                        if (view == selected)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: scale.px(1),
                            child: ColoredBox(color: Palette.marigold.color),
                          ),
                        Center(
                          child: PixelIcon(
                            icon,
                            color:
                                (view == selected ? Palette.bone : Palette.fog)
                                    .color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
