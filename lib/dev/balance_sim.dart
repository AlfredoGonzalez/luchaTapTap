import 'dart:math' as math;

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/game_engine.dart';
import '../core/rng.dart';
import '../data/content_bundle.dart';
import '../data/content_models.dart';

/// Development tool for the balance pass: a bot that plays the game through
/// the real [GameEngine] and records when it reaches each milestone. It is not
/// used by the app.

/// How a simulated player behaves.
class BotProfile {
  const BotProfile({
    required this.name,
    required this.tapsPerSecond,
    required this.actEverySeconds,
    this.finisherSuccess = 0.8,
    this.gestureSeconds = 2.5,
    this.luckyCatch = 0.6,
    this.stallMinutesBeforePrestige = 5,
    this.sessionMinutes,
    this.sessionEveryMinutes,
  });

  final String name;

  /// Taps per second while playing.
  final double tapsPerSecond;

  /// Seconds between shopping and skill decisions (the player looks at the
  /// screen this often).
  final double actEverySeconds;

  /// Chance that the finisher gesture is drawn correctly.
  final double finisherSuccess;

  /// Seconds spent drawing the gesture (no taps meanwhile). Zero means the
  /// player never tries it.
  final double gestureSeconds;

  /// Chance that a lucky pickup is caught.
  final double luckyCatch;

  /// The player changes mask (prestige) when the run has made no progress for
  /// this long and prestige is allowed.
  final double stallMinutesBeforePrestige;

  /// For a casual player: plays [sessionMinutes] every [sessionEveryMinutes]
  /// and is away (offline earnings) the rest of the time. Null means always
  /// playing.
  final double? sessionMinutes;
  final double? sessionEveryMinutes;

  /// The same player with a different chance of catching lucky pickups.
  BotProfile withLuckyCatch(double chance) => BotProfile(
        name: name,
        tapsPerSecond: tapsPerSecond,
        actEverySeconds: actEverySeconds,
        finisherSuccess: finisherSuccess,
        gestureSeconds: gestureSeconds,
        luckyCatch: chance,
        stallMinutesBeforePrestige: stallMinutesBeforePrestige,
        sessionMinutes: sessionMinutes,
        sessionEveryMinutes: sessionEveryMinutes,
      );

  /// Plays all the time at a steady pace.
  static const BotProfile active = BotProfile(
    name: 'activo',
    tapsPerSecond: 4,
    actEverySeconds: 2,
  );

  /// Plays 5 minutes every half hour, offline the rest.
  static const BotProfile casual = BotProfile(
    name: 'casual',
    tapsPerSecond: 3,
    actEverySeconds: 3,
    sessionMinutes: 5,
    sessionEveryMinutes: 30,
  );

  /// Opens the game every 4 hours for a minute (a few taps to get started),
  /// collects, shops and leaves.
  static const BotProfile idle = BotProfile(
    name: 'pasivo',
    tapsPerSecond: 2,
    actEverySeconds: 5,
    sessionMinutes: 1,
    sessionEveryMinutes: 240,
  );
}

/// Something the bot reached, with the time it took.
class SimEvent {
  const SimEvent(this.minute, this.label, {this.fight = 0, this.belts = 0});

  final double minute;
  final String label;
  final int fight;
  final double belts;
}

/// Progress at a point in time (for the table).
class SimSnapshot {
  const SimSnapshot(this.minute, this.fight, this.bestFight, this.prestiges, this.belts, this.dps, this.tap);

  final double minute;
  final int fight;
  final int bestFight;
  final int prestiges;
  final double belts;
  final Big dps;
  final Big tap;
}

class SimResult {
  SimResult(this.profile, this.events, this.snapshots, this.engine, this.buyMinutes, this.firstTrainerMinute, this.firstSkillMinute);

  /// Minute of every upgrade, trainer or skill purchase.
  final List<double> buyMinutes;

  /// What was bought, in order, with the minute (first purchases of each kind).
  List<String> buyLog = const [];

  /// Minute of the first trainer hired, or null.
  final double? firstTrainerMinute;

