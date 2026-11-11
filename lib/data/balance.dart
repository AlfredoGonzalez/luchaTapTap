import 'content_exception.dart';
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
    required this.combo,
    required this.bossTimerSeconds,
    required this.crit,
    required this.lucky,
    required this.prestige,
    required this.skillCooldownReductionCap,
    required this.offline,
    required this.saveIntervalSeconds,
    required this.debug,
    required this.ui,
  });

  static const int schemaVersion = 1;

  factory Balance.fromJson(Map<String, dynamic> json) {
    final r = JsonReader('balance.json', json)
      ..expectSchemaVersion(schemaVersion);
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
      bossHpMultiplier: economy.number(
        'bossHpMultiplier',
        min: 0,
        minExclusive: true,
      ),
      coinsPerHpFraction: economy.number(
        'coinsPerHpFraction',
        min: 0,
        minExclusive: true,
      ),
      bossCoinMultiplier: economy.number(
        'bossCoinMultiplier',
        min: 0,
        minExclusive: true,
      ),
      costGrowth: economy.number('costGrowth', min: 1, minExclusive: true),
      beltCoinDivisor: economy.number(
        'beltCoinDivisor',
        min: 0,
        minExclusive: true,
      ),
      buyFixedAmounts: buy.integers('fixedAmounts', min: 1),
      maxBulkLevels: buy.integer('maxBulkLevels', min: 1),
      startCoins: start.number('coins', min: 0),
      startFightNumber: start.integer('fightNumber', min: 1),
      fx: FxConfig.fromReader(r.object('fx')),
      combo: ComboConfig.fromReader(r.object('combo')),
      bossTimerSeconds: r
          .object('boss')
          .number('timerSeconds', min: 0, minExclusive: true),
      crit: CritConfig.fromReader(r.object('crit')),
      lucky: LuckyConfig.fromReader(r.object('lucky')),
      prestige: PrestigeConfig.fromReader(r.object('prestige')),
      skillCooldownReductionCap: r
          .object('skills')
          .number('cooldownReductionCap', min: 0),
      offline: OfflineConfig.fromReader(r.object('offline')),
      saveIntervalSeconds: r
          .object('save')
          .number('intervalSeconds', min: 0, minExclusive: true),
      debug: DebugConfig.fromReader(r.object('debug')),
      ui: UiConfig.fromReader(r.object('ui')),
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
  final ComboConfig combo;

  /// Default boss countdown (an opponent may override it).
  final double bossTimerSeconds;
  final CritConfig crit;
  final LuckyConfig lucky;
  final PrestigeConfig prestige;

  /// Skill cooldowns can never be reduced by more than this fraction.
  final double skillCooldownReductionCap;
  final OfflineConfig offline;

  /// Seconds between automatic saves while playing.
  final double saveIntervalSeconds;
  final DebugConfig debug;
  final UiConfig ui;
}

class ComboConfig {
  const ComboConfig({
    required this.fillPerTap,
    required this.holdSeconds,
    required this.decayPerSecond,
    required this.finisherMultiplier,
  });

  factory ComboConfig.fromReader(JsonReader r) => ComboConfig(
    fillPerTap: r.number('fillPerTap', min: 0, minExclusive: true),
    holdSeconds: r.number('holdSeconds', min: 0),
    decayPerSecond: r.number('decayPerSecond', min: 0),
    finisherMultiplier: r.number('finisherMultiplier', min: 1),
  );

  /// Meter (0 to 1) gained per tap.
  final double fillPerTap;

  /// Seconds after the last tap before the meter starts to decay.
  final double holdSeconds;
  final double decayPerSecond;

  /// Finisher damage as a multiple of tap damage.
  final double finisherMultiplier;
}

class CritConfig {
  const CritConfig({required this.multiplier, required this.maxChance});

  factory CritConfig.fromReader(JsonReader r) => CritConfig(
    multiplier: r.number('multiplier', min: 1),
    maxChance: r.number('maxChance', min: 0),
  );

  final double multiplier;
  final double maxChance;
}

class LuckyConfig {
  const LuckyConfig({
    required this.spawnPerSecond,
    required this.lifetimeSeconds,
    required this.rewardCoinMultiple,
  });

  factory LuckyConfig.fromReader(JsonReader r) => LuckyConfig(
    spawnPerSecond: r.number('spawnPerSecond', min: 0),
    lifetimeSeconds: r.number('lifetimeSeconds', min: 0, minExclusive: true),
    rewardCoinMultiple: r.number('rewardCoinMultiple', min: 0),
  );

