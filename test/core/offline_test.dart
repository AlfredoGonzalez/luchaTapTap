import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/formulas.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';

import '../test_content.dart';

typedef Edit = void Function(Map<String, Map<String, dynamic>>);

const x1 = BuyAmount.fixed(1);

/// No mask equipped, 1e9 coins and one Don Chuy hired (1 damage per second).
GameEngine hired([Edit? edit]) {
  final content = loadTestContent((f) {
    f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1};
    edit?.call(f);
  });
  final fresh = GameEngine(content: content);
  final e = GameEngine(content: content, state: fresh.state.copyWith(clearEquippedMask: true));
  e.buyTrainer('don_chuy', x1);
  return e;
}

void main() {
  group('offline cap (4 h base + Siesta + purchase, at most 8 h)', () {
    test('base cap', () {
      expect(hired().offlineCapHours, 4);
    });

    test('Siesta adds 0.5 h per level', () {
      final e = hired();
      e.debugGrantBelts(100);
      e.buyTalent('entrenamiento');
      e.buyTalent('siesta');
      e.buyTalent('siesta');
      expect(e.offlineCapHours, 5);
    });

    test('the "Más descanso" purchase adds its hours', () {
      final e = hired();
      e.grantPurchase('mas_descanso');
      expect(e.offlineCapHours, 6);
    });

    test('they add up but never pass the maximum', () {
      final e = hired();
      e.debugGrantBelts(100);
      e.buyTalent('entrenamiento');
      for (var i = 0; i < 4; i++) {
        e.buyTalent('siesta'); // +2 h
      }
      e.grantPurchase('mas_descanso'); // +2 h -> 8 h
      expect(e.offlineCapHours, 8);
      e.grantMask('la_calaverita');
      expect(e.offlineCapHours, lessThanOrEqualTo(8));
    });

    test('a purchase without cap hours adds nothing', () {
      final e = hired();
      e.grantPurchase('doble_moneda');
      expect(e.offlineCapHours, 4);
    });

    test('all of it comes from balance.json', () {
      final e = hired((f) {
        f['balance.json']!['offline']['baseCapHours'] = 1;
        f['balance.json']!['offline']['maxCapHours'] = 3;
      });
      expect(e.offlineCapHours, 1);
      e.grantPurchase('mas_descanso'); // +2 -> 3
      expect(e.offlineCapHours, 3);
    });
  });

  group('offline progress', () {
    test('nothing happens with no trainers', () {
      final content = loadTestContent();
      final e = GameEngine(content: content);
      expect(e.applyOffline(const Duration(hours: 1)), isNull);
      expect(e.state.fightNumber, 1);
    });

    test('no time or negative time (clock moved back) does nothing', () {
      final e = hired();
      expect(e.applyOffline(Duration.zero), isNull);
      expect(e.applyOffline(const Duration(hours: -3)), isNull);
      expect(e.state.fightNumber, 1);
      expect(e.state.pendingOffline, isNull);
    });

    test('trainers fight through the regular opponents and pay normal coins', () {
      final e = hired();
      final f = Formulas(e.content.balance);
      final report = e.applyOffline(const Duration(seconds: 100))!;
      // 1 damage per second for 100 s = 100 damage.
      var budget = 100.0;
      var fight = 1;
      var coins = 0.0;
      while (budget >= f.baseHp(fight).toDouble()) {
        budget -= f.baseHp(fight).toDouble();
        coins += f.coinsReward(fight).toDouble();
        fight++;
      }
      expect(report.defeats, fight - 1);
      expect(report.coinsEarned.toDouble(), closeTo(coins, 1e-6));
      expect(e.state.fightNumber, fight);
      expect(e.state.enemyHp.toDouble(), closeTo(f.baseHp(fight).toDouble() - budget, 1e-6));
    });

    test('it stops at the fight before the boss and farms it with a division', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 1e12);
      final f = Formulas(e.content.balance);
      // Damage per second at the time of leaving (achievements won while
      // away must not change what the trainers did).
      final dps = e.damagePerSecondOf(withSkills: false).toDouble();
      final report = e.applyOffline(const Duration(hours: 8))!;
      // The player is held at fight 9, not sent into the boss.
      expect(e.state.fightNumber, 9);
      expect(e.bossGateReady, isTrue);
      expect(e.isBossFight, isFalse);
      expect(e.state.bossTimeLeft, isNull);
      // Fights 1 to 8 once each, then fight 9 over and over.
      var hpBefore9 = 0.0;
      var coins = 0.0;
      for (var n = 1; n <= 8; n++) {
        hpBefore9 += f.baseHp(n).toDouble();
        coins += f.coinsReward(n).toDouble();
      }
      final hp9 = f.baseHp(9).toDouble();
      final budget = dps * 4 * 3600; // 4 h cap
      final kills9 = 1 + ((budget - hpBefore9 - hp9) / hp9).floor();
      coins += kills9 * f.coinsReward(9).toDouble();
      expect(report.defeats, 8 + kills9);
      expect(report.coinsEarned.toDouble() / coins, closeTo(1, 1e-6));
      expect(e.state.enemyHp > Big.zero, isTrue);
      expect(e.state.enemyHp <= e.enemyMaxHp, isTrue);
    });

    test('farming the gate for 100 hours of dps is still instant', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 1e30);
      final clock = Stopwatch()..start();
      e.applyOffline(const Duration(hours: 8));
      expect(clock.elapsedMilliseconds, lessThan(100));
      expect(e.state.fightNumber, 9);
    });

    test('while standing at a boss nothing progresses', () {
      final e = hired();
      e.debugGoToBoss();
      expect(e.applyOffline(const Duration(hours: 4)), isNull);
      expect(e.state.fightNumber, 10);
    });

    test('time beyond the cap does not count', () {
      final a = hired();
      final b = hired();
      final capped = a.applyOffline(const Duration(hours: 100))!;
      final exact = b.applyOffline(Duration(seconds: (b.offlineCapHours * 3600).round()))!;
      expect(capped.coinsEarned, exact.coinsEarned);
      expect(capped.capped, isTrue);
      expect(exact.capped, isFalse);
      expect(capped.appliedSeconds, 4 * 3600);
    });

    test('earnings wait for the player when away at least a minute', () {
      final e = hired();
      final before = e.state.coins;
      final report = e.applyOffline(const Duration(minutes: 5))!;
      expect(e.state.pendingOffline, same(report));
      expect(e.state.coins, before); // not paid yet
      final paid = e.collectOffline()!;
      expect(paid, report.coinsEarned);
      expect(e.state.coins, before + paid);
      expect(e.state.pendingOffline, isNull);
      expect(e.collectOffline(), isNull);
    });

    test('collecting with the ad multiplier doubles the amount', () {
      final e = hired();
      final before = e.state.coins;
      final report = e.applyOffline(const Duration(minutes: 5))!;
      final multiplier = e.content.balance.offline.adMultiplier;
      e.collectOffline(multiplier: multiplier);
      expect(e.state.coins, before + report.coinsEarned.mulDouble(2));
    });

    test('a short absence is paid right away, with no pop-up', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 100);
      final before = e.state.coins;
      final report = e.applyOffline(const Duration(seconds: 30))!;
      expect(e.state.pendingOffline, isNull);
      expect(e.state.coins, before + report.coinsEarned);
    });

    test('offline coins count toward the prestige belts', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 100);
      e.applyOffline(const Duration(minutes: 10));
      e.collectOffline();
      expect(e.state.totalCoinsEarned > Big.zero, isTrue);
    });

    test('skills and timers do not move while away', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 5);
      e.debugSkipFights(8);
      e.buySkill('grito');
      e.useSkill('grito');
      final cooldown = e.state.skillCooldownLeft('grito');
      final active = e.state.skillActiveLeft('grito');
      final combo = e.state.comboMeter;
      e.applyOffline(const Duration(hours: 1));
      expect(e.state.skillCooldownLeft('grito'), cooldown);
      expect(e.state.skillActiveLeft('grito'), active);
      expect(e.state.comboMeter, combo);
      expect(e.state.lucky, isNull);
    });

    test('active skills do not boost offline damage', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 2);
      e.debugSkipFights(8);
      e.buySkill('grito');
      e.useSkill('grito');
      expect(e.damagePerSecond.toDouble(), closeTo(4, 1e-9));
      expect(e.damagePerSecondOf(withSkills: false).toDouble(), closeTo(2, 1e-9));
    });

    test('progress feeds achievements', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 100);
      e.applyOffline(const Duration(hours: 1));
      expect(e.state.achievements, contains('primera_victoria'));
    });

    test('eight hours compute in under 100 ms', () {
      final e = hired((f) {
        f['trainers.json']!['trainers'][0]['baseDps'] = 1e15;
        f['balance.json']!['offline'] = {
          'baseCapHours': 8,
          'maxCapHours': 8,
          'minPopupSeconds': 60,
          'adMultiplier': 2,
          'purchaseCapHours': {'mas_descanso': 2},
        };
      });
      final clock = Stopwatch()..start();
      final report = e.applyOffline(const Duration(hours: 8))!;
      clock.stop();
      expect(report.appliedSeconds, 8 * 3600);
      expect(clock.elapsedMilliseconds, lessThan(100));
    });

    test('repeated offline rounds with a loop of leagues stay cheap', () {
      final e = hired((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 1e12);
      final clock = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        e.applyOffline(const Duration(hours: 8));
        e.collectOffline();
        e.debugGoToBoss();
        e.debugSkipFights(1); // past the boss, into the next pass
      }
      expect(clock.elapsedMilliseconds, lessThan(1000));
    });
  });
}
