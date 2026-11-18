import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../game/sprite_library.dart';
import '../services/game_controller.dart';
import '../services/tutorial_controller.dart';
import 'art_icon.dart';
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
        child: Row(
          children: [
            // Coins over Belts on the left, the fight in the middle, the
            // trophy and the gear on the right: each side has room for long
            // numbers.
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: scale.px(sideMargin)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TutorialTarget(
                      id: 'hudCoins',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PixelIcon(PixelIcons.coin),
                          SizedBox(width: scale.px(3)),
                          Flexible(
                            child: PixelText(
                              formatBigShort(state.coins),
                              color: Palette.sunYellow.color,
                              ellipsis: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: scale.px(2)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PixelIcon(PixelIcons.belt),
                        SizedBox(width: scale.px(3)),
                        Flexible(
                          child: PixelText(
                            formatBigShort(state.belts),
                            color: Palette.aqua.color,
                            ellipsis: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: debugToolsEnabled
                  ? () =>
                        ref.read(dialogProvider.notifier).open(GameDialog.debug)
                  : null,
              child: PixelText(
                strings.t('hud_fight', {'n': state.fightNumber}),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TutorialTarget(
                    id: 'hud:goals',
                    child: AttentionDot(
                      show: ref
                          .read(gameControllerProvider.notifier)
                          .goalsAttention,
                      child: PixelButton(
                        label: '',
                        icon: PixelIcons.trophy,
                        iconWidget: _artIcon(ref, SpriteLibrary.trophyKey),
                        width: 24,
                        semanticLabel: strings.t('goals_open'),
                        style: PixelButtonStyle.flat,
                        onPressed: () => ref
                            .read(viewProvider.notifier)
                            .show(GameView.goals),
                      ),
                    ),
                  ),
                  PixelButton(
                    label: '',
                    icon: PixelIcons.gear,
                    width: 24,
                    semanticLabel: strings.t('view_settings'),
                    style: PixelButtonStyle.flat,
                    onPressed: () =>
                        ref.read(viewProvider.notifier).show(GameView.settings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shakes its child a few whole pixels sideways when [active] turns on (a
/// tab just picked).
class _Shake extends StatefulWidget {
  const _Shake({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> {
  static const List<int> _steps = [1, -1, 1, -1, 0];
  Timer? _timer;
  int _step = _steps.length - 1;

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _timer?.cancel();
      _step = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        if (!mounted) return t.cancel();
        setState(() => _step++);
        if (_step >= _steps.length - 1) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dx = _steps[_step.clamp(0, _steps.length - 1)];
    return Transform.translate(
      offset: Offset(PixelScale.of(context).px(dx.toDouble()), 0),
      child: widget.child,
    );
  }
}

/// What a locked tab says it needs ("Se desbloquea en la pelea 3").
String _lockedText(WidgetRef ref, GameView view) {
  final strings = ref.read(stringsProvider);
  final content = ref.read(contentProvider);
  switch (view) {
    case GameView.skills:
      final fight = content.skills
          .map((s) => s.unlockFight)
          .reduce((a, b) => a < b ? a : b);
      return strings.t('tab_locked_skills', {'n': fight});
    case GameView.masks:
      final prices = [
        for (final m in content.masks)
          if (m.unlockRule == MaskUnlockRule.belts) m.unlockValue.round(),
      ]..sort();
      return strings.t('tab_locked_masks', {
        'n': prices.isEmpty ? 0 : prices.first,
      });
    case GameView.talents:
      final costs = [
        for (final t in content.talents) t.costs.first.round(),
      ]..sort();
      return strings.t('tab_locked_talents', {'n': costs.first});
    default:
      return '';
  }
}

/// A short text that floats up from a locked tab and fades out.
class LockedHint {
  const LockedHint(this.tab, this.text, this.serial);
  final int tab;
  final String text;
  final int serial;
}

final lockedHintProvider = NotifierProvider<LockedHintNotifier, LockedHint?>(
  LockedHintNotifier.new,
);

class LockedHintNotifier extends Notifier<LockedHint?> {
  int _serial = 0;

  @override
  LockedHint? build() => null;

  void show(int tab, String text) => state = LockedHint(tab, text, ++_serial);

  void clear() => state = null;
}

/// Draws [lockedHintProvider] above the navigation bar: it rises a few
/// pixels and fades out in steps.
class LockedHintLayer extends ConsumerStatefulWidget {
  const LockedHintLayer({super.key});

  @override
  ConsumerState<LockedHintLayer> createState() => _LockedHintLayerState();
}

class _LockedHintLayerState extends ConsumerState<LockedHintLayer> {
  Timer? _timer;
  final Stopwatch _age = Stopwatch();
  int? _serial;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = ref.watch(lockedHintProvider);
    if (hint == null) return const SizedBox.shrink();
    final seconds = ref.read(contentProvider).balance.ui.noticeSeconds;
    if (hint.serial != _serial) {
      _serial = hint.serial;
      _age
        ..reset()
        ..start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
        if (!mounted) return t.cancel();
        if (_age.elapsedMilliseconds >= seconds * 1000) {
          t.cancel();
          ref.read(lockedHintProvider.notifier).clear();
        } else {
          setState(() {});
        }
      });
    }
    final scale = PixelScale.of(context);
    final t = (_age.elapsedMilliseconds / (seconds * 1000)).clamp(0.0, 1.0);
    final rise = (t * 8).floorToDouble();
    // Four steps of fading over the second half (no soft transparency).
    final fade = t < 0.5 ? 1.0 : 1 - ((t - 0.5) * 2 * 4).floor() / 4;
    final tabs = NavBar._tabs.length;
    return Positioned(
      left: 0,
      right: 0,
      bottom: scale.px(navHeight + bottomSafeHeight + 2 + rise),
      child: IgnorePointer(
        child: Opacity(
          opacity: fade.clamp(0.0, 1.0),
          child: Align(
            alignment: Alignment(-1 + (2 * hint.tab + 1) / tabs, 0),
            child: Container(
              color: Palette.ink.color,
              padding: EdgeInsets.all(scale.px(2)),
              constraints: BoxConstraints(maxWidth: scale.px(120)),
              child: PixelText(
                hint.text,
                color: Palette.sunYellow.color,
                align: TextAlign.center,
                wrap: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab's picture ([art] is already the selected or the silhouette version);
/// the code glyph while there is no art.
Widget _tabIcon(
  ui.Image? art,
  PixelIconData glyph, {
  required bool selected,
  required bool locked,
}) {
  final tint = (locked
          ? Palette.dust
          : (selected ? Palette.bone : Palette.fog))
      .color;
  // Selected: the art; otherwise its silhouette picture (`nav_<tab>_off`).
  if (art == null) return PixelIcon(glyph, color: tint);
  return ArtIcon(art);
}

/// Tabs still locked (`ui.lockTabs`): Habilidades until the first skill can
/// be learned, Máscaras until a mask can be bought or a second one is owned,
/// Talentos until a talent can be raised or the mask change is ready. A tab
/// that opened up is remembered and never locks again.
Set<GameView> _lockedTabs(WidgetRef ref) {
  final content = ref.read(contentProvider);
  if (!content.balance.ui.lockTabs) return const {};
  final engine = ref.read(gameControllerProvider.notifier).engine;
  final state = engine.state;
  final open = <GameView>{
    if (content.skills.any(
      (s) => state.skillLevel(s.id) > 0 || engine.quoteSkill(s.id).canBuy,
    ))
      GameView.skills,
    if (state.ownedMasks.length > 1 ||
        content.masks.any((m) => engine.quoteMask(m.id).canBuy))
      GameView.masks,
    if (content.talents.any(
          (t) => state.talentLevel(t.id) > 0 || engine.quoteTalent(t.id).canBuy,
        ) ||
        engine.prestigePreview().canPrestige)
      GameView.talents,
  };
  // A tab whose tutorial step has not begun stays locked even when it could
  // open, so the coach introduces it first.
  final tutorial = ref.read(tutorialProvider.notifier);
  ref.watch(tutorialProvider);
  const introStep = {
    GameView.skills: 'skill',
    GameView.masks: 'masks',
    GameView.talents: 'talents',
  };
  open.removeWhere((v) => !tutorial.reached(introStep[v]!));
  final remembered = ref.watch(settingsProvider).unlockedTabs;
  final fresh = [
    for (final v in open)
      if (!remembered.contains(v.name)) v.name,
  ];
  if (fresh.isNotEmpty) {
    Future.microtask(
      () => ref.read(settingsProvider.notifier).unlockTabs(fresh),
    );
  }
  return {
    for (final v in const [GameView.skills, GameView.masks, GameView.talents])
      if (!open.contains(v) && !remembered.contains(v.name)) v,
  };
}

/// Tabs with something new: a skill to learn, a mask to buy, a talent to
/// raise or a mask change to make.
Set<GameView> _attention(WidgetRef ref) {
  final engine = ref.read(gameControllerProvider.notifier).engine;
  final content = ref.read(contentProvider);
  return {
    if (content.skills.any(
      (s) =>
          engine.state.skillLevel(s.id) == 0 && engine.quoteSkill(s.id).canBuy,
    ))
      GameView.skills,
    if (content.masks.any((m) => engine.quoteMask(m.id).canBuy)) GameView.masks,
    if (engine.prestigePreview().canPrestige ||
        content.talents.any((t) => engine.quoteTalent(t.id).canBuy))
      GameView.talents,
  };
}

/// The picture for [key], or null while there is none (the glyph shows).
Widget? _artIcon(WidgetRef ref, String key) {
  final image = ref.watch(spriteLibraryProvider).icon(key);
  return image == null ? null : ArtIcon(image);
}

/// A small red square on the top-right corner of [child] when [show]: there
/// is something new there (a reward to claim, something to buy).
class AttentionDot extends StatelessWidget {
  const AttentionDot({super.key, required this.show, required this.child});

  final bool show;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    final scale = PixelScale.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: scale.px(2),
          top: scale.px(2),
          width: scale.px(4),
          height: scale.px(4),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.luchaRed.color,
                border: Border.all(
                  color: Palette.ink.color,
                  width: scale.px(1),
                ),
              ),
            ),
          ),
        ),
      ],
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
    ref.watch(gameControllerProvider);
    final dots = _attention(ref);
    final locked = _lockedTabs(ref);
    final sprites = ref.watch(spriteLibraryProvider);
    return SizedBox(
      height: scale.px(navHeight),
      child: Row(
        children: [
          for (final (view, icon, labelKey) in _tabs)
            Expanded(
              child: TutorialTarget(
                id: 'nav:${view.name}',
                child: Semantics(
                  button: true,
                  selected: view == selected,
                  label: strings.t(labelKey),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: locked.contains(view)
                        ? () => ref
                              .read(lockedHintProvider.notifier)
                              .show(
                                _tabs.indexWhere((t) => t.$1 == view),
                                _lockedText(ref, view),
                              )
                        : () => ref.read(viewProvider.notifier).show(view),
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
                            child: _Shake(
                              active: view == selected,
                              child: _tabIcon(
                              locked.contains(view)
                                  ? null
                                  : sprites.icon(
                                      (view == selected
                                          ? SpriteLibrary.navKey
                                          : SpriteLibrary.navOffKey)(
                                        view == GameView.fight
                                            ? 'upgrades'
                                            : view.name,
                                      ),
                                    ),
                              locked.contains(view) ? PixelIcons.locked : icon,
                              selected: view == selected,
                              locked: locked.contains(view),
                            ),
                            ),
                          ),
                          if (view != selected &&
                              !locked.contains(view) &&
                              dots.contains(view))
                            Positioned.fill(
                              child: AttentionDot(
                                show: true,
                                child: const SizedBox.expand(),
                              ),
                            ),
                        ],
                      ),
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
