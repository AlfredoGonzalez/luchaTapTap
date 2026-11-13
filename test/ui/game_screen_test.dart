import 'dart:math' as math;

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
import 'package:lucha_tap_tap/services/billing_service.dart';
import 'package:lucha_tap_tap/services/game_controller.dart';
import 'package:lucha_tap_tap/services/save_store.dart';
import 'package:lucha_tap_tap/services/tutorial_controller.dart';
import 'package:lucha_tap_tap/ui/intro_screens.dart';
import 'package:lucha_tap_tap/ui/pixel_widgets.dart';
import 'package:lucha_tap_tap/ui/ui_state.dart';

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

/// Semantics handles must be released before a test ends.
final List<SemanticsHandle> _handles = [];

Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Edit? edit,
  SaveData? save,
  SaveStore? store,
  AdService? ads,
  BillingService? billing,
  AppStage stage = AppStage.game,
  bool tutorial = false,
  Size size = const Size(1080, 1920),
  double dpr = 3,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  _handles.add(tester.ensureSemantics());
  await tester.pumpWidget(ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(loadTestContent(edit)),
      initialAppStageProvider.overrideWithValue(stage),
      tutorialEnabledProvider.overrideWithValue(tutorial),
      if (save != null) initialSaveProvider.overrideWithValue(save),
      if (store != null) saveStoreProvider.overrideWithValue(store),
      if (ads != null) adServiceProvider.overrideWithValue(ads),
      if (billing != null) billingServiceProvider.overrideWithValue(billing),
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
  for (final handle in _handles) {
    handle.dispose();
  }
  _handles.clear();
}

GameState stateOf(ProviderContainer c) => c.read(gameControllerProvider);

/// Lets [seconds] of game time pass.
Future<void> elapse(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

const _short = Duration(milliseconds: 30);

/// Taps a navigation tab (icon only; found by its spoken label).
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel(label));
  await tester.pump(_short);
}

/// The button (not its row) whose spoken label is [label].
Finder buttonLabelled(String label) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.button == true && w.properties.label == label,
    );

/// Taps the [PixelButton] showing [text] (first match).
Future<void> tapButton(WidgetTester tester, String text) async {
  await tester.tap(find.widgetWithText(PixelButton, text).first);
  await tester.pump(_short);
}

