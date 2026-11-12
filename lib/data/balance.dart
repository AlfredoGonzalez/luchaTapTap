import '../core/big.dart';
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
    required this.gesture,
    required this.milestones,
    required this.animations,
    required this.monetization,
    required this.audio,
    required this.haptics,
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
      gesture: GestureConfig.fromReader(r.object('gesture')),
      animations: AnimationConfig.fromReader(r.object('animations')),
      monetization: MonetizationConfig.fromReader(r.object('monetization')),
      audio: r.has('audio')
          ? AudioConfig.fromReader(r.object('audio'))
          : const AudioConfig(master: 1, music: 1, sfx: 1),
      haptics: r.has('haptics')
          ? HapticsConfig.fromReader(r.object('haptics'))
          : const HapticsConfig({}),
      milestones: r.has('milestones')
          ? MilestoneConfig.fromReader(r.object('milestones'))
          : const MilestoneConfig(levels: [], multiplier: 1),
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
  final GestureConfig gesture;

  /// Level milestones of upgrades and trainers (the GDD's "milestone levels").
  final MilestoneConfig milestones;

  /// Ad and store settings.
  final MonetizationConfig monetization;

  /// Sprite sheet layout and clip speeds.
  final AnimationConfig animations;

  /// Volume levels (0 to 1) of the audio mix.
  final AudioConfig audio;

  /// Which vibration each event gives.
  final HapticsConfig haptics;
}

/// Settings of the rewarded ads and the store. The ad unit ids are data so the
/// release id can be set without touching code; non-release builds always use
/// the Google test unit.
class MonetizationConfig {
  const MonetizationConfig({
    required this.adLoadTimeoutSeconds,
    required this.restoreWaitSeconds,
    required this.purchaseWaitSeconds,
    required this.testRewardedUnitId,
    required this.rewardedUnitId,
  });

  factory MonetizationConfig.fromReader(JsonReader r) => MonetizationConfig(
    adLoadTimeoutSeconds: r.number('adLoadTimeoutSeconds', min: 0, minExclusive: true),
    restoreWaitSeconds: r.number('restoreWaitSeconds', min: 0, minExclusive: true),
    purchaseWaitSeconds: r.number('purchaseWaitSeconds', min: 0, minExclusive: true),
    testRewardedUnitId: r.string('testRewardedUnitId'),
    rewardedUnitId: r.optionalString('rewardedUnitId'),
  );

  /// Give up on an ad that has not loaded after this long.
  final double adLoadTimeoutSeconds;

  /// How long "Restaurar compras" waits for the store to answer.
  final double restoreWaitSeconds;

  /// How long a purchase may stay open before the app stops waiting for it.
  final double purchaseWaitSeconds;

  /// Google's sample rewarded unit, used in every non-release build.
  final String testRewardedUnitId;

  /// Your own rewarded unit for release builds; null until it exists (ads are
  /// then simply unavailable in release).
  final String? rewardedUnitId;

  /// The unit to load: the test one outside release builds.
  String? unitFor({required bool release}) =>
      release ? rewardedUnitId : testRewardedUnitId;
}

/// One animation clip of a fighter sprite sheet.
class ClipConfig {
  const ClipConfig({
    required this.frames,
    required this.fps,
    required this.loop,
  });

  final int frames;
  final double fps;
  final bool loop;

  double get seconds => frames / fps;
}

/// Layout of the sprite sheets (one row per clip, in [order]) and how fast each
/// clip plays. Frame size is the sprite's size from the data.
class AnimationConfig {
  const AnimationConfig({
    required this.order,
    required this.clips,
    required this.victorySeconds,
    required this.defeatedHoldSeconds,
    required this.playerDownSeconds,
  });

  factory AnimationConfig.fromReader(JsonReader r) {
    final order = r.strings('order');
    final clipsReader = r.object('clips');
    final clips = <String, ClipConfig>{};
    for (final name in order) {
      final c = clipsReader.object(name);
      clips[name] = ClipConfig(
        frames: c.integer('frames', min: 1),
        fps: c.number('fps', min: 0, minExclusive: true),
        loop: c.boolean('loop'),
      );
    }
    for (final required in AnimationConfig.requiredClips) {
      if (!clips.containsKey(required)) {
        throw ContentException(
          'balance.json: animations.order must include "$required"',
        );
      }
    }
    return AnimationConfig(
      order: order,
      clips: clips,
      victorySeconds: r.number('victorySeconds', min: 0),
      defeatedHoldSeconds: r.number('defeatedHoldSeconds', min: 0),
      playerDownSeconds: r.number('playerDownSeconds', min: 0),
    );
  }

