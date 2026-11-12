import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../core/palette.dart';
import '../services/game_controller.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import '../services/tutorial_controller.dart';
import 'rows.dart';
import 'ui_state.dart';

/// "AJUSTES": sound, music, vibration, notices, restore purchases, credits,
/// privacy and delete data.
class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  String? _message;

  Future<void> _restore() async {
    final restored = await ref
        .read(gameControllerProvider.notifier)
        .restorePurchases();
    if (!mounted) return;
    final strings = ref.read(stringsProvider);
    setState(
      () =>
          _message = strings.t(restored > 0 ? 'restore_done' : 'restore_none'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    Widget toggle(
      String key,
      String titleKey,
      bool value, {
      String? sub,
    }) => ListRow(
      title: strings.t(titleKey),
      subtitle: sub ?? '',
      height: 26,
      trailing: PixelButton(
        label: strings.t(value ? 'settings_on' : 'settings_off'),
        semanticLabel:
            '${strings.t(titleKey)}: ${strings.t(value ? 'settings_on' : 'settings_off')}',
        width: 36,
        style: value ? PixelButtonStyle.confirm : PixelButtonStyle.secondary,
        onPressed: () => notifier.toggle(key),
      ),
    );

    Widget action(
      String titleKey, {
      String? subKey,
      required VoidCallback onTap,
      bool danger = false,
      String label = '>',
    }) => ListRow(
      title: strings.t(titleKey),
      subtitle: subKey == null ? '' : strings.t(subKey),
      height: 26,
      trailing: PixelButton(
        label: label,
        semanticLabel: strings.t(titleKey),
        width: 36,
        style: danger ? PixelButtonStyle.danger : PixelButtonStyle.secondary,
        onPressed: onTap,
      ),
    );

    return Column(
      children: [
        ViewTitleBar(
          title: strings.t('view_settings'),
          trailing: PixelText('v$appVersion', color: Palette.dust.color),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
            children: [
              toggle('sound', 'settings_sound', settings.sound),
              toggle('music', 'settings_music', settings.music),
              toggle('vibration', 'settings_vibration', settings.vibration),
              toggle('notices', 'settings_notices', settings.notices, sub: strings.t('settings_notices_sub')),
              action('settings_restore', subKey: 'settings_restore_sub', onTap: _restore),
              action('settings_tutorial', onTap: () {
                ref.read(tutorialProvider.notifier).restart();
                ref.read(viewProvider.notifier).show(GameView.fight);
              }),
              action('settings_credits', onTap: () => ref.read(viewProvider.notifier).show(GameView.credits)),
              action('settings_privacy', onTap: () => ref.read(dialogProvider.notifier).open(GameDialog.privacy)),
              action('settings_delete',
                  subKey: 'settings_delete_sub',
                  danger: true,
                  label: '!',
                  onTap: () => ref.read(dialogProvider.notifier).open(GameDialog.deleteData)),
            ],
          ),
        ),
        if (_message != null)
          SizedBox(
            height: scale.px(12),
            child: Center(child: PixelText(_message!, color: Palette.sunYellow.color, align: TextAlign.center)),
          ),
      ],
    );
  }
}

/// "CRÉDITOS": built from `credits.json`, so attribution is automatic.
class CreditsView extends ConsumerWidget {
  const CreditsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    return Column(
      children: [
        ViewTitleBar(title: strings.t('view_credits')),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(scale.px(sideMargin)),
            children: [
              for (final group in content.credits) ...[
                SizedBox(height: scale.px(4)),
                PixelText(group.title, color: Palette.marigold.color),
                for (final line in group.lines) ...[
                  SizedBox(height: scale.px(3)),
                  PixelText(line.text, wrap: true),
                ],
              ],
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(scale.px(sideMargin)),
          child: Center(
            child: PixelButton(
              label: strings.t('dialog_back'),
              style: PixelButtonStyle.secondary,
              width: 100,
              onPressed: () => ref.read(viewProvider.notifier).back(),
            ),
          ),
        ),
      ],
    );
  }
}
