import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../game/sprite_library.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import 'art_icon.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

/// "3 h 20 min" / "45 min".
String formatAway(Strings strings, double seconds) {
  final minutes = (seconds / 60).floor();
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0
      ? strings.t('time_hm', {'h': h, 'm': m})
      : strings.t('time_m', {'m': m});
}

/// "¡NUEVA MÁSCARA!": what resets, what stays and the Belts and damage to gain.
class PrestigeDialog extends ConsumerWidget {
  const PrestigeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final preview = engine.prestigePreview();
    final bonus = engine.content.balance.prestige.beltDamageBonus;
    final damagePercent = (preview.beltsToEarn.toDouble() * bonus * 100)
        .round();
    return PixelDialog(
      title: strings.t('prestige_title_big'),
      body: [
        PixelText(
          strings.t('prestige_resets_short'),
          wrap: true,
          color: Palette.fog.color,
        ),
        SizedBox(height: scale.px(4)),
        PixelText(
          strings.t('prestige_keeps_short'),
          wrap: true,
          color: Palette.fog.color,
        ),
        SizedBox(height: scale.px(6)),
        if (preview.canPrestige) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PixelIcon(PixelIcons.belt, size: 16),
              SizedBox(width: scale.px(4)),
              PixelText(
                strings.t('prestige_belts_short', {
                  'n': formatBig(preview.beltsToEarn),
                }),
                size: 16,
                color: Palette.aqua.color,
                shadow: Palette.ink.color,
              ),
            ],
          ),
          SizedBox(height: scale.px(4)),
          PixelText(
            strings.t('prestige_belts', {'n': formatBig(preview.beltsToEarn)}),
            align: TextAlign.center,
            wrap: true,
          ),
          SizedBox(height: scale.px(2)),
          PixelText(
            strings.t('prestige_damage', {'n': damagePercent}),
            align: TextAlign.center,
            wrap: true,
            color: Palette.sunYellow.color,
          ),
        ] else
          PixelText(
            strings.t('prestige_not_yet'),
            align: TextAlign.center,
            wrap: true,
            color: Palette.coral.color,
          ),
      ],
      actions: [
        PixelButton(
          label: strings.t('prestige_confirm'),
          style: PixelButtonStyle.confirm,
          onPressed: preview.canPrestige
              ? () {
                  ref.read(gameControllerProvider.notifier).prestige();
                  ref.read(dialogProvider.notifier).close();
                  ref.read(viewProvider.notifier).show(GameView.fight);
                }
              : null,
        ),
        PixelButton(
          label: strings.t('dialog_back'),
          style: PixelButtonStyle.secondary,
          onPressed: () => ref.read(dialogProvider.notifier).close(),
        ),
      ],
    );
  }
}

/// "¡BIENVENIDO!": time away, coins earned, collect or watch an ad to double.
/// Failing or declining the ad never blocks the base reward.
class OfflineDialog extends ConsumerStatefulWidget {
  const OfflineDialog({super.key});

  @override
  ConsumerState<OfflineDialog> createState() => _OfflineDialogState();
}

class _OfflineDialogState extends ConsumerState<OfflineDialog> {
  bool _watching = false;
  bool _adFailed = false;