  /// Clips the arena plays; the sheet must have a row for each.
  static const List<String> requiredClips = [
    'idle',
    'attack',
    'hit',
    'defeated',
    'victory',
  ];

  /// Clip names from the top row of a sheet down.
  final List<String> order;
  final Map<String, ClipConfig> clips;

  /// How long the player celebrates after a boss falls.
  final double victorySeconds;

  /// How long a defeated opponent stays on the floor before the next arrives.
  final double defeatedHoldSeconds;

  /// How long the player stays on the floor after the boss timer runs out.
  final double playerDownSeconds;

  int rowOf(String clip) => order.indexOf(clip);

  /// Frames of the longest clip: the number of columns of a sheet.
  int get columns =>
      clips.values.map((c) => c.frames).reduce((a, b) => a > b ? a : b);
}

/// Volume mix. The player's own switches in Ajustes turn music and effects on
/// or off; these set how loud each group is when on.
class AudioConfig {
  const AudioConfig({
    required this.master,
    required this.music,
    required this.sfx,
  });

  factory AudioConfig.fromReader(JsonReader r) => AudioConfig(
    master: r.number('master', min: 0),
    music: r.number('music', min: 0),
    sfx: r.number('sfx', min: 0),
  );

  final double master;
  final double music;
  final double sfx;
}

/// Vibration strength per event: one of none, selection, light, medium, heavy.
class HapticsConfig {
  const HapticsConfig(this.byEvent);

  /// The events that can vibrate.
  static const List<String> events = [
    'tap',
    'crit',
    'finisher',
    'buy',
    'bossIntro',
    'victory',
  ];

  factory HapticsConfig.fromReader(JsonReader r) {
    final result = <String, HapticKind>{};
    for (final event in events) {
      if (!r.has(event)) continue;
      final name = r.string(event);
      final kind = HapticKind.values.where((k) => k.name == name).firstOrNull;
      if (kind == null) {
        throw ContentException(
          'balance.json: haptics.$event must be one of '
          '${HapticKind.values.map((k) => k.name).join(', ')}',
        );
      }
      result[event] = kind;
    }
    return HapticsConfig(result);
  }

  final Map<String, HapticKind> byEvent;

  HapticKind of(String event) => byEvent[event] ?? HapticKind.none;
}

enum HapticKind { none, selection, light, medium, heavy }

/// Every time an upgrade or trainer reaches one of [levels], its output is
/// multiplied by [multiplier]. This is what lets damage keep up with the
/// exponential growth of opponent HP.
class MilestoneConfig {
  const MilestoneConfig({required this.levels, required this.multiplier});

  factory MilestoneConfig.fromReader(JsonReader r) {
    final levels = r.integers('levels', min: 1);
    for (var i = 1; i < levels.length; i++) {
      if (levels[i] <= levels[i - 1]) {
        throw ContentException('balance.json: milestones.levels must be increasing');
      }
    }
    return MilestoneConfig(levels: levels, multiplier: r.number('multiplier', min: 1));
  }

  final List<int> levels;
  final double multiplier;

  /// How many milestones a unit at [level] has reached.
  int reached(int level) {
    var n = 0;
    for (final l in levels) {
      if (l <= level) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  /// The next milestone level above [level], or null after the last one.
  int? nextAfter(int level) {
    for (final l in levels) {
      if (l > level) return l;
    }
    return null;
  }

  /// Progress (0..1) from the previous milestone (or level 0) to the next
  /// one; 1 when there is none left.
  double progressAt(int level) {
    final next = nextAfter(level);
    if (next == null) return 1;
    final n = reached(level);
    final from = n == 0 ? 0 : levels[n - 1];
    return ((level - from) / (next - from)).clamp(0.0, 1.0);
  }

  /// Output factor of a unit at [level] (1 before the first milestone).
  Big factorAt(int level) {
    final n = reached(level);
    return n == 0 || multiplier == 1 ? Big.one : Big.powOf(multiplier, n);
  }
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
    required this.maxVirtualWidth,
    required this.maxVirtualHeight,
    required this.splashLogoMaxFraction,
    required this.loadingFrames,
    required this.loadingFps,
    required this.splashVideoLogoFraction,
  });

