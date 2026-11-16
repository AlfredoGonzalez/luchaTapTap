import 'content_exception.dart';
import 'json_reader.dart';

/// Counters the game keeps (in `GameState.stats`) or derives from the state,
/// used by achievements and daily goals.
enum GoalCounter {
  taps,
  defeats,
  bosses,
  prestiges,
  finishers,
  luckyCaught,
  skillsUsed,
  upgradeLevels,
  trainerLevels,
  dailyGoals,
  loginDays,

  /// Derived: the best fight reached (not a running count).
  bestFight,

  /// Derived: masks owned.
  masksOwned;

  /// Counters that are running totals in `GameState.stats` (the derived ones
  /// are read from the state instead).
  bool get isStat => this != bestFight && this != masksOwned;

  static GoalCounter parse(String source, String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
      '$source: "$id" has unknown counter "$name" (known: ${values.map((e) => e.name).join(', ')})',
    );
  }
}

/// What a goal, the daily chest or a day of the calendar gives. Any mix of
/// Belts, coins (as a number of the current fight's rewards, so it keeps up
/// with the player) and a temporary coin boost.
class RewardDef {
  const RewardDef({
    this.belts = 0,
    this.fightCoins = 0,
    this.boostSeconds = 0,
    this.boostMultiplier = 1,
  });

  factory RewardDef.fromReader(JsonReader r) {
    final reward = RewardDef(
      belts: r.has('belts') ? r.integer('belts', min: 0) : 0,
      fightCoins: r.has('fightCoins') ? r.number('fightCoins', min: 0) : 0,
      boostSeconds: r.has('boostSeconds') ? r.number('boostSeconds', min: 0) : 0,
      boostMultiplier: r.has('boostMultiplier')
          ? r.number('boostMultiplier', min: 1)
          : 1,
    );
    if (reward.isEmpty) {
      throw ContentException('${r.where}: a reward must give something');
    }
    if ((reward.boostSeconds > 0) != (reward.boostMultiplier > 1)) {
      throw ContentException(
        '${r.where}: boostSeconds and boostMultiplier go together',
      );
    }
    return reward;
  }

  final int belts;

  /// Coins worth this many rewards of the current (regular) fight.
  final double fightCoins;
  final double boostSeconds;
  final double boostMultiplier;

  bool get isEmpty => belts == 0 && fightCoins == 0 && boostSeconds == 0;
}

/// A daily goal from the pool: reach [target] more of [counter] today.
class DailyGoalDef {
  const DailyGoalDef({
    required this.id,
    required this.counter,
    required this.target,
    required this.reward,
  });

  factory DailyGoalDef.fromReader(JsonReader r) {
    final id = r.string('id');
    final counter = GoalCounter.parse('goals.json', id, r.string('counter'));
    if (!counter.isStat) {
      throw ContentException(
        'goals.json: daily goal "$id" needs a running counter, not "${counter.name}"',
      );
    }
    return DailyGoalDef(
      id: id,
      counter: counter,
      target: r.integer('target', min: 1),
      reward: RewardDef.fromReader(r.object('reward')),
    );
  }

  final String id;
  final GoalCounter counter;
  final int target;
  final RewardDef reward;
}

enum EventEffect {
  /// Every coin earned is multiplied.
  coinMultiplier,

  /// Boss rewards are multiplied.
  bossCoinMultiplier;

  static EventEffect parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
      'goals.json: event "$id" has unknown effect "$name" (known: ${values.map((e) => e.name).join(', ')})',
    );
  }
}

/// A timed bonus. Active on some weekdays (1 = Monday ... 7 = Sunday) and/or
/// between two dates (inclusive), by the phone's calendar.
class EventDef {
  const EventDef({
    required this.id,
    required this.name,
    required this.text,
    required this.effect,
    required this.value,
    this.weekdays = const [],
    this.from,
    this.to,
  });

  factory EventDef.fromReader(JsonReader r) {
    final id = r.string('id');
    DateTime? date(String key) {
      if (!r.has(key)) return null;
      final parsed = DateTime.tryParse(r.string(key));
      if (parsed == null) {
        throw ContentException('goals.json: event "$id" has a bad $key date');
      }
      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }

    final weekdays = r.has('weekdays')
        ? [for (final d in r.numbers('weekdays', min: 1)) d.toInt()]
        : const <int>[];
    if (weekdays.any((d) => d > 7)) {
      throw ContentException('goals.json: event "$id" weekdays go from 1 to 7');
    }
    final from = date('from');
    final to = date('to');
    if (weekdays.isEmpty && from == null && to == null) {
      throw ContentException(
        'goals.json: event "$id" needs weekdays or a from/to date',
      );
    }
    return EventDef(
      id: id,
      name: r.string('name'),
      text: r.string('text'),
      effect: EventEffect.parse(id, r.string('effect')),
      value: r.number('value', min: 1),
      weekdays: weekdays,
      from: from,
      to: to,
    );
  }

  final String id;
  final String name;
  final String text;
  final EventEffect effect;
  final double value;
  final List<int> weekdays;
  final DateTime? from;
  final DateTime? to;

  /// Whether the event runs on the local calendar day [day] (only its year,
  /// month and day are used).
  bool activeOn(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
    if (weekdays.isNotEmpty && !weekdays.contains(d.weekday)) return false;
    if (from != null && d.isBefore(from!)) return false;
    if (to != null && d.isAfter(to!)) return false;
    return true;
  }
}

/// Daily goals, the daily chest, the 7-day calendar and the events, from
/// `goals.json`.
class GoalsDef {
  const GoalsDef({
    required this.dailyCount,
    required this.dailyPool,
    required this.chest,
    required this.loginRewards,
    required this.events,
  });

  factory GoalsDef.fromReader(JsonReader r) {
    final daily = r.object('daily');
    final pool = [for (final g in daily.objects('pool')) DailyGoalDef.fromReader(g)];
    final ids = <String>{};
    for (final g in pool) {
      if (!ids.add(g.id)) {
        throw ContentException('goals.json: duplicate daily goal "${g.id}"');
      }
    }
    final count = daily.integer('count', min: 1);
    if (count > pool.length) {
      throw ContentException(
        'goals.json: daily.count ($count) is larger than the pool (${pool.length})',
      );
    }
    final login = [
      for (final d in r.object('login').objects('rewards')) RewardDef.fromReader(d),
    ];
    if (login.isEmpty) {
      throw ContentException('goals.json: login.rewards needs at least one day');
    }
    final events = [for (final e in r.objects('events')) EventDef.fromReader(e)];
    final eventIds = <String>{};
    for (final e in events) {
      if (!eventIds.add(e.id)) {
        throw ContentException('goals.json: duplicate event "${e.id}"');
      }
    }
    return GoalsDef(
      dailyCount: count,
      dailyPool: pool,
      chest: RewardDef.fromReader(daily.object('chest')),
      loginRewards: login,
      events: events,
    );
  }

  /// Goals offered each day, drawn from [dailyPool].
  final int dailyCount;
  final List<DailyGoalDef> dailyPool;

  /// Given once all of the day's goals are claimed.
  final RewardDef chest;

  /// The calendar: one reward per day claimed, then it starts over.
  final List<RewardDef> loginRewards;
  final List<EventDef> events;
}
