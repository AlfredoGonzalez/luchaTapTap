import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/number_format.dart';
import 'package:lucha_tap_tap/core/rng.dart';
import 'package:lucha_tap_tap/core/save_codec.dart';

import '../test_content.dart';

/// Simulated play with a bot that uses every system. Proves the whole game
/// holds together over hours of play and gives a rough feel for pacing
/// (tuning is the balance milestone).
void main() {
  final content = loadTestContent();
  final codec = SaveCodec(content: content);

  void expectInvariants(GameEngine e) {
    final s = e.state;
    expect(s.fightNumber, greaterThanOrEqualTo(1));
    expect(s.enemyHp <= e.enemyMaxHp, isTrue, reason: 'HP above max');
    expect(s.enemyHp > Big.zero || e.enemyMaxHp.isZero, isTrue);
    expect(s.coins >= Big.zero, isTrue);
    expect(s.comboMeter, inInclusiveRange(0, 1));
    expect(s.lifetimeBelts >= s.belts || s.belts >= Big.zero, isTrue);
    if (!e.isBossFight) expect(s.bossTimeLeft, isNull);
    expect(s.ownedMasks, contains(s.equippedMask));
  }

  test('three hours of bot play with every system never breaks', () {
    final engine = GameEngine(content: content, rng: SeededRng(2026));
    final tps = content.balance.ticksPerSecond;
    final botRng = SeededRng(77);
    final report = <String>[];
    var prestiges = 0;
    var bossesBeaten = 0;
    var saves = 0;

    for (var tick = 1; tick <= 3 * 3600 * tps; tick++) {
      // About 4 taps per second, a finisher whenever it is ready.
      if (tick % 3 == 0) engine.tap();
      if (engine.awaitingBossStart) engine.startBoss();
      engine.finisher();
      final out = engine.tick();
      if (out.defeats > 0 && engine.state.stat('bosses') > bossesBeaten) {
        bossesBeaten = engine.state.stat('bosses');
      }
      if (engine.state.lucky != null && botRng.nextDouble() < 0.5) engine.collectLucky();

      // Every second: shop, skills, talents, masks.
      if (tick % tps == 0) {
        for (final skill in content.skills) {
          engine.buySkill(skill.id);
          engine.useSkill(skill.id);
        }
        for (final u in content.upgrades) {
          engine.buyUpgrade(u.id, const BuyAmount.max());
        }
        for (final t in content.trainers) {
          engine.buyTrainer(t.id, const BuyAmount.max());
        }
        for (final t in content.talents) {
          engine.buyTalent(t.id);
        }
        for (final m in content.masks) {
          if (engine.buyMask(m.id).canBuy) engine.equipMask(m.id);
        }
      }

      // Every 10 minutes: save and reload through the codec, and sometimes
      // prestige or close the app for a while.
      if (tick % (600 * tps) == 0) {
        expectInvariants(engine);
        final data = SaveData(
          saveVersion: 1,
          lastSeen: DateTime.utc(2026),
          rngState: engine.rng.state,
          state: engine.state,
        );
        final back = codec.decode(codec.encode(data));
        expect(back.state.coins, engine.state.coins);
        expect(back.state.fightNumber, engine.state.fightNumber);
        saves++;

        if (engine.prestige()) prestiges++;
        engine.applyOffline(Duration(minutes: 30 + botRng.nextDouble().floor()));
        engine.collectOffline();
        report.add('min ${tick ~/ (60 * tps)}: fight ${engine.state.fightNumber}, '
            'best ${engine.state.bestFight}, coins ${formatBig(engine.state.coins)}, '
            'belts ${formatBig(engine.state.belts)}, prestiges $prestiges');
      }
    }

    expectInvariants(engine);
    // ignore: avoid_print
    print(report.join('\n'));
    expect(saves, 18);
    expect(engine.state.bestFight, greaterThan(content.balance.startFightNumber));
    expect(engine.state.stat('taps'), greaterThan(0));
  });

  test('a player who never taps still progresses with trainers only', () {
    final engine = GameEngine(
      content: loadTestContent((f) => f['balance.json']!['start'] = {'coins': 1e6, 'fightNumber': 1}),
    );
    engine.buyTrainer('don_chuy', const BuyAmount.max());
    for (var i = 0; i < 10 * 60 * content.balance.ticksPerSecond; i++) {
      engine.tick();
    }
    expect(engine.state.fightNumber, greaterThan(1));
    expectInvariants(engine);
  });
}
