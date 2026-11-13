import 'dart:math' as math;

import '../data/balance.dart';
import '../data/content_bundle.dart';
import '../data/content_models.dart';
import 'big.dart';
import 'buy_amount.dart';
import 'formulas.dart';
import 'game_state.dart';
import 'rng.dart';

/// Result of dealing damage (a tap, a finisher, a skill or an idle tick).
class DamageOutcome {
  const DamageOutcome({
    required this.damageDealt,
    required this.defeats,
    required this.coinsEarned,
    this.isCrit = false,
    this.bossTimedOut = false,
    this.luckySpawned = false,
  });

  static const none = DamageOutcome(
    damageDealt: Big.zero,
    defeats: 0,
    coinsEarned: Big.zero,
  );

  /// Damage that was applied (a tap's damage, or the idle damage of a tick).
  final Big damageDealt;

  /// Opponents defeated by this damage.
  final int defeats;
  final Big coinsEarned;
  final bool isCrit;

  /// The boss countdown ran out and the player dropped back one fight.
  final bool bossTimedOut;

  /// A lucky pickup appeared during this tick.
  final bool luckySpawned;

  DamageOutcome operator +(DamageOutcome other) => DamageOutcome(
    damageDealt: damageDealt + other.damageDealt,
    defeats: defeats + other.defeats,
    coinsEarned: coinsEarned + other.coinsEarned,
    isCrit: isCrit || other.isCrit,
    bossTimedOut: bossTimedOut || other.bossTimedOut,
    luckySpawned: luckySpawned || other.luckySpawned,
  );
}

enum BuyFailure {
  unknownItem,
  locked,
  notEnoughCoins,
  notEnoughBelts,
  maxed,
  alreadyOwned,
  notPurchasable,
}

/// What a purchase would do (or did), for the button label and the result.
class BuyQuote {
  const BuyQuote({
    required this.count,
    required this.cost,
    required this.failure,
  });

  /// Levels bought. For MAX with nothing affordable this is 1 so the button
  /// can show the price of the next level.
  final int count;
  final Big cost;

  /// Null when the purchase can go ahead.
  final BuyFailure? failure;

  bool get canBuy => failure == null;
}

enum SkillFailure { unknown, notLearned, cooldown, noBoss, waitingBoss }

class SkillUseResult {
  const SkillUseResult({this.failure, this.outcome = DamageOutcome.none});

  final SkillFailure? failure;
  final DamageOutcome outcome;

  bool get ok => failure == null;
}

/// What Change Mask would do right now.
class PrestigePreview {
  const PrestigePreview({required this.beltsToEarn, required this.canPrestige});

  final Big beltsToEarn;
  final bool canPrestige;
}

/// All game rules, deterministic and free of Flutter. The UI calls the action
/// methods; it never changes [state] directly.
class GameEngine {
  GameEngine({required this.content, GameState? state, SeededRng? rng})
    : formulas = Formulas(content.balance),
      rng = rng ?? SeededRng(_defaultSeed) {
    _state = state ?? _initialState();
  }

  /// Seed of a brand new game; a loaded save restores its own generator state.
  static const int _defaultSeed = 0x5EED5EED;

  final ContentBundle content;
  final Formulas formulas;
  final SeededRng rng;
  late GameState _state;

  GameState get state => _state;

  Balance get _balance => content.balance;

  GameState _initialState() {
    final fight = _balance.startFightNumber;
    final starters = [
      for (final m in content.masks)
        if (m.unlockRule == MaskUnlockRule.starter) m.id,
    ];
    return GameState(
      coins: Big.fromDouble(_balance.startCoins),
      totalCoinsEarned: Big.zero,
      fightNumber: fight,
      enemyHp: _maxHpOf(fight),
      ownedMasks: starters.toSet(),
      equippedMask: starters.first,
      bestFight: fight,
    );
  }

  // ---------------------------------------------------------------------------
  // Current fight

  FightInfo get fightInfo => content.fightInfo(_state.fightNumber);
  OpponentDef get opponent => fightInfo.opponent;
  bool get isBossFight => fightInfo.isBoss;

  /// True while a boss fight is showing its intro: the countdown has not
  /// started, so nothing is damaged until [startBoss].
  bool get awaitingBossStart => isBossFight && _state.bossTimeLeft == null;

  /// "¡A PELEAR!": starts the boss countdown.
  void startBoss() {
    if (!awaitingBossStart) return;
    _state = _state.copyWith(bossTimeLeft: _bossSeconds(fightInfo));
  }

  /// True when [fight] is the last regular fight before a boss. The game holds
  /// the player there, farming coins, until they choose to challenge the boss.
  bool _isGate(int fight) =>
      !content.fightInfo(fight).isBoss && content.fightInfo(fight + 1).isBoss;

  /// The player stands in the fight before a boss and may challenge it.
  bool get bossGateReady => _holdsGate(_state.fightNumber);

  /// The gate holds the player (farming) only after they have met the boss
  /// once. The first time, beating the gate fight leads straight into the boss.
  bool _holdsGate(int fight) => _isGate(fight) && _state.bestFight > fight;

  /// The boss countdown ran out and the player lies defeated until
  /// [acknowledgeBossLoss] (the UI shows its tip meanwhile).
  bool get awaitingBossLossAck => _bossLossPending;
  bool _bossLossPending = false;

