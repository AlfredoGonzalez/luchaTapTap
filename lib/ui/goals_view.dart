import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/game_engine.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../data/goals_models.dart';
import '../game/sprite_library.dart';
import '../services/game_controller.dart';
import '../services/localized_text.dart';
import '../services/strings.dart';
import 'art_icon.dart';
import 'hud.dart';
import 'masks_view.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'rows.dart';
import 'tutorial_overlay.dart';
import 'ui_state.dart';

/// Width of the claim button (and of the progress text in its place).
const double _claimWidth = 48;

String _count(int n) => formatBigShort(Big.fromInt(n));

String _plain(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v.toStringAsFixed(1);

/// Text of a counter goal ("Vence 15 peleas"); uses the `_1` form for one.
String goalText(Strings strings, GoalCounter counter, int target) {
  final single = 'goal_${counter.name}_1';
  if (target == 1 && strings.has(single)) return strings.t(single);
  return strings.t('goal_${counter.name}', {'n': _count(target)});
}

/// What a reward gives, in words ("+2 cinturones · +1.2K monedas").
String rewardText(Strings strings, GameEngine engine, RewardDef reward) {
  final parts = <String>[
    if (reward.belts == 1) strings.t('reward_belts_1'),
    if (reward.belts > 1) strings.t('reward_belts', {'n': reward.belts}),
    if (reward.fightCoins > 0)
      strings.t('reward_coins', {
        'n': formatBigShort(engine.rewardCoins(reward.fightCoins)),
      }),
    if (reward.boostSeconds > 0)
      strings.t('reward_boost', {
        'm': _plain(reward.boostMultiplier),
        't': (reward.boostSeconds / 60).ceil(),
      }),
  ];
  return parts.join(' · ');
}

/// Small icon of the main part of a reward (Belt, coin or boost).
PixelIconData rewardIcon(RewardDef reward) => reward.belts > 0
    ? PixelIcons.belt
    : (reward.fightCoins > 0 ? PixelIcons.coin : PixelIcons.shopDouble);

/// The 8-pixel picture of a calendar reward (the boost has art).
Widget _rewardPicture(WidgetRef ref, RewardDef reward) {
  final icon = rewardIcon(reward);
  final art = ref.watch(spriteLibraryProvider).icon(SpriteLibrary.boostSmallKey);
  if (icon == PixelIcons.shopDouble && art != null) return ArtIcon(art, size: 8);
  return PixelIcon(icon, size: 8);
}

/// "METAS": the 7-day calendar, today's goals with their chest, and the
/// achievements.
class GoalsView extends ConsumerWidget {
  const GoalsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = controller.engine;
    final content = ref.watch(contentProvider);

    final achievements = [...content.achievements];
    int rank(AchievementDef a) => engine.achievementClaimable(a)
        ? 0
        : (engine.achievementClaimed(a) ? 2 : 1);
    achievements.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final fa = engine.counterValue(a.counter) / a.target;
      final fb = engine.counterValue(b.counter) / b.target;
      return fb.compareTo(fa);
    });

    return Column(
      children: [
        ViewTitleBar(title: strings.t('view_goals')),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
            children: [
              for (final event in controller.activeEvents)
                if (event.goals.isNotEmpty) ..._eventSection(ref, strings, event),
              TutorialTarget(
                id: 'goals:login',
                child: Column(
                  children: [
                    SectionHeader(strings.t('goals_login')),
                    const LoginCalendar(),
                    SizedBox(height: scale.px(rowGap)),
                    _loginButton(context, ref, strings),
                  ],
                ),
              ),
              TutorialTarget(
                id: 'goals:daily',
                child: SectionHeader(strings.t('goals_daily')),
              ),
              ..._dailySection(context, ref, strings),
              TutorialTarget(
                id: 'goals:achievements',
                child: SectionHeader(strings.t('goals_achievements')),
              ),
              for (final a in achievements)
                _GoalRow(
                  icon: PixelIcons.trophy,
                  artKey: SpriteLibrary.trophyKey,
                  title: strings.achievementName(a),
                  subtitle: goalText(strings, a.counter, a.target),
                  reward: a.reward,
                  value: engine.counterValue(a.counter),
                  target: a.target,
                  claimable: engine.achievementClaimable(a),
                  claimed: engine.achievementClaimed(a),
                  onClaim: () => controller.claimAchievement(a.id),
                ),
              SizedBox(height: scale.px(rowGap)),
            ],
          ),
        ),
      ],
    );
  }

  /// Today's goals: ready to claim first, then the closest to done, the
  /// claimed ones last. When all are claimed, when new ones come (and new
  /// ones for an ad). Each open goal may be swapped for an ad.
  List<Widget> _dailySection(
    BuildContext context,
    WidgetRef ref,
    Strings strings,
  ) {
    final scale = PixelScale.of(context);
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = controller.engine;
    final content = ref.read(contentProvider);
    final goals = [...engine.dailyGoals];
    int rank(DailyGoalDef g) => engine.dailyClaimable(g)
        ? 0
        : (engine.dailyClaimed(g) ? 2 : 1);
    goals.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      return (engine.dailyProgress(b) / b.target).compareTo(
        engine.dailyProgress(a) / a.target,
      );
    });
    Future<void> ad(Future<ShopResult> Function() call) async {
      final result = await call();
      if (result == ShopResult.noAd) {
        ref.read(noticeProvider.notifier).show('goals_no_ad');
      }
    }

    final chest = _GoalRow(
      icon: PixelIcons.chest,
      artKey: SpriteLibrary.chestKey,
      title: strings.t('goals_chest'),
      reward: content.goals.chest,
      value: goals.where(engine.dailyClaimed).length,
      target: goals.length,
      claimable: engine.dailyChestReady,
      claimed: engine.state.daily.chestClaimed,
      onClaim: controller.claimDailyChest,
    );
    if (engine.dailyAllClaimed) {
      final left = controller.untilTomorrow;
      final clock =
          '${left.inHours}:${(left.inMinutes % 60).toString().padLeft(2, '0')}';
      return [
        if (!engine.state.daily.chestClaimed) chest,
        Padding(
          padding: EdgeInsets.symmetric(vertical: scale.px(4)),
          child: Column(
            children: [
              PixelText(
                strings.t('goals_done'),
                color: Palette.sunYellow.color,
                align: TextAlign.center,
                wrap: true,
              ),
              SizedBox(height: scale.px(2)),
              PixelText(
                strings.t('goals_next_in', {'t': clock}),
                color: Palette.fog.color,
                align: TextAlign.center,
              ),
              if (engine.canRefreshDaily) ...[
                SizedBox(height: scale.px(4)),
                PixelButton(
                  label: strings.t('goals_ad_new'),
                  icon: PixelIcons.adWatch,
                  width: 96,
                  style: PixelButtonStyle.secondary,
                  onPressed: () => ad(controller.refreshGoals),
                ),
              ],
            ],
          ),
        ),
      ];
    }
    return [
      for (final g in goals)
        _GoalRow(
          icon: PixelIcons.skillStar,
          artKey: SpriteLibrary.goalKey,
          title: goalText(strings, g.counter, g.target),
          reward: g.reward,
          value: engine.dailyProgress(g),
          target: g.target,
          claimable: engine.dailyClaimable(g),
          claimed: engine.dailyClaimed(g),
          onClaim: () => controller.claimDailyGoal(g.id),
          onSwap: engine.canRerollDaily(g)
              ? () => ad(() => controller.rerollGoal(g.id))
              : null,
        ),
      if (goals.isNotEmpty) chest,
    ];
  }

  /// A running event with goals: each goal, then its mask.
  List<Widget> _eventSection(WidgetRef ref, Strings strings, EventDef event) {
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = controller.engine;
    final content = ref.read(contentProvider);
    final mask = content.mask(event.rewardMask!);
    final done = event.goals
        .where((g) => engine.eventProgress(event, g) >= g.target)
        .length;
    final owned = engine.ownsMask(mask.id);
    return [
      SectionHeader(strings.t('goals_event', {'name': strings.eventName(event)})),
      for (final g in event.goals)
        _GoalRow(
          icon: PixelIcons.skillStar,
          artKey: SpriteLibrary.goalKey,
          title: goalText(strings, g.counter, g.target),
          rewardLine: '',
          value: engine.eventProgress(event, g),
          target: g.target,
          claimable: false,
          claimed: owned,
          onClaim: () {},
        ),
      _GoalRow(
        icon: PixelIcons.trophy,
        iconWidget: maskIcon(ref, mask),
        title: strings.t('goals_event_mask', {'name': mask.name}),
        subtitle: owned ? null : strings.t('goals_event_hint'),
        rewardLine: maskBonusText(strings, mask),
        value: done,
        target: event.goals.length,
        claimable: engine.eventMaskReady(event),
        claimed: owned,
        onClaim: () => controller.claimEventMask(event.id),
      ),
    ];
  }

  Widget _loginButton(BuildContext context, WidgetRef ref, Strings strings) {
    final controller = ref.read(gameControllerProvider.notifier);
    final ready = controller.loginReady;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ready
            ? PixelButton(
                label: strings.t('goals_claim'),
                width: 72,
                style: PixelButtonStyle.gold,
                onPressed: controller.claimLogin,
              )
            : SizedBox(
                height: PixelScale.of(context).px(24),
                child: Center(
                  child: PixelText(
                    strings.t('goals_login_done'),
                    color: Palette.fog.color,
                  ),
                ),
              ),
      ],
    );
  }
}