  /// Minute of the first skill learned, or null.
  final double? firstSkillMinute;

  /// Purchases made in the first [minutes] minutes (the GDD asks for one every
  /// 30 to 60 seconds early on).
  int buysWithin(double minutes) => buyMinutes.where((m) => m <= minutes).length;

  final BotProfile profile;
  final List<SimEvent> events;
  final List<SimSnapshot> snapshots;
  final GameEngine engine;

  /// Minute of the first event with [label], or null.
  double? firstMinute(String label) {
    for (final e in events) {
      if (e.label == label) return e.minute;
    }
    return null;
  }

  /// Minutes at which each prestige happened.
  List<double> get prestigeMinutes => [
        for (final e in events)
          if (e.label == 'prestige') e.minute,
      ];
}

/// Plays [content] with [profile] for [length] of game time.
SimResult simulate(
  ContentBundle content,
  BotProfile profile, {
  Duration length = const Duration(hours: 3),
  int seed = 1,
  Duration snapshotEvery = const Duration(minutes: 15),
}) {
  final engine = GameEngine(content: content, rng: SeededRng(seed));
  final bot = _Bot(engine, content, profile, SeededRng(seed + 1000));
  return bot.run(length, snapshotEvery);
}

class _Bot {
  _Bot(this.engine, this.content, this.profile, this.rng);

  final GameEngine engine;
  final ContentBundle content;
  final BotProfile profile;
  final SeededRng rng;

  final List<SimEvent> events = [];
  final List<SimSnapshot> snapshots = [];
  final List<double> buyMinutes = [];
  final List<String> buyLog = [];
  double? firstTrainerMinute;
  double? firstSkillMinute;
  double t = 0; // seconds
  double _tapDebt = 0;
  double _busyUntil = 0; // drawing the gesture: no taps until then
  bool _pendingFinisher = false;
  double _lastActAt = -1e9;
  double _lastProgressAt = 0;
  int _runBestFight = 1;
  int _prestiges = 0;
  int _bossesBeaten = 0;
  bool _firstPrestigeReady = false;
  final Set<int> _milestones = {};

  double get _tickSeconds => 1 / content.balance.ticksPerSecond;

  SimResult run(Duration length, Duration snapshotEvery) {
    final end = length.inMicroseconds / 1e6;
    var nextSnapshot = 0.0;
    final cycle = profile.sessionEveryMinutes == null ? null : profile.sessionEveryMinutes! * 60;
    final session = profile.sessionMinutes == null ? null : profile.sessionMinutes! * 60;

    while (t < end) {
      if (t >= nextSnapshot) {
        _snapshot();
        nextSnapshot += snapshotEvery.inMicroseconds / 1e6;
      }
      final playing = cycle == null || (t % cycle) < session!;
      if (!playing) {
        // Away until the next session: the engine simulates the idle progress.
        final away = math.min(cycle - (t % cycle), end - t);
        engine.applyOffline(Duration(microseconds: (away * 1e6).round()));
        t += away;
        _noteProgress();
        continue;
      }
      if (engine.state.pendingOffline != null) engine.collectOffline();
      _playTick();
    }
    _snapshot();
    return SimResult(profile, events, snapshots, engine, buyMinutes, firstTrainerMinute, firstSkillMinute)
      ..buyLog = buyLog;
  }

  void _snapshot() {
    final s = engine.state;
    snapshots.add(SimSnapshot(t / 60, s.fightNumber, s.bestFight, _prestiges, s.belts.toDouble(),
        engine.damagePerSecond, engine.tapDamage));
  }