  /// The boss that was just beaten while the player has not pressed
  /// "Continuar" on the victory screen; nothing is damaged meanwhile.
  OpponentDef? get bossWinOpponent => _bossWin;
  OpponentDef? _bossWin;

  /// The fight is paused by a result screen (victory or defeat).
  bool get _blocked => _bossLossPending || _bossWin != null;

  /// "Continuar" on the victory screen.
  bool acknowledgeBossWin() {
    if (_bossWin == null) return false;
    _bossWin = null;
    return true;
  }

  /// "Aceptar" on the defeat tip: back to the farming fight, no other penalty.
  bool acknowledgeBossLoss() {
    if (!_bossLossPending) return false;
    _bossLossPending = false;
    final previous = math.max(1, _state.fightNumber - 1);
    _state = _state.copyWith(
      fightNumber: previous,
      enemyHp: _maxHpOf(previous),
      clearBossTimer: true,
    );
    return true;
  }

  /// "Jefe": leaves the farming fight for the boss fight (its intro shows, the
  /// countdown waits for [startBoss]). False when no boss is waiting.
  bool challengeBoss() {
    if (!bossGateReady) return false;
    final boss = _state.fightNumber + 1;
    _state = _state.copyWith(
      fightNumber: boss,
      enemyHp: _maxHpOf(boss),
      bestFight: math.max(_state.bestFight, boss),
      clearBossTimer: true,
    );
    return true;
  }

  /// "Volver" on the boss intro: back to the farming fight before the boss.
  bool abandonBoss() {
    if (!awaitingBossStart) return false;
    final gate = _state.fightNumber - 1;
    _state = _state.copyWith(
      fightNumber: gate,
      enemyHp: _maxHpOf(gate),
      clearBossTimer: true,
    );
    return true;
  }

  Big get enemyMaxHp => _maxHpOf(_state.fightNumber);

  Big _maxHpOf(int fight) {
    final info = content.fightInfo(fight);
    final o = info.opponent;
    var hp = formulas.opponentHp(
      fight,
      isBoss: info.isBoss,
      hpMultiplier: o.hpMultiplier,
    );
    if (info.loops > 0) {
      hp = hp * Big.powOf(info.league.loopScale, info.loops);
    }
    return hp;
  }

  /// Length of the current boss fight's countdown, in seconds.
  double get bossTimerLength => _bossSeconds(fightInfo);

  /// Boss countdown length for [info]'s opponent.
  double _bossSeconds(FightInfo info) =>
      info.opponent.bossTimerSeconds ?? _balance.bossTimerSeconds;

  // ---------------------------------------------------------------------------
  // Derived values (talents, masks, belts, skills)

  double _talentSum(TalentEffect effect) {
    var total = 0.0;
    for (final t in content.talents) {
      if (t.effect == effect) {
        total += t.valuePerLevel * _state.talentLevel(t.id);
      }
    }
    return total;
  }

  MaskDef? get equippedMaskDef {
    final id = _state.equippedMask;
    return id == null ? null : content.mask(id);
  }

  double _maskBonus(MaskBonusType type) {
    final mask = equippedMaskDef;
    return mask != null && mask.bonusType == type ? mask.bonusValue : 0;
  }

  /// Permanent damage factor from Belts earned: 1 + bonus * lifetime belts.
  Big get beltMultiplier =>
      Big.one +
      _state.lifetimeBelts.mulDouble(_balance.prestige.beltDamageBonus);

  /// Value of the active skill with [effect], or null when none is active.
  double? _activeSkillValue(SkillEffect effect) {
    for (final s in content.skills) {
      if (s.effect == effect && _state.skillActiveLeft(s.id) > 0) {
        return s.valueAt(math.max(1, _state.skillLevel(s.id)));
      }
    }
    return null;
  }

  /// Damage of one regular tap, before a critical hit.
  Big get tapDamage {
    var base = Big.fromDouble(_balance.baseTapDamage);
    for (final u in content.upgrades) {
      if (u.effect == UpgradeEffect.tapDamage) {
        final level = _state.upgradeLevel(u.id);
        if (level > 0) {
          base +=
              Big.fromDouble(level * u.perLevelValue) *
              _balance.milestones.factorAt(level);
        }
      }
    }
    final factor =
        (1 + _talentSum(TalentEffect.tapDamageMultiplier)) *
        (1 + _maskBonus(MaskBonusType.tapDamageMultiplier)) *
        (_activeSkillValue(SkillEffect.tapMultiplier) ?? 1);
    return base.mulDouble(factor) * beltMultiplier;
  }

  /// Chance (0 to 1) that a tap is a critical hit.
  double get critChance {
    var chance = _talentSum(TalentEffect.critChance);
    for (final u in content.upgrades) {
      if (u.effect == UpgradeEffect.critChance) {
        chance += _state.upgradeLevel(u.id) * u.perLevelValue;
      }
    }
    return math.min(chance, _balance.crit.maxChance);
  }

