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
    expect(aguacate.image.height, 48 * content.balance.animations.order.length);
    expect(library.opponent('opp_el_mariachi_furioso')!.cell, 64);
    // One recolored sheet per mask plus the one with the colors as drawn.
    expect(library.player(null), isNotNull);
    for (final mask in content.masks) {
      expect(library.player(mask.id), isNotNull, reason: mask.id);
    }
  });

  testWidgets('final art in assets/sprites wins over the placeholder', (tester) async {
    final tmp = Directory.systemTemp.createTempSync('sprites');
    addTearDown(() => tmp.deleteSync(recursive: true));
    Directory('${tmp.path}/assets/sprites/placeholder').createSync(recursive: true);
    // Placeholder: the real aguacate. "Final art": the taquero's sheet saved
    // under the aguacate's name (same size, different pixels).
    File('${repo.path}/assets/sprites/placeholder/opp_mr_aguacate.png')
        .copySync('${tmp.path}/assets/sprites/placeholder/opp_mr_aguacate.png');
    File('${repo.path}/assets/sprites/placeholder/opp_el_taquero_cosmico.png')
        .copySync('${tmp.path}/assets/sprites/opp_mr_aguacate.png');
    final result = await tester.runAsync(() async {
      final custom = await SpriteLibrary.load(content, bundle: FolderBundle(tmp));
      final stock = await SpriteLibrary.load(content, bundle: FolderBundle(repo));
      Future<List<int>> bytes(SpriteSheet s) async =>
          (await s.image.toByteData())!.buffer.asUint8List().toList();
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