  void _playTick() {
    if (t - _lastActAt >= profile.actEverySeconds) {
      _lastActAt = t;
      _act();
    }
    // Taps for this tick (none while the finger draws the gesture).
    if (t >= _busyUntil) {
      _tapDebt += profile.tapsPerSecond * _tickSeconds;
      while (_tapDebt >= 1) {
        _tapDebt -= 1;
        if (!engine.awaitingBossStart) engine.tap();
      }
    } else {
      _tapDebt = 0;
    }
    // The hit lands when the drawing is done; only then is a new one started.
    if (_pendingFinisher && t >= _busyUntil) {
      _pendingFinisher = false;
      if (engine.finisherReady) {
        if (rng.nextDouble() < profile.finisherSuccess) {
          engine.finisher();
        } else {
          engine.failFinisher();
        }
      }
    }
    if (!_pendingFinisher &&
        engine.finisherReady &&
        !engine.awaitingBossStart &&
        profile.gestureSeconds > 0 &&
        t >= _busyUntil) {
      // Drawing the two circles takes a moment, without tapping.
      _busyUntil = t + profile.gestureSeconds;
      _pendingFinisher = true;
    }
    if (engine.state.lucky != null && rng.nextDouble() < profile.luckyCatch * _tickSeconds * 2) {
      engine.collectLucky();
    }
    final before = engine.state.stat('bosses');
    engine.tick();
    if (engine.state.stat('bosses') > before) {
      _bossesBeaten = engine.state.stat('bosses');
      _log('jefe $_bossesBeaten vencido');
    }
    t += _tickSeconds;
    _noteProgress();
  }

  void _noteProgress() {
    final fight = engine.state.fightNumber;
    if (fight > _runBestFight) {
      _runBestFight = fight;
      _lastProgressAt = t;
      for (final m in const [5, 9, 11, 15, 20, 30, 40, 50]) {
        if (fight >= m && _milestones.add(_prestiges * 1000 + m)) {
          _log('pelea $m', fight: fight);
        }
      }
    }
    if (!_firstPrestigeReady && engine.prestigePreview().canPrestige) {
      _firstPrestigeReady = true;
      _log('prestigio disponible');
    }
  }

  void _log(String label, {int fight = 0}) => events.add(
        SimEvent(t / 60, label, fight: fight == 0 ? engine.state.fightNumber : fight, belts: engine.state.belts.toDouble()),
      );

  // ---------------------------------------------------------------------------
  // Decisions

  void _act() {
    _useSkills();
    _shop();
    _spendBelts();
    _equipBestMask();
    _maybeChallengeBoss();
    _maybePrestige();
  }

  /// Damage per second the bot expects from its current build.
  double _effective(GameEngine e) {
    final crit = e.critChance;
    final tap = e.tapDamage.toDouble() * (1 + crit * (content.balance.crit.multiplier - 1));
    return tap * profile.tapsPerSecond + e.damagePerSecond.toDouble();
  }

  GameEngine _copy() => GameEngine(content: content, state: engine.state, rng: SeededRng(1));

  void _shop() {
    for (var guard = 0; guard < 300; guard++) {
      final base = _effective(engine);
      ({double ratio, bool upgrade, String id})? best;
      for (final u in content.upgrades) {
        final q = engine.quoteUpgrade(u.id, const BuyAmount.fixed(1));
        if (!q.canBuy) continue;
        final trial = _copy()..buyUpgrade(u.id, const BuyAmount.fixed(1));
        final gain = _effective(trial) - base;
        final ratio = gain / math.max(q.cost.toDouble(), 1e-9);
        if (best == null || ratio > best.ratio) best = (ratio: ratio, upgrade: true, id: u.id);
      }
      for (final tr in content.trainers) {
        final q = engine.quoteTrainer(tr.id, const BuyAmount.fixed(1));
        if (!q.canBuy) continue;
        final trial = _copy()..buyTrainer(tr.id, const BuyAmount.fixed(1));
        final gain = _effective(trial) - base;
        final ratio = gain / math.max(q.cost.toDouble(), 1e-9);
        if (best == null || ratio > best.ratio) best = (ratio: ratio, upgrade: false, id: tr.id);
      }
      if (best == null) break;
      if (best.upgrade) {
        engine.buyUpgrade(best.id, const BuyAmount.fixed(1));
      } else {
        engine.buyTrainer(best.id, const BuyAmount.fixed(1));
        firstTrainerMinute ??= t / 60;
      }
      buyMinutes.add(t / 60);
      _logBuy(best.id);
    }
    // Skills: learn or level up when it costs a small part of the coins.
    for (final s in content.skills) {
      final q = engine.quoteSkill(s.id);
      if (q.canBuy && q.cost.toDouble() <= engine.state.coins.toDouble() * 0.25) {
        engine.buySkill(s.id);
        buyMinutes.add(t / 60);
        firstSkillMinute ??= t / 60;
        _logBuy(s.id);
      }
    }
  }

