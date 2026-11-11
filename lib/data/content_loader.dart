import 'dart:convert';

import 'package:flutter/services.dart';

import 'content_bundle.dart';
import 'content_exception.dart';

/// Loads and validates every JSON file under `assets/data/`.
/// Throws [ContentException] on any problem so a bad data file fails loudly.
Future<ContentBundle> loadContent([AssetBundle? bundle]) async {
  final source = bundle ?? rootBundle;
  final files = <String, Map<String, dynamic>>{};
  for (final name in ContentFiles.all) {
    final String text;
    try {
      text = await source.loadString('assets/data/$name');
    } catch (e) {
      throw ContentException('$name could not be read: $e');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw ContentException('$name is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw ContentException('$name must contain a JSON object');
    }
    files[name] = decoded;
  }
  return ContentBundle.parse(files);
}
