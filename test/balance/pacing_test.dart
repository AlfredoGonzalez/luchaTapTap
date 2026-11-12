import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/dev/balance_sim.dart';

import '../test_content.dart';

/// Guards the pacing of the SHIPPED data (`assets/data/`), measured with the
/// balance simulator. If a change to the JSON files makes the game much faster
/// or slower than the targets, one of these fails and says which.
///
/// Targets (GDD): first prestige 20 to 30 minutes of active play, the second
/// around 40 to 60; early purchases within the first minute; progress that
/// does not stop. The windows are wide on purpose: they catch real regressions,
/// not small tweaks. Rerun `dart run tool/balance_report.dart` after changing
/// the economy.
void main() {
  final content = loadShippedContent();
  const threeHours = Duration(hours: 3);

  group('an active player who never catches a lucky pickup (worst case)', () {
    final r = simulate(content, BotProfile.active.withLuckyCatch(0), length: threeHours);

    test('the first mask change becomes possible between 15 and 40 minutes', () {
      expect(r.firstMinute('prestigio disponible'), inInclusiveRange(15, 35));
    });

    test('the first prestige is around 20 to 35 minutes, the second 32 to 60', () {
      final p = r.prestigeMinutes;
      expect(p.length, greaterThanOrEqualTo(3));
      expect(p[0], inInclusiveRange(20, 35));
      expect(p[1], inInclusiveRange(32, 60));
      expect(p[1] - p[0], greaterThan(5)); // runs are not instant
    });

    test('the first boss falls and later fights keep coming at a steady pace', () {
      expect(r.firstMinute('pelea 11'), lessThan(10));
      expect(r.firstMinute('pelea 20'), lessThan(16));
      expect(r.firstMinute('pelea 30'), lessThan(36));
    });

    test('there is no permanent wall: the best fight keeps growing over hours', () {
      int bestAt(double m) => r.snapshots.lastWhere((s) => s.minute <= m + 0.5).bestFight;
      expect(bestAt(60), greaterThanOrEqualTo(40));
      expect(bestAt(120), greaterThan(bestAt(60)));
      expect(r.snapshots.last.bestFight, greaterThanOrEqualTo(60));
    });
  });

  group('the first minutes', () {
    final r = simulate(content, BotProfile.active.withLuckyCatch(0), length: const Duration(minutes: 20));

    test('the first purchase comes within a minute and the first trainer within 4', () {
      expect(r.buyMinutes.first, lessThan(1.0));
      expect(r.firstTrainerMinute, lessThan(4));
    });

    test('a skill is learned in the first 10 minutes', () {
      expect(r.firstSkillMinute, lessThan(10));
    });
  });

  group('lucky pickups are a bonus, not a requirement', () {
    test('catching them speeds the game up, but by less than half', () {
      final without = simulate(content, BotProfile.active.withLuckyCatch(0), length: threeHours);
      final withLuck = simulate(content, BotProfile.active.withLuckyCatch(0.6), length: threeHours);
      final a = without.prestigeMinutes.first;
      final b = withLuck.prestigeMinutes.first;
      expect(b, lessThan(a)); // a real bonus
      expect(b, greaterThan(a * 0.5)); // never doubling the speed
    });
  });

  group('other kinds of players still progress', () {
    test('a player who taps half as fast reaches the first prestige in under an hour', () {
      final slow = BotProfile(
        name: 'lento',
        tapsPerSecond: 2,
        actEverySeconds: 2,
        luckyCatch: 0,
      );
      final r = simulate(content, slow, length: threeHours);
      expect(r.prestigeMinutes.first, lessThan(60));
    });

    test('a player who never draws the gesture is only a little slower', () {
      final base = simulate(content, BotProfile.active.withLuckyCatch(0), length: threeHours);
      final none = simulate(
        content,
        const BotProfile(name: 'sin gesto', tapsPerSecond: 4, actEverySeconds: 2, finisherSuccess: 0, gestureSeconds: 0, luckyCatch: 0),
        length: threeHours,
      );
      expect(none.prestigeMinutes.first, lessThan(base.prestigeMinutes.first * 1.6));
    });

    test('a casual player (5 minutes every half hour) moves forward through offline earnings', () {
      final r = simulate(content, BotProfile.casual.withLuckyCatch(0), length: threeHours);
      expect(r.snapshots.last.bestFight, greaterThanOrEqualTo(19));
    });
  });

  test('the simulation is deterministic', () {
    final a = simulate(content, BotProfile.active, length: const Duration(minutes: 40));
    final b = simulate(content, BotProfile.active, length: const Duration(minutes: 40));
    expect(a.events.map((e) => '${e.label}@${e.minute.toStringAsFixed(3)}').toList(),
        b.events.map((e) => '${e.label}@${e.minute.toStringAsFixed(3)}').toList());
  });
}