/// One goal: icon, text, reward, progress bar and the claim button (or the
/// progress, or "Listo").
class _GoalRow extends ConsumerWidget {
  const _GoalRow({
    required this.icon,
    required this.title,
    this.reward,
    required this.value,
    required this.target,
    required this.claimable,
    required this.claimed,
    required this.onClaim,
    this.subtitle,
    this.artKey,
    this.rewardLine,
    this.iconWidget,
    this.onSwap,
  });

  /// Shows a small "swap (ad)" button under the progress.
  final VoidCallback? onSwap;

  final PixelIconData icon;

  /// Replaces the icon entirely (an event mask in its colors).
  final Widget? iconWidget;

  /// Text in place of [reward]'s (an event mask, or nothing).
  final String? rewardLine;

  /// Picture shown instead of [icon] when it exists.
  final String? artKey;
  final String title;
  final String? subtitle;
  final RewardDef? reward;
  final int value;
  final int target;
  final bool claimable;
  final bool claimed;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final shown = value > target ? target : value;
    final Widget trailing;
    if (claimable) {
      trailing = PixelButton(
        label: strings.t('goals_claim'),
        width: _claimWidth,
        style: PixelButtonStyle.gold,
        semanticLabel: '${strings.t('goals_claim')} $title',
        onPressed: onClaim,
      );
    } else {
      final progress = PixelText(
        claimed
            ? strings.t('goals_claimed')
            : strings.t('goals_progress', {
                'a': _count(shown),
                'b': _count(target),
              }),
        color: (claimed ? Palette.lime : Palette.fog).color,
      );
      trailing = SizedBox(
        width: PixelScale.of(context).px(_claimWidth),
        child: onSwap == null
            ? Center(child: progress)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  progress,
                  SizedBox(height: PixelScale.of(context).px(2)),
                  PixelButton(
                    label: strings.t('goals_reroll'),
                    icon: PixelIcons.adWatch,
                    width: _claimWidth,
                    style: PixelButtonStyle.secondary,
                    semanticLabel: '${strings.t('goals_reroll_label')}: $title',
                    onPressed: onSwap,
                  ),
                ],
              ),
      );
    }
    final scale = PixelScale.of(context);
    final row = DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Palette.slate.color, width: scale.px(1)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: scale.px(3)),
        child: Row(
          children: [
            SizedBox(width: scale.px(2)),
            if (iconWidget != null)
              iconWidget!
            else if (artKey != null &&
                ref.watch(spriteLibraryProvider).icon(artKey!) != null)
              ArtIcon(ref.watch(spriteLibraryProvider).icon(artKey!)!)
            else
              PixelIcon(icon, color: Palette.bone.color),
            SizedBox(width: scale.px(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(
                    title,
                    color: (claimed ? Palette.fog : Palette.bone).color,
                    wrap: true,
                    maxLines: 2,
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: scale.px(2)),
                    PixelText(
                      subtitle!,
                      color: Palette.fog.color,
                      wrap: true,
                      maxLines: 2,
                    ),
                  ],
                  if (rewardLine != '') ...[
                    SizedBox(height: scale.px(2)),
                    PixelText(
                      rewardLine ?? rewardText(strings, engine, reward!),
                      color: (claimed ? Palette.dust : Palette.marigold).color,
                      wrap: true,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: scale.px(2)),
            trailing,
            SizedBox(width: scale.px(2)),
          ],
        ),
      ),
    );
    final bar = claimed ? null : shown / target;
    return Padding(
      padding: EdgeInsets.only(bottom: scale.px(rowGap)),
      child: bar == null
          ? row
          : Stack(
              children: [
                row,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: scale.px(1),
                  child: Row(
                    children: [
                      Expanded(
                        flex: (bar * 1000).round(),
                        child: ColoredBox(color: Palette.sunYellow.color),
                      ),
                      Expanded(
                        flex: 1000 - (bar * 1000).round(),
                        child: ColoredBox(color: Palette.slate.color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The 7 days of the calendar: claimed days dimmed, the next one framed.
class LoginCalendar extends ConsumerWidget {
  const LoginCalendar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final rewards = ref.watch(contentProvider).goals.loginRewards;
    final next = controller.engine.loginIndex;
    final ready = controller.loginReady;
    return Row(
      children: [
        for (var i = 0; i < rewards.length; i++) ...[
          if (i > 0) SizedBox(width: scale.px(1)),
          Expanded(
            child: Container(
              height: scale.px(30),
              decoration: BoxDecoration(
                color: (i < next ? Palette.ink : Palette.nightPurple).color,
                border: Border.all(
                  color: (i == next && ready ? Palette.marigold : Palette.slate)
                      .color,
                  width: scale.px(1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PixelText(
                    '${i + 1}',
                    color: (i < next ? Palette.dust : Palette.bone).color,
                  ),
                  SizedBox(height: scale.px(2)),
                  Opacity(
                    opacity: i < next ? 0.4 : 1,
                    child: _rewardPicture(ref, rewards[i]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Shown once a day when the calendar reward is waiting (after the first
/// minutes): the calendar and "Cobrar".
class DailyRewardDialog extends ConsumerWidget {
  const DailyRewardDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final rewards = ref.watch(contentProvider).goals.loginRewards;
    final index = controller.engine.loginIndex;
    return PixelDialog(
      title: strings.t('daily_title'),
      body: [
        const LoginCalendar(),
        SizedBox(height: PixelScale.of(context).px(4)),
        PixelText(
          rewardText(strings, controller.engine, rewards[index]),
          color: Palette.sunYellow.color,
          wrap: true,
        ),
        PixelText(
          strings.t('daily_text', {'n': index + 1, 'total': rewards.length}),
          color: Palette.fog.color,
          wrap: true,
        ),
      ],
      actions: [
        PixelButton(
          label: strings.t('daily_later'),
          style: PixelButtonStyle.secondary,
          onPressed: () => ref.read(dailyPopupDismissedProvider.notifier).set(),
        ),
        PixelButton(
          label: strings.t('goals_claim'),
          style: PixelButtonStyle.gold,
          onPressed: controller.claimLogin,
        ),
      ],
    );
  }
}
