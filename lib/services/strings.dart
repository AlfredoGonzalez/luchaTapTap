/// Player-facing text in the chosen language. UI text comes from
/// `strings_<language>.json`; names and descriptions inside the other data
/// files are translated with `data.<file>.<id>.<field>` keys in the same
/// file. Anything missing falls back to Spanish, the language the game is
/// written in.
class Strings {
  const Strings(this._map, [this._fallback = const {}]);

  final Map<String, String> _map;
  final Map<String, String> _fallback;

  /// Whether [key] has a text (for optional forms such as singulars).
  bool has(String key) => _map.containsKey(key) || _fallback.containsKey(key);

  /// Text for [key], replacing `{name}` placeholders with [params].
  /// A missing key is a bug in the data, so it throws instead of showing blanks.
  String t(String key, [Map<String, Object> params = const {}]) {
    final text = _map[key] ?? _fallback[key];
    if (text == null) {
      throw StateError('Missing string "$key" in strings_es.json');
    }
    return fill(text, params);
  }

  /// Text of a data file field ([fallback] is the Spanish text in the file).
  /// [file] is the data file name without `.json`, e.g. `upgrades`.
  String data(String file, String id, String field, String fallback) =>
      _map['data.$file.$id.$field'] ?? fallback;

  /// Replaces `{name}` placeholders in [text].
  static String fill(String text, Map<String, Object> params) {
    var result = text;
    params.forEach((name, value) {
      result = result.replaceAll('{$name}', '$value');
    });
    return result;
  }
}
