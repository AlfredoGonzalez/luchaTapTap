import 'balance.dart';
import 'content_exception.dart';
import 'content_models.dart';
import 'json_reader.dart';

/// Names of the JSON files the game loads at startup, under `assets/data/`.
abstract final class ContentFiles {
  static const balance = 'balance.json';
  static const opponents = 'opponents.json';
  static const leagues = 'leagues.json';
  static const trainers = 'trainers.json';
  static const upgrades = 'upgrades.json';
  static const skills = 'skills.json';
  static const talents = 'talents.json';
  static const masks = 'masks.json';
  static const achievements = 'achievements.json';
  static const strings = 'strings_es.json';

  static const all = [
    balance,
    opponents,
    leagues,
    trainers,
    upgrades,
    skills,
    talents,
    masks,
    achievements,
    strings,
  ];
}

const int _supportedSchemaVersion = 1;

/// Where a fight number falls in the league structure.
class FightInfo {
  const FightInfo({
    required this.fight,
    required this.league,
    required this.position,
    required this.isBoss,
    required this.opponent,
    required this.loops,
  });

  final int fight;
  final LeagueDef league;

  /// Zero-based position inside the league (the boss is the last one).
  final int position;
  final bool isBoss;
  final OpponentDef opponent;

  /// Completed passes through all leagues (endless leagues).
  final int loops;
}

/// All game content, parsed and validated, read-only after creation.
///
/// Pure Dart: [ContentBundle.parse] takes already decoded JSON so tests can
/// build it from files on disk or from modified maps.
class ContentBundle {
  ContentBundle._({
    required this.balance,
    required this.opponents,
    required this.leagues,
    required this.trainers,
    required this.upgrades,
    required this.skills,
    required this.talentBranches,
    required this.masks,
    required this.achievements,
    required this.strings,
  });

  /// [files] maps a file name from [ContentFiles] to its decoded JSON.
  /// Throws [ContentException] on any missing file, bad value, duplicate id
  /// or broken reference.
  factory ContentBundle.parse(Map<String, Map<String, dynamic>> files) {
    Map<String, dynamic> file(String name) =>
        files[name] ?? (throw ContentException('$name is missing'));

    final balance = Balance.fromJson(file(ContentFiles.balance));

    final opponentsReader = JsonReader(ContentFiles.opponents, file(ContentFiles.opponents))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final opponents = _unique(
      ContentFiles.opponents,
      opponentsReader.objects('opponents').map(OpponentDef.fromReader),
      (o) => o.id,
    );

    final leaguesReader = JsonReader(ContentFiles.leagues, file(ContentFiles.leagues))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final leagues = _unique(
      ContentFiles.leagues,
      leaguesReader.objects('leagues').map(LeagueDef.fromReader),
      (l) => l.id,
    )..sort((a, b) => a.order.compareTo(b.order));
    if (leagues.isEmpty) {
      throw ContentException('${ContentFiles.leagues}: at least one league is required');
    }
    final orders = leagues.map((l) => l.order).toSet();
    if (orders.length != leagues.length) {
      throw ContentException('${ContentFiles.leagues}: league "order" values must be unique');
    }
    final opponentById = {for (final o in opponents) o.id: o};
    for (final league in leagues) {
      if (league.opponentIds.isEmpty) {
        throw ContentException(
            '${ContentFiles.leagues}: "${league.id}" needs at least one opponent');
      }
      for (final id in league.opponentIds) {
        final opponent = opponentById[id];
        if (opponent == null) {
          throw ContentException(
              '${ContentFiles.leagues}: "${league.id}" references unknown opponent "$id"');
        }
        if (opponent.isBoss) {
          throw ContentException(
              '${ContentFiles.leagues}: "${league.id}" lists boss "$id" as a regular opponent');
        }
      }
      final bossId = league.bossId;
      if (bossId != null) {
        final boss = opponentById[bossId];
        if (boss == null || !boss.isBoss) {
          throw ContentException(
              '${ContentFiles.leagues}: "${league.id}" bossId "$bossId" must be an opponent with isBoss true');
        }
      }
    }

    final trainersReader = JsonReader(ContentFiles.trainers, file(ContentFiles.trainers))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final trainers = _unique(
      ContentFiles.trainers,
      trainersReader.objects('trainers').map(TrainerDef.fromReader),
      (t) => t.id,
    );

    final upgradesReader = JsonReader(ContentFiles.upgrades, file(ContentFiles.upgrades))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final upgrades = _unique(
      ContentFiles.upgrades,
      upgradesReader.objects('upgrades').map(UpgradeDef.fromReader),
      (u) => u.id,
    );

    final skillsReader = JsonReader(ContentFiles.skills, file(ContentFiles.skills))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final skills = _unique(
      ContentFiles.skills,
      skillsReader.objects('skills').map(SkillDef.fromReader),
      (s) => s.id,
    );

    final talentsReader = JsonReader(ContentFiles.talents, file(ContentFiles.talents))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final branches = <TalentBranchDef>[];
    for (final branch in talentsReader.objects('branches')) {
      final branchId = branch.string('id');
      branches.add(TalentBranchDef(
        id: branchId,
        name: branch.string('name'),
        nodes: branch.objects('nodes').map((n) => TalentDef.fromReader(n, branchId)).toList(),
      ));
    }
    _unique(ContentFiles.talents, branches, (b) => b.id);
    final allTalents = _unique(
      ContentFiles.talents,
      branches.expand((b) => b.nodes),
      (t) => t.id,
    );
    final talentById = {for (final t in allTalents) t.id: t};
    for (final t in allTalents) {
      final parent = t.parent;
      if (parent == null) continue;
      final p = talentById[parent];
      if (p == null) {
        throw ContentException(
            '${ContentFiles.talents}: "${t.id}" has unknown parent "$parent"');
      }
      if (p.branchId != t.branchId) {
        throw ContentException(
            '${ContentFiles.talents}: "${t.id}" and its parent "$parent" must be in the same branch');
      }
      // Parents must come earlier in the file, which also rules out cycles.
      if (allTalents.indexOf(p) >= allTalents.indexOf(t)) {
        throw ContentException(
            '${ContentFiles.talents}: parent "$parent" must be listed before "${t.id}"');
      }
    }

    final masksReader = JsonReader(ContentFiles.masks, file(ContentFiles.masks))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final masks = _unique(
      ContentFiles.masks,
      masksReader.objects('masks').map(MaskDef.fromReader),
      (m) => m.id,
    );
    if (!masks.any((m) => m.unlockRule == MaskUnlockRule.starter)) {
      throw ContentException('${ContentFiles.masks}: at least one starter mask is required');
    }
    for (final m in masks) {
      if (m.unlockRule == MaskUnlockRule.league && !orders.contains(m.unlockValue.toInt())) {
        throw ContentException(
            '${ContentFiles.masks}: "${m.id}" unlocks with league ${m.unlockValue.toInt()}, which does not exist');
      }
    }

    final achievementsReader =
        JsonReader(ContentFiles.achievements, file(ContentFiles.achievements))
          ..expectSchemaVersion(_supportedSchemaVersion);
    final achievements = _unique(
      ContentFiles.achievements,
      achievementsReader.objects('achievements').map(AchievementDef.fromReader),
      (a) => a.id,
    );

    final stringsReader = JsonReader(ContentFiles.strings, file(ContentFiles.strings))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final strings = stringsReader.stringMap('strings');

    return ContentBundle._(
      balance: balance,
      opponents: List.unmodifiable(opponents),
      leagues: List.unmodifiable(leagues),
      trainers: List.unmodifiable(trainers),
      upgrades: List.unmodifiable(upgrades),
      skills: List.unmodifiable(skills),
      talentBranches: List.unmodifiable(branches),
      masks: List.unmodifiable(masks),
      achievements: List.unmodifiable(achievements),
      strings: Map.unmodifiable(strings),
    );
  }

