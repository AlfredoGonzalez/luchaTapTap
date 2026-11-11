import 'json_reader.dart';

/// Every global game constant, read from `assets/data/balance.json`.
///
/// Rule: no balance number lives in Dart. If a system needs a number, it is
/// added to the JSON and read through this class.
class Balance {
  const Balance({
    required this.ticksPerSecond,
    required this.maxFightsPerTick,
    required this.maxCatchUpTicks,
    required this.baseTapDamage,
    required this.hpBase,
    required this.hpGrowth,
    required this.bossHpMultiplier,
    required this.coinsPerHpFraction,
    required this.bossCoinMultiplier,
    required this.costGrowth,
    required this.beltCoinDivisor,
    required this.buyFixedAmounts,
    required this.maxBulkLevels,
    required this.startCoins,
    required this.startFightNumber,
    required this.fx,
  });

  static const int schemaVersion = 1;

  factory Balance.fromJson(Map<String, dynamic> json) {
    final r = JsonReader('balance.json', json)..expectSchemaVersion(schemaVersion);
    final tick = r.object('tick');
    final tap = r.object('tap');
    final economy = r.object('economy');
    final buy = r.object('buy');
    final start = r.object('start');
    return Balance(
      ticksPerSecond: tick.integer('ticksPerSecond', min: 1),
      maxFightsPerTick: tick.integer('maxFightsPerTick', min: 1),
      maxCatchUpTicks: tick.integer('maxCatchUpTicks', min: 1),
      baseTapDamage: tap.number('baseDamage', min: 0, minExclusive: true),
      hpBase: economy.number('hpBase', min: 0, minExclusive: true),
      hpGrowth: economy.number('hpGrowth', min: 1),
      bossHpMultiplier: economy.number('bossHpMultiplier', min: 0, minExclusive: true),
      coinsPerHpFraction: economy.number('coinsPerHpFraction', min: 0, minExclusive: true),
      bossCoinMultiplier: economy.number('bossCoinMultiplier', min: 0, minExclusive: true),
      costGrowth: economy.number('costGrowth', min: 1, minExclusive: true),
      beltCoinDivisor: economy.number('beltCoinDivisor', min: 0, minExclusive: true),
      buyFixedAmounts: buy.integers('fixedAmounts', min: 1),
      maxBulkLevels: buy.integer('maxBulkLevels', min: 1),
      startCoins: start.number('coins', min: 0),
      startFightNumber: start.integer('fightNumber', min: 1),
      fx: FxConfig.fromReader(r.object('fx')),
    );
  }

  /// Fixed simulation steps per second.
  final int ticksPerSecond;

  /// Safety cap on opponents defeated in one tick.
  final int maxFightsPerTick;

  /// Most ticks run at once after a stall (frame hitch, app resume).
  final int maxCatchUpTicks;

  final double baseTapDamage;

  /// HP of fight 1; HP(n) = hpBase * hpGrowth^(n-1).
  final double hpBase;
  final double hpGrowth;
  final double bossHpMultiplier;

  /// Coins(n) = coinsPerHpFraction * HP(n).
  final double coinsPerHpFraction;
  final double bossCoinMultiplier;

  /// Cost(k) = base * costGrowth^k.
  final double costGrowth;

  /// Belts = floor(sqrt(totalCoins / beltCoinDivisor)).
  final double beltCoinDivisor;

  /// Quantities of the buy selector, in addition to MAX (for example 1, 10, 100).
  final List<int> buyFixedAmounts;

  /// Upper bound for a MAX purchase in one action.
  final int maxBulkLevels;

  final double startCoins;
  final int startFightNumber;

  final FxConfig fx;
}

/// Visual effect timings. Not game balance, but tunable without code changes.
class FxConfig {
  const FxConfig({
    required this.idleFps,
    required this.hitFlashSeconds,
    required this.damageNumberRisePx,
    required this.damageNumberSeconds,
    required this.damageNumberJitterPx,
  });

  factory FxConfig.fromReader(JsonReader r) => FxConfig(
        idleFps: r.integer('idleFps', min: 1),
        hitFlashSeconds: r.number('hitFlashSeconds', min: 0),
        damageNumberRisePx: r.integer('damageNumberRisePx', min: 0),
        damageNumberSeconds: r.number('damageNumberSeconds', min: 0, minExclusive: true),
        damageNumberJitterPx: r.integer('damageNumberJitterPx', min: 0),
      );

  final int idleFps;
  final double hitFlashSeconds;
  final int damageNumberRisePx;
  final double damageNumberSeconds;
  final int damageNumberJitterPx;
}
