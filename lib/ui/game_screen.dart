import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'boss_intro.dart';
import 'dialogs.dart';
import 'fight_view.dart';
import 'hud.dart';
import 'masks_view.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'settings_view.dart';
import 'shop_view.dart';
import 'skills_view.dart';
import 'talents_view.dart';
import 'ui_state.dart';

/// The game: HUD on top, the current view in the middle and the navigation bar
/// below. Pop-ups and the boss intro sit on top of everything.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final view = ref.watch(viewProvider);
    final dialog = ref.watch(dialogProvider);
    final state = ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final hasOffline = state.pendingOffline != null;
    final bossIntro = engine.awaitingBossStart && !hasOffline && dialog == null;

    final contentHeight =
        scale.virtualHeight -
        (topSafeHeight + hudHeight + navHeight + bottomSafeHeight);

    return PopScope(
      // The Android back button closes pop-ups and returns from other views;
      // the offline pop-up collects the base amount (it never blocks the
      // reward) and the boss intro stays until "¡A PELEAR!".
      canPop:
          view == GameView.fight && dialog == null && !hasOffline && !bossIntro,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (hasOffline) {
          ref.read(gameControllerProvider.notifier).collectOffline();
        } else if (dialog != null) {
          ref.read(dialogProvider.notifier).close();
        } else if (!bossIntro) {
          ref.read(viewProvider.notifier).back();
        }
      },
      child: Stack(
        children: [
          ColoredBox(
            color: Palette.ink.color,
            child: Column(
              children: [
                SizedBox(height: scale.px(topSafeHeight)),
                const HudBar(),
                SizedBox(
                  height: scale.px(contentHeight),
                  child: Stack(
                    children: [
                      // The fight stays mounted (but hidden) so the arena keeps
                      // running while another view is open.
                      Offstage(
                        offstage: view != GameView.fight,
                        child: FightView(height: contentHeight),
                      ),
                      if (view != GameView.fight) _viewFor(view),
                    ],
                  ),
                ),
                const NavBar(),
                SizedBox(height: scale.px(bottomSafeHeight)),
              ],
            ),
          ),
          if (dialog == GameDialog.prestige) const PrestigeDialog(),
          if (dialog == GameDialog.debug) const DebugDialog(),
          if (dialog == GameDialog.privacy) const PrivacyDialog(),
          if (dialog == GameDialog.info) const InfoDialog(),
          if (dialog == GameDialog.deleteData) const DeleteDataDialog(),
          if (hasOffline) const OfflineDialog(),
          if (bossIntro) const BossIntro(),
        ],
      ),
    );
  }

  Widget _viewFor(GameView view) => switch (view) {
    GameView.skills => const SkillsView(),
    GameView.masks => const MasksView(),
    GameView.talents => const TalentsView(),
    GameView.shop => const ShopView(),
    GameView.settings => const SettingsView(),
    GameView.credits => const CreditsView(),
    GameView.fight => const SizedBox.shrink(),
  };
}
