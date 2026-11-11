import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/game_state.dart';
import 'package:lucha_tap_tap/core/save_codec.dart';

import '../test_content.dart';

final content = loadTestContent();
final codec = SaveCodec(content: content);
final savedAt = DateTime.utc(2026, 11, 11, 18, 30, 5);

/// A game with something in every part of the state.
GameEngine richGame() {
  final e = GameEngine(
    content: loadTestContent((f) => f['balance.json']!['start'] = {'coins': 1e12, 'fightNumber': 1}),
  );
  e.buyUpgrade('puno_duro', const BuyAmount.fixed(7));
  e.buyTrainer('don_chuy', const BuyAmount.fixed(3));
  e.debugSkipFights(9);
  e.buySkill('plancha');
  e.useSkill('plancha');
  e.buySkill('furia');
  e.useSkill('furia');
  e.debugGrantBelts(20);
  e.buyTalent('punos_acero');
  e.buyMask('la_calaverita');
  e.equipMask('la_calaverita');
  e.grantPurchase('mas_descanso');
  for (var i = 0; i < 6; i++) {
    e.tap();
  }
  e.grantPurchase('doble_moneda');
  e.claimAdOffer('doble_2min', 5000);
  e.debugGoToBoss();
  e.startBoss();
  e.tick();
  return e;
}

void expectSameState(GameState a, GameState b) {
  expect(b.coins, a.coins);
  expect(b.totalCoinsEarned, a.totalCoinsEarned);
  expect(b.fightNumber, a.fightNumber);
  expect(b.enemyHp, a.enemyHp);
  expect(b.upgradeLevels, a.upgradeLevels);
  expect(b.trainerLevels, a.trainerLevels);
  expect(b.belts, a.belts);
  expect(b.lifetimeBelts, a.lifetimeBelts);
  expect(b.comboMeter, a.comboMeter);
  expect(b.secondsSinceTap, a.secondsSinceTap);
  expect(b.bossTimeLeft, a.bossTimeLeft);
  expect(b.skillLevels, a.skillLevels);
  expect(b.skillCooldowns, a.skillCooldowns);
  expect(b.skillActive, a.skillActive);
  expect(b.talentLevels, a.talentLevels);
  expect(b.ownedMasks, a.ownedMasks);
  expect(b.equippedMask, a.equippedMask);
  expect(b.stats, a.stats);
  expect(b.achievements, a.achievements);
  expect(b.purchases, a.purchases);
  expect(b.bestFight, a.bestFight);
  expect(b.boostLeft, a.boostLeft);
  expect(b.boostMultiplier, a.boostMultiplier);
  expect(b.adReadyAt, a.adReadyAt);
  expect(b.lucky?.x, a.lucky?.x);
  expect(b.pendingOffline?.coinsEarned, a.pendingOffline?.coinsEarned);
}

String encodeOf(GameEngine e, {Map<String, dynamic> settings = const {}}) => codec.encode(SaveData(
      saveVersion: 1,
      lastSeen: savedAt,
      rngState: e.rng.state,
      state: e.state,
      settings: settings,
    ));

