import 'dart:math' as math;

import 'big.dart';

/// Names of the first thousands tiers: none, K, M, B, T. Later tiers use
/// letters (aa, ab, ...), then scientific notation.
const List<String> _namedTiers = ['', 'K', 'M', 'B', 'T'];
const int _lettersCount = 26;
const int _asciiLowerA = 0x61;

/// Compact display notation: `999`, `1.2K`, `3.4M`, `5.6B`, `7.8T`, `1.2aa`.
///
/// Values are truncated, never rounded up, so `999.99K` never shows as
/// `1000K`.
String formatBig(Big value) {
  if (value.isZero) return '0';
  final e = value.exponent;
  if (e < 0) return _truncate(value.toDouble(), 2);
  if (e < 3) {
    final d = value.toDouble();
    if (d < 10 && d != d.floorToDouble()) return _truncate(d, 1);
    return d.floor().toString();
  }
  final tier = e ~/ 3;
  final scaled = value.mantissa * math.pow(10, e % 3);
  final suffix = _suffix(tier);
  if (suffix == null) {
    return '${value.mantissa.toStringAsFixed(2)}e$e';
  }
  return '${_truncate(scaled, 1)}$suffix';
}

String? _suffix(int tier) {
  if (tier < _namedTiers.length) return _namedTiers[tier];
  final n = tier - _namedTiers.length;
  if (n >= _lettersCount * _lettersCount) return null;
  return String.fromCharCodes([
    _asciiLowerA + n ~/ _lettersCount,
    _asciiLowerA + n % _lettersCount,
  ]);
}

String _truncate(double value, int decimals) {
  final factor = math.pow(10, decimals);
  final cut = (value * factor).floor() / factor;
  if (cut == cut.floorToDouble()) return cut.toInt().toString();
  return cut.toStringAsFixed(decimals);
}
