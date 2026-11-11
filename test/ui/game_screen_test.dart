import 'package:clock/clock.dart';
import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/app.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/game_state.dart';
import 'package:lucha_tap_tap/core/save_codec.dart';
import 'package:lucha_tap_tap/game/arena_game.dart';
import 'package:lucha_tap_tap/services/ad_service.dart';
import 'package:lucha_tap_tap/services/game_controller.dart';
import 'package:lucha_tap_tap/services/save_store.dart';

import '../test_content.dart';

typedef Edit = void Function(Map<String, Map<String, dynamic>>);

/// A save made by playing [play] on a fresh engine, as if the app was closed
/// [ago] before "now".
SaveData saveFrom(void Function(GameEngine e) play, {Edit? edit, Duration ago = Duration.zero}) {
  final e = GameEngine(content: loadTestContent(edit));
  play(e);
  return SaveData(
    saveVersion: 1,
    lastSeen: clock.now().toUtc().subtract(ago),
    rngState: e.rng.state,
    state: e.state,
  );
}

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Edit? edit,
  SaveData? save,
  SaveStore? store,
  AdService? ads,
  Size size = const Size(1080, 1920),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(loadTestContent(edit)),
      if (save != null) initialSaveProvider.overrideWithValue(save),
      if (store != null) saveStoreProvider.overrideWithValue(store),
      if (ads != null) adServiceProvider.overrideWithValue(ads),
    ],
    child: const LuchaTapApp(),
  ));
  await tester.pump(const Duration(milliseconds: 200)); // let Flame load
  return ProviderScope.containerOf(tester.element(find.byType(LuchaTapApp)));
}

Future<void> closeApp(WidgetTester tester) async {
  // Let Flame's tap recognizer finish its short timer, then unmount so the
  // game timers are cancelled before the test ends.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox());
}

GameState stateOf(ProviderContainer c) => c.read(gameControllerProvider);

