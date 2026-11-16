/// Progress of the daily goals and of the 7-day calendar. Days are local
/// calendar days counted from 1970-01-01 (see [dayNumberOf]).
class DailyState {
  const DailyState({
    this.day,
    this.goals = const [],
    this.base = const {},
    this.claimed = const {},
    this.chestClaimed = false,
    this.loginDay,
    this.loginIndex = 0,
  });

  /// Day the current goals belong to; null before the first day starts.
  final int? day;

  /// Ids of today's goals (from the pool in `goals.json`).
  final List<String> goals;

  /// Counter values when the day started; progress is the difference.
  final Map<String, int> base;

  /// Today's goals whose reward was taken.
  final Set<String> claimed;
  final bool chestClaimed;

  /// Last day the calendar reward was taken; null if never.
  final int? loginDay;

  /// Calendar slot the next claim takes (0-based). Missing a day does not
  /// reset it: the streak only pauses.
  final int loginIndex;

  DailyState copyWith({
    int? day,
    List<String>? goals,
    Map<String, int>? base,
    Set<String>? claimed,
    bool? chestClaimed,
    int? loginDay,
    int? loginIndex,
  }) => DailyState(
    day: day ?? this.day,
    goals: goals ?? this.goals,
    base: base ?? this.base,
    claimed: claimed ?? this.claimed,
    chestClaimed: chestClaimed ?? this.chestClaimed,
    loginDay: loginDay ?? this.loginDay,
    loginIndex: loginIndex ?? this.loginIndex,
  );

  Map<String, dynamic> toJson() => {
    'day': day,
    'goals': goals,
    'base': base,
    'claimed': claimed.toList()..sort(),
    'chestClaimed': chestClaimed,
    'loginDay': loginDay,
    'loginIndex': loginIndex,
  };

  /// Reads a saved state; unknown goal ids are dropped by the caller.
  factory DailyState.fromJson(Map<String, dynamic> json) => DailyState(
    day: (json['day'] as num?)?.toInt(),
    goals: [for (final g in (json['goals'] as List?) ?? const []) g as String],
    base: {
      for (final e in ((json['base'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    claimed: {
      for (final g in (json['claimed'] as List?) ?? const []) g as String,
    },
    chestClaimed: json['chestClaimed'] as bool? ?? false,
    loginDay: (json['loginDay'] as num?)?.toInt(),
    loginIndex: (json['loginIndex'] as num?)?.toInt() ?? 0,
  );

  /// Number of the local calendar day of [time] (days since 1970-01-01).
  static int dayNumberOf(DateTime time) =>
      DateTime.utc(time.year, time.month, time.day)
          .difference(DateTime.utc(1970))
          .inDays;
}