  static List<T> _unique<T>(String source, Iterable<T> items, String Function(T) idOf) {
    final result = items.toList();
    final seen = <String>{};
    for (final item in result) {
      final id = idOf(item);
      if (!seen.add(id)) {
        throw ContentException('$source: duplicate id "$id"');
      }
    }
    return result;
  }

  final Balance balance;
  final List<OpponentDef> opponents;
  final List<LeagueDef> leagues;
  final List<TrainerDef> trainers;
  final List<UpgradeDef> upgrades;
  final List<SkillDef> skills;
  final List<TalentBranchDef> talentBranches;
  final List<MaskDef> masks;
  final List<AchievementDef> achievements;
  final Map<String, String> strings;

  late final Map<String, OpponentDef> _opponentById = {for (final o in opponents) o.id: o};

  /// Fights in one league: its regular opponents, then the boss if any.
  static int leagueLength(LeagueDef league) =>
      league.opponentIds.length + (league.bossId == null ? 0 : 1);

  late final int _cycleLength = leagues.fold(0, (sum, l) => sum + leagueLength(l));

  /// All talents of all branches, in file order.
  late final List<TalentDef> talents = [for (final b in talentBranches) ...b.nodes];

  /// Structure of fight number [fight] (1-based). Leagues play in order and,
  /// after the last one, repeat forever (endless leagues).
  FightInfo fightInfo(int fight) {
    final zeroBased = fight - 1;
    final loops = zeroBased ~/ _cycleLength;
    var offset = zeroBased % _cycleLength;
    for (final league in leagues) {
      final length = leagueLength(league);
      if (offset < length) {
        final isBoss = league.bossId != null && offset == length - 1;
        final id = isBoss ? league.bossId! : league.opponentIds[offset];
        return FightInfo(
          fight: fight,
          league: league,
          position: offset,
          isBoss: isBoss,
          opponent: _opponentById[id]!,
          loops: loops,
        );
      }
      offset -= length;
    }
    throw StateError('unreachable: fight $fight is outside every league');
  }

  /// Opponent for fight number [fight].
  OpponentDef opponentForFight(int fight) => fightInfo(fight).opponent;

  /// Number of the last fight (the boss, when there is one) of the league with
  /// the given `order` in the first pass through the leagues.
  int leagueEndFight(int order) {
    var end = 0;
    for (final league in leagues) {
      end += leagueLength(league);
      if (league.order == order) return end;
    }
    throw ArgumentError.value(order, 'order', 'no league with this order');
  }

  UpgradeDef upgrade(String id) => upgrades.firstWhere(
        (u) => u.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown upgrade'),
      );

  SkillDef skill(String id) => skills.firstWhere(
        (s) => s.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown skill'),
      );

  TalentDef talent(String id) => talents.firstWhere(
        (t) => t.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown talent'),
      );

  MaskDef mask(String id) => masks.firstWhere(
        (m) => m.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown mask'),
      );

  TrainerDef trainer(String id) => trainers.firstWhere(
        (t) => t.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown trainer'),
      );
}