  Future<void> _watchAd() async {
    setState(() {
      _watching = true;
      _adFailed = false;
    });
    final ok = await ref
        .read(gameControllerProvider.notifier)
        .collectOffline(watchAd: true);
    if (!mounted) return;
    setState(() {
      _watching = false;
      _adFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final report = ref.watch(
      gameControllerProvider.select((s) => s.pendingOffline),
    );
    if (report == null) return const SizedBox.shrink();
    return PixelDialog(
      title: strings.t('offline_welcome'),
      body: [
        PixelText(
          strings.t('offline_away_short'),
          align: TextAlign.center,
          color: Palette.fog.color,
        ),
        SizedBox(height: scale.px(3)),
        PixelText(
          formatAway(strings, report.awaySeconds),
          align: TextAlign.center,
          wrap: true,
        ),
        SizedBox(height: scale.px(6)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const PixelIcon(PixelIcons.coin, size: 16),
            SizedBox(width: scale.px(4)),
            PixelText(
              '+${formatBigShort(report.coinsEarned)}',
              size: 16,
              color: Palette.sunYellow.color,
              shadow: Palette.ink.color,
            ),
          ],
        ),
        if (report.capped) ...[
          SizedBox(height: scale.px(6)),
          PixelText(
            strings.t('offline_cap_hint', {
              'h': (report.capSeconds / 3600).toStringAsFixed(
                report.capSeconds % 3600 == 0 ? 0 : 1,
              ),
            }),
            wrap: true,
            align: TextAlign.center,
            color: Palette.fog.color,
          ),
        ],
        if (_adFailed) ...[
          SizedBox(height: scale.px(6)),
          PixelText(
            strings.t('offline_ad_failed'),
            wrap: true,
            align: TextAlign.center,
            color: Palette.coral.color,
          ),
        ],
      ],
      actions: [
        PixelButton(
          label: strings.t('offline_double_short'),
          icon: PixelIcons.adWatch,
          semanticLabel: strings.t('offline_double'),
          style: PixelButtonStyle.secondary,
          onPressed: _watching ? null : _watchAd,
        ),
        PixelButton(
          label: strings.t('offline_collect_short'),
          semanticLabel: strings.t('offline_collect'),
          style: PixelButtonStyle.confirm,
          onPressed: _watching
              ? null
              : () =>
                    ref.read(gameControllerProvider.notifier).collectOffline(),
        ),
      ],
    );
  }
}

/// Privacy policy placeholder: the real text and link come before launch.
class PrivacyDialog extends ConsumerWidget {
  const PrivacyDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return PixelDialog(
      title: strings.t('privacy_title'),
      body: [PixelText(strings.t('privacy_text'), wrap: true)],
      actions: [
        PixelButton(
          label: strings.t('dialog_close'),
          style: PixelButtonStyle.secondary,
          onPressed: () => ref.read(dialogProvider.notifier).close(),
        ),
      ],
    );
  }
}

/// Confirmation before deleting the save (destructive actions always ask).
class DeleteDataDialog extends ConsumerWidget {
  const DeleteDataDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return PixelDialog(
      title: strings.t('delete_title'),
      body: [
        PixelText(
          strings.t('delete_text'),
          wrap: true,
          color: Palette.fog.color,
        ),
      ],
      actions: [
        PixelButton(
          label: strings.t('delete_confirm'),
          style: PixelButtonStyle.danger,
          onPressed: () async {
            ref.read(dialogProvider.notifier).close();
            await ref.read(gameControllerProvider.notifier).deleteAllData();
            ref.read(viewProvider.notifier).show(GameView.fight);
          },
        ),
        PixelButton(
          label: strings.t('dialog_back'),
          style: PixelButtonStyle.secondary,
          onPressed: () => ref.read(dialogProvider.notifier).close(),
        ),
      ],
    );
  }
}