  final Map<String, int> _bought = {};

  /// Keeps the first few purchases of each item, to describe the early game.
  void _logBuy(String id) {
    final n = (_bought[id] = (_bought[id] ?? 0) + 1);
    if (n <= 3 || n == 10) buyLog.add('${(t / 60).toStringAsFixed(2)} min  $id #$n');
  }

  void _useSkills() {
    for (final s in content.skills) {
      if (engine.state.skillLevel(s.id) == 0) continue;
      if (engine.state.skillCooldownLeft(s.id) > 0) continue;
      if (s.effect == SkillEffect.bossTimerExtend && engine.state.bossTimeLeft == null) continue;
      if (s.effect == SkillEffect.bossTimerExtend && engine.state.bossTimeLeft! > 10) continue;
      engine.useSkill(s.id);
    }
  }

  void _spendBelts() {
    for (var guard = 0; guard < 100; guard++) {
      TalentDef? pick;
      var cost = double.infinity;
      for (final talent in content.talents) {
        final q = engine.quoteTalent(talent.id);
        if (q.canBuy && q.cost.toDouble() < cost) {
          pick = talent;
          cost = q.cost.toDouble();
        }
      }
      if (pick == null) return;
      engine.buyTalent(pick.id);
    }
  }

  void _equipBestMask() {
    for (final m in content.masks) {
      if (!engine.ownsMask(m.id)) engine.buyMask(m.id);
    }
    MaskDef? best;
    for (final m in content.masks) {
      if (!engine.ownsMask(m.id)) continue;
      final score = m.bonusType == MaskBonusType.tapDamageMultiplier ||
              m.bonusType == MaskBonusType.trainerDamageMultiplier
          ? m.bonusValue
          : m.bonusValue * 0.5;
      if (best == null ||
          score > (best.bonusType == MaskBonusType.tapDamageMultiplier ||
                  best.bonusType == MaskBonusType.trainerDamageMultiplier
              ? best.bonusValue
              : best.bonusValue * 0.5)) {
        best = m;
      }
    }
    if (best != null && engine.state.equippedMask != best.id) engine.equipMask(best.id);
  }

  void _maybeChallengeBoss() {
    if (engine.awaitingBossLossAck) {
      engine.acknowledgeBossLoss();
      return;
    }
    if (engine.awaitingBossStart) {
      // The first time the boss comes by itself: take it or go back to farm.
      final expected = _effective(engine) * engine.bossTimerLength * 1.05;
      if (expected >= engine.enemyMaxHp.toDouble() * 1.1) {
        engine.startBoss();
        _log('jefe: reto');
      } else {
        engine.abandonBoss();
      }
      return;
    }
    if (!engine.bossGateReady) return;
    final trial = _copy();
    trial.challengeBoss();
    final hp = trial.enemyMaxHp.toDouble();
    final seconds = trial.bossTimerLength;
    // Expected damage in the time limit, counting skill bursts as a bonus.
    final expected = _effective(engine) * seconds * 1.05;
    if (expected >= hp * 1.1) {
      engine.challengeBoss();
      engine.startBoss();
      _log('jefe: reto');
    }
  }

  void _maybePrestige() {
    if (!engine.prestigePreview().canPrestige) return;
    final stalled = (t - _lastProgressAt) >= profile.stallMinutesBeforePrestige * 60;
    if (!stalled) return;
    _log('prestige');
    engine.prestige();
    _prestiges++;
    _runBestFight = 1;
    _lastProgressAt = t;
  }
}