  factory UiConfig.fromReader(JsonReader r) => UiConfig(
    splashSeconds: r.number('splashSeconds', min: 0),
    loadingSeconds: r.number('loadingSeconds', min: 0),
    blinkSeconds: r.number('blinkSeconds', min: 0, minExclusive: true),
    purchaseFlashSeconds: r.number('purchaseFlashSeconds', min: 0),
    noticeSeconds: r.number('noticeSeconds', min: 0, minExclusive: true),
    maxVirtualWidth: r.integer('maxVirtualWidth', min: 180),
    maxVirtualHeight: r.integer('maxVirtualHeight', min: 320),
    splashLogoMaxFraction: r.number('splashLogoMaxFraction', min: 0, minExclusive: true),
    loadingFrames: r.integer('loadingFrames', min: 1),
    loadingFps: r.number('loadingFps', min: 0, minExclusive: true),
    splashVideoLogoFraction: r.number('splashVideoLogoFraction', min: 0, minExclusive: true),
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

  /// The game canvas grows with the window up to this many virtual pixels
  /// (the base design is 180 x 320); beyond that the leftover is a border.
  final int maxVirtualWidth;
  final int maxVirtualHeight;

  /// The studio logo in the splash video may fill at most this share of the
  /// screen width.
  final double splashLogoMaxFraction;

  /// The loading background is `assets/backgrounds/loading_<n>.png` for n in
  /// 0 until [loadingFrames], shown at [loadingFps] frames per second.
  final int loadingFrames;
  final double loadingFps;

  /// How much of the video's width the logo spans in its last frame
  /// (measured on the file; change it if the video is replaced).
  final double splashVideoLogoFraction;
}

/// The finisher gesture: two circles in opposite directions.
class GestureConfig {
  const GestureConfig({
    required this.firstClockwise,
    required this.timeLimitSeconds,
    required this.minStrokeLength,
    required this.sampleStep,
    required this.loopDegrees,
    required this.minLoopSize,
    required this.maxLoopAspect,
    required this.closeFraction,
    required this.minArcDegrees,
  });

  factory GestureConfig.fromReader(JsonReader r) {
    final direction = r.string('firstDirection');
    if (direction != 'clockwise' && direction != 'counterclockwise') {
      throw ContentException(
          'balance.json: gesture.firstDirection must be "clockwise" or "counterclockwise" (found "$direction")');
    }
    return GestureConfig(
      firstClockwise: direction == 'clockwise',
      timeLimitSeconds: r.number('timeLimitSeconds', min: 0, minExclusive: true),
      minStrokeLength: r.number('minStrokeLength', min: 0, minExclusive: true),
      sampleStep: r.number('sampleStep', min: 0, minExclusive: true),
      loopDegrees: r.number('loopDegrees', min: 90),
      minLoopSize: r.number('minLoopSize', min: 0, minExclusive: true),
      maxLoopAspect: r.number('maxLoopAspect', min: 1),
      closeFraction: r.number('closeFraction', min: 0, minExclusive: true),
      minArcDegrees: r.number('minArcDegrees', min: 0),
    );
  }

  /// First circle is drawn clockwise (the second goes the other way).
  final bool firstClockwise;

  /// Seconds to finish both circles once the drawing starts.
  final double timeLimitSeconds;

  /// A touch that travels less than this (virtual pixels) is a tap, not a stroke.
  final double minStrokeLength;

  /// Samples closer than this (virtual pixels) are ignored.
  final double sampleStep;

  /// Turning angle that completes a circle.
  final double loopDegrees;

  /// Smallest circle accepted (virtual pixels across).
  final double minLoopSize;

  /// Widest/tallest ratio accepted for a circle.
  final double maxLoopAspect;

  /// A circle must end within this fraction of its size from where it started.
  final double closeFraction;

  /// A stroke lifted before turning this much is not a circle (fails at once).
  final double minArcDegrees;
}
