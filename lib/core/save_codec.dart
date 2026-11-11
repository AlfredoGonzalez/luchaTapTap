import 'dart:convert';

import '../data/content_bundle.dart';
import '../data/content_exception.dart';
import 'big.dart';
import 'game_state.dart';

/// A save file could not be read (damaged, from a newer build, or invalid).
class SaveFormatException implements Exception {
  SaveFormatException(this.message);

  final String message;

  @override
  String toString() => 'SaveFormatException: $message';
}

/// Everything stored in the save file.
class SaveData {
  const SaveData({
    required this.saveVersion,
    required this.lastSeen,
    required this.rngState,
    required this.state,
    this.settings = const {},
  });

  final int saveVersion;

  /// UTC time of the last save; offline earnings are measured from here.
  final DateTime lastSeen;

  /// State of the seeded random generator, so replays stay reproducible.
  final int rngState;
  final GameState state;

  /// Player settings (sound, music, vibration...). Filled by the settings
  /// screen in a later milestone.
  final Map<String, dynamic> settings;
}

/// Upgrades a decoded save from one version to the next.
typedef SaveMigration = Map<String, dynamic> Function(
  Map<String, dynamic> json,
);

/// Turns [SaveData] into JSON text and back.
///
/// Pure Dart. Reading is forgiving: missing fields take their starting value
/// and ids that no longer exist in the content are dropped, so a save never
/// breaks because the data files changed. Older saves are upgraded by
/// [migrations]: `migrations[v]` converts version `v` to `v + 1`.
class SaveCodec {
  SaveCodec({
    required this.content,
    this.currentVersion = 1,
    this.migrations = const {},
  });

  final ContentBundle content;
  final int currentVersion;
  final Map<int, SaveMigration> migrations;

  String encode(SaveData data) {
    final s = data.state;
    return jsonEncode({
      'saveVersion': currentVersion,
      'lastSeen': data.lastSeen.toUtc().toIso8601String(),
      'rng': data.rngState,
      'settings': data.settings,
      'state': {
        'coins': s.coins.toJson(),
        'totalCoinsEarned': s.totalCoinsEarned.toJson(),
        'fightNumber': s.fightNumber,
        'enemyHp': s.enemyHp.toJson(),
        'upgradeLevels': s.upgradeLevels,
        'trainerLevels': s.trainerLevels,
        'belts': s.belts.toJson(),
        'lifetimeBelts': s.lifetimeBelts.toJson(),
        'comboMeter': s.comboMeter,
        'secondsSinceTap': s.secondsSinceTap,
        'bossTimeLeft': s.bossTimeLeft,
        'skillLevels': s.skillLevels,
        'skillCooldowns': s.skillCooldowns,
        'skillActive': s.skillActive,
        'lucky': s.lucky == null
            ? null
            : {'x': s.lucky!.x, 'y': s.lucky!.y, 'lifeLeft': s.lucky!.lifeLeft},
        'talentLevels': s.talentLevels,
        'ownedMasks': s.ownedMasks.toList()..sort(),
        'equippedMask': s.equippedMask,
        'stats': s.stats,
        'achievements': s.achievements.toList()..sort(),
        'purchases': s.purchases.toList()..sort(),
        'pendingOffline': s.pendingOffline == null
            ? null
            : {
                'awaySeconds': s.pendingOffline!.awaySeconds,
                'appliedSeconds': s.pendingOffline!.appliedSeconds,
                'capSeconds': s.pendingOffline!.capSeconds,
                'coinsEarned': s.pendingOffline!.coinsEarned.toJson(),
                'defeats': s.pendingOffline!.defeats,
              },
        'bestFight': s.bestFight,
        'boostLeft': s.boostLeft,
        'boostMultiplier': s.boostMultiplier,
        'adReadyAt': s.adReadyAt,
      },
    });
  }

  /// Decodes [text]. Throws [SaveFormatException] if it cannot be used.
  SaveData decode(String text) {
    try {
      return _decode(text);
    } on SaveFormatException {
      rethrow;
    } on FormatException catch (e) {
      throw SaveFormatException('invalid save: ${e.message}');
    } on TypeError catch (e) {
      throw SaveFormatException('invalid save structure: $e');
    } on ContentException catch (e) {
      throw SaveFormatException('invalid save: ${e.message}');
    }
  }

  SaveData _decode(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw SaveFormatException('save must contain a JSON object');
    }
    var json = decoded;
    var version = _int(json, 'saveVersion', 0);
    if (version <= 0) {
      throw SaveFormatException('save has no valid saveVersion');
    }
    if (version > currentVersion) {
      throw SaveFormatException(
        'save version $version is newer than this build supports ($currentVersion)',
      );
    }
    while (version < currentVersion) {
      final migrate = migrations[version];
      if (migrate == null) {
        throw SaveFormatException('no migration from save version $version');
      }
      json = migrate(Map<String, dynamic>.from(json));
      version++;
      json['saveVersion'] = version;
    }

