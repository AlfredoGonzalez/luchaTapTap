import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/data/content_exception.dart';

import '../test_content.dart';

typedef Edit = void Function(Map<String, Map<String, dynamic>>);

GameEngine withMilestones({List<int> levels = const [2, 5], double multiplier = 3, Edit? edit}) {
  final content = loadTestContent((f) {
    f['balance.json']!['milestones'] = {'levels': levels, 'multiplier': multiplier};
    f['balance.json']!['start'] = {'coins': 1e100, 'fightNumber': 1};
    edit?.call(f);
  });
  final fresh = GameEngine(content: content);
  return GameEngine(content: content, state: fresh.state.copyWith(clearEquippedMask: true));
}

void main() {
  group('milestone multipliers', () {
    test('without a milestones section nothing changes', () {
      final content = loadTestContent();
      expect(content.balance.milestones.levels, isEmpty);
      expect(content.balance.milestones.factorAt(500), Big.one);
    });

    test('a trainer is multiplied each time it reaches a milestone level', () {
      final e = withMilestones();
      final base = e.content.trainer('don_chuy').baseDps;
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      expect(e.damagePerSecond.toDouble(), closeTo(base * 1, 1e-9)); // level 1
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      expect(e.damagePerSecond.toDouble(), closeTo(base * 2 * 3, 1e-9)); // level 2: first milestone
      e.buyTrainer('don_chuy', const BuyAmount.fixed(3));
      expect(e.damagePerSecond.toDouble(), closeTo(base * 5 * 9, 1e-9)); // level 5: second milestone
      e.buyTrainer('don_chuy', const BuyAmount.fixed(2));
      expect(e.damagePerSecond.toDouble(), closeTo(base * 7 * 9, 1e-9)); // no third milestone
    });

    test('tap upgrades get the same multiplier', () {
      final e = withMilestones();
      final per = e.content.upgrade('puno_duro').perLevelValue;
      final tap0 = e.content.balance.baseTapDamage;
      e.buyUpgrade('puno_duro', const BuyAmount.fixed(1));
      expect(e.tapDamage.toDouble(), closeTo(tap0 + per * 1, 1e-9));
      e.buyUpgrade('puno_duro', const BuyAmount.fixed(1));
      expect(e.tapDamage.toDouble(), closeTo(tap0 + per * 2 * 3, 1e-9));
    });

    test('buying many levels at once still counts every milestone passed', () {
      final e = withMilestones(levels: [10, 25, 50], multiplier: 2);
      final base = e.content.trainer('don_chuy').baseDps;
      e.buyTrainer('don_chuy', const BuyAmount.fixed(60));
      expect(e.damagePerSecond.toDouble(), closeTo(base * 60 * 8, 1e-6));
    });

    test('prices are not affected by milestones', () {
      final a = withMilestones();
      final b = GameEngine(content: loadTestContent());
      expect(a.quoteTrainer('don_chuy', const BuyAmount.fixed(1)).cost,
          b.quoteTrainer('don_chuy', const BuyAmount.fixed(1)).cost);
    });

    test('a thousand levels stay finite (Big numbers)', () {
      final levels = [for (var i = 1; i <= 30; i++) i * 30];
      final e = withMilestones(levels: levels, multiplier: 100);
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1000));
      expect(e.damagePerSecond.exponent, greaterThan(60)); // 100^30 = 1e60 and more
    });

    test('data drives it: the same build with a bigger multiplier hits harder', () {
      final a = withMilestones(multiplier: 2);
      final b = withMilestones(multiplier: 4);
      a.buyTrainer('don_chuy', const BuyAmount.fixed(5));
      b.buyTrainer('don_chuy', const BuyAmount.fixed(5));
      expect(b.damagePerSecond > a.damagePerSecond, isTrue);
    });
  });

  group('milestone progress (for the list rows)', () {
    final m = withMilestones(levels: [10, 20]).content.balance.milestones;

    test('the next milestone is the first level above the current one', () {
      expect(m.nextAfter(0), 10);
      expect(m.nextAfter(10), 20);
      expect(m.nextAfter(20), isNull);
    });

    test('progress runs from the previous milestone to the next', () {
      expect(m.progressAt(0), 0);
      expect(m.progressAt(5), 0.5);
      expect(m.progressAt(10), 0);
      expect(m.progressAt(15), 0.5);
      expect(m.progressAt(25), 1);
    });
  });

  group('milestone configuration is validated', () {
    void invalid(Map<String, dynamic> section, String message) {
      expect(
        () => loadTestContent((f) => f['balance.json']!['milestones'] = section),
        throwsA(isA<ContentException>().having((e) => e.message, 'message', contains(message))),
      );
    }

    test('levels must increase', () => invalid({'levels': [10, 5], 'multiplier': 2}, 'increasing'));
    test('levels start at 1', () => invalid({'levels': [0, 5], 'multiplier': 2}, 'at least 1'));
    test('the multiplier is at least 1', () => invalid({'levels': [5], 'multiplier': 0.5}, 'multiplier'));
    test('both keys are required', () => invalid({'levels': [5]}, 'multiplier'));
  });
}
