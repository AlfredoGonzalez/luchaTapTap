import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/data/content_exception.dart';

import '../test_content.dart';

typedef Files = Map<String, Map<String, dynamic>>;

/// An engine with lots of coins; [special] goes on the first trainer.
GameEngine engineWith(Map<String, dynamic>? special, [void Function(Files)? more]) {
  final content = loadTestContent((f) {
    f['balance.json']!['start'] = {'coins': 1e12, 'fightNumber': 1};
    if (special != null) f['trainers.json']!['trainers'][0]['special'] = special;
    more?.call(f);
  });
  return GameEngine(content: content);
}

void main() {
  group('trainer specials', () {
    test('coinGain adds a share per level up to its cap', () {
      final plain = engineWith(null);
      final base = plain.currentReward.toDouble();
      final e = engineWith({'type': 'coinGain', 'perLevel': 0.1, 'maxBonus': 0.5});
      e.buyTrainer('don_chuy', const BuyAmount.fixed(3));
      expect(e.currentReward.toDouble(), closeTo(base * 1.3, 1e-9));
      e.buyTrainer('don_chuy', const BuyAmount.fixed(20));
      expect(e.currentReward.toDouble(), closeTo(base * 1.5, 1e-9)); // capped
    });

    test('coinMultiplier applies only while the trainer is hired', () {
      final e = engineWith({'type': 'coinMultiplier', 'multiplier': 2.0});
      final base = e.currentReward.toDouble();
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      expect(e.currentReward.toDouble(), closeTo(base * 2, 1e-9));
    });

    test('comboDamage grows the trainer damage with the combo bar', () {
      final e = engineWith({'type': 'comboDamage', 'bonus': 1.0});
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      double ratio() =>
          e.damagePerSecondOf(withSkills: true).toDouble() /
          e.damagePerSecondOf(withSkills: true, withCombo: false).toDouble();
      expect(ratio(), closeTo(1, 1e-9));
      for (var i = 0; i < 5; i++) {
        e.tap();
      }
      expect(ratio(), closeTo(1 + e.state.comboMeter, 1e-9));
      for (var i = 0; i < 5; i++) {
        e.tap();
      }
      expect(e.state.comboMeter, closeTo(1, 1e-9));
      expect(ratio(), closeTo(2, 1e-9));
    });

    test('the combo bonus does not count while the app is closed', () {
      final e = engineWith({'type': 'comboDamage', 'bonus': 1.0});
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      for (var i = 0; i < 10; i++) {
        e.tap();
      }
      expect(e.state.comboMeter, closeTo(1, 1e-9));
      final away = e.damagePerSecondOf(withSkills: false).toDouble();
      final noCombo = e.damagePerSecondOf(withSkills: false, withCombo: false).toDouble();
      expect(away, noCombo);
      expect(e.damagePerSecond.toDouble(), greaterThan(away));
    });

    test('skillCooldown shortens the recharge, within the global cap', () {
      final plain = engineWith(null);
      final skill = plain.content.skills.first;
      final base = plain.cooldownOf(skill);
      final e = engineWith({'type': 'skillCooldown', 'perLevel': 0.1, 'maxBonus': 0.4});
      e.buyTrainer('don_chuy', const BuyAmount.fixed(2));
      expect(e.cooldownOf(skill), closeTo(base * 0.8, 1e-9));
      e.buyTrainer('don_chuy', const BuyAmount.fixed(30));
      expect(e.cooldownOf(skill), closeTo(base * 0.6, 1e-9)); // maxBonus
    });

    test('a bad special is rejected when the data loads', () {
      expect(
        () => engineWith({'type': 'flying'}),
        throwsA(isA<ContentException>()),
      );
      expect(
        () => engineWith({'type': 'coinMultiplier', 'multiplier': 1.0}),
        throwsA(isA<ContentException>()),
      );
      expect(
        () => engineWith({'type': 'coinGain', 'perLevel': 0.1}),
        throwsA(isA<ContentException>()),
      );
    });

    test('the shipped trainers carry the four specials', () {
      final shipped = loadShippedContent();
      final kinds = {
        for (final t in shipped.trainers)
          if (t.special != null) t.id: t.special!.type.name,
      };
      expect(kinds, {
        'la_licenciada': 'coinGain',
        'las_porras': 'comboDamage',
        'tortilleria_el_puno': 'coinMultiplier',
        'doctor_vendajes': 'skillCooldown',
      });
    });
  });
}
