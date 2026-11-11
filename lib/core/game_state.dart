import 'big.dart';

/// A random pickup floating in the arena.
class LuckyEvent {
  const LuckyEvent({required this.x, required this.y, required this.lifeLeft});

  /// Position as a fraction (0 to 1) of the arena width and height.
  final double x;
  final double y;

  /// Seconds before it vanishes.
  final double lifeLeft;

  LuckyEvent withLife(double seconds) =>
      LuckyEvent(x: x, y: y, lifeLeft: seconds);
}

/// What happened while the app was closed.
class OfflineReport {
  const OfflineReport({
    required this.awaySeconds,
    required this.appliedSeconds,
    required this.capSeconds,
    required this.coinsEarned,
    required this.defeats,
  });

  /// Real time between closing and reopening.
  final double awaySeconds;

  /// Time that actually counted (limited by the cap).
  final double appliedSeconds;
  final double capSeconds;
  final Big coinsEarned;
  final int defeats;

  bool get capped => awaySeconds > capSeconds;
}

/// Complete player state of the running game. Immutable: every change creates
/// a new value, which keeps it easy to test, compare and save.
class GameState {
  GameState({
    required this.coins,
    required this.totalCoinsEarned,
    required this.fightNumber,
    required this.enemyHp,
    Map<String, int> upgradeLevels = const {},
    Map<String, int> trainerLevels = const {},
    this.belts = Big.zero,
    this.lifetimeBelts = Big.zero,
    this.comboMeter = 0,
    this.secondsSinceTap = 0,
    this.bossTimeLeft,
    Map<String, int> skillLevels = const {},
    Map<String, double> skillCooldowns = const {},
    Map<String, double> skillActive = const {},
    this.lucky,
    Map<String, int> talentLevels = const {},
    Set<String> ownedMasks = const {},
    this.equippedMask,
    Map<String, int> stats = const {},
    Set<String> achievements = const {},
    Set<String> purchases = const {},
    this.pendingOffline,
    this.bestFight = 1,
    this.boostLeft = 0,
    this.boostMultiplier = 1,
    Map<String, int> adReadyAt = const {},
  }) : upgradeLevels = Map.unmodifiable(upgradeLevels),
       trainerLevels = Map.unmodifiable(trainerLevels),
       skillLevels = Map.unmodifiable(skillLevels),
       skillCooldowns = Map.unmodifiable(skillCooldowns),
       skillActive = Map.unmodifiable(skillActive),
       talentLevels = Map.unmodifiable(talentLevels),
       ownedMasks = Set.unmodifiable(ownedMasks),
       stats = Map.unmodifiable(stats),
       achievements = Set.unmodifiable(achievements),
       purchases = Set.unmodifiable(purchases),
       adReadyAt = Map.unmodifiable(adReadyAt);

  final Big coins;

  /// Coins earned in the current run (feeds the prestige formula).
  final Big totalCoinsEarned;

  /// Current fight, starting at 1.
  final int fightNumber;

  /// Remaining HP of the current opponent.
  final Big enemyHp;

  final Map<String, int> upgradeLevels;
  final Map<String, int> trainerLevels;

  /// Spendable Belts (permanent currency).
  final Big belts;

  /// Every Belt ever earned; drives the permanent damage bonus.
  final Big lifetimeBelts;

  /// Combo meter from 0 to 1; full means the finisher is ready.
  final double comboMeter;
  final double secondsSinceTap;

  /// Boss countdown, null until the boss fight's timer starts.
  final double? bossTimeLeft;

  final Map<String, int> skillLevels;
  final Map<String, double> skillCooldowns;
  final Map<String, double> skillActive;
  final LuckyEvent? lucky;
  final Map<String, int> talentLevels;
  final Set<String> ownedMasks;
  final String? equippedMask;

  /// Counters for achievements: taps, defeats, bosses, prestiges.
  final Map<String, int> stats;
  final Set<String> achievements;

