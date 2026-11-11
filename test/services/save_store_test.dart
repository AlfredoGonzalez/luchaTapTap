import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/save_codec.dart';
import 'package:lucha_tap_tap/services/save_store.dart';

import '../test_content.dart';

void main() {
  late Directory dir;
  late FileSaveStore store;
  final content = loadTestContent();
  final codec = SaveCodec(content: content);

  SaveData dataWith(int fight, {int minute = 0}) {
    final e = GameEngine(content: content)..debugSkipFights(fight - 1);
    return SaveData(
      saveVersion: 1,
      lastSeen: DateTime.utc(2026, 11, 11, 12, minute),
      rngState: 42,
      state: e.state,
    );
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lucha_save_test_');
    store = FileSaveStore(directory: dir, codec: codec);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  File file(String name) => File('${dir.path}/$name');

  test('with nothing saved there is nothing to load', () async {
    final load = await store.load();
    expect(load.data, isNull);
    expect(load.source, SaveSource.none);
    expect(load.error, isNull);
  });

  test('save then load gives the same game', () async {
    await store.save(dataWith(5));
    final load = await store.load();
    expect(load.source, SaveSource.main);
    expect(load.data!.state.fightNumber, 5);
    expect(load.data!.rngState, 42);
    expect(load.data!.lastSeen, DateTime.utc(2026, 11, 11, 12));
  });

  test('a save leaves no temporary file behind', () async {
    await store.save(dataWith(2));
    expect(file('save.json').existsSync(), isTrue);
    expect(file('save.json.tmp').existsSync(), isFalse);
  });

  test('the second save keeps the one before it as a backup', () async {
    await store.save(dataWith(3, minute: 1));
    expect(file('save.json.bak').existsSync(), isFalse);
    await store.save(dataWith(8, minute: 2));
    final backup = codec.decode(file('save.json.bak').readAsStringSync());
    final main = codec.decode(file('save.json').readAsStringSync());
    expect(backup.state.fightNumber, 3);
    expect(main.state.fightNumber, 8);
  });

  test('a damaged main file falls back to the backup', () async {
    await store.save(dataWith(3, minute: 1));
    await store.save(dataWith(8, minute: 2));
    file('save.json').writeAsStringSync('{"saveVersion": 1, "last'); // cut off mid-write
    final load = await store.load();
    expect(load.source, SaveSource.backup);
    expect(load.data!.state.fightNumber, 3);
    expect(load.error, isNotNull);
  });

  test('an empty main file falls back to the backup', () async {
    await store.save(dataWith(3, minute: 1));
    await store.save(dataWith(8, minute: 2));
    file('save.json').writeAsStringSync('');
    expect((await store.load()).data!.state.fightNumber, 3);
  });

  test('both files damaged starts a new game instead of crashing', () async {
    file('save.json').writeAsStringSync('garbage');
    file('save.json.bak').writeAsStringSync('more garbage');
    final load = await store.load();
    expect(load.data, isNull);
    expect(load.source, SaveSource.none);
    expect(load.error, isNotNull);
  });

  test('a leftover temporary file from a crash is ignored', () async {
    await store.save(dataWith(4));
    file('save.json.tmp').writeAsStringSync('half written');
    expect((await store.load()).data!.state.fightNumber, 4);
    await store.save(dataWith(6, minute: 3)); // and the next save recovers
    expect((await store.load()).data!.state.fightNumber, 6);
    expect(file('save.json.tmp').existsSync(), isFalse);
  });

  test('a save from a newer build is not used', () async {
    file('save.json').writeAsStringSync(
        '{"saveVersion": 99, "lastSeen": "2026-01-01T00:00:00Z", "state": {}}');
    final load = await store.load();
    expect(load.data, isNull);
    expect(load.error, contains('newer'));
  });

  test('delete removes every file', () async {
    await store.save(dataWith(3, minute: 1));
    await store.save(dataWith(5, minute: 2));
    await store.delete();
    expect(file('save.json').existsSync(), isFalse);
    expect(file('save.json.bak').existsSync(), isFalse);
    expect((await store.load()).data, isNull);
  });

  test('many saves in a row stay consistent', () async {
    for (var i = 1; i <= 25; i++) {
      await store.save(dataWith(i));
    }
    expect((await store.load()).data!.state.fightNumber, 25);
  });
}