  /// Chance per second that a pickup appears (while none is on screen).
  final double spawnPerSecond;
  final double lifetimeSeconds;

  /// Reward as a multiple of the coins paid by the current fight.
  final double rewardCoinMultiple;
}

class PrestigeConfig {
  const PrestigeConfig({required this.minBelts, required this.beltDamageBonus});

  factory PrestigeConfig.fromReader(JsonReader r) => PrestigeConfig(
    minBelts: r.integer('minBelts', min: 1),
    beltDamageBonus: r.number('beltDamageBonus', min: 0),
  );

  /// Belts the run must be worth before Change Mask is allowed.
  final int minBelts;

  /// Damage bonus per Belt earned (0.02 is +2%).
  final double beltDamageBonus;
}

class OfflineConfig {
  const OfflineConfig({
    required this.baseCapHours,
    required this.maxCapHours,
    required this.minPopupSeconds,
    required this.adMultiplier,
    required this.purchaseCapHours,
  });

  factory OfflineConfig.fromReader(JsonReader r) {
    final base = r.number('baseCapHours', min: 0, minExclusive: true);
    final max = r.number('maxCapHours', min: 0, minExclusive: true);
    if (max < base) {
      throw ContentException(
        'balance.json: offline.maxCapHours must be at least baseCapHours',
      );
    }
    return OfflineConfig(
      baseCapHours: base,
      maxCapHours: max,
      minPopupSeconds: r.number('minPopupSeconds', min: 0),
      adMultiplier: r.number('adMultiplier', min: 1),
      purchaseCapHours: r.numberMap('purchaseCapHours'),
    );
  }

  /// The offline cap is `baseCapHours` plus bonuses (Siesta talent, masks,
  /// purchases), never more than `maxCapHours`.
  final double baseCapHours;
  final double maxCapHours;

  /// Away time below this is collected silently, with no pop-up.
  final double minPopupSeconds;

  /// Factor applied to the offline coins when the rewarded ad is watched.
  final double adMultiplier;

  /// Purchase id to extra cap hours.
  final Map<String, double> purchaseCapHours;
}

class DebugConfig {
  const DebugConfig({
    required this.coinAmounts,
    required this.fastForwardMinutes,
    required this.absenceHours,
  });

  factory DebugConfig.fromReader(JsonReader r) => DebugConfig(
    coinAmounts: r.numbers('coinAmounts', min: 0),
    fastForwardMinutes: r.integers('fastForwardMinutes', min: 1),
    absenceHours: r.integers('absenceHours', min: 1),
  );

  final List<double> coinAmounts;
  final List<int> fastForwardMinutes;
  final List<int> absenceHours;
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
    damageNumberSeconds: r.number(
      'damageNumberSeconds',
      min: 0,
      minExclusive: true,
    ),
    damageNumberJitterPx: r.integer('damageNumberJitterPx', min: 0),
  );

  final int idleFps;
  final double hitFlashSeconds;
  final int damageNumberRisePx;
  final double damageNumberSeconds;
  final int damageNumberJitterPx;
}

/// Screen timings (splash, loading, flashes). Not balance, but tunable.
class UiConfig {
  const UiConfig({
    required this.splashSeconds,
    required this.loadingSeconds,
    required this.blinkSeconds,
    required this.purchaseFlashSeconds,
    required this.noticeSeconds,
  });

  factory UiConfig.fromReader(JsonReader r) => UiConfig(
    splashSeconds: r.number('splashSeconds', min: 0),
    loadingSeconds: r.number('loadingSeconds', min: 0),
    blinkSeconds: r.number('blinkSeconds', min: 0, minExclusive: true),
    purchaseFlashSeconds: r.number('purchaseFlashSeconds', min: 0),
    noticeSeconds: r.number('noticeSeconds', min: 0, minExclusive: true),
  );

  /// How long the studio splash shows before the loading screen.
  final double splashSeconds;

  /// How long the loading bar takes to fill.
  final double loadingSeconds;

  /// Half period of the blinking "Toca para continuar".
  final double blinkSeconds;

  /// How long a purchased row flashes yellow.
  final double purchaseFlashSeconds;

  /// How long a short message over the arena stays.
  final double noticeSeconds;
}
