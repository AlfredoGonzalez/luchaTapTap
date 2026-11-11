import 'content_exception.dart';

/// Strict typed access to a decoded JSON object. Every failure names the file
/// and the path of the offending key.
class JsonReader {
  JsonReader(this.source, this._map, [this.path = '']);

  /// File name used in error messages.
  final String source;
  final Map<String, dynamic> _map;
  final String path;

  String _where(String key) => '$source: ${path.isEmpty ? key : '$path.$key'}';

  bool has(String key) => _map.containsKey(key) && _map[key] != null;

  T _typed<T>(String key, String typeName) {
    final value = _map[key];
    if (value is! T) {
      throw ContentException(
        '${_where(key)} must be $typeName (found ${value.runtimeType})',
      );
    }
    return value;
  }

  String string(String key) {
    final value = _typed<String>(key, 'a string');
    if (value.trim().isEmpty) {
      throw ContentException('${_where(key)} must not be empty');
    }
    return value;
  }

  String? optionalString(String key) => has(key) ? string(key) : null;

  bool boolean(String key) => _typed<bool>(key, 'true or false');

  int integer(String key, {int? min}) {
    final value = _typed<num>(key, 'a whole number');
    if (value != value.truncate()) {
      throw ContentException('${_where(key)} must be a whole number');
    }
    final result = value.toInt();
    if (min != null && result < min) {
      throw ContentException('${_where(key)} must be at least $min');
    }
    return result;
  }

  double number(String key, {double? min, bool minExclusive = false}) {
    final value = _typed<num>(key, 'a number').toDouble();
    if (min != null && (minExclusive ? value <= min : value < min)) {
      throw ContentException(
        '${_where(key)} must be ${minExclusive ? 'greater than' : 'at least'} $min',
      );
    }
    return value;
  }

  JsonReader object(String key) {
    final value = _typed<Map<String, dynamic>>(key, 'an object');
    return JsonReader(source, value, path.isEmpty ? key : '$path.$key');
  }

  List<JsonReader> objects(String key) {
    final value = _typed<List<dynamic>>(key, 'a list');
    final result = <JsonReader>[];
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      if (item is! Map<String, dynamic>) {
        throw ContentException('${_where('$key[$i]')} must be an object');
      }
      result.add(
        JsonReader(source, item, '${path.isEmpty ? '' : '$path.'}$key[$i]'),
      );
    }
    return result;
  }

  List<int> integers(String key, {int? min}) {
    final value = _typed<List<dynamic>>(key, 'a list of whole numbers');
    return [
      for (var i = 0; i < value.length; i++) _intAt(value[i], '$key[$i]', min),
    ];
  }

  int _intAt(Object? value, String key, int? min) {
    if (value is! num || value != value.truncate()) {
      throw ContentException('${_where(key)} must be a whole number');
    }
    if (min != null && value < min) {
      throw ContentException('${_where(key)} must be at least $min');
    }
    return value.toInt();
  }

  List<double> numbers(String key, {double? min}) {
    final value = _typed<List<dynamic>>(key, 'a list of numbers');
    return [
      for (var i = 0; i < value.length; i++)
        value[i] is num && (min == null || (value[i] as num) >= min)
            ? (value[i] as num).toDouble()
            : throw ContentException(
                '${_where('$key[$i]')} must be a number${min == null ? '' : ' of at least $min'}',
              ),
    ];
  }

  Map<String, double> numberMap(String key) {
    final value = _typed<Map<String, dynamic>>(key, 'an object of numbers');
    return {
      for (final entry in value.entries)
        entry.key: entry.value is num
            ? (entry.value as num).toDouble()
            : throw ContentException(
                '${_where('$key.${entry.key}')} must be a number',
              ),
    };
  }

  List<String> strings(String key) {
    final value = _typed<List<dynamic>>(key, 'a list of strings');
    return [
      for (var i = 0; i < value.length; i++)
        value[i] is String
            ? value[i] as String
            : throw ContentException('${_where('$key[$i]')} must be a string'),
    ];
  }

  Map<String, String> stringMap(String key) {
    final value = _typed<Map<String, dynamic>>(key, 'an object of strings');
    return {
      for (final entry in value.entries)
        entry.key: entry.value is String
            ? entry.value as String
            : throw ContentException(
                '${_where('$key.${entry.key}')} must be a string',
              ),
    };
  }

  /// Checks `schemaVersion` equals [expected].
  void expectSchemaVersion(int expected) {
    final found = integer('schemaVersion');
    if (found != expected) {
      throw ContentException(
        '$source: schemaVersion is $found but this build supports $expected',
      );
    }
  }
}
