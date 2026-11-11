import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/formulas.dart';

import '../test_content.dart';

void main() {
  final content = loadTestContent();
  final f = Formulas(content.balance);
  final r = content.balance.costGrowth;

  group('HP and coins', () {
    test('HP(n) = 10 * 1.55^(n-1)', () {
      expect(f.baseHp(1).toDouble(), closeTo(10, 1e-9));
      expect(f.baseHp(2).toDouble(), closeTo(15.5, 1e-9));
      expect(f.baseHp(3).toDouble(), closeTo(24.025, 1e-9));
      expect(f.baseHp(10).toDouble(), closeTo(10 * 1.55 * 1.55 * 1.55 * 1.55 * 1.55 * 1.55 * 1.55 * 1.55 * 1.55, 1e-6));
    });

    test('Coins(n) = 0.15 * HP(n)', () {
      expect(f.coinsReward(1).toDouble(), closeTo(1.5, 1e-9));
      expect(f.coinsReward(2).toDouble(), closeTo(2.325, 1e-9));
    });

    test('boss: HP x10, coins x5 (from base HP)', () {
      expect(f.opponentHp(10, isBoss: true), f.baseHp(10).mulDouble(10));
      expect(f.coinsReward(10, isBoss: true).toDouble(),
          closeTo(f.baseHp(10).toDouble() * 0.15 * 5, 1e-6));
    });

    test('opponent multipliers apply', () {
      expect(f.opponentHp(1, hpMultiplier: 2).toDouble(), closeTo(20, 1e-9));
      expect(f.coinsReward(1, coinMultiplier: 3).toDouble(), closeTo(4.5, 1e-9));
    });

    test('fight number must be at least 1', () {
      expect(() => f.baseHp(0), throwsArgumentError);
    });

    test('HP keeps working for endless leagues', () {
      final hp = f.baseHp(5000);
      expect(hp.log10(), closeTo(1 + 4999 * 0.19033169817029893, 1e-5));
    });
  });

  group('Cost(k) = base * 1.15^k', () {
    test('level cost', () {
      expect(f.levelCost(10, 0).toDouble(), 10);
      expect(f.levelCost(10, 1).toDouble(), closeTo(11.5, 1e-9));
      expect(f.levelCost(10, 10).toDouble(), closeTo(10 * 4.0455577, 1e-5));
    });

    test('purchase cost rounds up to a whole coin', () {
      expect(f.purchaseCost(10, 1, 1), Big.fromInt(12)); // 11.5 -> 12
      expect(f.purchaseCost(10, 0, 1), Big.fromInt(10)); // exact stays
    });

    test('negative owned is rejected', () {
      expect(() => f.levelCost(10, -1), throwsArgumentError);
    });
  });

  group('bulk cost (buy x1, x10, x100)', () {
    double brute(double base, int owned, int count) {
      var sum = 0.0;
      for (var i = 0; i < count; i++) {
        sum += base * _pow(r, owned + i);
      }
      return sum;
    }

    test('matches summing each level one by one', () {
      for (final base in [10.0, 50.0, 12345.0]) {
        for (final owned in [0, 1, 7, 40, 120]) {
          for (final count in [1, 2, 10, 100]) {
            final exact = brute(base, owned, count);
            expect(f.bulkCost(base, owned, count).toDouble() / exact, closeTo(1, 1e-9),
                reason: 'base=$base owned=$owned count=$count');
          }
        }
      }
    });

    test('count 0 costs nothing, negative is rejected', () {
      expect(f.bulkCost(10, 5, 0), Big.zero);
      expect(() => f.bulkCost(10, 5, -1), throwsArgumentError);
    });

    test('x1 equals the level cost', () {
      expect(f.bulkCost(10, 3, 1), f.levelCost(10, 3));
    });
  });

  group('MAX affordable', () {
    int bruteMax(double coins, double base, int owned) {
      var spent = 0.0;
      var n = 0;
      while (true) {
        final next = (base * _pow(r, owned + n)).ceilToDouble();
        if (spent + next > coins) return n;
        spent += next;
        n++;
      }
    }

    test('nothing affordable returns 0', () {
      expect(f.maxAffordable(Big.fromInt(9), 10, 0), 0);
      expect(f.maxAffordable(Big.zero, 10, 0), 0);
    });

    test('exactly one level', () {
      expect(f.maxAffordable(Big.fromInt(10), 10, 0), 1);
    });

    test('result is the largest count whose cost fits, never more', () {
      for (final coins in [10.0, 25.0, 100.0, 1000.0, 54321.0, 1e7]) {
        for (final owned in [0, 3, 25]) {
          final m = f.maxAffordable(Big.fromDouble(coins), 10, owned);
          if (m > 0) {
            expect(f.purchaseCost(10, owned, m) <= Big.fromDouble(coins), isTrue,
                reason: 'cost of $m must fit in $coins (owned $owned)');
          }
          expect(f.purchaseCost(10, owned, m + 1) > Big.fromDouble(coins), isTrue,
              reason: '${m + 1} must not fit in $coins (owned $owned)');
        }
      }
    });

    test('agrees with a one-at-a-time buyer within the rounding of whole coins', () {
      // The bulk price rounds the total once, the brute force rounds each
      // level, so they may differ by at most one level.
      for (final coins in [100.0, 1000.0, 54321.0]) {
        final m = f.maxAffordable(Big.fromDouble(coins), 10, 0);
        expect((m - bruteMax(coins, 10, 0)).abs(), lessThanOrEqualTo(1));
      }
    });

    test('is capped by maxBulkLevels from balance.json', () {
      final capped = Formulas(loadTestContent((files) {
        files['balance.json']!['buy']['maxBulkLevels'] = 50;
      }).balance);
      // 1e30 coins could afford ~500 levels; the cap of 50 wins.
      expect(capped.maxAffordable(Big.powOf(10, 30), 10, 0), 50);
    });

    test('works with very large coin amounts', () {
      final m = f.maxAffordable(Big.powOf(10, 200), 10, 0);
      expect(m, greaterThan(3000));
      expect(f.purchaseCost(10, 0, m) <= Big.powOf(10, 200), isTrue);
      expect(f.purchaseCost(10, 0, m + 1) > Big.powOf(10, 200), isTrue);
    });
  });

  group('Belts', () {
    test('floor(sqrt(C / 1e6))', () {
      expect(f.belts(Big.fromDouble(1e6)), Big.fromInt(1));
      expect(f.belts(Big.fromDouble(4e6)), Big.fromInt(2));
      expect(f.belts(Big.fromDouble(9.9e6)), Big.fromInt(3));
      expect(f.belts(Big.fromDouble(999999)), Big.zero);
      expect(f.belts(Big.zero), Big.zero);
    });
  });
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
