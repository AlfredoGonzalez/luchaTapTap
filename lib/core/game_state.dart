import 'big.dart';

/// Complete player state of the running game. Immutable: every change creates
/// a new value, which keeps it easy to test, compare and save later.
class GameState {
  GameState({
    required this.coins,
    required this.totalCoinsEarned,
    required this.fightNumber,
    required this.enemyHp,
    Map<String, int> upgradeLevels = const {},
    Map<String, int> trainerLevels = const {},
  })  : upgradeLevels = Map.unmodifiable(upgradeLevels),
        trainerLevels = Map.unmodifiable(trainerLevels);

  final Big coins;

  /// Coins earned in the current run (feeds the prestige formula later).
  final Big totalCoinsEarned;

  /// Current fight, starting at 1.
  final int fightNumber;

  /// Remaining HP of the current opponent.
  final Big enemyHp;

  final Map<String, int> upgradeLevels;
  final Map<String, int> trainerLevels;

  int upgradeLevel(String id) => upgradeLevels[id] ?? 0;
  int trainerLevel(String id) => trainerLevels[id] ?? 0;

  GameState copyWith({
    Big? coins,
    Big? totalCoinsEarned,
    int? fightNumber,
    Big? enemyHp,
    Map<String, int>? upgradeLevels,
    Map<String, int>? trainerLevels,
  }) =>
      GameState(
        coins: coins ?? this.coins,
        totalCoinsEarned: totalCoinsEarned ?? this.totalCoinsEarned,
        fightNumber: fightNumber ?? this.fightNumber,
        enemyHp: enemyHp ?? this.enemyHp,
        upgradeLevels: upgradeLevels ?? this.upgradeLevels,
        trainerLevels: trainerLevels ?? this.trainerLevels,
      );
}
