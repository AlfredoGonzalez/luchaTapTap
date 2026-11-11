import '../data/content_bundle.dart';
import '../data/content_models.dart';
import 'big.dart';
import 'buy_amount.dart';
import 'formulas.dart';
import 'game_state.dart';

/// Result of dealing damage (a tap or an idle tick).
class DamageOutcome {
  const DamageOutcome({
    required this.damageDealt,
    required this.defeats,
    required this.coinsEarned,
  });

  static const none = DamageOutcome(damageDealt: Big.zero, defeats: 0, coinsEarned: Big.zero);

  /// Damage that was applied (a tap's damage, or the idle damage of a tick).
  final Big damageDealt;

  /// Opponents defeated by this damage.
  final int defeats;
  final Big coinsEarned;

  DamageOutcome operator +(DamageOutcome other) => DamageOutcome(
        damageDealt: damageDealt + other.damageDealt,
        defeats: defeats + other.defeats,
        coinsEarned: coinsEarned + other.coinsEarned,
      );
}

enum BuyFailure { unknownItem, locked, notEnoughCoins }

/// What a purchase would do (or did), for the button label and the result.
class BuyQuote {
  const BuyQuote({required this.count, required this.cost, required this.failure});

  /// Levels bought. For MAX with nothing affordable this is 1 so the button
  /// can show the price of the next level.
  final int count;
  final Big cost;

  /// Null when the purchase can go ahead.
  final BuyFailure? failure;

  bool get canBuy => failure == null;
}

/// All game rules, deterministic and free of Flutter. The UI calls [tap],
/// [tick] and the buy methods; it never changes [state] directly.
class GameEngine {
  GameEngine({required this.content, GameState? state})
      : formulas = Formulas(content.balance) {
    _state = state ?? _initialState();
  }

  final ContentBundle content;
  final Formulas formulas;
  late GameState _state;

  GameState get state => _state;

  GameState _initialState() {
    final balance = content.balance;
    final fight = balance.startFightNumber;
    return GameState(
      coins: Big.fromDouble(balance.startCoins),
      totalCoinsEarned: Big.zero,
      fightNumber: fight,
      enemyHp: _maxHpOf(fight),
    );
  }

  OpponentDef get opponent => content.opponentForFight(_state.fightNumber);

  Big get enemyMaxHp => _maxHpOf(_state.fightNumber);

  Big _maxHpOf(int fight) {
    final o = content.opponentForFight(fight);
    return formulas.opponentHp(fight, isBoss: o.isBoss, hpMultiplier: o.hpMultiplier);
  }

  Big _rewardOf(int fight) {
    final o = content.opponentForFight(fight);
    return formulas.coinsReward(fight, isBoss: o.isBoss, coinMultiplier: o.coinMultiplier);
  }

  /// Damage of one tap: base damage plus every `tapDamage` upgrade.
  Big get tapDamage {
    var total = content.balance.baseTapDamage;
    for (final upgrade in content.upgrades) {
      if (upgrade.effect == UpgradeEffect.tapDamage) {
        total += _state.upgradeLevel(upgrade.id) * upgrade.perLevelValue;
      }
    }
    return Big.fromDouble(total);
  }

  /// Idle damage per second from all hired trainers.
  Big get damagePerSecond {
    var total = Big.zero;
    for (final trainer in content.trainers) {
      final level = _state.trainerLevel(trainer.id);
      if (level > 0) total += Big.fromDouble(trainer.baseDps).mulDouble(level.toDouble());
    }
    return total;
  }

  /// One tap. Applied immediately, not on the tick. Damage beyond the current
  /// opponent's HP is not carried over to the next one.
  DamageOutcome tap() {
    final damage = tapDamage;
    final outcome = _applyDamage(damage, carryOver: false);
    return DamageOutcome(
      damageDealt: damage,
      defeats: outcome.defeats,
      coinsEarned: outcome.coinsEarned,
    );
  }

  /// One fixed simulation step: idle damage of `1 / ticksPerSecond` seconds.
  /// Leftover damage carries over, so a strong idle build can defeat several
  /// opponents in one tick (capped by `maxFightsPerTick`).
  DamageOutcome tick() {
    final dps = damagePerSecond;
    if (dps.isZero) return DamageOutcome.none;
    final damage = dps.divDouble(content.balance.ticksPerSecond.toDouble());
    final outcome = _applyDamage(damage, carryOver: true);
    return DamageOutcome(
      damageDealt: damage,
      defeats: outcome.defeats,
      coinsEarned: outcome.coinsEarned,
    );
  }

  DamageOutcome _applyDamage(Big damage, {required bool carryOver}) {
    var remaining = damage;
    var fight = _state.fightNumber;
    var hp = _state.enemyHp;
    var coins = _state.coins;
    var total = _state.totalCoinsEarned;
    var earned = Big.zero;
    var defeats = 0;
    final maxDefeats = content.balance.maxFightsPerTick;

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
      fight++;
      hp = _maxHpOf(fight);
      if (!carryOver || defeats >= maxDefeats) break;
    }

    _state = _state.copyWith(
      coins: coins,
      totalCoinsEarned: total,
      fightNumber: fight,
      enemyHp: hp,
    );
    return DamageOutcome(damageDealt: damage, defeats: defeats, coinsEarned: earned);
  }

  bool isTrainerUnlocked(TrainerDef trainer) => _state.fightNumber >= trainer.unlockFight;

  /// Price and feasibility of buying [amount] levels of upgrade [id].
  BuyQuote quoteUpgrade(String id, BuyAmount amount) {
    final def = _findUpgrade(id);
    if (def == null) return _failed(BuyFailure.unknownItem);
    return _quote(def.baseCost, _state.upgradeLevel(id), amount, unlocked: true);
  }

  /// Price and feasibility of buying [amount] levels of trainer [id].
  BuyQuote quoteTrainer(String id, BuyAmount amount) {
    final def = _findTrainer(id);
    if (def == null) return _failed(BuyFailure.unknownItem);
    return _quote(def.baseCost, _state.trainerLevel(id), amount,
        unlocked: isTrainerUnlocked(def));
  }

  BuyQuote buyUpgrade(String id, BuyAmount amount) {
    final quote = quoteUpgrade(id, amount);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      coins: _state.coins - quote.cost,
      upgradeLevels: {..._state.upgradeLevels, id: _state.upgradeLevel(id) + quote.count},
    );
    return quote;
  }

  BuyQuote buyTrainer(String id, BuyAmount amount) {
    final quote = quoteTrainer(id, amount);
    if (!quote.canBuy) return quote;
    _state = _state.copyWith(
      coins: _state.coins - quote.cost,
      trainerLevels: {..._state.trainerLevels, id: _state.trainerLevel(id) + quote.count},
    );
    return quote;
  }

  BuyQuote _failed(BuyFailure failure) =>
      BuyQuote(count: 0, cost: Big.zero, failure: failure);

  BuyQuote _quote(double baseCost, int owned, BuyAmount amount, {required bool unlocked}) {
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
}
