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
  tapDamage;

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