  /// Idle damage per second from all hired trainers. With [withSkills] false
  /// the active skills do not count (they pause while the app is closed).
  /// [withCombo] counts the trainers whose damage grows with the combo bar
  /// (it is live only while the app is open, like the skills).
  Big damagePerSecondOf({required bool withSkills, bool? withCombo}) {
    final useCombo = withCombo ?? withSkills;
    var total = Big.zero;
    for (final trainer in content.trainers) {
      final level = _state.trainerLevel(trainer.id);
      if (level > 0) {
        var own =
            Big.fromDouble(trainer.baseDps).mulDouble(level.toDouble()) *
            _balance.milestones.factorAt(level);
        final special = trainer.special;
        if (useCombo && special?.type == TrainerSpecialType.comboDamage) {
          own = own.mulDouble(1 + special!.bonus * _state.comboMeter);
        }
        total += own;
      }
    }
    if (total.isZero) return total;
    final factor =
        (1 + _talentSum(TalentEffect.trainerDamageMultiplier)) *
        (1 + _maskBonus(MaskBonusType.trainerDamageMultiplier)) *
        (withSkills
            ? (_activeSkillValue(SkillEffect.trainerMultiplier) ?? 1)
            : 1);
    return total.mulDouble(factor) * beltMultiplier;
  }

  Big get damagePerSecond => damagePerSecondOf(withSkills: true);

  /// Product of the permanent coin multipliers of owned store purchases.
  double get _purchaseCoinMultiplier {
    var factor = 1.0;
    for (final id in _state.purchases) {
      for (final item in content.shopItems) {
        if (item.id == id) factor *= item.coinMultiplier;
      }
    }
    return factor;
  }

  /// Coin factor from the trainers with a coin special: the sum of the
  /// per-level bonuses, times the flat multipliers of those hired.
  double get _trainerCoinMultiplier {
    var bonus = 0.0;
    var factor = 1.0;
    for (final trainer in content.trainers) {
      final special = trainer.special;
      final level = _state.trainerLevel(trainer.id);
      if (special == null || level <= 0) continue;
      if (special.type == TrainerSpecialType.coinGain) {
        bonus += special.bonusAt(level);
      } else if (special.type == TrainerSpecialType.coinMultiplier) {
        factor *= special.multiplier;
      }
    }
    return (1 + bonus) * factor;
  }

  /// Share of the skills' cooldown the trainers take off.
  double get _trainerCooldownReduction {
    var bonus = 0.0;
    for (final trainer in content.trainers) {
      final special = trainer.special;
      if (special?.type == TrainerSpecialType.skillCooldown) {
        bonus += special!.bonusAt(_state.trainerLevel(trainer.id));
      }
    }
    return bonus;
  }

  double get coinMultiplier =>
      _trainerCoinMultiplier *
      (1 + _talentSum(TalentEffect.coinGainMultiplier)) *
      (1 + _maskBonus(MaskBonusType.coinGainMultiplier)) *
      _purchaseCoinMultiplier *
      (_state.boostLeft > 0 ? _state.boostMultiplier : 1);

  Big _rewardOf(int fight) {
    final info = content.fightInfo(fight);
    var reward = formulas
        .coinsReward(
          fight,
          isBoss: info.isBoss,
          coinMultiplier: info.opponent.coinMultiplier,
        )
        .mulDouble(coinMultiplier);
    if (info.isBoss) {
      reward = reward.mulDouble(
        1 + _maskBonus(MaskBonusType.bossCoinMultiplier),
      );
    }
    return reward;
  }

  /// Coins paid by the current fight, as shown to the player.
  Big get currentReward => _rewardOf(_state.fightNumber);

  // ---------------------------------------------------------------------------
  // Tap, finisher, tick

  /// One tap. Applied immediately, not on the tick. Damage beyond the current
  /// opponent's HP is not carried over to the next one.
  DamageOutcome tap() {
    if (awaitingBossStart || _blocked) return DamageOutcome.none;
    final chance = critChance;
    final isCrit = chance > 0 && rng.nextDouble() < chance;
    var damage = tapDamage;
    if (isCrit) damage = damage.mulDouble(_balance.crit.multiplier);

    final combo = _balance.combo;
    var meter = _state.comboMeter + combo.fillPerTap;
    // Ten taps of 0.1 add up to 0.9999999999999999: treat that as full.
    if (meter > 1 - _meterEpsilon) meter = 1;
    _state = _state.copyWith(
      comboMeter: meter,
      secondsSinceTap: 0,
      stats: _bump(_state.stats, 'taps', 1),
    );
    final outcome = _applyDamage(damage, carryOver: false);
    _awardAchievements();
    return DamageOutcome(
      damageDealt: damage,
      defeats: outcome.defeats,
      coinsEarned: outcome.coinsEarned,
      isCrit: isCrit,
    );
  }

  /// Floating point slack when deciding that the combo meter is full.
  static const double _meterEpsilon = 1e-9;

  bool get finisherReady => _state.comboMeter >= 1;

  /// The finisher ("GOLPE"): one large hit, then the meter resets. Null when
  /// the meter is not full.
  DamageOutcome? finisher() {
    if (!finisherReady || awaitingBossStart || _blocked) return null;
    final damage = tapDamage.mulDouble(_balance.combo.finisherMultiplier);
    _state = _state.copyWith(
      comboMeter: 0,
      stats: _bump(_state.stats, 'finishers', 1),
    );
    final outcome = _applyDamage(damage, carryOver: false);
    _awardAchievements();
    return DamageOutcome(
      damageDealt: damage,
      defeats: outcome.defeats,
      coinsEarned: outcome.coinsEarned,
    );
  }

