import 'dart:convert';
import 'dart:io';

import 'package:lucha_tap_tap/data/content_bundle.dart';

/// Decoded JSON of every data file, read from `assets/data/` on disk.
/// Tests may edit the returned maps to prove that data drives the game.
Map<String, Map<String, dynamic>> readContentFiles() => {
      for (final name in ContentFiles.all)
        name: jsonDecode(File('assets/data/$name').readAsStringSync())
            as Map<String, dynamic>,
    };

ContentBundle loadTestContent([void Function(Map<String, Map<String, dynamic>>)? edit]) {
  final files = readContentFiles();
  edit?.call(files);
  return ContentBundle.parse(files);
}
