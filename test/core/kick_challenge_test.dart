import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/kick_challenge.dart';
import 'package:lucha_tap_tap/core/rng.dart';

const settings = KickSettings(
  targets: 3,
  circleSeconds: 1.0,
  startDelaySeconds: 0.5,
  gapSeconds: 0.2,
  minMoveFraction: 0.3,
);

KickChallenge fresh([int seed = 1]) => KickChallenge(settings, SeededRng(seed));

/// Advances in small steps until a circle shows (or gives up).
void untilCircle(KickChallenge k) {
  for (var i = 0; i < 200 && !k.circleVisible && k.isActive; i++) {
    k.tick(0.05);
  }
}

void main() {
  group('kick challenge', () {
    test('nothing happens until it starts, then the first circle waits for the delay', () {
      final k = fresh();
      k.tick(5);
      expect(k.status, KickStatus.idle);
      k.start();
      k.tick(0.3);
      expect(k.circleVisible, isFalse);
      k.tick(0.3);
      expect(k.circleVisible, isTrue);
      expect(k.remaining, 1);
    });

    test('a circle shrinks to nothing and vanishing loses the kick', () {
      final k = fresh()..start();
      untilCircle(k);
      k.tick(0.5);
      expect(k.remaining, closeTo(0.5, 1e-9));
      k.tick(0.6);
      expect(k.status, KickStatus.failed);
      expect(k.circleVisible, isFalse);
    });

    test('tapping every circle in time lands the kick', () {
      final k = fresh()..start();
      for (var i = 0; i < settings.targets; i++) {
        untilCircle(k);
        expect(k.circleVisible, isTrue);
        expect(k.hits, i);
        k.tick(0.3);
        expect(k.hit(), isTrue);
      }
      expect(k.status, KickStatus.success);
      expect(k.hits, 3);
    });

    test('a tap with no circle on screen does nothing', () {
      final k = fresh()..start();
      expect(k.hit(), isFalse); // still in the start delay
      untilCircle(k);
      expect(k.hit(), isTrue);
      expect(k.hit(), isFalse); // already tapped, the next one has not come
    });

    test('there is a pause between a tapped circle and the next one', () {
      final k = fresh()..start();
      untilCircle(k);
      k.hit();
      k.tick(0.1);
      expect(k.circleVisible, isFalse);
      k.tick(0.15);
      expect(k.circleVisible, isTrue);
    });

    test('circles appear at random places inside the area, and move between taps', () {
      final k = fresh(7)..start();
      final spots = <(double, double)>[];
      for (var i = 0; i < 40; i++) {
        if (!k.isActive) k.start();
        untilCircle(k);
        expect(k.x, inInclusiveRange(0.0, 1.0));
        expect(k.y, inInclusiveRange(0.0, 1.0));
        spots.add((k.x, k.y));
        k.hit();
      }
      expect(spots.toSet().length, greaterThan(30)); // not always the same place
      // Inside one challenge, neighbours are at least minMoveFraction apart
      // (the generator retries a few times, so check most of them).
      var far = 0;
      var pairs = 0;
      for (var i = 1; i < spots.length; i++) {
        final dx = spots[i].$1 - spots[i - 1].$1;
        final dy = spots[i].$2 - spots[i - 1].$2;
        pairs++;
        if (dx * dx + dy * dy >= 0.3 * 0.3) far++;
      }
      expect(far / pairs, greaterThan(0.8));
    });

    test('the same seed gives the same places', () {
      List<(double, double)> run() {
        final k = fresh(42)..start();
        final out = <(double, double)>[];
        while (k.isActive) {
          untilCircle(k);
          if (!k.isActive) break;
          out.add((k.x, k.y));
          k.hit();
        }
        return out;
      }

      expect(run(), run());
      expect(run().length, settings.targets);
    });

    test('reset puts it back to idle', () {
      final k = fresh()..start();
      untilCircle(k);
      k.reset();
      expect(k.status, KickStatus.idle);
      expect(k.circleVisible, isFalse);
      expect(k.hits, 0);
    });
  });
}
