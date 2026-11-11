import 'package:shared_preferences/shared_preferences.dart';

import '../core/save_codec.dart';
import 'save_store.dart';

/// Save kept in the browser's local storage (the GitHub Pages test build) or
/// any place `shared_preferences` works. Same contract as [FileSaveStore]:
/// the previous save is kept as a backup and used if the main one is damaged.
class PrefsSaveStore implements SaveStore {
  PrefsSaveStore({required this.prefs, required this.codec, this.key = 'save'});

  final SharedPreferences prefs;
  final SaveCodec codec;
  final String key;

  String get _main => '$key.main';
  String get _backup => '$key.bak';

  @override
  Future<SaveLoad> load() async {
    String? error;
    final fromMain = _tryRead(_main, (e) => error = e);
    if (fromMain != null) {
      return SaveLoad(data: fromMain, source: SaveSource.main);
    }
    final fromBackup = _tryRead(_backup, (_) {});
    if (fromBackup != null) {
      return SaveLoad(
        data: fromBackup,
        source: SaveSource.backup,
        error: error,
      );
    }
    return SaveLoad(source: SaveSource.none, error: error);
  }

  SaveData? _tryRead(String name, void Function(String) onError) {
    final text = prefs.getString(name);
    if (text == null) return null;
    try {
      return codec.decode(text);
    } on SaveFormatException catch (e) {
      onError(e.message);
      return null;
    }
  }

  @override
  Future<void> save(SaveData data) async {
    final text = codec.encode(data);
    final previous = prefs.getString(_main);
    if (previous != null) await prefs.setString(_backup, previous);
    await prefs.setString(_main, text);
  }

  @override
  Future<void> delete() async {
    await prefs.remove(_main);
    await prefs.remove(_backup);
  }
}