void main() {
  group('round trip', () {
    test('every part of the state survives', () {
      final e = richGame();
      expect(e.state.bossTimeLeft, isNotNull); // make sure the test covers it
      final data = codec.decode(encodeOf(e, settings: {'music': false}));
      expectSameState(e.state, data.state);
      expect(data.lastSeen, savedAt);
      expect(data.rngState, e.rng.state);
      expect(data.settings, {'music': false});
      expect(data.saveVersion, 1);
    });

    test('lucky pickups and pending offline earnings survive', () {
      final e = GameEngine(content: loadTestContent((f) {
        f['balance.json']!['lucky'] = {'spawnPerSecond': 1000, 'lifetimeSeconds': 5, 'rewardCoinMultiple': 8};
        f['balance.json']!['start'] = {'coins': 1e9, 'fightNumber': 1};
      }));
      e.buyTrainer('don_chuy', const BuyAmount.fixed(1));
      e.tick();
      e.applyOffline(const Duration(minutes: 30));
      expect(e.state.lucky, isNotNull);
      expect(e.state.pendingOffline, isNotNull);
      final data = codec.decode(encodeOf(e));
      expect(data.state.lucky!.x, e.state.lucky!.x);
      expect(data.state.lucky!.lifeLeft, e.state.lucky!.lifeLeft);
      expect(data.state.pendingOffline!.coinsEarned, e.state.pendingOffline!.coinsEarned);
      expect(data.state.pendingOffline!.defeats, e.state.pendingOffline!.defeats);
    });

    test('huge numbers beyond a double survive', () {
      final e = GameEngine(content: content);
      e.debugAddCoins(Big.powOf(10, 5000));
      final data = codec.decode(encodeOf(e));
      expect(data.state.coins, e.state.coins);
    });

    test('a restored game plays on exactly like the original', () {
      final a = richGame();
      final b = GameEngine(
        content: a.content,
        state: codec.decode(encodeOf(a)).state,
        rng: null,
      );
      for (var i = 0; i < 50; i++) {
        a.tick();
        b.tick();
      }
      expect(b.state.enemyHp, a.state.enemyHp);
      expect(b.state.bossTimeLeft, a.state.bossTimeLeft);
    });

    test('a restored random generator continues the same sequence', () {
      final e = richGame();
      final restored = codec.decode(encodeOf(e)).rngState;
      expect(restored, e.rng.state);
    });
  });

  group('forgiving reads', () {
    test('ids that no longer exist are dropped', () {
      final e = richGame();
      final map = jsonDecode(encodeOf(e)) as Map<String, dynamic>;
      final s = map['state'] as Map<String, dynamic>;
      (s['upgradeLevels'] as Map)['deleted_upgrade'] = 4;
      (s['skillLevels'] as Map)['deleted_skill'] = 1;
      (s['ownedMasks'] as List).add('deleted_mask');
      (s['achievements'] as List).add('deleted_achievement');
      s['equippedMask'] = 'deleted_mask';
      final data = codec.decode(jsonEncode(map));
      expect(data.state.upgradeLevels.keys, isNot(contains('deleted_upgrade')));
      expect(data.state.skillLevels.keys, isNot(contains('deleted_skill')));
      expect(data.state.ownedMasks, isNot(contains('deleted_mask')));
      expect(data.state.achievements, isNot(contains('deleted_achievement')));
      expect(data.state.equippedMask, isNull);
    });

    test('missing fields take their starting values', () {
      final data = codec.decode(jsonEncode({
        'saveVersion': 1,
        'lastSeen': savedAt.toIso8601String(),
        'state': {'fightNumber': 4},
      }));
      expect(data.state.fightNumber, 4);
      expect(data.state.coins, Big.zero);
      expect(data.state.upgradeLevels, isEmpty);
      expect(data.rngState, 1);
    });

    test('engine.repair fixes a state that does not fit the content', () {
      final data = codec.decode(jsonEncode({
        'saveVersion': 1,
        'lastSeen': savedAt.toIso8601String(),
        'state': {'fightNumber': 1, 'enemyHp': Big.powOf(10, 50).toJson(), 'equippedMask': 'la_calaverita'},
      }));
      final e = GameEngine(content: content, state: data.state)..repair();
      expect(e.state.enemyHp, e.enemyMaxHp);
      expect(e.ownsMask('jaguar_dorado'), isTrue); // starter masks are never lost
      expect(e.state.equippedMask, 'jaguar_dorado');
    });
  });

  group('unusable saves', () {
    void expectRejected(String text, String reason) {
      expect(
        () => codec.decode(text),
        throwsA(isA<SaveFormatException>().having((e) => e.message, 'message', contains(reason))),
      );
    }

    test('not JSON', () => expectRejected('{"saveVersion": 1', 'invalid save'));
    test('JSON but not an object', () => expectRejected('[1, 2]', 'JSON object'));
    test('no version', () => expectRejected('{"lastSeen": "2026-01-01T00:00:00Z"}', 'saveVersion'));
    test('newer than this build', () => expectRejected('{"saveVersion": 9, "lastSeen": "2026-01-01T00:00:00Z"}', 'newer'));
    test('no lastSeen', () => expectRejected('{"saveVersion": 1}', 'lastSeen'));
    test('wrong types', () {
      expectRejected(
          jsonEncode({'saveVersion': 1, 'lastSeen': '2026-01-01T00:00:00Z', 'state': {'coins': 5}}),
          'invalid save');
    });
    test('fight number below 1', () {
      expectRejected(
          jsonEncode({'saveVersion': 1, 'lastSeen': '2026-01-01T00:00:00Z', 'state': {'fightNumber': 0}}),
          'fightNumber');
    });
  });

  group('migrations', () {
    // Pretend the format moved to version 3: v1 stored "gold", v2 renamed it
    // to "coins", v3 is current.
    SaveCodec codecV3() => SaveCodec(
          content: content,
          currentVersion: 3,
          migrations: {
            1: (json) {
              final state = Map<String, dynamic>.from(json['state'] as Map);
              state['coins'] = state.remove('gold');
              return {...json, 'state': state};
            },
            2: (json) => {...json, 'settings': {'migrated': true}},
          },
        );

    test('an old save is upgraded step by step', () {
      final old = jsonEncode({
        'saveVersion': 1,
        'lastSeen': savedAt.toIso8601String(),
        'state': {'gold': Big.fromInt(777).toJson(), 'fightNumber': 3},
      });
      final data = codecV3().decode(old);
      expect(data.state.coins, Big.fromInt(777));
      expect(data.settings, {'migrated': true});
      expect(data.saveVersion, 3);
    });

    test('a save at the current version is untouched', () {
      final c = codecV3();
      final text = c.encode(SaveData(
        saveVersion: 3,
        lastSeen: savedAt,
        rngState: 5,
        state: GameEngine(content: content).state,
      ));
      expect(c.decode(text).settings, isEmpty);
    });

    test('a missing migration is an error, not silent data loss', () {
      final c = SaveCodec(content: content, currentVersion: 2);
      expect(
        () => c.decode(jsonEncode({'saveVersion': 1, 'lastSeen': savedAt.toIso8601String()})),
        throwsA(isA<SaveFormatException>()),
      );
    });
  });
}