  /// The finisher gesture failed: the combo starts over.
  void failFinisher() {
    _state = _state.copyWith(comboMeter: 0, secondsSinceTap: 0);
  }

  /// One fixed simulation step of `1 / ticksPerSecond` seconds: idle damage,
  /// boss countdown, combo decay, skill timers and lucky events.
  DamageOutcome tick() {
    // The boss intro is showing: the fight has not begun.
    if (awaitingBossStart || _blocked) return DamageOutcome.none;
    final dt = 1 / _balance.ticksPerSecond;
    var outcome = DamageOutcome.none;

    final dps = damagePerSecond;
    if (!dps.isZero) {
      final damage = dps.divDouble(_balance.ticksPerSecond.toDouble());
      final dealt = _applyDamage(damage, carryOver: true);
      outcome =
          outcome +
          DamageOutcome(
            damageDealt: damage,
            defeats: dealt.defeats,
            coinsEarned: dealt.coinsEarned,
          );
    }

    final timedOut = _tickBossTimer(dt);
    _tickCombo(dt);
    _tickSkills(dt);
    _tickBoost(dt);
    final spawned = _tickLucky(dt);
    if (defeatsHappened(outcome)) _awardAchievements();

    return outcome +
        DamageOutcome(
          damageDealt: Big.zero,
          defeats: 0,
          coinsEarned: Big.zero,
          bossTimedOut: timedOut,
          luckySpawned: spawned,
        );
  }

  bool defeatsHappened(DamageOutcome o) => o.defeats > 0;

  bool _tickBossTimer(double dt) {
    if (!isBossFight) {
      if (_state.bossTimeLeft != null) {
        _state = _state.copyWith(clearBossTimer: true);
      }
      return false;
    }
    final left = _state.bossTimeLeft;
    if (left == null) return false; // waiting for startBoss
    final remaining = left - dt;
    if (remaining > 0) {
      _state = _state.copyWith(bossTimeLeft: remaining);
      return false;
    }
    // Time is up: the player lies defeated until the loss is acknowledged.
    _bossLossPending = true;
    _state = _state.copyWith(bossTimeLeft: 0);
    return true;
  }

  void _tickCombo(double dt) {
    final since = _state.secondsSinceTap + dt;
    var meter = _state.comboMeter;
    // A full meter waits for the finisher gesture; it does not decay.
    if (meter < 1 && since > _balance.combo.holdSeconds) {
      meter = math.max(0, meter - _balance.combo.decayPerSecond * dt);
    }
    _state = _state.copyWith(comboMeter: meter, secondsSinceTap: since);
  }

  void _tickSkills(double dt) {
    if (_state.skillCooldowns.isEmpty && _state.skillActive.isEmpty) return;
    Map<String, double> advance(Map<String, double> timers) => {
      for (final e in timers.entries)
        if (e.value - dt > 0) e.key: e.value - dt,
    };
    _state = _state.copyWith(
      skillCooldowns: advance(_state.skillCooldowns),
      skillActive: advance(_state.skillActive),
    );
  }

  void _tickBoost(double dt) {
    if (_state.boostLeft <= 0) return;
    final left = _state.boostLeft - dt;
    _state = left > 0
        ? _state.copyWith(boostLeft: left)
        : _state.copyWith(boostLeft: 0, boostMultiplier: 1);
  }

  bool _tickLucky(double dt) {
    final current = _state.lucky;
    if (current != null) {
      final left = current.lifeLeft - dt;
      _state = left > 0
          ? _state.copyWith(lucky: current.withLife(left))
          : _state.copyWith(clearLucky: true);
      return false;
    }
    final lucky = _balance.lucky;
    if (lucky.spawnPerSecond <= 0) return false;
    final rate =
        lucky.spawnPerSecond *
        (1 + _talentSum(TalentEffect.luckyRateMultiplier)) *
        (_activeSkillValue(SkillEffect.luckBoost) ?? 1);
    if (rng.nextDouble() >= rate * dt) return false;
    _state = _state.copyWith(
      lucky: LuckyEvent(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        lifeLeft: lucky.lifetimeSeconds,
      ),
    );
    return true;
  }

  /// Collects the lucky pickup on screen. Returns the coins won, or null when
  /// there was nothing to collect.
  Big? collectLucky() {
    if (_state.lucky == null) return null;
    final reward = _rewardOf(_state.fightNumber)
        .mulDouble(_balance.lucky.rewardCoinMultiple);
    _state = _state.copyWith(
      coins: _state.coins + reward,
      totalCoinsEarned: _state.totalCoinsEarned + reward,
      clearLucky: true,
    );
    return reward;
  }

  // ---------------------------------------------------------------------------
  // Damage and fights

