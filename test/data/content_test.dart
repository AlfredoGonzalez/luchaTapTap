import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/palette.dart';
import 'package:lucha_tap_tap/data/content_bundle.dart';
import 'package:lucha_tap_tap/data/content_exception.dart';
import 'package:lucha_tap_tap/data/content_models.dart';

import '../test_content.dart';

void expectInvalid(void Function(Map<String, Map<String, dynamic>>) edit, String message) {
  expect(
    () => loadTestContent(edit),
    throwsA(isA<ContentException>().having((e) => e.message, 'message', contains(message))),
  );
}

void main() {
  test('the shipped data files load and validate', () {
    final c = loadShippedContent();
    expect(c.upgrades.length, 2);
    expect(c.skills.length, 5);
    expect(c.talents.length, 8);
  });

  test('the launch content is all there: 3 leagues, 6 opponents and a boss each, 12 masks, 6 trainers', () {
    final c = loadShippedContent();
    OpponentDef opp(String id) => c.opponents.firstWhere((o) => o.id == id);
    expect(c.leagues.length, 3);
    for (final league in c.leagues) {
      expect(league.opponentIds.toSet().length, 6, reason: '${league.id} needs 6 different opponents');
      expect(league.bossId, isNotNull, reason: league.id);
      expect(opp(league.bossId!).isBoss, isTrue);
      expect(opp(league.bossId!).size, 64);
      for (final id in league.opponentIds) {
        expect(opp(id).isBoss, isFalse);
        expect(opp(id).size, 48);
      }
    }
    expect(c.opponents.length, 21);
    expect(c.masks.length, 12);
    expect(c.trainers.length, 6);
    // Every sprite key is used once, so one sheet per opponent.
    expect(c.opponents.map((o) => o.sprite).toSet().length, c.opponents.length);
  });

  test('masks: exactly one starter, every league boss unlocks a mask, bonuses differ in kind', () {
    final c = loadShippedContent();
    expect(c.masks.where((m) => m.unlockRule == MaskUnlockRule.starter).length, 1);
    for (final league in c.leagues) {
      expect(
        c.masks.where((m) => m.unlockRule == MaskUnlockRule.league && m.unlockValue == league.order).length,
        1,
        reason: 'league ${league.order}',
      );
    }
    expect(c.masks.map((m) => m.bonusType).toSet().length, MaskBonusType.values.length);
    expect(c.masks.map((m) => m.id).toSet().length, 12);
  });

  test('trainers get more expensive and stronger tier by tier, and unlock later', () {
    final t = loadShippedContent().trainers;
    for (var i = 1; i < t.length; i++) {
      expect(t[i].baseCost, greaterThan(t[i - 1].baseCost));
      expect(t[i].baseDps, greaterThan(t[i - 1].baseDps));
      expect(t[i].unlockFight, greaterThan(t[i - 1].unlockFight));
    }
  });

  test('every data file has a schemaVersion', () {
    for (final entry in readShippedFiles().entries) {
      expect(entry.value['schemaVersion'], isA<int>(), reason: entry.key);
    }
  });

  group('fails loudly on bad data', () {
    test('missing file', () {
      expect(
        () => ContentBundle.parse({}),
        throwsA(isA<ContentException>().having((e) => e.message, 'm', contains('missing'))),
      );
    });

    test('wrong schema version', () {
      expectInvalid((f) => f['opponents.json']!['schemaVersion'] = 99, 'schemaVersion');
    });

    test('duplicate opponent id', () {
      expectInvalid((f) {
        final list = f['opponents.json']!['opponents'] as List;
        list.add(Map<String, dynamic>.from(list.first as Map));
      }, 'duplicate id "mr_aguacate"');
    });

    test('league references unknown opponent', () {
      expectInvalid((f) => f['leagues.json']!['leagues'][0]['opponentIds'] = ['ghost'],
          'unknown opponent "ghost"');
    });

    test('opponent colors outside the palette or reserved for masks', () {
      expectInvalid(
          (f) => f['opponents.json']!['opponents'][0]['placeholderColor'] = 'hot_pink', 'not in the palette');
      expectInvalid(
          (f) => f['opponents.json']!['opponents'][0]['placeholderColor'] = 'violet', 'reserved for masks');
    });

    test('regular opponent with a boss size', () {
      expectInvalid((f) => f['opponents.json']!['opponents'][0]['size'] = 64, 'must be 48');
    });

    test('unknown upgrade effect', () {
      expectInvalid((f) => f['upgrades.json']!['upgrades'][0]['effect'] = 'teleport', 'unknown effect');
    });

    test('type and range errors name the file and key', () {
      expectInvalid((f) => f['balance.json']!['economy']['hpGrowth'] = 'fast', 'balance.json: economy.hpGrowth');
      expectInvalid((f) => f['balance.json']!['economy']['costGrowth'] = 1, 'costGrowth');
      expectInvalid((f) => f['trainers.json']!['trainers'][0]['baseCost'] = 0, 'trainers.json');
      expectInvalid((f) => f['balance.json']!['tick']['ticksPerSecond'] = 2.5, 'whole number');
    });

    test('talent with the wrong number of costs', () {
      expectInvalid((f) => f['talents.json']!['branches'][0]['nodes'][0]['costs'] = [1], 'needs exactly 5 costs');
    });

    test('talent parent must exist, be in the same branch and come first', () {
      expectInvalid((f) => f['talents.json']!['branches'][0]['nodes'][1]['parent'] = 'ghost', 'unknown parent');
      expectInvalid((f) => f['talents.json']!['branches'][0]['nodes'][1]['parent'] = 'cartera', 'same branch');
      expectInvalid((f) {
        final nodes = f['talents.json']!['branches'][0]['nodes'] as List;
        f['talents.json']!['branches'][0]['nodes'] = nodes.reversed.toList();
      }, 'must be listed before');
    });

    test('mask rules: palette colors, starter present, known league', () {
      expectInvalid((f) => f['masks.json']!['masks'][0]['slotColors'] = ['ink', 'ink', 'hot_pink'], 'not in the palette');
      expectInvalid((f) => f['masks.json']!['masks'][0]['slotColors'] = ['ink'], 'exactly 3');
      expectInvalid((f) => f['masks.json']!['masks'][0]['unlock'] = {'rule': 'belts', 'value': 2}, 'starter mask');
      expectInvalid((f) => f['masks.json']!['masks'][1]['unlock'] = {'rule': 'league', 'value': 9}, 'league 9');
    });

    test('skills: unknown effect and missing duration', () {
      expectInvalid((f) => f['skills.json']!['skills'][0]['effect'] = 'laser', 'unknown effect');
      expectInvalid((f) => f['skills.json']!['skills'][1]['duration'] = 0, 'needs a duration');
    });

    test('offline cap must not be below the base', () {
      expectInvalid((f) => f['balance.json']!['offline']['maxCapHours'] = 1, 'maxCapHours');
    });

    test('boss id must point at a boss', () {
      expectInvalid((f) => f['leagues.json']!['leagues'][0]['bossId'] = 'mr_aguacate', 'isBoss true');
    });
  });

  group('palette', () {
    test('has exactly 32 unique colors', () {
      expect(Palette.byId.length, 32);
      expect(Palette.byId.values.toSet().length, 32);
    });
  });

  group('Spanish strings', () {
    final strings = loadTestContent().strings;

    test('every string key used in lib/ exists in strings_es.json', () {
      final used = <String>{};
      final pattern = RegExp(r"\.t\(\s*'([a-z0-9_]+)'");
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          for (final m in pattern.allMatches(entity.readAsStringSync())) {
            used.add(m.group(1)!);
          }
        }
      }
      expect(used, isNotEmpty);
      for (final key in used) {
        expect(strings.containsKey(key), isTrue, reason: 'missing string "$key"');
      }
    });
  });

  group('dynamic Spanish strings', () {
    final content = loadTestContent();
    final strings = content.strings;

    test('every mask bonus and talent effect has a text', () {
      // These keys are built from enum names, so the regex test above cannot see them.
      for (final b in MaskBonusType.values) {
        expect(strings.containsKey('mask_bonus_${b.name}'), isTrue, reason: 'mask_bonus_${b.name}');
      }
      for (final t in TalentEffect.values) {
        expect(strings.containsKey('talent_${t.name}'), isTrue, reason: 'talent_${t.name}');
      }
    });

    test('no string is empty', () {
      strings.forEach((key, value) => expect(value.trim(), isNotEmpty, reason: key));
    });
  });

  group('no balance numbers in Dart', () {
    test('formula and engine code reads constants from Balance, not literals', () {
      // Guard rail, not a proof: the economy constants must not appear as
      // literals in the rules code.
      final forbidden = [RegExp(r'\b1\.55\b'), RegExp(r'\b1\.15\b'), RegExp(r'\b0\.15\b')];
      for (final path in [
        'lib/core/formulas.dart',
        'lib/core/game_engine.dart',
        'lib/core/save_codec.dart',
        'lib/services/game_controller.dart',
      ]) {
        final code = File(path)
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
            .join('\n');
        for (final pattern in forbidden) {
          expect(pattern.hasMatch(code), isFalse, reason: '$path contains ${pattern.pattern}');
        }
      }
    });
  });
}