/// Debug panel: add coins, skip fights, fast-forward time, simulate an absence.
/// Reached by long-pressing the fight number, in debug builds only.
class DebugDialog extends ConsumerWidget {
  const DebugDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final debug = ref.watch(contentProvider).balance.debug;
    final controller = ref.read(gameControllerProvider.notifier);
    Widget row(List<Widget> buttons) => Padding(
      padding: EdgeInsets.only(bottom: scale.px(2)),
      child: Row(
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) SizedBox(width: scale.px(2)),
            Expanded(child: buttons[i]),
          ],
        ],
      ),
    );
    Widget label(String key) => Padding(
      padding: EdgeInsets.only(bottom: scale.px(2)),
      child: PixelText(strings.t(key), color: Palette.fog.color),
    );
    return PixelDialog(
      title: strings.t('debug_title'),
      body: [
        label('debug_row_coins'),
        row([
          for (final amount in debug.coinAmounts)
            PixelButton(
              label: strings.t('debug_add_coins', {
                'n': formatBig(Big.fromDouble(amount)),
              }),
              style: PixelButtonStyle.secondary,
              onPressed: () => controller.debugAddCoins(amount),
            ),
        ]),
        label('debug_row_fight'),
        row([
          PixelButton(
            label: strings.t('debug_skip_fight'),
            style: PixelButtonStyle.secondary,
            onPressed: controller.debugSkipFight,
          ),
          PixelButton(
            label: strings.t('debug_skip_boss'),
            style: PixelButtonStyle.secondary,
            onPressed: controller.debugGoToBoss,
          ),
        ]),
        label('debug_row_time'),
        row([
          for (final m in debug.fastForwardMinutes)
            PixelButton(
              label: strings.t('debug_fast_forward', {'n': m}),
              style: PixelButtonStyle.secondary,
              onPressed: () => controller.debugFastForward(m),
            ),
        ]),
        label('debug_row_away'),
        row([
          for (final h in debug.absenceHours)
            PixelButton(
              label: strings.t('debug_absence', {'n': h}),
              style: PixelButtonStyle.secondary,
              onPressed: () {
                controller.debugSimulateAbsence(h);
                ref.read(dialogProvider.notifier).close();
              },
            ),
        ]),
        row([
          PixelButton(
            label: strings.t('debug_save'),
            style: PixelButtonStyle.confirm,
            onPressed: controller.saveNow,
          ),
        ]),
      ],
      actions: [
        PixelButton(
          label: strings.t('dialog_close'),
          onPressed: () => ref.read(dialogProvider.notifier).close(),
        ),
      ],
    );
  }
}

/// Whether the debug panel may be opened in this build.
bool get debugToolsEnabled => kDebugMode;

/// What an upgrade or trainer does, its level and its next milestone; for a
/// locked trainer, how to unlock it. Opened with the "i" on the row.
class InfoDialog extends ConsumerWidget {
  const InfoDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final target = ref.watch(infoTargetProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final milestones = content.balance.milestones;
    final body = <Widget>[];
    var title = '';

    void line(String text, {Color? color}) {
      body.add(PixelText(text, wrap: true, color: color));
      body.add(const SizedBox(height: 4));
    }

    int levelAndMilestone(int level) {
      line(
        strings.t('info_level', {'n': level}),
        color: Palette.sunYellow.color,
      );
      final next = milestones.nextAfter(level);
      line(
        next == null
            ? strings.t('info_all_milestones')
            : strings.t('info_next_milestone', {
                'n': next,
                'm': milestones.multiplier.round(),
              }),
        color: Palette.fog.color,
      );
      return level;
    }

    if (target != null && target.kind == InfoKind.upgrade) {
      final u = content.upgrades.firstWhere((u) => u.id == target.id);
      title = u.name;
      final value = u.effect == UpgradeEffect.critChance
          ? formatBigShort(Big.fromDouble(u.perLevelValue * 100))
          : formatBigShort(Big.fromDouble(u.perLevelValue));
      line(u.description.replaceAll('{n}', value));
      levelAndMilestone(engine.state.upgradeLevel(u.id));
    } else if (target != null) {
      final t = content.trainers.firstWhere((t) => t.id == target.id);
      if (!engine.isTrainerUnlocked(t)) {
        title = strings.t('info_locked_title');
        line(strings.t('info_locked', {'n': t.unlockFight}));
      } else {
        title = t.name;
        final portrait = ref
            .watch(spriteLibraryProvider)
            .icon(SpriteLibrary.portraitBigKey(t.portrait));
        if (portrait != null) {
          body.add(Center(child: ArtIcon(portrait, size: 48)));
          body.add(const SizedBox(height: 4));
        }
        line(
          t.description.replaceAll(
            '{d}',
            formatBigShort(Big.fromDouble(t.baseDps)),
          ),
        );
        levelAndMilestone(engine.state.trainerLevel(t.id));
      }
    }
    return PixelDialog(
      title: title,
      body: body,
      actions: [
        PixelButton(
          label: strings.t('info_close'),
          style: PixelButtonStyle.secondary,
          onPressed: () => ref.read(dialogProvider.notifier).close(),
        ),
      ],
    );
  }
}
