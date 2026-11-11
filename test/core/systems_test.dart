import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/formulas.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/rng.dart';

import '../test_content.dart';

const x1 = BuyAmount.fixed(1);

typedef Edit = void Function(Map<String, Map<String, dynamic>>);

/// Engine with no mask equipped (easy arithmetic) and [edit] applied to the
/// data files.
GameEngine newEngine([Edit? edit]) {
  final content = loadTestContent(edit);
  final fresh = GameEngine(content: content);
  return GameEngine(content: content, state: fresh.state.copyWith(clearEquippedMask: true));
}

void main() {
  group('league structure and bosses', () {
    final content = loadTestContent();

    test('9 regular fights then the boss, then the league repeats', () {
      final ids = [for (var f = 1; f <= 11; f++) content.fightInfo(f).opponent.id];
      expect(ids[8], 'el_taquero_cosmico');
      expect(ids[9], 'el_mariachi_furioso');
      expect(ids[10], 'mr_aguacate'); // endless leagues: back to the start
      expect(content.fightInfo(10).isBoss, isTrue);
      expect(content.fightInfo(9).isBoss, isFalse);
      expect(content.fightInfo(11).loops, 1);
      expect(content.leagueEndFight(1), 10);
    });

    test('boss HP is x10 and pays x5 coins', () {
      final e = newEngine();
      e.debugGoToBoss();
      final f = Formulas(e.content.balance);
      expect(e.state.fightNumber, 10);
      expect(e.isBossFight, isTrue);
      expect(e.state.enemyHp, f.baseHp(10).mulDouble(10));
      expect(e.currentReward.toDouble(), closeTo(f.baseHp(10).toDouble() * 0.15 * 5, 1e-6));
    });

    test('loopScale multiplies HP on repeated leagues', () {
      final e = newEngine((f) => f['leagues.json']!['leagues'][0]['loopScale'] = 3.0);
      final f = Formulas(e.content.balance);
      e.debugSkipFights(10); // fight 11, second pass
      expect(e.state.enemyHp.toDouble(), closeTo(f.baseHp(11).toDouble() * 3, 1e-6));
    });

    test('the boss waits for its intro: nothing happens until startBoss', () {
      final e = newEngine((f) => f['trainers.json']!['trainers'][0]['baseDps'] = 5);
      e.debugGoToBoss();
      e.debugAddCoins(Big.fromInt(1000));
      e.buyTrainer('don_chuy', x1);
      expect(e.awaitingBossStart, isTrue);
      final hp = e.state.enemyHp;
      for (var i = 0; i < 50; i++) {
        e.tick();
      }
      expect(e.tap().defeats, 0);
      expect(e.tap().damageDealt, Big.zero); // taps are ignored too
      expect(e.state.enemyHp, hp);
      expect(e.state.bossTimeLeft, isNull);
      e.startBoss();
      expect(e.awaitingBossStart, isFalse);
      expect(e.state.bossTimeLeft, 30);
      e.tick();
      expect(e.state.enemyHp < hp, isTrue); // now the fight is on
    });

    test('the countdown runs and failing drops one fight', () {
      final e = newEngine();
      e.debugGoToBoss();
      expect(e.state.bossTimeLeft, isNull);
      e.startBoss();
      e.tick();
      expect(e.state.bossTimeLeft, closeTo(29.9, 1e-9));
      var ticks = 1;
      var timedOut = false;
      while (!timedOut && ticks < 400) {
        timedOut = e.tick().bossTimedOut;
        ticks++;
      }
      expect(timedOut, isTrue);
      expect(ticks, inInclusiveRange(300, 302)); // 30 s at 10 ticks per second
      expect(e.state.fightNumber, 9);
      expect(e.isBossFight, isFalse);
      expect(e.state.bossTimeLeft, isNull);
      expect(e.state.enemyHp, e.enemyMaxHp); // no lingering damage
    });

    test('an opponent can override the boss timer', () {
      final e = newEngine((f) {
        final opp = (f['opponents.json']!['opponents'] as List).last as Map;
        opp['bossTimerSeconds'] = 12;
      });
      e.debugGoToBoss();
      e.startBoss();
      expect(e.state.bossTimeLeft, 12);
    });

    test('defeating the boss clears the timer, pays and counts it', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 1e9});
      e.debugGoToBoss();
      e.startBoss();
      expect(e.state.bossTimeLeft, isNotNull);
      final r = e.tap();
      expect(r.defeats, 1);
      expect(e.state.fightNumber, 11);
      expect(e.state.bossTimeLeft, isNull);
      expect(e.state.stat('bosses'), 1);
    });
  });

  group('combo and finisher', () {
    test('taps fill the meter; 10 taps make the finisher ready', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 0.001});
      expect(e.finisherReady, isFalse);
      for (var i = 0; i < 9; i++) {
        e.tap();
      }
      expect(e.state.comboMeter, closeTo(0.9, 1e-9));
      expect(e.finisher(), isNull);
      e.tap();
      expect(e.finisherReady, isTrue);
    });

    test('finisher hits for 20x tap damage and empties the meter', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 0.001});
      for (var i = 0; i < 10; i++) {
        e.tap();
      }
      final r = e.finisher()!;
      expect(r.damageDealt.toDouble(), closeTo(0.02, 1e-12));
      expect(e.state.comboMeter, 0);
      expect(e.finisher(), isNull);
    });

    test('the meter holds, then decays when the player stops', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 0.001});
      for (var i = 0; i < 5; i++) {
        e.tap();
      }
      for (var i = 0; i < 14; i++) {
        e.tick(); // 1.4 s: still inside the 1.5 s hold
      }
      expect(e.state.comboMeter, closeTo(0.5, 1e-9));
      for (var i = 0; i < 16; i++) {
        e.tick(); // past the hold, decays 0.5 per second
      }
      expect(e.state.comboMeter, lessThan(0.5));
      for (var i = 0; i < 60; i++) {
        e.tick();
      }
      expect(e.state.comboMeter, 0);
    });
  });

  group('critical hits', () {
    test('with a guaranteed chance every tap multiplies damage', () {
      final e = newEngine((f) {
        f['balance.json']!['crit'] = {'multiplier': 3, 'maxChance': 1};
        f['balance.json']!['start'] = {'coins': 1e6, 'fightNumber': 1};
        f['upgrades.json']!['upgrades'][1]['perLevelValue'] = 1.0;
      });
      e.buyUpgrade('golpe_certero', x1);
      expect(e.critChance, 1);
      final r = e.tap();
      expect(r.isCrit, isTrue);
      expect(r.damageDealt.toDouble(), closeTo(3, 1e-9));
    });

    test('chance is capped by balance.json', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1};
        f['upgrades.json']!['upgrades'][1]['perLevelValue'] = 0.5;
      });
      e.buyUpgrade('golpe_certero', const BuyAmount.fixed(10));
      expect(e.critChance, 0.75);
    });

    test('no crit chance never consumes randomness or crits', () {
      final e = newEngine();
      final before = e.rng.state;
      expect(e.tap().isCrit, isFalse);
      expect(e.rng.state, before);
    });
  });

  group('skills', () {
    GameEngine rich([Edit? edit]) => newEngine((f) {
          f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1};
          edit?.call(f);
        });

    test('locked until its fight, then learnable with coins', () {
      final e = rich();
      expect(e.quoteSkill('plancha').failure, BuyFailure.locked);
      e.debugSkipFights(2);
      expect(e.quoteSkill('plancha').canBuy, isTrue);
      final q = e.buySkill('plancha');
      expect(q.cost.toDouble(), 200);
      expect(e.state.skillLevel('plancha'), 1);
      expect(e.quoteSkill('plancha').cost.toDouble(), 230); // 200 * 1.15
    });

    test('cannot use a skill that is not learned', () {
      final e = rich();
      expect(e.useSkill('plancha').failure, SkillFailure.notLearned);
      expect(e.useSkill('nope').failure, SkillFailure.unknown);
    });

    test('max level is enforced', () {
      final e = rich((f) => f['skills.json']!['skills'][0]['maxLevel'] = 2);
      e.debugSkipFights(2);
      e.buySkill('plancha');
      e.buySkill('plancha');
      expect(e.quoteSkill('plancha').failure, BuyFailure.maxed);
    });

    test('Plancha hits for value x tap damage, then goes on cooldown', () {
      final e = rich();
      e.debugSkipFights(2);
      e.buySkill('plancha');
      final r = e.useSkill('plancha');
      expect(r.ok, isTrue);
      expect(r.outcome.damageDealt.toDouble(), closeTo(15, 1e-9)); // level 1: 15x
      expect(e.useSkill('plancha').failure, SkillFailure.cooldown);
      expect(e.state.skillCooldownLeft('plancha'), 25);
      for (var i = 0; i < 251; i++) {
        e.tick();
      }
      expect(e.state.skillCooldownLeft('plancha'), 0);
      expect(e.useSkill('plancha').ok, isTrue);
    });

    test('level raises the value', () {
      final e = rich();
      e.debugSkipFights(2);
      e.buySkill('plancha');
      e.buySkill('plancha');
      expect(e.useSkill('plancha').outcome.damageDealt.toDouble(), closeTo(20, 1e-9));
    });

    test('Furia multiplies taps while active and then ends', () {
      final e = rich();
      e.debugSkipFights(4);
      e.buySkill('furia');
      final before = e.tapDamage.toDouble();
      e.useSkill('furia');
      expect(e.tapDamage.toDouble(), closeTo(before * 2, 1e-9));
      for (var i = 0; i < 101; i++) {
        e.tick(); // 10 s
      }
      expect(e.tapDamage.toDouble(), closeTo(before, 1e-9));
    });

    test('Grito multiplies trainer damage while active', () {
      final e = rich();
      e.debugSkipFights(8);
      e.buySkill('grito');
      e.buyTrainer('don_chuy', x1);
      final before = e.damagePerSecond.toDouble();
      e.useSkill('grito');
      expect(e.damagePerSecond.toDouble(), closeTo(before * 2, 1e-9));
    });

    test('Llave adds seconds to the boss timer, and only works in a boss fight', () {
      final e = rich();
      e.debugSkipFights(9);
      e.buySkill('llave');
      expect(e.useSkill('llave').failure, SkillFailure.waitingBoss); // intro not done
      e.debugSkipFights(-1);
      expect(e.isBossFight, isFalse);
      expect(e.useSkill('llave').failure, SkillFailure.noBoss);
      expect(e.state.skillCooldownLeft('llave'), 0); // a failed use costs nothing
      e.debugGoToBoss();
      e.startBoss();
      e.tick();
      final before = e.state.bossTimeLeft!;
      expect(e.useSkill('llave').ok, isTrue);
      expect(e.state.bossTimeLeft, closeTo(before + 10, 1e-9));
    });

    test('talent shortens cooldowns, never beyond the cap', () {
      final e = rich((f) => f['skills.json']!['skills'][0]['cooldown'] = 100);
      e.debugSkipFights(2);
      e.buySkill('plancha');
      final skill = e.content.skill('plancha');
      expect(e.cooldownOf(skill), 100);
      // Four talent levels of 5% = 20% shorter.
      e.debugGrantBelts(100);
      for (var i = 0; i < 4; i++) {
        e.buyTalent('descanso_corto');
      }
      expect(e.cooldownOf(skill), closeTo(80, 1e-9));
    });
  });

  group('lucky events', () {
    test('a pickup appears, expires, and can be collected for coins', () {
      final e = newEngine((f) {
        f['balance.json']!['lucky'] = {'spawnPerSecond': 1000, 'lifetimeSeconds': 1, 'rewardCoinMultiple': 8};
      });
      expect(e.state.lucky, isNull);
      expect(e.tick().luckySpawned, isTrue);
      final lucky = e.state.lucky!;
      expect(lucky.x, inInclusiveRange(0, 1));
      expect(lucky.y, inInclusiveRange(0, 1));
      final reward = e.collectLucky()!;
      expect(reward.toDouble(), closeTo(1.5 * 8, 1e-9)); // current fight pays 1.5
      expect(e.state.coins, reward);
      expect(e.state.lucky, isNull);
      expect(e.collectLucky(), isNull);
    });

    test('an uncollected pickup vanishes after its lifetime', () {
      final e = newEngine((f) {
        f['balance.json']!['lucky'] = {'spawnPerSecond': 1000, 'lifetimeSeconds': 1, 'rewardCoinMultiple': 8};
      });
      e.tick();
      expect(e.state.lucky, isNotNull);
      for (var i = 0; i < 11; i++) {
        e.tick();
      }
      // It vanished (a new one may have appeared at this absurd spawn rate).
      expect(e.state.lucky == null || e.state.lucky!.lifeLeft > 0.5, isTrue);
    });

    test('a spawn rate of zero never spawns', () {
      final e = newEngine((f) {
        f['balance.json']!['lucky'] = {'spawnPerSecond': 0, 'lifetimeSeconds': 1, 'rewardCoinMultiple': 8};
      });
      for (var i = 0; i < 200; i++) {
        e.tick();
      }
      expect(e.state.lucky, isNull);
    });
  });

  group('talents', () {
    GameEngine withBelts(int belts, [Edit? edit]) {
      final e = newEngine(edit);
      e.debugGrantBelts(belts);
      return e;
    }

    test('need belts and a parent', () {
      final e = newEngine();
      expect(e.quoteTalent('punos_acero').failure, BuyFailure.notEnoughBelts);
      expect(e.quoteTalent('nope').failure, BuyFailure.unknownItem);
      e.debugGrantBelts(50);
      expect(e.quoteTalent('golpe_critico').failure, BuyFailure.locked);
      e.buyTalent('punos_acero');
      expect(e.quoteTalent('golpe_critico').canBuy, isTrue);
    });

    test('cost per level comes from the data and belts are spent', () {
      final e = withBelts(10);
      e.buyTalent('punos_acero'); // 1
      e.buyTalent('punos_acero'); // 2
      expect(e.state.belts.toDouble(), 7);
      expect(e.state.talentLevel('punos_acero'), 2);
    });

    test('a talent maxes out', () {
      final e = withBelts(100);
      for (var i = 0; i < 5; i++) {
        e.buyTalent('punos_acero');
      }
      expect(e.quoteTalent('punos_acero').failure, BuyFailure.maxed);
    });

    test('tap damage and trainer damage multipliers apply', () {
      final e = withBelts(100, (f) => f['balance.json']!['start'] = {'coins': 1e6, 'fightNumber': 1});
      e.buyTalent('punos_acero');
      e.buyTalent('punos_acero'); // +20%
      expect(e.tapDamage.toDouble(), closeTo(1.2, 1e-9));
      e.buyTrainer('don_chuy', x1);
      e.buyTalent('entrenamiento'); // +10%
      expect(e.damagePerSecond.toDouble(), closeTo(1.1, 1e-9));
    });

    test('coin gain multiplier raises rewards', () {
      final e = withBelts(10);
      e.buyTalent('cartera'); // +5%
      expect(e.currentReward.toDouble(), closeTo(1.5 * 1.05, 1e-9));
    });
  });

  group('masks', () {
    test('the starter mask is owned and equipped from the start', () {
      final e = GameEngine(content: loadTestContent());
      expect(e.ownsMask('jaguar_dorado'), isTrue);
      expect(e.state.equippedMask, 'jaguar_dorado');
      expect(e.ownsMask('la_calaverita'), isFalse);
    });

    test('an equipped mask adds its bonus', () {
      final e = GameEngine(content: loadTestContent());
      expect(e.tapDamage.toDouble(), closeTo(1.15, 1e-9)); // Jaguar Dorado +15%
    });

    test('belts-rule masks are bought with belts and then equipped', () {
      final e = newEngine();
      expect(e.quoteMask('la_calaverita').failure, BuyFailure.notEnoughBelts);
      expect(e.equipMask('la_calaverita'), isFalse);
      e.debugGrantBelts(5);
      expect(e.buyMask('la_calaverita').canBuy, isTrue);
      expect(e.state.belts.toDouble(), 2);
      expect(e.quoteMask('la_calaverita').failure, BuyFailure.alreadyOwned);
      expect(e.equipMask('la_calaverita'), isTrue);
    });

    test('La Calaverita raises boss coins', () {
      final e = newEngine();
      e.debugGoToBoss();
      final base = e.currentReward.toDouble();
      e.debugGrantBelts(5);
      e.buyMask('la_calaverita');
      e.equipMask('la_calaverita');
      expect(e.currentReward.toDouble(), closeTo(base * 1.5, 1e-6)); // +50% boss coins
    });

    test('a league mask unlocks when that league boss falls', () {
      final e = newEngine((f) {
        f['masks.json']!['masks'][1]['unlock'] = {'rule': 'league', 'value': 1};
        f['balance.json']!['tap'] = {'baseDamage': 1e9};
      });
      expect(e.ownsMask('la_calaverita'), isFalse);
      e.debugGoToBoss();
      e.startBoss();
      e.tap();
      expect(e.state.fightNumber, 11);
      expect(e.ownsMask('la_calaverita'), isTrue);
    });

    test('shop masks are granted, not bought', () {
      final e = newEngine((f) => f['masks.json']!['masks'][1]['unlock'] = {'rule': 'shop'});
      expect(e.quoteMask('la_calaverita').failure, BuyFailure.notPurchasable);
      e.grantMask('la_calaverita');
      expect(e.ownsMask('la_calaverita'), isTrue);
    });
  });

  group('achievements', () {
    test('first defeat pays belts once', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 1e9});
      e.tap();
      expect(e.state.achievements, contains('primera_victoria'));
      expect(e.state.belts.toDouble(), 1);
      expect(e.state.lifetimeBelts.toDouble(), 1);
      e.tap();
      e.tap();
      expect(e.state.achievements, isNot(contains('cien_golpes'))); // only 3 taps
      expect(e.state.belts.toDouble(), 1); // not paid twice
    });

    test('tap counters pay their reward at the target', () {
      final e = newEngine((f) => f['balance.json']!['tap'] = {'baseDamage': 0.0001});
      for (var i = 0; i < 100; i++) {
        e.tap();
      }
      expect(e.state.stat('taps'), 100);
      expect(e.state.achievements, contains('cien_golpes'));
    });
  });

  group('prestige', () {
    GameEngine progressed() {
      final e = newEngine();
      e.debugAddCoins(Big.fromDouble(1e6));
      e.buyUpgrade('puno_duro', const BuyAmount.fixed(5));
      e.buyTrainer('don_chuy', x1);
      e.debugSkipFights(5);
      e.debugAddCoins(Big.fromDouble(4e6)); // 5e6 earned in total -> 2 belts
      return e;
    }

    test('is not allowed until the run is worth a belt', () {
      final e = newEngine();
      expect(e.prestigePreview().canPrestige, isFalse);
      expect(e.prestige(), isFalse);
      expect(e.state.fightNumber, 1);
    });

    test('preview shows the belts to earn: floor(sqrt(C / 1e6))', () {
      final e = progressed();
      expect(e.prestigePreview().beltsToEarn.toDouble(), 2);
      expect(e.prestigePreview().canPrestige, isTrue);
    });

    test('resets the run and keeps the permanent things', () {
      final e = progressed();
      e.debugGrantBelts(10);
      e.buyTalent('punos_acero');
      e.grantMask('la_calaverita');
      e.equipMask('la_calaverita');
      e.debugSkipFights(2);
      e.buySkill('plancha');
      expect(e.prestige(), isTrue);
      final s = e.state;
      expect(s.fightNumber, 1);
      expect(s.coins, Big.zero);
      expect(s.totalCoinsEarned, Big.zero);
      expect(s.upgradeLevels, isEmpty);
      expect(s.trainerLevels, isEmpty);
      expect(s.comboMeter, 0);
      expect(s.skillCooldowns, isEmpty);
      // Kept:
      expect(s.talentLevel('punos_acero'), 1);
      expect(s.ownedMasks, contains('la_calaverita'));
      expect(s.equippedMask, 'la_calaverita');
      expect(s.skillLevel('plancha'), 1);
      expect(s.bestFight, greaterThan(1));
      // Granted: 10 + 2 earned (and the "nueva cara" achievement), minus 1 spent.
      expect(s.stat('prestiges'), 1);
      expect(s.belts.toDouble(), 10 - 1 + 2 + 3);
      expect(s.achievements, contains('nueva_cara'));
    });

    test('each belt earned adds +2% to all damage, permanently', () {
      final e = progressed();
      final before = e.tapDamage.toDouble();
      e.prestige();
      // 2 belts from the formula + 3 from the "nueva cara" achievement = 5.
      expect(e.state.lifetimeBelts.toDouble(), 5);
      expect(e.beltMultiplier.toDouble(), closeTo(1.1, 1e-9));
      expect(e.tapDamage.toDouble(), closeTo(1 * 1.1, 1e-9));
      expect(before, greaterThan(e.tapDamage.toDouble())); // upgrades were reset
    });

    test('the Ahorrito talent gives starting coins after a prestige', () {
      final e = progressed();
      e.debugGrantBelts(20);
      e.buyTalent('buena_racha');
      e.buyTalent('ahorrito');
      e.buyTalent('ahorrito');
      e.prestige();
      expect(e.state.coins.toDouble(), 200);
    });
  });

  group('seeded randomness', () {
    test('the same seed gives the same sequence', () {
      final a = SeededRng(123);
      final b = SeededRng(123);
      expect([for (var i = 0; i < 5; i++) a.nextDouble()], [for (var i = 0; i < 5; i++) b.nextDouble()]);
    });

    test('values stay in [0, 1)', () {
      final r = SeededRng(7);
      for (var i = 0; i < 10000; i++) {
        final v = r.nextDouble();
        expect(v >= 0 && v < 1, isTrue);
      }
    });

    test('restoring the saved state continues the same sequence', () {
      final a = SeededRng(99)..nextDouble()..nextDouble();
      final restored = SeededRng(a.state);
      expect(restored.nextDouble(), a.nextDouble());
    });
  });

  group('store purchases, boosts and ad offers', () {
    test('Doble moneda doubles every reward, forever', () {
      final e = newEngine();
      final base = e.currentReward.toDouble();
      e.grantPurchase('doble_moneda');
      expect(e.currentReward.toDouble(), closeTo(base * 2, 1e-9));
      expect(e.ownsPurchase('doble_moneda'), isTrue);
    });

    test('an unknown purchase id is rejected', () {
      expect(() => newEngine().grantPurchase('nope'), throwsArgumentError);
    });

    test('belt packs add spendable belts but not the permanent damage bonus', () {
      final e = newEngine();
      e.grantBeltPack('belts_100');
      expect(e.state.belts.toDouble(), 100);
      expect(e.state.lifetimeBelts, Big.zero);
      expect(e.beltMultiplier, Big.one);
    });

    test('the 2-minute boost doubles coins and then ends', () {
      final e = newEngine();
      final base = e.currentReward.toDouble();
      expect(e.claimAdOffer('doble_2min', 0), isTrue);
      expect(e.currentReward.toDouble(), closeTo(base * 2, 1e-9));
      expect(e.state.boostLeft, 120);
      for (var i = 0; i < 1201; i++) {
        e.tick();
      }
      expect(e.state.boostLeft, 0);
      expect(e.currentReward.toDouble(), closeTo(base, 1e-9));
    });

    test('boost and Doble moneda stack', () {
      final e = newEngine();
      final base = e.currentReward.toDouble();
      e.grantPurchase('doble_moneda');
      e.claimAdOffer('doble_2min', 0);
      expect(e.currentReward.toDouble(), closeTo(base * 4, 1e-9));
    });

    test('a free belt for an ad, then a cooldown from the data file', () {
      final e = newEngine();
      expect(e.claimAdOffer('cinturon_gratis', 1000), isTrue);
      expect(e.state.belts.toDouble(), 1);
      expect(e.adOfferWait('cinturon_gratis', 1000), 1800); // 30 minutes
      expect(e.claimAdOffer('cinturon_gratis', 1000 + 60000), isFalse);
      expect(e.state.belts.toDouble(), 1);
      expect(e.adOfferWait('cinturon_gratis', 1000 + 900000), closeTo(900 - 0, 1e-6));
      expect(e.claimAdOffer('cinturon_gratis', 1000 + 1800000), isTrue);
      expect(e.state.belts.toDouble(), 2);
    });

    test('cooldowns come from shop.json', () {
      final e = newEngine((f) {
        final item = (f['shop.json']!['items'] as List).last as Map;
        item['cooldownSeconds'] = 5;
      });
      e.claimAdOffer('cinturon_gratis', 0);
      expect(e.adOfferWait('cinturon_gratis', 0), 5);
    });

    test('paid items are not ad offers', () {
      final e = newEngine();
      expect(e.claimAdOffer('belts_20', 0), isFalse);
      expect(e.claimAdOffer('mas_descanso', 0), isFalse);
      expect(e.state.belts, Big.zero);
    });

    test('Borrar datos starts a brand new game', () {
      final e = newEngine();
      e.debugAddCoins(Big.fromInt(500));
      e.debugSkipFights(5);
      e.grantPurchase('mas_descanso');
      e.resetAll();
      expect(e.state.fightNumber, 1);
      expect(e.state.coins, Big.zero);
      expect(e.state.purchases, isEmpty);
    });
  });
}