  DamageOutcome _applyDamage(Big damage, {required bool carryOver}) {
    var remaining = damage;
    var fight = _state.fightNumber;
    var hp = _state.enemyHp;
    var coins = _state.coins;
    var total = _state.totalCoinsEarned;
    var earned = Big.zero;
    var defeats = 0;
    var bosses = 0;
    OpponentDef? bossBeaten;
    final maxDefeats = _balance.maxFightsPerTick;

    while (!remaining.isZero) {
      if (remaining < hp) {
        hp = hp - remaining;
        break;
      }
      remaining = remaining - hp;
      final reward = _rewardOf(fight);
      coins += reward;
      total += reward;
      earned += reward;
      defeats++;
      if (content.fightInfo(fight).isBoss) {
        bosses++;
        bossBeaten = content.fightInfo(fight).opponent;
      }
      // Before a boss the player keeps farming the same fight until they
      // choose to challenge the boss.
      if (!_holdsGate(fight)) fight++;
      hp = _maxHpOf(fight);
      // A boss waits for its intro: no damage carries into it.
      if (!carryOver || defeats >= maxDefeats || content.fightInfo(fight).isBoss) {
        break;
      }
    }

    var stats = _state.stats;
    if (defeats > 0) stats = _bump(stats, 'defeats', defeats);
    if (bosses > 0) stats = _bump(stats, 'bosses', bosses);
    if (bossBeaten != null) _bossWin = bossBeaten;
    _state = _state.copyWith(
      coins: coins,
      totalCoinsEarned: total,
      fightNumber: fight,
      enemyHp: hp,
      stats: stats,
      bestFight: math.max(_state.bestFight, fight),
      clearBossTimer: defeats > 0,
    );
    if (defeats > 0) _unlockLeagueMasks();
    return DamageOutcome(
      damageDealt: damage,
      defeats: defeats,
      coinsEarned: earned,
    );
  }

  Map<String, int> _bump(Map<String, int> stats, String key, int by) => {
    ...stats,
    key: (stats[key] ?? 0) + by,
  };

  void _unlockLeagueMasks() {
    var owned = _state.ownedMasks;
    for (final m in content.masks) {
      if (m.unlockRule != MaskUnlockRule.league || owned.contains(m.id)) {
        continue;
      }
      if (_state.bestFight > content.leagueEndFight(m.unlockValue.toInt())) {
        owned = {...owned, m.id};
      }
    }
    if (owned != _state.ownedMasks) _state = _state.copyWith(ownedMasks: owned);
  }

