import 'dart:convert';
import 'dart:io';

import 'package:lucha_tap_tap/data/content_bundle.dart';

/// Files whose text always comes from the shipped data (they hold no numbers
/// the rules tests depend on).
const _alwaysShipped = {ContentFiles.strings, ContentFiles.credits};

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// Decoded JSON of every data file for the *rules* tests.
///
/// Numbers come from `test/fixtures/data/`, a frozen copy of the economy, so
/// the balance pass can retune `assets/data/` without breaking tests that
/// check formulas and mechanics. Spanish strings and credits are the shipped
/// ones. Tests may edit the returned maps to prove that data drives the game.
Map<String, Map<String, dynamic>> readContentFiles() => {
      for (final name in ContentFiles.all)
        name: _read(_alwaysShipped.contains(name)
            ? 'assets/data/$name'
            : 'test/fixtures/data/$name'),
    };

/// Decoded JSON of the files exactly as the game ships them.
Map<String, Map<String, dynamic>> readShippedFiles() => {
      for (final name in ContentFiles.all) name: _read('assets/data/$name'),
    };

ContentBundle loadTestContent([void Function(Map<String, Map<String, dynamic>>)? edit]) {
  final files = readContentFiles();
  edit?.call(files);
  return ContentBundle.parse(files);
}

/// The content exactly as the game ships it (validation and pacing tests).
ContentBundle loadShippedContent() => ContentBundle.parse(readShippedFiles());
