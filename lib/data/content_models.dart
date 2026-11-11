import '../core/palette.dart';
import 'content_exception.dart';
import 'json_reader.dart';

const int regularSpriteSize = 48;
const int bossSpriteSize = 64;

class OpponentDef {
  const OpponentDef({
    required this.id,
    required this.name,
    required this.sprite,
    required this.placeholderColor,
    required this.size,
    required this.isBoss,
    required this.hpMultiplier,
    required this.coinMultiplier,
    required this.flavor,
    this.bossTimerSeconds,
  });

  factory OpponentDef.fromReader(JsonReader r) {
    final size = r.integer('size');
    final isBoss = r.boolean('isBoss');
    final color = r.string('placeholderColor');
    final id = r.string('id');
    if (size != (isBoss ? bossSpriteSize : regularSpriteSize)) {
      throw ContentException(
          'opponents.json: "$id" has size $size but ${isBoss ? 'bosses' : 'regular opponents'} must be ${isBoss ? bossSpriteSize : regularSpriteSize}');
    }
    if (!Palette.byId.containsKey(color)) {
      throw ContentException(
          'opponents.json: "$id" placeholderColor "$color" is not in the palette');
    }
    if (Palette.maskReservedIds.contains(color)) {
      throw ContentException(
          'opponents.json: "$id" placeholderColor "$color" is reserved for masks');
    }
    return OpponentDef(
      id: id,
      name: r.string('name'),
      sprite: r.string('sprite'),
      placeholderColor: color,
      size: size,
      isBoss: isBoss,
      hpMultiplier: r.number('hpMultiplier', min: 0, minExclusive: true),
      coinMultiplier: r.number('coinMultiplier', min: 0, minExclusive: true),
      flavor: r.string('flavor'),
      bossTimerSeconds:
          r.has('bossTimerSeconds') ? r.number('bossTimerSeconds', min: 0, minExclusive: true) : null,
    );
  }

  final String id;
  final String name;

  /// Final art file key (art arrives in a later milestone).
  final String sprite;

  /// Palette id used to draw the placeholder rectangle until art exists.
  final String placeholderColor;
  final int size;
  final bool isBoss;
  final double hpMultiplier;
  final double coinMultiplier;
  final String flavor;
  final double? bossTimerSeconds;
}

class LeagueDef {
  const LeagueDef({
    required this.id,
    required this.name,
    required this.order,
    required this.opponentIds,
    required this.bossId,
    required this.loopScale,
  });

  factory LeagueDef.fromReader(JsonReader r) => LeagueDef(
        id: r.string('id'),
        name: r.string('name'),
        order: r.integer('order', min: 1),
        opponentIds: r.strings('opponentIds'),
        bossId: r.optionalString('bossId'),
        loopScale: r.number('loopScale', min: 0, minExclusive: true),
      );

  final String id;
  final String name;
  final int order;

  /// Regular opponents in fight order.
  final List<String> opponentIds;
  final String? bossId;

  /// Stat multiplier applied each time the leagues repeat (endless leagues).
  final double loopScale;
}

class TrainerDef {
  const TrainerDef({
    required this.id,
    required this.name,
    required this.portrait,
    required this.baseCost,
    required this.baseDps,
    required this.unlockFight,
  });

  factory TrainerDef.fromReader(JsonReader r) => TrainerDef(
        id: r.string('id'),
        name: r.string('name'),
        portrait: r.string('portrait'),
        baseCost: r.number('baseCost', min: 0, minExclusive: true),
        baseDps: r.number('baseDps', min: 0, minExclusive: true),
        unlockFight: r.integer('unlockFight', min: 1),
      );

  final String id;
  final String name;
  final String portrait;
  final double baseCost;

  /// Damage per second added per level.
  final double baseDps;

  /// First fight number at which the trainer can be hired.
  final int unlockFight;
}

enum UpgradeEffect {
  tapDamage,
  critChance;