  void _awardAchievements() {
    var done = _state.achievements;
    var belts = _state.belts;
    var lifetime = _state.lifetimeBelts;
    for (final a in content.achievements) {
      if (done.contains(a.id)) continue;
      if (_state.stat(a.counter.name) < a.target) continue;
      done = {...done, a.id};
      final reward = Big.fromInt(a.rewardBelts);
      belts += reward;
      lifetime += reward;
    }
    if (done != _state.achievements) {
      _state = _state.copyWith(
        achievements: done,
        belts: belts,
        lifetimeBelts: lifetime,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Upgrades and trainers

  bool isTrainerUnlocked(TrainerDef trainer) =>
      _state.fightNumber >= trainer.unlockFight;

  /// Price and feasibility of buying [amount] levels of upgrade [id].
  BuyQuote quoteUpgrade(String id, BuyAmount amount) {
    final def = _findUpgrade(id);
    if (def == null) return _failed(BuyFailure.unknownItem);
    return _quote(
      def.baseCost,
      _state.upgradeLevel(id),
      amount,
      unlocked: true,
    );
  }

  /// Price and feasibility of buying [amount] levels of trainer [id].
  BuyQuote quoteTrainer(String id, BuyAmount amount) {
    final def = _findTrainer(id);
    if (def == null) return _failed(BuyFailure.unknownItem);
    return _quote(
      def.baseCost,
      _state.trainerLevel(id),
      amount,
      unlocked: isTrainerUnlocked(def),
    );
  }

  BuyQuote buyUpgrade(String id, BuyAmount amount) {
    final quote = quoteUpgrade(id, amount);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      coins: _state.coins - quote.cost,
      upgradeLevels: {
        ..._state.upgradeLevels,
        id: _state.upgradeLevel(id) + quote.count,
      },
    );
    return quote;
  }

  BuyQuote buyTrainer(String id, BuyAmount amount) {
    final quote = quoteTrainer(id, amount);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      coins: _state.coins - quote.cost,
      trainerLevels: {
        ..._state.trainerLevels,
        id: _state.trainerLevel(id) + quote.count,
      },
    );
    return quote;
  }

  BuyQuote _failed(BuyFailure failure) =>
      BuyQuote(count: 0, cost: Big.zero, failure: failure);

  BuyQuote _quote(
    double baseCost,
    int owned,
    BuyAmount amount, {
    required bool unlocked,
  }) {
    final int count;
    if (amount.isMax) {
      final affordable = formulas.maxAffordable(_state.coins, baseCost, owned);
      count = affordable == 0 ? 1 : affordable;
    } else {
      count = amount.count!;
    }
    final cost = formulas.purchaseCost(baseCost, owned, count);
    final BuyFailure? failure;
    if (!unlocked) {
      failure = BuyFailure.locked;
    } else if (cost > _state.coins) {
      failure = BuyFailure.notEnoughCoins;
    } else {
      failure = null;
    }
    return BuyQuote(count: count, cost: cost, failure: failure);
  }

  UpgradeDef? _findUpgrade(String id) {
    for (final u in content.upgrades) {
      if (u.id == id) return u;
    }
    return null;
  }

  TrainerDef? _findTrainer(String id) {
    for (final t in content.trainers) {
      if (t.id == id) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Skills

  bool isSkillUnlocked(SkillDef skill) =>
      _state.fightNumber >= skill.unlockFight;

  /// Cost and feasibility of learning or levelling up skill [id] (coins).
  BuyQuote quoteSkill(String id) {
    final def = _findSkill(id);
    if (def == null) return _failed(BuyFailure.unknownItem);
    final level = _state.skillLevel(id);
    final cost = formulas.purchaseCost(def.baseCost, level, 1);
    final BuyFailure? failure;
    if (level >= def.maxLevel) {
      failure = BuyFailure.maxed;
    } else if (level == 0 && !isSkillUnlocked(def)) {
      failure = BuyFailure.locked;
    } else if (cost > _state.coins) {
      failure = BuyFailure.notEnoughCoins;
    } else {
      failure = null;
    }
    return BuyQuote(count: 1, cost: cost, failure: failure);
  }

  BuyQuote buySkill(String id) {
    final quote = quoteSkill(id);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      coins: _state.coins - quote.cost,
      skillLevels: {..._state.skillLevels, id: _state.skillLevel(id) + 1},
    );
    return quote;
  }

  /// Cooldown of [skill] after talent reductions, in seconds.
  double cooldownOf(SkillDef skill) {
    final reduction = math.min(
      _talentSum(TalentEffect.skillCooldownReduction) +
          _trainerCooldownReduction,
      _balance.skillCooldownReductionCap,
    );
    return skill.cooldown * (1 - reduction);
  }

  SkillUseResult useSkill(String id) {
    final def = _findSkill(id);
    if (def == null) return const SkillUseResult(failure: SkillFailure.unknown);
    final level = _state.skillLevel(id);
    if (level == 0) {
      return const SkillUseResult(failure: SkillFailure.notLearned);
    }
    if (awaitingBossStart || _blocked) {
      return const SkillUseResult(failure: SkillFailure.waitingBoss);
    }
    if (_state.skillCooldownLeft(id) > 0) {
      return const SkillUseResult(failure: SkillFailure.cooldown);
    }
    final value = def.valueAt(level);
    var outcome = DamageOutcome.none;
    switch (def.effect) {
      case SkillEffect.burst:
        final damage = tapDamage.mulDouble(value);
        final dealt = _applyDamage(damage, carryOver: false);
        outcome = DamageOutcome(
          damageDealt: damage,
          defeats: dealt.defeats,
          coinsEarned: dealt.coinsEarned,
        );
        _awardAchievements();
      case SkillEffect.bossTimerExtend:
        final left = _state.bossTimeLeft;
        if (left == null) {
          return const SkillUseResult(failure: SkillFailure.noBoss);
        }
        _state = _state.copyWith(bossTimeLeft: left + value);
      case SkillEffect.tapMultiplier:
      case SkillEffect.luckBoost:
      case SkillEffect.trainerMultiplier:
        _state = _state.copyWith(
          skillActive: {..._state.skillActive, id: def.duration},
        );
    }
    _state = _state.copyWith(
      skillCooldowns: {..._state.skillCooldowns, id: cooldownOf(def)},
    );
    return SkillUseResult(outcome: outcome);
  }

  SkillDef? _findSkill(String id) {
    for (final s in content.skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Talents

  /// Cost (Belts) and feasibility of the next level of talent [id].
  BuyQuote quoteTalent(String id) {
    final TalentDef def;
    try {
      def = content.talent(id);
    } on ArgumentError {
      return _failed(BuyFailure.unknownItem);
    }
    final level = _state.talentLevel(id);
    if (level >= def.maxLevel) {
      return const BuyQuote(
        count: 0,
        cost: Big.zero,
        failure: BuyFailure.maxed,
      );
    }
    final cost = Big.fromDouble(def.costs[level]);
    final parent = def.parent;
    final BuyFailure? failure;
    if (parent != null && _state.talentLevel(parent) == 0) {
      failure = BuyFailure.locked;
    } else if (cost > _state.belts) {
      failure = BuyFailure.notEnoughBelts;
    } else {
      failure = null;
    }
    return BuyQuote(count: 1, cost: cost, failure: failure);
  }

  BuyQuote buyTalent(String id) {
    final quote = quoteTalent(id);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      belts: _state.belts - quote.cost,
      talentLevels: {..._state.talentLevels, id: _state.talentLevel(id) + 1},
    );
    return quote;
  }

  // ---------------------------------------------------------------------------
  // Masks

  bool ownsMask(String id) => _state.ownedMasks.contains(id);

  /// Belt price and feasibility of buying mask [id] (belts rule only).
  BuyQuote quoteMask(String id) {
    final MaskDef def;
    try {
      def = content.mask(id);
    } on ArgumentError {
      return _failed(BuyFailure.unknownItem);
    }
    if (ownsMask(id)) {
      return const BuyQuote(
        count: 0,
        cost: Big.zero,
        failure: BuyFailure.alreadyOwned,
      );
    }
    if (def.unlockRule != MaskUnlockRule.belts) {
      return const BuyQuote(
        count: 0,
        cost: Big.zero,
        failure: BuyFailure.notPurchasable,
      );
    }
    final cost = Big.fromDouble(def.unlockValue);
    return BuyQuote(
      count: 1,
      cost: cost,
      failure: cost > _state.belts ? BuyFailure.notEnoughBelts : null,
    );
  }

  BuyQuote buyMask(String id) {
    final quote = quoteMask(id);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      belts: _state.belts - quote.cost,
      ownedMasks: {..._state.ownedMasks, id},
    );
    return quote;
  }

  /// Gives mask [id] to the player (store purchase, debug).
  void grantMask(String id) {
    content.mask(id); // throws on an unknown id
    _state = _state.copyWith(ownedMasks: {..._state.ownedMasks, id});
  }

  /// Equips an owned mask. Returns false if it is not owned.
  bool equipMask(String id) {
    if (!ownsMask(id)) return false;
    _state = _state.copyWith(equippedMask: id);
    return true;
  }

  /// Records a store purchase (for example "mas_descanso").
  void grantPurchase(String id) {
    content.shopItem(id); // throws on an unknown id
    _state = _state.copyWith(purchases: {..._state.purchases, id});
  }

  bool ownsPurchase(String id) => _state.purchases.contains(id);

  /// Adds the Belts of a belt pack bought with real money. They can be spent
  /// but do not count as earned Belts for the permanent damage bonus.
  void grantBeltPack(String id) {
    final item = content.shopItem(id);
    _state = _state.copyWith(belts: _state.belts + Big.fromInt(item.belts));
  }

  /// Seconds until the rewarded-ad offer [id] can be used again (0 when ready).
  double adOfferWait(String id, int nowMs) {
    final readyAt = _state.adReadyAt[id] ?? 0;
    return readyAt > nowMs ? (readyAt - nowMs) / 1000 : 0;
  }

  /// Applies a rewarded-ad offer after the ad was watched and starts its
  /// cooldown. Returns false if it is still cooling down.
  bool claimAdOffer(String id, int nowMs) {
    final item = content.shopItem(id);
    if (adOfferWait(id, nowMs) > 0) return false;
    switch (item.kind) {
      case ShopKind.boost:
        _state = _state.copyWith(
          boostLeft: item.durationSeconds,
          boostMultiplier: item.multiplier,
        );
      case ShopKind.adBelt:
        _state = _state.copyWith(belts: _state.belts + Big.fromInt(item.belts));
      case ShopKind.purchase:
      case ShopKind.beltPack:
        return false; // paid items, not ad offers
    }
    _state = _state.copyWith(
      adReadyAt: {
        ..._state.adReadyAt,
        id: nowMs + (item.cooldownSeconds * 1000).round(),
      },
    );
    return true;
  }

  /// Starts over with a brand new game (Borrar datos).
  void resetAll() => _state = _initialState();

  // ---------------------------------------------------------------------------
  // Prestige ("Cambiar de máscara")

  PrestigePreview prestigePreview() {
    final belts = formulas.belts(_state.totalCoinsEarned);
    return PrestigePreview(
      beltsToEarn: belts,
      canPrestige: belts >= Big.fromInt(_balance.prestige.minBelts),
    );
  }

  /// Resets coins, upgrades, trainers and fights; keeps masks, talents,
  /// belts, skills and achievements; grants the belts of this run.
  /// Returns false when the run is not worth enough Belts yet.
  bool prestige() {
    final preview = prestigePreview();
    if (!preview.canPrestige) return false;
    final startCoins =
        _balance.startCoins + _talentSum(TalentEffect.startingCoins);
    final fight = _balance.startFightNumber;
    _state = _state.copyWith(
      coins: Big.fromDouble(startCoins),
      totalCoinsEarned: Big.zero,
      fightNumber: fight,
      enemyHp: _maxHpOf(fight),
      upgradeLevels: const {},
      trainerLevels: const {},
      belts: _state.belts + preview.beltsToEarn,
      lifetimeBelts: _state.lifetimeBelts + preview.beltsToEarn,
      comboMeter: 0,
      secondsSinceTap: 0,
      clearBossTimer: true,
      skillCooldowns: const {},
      skillActive: const {},
      clearLucky: true,
      stats: _bump(_state.stats, 'prestiges', 1),
    );
    _awardAchievements();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Offline progression

  /// Longest away time that counts, in hours: base cap plus the Siesta talent,
  /// the equipped mask and store purchases, never above the maximum.
  double get offlineCapHours {
    final cfg = _balance.offline;
    var hours =
        cfg.baseCapHours +
        _talentSum(TalentEffect.offlineCapHours) +
        _maskBonus(MaskBonusType.offlineCapHours);
    for (final id in _state.purchases) {
      hours += cfg.purchaseCapHours[id] ?? 0;
    }
    return math.min(hours, cfg.maxCapHours);
  }

  /// Simulates the player being away for [away]. Only idle progress counts:
  /// trainer damage against the current and following regular opponents,
  /// stopping before the next boss. Skills, combo, lucky events and boss
  /// timers do not move.
  ///
  /// The earnings wait in [GameState.pendingOffline] until
  /// [collectOffline], or are collected at once when the absence is shorter
  /// than `minPopupSeconds`. Returns the report, or null when nothing was
  /// earned. A negative [away] (clock moved back) counts as zero.
  ///
  /// Cost is bounded by the length of a league, not by the time away, so eight
  /// hours compute instantly.
  /// Largest value kept in a plain counter (defeats): far beyond any real game.
  static const double _maxCounted = 1e15;

  OfflineReport? applyOffline(Duration away) {
    final awaySeconds = away.isNegative
        ? 0.0
        : away.inMicroseconds / Duration.microsecondsPerSecond;
    if (awaySeconds <= 0) return null;
    final capSeconds = offlineCapHours * 3600;
    final applied = math.min(awaySeconds, capSeconds);

    // Away from the game the skills and the combo bar do not count.
    final dps = damagePerSecondOf(withSkills: false, withCombo: false);
    if (dps.isZero || isBossFight) return null;

    var budget = dps.mulDouble(applied);
    var fight = _state.fightNumber;
    var hp = _state.enemyHp;
    var earned = Big.zero;
    var defeats = 0;
    while (!budget.isZero && !content.fightInfo(fight).isBoss) {
      if (_holdsGate(fight)) {
        // Farming the fight before the boss: the same fight is beaten over and
        // over, so the kills are counted with a division instead of a loop.
        final maxHp = _maxHpOf(fight);
        if (budget >= hp) {
          budget = budget - hp;
          final extra = (budget / maxHp).floor();
          final kills = Big.one + extra;
          budget = budget - extra * maxHp;
          earned += _rewardOf(fight) * kills;
          final counted = kills > Big.fromDouble(_maxCounted) ? _maxCounted : kills.toDouble();
          defeats += counted.toInt();
          hp = maxHp;
        }
        hp = hp - budget;
        break;
      }
      if (budget < hp) {
        hp = hp - budget;
        break;
      }
      budget = budget - hp;
      earned += _rewardOf(fight);
      defeats++;
      fight++;
      hp = _maxHpOf(fight);
    }

    _state = _state.copyWith(
      fightNumber: fight,
      enemyHp: hp,
      stats: defeats > 0 ? _bump(_state.stats, 'defeats', defeats) : null,
      bestFight: math.max(_state.bestFight, fight),
      clearBossTimer: defeats > 0,
    );
    if (defeats > 0) {
      _unlockLeagueMasks();
      _awardAchievements();
    }
    if (earned.isZero) return null;

    final report = OfflineReport(
      awaySeconds: awaySeconds,
      appliedSeconds: applied,
      capSeconds: capSeconds,
      coinsEarned: earned,
      defeats: defeats,
    );
    if (awaySeconds >= _balance.offline.minPopupSeconds) {
      _state = _state.copyWith(pendingOffline: report);
    } else {
      _state = _state.copyWith(
        coins: _state.coins + earned,
        totalCoinsEarned: _state.totalCoinsEarned + earned,
      );
    }
    return report;
  }

  /// Pays the pending offline coins, multiplied by [multiplier] (the rewarded
  /// ad doubles them). Returns the coins paid, or null if nothing was pending.
  Big? collectOffline({double multiplier = 1}) {
    final report = _state.pendingOffline;
    if (report == null) return null;
    final paid = report.coinsEarned.mulDouble(multiplier);
    _state = _state.copyWith(
      coins: _state.coins + paid,
      totalCoinsEarned: _state.totalCoinsEarned + paid,
      clearPendingOffline: true,
    );
    return paid;
  }

  /// Fixes a state that came from a save made with different content: clamps
  /// the opponent's HP, makes sure the equipped mask is owned and starter
  /// masks are never lost.
  void repair() {
    final max = enemyMaxHp;
    var owned = _state.ownedMasks;
    for (final m in content.masks) {
      if (m.unlockRule == MaskUnlockRule.starter) owned = {...owned, m.id};
    }
    var equipped = _state.equippedMask;
    if (equipped == null || !owned.contains(equipped)) {
      equipped = content.masks.firstWhere((m) => owned.contains(m.id)).id;
    }
    _state = _state.copyWith(
      enemyHp: _state.enemyHp > max
          ? max
          : (_state.enemyHp.isZero ? max : _state.enemyHp),
      ownedMasks: owned,
      equippedMask: equipped,
    );
  }

  // ---------------------------------------------------------------------------
  /// Coins that are not earned from a fight (they do not count towards belts).
  void grantCoins(Big amount) {
    _state = _state.copyWith(coins: _state.coins + amount);
  }

  // Debug tools (reached only from the debug panel)

  void debugAddCoins(Big amount) {
    _state = _state.copyWith(
      coins: _state.coins + amount,
      totalCoinsEarned: _state.totalCoinsEarned + amount,
    );
  }

  void debugGrantBelts(int amount) {
    _state = _state.copyWith(belts: _state.belts + Big.fromInt(amount));
  }

  /// Jumps [count] fights ahead without rewards.
  void debugSkipFights(int count) =>
      _debugGoToFight(_state.fightNumber + count);

  /// Jumps to the next boss fight.
  void debugGoToBoss() {
    for (var f = _state.fightNumber + 1; f <= _state.fightNumber + 1000; f++) {
      if (content.fightInfo(f).isBoss) {
        _debugGoToFight(f);
        return;
      }
    }
  }

  void _debugGoToFight(int fight) {
    _state = _state.copyWith(
      fightNumber: fight,
      enemyHp: _maxHpOf(fight),
      bestFight: math.max(_state.bestFight, fight),
      clearBossTimer: true,
    );
    _unlockLeagueMasks();
  }
}
