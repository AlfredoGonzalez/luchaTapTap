import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/app.dart';
import 'package:lucha_tap_tap/game/arena_game.dart';
import 'package:lucha_tap_tap/services/game_controller.dart';

import '../test_content.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  void Function(Map<String, Map<String, dynamic>>)? edit,
  Size size = const Size(1080, 1920),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [contentProvider.overrideWithValue(loadTestContent(edit))],
    child: const LuchaTapApp(),
  ));
  await tester.pump(const Duration(milliseconds: 200)); // let Flame load
}

Future<void> closeApp(WidgetTester tester) async {
  // Let Flame's tap recognizer finish its short timer, then unmount so the game timer is cancelled before the test ends.
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpWidget(const SizedBox());
}

void main() {
  testWidgets('shows the fight screen in Spanish', (tester) async {
    await pumpApp(tester);
    expect(find.text('Pelea 1'), findsOneWidget);
    expect(find.text('Mr. Aguacate'), findsOneWidget);
    expect(find.text('Monedas'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('x10'), findsOneWidget);
    expect(find.textContaining('Puño duro'), findsOneWidget);
    expect(find.textContaining('Don Chuy'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('tapping the arena 10 times defeats the first opponent', (tester) async {
    await pumpApp(tester);
    final arena = tester.getCenter(find.byType(GameWidget<ArenaGame>));
    for (var i = 0; i < 10; i++) {
      await tester.tapAt(arena);
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('Pelea 2'), findsOneWidget);
    expect(find.text('El Tamal Mortal'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget); // coins earned
    await closeApp(tester);
  });

  testWidgets('buying an upgrade spends coins and raises its level', (tester) async {
    await pumpApp(tester, edit: (f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});
    expect(find.text('1K'), findsOneWidget);
    expect(find.textContaining('Nv. 0'), findsNWidgets(2));
    await tester.tap(find.text('10')); // cost button of "Puño duro"
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('Puño duro  Nv. 1'), findsOneWidget);
    expect(find.text('990'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a button is disabled while unaffordable', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('10'));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.textContaining('Nv. 0'), findsNWidgets(2));
    await closeApp(tester);
  });

  testWidgets('idle trainer progresses the fight without taps', (tester) async {
    await pumpApp(tester, edit: (f) {
      f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
      f['trainers.json']!['trainers'][0]['baseDps'] = 100;
    });
    await tester.tap(find.text('50')); // hire Don Chuy
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    final container = ProviderScope.containerOf(tester.element(find.byType(LuchaTapApp)));
    expect(container.read(gameControllerProvider).fightNumber, greaterThan(1));
    await closeApp(tester);
  });

  // Layout must hold on small, standard and tall phones with no overflow
  // (flutter_test turns any RenderFlex overflow into a failure).
  for (final entry in {
    'small 720x1280': const Size(720, 1280),
    'tall 1080x2340': const Size(1080, 2340),
    'very tall 1080x2560': const Size(1080, 2560),
    'wide-ish 1200x1920': const Size(1200, 1920),
  }.entries) {
    testWidgets('layout fits on ${entry.key}', (tester) async {
      await pumpApp(tester, size: entry.value);
      expect(find.text('Pelea 1'), findsOneWidget);
      expect(find.text('MAX'), findsOneWidget);
      await closeApp(tester);
    });
  }
}