  static UpgradeEffect parse(String source, String id, String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw ContentException(
        '$source: "$id" has unknown effect "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

class UpgradeDef {
  const UpgradeDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.baseCost,
    required this.effect,
    required this.perLevelValue,
  });

  factory UpgradeDef.fromReader(JsonReader r) {
    final id = r.string('id');
    return UpgradeDef(
      id: id,
      name: r.string('name'),
      icon: r.string('icon'),
      baseCost: r.number('baseCost', min: 0, minExclusive: true),
      effect: UpgradeEffect.parse('upgrades.json', id, r.string('effect')),
      perLevelValue: r.number('perLevelValue', min: 0, minExclusive: true),
    );
  }

  final String id;
  final String name;
  final String icon;
  final double baseCost;
  final UpgradeEffect effect;

  /// Amount of [effect] added per level owned.
  final double perLevelValue;
}

enum SkillEffect {
  /// Instant hit worth `value` times the tap damage.
  burst,

  /// Tap damage times `value` while active.
  tapMultiplier,

  /// Lucky-event spawn rate times `value` while active.
  luckBoost,

  /// Trainer damage times `value` while active.
  trainerMultiplier,

  /// Adds `value` seconds to the boss countdown.
  bossTimerExtend;

  static SkillEffect parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
        'skills.json: "$id" has unknown effect "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

class SkillDef {
  const SkillDef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.icon,
    required this.effect,
    required this.cooldown,
    required this.duration,
    required this.baseValue,
    required this.perLevelValue,
    required this.unlockFight,
    required this.baseCost,
    required this.maxLevel,
  });

  factory SkillDef.fromReader(JsonReader r) {
    final id = r.string('id');
    final effect = SkillEffect.parse(id, r.string('effect'));
    final duration = r.number('duration', min: 0);
    if (duration == 0 &&
        (effect == SkillEffect.tapMultiplier ||
            effect == SkillEffect.luckBoost ||
            effect == SkillEffect.trainerMultiplier)) {
      throw ContentException('skills.json: "$id" (${effect.name}) needs a duration above 0');
    }
    return SkillDef(
      id: id,
      name: r.string('name'),
      shortName: r.string('shortName'),
      icon: r.string('icon'),
      effect: effect,
      cooldown: r.number('cooldown', min: 0, minExclusive: true),
      duration: duration,
      baseValue: r.number('baseValue', min: 0, minExclusive: true),
      perLevelValue: r.number('perLevelValue', min: 0),
      unlockFight: r.integer('unlockFight', min: 1),
      baseCost: r.number('baseCost', min: 0, minExclusive: true),
      maxLevel: r.integer('maxLevel', min: 1),
    );
  }

  final String id;
  final String name;

  /// Three-letter label for the skill button until icons exist.
  final String shortName;
  final String icon;
  final SkillEffect effect;
  final double cooldown;

  /// Seconds the effect lasts (0 for instant skills).
  final double duration;
  final double baseValue;
  final double perLevelValue;
  final int unlockFight;
  final double baseCost;
  final int maxLevel;

  /// Effect value at [level] (1-based).
  double valueAt(int level) => baseValue + perLevelValue * (level - 1);
}

enum TalentEffect {
  tapDamageMultiplier,
  trainerDamageMultiplier,
  coinGainMultiplier,
  critChance,
  skillCooldownReduction,
  offlineCapHours,
  luckyRateMultiplier,
  startingCoins;

  static TalentEffect parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
        'talents.json: "$id" has unknown effect "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

class TalentDef {
  const TalentDef({
    required this.id,
    required this.name,
    required this.icon,
    required this.branchId,
    required this.maxLevel,
    required this.costs,
    required this.effect,
    required this.valuePerLevel,
    required this.parent,
  });

