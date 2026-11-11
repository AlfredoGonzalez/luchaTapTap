/// Spanish UI text, loaded from `strings_es.json`. All player-facing text goes
/// through [t] so other languages can be added later.
class Strings {
  const Strings(this._map);

  final Map<String, String> _map;

  /// Text for [key], replacing `{name}` placeholders with [params].
  /// A missing key is a bug in the data, so it throws instead of showing blanks.
  String t(String key, [Map<String, Object> params = const {}]) {
    final text = _map[key];
    if (text == null) throw StateError('Missing string "$key" in strings_es.json');
    var result = text;
    params.forEach((name, value) {
      result = result.replaceAll('{$name}', '$value');
    });
    return result;
  }
}
