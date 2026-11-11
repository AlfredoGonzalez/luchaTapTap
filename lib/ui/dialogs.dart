import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

String _duration(dynamic strings, double seconds) {
  final minutes = (seconds / 60).floor();
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0
      ? strings.t('time_hm', {'h': h, 'm': m}) as String
      : strings.t('time_m', {'m': m}) as String;
}

/// "Cambiar de máscara": what resets, what stays and the belts to earn.
class PrestigeDialog extends ConsumerWidget {
  const PrestigeDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    ref.watch(gameControllerProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final preview = engine.prestigePreview();
    return PixelDialog(
      title: strings.t('prestige_title'),
      body: [
        PixelText(
          preview.canPrestige
              ? strings.t('prestige_earn', {'n': formatBig(preview.beltsToEarn)})
              : strings.t('prestige_not_yet'),
          color: Palette.sunYellow.color,
          align: TextAlign.center,
          wrap: true,
        ),
        const SizedBox(height: 6),
        PixelText(strings.t('prestige_resets'), wrap: true, color: Palette.fog.color),
        const SizedBox(height: 4),
        PixelText(strings.t('prestige_keeps'), wrap: true, color: Palette.fog.color),
      ],
      actions: [
        PixelButton(
          label: strings.t('prestige_confirm'),
          style: PixelButtonStyle.confirm,
          onPressed: preview.canPrestige
              ? () {
                  ref.read(gameControllerProvider.notifier).prestige();
                  ref.read(dialogProvider.notifier).close();
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

/// "Ganancias sin conexión": time away, coins earned, collect or watch an ad
/// to double. Failing or declining the ad never blocks the base reward.
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
    final ok = await ref.read(gameControllerProvider.notifier).collectOffline(watchAd: true);
    if (!mounted) return;
    setState(() {
      _watching = false;
      _adFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final report = ref.watch(gameControllerProvider.select((s) => s.pendingOffline));
    if (report == null) return const SizedBox.shrink();
    return PixelDialog(
      title: strings.t('offline_title'),
      body: [
        PixelText(strings.t('offline_away', {'t': _duration(strings, report.awaySeconds)}),
            wrap: true, align: TextAlign.center),
        const SizedBox(height: 4),
        PixelText(strings.t('offline_coins', {'n': formatBig(report.coinsEarned)}),
            wrap: true, align: TextAlign.center, color: Palette.sunYellow.color),
        if (report.capped) ...[
          const SizedBox(height: 4),
          PixelText(
            strings.t('offline_capped', {'h': (report.capSeconds / 3600).toStringAsFixed(report.capSeconds % 3600 == 0 ? 0 : 1)}),
            wrap: true,
            align: TextAlign.center,
            color: Palette.fog.color,
          ),
        ],
        if (_adFailed) ...[
          const SizedBox(height: 4),
          PixelText(strings.t('offline_ad_failed'),
              wrap: true, align: TextAlign.center, color: Palette.coral.color),
        ],
      ],
      actions: [
        PixelButton(
          label: strings.t('offline_double'),
          onPressed: _watching ? null : _watchAd,
        ),
        PixelButton(
          label: strings.t('offline_collect'),
          style: PixelButtonStyle.confirm,
          onPressed: _watching
              ? null
              : () => ref.read(gameControllerProvider.notifier).collectOffline(),
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
    return PixelDialog(
      title: strings.t('debug_title'),
      body: [
        row([
          for (final amount in debug.coinAmounts)
            PixelButton(
              label: strings.t('debug_add_coins', {'n': formatBig(Big.fromDouble(amount))}),
              style: PixelButtonStyle.secondary,
              onPressed: () => controller.debugAddCoins(amount),
            ),
        ]),
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
        row([
          for (final m in debug.fastForwardMinutes)
            PixelButton(
              label: strings.t('debug_fast_forward', {'n': m}),
              style: PixelButtonStyle.secondary,
              onPressed: () => controller.debugFastForward(m),
            ),
        ]),
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
