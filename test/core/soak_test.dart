import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/buy_amount.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/number_format.dart';

import '../test_content.dart';

/// Simulated play with a simple bot: taps at a fixed rate and spends coins as
/// soon as anything is affordable. Proves the loop holds together over a long
/// session and gives a rough feel for pacing (tuning is a later milestone).
void main() {
  test('30 minutes of simulated play never breaks and always progresses', () {
    final content = loadTestContent();
    final engine = GameEngine(content: content);
    final ticksPerSecond = content.balance.ticksPerSecond;
    const tapsPerSecond = 5;
    const minutes = 30;
    final report = <String>[];
    var lastFight = engine.state.fightNumber;

    for (var tick = 1; tick <= minutes * 60 * ticksPerSecond; tick++) {
      if (tick % (ticksPerSecond ~/ tapsPerSecond) == 0) engine.tap();
      engine.tick();
      // The bot buys the cheapest affordable thing every tick.
      for (final u in content.upgrades) {
        engine.buyUpgrade(u.id, const BuyAmount.max());
      }
      for (final t in content.trainers) {
        engine.buyTrainer(t.id, const BuyAmount.max());
      }
      if (tick % (60 * ticksPerSecond * 5) == 0) {
        final s = engine.state;
        report.add('min ${tick ~/ (60 * ticksPerSecond)}: fight ${s.fightNumber}, '
            'coins ${formatBig(s.coins)}, tap ${formatBig(engine.tapDamage)}, '
            'dps ${formatBig(engine.damagePerSecond)}');
      }
      expect(engine.state.coins.mantissa.isNaN, isFalse);
      lastFight = engine.state.fightNumber;
    }

    // ignore: avoid_print
    print(report.join('\n'));
    expect(lastFight, greaterThan(content.balance.startFightNumber));
  });
}
