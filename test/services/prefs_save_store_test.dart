import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/game_engine.dart';
import 'package:lucha_tap_tap/core/save_codec.dart';
import 'package:lucha_tap_tap/services/prefs_save_store.dart';
import 'package:lucha_tap_tap/services/save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_content.dart';

void main() {
  final content = loadTestContent();
  final codec = SaveCodec(content: content);
  late SharedPreferences prefs;
  late PrefsSaveStore store;

  SaveData dataWith(int fight, {int minute = 0}) {
    final e = GameEngine(content: content)..debugSkipFights(fight - 1);
    return SaveData(
      saveVersion: 1,
      lastSeen: DateTime.utc(2026, 11, 11, 12, minute),
      rngState: 7,
      state: e.state,
      settings: {'sound': false},
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = PrefsSaveStore(prefs: prefs, codec: codec);
  });

  test('nothing saved means nothing to load', () async {
    final load = await store.load();
    expect(load.data, isNull);
    expect(load.source, SaveSource.none);
  });

  test('save then load, including settings', () async {
    await store.save(dataWith(5));
    final load = await store.load();
    expect(load.source, SaveSource.main);
    expect(load.data!.state.fightNumber, 5);
    expect(load.data!.settings, {'sound': false});
  });

  test('keeps the previous save as a backup and falls back to it', () async {
    await store.save(dataWith(3, minute: 1));
    await store.save(dataWith(8, minute: 2));
    await prefs.setString('save.main', '{"saveVersion": 1, "last'); // damaged
    final load = await store.load();
    expect(load.source, SaveSource.backup);
    expect(load.data!.state.fightNumber, 3);
    expect(load.error, isNotNull);
  });

  test('both damaged starts a new game', () async {
    await prefs.setString('save.main', 'garbage');
    await prefs.setString('save.bak', 'garbage');
    final load = await store.load();
    expect(load.data, isNull);
    expect(load.error, isNotNull);
  });

  test('delete removes both copies', () async {
    await store.save(dataWith(3, minute: 1));
    await store.save(dataWith(5, minute: 2));
    await store.delete();
    expect((await store.load()).data, isNull);
  });
}
