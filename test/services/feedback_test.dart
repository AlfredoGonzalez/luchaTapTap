import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/data/balance.dart';
import 'package:lucha_tap_tap/services/audio_service.dart';
import 'package:lucha_tap_tap/services/game_controller.dart';
import 'package:lucha_tap_tap/services/haptics_service.dart';

import '../test_content.dart';

class Rig {
  Rig({bool vibration = true}) {
    final content = loadTestContent((f) {
      f['balance.json']!['audio'] = {'master': 0.5, 'music': 0.5, 'sfx': 0.8};
      f['balance.json']!['haptics'] = {
        'tap': 'light',
        'crit': 'medium',
        'buy': 'selection',
        'bossIntro': 'heavy',
        'finisher': 'heavy',
        'victory': 'medium',
      };
      f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1};
    });
    container = ProviderContainer(
      overrides: [
        contentProvider.overrideWithValue(content),
        audioServiceProvider.overrideWithValue(audio),
        hapticsServiceProvider.overrideWithValue(haptics),
      ],
    );
    controller = container.read(gameControllerProvider.notifier);
    if (vibration) container.read(settingsProvider.notifier).toggle('vibration');
  }

  final audio = RecordingAudioService();
  final haptics = RecordingHapticsService();
  late final ProviderContainer container;
  late final GameController controller;

  void dispose() => container.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a tap plays the tap effect at master x sfx volume and vibrates', () {
    final rig = Rig();
    addTearDown(rig.dispose);
    rig.controller.tap();
    expect(rig.audio.sfx, contains(Sfx.tap));
    expect(rig.audio.sfxVolumes.last, closeTo(0.4, 1e-9));
    expect(rig.haptics.performed, contains(HapticKind.light));
  });

  test('vibration off means no vibration; sound off means no effects', () {
    final rig = Rig(vibration: false);
    addTearDown(rig.dispose);
    rig.container.read(settingsProvider.notifier).toggle('sound');
    rig.controller.tap();
    expect(rig.haptics.performed, isEmpty);
    expect(rig.audio.sfx, isEmpty);
  });

  test('buying plays the buy effect and a failed buy plays the error effect', () {
    final rig = Rig();
    addTearDown(rig.dispose);
    rig.controller.buyUpgrade('puno_duro');
    expect(rig.audio.sfx, contains(Sfx.buy));
    expect(rig.haptics.performed, contains(HapticKind.selection));
    // Locked trainers cannot be bought: that is the error effect.
    rig.controller.buyTrainer('chema_pesas');
    expect(rig.audio.sfx, contains(Sfx.error));
  });

  test('music follows the fight: main, then boss, and stops when switched off', () async {
    final rig = Rig();
    addTearDown(rig.dispose);
    await Future<void>.delayed(Duration.zero); // initial sync
    expect(rig.audio.current, MusicTrack.main);
    expect(rig.audio.musicVolume, closeTo(0.25, 1e-9));
    rig.controller.debugGoToBoss();
    expect(rig.audio.current, MusicTrack.boss);
    rig.container.read(settingsProvider.notifier).toggle('music');
    expect(rig.audio.current, isNull);
  });

  test('starting a boss fight plays its intro; pop-ups have open and close sounds', () {
    final rig = Rig();
    addTearDown(rig.dispose);
    rig.controller.debugGoToBoss();
    rig.controller.popupSound(open: true);
    rig.controller.popupSound(open: false);
    expect(rig.audio.sfx, containsAllInOrder([Sfx.popupOpen, Sfx.popupClose]));
  });

  test('losing focus pauses the music and coming back resumes it', () {
    final rig = Rig();
    addTearDown(rig.dispose);
    rig.controller.onBackground();
    expect(rig.audio.paused, isTrue);
    rig.controller.onForeground();
    expect(rig.audio.paused, isFalse);
  });
}