  factory TalentDef.fromReader(JsonReader r, String branchId) {
    final id = r.string('id');
    final maxLevel = r.integer('maxLevel', min: 1);
    final costs = r.numbers('costs', min: 1);
    if (costs.length != maxLevel) {
      throw ContentException(
          'talents.json: "$id" needs exactly $maxLevel costs (one per level), found ${costs.length}');
    }
    return TalentDef(
      id: id,
      name: r.string('name'),
      icon: r.string('icon'),
      branchId: branchId,
      maxLevel: maxLevel,
      costs: costs,
      effect: TalentEffect.parse(id, r.string('effect')),
      valuePerLevel: r.number('valuePerLevel', min: 0, minExclusive: true),
      parent: r.optionalString('parent'),
    );
  }

  final String id;
  final String name;
  final String icon;
  final String branchId;
  final int maxLevel;

  /// Belt cost of each level, level 1 first.
  final List<double> costs;
  final TalentEffect effect;
  final double valuePerLevel;

  /// Talent that needs at least one level before this one can be bought.
  final String? parent;
}

class TalentBranchDef {
  const TalentBranchDef({required this.id, required this.name, required this.nodes});

  final String id;
  final String name;
  final List<TalentDef> nodes;
}

enum MaskBonusType {
  tapDamageMultiplier,
  trainerDamageMultiplier,
  coinGainMultiplier,
  bossCoinMultiplier,
  offlineCapHours;

  static MaskBonusType parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
        'masks.json: "$id" has unknown bonus "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

enum MaskUnlockRule {
  /// Owned from the start.
  starter,

  /// Bought with Belts (`value` is the price).
  belts,

  /// Unlocked when the boss of league number `value` is defeated.
  league,

  /// Granted by a store purchase.
  shop;

  static MaskUnlockRule parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
        'masks.json: "$id" has unknown unlock rule "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

class MaskDef {
  const MaskDef({
    required this.id,
    required this.name,
    required this.rarity,
    required this.bonusType,
    required this.bonusValue,
    required this.unlockRule,
    required this.unlockValue,
    required this.slotColors,
  });

  factory MaskDef.fromReader(JsonReader r) {
    final id = r.string('id');
    final bonus = r.object('bonus');
    final unlock = r.object('unlock');
    final rule = MaskUnlockRule.parse(id, unlock.string('rule'));
    final needsValue = rule == MaskUnlockRule.belts || rule == MaskUnlockRule.league;
    final slots = r.strings('slotColors');
    if (slots.length != 3) {
      throw ContentException('masks.json: "$id" slotColors needs exactly 3 palette colors');
    }
    for (final c in slots) {
      if (!Palette.byId.containsKey(c)) {
        throw ContentException('masks.json: "$id" slot color "$c" is not in the palette');
      }
    }
    return MaskDef(
      id: id,
      name: r.string('name'),
      rarity: r.string('rarity'),
      bonusType: MaskBonusType.parse(id, bonus.string('type')),
      bonusValue: bonus.number('value', min: 0, minExclusive: true),
      unlockRule: rule,
      unlockValue: needsValue ? unlock.number('value', min: 1) : 0,
      slotColors: slots,
    );
  }

  final String id;
  final String name;
  final String rarity;
  final MaskBonusType bonusType;
  final double bonusValue;
  final MaskUnlockRule unlockRule;

  /// Belt price (belts rule) or league number (league rule); 0 otherwise.
  final double unlockValue;

  /// Palette ids that replace the mask's reserved Night Purple, Violet and
  /// Lilac at runtime (shadow, base, light).
  final List<String> slotColors;
}

enum AchievementCounter {
  taps,
  defeats,
  bosses,
  prestiges;

  static AchievementCounter parse(String id, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw ContentException(
        'achievements.json: "$id" has unknown counter "$name" (known: ${values.map((e) => e.name).join(', ')})');
  }
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.counter,
    required this.target,
    required this.rewardBelts,
  });

  factory AchievementDef.fromReader(JsonReader r) {
    final id = r.string('id');
    return AchievementDef(
      id: id,
      name: r.string('name'),
      counter: AchievementCounter.parse(id, r.string('counter')),
      target: r.integer('target', min: 1),
      rewardBelts: r.integer('rewardBelts', min: 0),
    );
  }

  final String id;
  final String name;
  final AchievementCounter counter;
  final int target;
  final int rewardBelts;
}
