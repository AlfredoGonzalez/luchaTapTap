import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/game_state.dart';

import '../test_content.dart';

const x1 = BuyAmount.fixed(1);
const x10 = BuyAmount.fixed(10);
const max = BuyAmount.max();

/// An engine whose arithmetic is easy to follow: the starter mask's tap bonus
/// is swapped for one that does not affect regular fights.
GameEngine newEngine([void Function(Map<String, Map<String, dynamic>>)? edit]) =>
    GameEngine(content: loadTestContent((files) {
      files['masks.json']!['masks'][0]['bonus'] = {'type': 'bossCoinMultiplier', 'value': 0.5};
      edit?.call(files);
    }));

void main() {
  group('start', () {
    test('begins at fight 1 with full HP and no coins', () {
      final e = newEngine();
      expect(e.state.fightNumber, 1);
      expect(e.state.coins, Big.zero);
      expect(e.state.enemyHp.toDouble(), closeTo(10, 1e-9));
      expect(e.tapDamage.toDouble(), 1);
      expect(e.damagePerSecond, Big.zero);
      expect(e.opponent.id, 'mr_aguacate');
    });
  });

  group('tapping', () {
    test('a tap deals tap damage and shows it', () {
      final e = newEngine();
      final result = e.tap();
      expect(result.damageDealt.toDouble(), 1);
      expect(e.state.enemyHp.toDouble(), closeTo(9, 1e-9));
      expect(result.defeats, 0);
    });

    test('defeating an opponent pays coins and starts the next fight', () {
      final e = newEngine();
      DamageOutcome last = DamageOutcome.none;
      for (var i = 0; i < 10; i++) {
        last = e.tap();
      }
      expect(last.defeats, 1);
      expect(e.state.fightNumber, 2);
      expect(e.state.coins.toDouble(), closeTo(1.5, 1e-9));
      expect(e.state.totalCoinsEarned.toDouble(), closeTo(1.5, 1e-9));
      expect(e.state.enemyHp.toDouble(), closeTo(15.5, 1e-9));
      expect(e.opponent.id, 'el_tamal_mortal');
    });

    test('opponents rotate through the league', () {
      final e = newEngine();
      final ids = <String>[];
      for (var fight = 1; fight <= 4; fight++) {
        ids.add(e.content.opponentForFight(fight).id);
      }
      expect(ids, ['mr_aguacate', 'el_tamal_mortal', 'el_taquero_cosmico', 'mr_aguacate']);
    });

    test('tap overkill is not carried to the next opponent', () {
      final e = newEngine((f) {
        f['balance.json']!['tap'] = {'baseDamage': 1000};
      });
      final r = e.tap();
      expect(r.defeats, 1);
      expect(e.state.fightNumber, 2);
      expect(e.state.enemyHp.toDouble(), closeTo(15.5, 1e-9));
    });
  });

  group('upgrades', () {
    test('cannot buy without coins', () {
      final e = newEngine();
      final q = e.buyUpgrade('puno_duro', x1);
      expect(q.failure, BuyFailure.notEnoughCoins);
      expect(e.state.upgradeLevel('puno_duro'), 0);
      expect(e.state.coins, Big.zero);
    });

    test('unknown id fails cleanly', () {
      final e = newEngine();
      expect(e.buyUpgrade('nope', x1).failure, BuyFailure.unknownItem);
      expect(e.buyTrainer('nope', x1).failure, BuyFailure.unknownItem);
    });

    test('buying spends coins and raises tap damage', () {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});
      final q = e.buyUpgrade('puno_duro', x1);
      expect(q.canBuy, isTrue);
      expect(e.state.upgradeLevel('puno_duro'), 1);
      expect(e.state.coins.toDouble(), 990);
      expect(e.tapDamage.toDouble(), 2);
    });

    test('x10 buys ten levels at the summed cost', () {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});
      final quote = e.quoteUpgrade('puno_duro', x10);
      // 10 * (1.15^10 - 1) / 0.15 = 203.03... -> 204
      expect(quote.cost.toDouble(), 204);
      e.buyUpgrade('puno_duro', x10);
      expect(e.state.upgradeLevel('puno_duro'), 10);
      expect(e.state.coins.toDouble(), 796);
      expect(e.tapDamage.toDouble(), 11);
    });

    test('x10 fails when it cannot be afforded and changes nothing', () {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 100, 'fightNumber': 1});
      final q = e.buyUpgrade('puno_duro', x10);
      expect(q.failure, BuyFailure.notEnoughCoins);
      expect(e.state.upgradeLevel('puno_duro'), 0);
      expect(e.state.coins.toDouble(), 100);
    });

    test('MAX buys as many as affordable and leaves less than the next level', () {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 500, 'fightNumber': 1});
      final before = e.state.coins;
      final q = e.buyUpgrade('puno_duro', max);
      expect(q.canBuy, isTrue);
      expect(q.count, greaterThan(1));
      expect(e.state.upgradeLevel('puno_duro'), q.count);
      expect(e.state.coins, before - q.cost);
      final next = e.quoteUpgrade('puno_duro', x1);
      expect(next.cost > e.state.coins, isTrue, reason: 'one more level must not fit');
    });

    test('MAX with no coins quotes the next level price but cannot buy', () {
      final e = newEngine();
      final q = e.quoteUpgrade('puno_duro', max);
      expect(q.count, 1);
      expect(q.cost.toDouble(), 10);
      expect(q.failure, BuyFailure.notEnoughCoins);
    });

    test('cost rises with each level (1.15^k)', () {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1});
      final first = e.quoteUpgrade('puno_duro', x1).cost;
      e.buyUpgrade('puno_duro', x1);
      final second = e.quoteUpgrade('puno_duro', x1).cost;
      expect(first.toDouble(), 10);
      expect(second.toDouble(), 12); // 11.5 rounded up
    });
  });

  group('trainers and the tick', () {
    GameEngine rich() =>
        newEngine((f) => f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1});

    test('a hired trainer deals damage per second, on every tick', () {
      final e = rich();
      e.buyTrainer('don_chuy', x1);
      expect(e.damagePerSecond.toDouble(), 1);
      final before = e.state.enemyHp;
      e.tick();
      expect((before - e.state.enemyHp).toDouble(), closeTo(0.1, 1e-9));
    });

    test('ten ticks equal one second of damage', () {
      final e = rich();
      e.buyTrainer('don_chuy', x1);
      for (var i = 0; i < 10; i++) {
        e.tick();
      }
      expect(e.state.enemyHp.toDouble(), closeTo(9, 1e-9));
    });

    test('idle damage defeats opponents without any tap', () {
      final e = rich();
      e.buyTrainer('don_chuy', x1);
      // 10 HP at 1 dps is 10 seconds = 100 ticks (101 at most: 0.1 per tick
      // is not exact in binary).
      var ticks = 0;
      while (e.state.fightNumber == 1 && ticks < 200) {
        e.tick();
        ticks++;
      }
      expect(ticks, inInclusiveRange(100, 101));
      expect(e.state.fightNumber, 2);
      expect(e.state.coins.toDouble(), greaterThan(900));
    });

    test('no trainers means the tick does nothing', () {
      final e = newEngine();
      final r = e.tick();
      expect(r.defeats, 0);
      expect(e.state.enemyHp.toDouble(), closeTo(10, 1e-9));
    });

    test('a strong idle build defeats several opponents in one tick', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1e12, 'fightNumber': 1};
        f['trainers.json']!['trainers'][0]['baseDps'] = 100000;
      });
      e.buyTrainer('don_chuy', x1);
      final r = e.tick();
      expect(r.defeats, greaterThan(1));
      expect(e.state.fightNumber, 1 + r.defeats);
    });

    test('defeats per tick are capped by balance.json', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1e12, 'fightNumber': 1};
        f['balance.json']!['tick']['maxFightsPerTick'] = 3;
        f['trainers.json']!['trainers'][0]['baseDps'] = 1e12;
      });
      e.buyTrainer('don_chuy', x1);
      expect(e.tick().defeats, 3);
      expect(e.state.fightNumber, 4);
    });

    test('trainer locked until its unlock fight', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        f['trainers.json']!['trainers'][0]['unlockFight'] = 5;
      });
      expect(e.quoteTrainer('don_chuy', x1).failure, BuyFailure.locked);
      expect(e.buyTrainer('don_chuy', x1).failure, BuyFailure.locked);
      expect(e.state.trainerLevel('don_chuy'), 0);
      expect(e.state.coins.toDouble(), 1000);
    });
  });

  group('data drives the game (no code change)', () {
    test('changing hpBase in balance.json changes opponent HP', () {
      final e = newEngine((f) => f['balance.json']!['economy']['hpBase'] = 40);
      expect(e.state.enemyHp.toDouble(), closeTo(40, 1e-9));
    });

    test('changing an upgrade base cost changes its price', () {
      final e = newEngine((f) => f['upgrades.json']!['upgrades'][0]['baseCost'] = 99);
      expect(e.quoteUpgrade('puno_duro', x1).cost.toDouble(), 99);
    });

    test('changing the trainer dps changes idle damage', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        f['trainers.json']!['trainers'][0]['baseDps'] = 7;
      });
      e.buyTrainer('don_chuy', x1);
      expect(e.damagePerSecond.toDouble(), 7);
    });

    test('changing the tick rate changes damage per tick', () {
      final e = newEngine((f) {
        f['balance.json']!['start'] = {'coins': 1000, 'fightNumber': 1};
        f['balance.json']!['tick']['ticksPerSecond'] = 20;
      });
      e.buyTrainer('don_chuy', x1);
      final before = e.state.enemyHp;
      e.tick();
      expect((before - e.state.enemyHp).toDouble(), closeTo(0.05, 1e-9));
    });
  });

  test('same inputs give the same state (deterministic)', () {
    GameState run() {
      final e = newEngine((f) => f['balance.json']!['start'] = {'coins': 5000, 'fightNumber': 1});
      e.buyTrainer('don_chuy', x10);
      e.buyUpgrade('puno_duro', max);
      for (var i = 0; i < 500; i++) {
        if (i % 3 == 0) e.tap();
        e.tick();
      }
      return e.state;
    }

    final a = run();
    final b = run();
    expect(a.coins, b.coins);
    expect(a.fightNumber, b.fightNumber);
    expect(a.enemyHp, b.enemyHp);
    expect(a.trainerLevels, b.trainerLevels);
  });

  test('long idle run progresses far without overflow', () {
    final e = newEngine((f) {
      f['balance.json']!['start'] = {'coins': 1e30, 'fightNumber': 1};
      f['balance.json']!['tick']['maxFightsPerTick'] = 1000000;
    });
    e.buyTrainer('don_chuy', max);
    e.buyUpgrade('puno_duro', max);
    for (var i = 0; i < 20000; i++) {
      e.tick();
    }
    expect(e.state.fightNumber, greaterThan(1));
    expect(e.state.coins.isZero, isFalse);
  });
}