Future<void> tapArena(WidgetTester tester, [int times = 1]) async {
  final arena = tester.getCenter(find.byType(GameWidget<ArenaGame>));
  for (var i = 0; i < times; i++) {
    await tester.tapAt(arena);
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> scrollPanel(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(ListView).first, Offset(0, dy));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Draws a circle with one finger around [center] (logical pixels): [clockwise]
/// as seen on screen, starting at [startDeg] (0 = right, 90 = bottom, 180 = left).
Future<void> drawCircle(
  WidgetTester tester,
  Offset center, {
  double radius = 40,
  bool clockwise = true,
  double startDeg = 180,
  bool lift = true,
  TestGesture? finger,
}) async {
  Offset at(double deg) {
    final a = deg * math.pi / 180;
    return center + Offset(radius * math.cos(a), radius * math.sin(a));
  }

  final g = finger ?? await tester.startGesture(at(startDeg));
  for (var i = 1; i <= 48; i++) {
    await g.moveTo(at(startDeg + (clockwise ? 1 : -1) * 360 * i / 48));
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (lift) {
    await g.up();
    await tester.pump(const Duration(milliseconds: 20));
  }
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
void fastTrainer(Map<String, Map<String, dynamic>> f) => f['trainers.json']!['trainers'][0]['baseDps'] = bigDps;

/// Opens the debug panel (long-press on the fight number).
Future<void> openDebug(WidgetTester tester) async {
  await tester.longPress(find.text('Pelea 1').first);
  await tester.pump(_short);
}

void main() {
  tutorialTests();
  group('app flow', () {
    testWidgets('studio splash, then loading, then the game', (tester) async {
      final c = await pumpApp(tester, stage: AppStage.splash);
      // Only the studio video (a plain background where it cannot play).
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('AM Studios Play'), findsNothing);
      await tester.pump(const Duration(seconds: 3)); // splashSeconds = 2
      expect(c.read(appStageProvider), AppStage.loading);
      expect(find.byType(LoadingScreen), findsOneWidget);
      // The bar fills first; tapping before it is full does nothing.
      await tester.tapAt(tester.getCenter(find.byType(LoadingScreen)));
      await tester.pump(_short);
      expect(c.read(appStageProvider), AppStage.loading);
      await tester.pump(const Duration(milliseconds: 1600)); // loadingSeconds = 1.5
      // The prompt blinks (0.5 s on, 0.5 s off): both states appear within a second.
      var seenOn = false;
      var seenOff = false;
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.text('Toca para continuar').evaluate().isEmpty) {
          seenOff = true;
        } else {
          seenOn = true;
        }
      }
      expect([seenOn, seenOff], [true, true]);
      while (find.text('Toca para continuar').evaluate().isEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tapAt(tester.getCenter(find.byType(LoadingScreen)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.read(appStageProvider), AppStage.game);
      expect(find.text('Pelea 1'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('tapping the splash skips it', (tester) async {
      final c = await pumpApp(tester, stage: AppStage.splash);
      await tester.tap(find.byType(SplashScreen));
      await tester.pump(_short);
      expect(c.read(appStageProvider), AppStage.loading);
      await closeApp(tester);
    });

    testWidgets('the splash and loading times come from balance.json', (tester) async {
      final c = await pumpApp(tester, stage: AppStage.splash, edit: (f) {
        f['balance.json']!['ui']['splashSeconds'] = 10;
      });
      await tester.pump(const Duration(seconds: 5));
      expect(c.read(appStageProvider), AppStage.splash);
      await tester.pump(const Duration(seconds: 6));
      expect(c.read(appStageProvider), AppStage.loading);
      await closeApp(tester);
    });
  });

  group('info buttons', () {
    testWidgets('the "i" on an upgrade explains it and shows the next milestone', (tester) async {
      await pumpApp(tester, edit: (f) => f['balance.json']!['milestones'] = {'levels': [10], 'multiplier': 2});
      await tester.tap(buttonLabelled('Información Puño duro'));
      await tester.pump(_short);
      expect(find.textContaining('Cada nivel suma'), findsOneWidget);
      expect(find.textContaining('Próximo hito'), findsOneWidget);
      await tester.tap(buttonLabelled('Cerrar'));
      await tester.pump(_short);
      expect(find.textContaining('Cada nivel suma'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('a trainer with a special says what it does', (tester) async {
      await pumpApp(tester, edit: (f) {
        f['trainers.json']!['trainers'][0]['special'] = {'type': 'coinGain', 'perLevel': 0.05, 'maxBonus': 1.0};
      });
      await tester.drag(find.text('Puño duro'), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(buttonLabelled('Información Don Chuy'));
      await tester.pump(_short);
      expect(find.textContaining('Especial: cada nivel suma 5% de monedas (máximo 100%)'), findsOneWidget);
      await tester.tap(buttonLabelled('Cerrar'));
      await tester.pump(_short);
      await closeApp(tester);
    });

    testWidgets('a locked trainer says in which fight it unlocks', (tester) async {
      await pumpApp(tester);
      await tester.drag(find.text('Puño duro'), const Offset(0, -400));
      await tester.pump(_short);
      await tester.tap(buttonLabelled('Información ???').first);
      await tester.pump(_short);
      expect(find.textContaining('Se desbloquea al llegar a la pelea'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('fight screen', () {
    testWidgets('shows everything in Spanish', (tester) async {
      await pumpApp(tester);
      expect(find.text('Pelea 1'), findsOneWidget);
      expect(find.text('Mr. Aguacate'), findsOneWidget);
      expect(find.text('GOLPE'), findsOneWidget);
      expect(find.text('x0'), findsOneWidget);
      for (final tab in ['Mejoras', 'Habilidades', 'Máscaras', 'Talentos', 'Tienda']) {
        expect(find.bySemanticsLabel(tab), findsOneWidget, reason: tab);
      }
      expect(find.text('MAX'), findsOneWidget);
      expect(find.text('x10'), findsOneWidget);
      expect(find.text('Puño duro'), findsOneWidget);
      expect(find.text('Nv 0'), findsWidgets);
      await closeApp(tester);
    });

    testWidgets('tapping the arena 10 times defeats the first opponent', (tester) async {
      final c = await pumpApp(tester);
      await tapArena(tester, 10);
      expect(find.text('Pelea 2'), findsOneWidget);
      expect(find.text(c.read(gameControllerProvider.notifier).engine.opponent.name), findsWidgets);
      expect(stateOf(c).coins.toDouble(), closeTo(1.5, 1e-9));
      expect(find.text('1.5'), findsOneWidget); // the HUD coins
      await closeApp(tester);
    });

    testWidgets('buying an upgrade spends coins, raises its level and flashes the row', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});
      expect(find.text('1K'), findsOneWidget);
      await tapButton(tester, '10'); // cost button of "Puño duro"
      expect(stateOf(c).upgradeLevel('puno_duro'), 1);
      expect(find.text('Nv 1'), findsOneWidget);
      expect(find.text('990'), findsOneWidget);
      // The row flashes Sun Yellow for the time in balance.json, then stops.
      expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color.toARGB32() == 0xFFFFE066), findsWidgets);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byWidgetPredicate((w) => w is ColoredBox && w.color.toARGB32() == 0xFFFFE066), findsNothing);
      await closeApp(tester);
    });

    testWidgets('a button is disabled while unaffordable', (tester) async {
      final c = await pumpApp(tester);
      await tester.tap(find.widgetWithText(PixelButton, '10').first);
      await tester.pump(_short);
      expect(stateOf(c).upgradeLevel('puno_duro'), 0);
      await closeApp(tester);
    });

    testWidgets('a trainer is a mystery until its fight', (tester) async {
      await pumpApp(tester, edit: (f) => f['trainers.json']!['trainers'][0]['unlockFight'] = 50);
      await scrollPanel(tester, -200);
      expect(find.text('???'), findsWidgets);
      expect(find.text('Misterio'), findsWidgets);
      expect(find.text('Pelea 50'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('an idle trainer progresses the fight without taps', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tapButton(tester, '50'); // hire Don Chuy
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
      'desktop 1920x1080 @1x': const Size(1920, 1080),
      'narrow browser 473x990 @1x': const Size(473, 990),
      'tablet 1536x2048': const Size(1536, 2048),
    }.entries) {
      // Any RenderFlex overflow fails the test, so this checks the layout of
      // the fight screen and of every other view with the real pixel font.
      testWidgets('layout fits on ${entry.key}', (tester) async {
        await pumpApp(
          tester,
          size: entry.value,
          dpr: entry.key.contains('@1x') ? 1 : 3,
          save: saveFrom((e) => e.debugAddCoins(Big.fromInt(1000))),
        );
        expect(find.text('Pelea 1'), findsOneWidget);
        for (final tab in ['Habilidades', 'Máscaras', 'Talentos', 'Tienda', 'Mejoras']) {
          await openTab(tester, tab);
        }
        await tester.tap(find.bySemanticsLabel('AJUSTES'));
        await tester.pump(_short);
        expect(find.text('Sonido'), findsOneWidget);
        // All eight settings rows are visible without scrolling, "Borrar datos" included.
        final area = tester.getRect(find.byType(ListView).first);
        final last = tester.getRect(find.text('Borrar datos'));
        expect(area.contains(last.center), isTrue);
        await closeApp(tester);
      });
    }
  });

  group('combo and skills', () {
    testWidgets('a full combo asks for a gesture; two circles land the finisher', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      expect(find.text('GOLPE'), findsOneWidget);
      await tapArena(tester, 10);
      expect(stateOf(c).comboMeter, 1);
      expect(find.text('x10'), findsWidgets); // combo count (and the buy selector)
      expect(find.text('DIBUJA'), findsOneWidget); // the badge
      expect(find.text('¡DIBUJA!'), findsOneWidget); // the on-screen prompt
      final hpBefore = stateOf(c).enemyHp;
      final center = tester.getCenter(find.byType(GameWidget<ArenaGame>));
      // Clockwise from the left, then counterclockwise from the right.
      await drawCircle(tester, center + const Offset(-30, 0), clockwise: true);
      expect(stateOf(c).comboMeter, 1); // one circle is not enough
      await drawCircle(tester, center + const Offset(30, 0), clockwise: false, startDeg: 0);
      expect(stateOf(c).comboMeter, 0);
      // 20x a tap of 0.01, with the starter mask's +15%, on top of the taps drawn with.
      expect((hpBefore - stateOf(c).enemyHp).toDouble(), greaterThanOrEqualTo(0.01 * 1.15 * 20));
      expect(find.text('¡DIBUJA!'), findsNothing);
      expect(find.text('GOLPE'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('one continuous figure eight also works', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      final center = tester.getCenter(find.byType(GameWidget<ArenaGame>));
      final finger = await tester.startGesture(center + const Offset(-70, 0)); // left point of the first circle
      await drawCircle(tester, center + const Offset(-30, 0), clockwise: true, lift: false, finger: finger);
      await drawCircle(tester, center + const Offset(-110, 0), clockwise: false, startDeg: 0, finger: finger);
      expect(stateOf(c).comboMeter, 0);
      await closeApp(tester);
    });

    testWidgets('drawing the circles the wrong way resets the combo', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      final center = tester.getCenter(find.byType(GameWidget<ArenaGame>));
      await drawCircle(tester, center, clockwise: false); // the first one must be clockwise
      expect(stateOf(c).comboMeter, 0);
      expect(find.text('¡Falló el golpe!'), findsOneWidget);
      expect(find.text('GOLPE'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('a straight swipe fails the gesture', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      final center = tester.getCenter(find.byType(GameWidget<ArenaGame>));
      final g = await tester.startGesture(center + const Offset(-60, 0));
      for (var i = 1; i <= 20; i++) {
        await g.moveTo(center + Offset(-60.0 + i * 6, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await g.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(stateOf(c).comboMeter, 0);
      await closeApp(tester);
    });

    testWidgets('taps keep working while the gesture is waiting', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      await tapArena(tester, 5);
      expect(stateOf(c).comboMeter, 1); // still ready, nothing failed
      expect(find.text('¡DIBUJA!'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('running out of time between the circles fails', (tester) async {
      final c = await pumpApp(tester, edit: (f) => f['balance.json']!['tap'] = {'baseDamage': 0.01});
      await tapArena(tester, 10);
      final center = tester.getCenter(find.byType(GameWidget<ArenaGame>));
      await drawCircle(tester, center, clockwise: true);
      await elapse(tester, 6); // the limit in balance.json is 5 s
      expect(stateOf(c).comboMeter, 0);
      await closeApp(tester);
    });

    testWidgets('skills view: locked, learn Plancha, details, then use it in the fight', (tester) async {
      final save = saveFrom((e) {
        e.debugAddCoins(Big.fromInt(100000));
        e.debugSkipFights(3);
      });
      final c = await pumpApp(tester, save: save);
      await openTab(tester, 'Habilidades');
      expect(find.text('HABILIDADES'), findsOneWidget);
      expect(find.text('Plancha'), findsWidgets);
      expect(find.text('???'), findsWidgets); // skills that need a later fight
      expect(find.textContaining('Salto desde las cuerdas: daño x15'), findsOneWidget);
      await tapButton(tester, '200'); // Plancha's price
      expect(stateOf(c).skillLevel('plancha'), 1);
      expect(find.text('Nv 1 · 25s'), findsOneWidget);
      expect(find.text('Nv 2: x20'), findsOneWidget); // preview of the next level
      await openTab(tester, 'Mejoras');
      final hp = stateOf(c).enemyHp;
      await tester.tap(find.bySemanticsLabel('Plancha'));
      await tester.pump(_short);
      expect(stateOf(c).enemyHp < hp, isTrue);
      expect(stateOf(c).skillCooldownLeft('plancha'), greaterThan(0));
      await closeApp(tester);
    });
  });

  group('masks', () {
    testWidgets('grid shows the owned mask, locked slots and the detail', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Máscaras');
      expect(find.text('MÁSCARAS'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('Jaguar Dorado'), findsWidgets);
      expect(find.text('EQUIPADA'), findsOneWidget);
      expect(find.textContaining('+15% daño por toque'), findsOneWidget);
      expect(find.text('???'), findsWidgets);
      await closeApp(tester);
    });

    testWidgets('buy a mask with belts, then equip it', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGrantBelts(5)));
      await openTab(tester, 'Máscaras');
      await tester.tap(find.bySemanticsLabel('???').first); // La Calaverita, locked
      await tester.pump(_short);
      expect(find.text('Cuesta 3 cinturones'), findsOneWidget);
      await tapButton(tester, '3');
      expect(stateOf(c).ownedMasks, contains('la_calaverita'));
      await tapButton(tester, 'Poner');
      expect(stateOf(c).equippedMask, 'la_calaverita');
      expect(find.text('EQUIPADA'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('talents and prestige', () {
    testWidgets('talents view: branches, belts and the upgrade button', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGrantBelts(5)));
      await openTab(tester, 'Talentos');
      expect(find.text('TALENTOS'), findsOneWidget);
      for (final branch in ['DAÑO', 'IDLE', 'SUERTE']) {
        expect(find.text(branch), findsOneWidget);
      }
      expect(find.text('5'), findsNWidgets(2)); // belts in the HUD and in the title bar
      expect(find.text('Puños de acero'), findsWidgets);
      await tapButton(tester, 'Mejorar 1');
      expect(stateOf(c).talentLevel('punos_acero'), 1);
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('4'), findsNWidgets(2));
      await closeApp(tester);
    });

    testWidgets('a locked talent says what it needs', (tester) async {
      await pumpApp(tester, save: saveFrom((e) => e.debugGrantBelts(5)));
      await openTab(tester, 'Talentos');
      await tester.tap(find.bySemanticsLabel(RegExp('Golpe crítico')));
      await tester.pump(_short);
      expect(find.text('Requiere Puños de acero'), findsOneWidget);
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
      await tapButton(tester, 'Cambiar de máscara');
      expect(find.text('¡NUEVA MÁSCARA!'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('+2 cinturones'), findsOneWidget);
      expect(find.text('+4% de daño para siempre'), findsOneWidget);
      expect(find.textContaining('Reinicias pelea'), findsOneWidget);
      expect(find.textContaining('Conservas máscaras'), findsOneWidget);
      await tapButton(tester, '¡Cambiar!');
      final s = stateOf(c);
      expect(s.fightNumber, 1);
      expect(s.upgradeLevels, isEmpty);
      expect(s.belts.toDouble(), 2 + 3); // earned + "Nueva cara" achievement
      expect(find.text('¡NUEVA MÁSCARA!'), findsNothing); // dialog closed
      expect(find.text('Pelea 1'), findsOneWidget); // back to the fight
      await closeApp(tester);
    });

    testWidgets('prestige is refused until the run is worth a belt', (tester) async {
      final c = await pumpApp(tester);
      await openTab(tester, 'Talentos');
      await tapButton(tester, 'Cambiar de máscara');
      expect(find.text('Aún no ganas cinturones'), findsOneWidget);
      await tester.tap(find.widgetWithText(PixelButton, '¡Cambiar!').first);
      await tester.pump(_short);
      expect(stateOf(c).stat('prestiges'), 0);
      await tapButton(tester, 'Volver');
      expect(find.text('Aún no ganas cinturones'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('the Android back button closes a pop-up, then leaves the view', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Talentos');
      await tapButton(tester, 'Cambiar de máscara');
      await tester.binding.handlePopRoute();
      await tester.pump(_short);
      expect(find.text('Aún no ganas cinturones'), findsNothing);
      expect(find.text('TALENTOS'), findsOneWidget); // still in the view
      await tester.binding.handlePopRoute();
      await tester.pump(_short);
      expect(find.text('TALENTOS'), findsNothing);
      expect(find.text('Pelea 1'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('boss fight', () {
    testWidgets('the intro waits for "¡A PELEAR!" and then the countdown runs', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGoToBoss()));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('¡JEFE!'), findsOneWidget);
      expect(find.text('Liga 1 · Pelea 10'), findsOneWidget);
      expect(find.text('El Mariachi Furioso'), findsOneWidget);
      expect(find.text('Tienes 30 s para vencerlo'), findsOneWidget);
      expect(stateOf(c).bossTimeLeft, isNull); // the clock has not started
      await tapButton(tester, '¡A PELEAR!');
      expect(find.text('¡JEFE!'), findsNothing);
      expect(stateOf(c).bossTimeLeft, isNotNull);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('El Mariachi Furioso'), findsOneWidget); // now at the top of the arena
      expect(find.textContaining('0:2'), findsOneWidget); // countdown as m:ss
      await closeApp(tester);
    });

    testWidgets('failing shows a tip; "Aceptar" drops back one fight', (tester) async {
      final c = await pumpApp(tester, save: saveFrom((e) => e.debugGoToBoss()));
      await tapButton(tester, '¡A PELEAR!');
      for (var i = 0; i < 40 && find.text('¡Has perdido!').evaluate().isEmpty; i++) {
        await elapse(tester, 1);
      }
      // The player stays defeated at the boss until the tip is accepted.
      expect(find.text('¡Has perdido!'), findsOneWidget);
      expect(stateOf(c).fightNumber, 10);
      await elapse(tester, 5);
      expect(stateOf(c).fightNumber, 10);
      await tapButton(tester, 'Aceptar');
      expect(stateOf(c).fightNumber, 9);
      expect(find.text('¡Has perdido!'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('the back button does not skip the boss intro', (tester) async {
      await pumpApp(tester, save: saveFrom((e) => e.debugGoToBoss()));
      await tester.binding.handlePopRoute();
      await tester.pump(_short);
      expect(find.text('¡JEFE!'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('the boss is the player\'s choice', () {
    SaveData atGate() => saveFrom((e) {
      e.debugSkipFights(8);
      // The boss was met before, so the gate holds the player farming.
      e.debugGoToBoss();
      e.abandonBoss();
    });
    void strongTaps(Map<String, Map<String, dynamic>> f) => f['balance.json']!['tap'] = {'baseDamage': 1e9};

    testWidgets('beating the fight before the boss repeats it and shows the "¡JEFE!" button', (tester) async {
      final c = await pumpApp(tester, save: atGate(), edit: strongTaps);
      expect(find.text('¡JEFE!'), findsOneWidget);
      await tapArena(tester, 3);
      expect(stateOf(c).fightNumber, 9); // still farming
      expect(stateOf(c).stat('defeats'), 3);
      expect(find.text('Pelea 9'), findsOneWidget);
      expect(find.text('¡JEFE!'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('there is no "¡JEFE!" button before regular fights', (tester) async {
      await pumpApp(tester);
      expect(find.text('¡JEFE!'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('pressing it shows the intro; "Volver" returns to the farming fight', (tester) async {
      final c = await pumpApp(tester, save: atGate());
      await tapButton(tester, '¡JEFE!');
      expect(stateOf(c).fightNumber, 10);
      expect(find.text('¡A PELEAR!'), findsOneWidget);
      await tapButton(tester, 'Volver');
      expect(stateOf(c).fightNumber, 9);
      expect(find.text('¡A PELEAR!'), findsNothing);
      expect(find.text('¡JEFE!'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('losing sends the player back to farm; nothing restarts the boss by itself', (tester) async {
      final c = await pumpApp(tester, save: atGate());
      await tapButton(tester, '¡JEFE!');
      await tapButton(tester, '¡A PELEAR!');
      for (var i = 0; i < 40 && find.text('¡Has perdido!').evaluate().isEmpty; i++) {
        await elapse(tester, 1);
      }
      expect(find.text('¡Has perdido!'), findsOneWidget);
      await tapButton(tester, 'Aceptar');
      expect(stateOf(c).fightNumber, 9);
      await elapse(tester, 10);
      expect(stateOf(c).fightNumber, 9);
      expect(find.text('¡A PELEAR!'), findsNothing); // no new intro
      expect(find.text('¡JEFE!'), findsOneWidget); // the choice is back
      await closeApp(tester);
    });

    testWidgets('beating the boss moves on', (tester) async {
      final c = await pumpApp(tester, save: atGate(), edit: strongTaps);
      await tapButton(tester, '¡JEFE!');
      await tapButton(tester, '¡A PELEAR!');
      await tapArena(tester);
      expect(stateOf(c).fightNumber, 11);
      // A victory screen waits; the fight is paused until "Continuar".
      expect(find.text('¡VICTORIA!'), findsOneWidget);
      final hp = stateOf(c).enemyHp;
      await tapArena(tester, 2);
      expect(stateOf(c).enemyHp, hp);
      await tapButton(tester, 'Continuar');
      expect(find.text('¡VICTORIA!'), findsNothing);
      await tapArena(tester);
      expect(stateOf(c).fightNumber, 12); // the fight goes on
      expect(find.text('¡JEFE!'), findsNothing);
      await closeApp(tester);
    });
  });

  group('offline earnings pop-up', () {
    SaveData awaySave({Duration ago = const Duration(hours: 2)}) => saveFrom((e) {
          e.debugAddCoins(Big.fromInt(1000));
          e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
        }, edit: fastTrainer, ago: ago);

    testWidgets('appears on a cold start and "Recoger" pays the base amount', (tester) async {
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave());
      expect(find.text('¡BIENVENIDO!'), findsOneWidget);
      expect(find.text('Estuviste fuera'), findsOneWidget);
      expect(find.text('2 h 0 min'), findsOneWidget);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tapButton(tester, 'Recoger');
      expect(find.text('¡BIENVENIDO!'), findsNothing);
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('it says when the cap was reached', (tester) async {
      await pumpApp(tester, edit: fastTrainer, save: awaySave(ago: const Duration(hours: 9)));
      expect(find.text('Tope: 4 h. Alárgalo en Talentos.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('watching the ad doubles the amount', (tester) async {
      final ads = FakeAdService(delay: const Duration(milliseconds: 100));
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave(), ads: ads);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tapButton(tester, 'x2 Ver anuncio');
      await tester.pump(const Duration(milliseconds: 300));
      expect(ads.shown, ['offline_double']);
      expect(stateOf(c).coins, before + pending.mulDouble(2));
      expect(find.text('¡BIENVENIDO!'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('a failed ad still lets the player collect the base amount', (tester) async {
      final ads = FakeAdService(succeeds: false, delay: const Duration(milliseconds: 100));
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave(), ads: ads);
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tapButton(tester, 'x2 Ver anuncio');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No hay anuncio disponible. Puedes cobrar normal.'), findsOneWidget);
      expect(stateOf(c).coins, before); // nothing paid yet
      await tapButton(tester, 'Recoger');
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('the Android back button collects the base amount', (tester) async {
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave());
      final pending = stateOf(c).pendingOffline!.coinsEarned;
      final before = stateOf(c).coins;
      await tester.binding.handlePopRoute();
      await tester.pump(_short);
      expect(stateOf(c).coins, before + pending);
      await closeApp(tester);
    });

    testWidgets('a very short absence is paid silently with no pop-up', (tester) async {
      final c = await pumpApp(tester, edit: fastTrainer, save: awaySave(ago: const Duration(seconds: 20)));
      expect(find.text('¡BIENVENIDO!'), findsNothing);
      expect(stateOf(c).pendingOffline, isNull);
      await closeApp(tester);
    });

    testWidgets('no pop-up on a brand new game', (tester) async {
      await pumpApp(tester);
      expect(find.text('¡BIENVENIDO!'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('going to the background and back shows the pop-up', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tapButton(tester, '50'); // hire Don Chuy
      expect(find.text('¡BIENVENIDO!'), findsNothing);
      await backgroundFor(tester, const Duration(minutes: 10));
      expect(find.text('¡BIENVENIDO!'), findsOneWidget);
      expect(stateOf(c).pendingOffline, isNotNull);
      expect(find.text('10 min'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('shop', () {
    testWidgets('lists every offer with a placeholder price', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Tienda');
      await tester.pump(const Duration(milliseconds: 100)); // prices load
      expect(find.text('TIENDA'), findsOneWidget);
      for (final section in ['PARA SIEMPRE', 'CINTURONES', 'GRATIS (ANUNCIO)']) {
        expect(find.text(section), findsOneWidget);
      }
      for (final item in ['Más descanso', 'Doble moneda', 'Puñado', 'Montón', 'Baúl', 'Doble 2 min']) {
        expect(find.text(item), findsOneWidget, reason: item);
      }
      expect(find.text(r'$XX'), findsWidgets);
      await scrollPanel(tester, -300);
      expect(find.text('Cinturón'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('buying a permanent item through the store service', (tester) async {
      final billing = FakeBillingService(placeholderPrice: r'$XX');
      final c = await pumpApp(tester, billing: billing);
      await openTab(tester, 'Tienda');
      await tester.pump(const Duration(milliseconds: 100)); // prices load
      await tester.tap(find.bySemanticsLabel('Comprar Más descanso'));
      await tester.pump(_short);
      await tester.pump(const Duration(milliseconds: 50));
      expect(billing.bought, ['mas_descanso']);
      expect(stateOf(c).purchases, contains('mas_descanso'));
      expect(find.text('Tuyo'), findsOneWidget);
      expect(find.text('¡Gracias!'), findsOneWidget);
      expect(c.read(gameControllerProvider.notifier).engine.offlineCapHours, 6);
      await closeApp(tester);
    });

    testWidgets('a cancelled purchase grants nothing', (tester) async {
      final billing = FakeBillingService(placeholderPrice: r'$XX', succeeds: false);
      final c = await pumpApp(tester, billing: billing);
      await openTab(tester, 'Tienda');
      await tester.pump(const Duration(milliseconds: 100)); // prices load
      await tester.tap(find.bySemanticsLabel('Comprar Puñado'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(stateOf(c).belts, Big.zero);
      expect(stateOf(c).purchases, isEmpty);
      await closeApp(tester);
    });

    testWidgets('a belt pack adds spendable belts', (tester) async {
      final c = await pumpApp(tester);
      await openTab(tester, 'Tienda');
      await tester.pump(const Duration(milliseconds: 100)); // prices load
      await tester.tap(find.bySemanticsLabel('Comprar Montón'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(stateOf(c).belts.toDouble(), 100);
      await closeApp(tester);
    });

    testWidgets('the 2-minute boost needs an ad and then cools down', (tester) async {
      final ads = FakeAdService(delay: const Duration(milliseconds: 50));
      final c = await pumpApp(tester, ads: ads);
      await openTab(tester, 'Tienda');
      await tester.tap(find.bySemanticsLabel('Ver Doble 2 min'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(ads.shown, ['shop_doble_2min']);
      expect(stateOf(c).boostLeft, greaterThan(100));
      expect(find.textContaining('Activo'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget); // 10-minute cooldown from shop.json
      // While cooling down the button does nothing.
      await tester.tap(find.bySemanticsLabel('Ver Doble 2 min'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(ads.shown.length, 1);
      await closeApp(tester);
    });

    testWidgets('no ad available: nothing is granted and the player is told', (tester) async {
      final ads = FakeAdService(succeeds: false, delay: const Duration(milliseconds: 50));
      final c = await pumpApp(tester, ads: ads);
      await openTab(tester, 'Tienda');
      await scrollPanel(tester, -300);
      await tester.tap(find.bySemanticsLabel('Ver Cinturón'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(stateOf(c).belts, Big.zero);
      expect(find.text('No hay anuncio disponible.'), findsOneWidget);
      await closeApp(tester);
    });
  });

  group('settings', () {
    testWidgets('toggles are saved with the game', (tester) async {
      final store = MemorySaveStore();
      final c = await pumpApp(tester, store: store);
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      expect(c.read(settingsProvider).vibration, isFalse);
      await tester.tap(find.bySemanticsLabel('Vibración: NO'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.read(settingsProvider).vibration, isTrue);
      expect(find.bySemanticsLabel('Vibración: SÍ'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Sonido: SÍ'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.current!.settings, containsPair('sound', false));
      expect(store.current!.settings, containsPair('vibration', true));
      await closeApp(tester);
    });

    testWidgets('saved settings come back on the next start', (tester) async {
      final save = SaveData(
        saveVersion: 1,
        lastSeen: clock.now().toUtc(),
        rngState: 1,
        state: GameEngine(content: loadTestContent()).state,
        settings: {'sound': false, 'music': false, 'vibration': true, 'notices': true},
      );
      final c = await pumpApp(tester, save: save);
      final s = c.read(settingsProvider);
      expect([s.sound, s.music, s.vibration, s.notices], [false, false, true, true]);
      await closeApp(tester);
    });

    testWidgets('credits come from credits.json and Volver returns to settings', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      await tester.tap(buttonLabelled('Créditos'));
      await tester.pump(_short);
      expect(find.text('CRÉDITOS'), findsOneWidget);
      expect(find.text('Press Start 2P'), findsOneWidget);
      expect(find.text('CodeMan38 · OFL'), findsOneWidget);
      await tapButton(tester, 'Volver');
      expect(find.text('AJUSTES'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('privacy shows its placeholder text', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      await tester.tap(buttonLabelled('Privacidad'));
      await tester.pump(_short);
      expect(find.textContaining('política de privacidad'), findsOneWidget);
      await tapButton(tester, 'Cerrar');
      expect(find.textContaining('política de privacidad'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('restore purchases brings back owned items', (tester) async {
      final billing = FakeBillingService(placeholderPrice: r'$XX')..owned.add('doble_moneda');
      final c = await pumpApp(tester, billing: billing);
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      await tester.tap(buttonLabelled('Restaurar'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(stateOf(c).purchases, contains('doble_moneda'));
      expect(find.text('Compras restauradas.'), findsOneWidget);
      await tester.tap(buttonLabelled('Restaurar'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No hay compras que restaurar.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('Borrar datos asks first, then starts a new game', (tester) async {
      final store = MemorySaveStore();
      final c = await pumpApp(tester, store: store, save: saveFrom((e) {
        e.debugAddCoins(Big.fromInt(777));
        e.debugSkipFights(5);
      }));
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      await tester.tap(buttonLabelled('Borrar datos'));
      await tester.pump(_short);
      expect(find.text('¿Borrar datos?'), findsOneWidget);
      // Backing out changes nothing.
      await tapButton(tester, 'Volver');
      expect(stateOf(c).fightNumber, 6);
      await tester.tap(buttonLabelled('Borrar datos'));
      await tester.pump(_short);
      await tapButton(tester, 'Borrar');
      await tester.pump(const Duration(milliseconds: 100));
      expect(stateOf(c).fightNumber, 1);
      expect(stateOf(c).coins, Big.zero);
      expect(store.current, isNull);
      expect(find.text('Pelea 1'), findsOneWidget);
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
      void edit(Map<String, Map<String, dynamic>> f) => f['balance.json']!['tap'] = {'baseDamage': 3};
      final c = await pumpApp(tester, store: store, edit: edit);
      await tapArena(tester, 12); // a couple of fights won
      await elapse(tester, 17); // the last save happened at 10 s
      final progressAtKill = stateOf(c).stat('taps');
      final savedAt = store.current!.lastSeen;
      final killedAt = clock.now().toUtc();
      // "Kill": drop the app without any shutdown handling.
      await tester.pumpWidget(const SizedBox());
      expect(killedAt.difference(savedAt), lessThanOrEqualTo(const Duration(seconds: 10, milliseconds: 100)));
      // Reopen from what is on disk.
      final c2 = await pumpApp(tester, store: store, save: store.current, edit: edit);
      expect(stateOf(c2).stat('taps'), progressAtKill); // the taps were before the save
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
      expect(find.text('Nv 5'), findsOneWidget);
      expect(find.text('7'), findsOneWidget); // belts in the HUD
      await closeApp(tester);
    });
  });

  group('debug panel', () {
    testWidgets('opens with a long press on the fight number', (tester) async {
      final c = await pumpApp(tester);
      await openDebug(tester);
      expect(find.text('Depuración'), findsOneWidget);
      await tapButton(tester, '+1K');
      expect(stateOf(c).coins.toDouble(), 1000);
      await tapButton(tester, '+1 pelea');
      expect(stateOf(c).fightNumber, 2);
      await tapButton(tester, 'Jefe');
      expect(stateOf(c).fightNumber, 10);
      await tapButton(tester, 'Cerrar');
      expect(find.text('Depuración'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('fast-forward runs game time at once', (tester) async {
      final c = await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tapButton(tester, '50');
      await openDebug(tester);
      await tapButton(tester, '+1m');
      expect(stateOf(c).fightNumber, greaterThan(1));
      await closeApp(tester);
    });

    testWidgets('simulate absence shows the offline pop-up', (tester) async {
      await pumpApp(tester, edit: (f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        fastTrainer(f);
      });
      await scrollPanel(tester, -200);
      await tapButton(tester, '50');
      await openDebug(tester);
      await tapButton(tester, '4 h');
      expect(find.text('¡BIENVENIDO!'), findsOneWidget);
      await closeApp(tester);
    });
  });
}

void tutorialTests() {
  group('tutorial', () {
    testWidgets('a new game starts with the coach and the arena lit', (tester) async {
      await pumpApp(tester, tutorial: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('¡Toca la arena para golpear al oponente!'), findsOneWidget);
      expect(find.text('El Profe'), findsOneWidget);
      expect(find.text('Saltar'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('taps outside the lit area do nothing', (tester) async {
      final c = await pumpApp(tester, tutorial: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.bySemanticsLabel('Talentos'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 30));
      expect(c.read(viewProvider), GameView.fight);
      await closeApp(tester);
    });

    testWidgets('the steps follow the player: taps, the bars, a gifted upgrade, "Entendido"', (tester) async {
      final c = await pumpApp(tester, tutorial: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tapArena(tester, 3);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('vida del oponente'), findsOneWidget);
      await tapButton(tester, 'Entendido');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Te regalo las monedas'), findsOneWidget);
      // The upgrade is affordable now, whatever the player had.
      final quote = c
          .read(gameControllerProvider.notifier)
          .engine
          .quoteUpgrade('puno_duro', const BuyAmount.fixed(1));
      expect(quote.canBuy, isTrue);
      await tester.tap(find.bySemanticsLabel('Puño duro'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Aquí compras mejoras'), findsOneWidget);
      await tapButton(tester, 'Entendido');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('El Profe'), findsNothing);
      expect(c.read(settingsProvider).tutorialDone, containsAll(['tap', 'defeat', 'upgrade', 'panel']));
      await closeApp(tester);
    });

    testWidgets('"Saltar" ends it', (tester) async {
      final c = await pumpApp(tester, tutorial: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tapButton(tester, 'Saltar');
      expect(find.text('El Profe'), findsNothing);
      expect(c.read(tutorialProvider).step, isNull);
      await closeApp(tester);
    });

    testWidgets('a game already played never sees it', (tester) async {
      await pumpApp(tester, tutorial: true, save: saveFrom((e) => e.tap()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('El Profe'), findsNothing);
      await closeApp(tester);
    });

    SaveData withTutorialDone(List<String> done, void Function(GameEngine e) play) {
      final e = GameEngine(content: loadTestContent());
      play(e);
      return SaveData(
        saveVersion: 1,
        lastSeen: clock.now().toUtc(),
        rngState: e.rng.state,
        state: e.state,
        settings: {'tutorialDone': done},
      );
    }

    const intro = ['tap', 'defeat', 'upgrade', 'panel'];

    testWidgets('a trainer step shows when one can be hired and ends when hired', (tester) async {
      final c = await pumpApp(
        tester,
        tutorial: true,
        save: withTutorialDone(intro, (e) => e.debugAddCoins(Big.fromInt(100000))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('contratar a Don Chuy'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Don Chuy').last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('contratar a Don Chuy'), findsNothing);
      expect(c.read(settingsProvider).tutorialDone, contains('trainer'));
      await closeApp(tester);
    });

    testWidgets('a full combo bar gets its step, with the kick', (tester) async {
      final c = await pumpApp(
        tester,
        tutorial: true,
        save: withTutorialDone([...intro, 'trainer'], (e) {
          for (var i = 0; i < 60; i++) {
            e.tap();
          }
        }),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(stateOf(c).comboMeter, closeTo(1, 1e-9));
      expect(find.textContaining('Barra llena'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('"Tutorial" in the settings plays it again', (tester) async {
      final c = await pumpApp(tester, tutorial: true);
      await tester.pump(const Duration(milliseconds: 100));
      await tapButton(tester, 'Saltar');
      await tester.tap(find.bySemanticsLabel('AJUSTES'));
      await tester.pump(_short);
      await tester.tap(find.bySemanticsLabel('Tutorial').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('El Profe'), findsOneWidget);
      expect(c.read(settingsProvider).tutorialDone, isEmpty);
      await closeApp(tester);
    });
  });
}
