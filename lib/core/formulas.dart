import 'dart:math' as math;

import '../data/balance.dart';
import 'big.dart';

/// The economy formulas of the Technical Spec (section 5). Every constant is
/// read from [Balance]; nothing is hard-coded here.
class Formulas {
  const Formulas(this.balance);

  final Balance balance;

  /// HP(n) = hpBase * hpGrowth^(n-1), before boss and opponent multipliers.
  Big baseHp(int fight) {
    _checkFight(fight);
    return Big.powOf(balance.hpGrowth, fight - 1).mulDouble(balance.hpBase);
  }

  /// HP of the opponent in [fight]. Bosses multiply HP by `bossHpMultiplier`.
  Big opponentHp(int fight, {bool isBoss = false, double hpMultiplier = 1}) {
    var hp = baseHp(fight).mulDouble(hpMultiplier);
    if (isBoss) hp = hp.mulDouble(balance.bossHpMultiplier);
    return hp;
  }

  /// Coins(n) = coinsPerHpFraction * HP(n). Computed from the base HP of the
  /// fight (without the boss HP multiplier); bosses pay `bossCoinMultiplier`
  /// times that.
  Big coinsReward(int fight, {bool isBoss = false, double coinMultiplier = 1}) {
    var coins = baseHp(fight)
        .mulDouble(balance.coinsPerHpFraction)
        .mulDouble(coinMultiplier);
    if (isBoss) coins = coins.mulDouble(balance.bossCoinMultiplier);
    return coins;
  }

  /// Cost(k) = base * costGrowth^k: cost of the next level when [owned]
  /// levels are already bought. Exact value, not rounded.
  Big levelCost(double baseCost, int owned) {
    _checkOwned(owned);
    return Big.powOf(balance.costGrowth, owned).mulDouble(baseCost);
  }

  /// Exact sum of the cost of [count] consecutive levels starting at [owned]:
  /// the geometric series `Cost(k) * (r^count - 1) / (r - 1)`.
  Big bulkCost(double baseCost, int owned, int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must not be negative');
    }
    if (count == 0) return Big.zero;
    final first = levelCost(baseCost, owned);
    if (count == 1) return first;
    final r = balance.costGrowth;
    final series = (Big.powOf(r, count) - Big.one).divDouble(r - 1);
    return first * series;
  }

  /// What the player actually pays: the exact cost rounded up to a whole coin,
  /// so the number on the button always matches what can be afforded.
  Big purchaseCost(double baseCost, int owned, int count) =>
      bulkCost(baseCost, owned, count).ceil();

  /// The most levels affordable with [coins] (the MAX button), capped by
  /// `maxBulkLevels`. Returns 0 when not even one level can be bought.
  int maxAffordable(Big coins, double baseCost, int owned) {
    if (coins < purchaseCost(baseCost, owned, 1)) return 0;
    final r = balance.costGrowth;
    final first = levelCost(baseCost, owned);
    // Solve first * (r^m - 1) / (r - 1) <= coins for m, then correct the
    // floating point estimate by checking the neighbors with exact costs.
    final ratio = coins.mulDouble(r - 1) / first + Big.one;
    final estimate = ratio.log10() / (math.log(r) / math.ln10);
    var m = math.max(1, math.min(estimate.floor(), balance.maxBulkLevels));
    while (m < balance.maxBulkLevels &&
        purchaseCost(baseCost, owned, m + 1) <= coins) {
      m++;
    }
    while (m > 1 && purchaseCost(baseCost, owned, m) > coins) {
      m--;
    }
    return m;
  }

  /// Belts = floor(sqrt(totalCoins / beltCoinDivisor)).
  Big belts(Big totalCoinsEarned) =>
      totalCoinsEarned.divDouble(balance.beltCoinDivisor).sqrt().floor();

  void _checkFight(int fight) {
    if (fight < 1) {
      throw ArgumentError.value(fight, 'fight', 'must be at least 1');
    }
  }

  void _checkOwned(int owned) {
    if (owned < 0) {
      throw ArgumentError.value(owned, 'owned', 'must not be negative');
    }
  }
}