  /// Ids of store purchases (for example "mas_descanso").
  final Set<String> purchases;

  /// Offline earnings waiting for the player to collect them.
  final OfflineReport? pendingOffline;

  /// Furthest fight ever reached (across prestiges).
  final int bestFight;

  /// Seconds left of the rewarded-ad coin boost, and its multiplier.
  final double boostLeft;
  final double boostMultiplier;

  /// Rewarded-ad offers: shop item id to the time (epoch milliseconds, UTC)
  /// when it can be used again.
  final Map<String, int> adReadyAt;

  int upgradeLevel(String id) => upgradeLevels[id] ?? 0;
  int trainerLevel(String id) => trainerLevels[id] ?? 0;
  int skillLevel(String id) => skillLevels[id] ?? 0;
  int talentLevel(String id) => talentLevels[id] ?? 0;
  int stat(String name) => stats[name] ?? 0;
  double skillCooldownLeft(String id) => skillCooldowns[id] ?? 0;
  double skillActiveLeft(String id) => skillActive[id] ?? 0;

  /// Returns a copy with the given fields replaced. The nullable fields
  /// [bossTimeLeft], [lucky], [equippedMask] and [pendingOffline] use the
  /// `clear*` flags to be set back to null.
  GameState copyWith({
    Big? coins,
    Big? totalCoinsEarned,
    int? fightNumber,
    Big? enemyHp,
    Map<String, int>? upgradeLevels,
    Map<String, int>? trainerLevels,
    Big? belts,
    Big? lifetimeBelts,
    double? comboMeter,
    double? secondsSinceTap,
    double? bossTimeLeft,
    bool clearBossTimer = false,
    Map<String, int>? skillLevels,
    Map<String, double>? skillCooldowns,
    Map<String, double>? skillActive,
    LuckyEvent? lucky,
    bool clearLucky = false,
    Map<String, int>? talentLevels,
    Set<String>? ownedMasks,
    String? equippedMask,
    bool clearEquippedMask = false,
    Map<String, int>? stats,
    Set<String>? achievements,
    Set<String>? purchases,
    OfflineReport? pendingOffline,
    bool clearPendingOffline = false,
    int? bestFight,
    double? boostLeft,
    double? boostMultiplier,
    Map<String, int>? adReadyAt,
  }) => GameState(
    coins: coins ?? this.coins,
    totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
    fightNumber: fightNumber ?? this.fightNumber,
    enemyHp: enemyHp ?? this.enemyHp,
    upgradeLevels: upgradeLevels ?? this.upgradeLevels,
    trainerLevels: trainerLevels ?? this.trainerLevels,
    belts: belts ?? this.belts,
    lifetimeBelts: lifetimeBelts ?? this.lifetimeBelts,
    comboMeter: comboMeter ?? this.comboMeter,
    secondsSinceTap: secondsSinceTap ?? this.secondsSinceTap,
    bossTimeLeft: clearBossTimer ? null : (bossTimeLeft ?? this.bossTimeLeft),
    skillLevels: skillLevels ?? this.skillLevels,
    skillCooldowns: skillCooldowns ?? this.skillCooldowns,
    skillActive: skillActive ?? this.skillActive,
    lucky: clearLucky ? null : (lucky ?? this.lucky),
    talentLevels: talentLevels ?? this.talentLevels,
    ownedMasks: ownedMasks ?? this.ownedMasks,
    equippedMask: clearEquippedMask
        ? null
        : (equippedMask ?? this.equippedMask),
    stats: stats ?? this.stats,
    achievements: achievements ?? this.achievements,
    purchases: purchases ?? this.purchases,
    pendingOffline: clearPendingOffline
        ? null
        : (pendingOffline ?? this.pendingOffline),
    bestFight: bestFight ?? this.bestFight,
    boostLeft: boostLeft ?? this.boostLeft,
    boostMultiplier: boostMultiplier ?? this.boostMultiplier,
    adReadyAt: adReadyAt ?? this.adReadyAt,
  );
}
