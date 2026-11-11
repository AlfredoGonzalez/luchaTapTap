import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/palette.dart';
import 'package:lucha_tap_tap/data/content_bundle.dart';
import 'package:lucha_tap_tap/data/content_exception.dart';

import '../test_content.dart';

void expectInvalid(void Function(Map<String, Map<String, dynamic>>) edit, String message) {
  expect(
    () => loadTestContent(edit),
    throwsA(isA<ContentException>().having((e) => e.message, 'message', contains(message))),
  );
}

void main() {
  test('the shipped data files load and validate', () {
    final c = loadTestContent();
    expect(c.opponents.length, 3);
    expect(c.trainers.length, 1);
    expect(c.upgrades.length, 1);
    expect(c.leagues.first.opponentIds.length, 3);
  });

  test('every data file has a schemaVersion', () {
    for (final entry in readContentFiles().entries) {
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

  group('no balance numbers in Dart', () {
    test('formula and engine code reads constants from Balance, not literals', () {
      // Guard rail, not a proof: the economy constants must not appear as
      // literals in the rules code.
      final forbidden = [RegExp(r'\b1\.55\b'), RegExp(r'\b1\.15\b'), RegExp(r'\b0\.15\b')];
      for (final path in ['lib/core/formulas.dart', 'lib/core/game_engine.dart']) {
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
