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
  static const strings = 'strings_es.json';

  static const all = [balance, opponents, leagues, trainers, upgrades, strings];
}

const int _supportedSchemaVersion = 1;

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

    final stringsReader = JsonReader(ContentFiles.strings, file(ContentFiles.strings))
      ..expectSchemaVersion(_supportedSchemaVersion);
    final strings = stringsReader.stringMap('strings');

    return ContentBundle._(
      balance: balance,
      opponents: List.unmodifiable(opponents),
      leagues: List.unmodifiable(leagues),
      trainers: List.unmodifiable(trainers),
      upgrades: List.unmodifiable(upgrades),
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
  final Map<String, String> strings;

  /// Opponent for fight number [fight] (1-based).
  ///
  /// M1: loops through the first league's opponents. League progression,
  /// bosses and `loopScale` arrive with M2.
  OpponentDef opponentForFight(int fight) {
    final league = leagues.first;
    final id = league.opponentIds[(fight - 1) % league.opponentIds.length];
    return opponents.firstWhere((o) => o.id == id);
  }

  UpgradeDef upgrade(String id) => upgrades.firstWhere(
        (u) => u.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown upgrade'),
      );

  TrainerDef trainer(String id) => trainers.firstWhere(
        (t) => t.id == id,
        orElse: () => throw ArgumentError.value(id, 'id', 'unknown trainer'),
      );
}
