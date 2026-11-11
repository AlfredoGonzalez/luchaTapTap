import 'dart:io';

import '../core/save_codec.dart';

/// Where a loaded save came from.
enum SaveSource { none, main, backup }

class SaveLoad {
  const SaveLoad({this.data, required this.source, this.error});

  final SaveData? data;
  final SaveSource source;

  /// Why the main file could not be used (when the backup or nothing was).
  final String? error;
}

/// Reads and writes the save. Implementations must never leave a half-written
/// save behind.
abstract class SaveStore {
  Future<SaveLoad> load();
  Future<void> save(SaveData data);
  Future<void> delete();
}

/// Keeps the save in memory only (tests, and before the real store exists).
class MemorySaveStore implements SaveStore {
  SaveData? current;
  int writes = 0;

  @override
  Future<SaveLoad> load() async => SaveLoad(
        data: current,
        source: current == null ? SaveSource.none : SaveSource.main,
      );

  @override
  Future<void> save(SaveData data) async {
    current = data;
    writes++;
  }

  @override
  Future<void> delete() async => current = null;
}

/// Save in a JSON file with crash-safe writes.
///
/// A save writes the new content to a temporary file, copies the current save
/// to a backup, and only then renames the temporary file over the main one.
/// A crash at any point leaves either the old or the new save intact; if the
/// main file fails to parse, the backup (the save before it) is used.
class FileSaveStore implements SaveStore {
  FileSaveStore({required Directory directory, required this.codec, this.fileName = 'save.json'})
      : _main = File('${directory.path}/$fileName'),
        _backup = File('${directory.path}/$fileName.bak'),
        _temp = File('${directory.path}/$fileName.tmp');

  final SaveCodec codec;
  final String fileName;
  final File _main;
  final File _backup;
  final File _temp;

  @override
  Future<SaveLoad> load() async {
    String? error;
    final fromMain = await _tryRead(_main, (e) => error = e);
    if (fromMain != null) return SaveLoad(data: fromMain, source: SaveSource.main);
    final fromBackup = await _tryRead(_backup, (_) {});
    if (fromBackup != null) {
      return SaveLoad(data: fromBackup, source: SaveSource.backup, error: error);
    }
    return SaveLoad(source: SaveSource.none, error: error);
  }

  Future<SaveData?> _tryRead(File file, void Function(String) onError) async {
    try {
      if (!await file.exists()) return null;
      return codec.decode(await file.readAsString());
    } on SaveFormatException catch (e) {
      onError(e.message);
    } on FileSystemException catch (e) {
      onError(e.message);
    }
    return null;
  }

  @override
  Future<void> save(SaveData data) async {
    final text = codec.encode(data);
    await _temp.writeAsString(text, flush: true);
    if (await _main.exists()) {
      await _main.copy(_backup.path);
    }
    await _temp.rename(_main.path);
  }

  @override
  Future<void> delete() async {
    for (final file in [_main, _backup, _temp]) {
      if (await file.exists()) await file.delete();
    }
  }
}
