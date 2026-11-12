import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/game/sprite_library.dart';

import '../test_content.dart';

/// Serves files from a folder as if they were the app's assets.
class FolderBundle extends CachingAssetBundle {
  FolderBundle(this.root);
  final Directory root;

  @override
  Future<ByteData> load(String key) async {
    final f = File('${root.path}/$key');
    if (!f.existsSync()) throw FlutterError('Unable to load asset: $key');
    final bytes = await f.readAsBytes();
    return ByteData.sublistView(Uint8List.fromList(bytes));
  }
}

void main() {
  final content = loadTestContent();
  final repo = Directory.current;

  testWidgets('loads sheets (placeholder folder fallback) and a recolored player per mask', (tester) async {
    final library = await tester.runAsync(() => SpriteLibrary.load(content, bundle: FolderBundle(repo)));
    final aguacate = library!.opponent('opp_mr_aguacate');
    expect(aguacate, isNotNull);
    expect(aguacate!.cell, 48);
    expect(aguacate.image.width, 48 * content.balance.animations.columns);
    // Five required rows; the kick row is optional (the player's sheet has it).
    expect(aguacate.image.height, 48 * 5);
    expect(aguacate.has('kick'), isFalse);
    expect(library.opponent('opp_el_mariachi_furioso')!.cell, 64);
    // One recolored sheet per mask plus the one with the colors as drawn.
    expect(library.player(null), isNotNull);
    expect(library.player(null)!.has('kick'), isTrue, reason: 'the player kicks');
    // The plancha strip (with and without a mask) and the skill icon.
    final strip = library.skillStrip('plancha', null)!;
    final cfg = content.balance.animations.skillClips['plancha']!;
    expect(strip.image.width, cfg.cellWidth * cfg.frames);
    expect(strip.image.height, cfg.cellHeight);
    expect(library.skillStrip('plancha', content.masks.first.id), isNotNull);
    expect(library.icon('sk_plancha'), isNotNull);
    for (final mask in content.masks) {
      expect(library.player(mask.id), isNotNull, reason: mask.id);
    }
  });

  testWidgets('final art in assets/sprites wins over the placeholder', (tester) async {
    final ph = '${repo.path}/assets/sprites/placeholder';
    Directory dir(String name) {
      final d = Directory.systemTemp.createTempSync(name);
      addTearDown(() => d.deleteSync(recursive: true));
      Directory('${d.path}/assets/sprites/placeholder').createSync(recursive: true);
      return d;
    }

    // A: the aguacate's placeholder, plus "final art" (really the taquero's
    // placeholder file) saved under the aguacate's name.
    final a = dir('a');
    File('$ph/opp_mr_aguacate.png').copySync('${a.path}/assets/sprites/placeholder/opp_mr_aguacate.png');
    File('$ph/opp_el_taquero_cosmico.png').copySync('${a.path}/assets/sprites/opp_mr_aguacate.png');
    // B: only the taquero's placeholder.
    final b = dir('b');
    File('$ph/opp_el_taquero_cosmico.png').copySync('${b.path}/assets/sprites/placeholder/opp_el_taquero_cosmico.png');
    File('$ph/opp_mr_aguacate.png').copySync('${b.path}/assets/sprites/placeholder/opp_mr_aguacate.png');
    final result = await tester.runAsync(() async {
      final custom = await SpriteLibrary.load(content, bundle: FolderBundle(a));
      final stock = await SpriteLibrary.load(content, bundle: FolderBundle(b));
      Future<List<int>> bytes(SpriteSheet s) async => (await s.image.toByteData())!.buffer.asUint8List().toList();
      return [
        await bytes(custom.opponent('opp_mr_aguacate')!),
        await bytes(stock.opponent('opp_el_taquero_cosmico')!),
        await bytes(stock.opponent('opp_mr_aguacate')!),
      ];
    });
    expect(result![0], result[1], reason: 'the final file is used');
    expect(result[0], isNot(result[2]), reason: 'not the placeholder');
  });

  testWidgets('a sheet of the wrong size is skipped (rectangles stay)', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('sprites');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/assets/sprites').createSync(recursive: true);
    // A valid PNG of the wrong size: 1x1.
    File('${tmp.path}/assets/sprites/opp_mr_aguacate.png').writeAsBytesSync(base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));
    final library = await tester.runAsync(() => SpriteLibrary.load(content, bundle: FolderBundle(tmp)));
    expect(library!.opponent('opp_mr_aguacate'), isNull);
  });

  testWidgets('with no art at all the library is empty', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('sprites');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final library = await tester.runAsync(() => SpriteLibrary.load(content, bundle: FolderBundle(tmp)));
    expect(library!.isEmpty, isTrue);
  });
}