    final lastSeen = DateTime.tryParse(json['lastSeen'] as String? ?? '');
    if (lastSeen == null) {
      throw SaveFormatException('save has no valid lastSeen');
    }
    final s = (json['state'] as Map?)?.cast<String, dynamic>() ?? const {};
    final b = content.balance;

    Map<String, int> levels(String key, bool Function(String) known) => {
      for (final e in ((s[key] as Map?) ?? const {}).entries)
        if (known(e.key as String) && (e.value as num) > 0)
          e.key as String: (e.value as num).toInt(),
    };
    Map<String, double> timers(String key, bool Function(String) known) => {
      for (final e in ((s[key] as Map?) ?? const {}).entries)
        if (known(e.key as String) && (e.value as num) > 0)
          e.key as String: (e.value as num).toDouble(),
    };
    Set<String> ids(String key, bool Function(String) known) => {
      for (final v in (s[key] as List?) ?? const [])
        if (known(v as String)) v,
    };

    final upgradeIds = content.upgrades.map((e) => e.id).toSet();
    final trainerIds = content.trainers.map((e) => e.id).toSet();
    final skillIds = content.skills.map((e) => e.id).toSet();
    final talentIds = content.talents.map((e) => e.id).toSet();
    final maskIds = content.masks.map((e) => e.id).toSet();
    final achievementIds = content.achievements.map((e) => e.id).toSet();
    final shopIds = content.shopItems.map((e) => e.id).toSet();
    const counters = {'taps', 'defeats', 'bosses', 'prestiges'};

    final lucky = s['lucky'] as Map?;
    final pending = s['pendingOffline'] as Map?;
    final equipped = s['equippedMask'] as String?;
    final fight = _int(s, 'fightNumber', b.startFightNumber);
    if (fight < 1) throw SaveFormatException('fightNumber must be at least 1');

    final state = GameState(
      coins: _big(s, 'coins', Big.fromDouble(b.startCoins)),
      totalCoinsEarned: _big(s, 'totalCoinsEarned', Big.zero),
      fightNumber: fight,
      enemyHp: _big(s, 'enemyHp', Big.one),
      upgradeLevels: levels('upgradeLevels', upgradeIds.contains),
      trainerLevels: levels('trainerLevels', trainerIds.contains),
      belts: _big(s, 'belts', Big.zero),
      lifetimeBelts: _big(s, 'lifetimeBelts', Big.zero),
      comboMeter: _double(s, 'comboMeter', 0).clamp(0.0, 1.0),
      secondsSinceTap: _double(s, 'secondsSinceTap', 0),
      bossTimeLeft: (s['bossTimeLeft'] as num?)?.toDouble(),
      skillLevels: levels('skillLevels', skillIds.contains),
      skillCooldowns: timers('skillCooldowns', skillIds.contains),
      skillActive: timers('skillActive', skillIds.contains),
      lucky: lucky == null
          ? null
          : LuckyEvent(
              x: (lucky['x'] as num).toDouble(),
              y: (lucky['y'] as num).toDouble(),
              lifeLeft: (lucky['lifeLeft'] as num).toDouble(),
            ),
      talentLevels: levels('talentLevels', talentIds.contains),
      ownedMasks: ids('ownedMasks', maskIds.contains),
      equippedMask: equipped != null && maskIds.contains(equipped)
          ? equipped
          : null,
      stats: levels('stats', counters.contains),
      achievements: ids('achievements', achievementIds.contains),
      purchases: {
        for (final v in (s['purchases'] as List?) ?? const []) v as String,
      },
      pendingOffline: pending == null
          ? null
          : OfflineReport(
              awaySeconds: (pending['awaySeconds'] as num).toDouble(),
              appliedSeconds: (pending['appliedSeconds'] as num).toDouble(),
              capSeconds: (pending['capSeconds'] as num).toDouble(),
              coinsEarned: Big.fromJson(pending['coinsEarned'] as String),
              defeats: (pending['defeats'] as num).toInt(),
            ),
      bestFight: _int(s, 'bestFight', fight),
      boostLeft: _double(s, 'boostLeft', 0),
      boostMultiplier: _double(s, 'boostMultiplier', 1),
      adReadyAt: levels('adReadyAt', shopIds.contains),
    );
    return SaveData(
      saveVersion: currentVersion,
      lastSeen: lastSeen.toUtc(),
      rngState: _int(json, 'rng', 1),
      state: state,
      settings: ((json['settings'] as Map?) ?? const {})
          .cast<String, dynamic>(),
    );
  }

  static Big _big(Map<String, dynamic> m, String key, Big fallback) {
    final v = m[key];
    return v == null ? fallback : Big.fromJson(v as String);
  }

  static int _int(Map<String, dynamic> m, String key, int fallback) =>
      (m[key] as num?)?.toInt() ?? fallback;

  static double _double(Map<String, dynamic> m, String key, double fallback) =>
      (m[key] as num?)?.toDouble() ?? fallback;
}