/// Lets [seconds] of game time pass.
Future<void> elapse(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> tapArena(WidgetTester tester, [int times = 1]) async {
  final arena = tester.getCenter(find.byType(GameWidget<ArenaGame>));
  for (var i = 0; i < times; i++) {
    await tester.tapAt(arena);
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> scrollPanel(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(ListView), Offset(0, dy));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Moves the app to the background and back, with [away] of time in between.
Future<void> backgroundFor(WidgetTester tester, Duration away) async {
  final b = tester.binding;
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump(away);
  b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump(const Duration(milliseconds: 50));
}

const bigDps = 100.0;
void fastTrainer(Map<String, Map<String, dynamic>> f) =>
    f['trainers.json']!['trainers'][0]['baseDps'] = bigDps;

void main() {
  group('fight screen', () {
    testWidgets('shows everything in Spanish', (tester) async {
      await pumpApp(tester);
      expect(find.text('Pelea 1'), findsOneWidget);
      expect(find.text('Mr. Aguacate'), findsOneWidget);
      expect(find.text('Monedas'), findsOneWidget);
      expect(find.text('GOLPE'), findsOneWidget);
      for (final tab in ['Mejoras', 'Habilidades', 'Máscaras', 'Talentos']) {
        expect(find.text(tab), findsOneWidget);
      }
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('x10'), findsOneWidget);
      expect(find.textContaining('Puño duro'), findsOneWidget);
      expect(find.text('?'), findsNWidgets(5)); // five unlearned skills
      await closeApp(tester);
    });

    testWidgets('tapping the arena 10 times defeats the first opponent', (tester) async {
      final c = await pumpApp(tester);
      await tapArena(tester, 10);
      expect(find.text('Pelea 2'), findsOneWidget);
      expect(find.text('El Tamal Mortal'), findsOneWidget);
      expect(stateOf(c).coins.toDouble(), closeTo(1.5, 1e-9));
      await closeApp(tester);
    });

    testWidgets('buying an upgrade spends coins and raises its level', (tester) async {
      await pumpApp(tester, edit: (f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});
      await tester.tap(find.text('10')); // cost button of "Puño duro"
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.textContaining('Puño duro  Nv. 1'), findsOneWidget);
      expect(find.text('990'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('a button is disabled while unaffordable', (tester) async {
      final c = await pumpApp(tester);
      await tester.tap(find.text('10'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).upgradeLevel('puno_duro'), 0);
      await closeApp(tester);
    });

    testWidgets('an idle trainer progresses the fight without taps', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tester.tap(find.text('50')); // hire Don Chuy
      await tester.pump(const Duration(milliseconds: 20));
      await elapse(tester, 2);
      expect(stateOf(c).fightNumber, greaterThan(1));
      await closeApp(tester);
    });

    for (final entry in {
      'small 720x1280': const Size(720, 1280),
      'standard 1080x1920': const Size(1080, 1920),
      'tall 1080x2340': const Size(1080, 2340),
      'very tall 1080x2560': const Size(1080, 2560),
      'wide-ish 1200x1920': const Size(1200, 1920),
    }.entries) {
      // Any RenderFlex overflow fails the test, so this checks the layout.
      testWidgets('layout fits on ${entry.key}', (tester) async {
        await pumpApp(tester, size: entry.value);
        expect(find.text('Pelea 1'), findsOneWidget);
        expect(find.text('Talentos'), findsOneWidget);
        await closeApp(tester);
      });
    }
  });

  group('combo and skills', () {
    testWidgets('ten taps fill the combo and GOLPE lands a big hit', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      expect(stateOf(c).comboMeter, 1);
      final hpBefore = stateOf(c).enemyHp;
      await tester.tap(find.text('GOLPE'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).comboMeter, 0);
      // 20x a tap of 0.01, with the starter mask's +15%.
      expect((hpBefore - stateOf(c).enemyHp).toDouble(), closeTo(0.01 * 1.15 * 20, 1e-9));
      await closeApp(tester);
    });

    testWidgets('learn Plancha in the skills tab and use it from the skills row', (tester) async {
      final save = saveFrom((e) {
        e.debugAddCoins(Big.fromInt(100000));
        e.debugSkipFights(3);
      });
      final c = await pumpApp(tester, save: save);
      await openTab(tester, 'Habilidades');
      expect(find.textContaining('Plancha'), findsOneWidget);
      await tester.tap(find.text('200')); // Plancha's price
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).skillLevel('plancha'), 1);
      expect(find.text('PLA'), findsOneWidget);
      final hp = stateOf(c).enemyHp;
      await tester.tap(find.text('PLA'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).enemyHp < hp, isTrue);
      expect(stateOf(c).skillCooldownLeft('plancha'), greaterThan(0));
      await closeApp(tester);
    });
  });

  group('masks, talents and prestige', () {
    testWidgets('masks tab shows the owned and the locked mask', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Máscaras');
      expect(find.text('Jaguar Dorado'), findsOneWidget);
      expect(find.text('Puesta'), findsOneWidget);
      expect(find.text('???'), findsOneWidget);
      expect(find.textContaining('+15% daño por toque'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('buy and equip a mask with belts', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGrantBelts(5)));
      await openTab(tester, 'Máscaras');
      await tester.tap(find.text('3')); // price in belts
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).ownedMasks, contains('la_calaverita'));
      await tester.tap(find.text('Poner'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).equippedMask, 'la_calaverita');
      await closeApp(tester);
    });

    testWidgets('talents tab: spend belts on a talent', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGrantBelts(5)));
      await openTab(tester, 'Talentos');
      expect(find.textContaining('Cinturones: 5'), findsOneWidget);
      await tester.tap(find.text('1').first);
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).talentLevel('punos_acero'), 1);
      expect(find.textContaining('Cinturones: 4'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('Cambiar de máscara: preview, confirm and reset', (tester) async {
      final save = saveFrom((e) {
        e.debugAddCoins(Big.fromDouble(5e6));
        e.buyUpgrade('puno_duro', const BuyAmount.fixed(3));
        e.debugSkipFights(4);
      });
      final c = await pumpApp(tester, save: save);
      await openTab(tester, 'Talentos');
      await tester.tap(find.text('Cambiar de máscara'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Ganarás 2 cinturones'), findsOneWidget);
      expect(find.textContaining('Se reinicia'), findsOneWidget);
      expect(find.textContaining('Se conserva'), findsOneWidget);
      await tester.tap(find.text('¡Cambiar!'));
      await tester.pump(const Duration(milliseconds: 20));
      final s = stateOf(c);
      expect(s.fightNumber, 1);
      expect(s.upgradeLevels, isEmpty);
      expect(s.belts.toDouble(), 2 + 3); // earned + "Nueva cara" achievement
      expect(find.text('Ganarás 2 cinturones'), findsNothing); // dialog closed
      await closeApp(tester);
    });

    testWidgets('prestige is refused until the run is worth a belt', (tester) async {
      final c = await pumpApp(tester);
      await openTab(tester, 'Talentos');
      await tester.tap(find.text('Cambiar de máscara'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Aún no ganas cinturones'), findsOneWidget);
      await tester.tap(find.text('¡Cambiar!'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).stat('prestiges'), 0);
      await tester.tap(find.text('Volver'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Aún no ganas cinturones'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('the Android back button closes a pop-up', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Talentos');
      await tester.tap(find.text('Cambiar de máscara'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Aún no ganas cinturones'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Aún no ganas cinturones'), findsNothing);
      await closeApp(tester);
    });
  });

  group('boss fight', () {
    testWidgets('shows the boss, its countdown, and failing drops one fight', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGoToBoss()));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('El Mariachi Furioso'), findsOneWidget);
      expect(find.textContaining('JEFE'), findsOneWidget);
      expect(stateOf(c).bossTimeLeft, isNotNull);
      for (var i = 0; i < 40 && stateOf(c).fightNumber == 10; i++) {
        await elapse(tester, 1);
      }
      expect(stateOf(c).fightNumber, 9);
      expect(find.text('¡Se acabó el tiempo!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // the notice goes away
      expect(find.text('¡Se acabó el tiempo!'), findsNothing);
      await closeApp(tester);
    });
  });

  group('offline earnings pop-up', () {
    SaveData awaySave({Duration ago = const Duration(hours: 2)}) => saveFrom((e) {
          e.debugAddCoins(Big.fromInt(1000));
          e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
        }, edit: fastTrainer, ago: ago);

    testWidgets('appears on a cold start and "Cobrar" pays the base amount', (tester) async {
      final save = awaySave();
      final c = await pumpApp(tester, edit: fastTrainer, save: save);
      expect(find.text('Ganancias sin conexión'), findsOneWidget);
      expect(find.textContaining('Estuviste fuera 2 h 0 min'), findsOneWidget);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tester.tap(find.text('Cobrar'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Ganancias sin conexión'), findsNothing);
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('watching the ad doubles the amount', (tester) async {
      final ads = FakeAdService(delay: const Duration(milliseconds: 100));
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave(), ads: ads);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tester.tap(find.text('Duplicar (ver anuncio)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.shown, ['offline_double']);
      expect(stateOf(c).coins, before + pending.mulDouble(2));
      expect(find.text('Ganancias sin conexión'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('a failed ad still lets the player collect the base amount', (tester) async {
      final ads = FakeAdService(succeeds: false, delay: const Duration(milliseconds: 100));
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave(), ads: ads);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tester.tap(find.text('Duplicar (ver anuncio)'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No hay anuncio disponible. Puedes cobrar normal.'), findsOneWidget);
      expect(stateOf(c).coins, before); // nothing paid yet
      await tester.tap(find.text('Cobrar'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('the Android back button collects the base amount', (tester) async {
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave());
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('a very short absence is paid silently with no pop-up', (tester) async {
      final c = await pumpApp(tester,
          edit: fastTrainer, save: awaySave(ago: const Duration(seconds: 20)));
      expect(find.text('Ganancias sin conexión'), findsNothing);
      expect(stateOf(c).pendingOffline, isNull);
      await closeApp(tester);
    });

    testWidgets('no pop-up on a brand new game', (tester) async {
      await pumpApp(tester);
      expect(find.text('Ganancias sin conexión'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('going to the background and back shows the pop-up', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tester.tap(find.text('50')); // hire Don Chuy
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Ganancias sin conexión'), findsNothing);
      await backgroundFor(tester, const Duration(minutes: 10));
      expect(find.text('Ganancias sin conexión'), findsOneWidget);
      expect(stateOf(c).pendingOffline, isNotNull);
      // The game did not tick while away: the earnings are the offline kind.
      expect(find.textContaining('Estuviste fuera 10 min'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('saving', () {
    testWidgets('saves every 10 seconds and when going to the background', (tester) async {
      final store = MemorySaveStore();
      await pumpApp(tester, store: store);
      expect(store.writes, 0);
      await elapse(tester, 9);
      expect(store.writes, 0);
      await elapse(tester, 2);
      expect(store.writes, 1);
      await elapse(tester, 10);
      expect(store.writes, 2);
      final before = store.writes;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(store.writes, greaterThan(before));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await closeApp(tester);
    });

    testWidgets('killing the app at a random moment loses at most 10 seconds', (tester) async {
      final store = MemorySaveStore();
      final c = await pumpApp(tester,
          store: store, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 3});
      await tapArena(tester, 12); // a couple of fights won
      await elapse(tester, 17); // the last save happened at 10 s
      final progressAtKill = stateOf(c).stat('taps');
      final savedAt = store.current!.lastSeen;
      final killedAt = clock.now().toUtc();
      // "Kill": drop the app without any shutdown handling.
      await tester.pumpWidget(const SizedBox());
      expect(killedAt.difference(savedAt), lessThanOrEqualTo(const Duration(seconds: 10, milliseconds: 100)));
      // Reopen from what is on disk.
      final c2 = await pumpApp(tester, store: store, save: store.current,
          edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 3});
      expect(stateOf(c2).stat('taps'), progressAtKill); // taps were before the save
      expect(stateOf(c2).fightNumber, greaterThan(1));
      await closeApp(tester);
    });

    testWidgets('a restored game keeps upgrades, masks and belts', (tester) async {
      final save = saveFrom((e) {
        e.debugAddCoins(Big.fromInt(5000));
        e.buyUpgrade('puno_duro', const BuyAmount.fixed(5));
        e.debugGrantBelts(7);
        e.grantMask('la_calaverita');
        e.equipMask('la_calaverita');
      });
      final c = await pumpApp(tester, save: save);
      expect(stateOf(c).upgradeLevel('puno_duro'), 5);
      expect(stateOf(c).belts.toDouble(), 7);
      expect(stateOf(c).equippedMask, 'la_calaverita');
      expect(find.textContaining('Puño duro  Nv. 5'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('debug panel', () {
    testWidgets('opens with a long press on the fight number', (tester) async {
      final c = await pumpApp(tester);
      await tester.longPress(find.text('Pelea 1'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Depuración'), findsOneWidget);
      await tester.tap(find.text('+1K monedas'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).coins.toDouble(), 1000);
      await tester.tap(find.text('Saltar pelea'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).fightNumber, 2);
      await tester.tap(find.text('Ir al jefe'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).fightNumber, 10);
      await tester.tap(find.text('Cerrar'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Depuración'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('fast-forward runs game time at once', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tester.tap(find.text('50'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.longPress(find.text('Pelea 1'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('Avanzar 1 min'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).fightNumber, greaterThan(1));
      await closeApp(tester);
    });

    testWidgets('simulate absence shows the offline pop-up', (tester) async {
      await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tester.tap(find.text('50'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.longPress(find.text('Pelea 1'));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('Simular ausencia 4 h'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Ganancias sin conexión'), findsOneWidget);
      await closeApp(tester);
    });
  });
}
