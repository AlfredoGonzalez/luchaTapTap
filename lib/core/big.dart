import 'dart:math' as math;

/// Non-negative big number stored as `mantissa * 10^exponent`.
///
/// The mantissa is `0` (for zero) or in `[1, 10)`. Doubles overflow around
/// 1e308; endless leagues will go far beyond that, so every currency, damage
/// and HP value in the game uses this type.
///
/// Pure Dart: no Flutter imports.
class Big implements Comparable<Big> {
  const Big._(this.mantissa, this.exponent);

  final double mantissa;
  final int exponent;

  static const Big zero = Big._(0, 0);
  static const Big one = Big._(1, 0);

  /// Digits of precision of a double; below this gap a sum ignores the
  /// smaller operand.
  static const int _precisionDigits = 17;

  /// Relative tolerance used by [ceil] to absorb floating point noise
  /// (for example `12.000000000000002` is treated as `12`).
  static const double _ceilTolerance = 1e-12;

  /// Exponents whose value is certainly an integer in a double.
  static const int _integerExponent = 15;

  /// Values whose exponent is within this range add and subtract through plain
  /// doubles, which keeps everyday integer coin math exact (1000 - 204 is 796,
  /// not 796.0000000000001).
  static const int _plainDoubleExponent = 15;

  factory Big.fromDouble(double value) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'Big is non-negative');
    }
    if (value == 0) return zero;
    // The shortest round-trip representation keeps values such as 0.15 clean
    // (a division by a power of ten would turn it into 1.4999999999999998).
    final text = value.toStringAsExponential();
    final parts = text.split('e');
    return Big._(double.parse(parts[0]), int.parse(parts[1]));
  }

  factory Big.fromInt(int value) => Big.fromDouble(value.toDouble());

  /// Parses the output of [toJson].
  factory Big.fromJson(String text) {
    if (text == '0') return zero;
    final parts = text.split('e');
    if (parts.length != 2) {
      throw FormatException('Invalid Big value', text);
    }
    return _normalize(double.parse(parts[0]), int.parse(parts[1]));
  }

  /// `base ^ exponent` for `base > 0`, accurate for normal ranges and still
  /// valid far beyond the range of a double.
  static Big powOf(double base, num exponent) {
    if (base <= 0) throw ArgumentError.value(base, 'base', 'must be positive');
    if (exponent == 0) return one;
    final log10Value = exponent * (math.log(base) / math.ln10);
    if (log10Value.abs() < 300) {
      return Big.fromDouble(math.pow(base, exponent).toDouble());
    }
    final whole = log10Value.floor();
    return _normalize(math.pow(10, log10Value - whole).toDouble(), whole);
  }

  static Big _normalize(double mantissa, int exponent) {
    if (mantissa <= 0) return zero;
    var m = mantissa;
    var e = exponent;
    while (m >= 10) {
      m /= 10;
      e++;
    }
    while (m < 1) {
      // Jump close to the target to keep this loop short for tiny values.
      final shift = (math.log(m) / math.ln10).floor();
      if (shift < -1) {
        m *= math.pow(10, -shift);
        e += shift;
      } else {
        m *= 10;
        e--;
      }
    }
    return Big._(m, e);
  }

  bool get isZero => mantissa == 0;

  bool _plainDoubleRange(Big other) =>
      exponent.abs() <= _plainDoubleExponent &&
      other.exponent.abs() <= _plainDoubleExponent;

  Big operator +(Big other) {
    if (isZero) return other;
    if (other.isZero) return this;
    if (_plainDoubleRange(other)) {
      return Big.fromDouble(toDouble() + other.toDouble());
    }
    final gap = exponent - other.exponent;
    if (gap > _precisionDigits) return this;
    if (gap < -_precisionDigits) return other;
    if (gap >= 0) {
      return _normalize(
          mantissa + other.mantissa * math.pow(10, -gap), exponent);
    }
    return _normalize(
        other.mantissa + mantissa * math.pow(10, gap), other.exponent);
  }

  /// Subtraction clamped at zero: a Big is never negative.
  Big operator -(Big other) {
    if (other.isZero) return this;
    if (this <= other) return zero;
    if (_plainDoubleRange(other) && exponent.abs() <= _plainDoubleExponent) {
      return Big.fromDouble(toDouble() - other.toDouble());
    }
    final gap = exponent - other.exponent;
    if (gap > _precisionDigits) return this;
    return _normalize(
        mantissa - other.mantissa * math.pow(10, -gap), exponent);
  }

  Big operator *(Big other) {
    if (isZero || other.isZero) return zero;
    return _normalize(mantissa * other.mantissa, exponent + other.exponent);
  }

  Big operator /(Big other) {
    if (other.isZero) throw ArgumentError('Division by zero');
    if (isZero) return zero;
    return _normalize(mantissa / other.mantissa, exponent - other.exponent);
  }

  Big mulDouble(double factor) => this * Big.fromDouble(factor);

  Big divDouble(double divisor) => this / Big.fromDouble(divisor);

  Big sqrt() {
    if (isZero) return zero;
    if (exponent.isEven) {
      return _normalize(math.sqrt(mantissa), exponent ~/ 2);
    }
    return _normalize(math.sqrt(mantissa * 10), (exponent - 1) ~/ 2);
  }

  double log10() {
    if (isZero) throw StateError('log10 of zero');
    return exponent + math.log(mantissa) / math.ln10;
  }

  Big floor() {
    if (isZero || exponent >= _integerExponent) return this;
    if (exponent < 0) return zero;
    return Big.fromDouble(toDouble().floorToDouble());
  }

  /// Rounds up, ignoring floating point noise below [_ceilTolerance].
  Big ceil() {
    if (isZero || exponent >= _integerExponent) return this;
    final value = toDouble();
    final nearest = value.roundToDouble();
    if (nearest > 0 && (value - nearest).abs() <= _ceilTolerance * value) {
      return Big.fromDouble(nearest);
    }
    return Big.fromDouble(value.ceilToDouble());
  }

  /// Plain double value, or [double.infinity] when out of range.
  double toDouble() {
    if (isZero) return 0;
    if (exponent > 308) return double.infinity;
    if (exponent < -323) return 0;
    // Parsing the decimal text gives the correctly rounded double
    // (7.96e2 -> 796.0), where mantissa * 10^exponent would add noise.
    return double.parse('${mantissa}e$exponent');
  }

  /// Exact text form, safe to store in the save file. See [Big.fromJson].
  String toJson() => isZero ? '0' : '${mantissa}e$exponent';

  @override
  int compareTo(Big other) {
    if (isZero && other.isZero) return 0;
    if (isZero) return -1;
    if (other.isZero) return 1;
    if (exponent != other.exponent) return exponent.compareTo(other.exponent);
    return mantissa.compareTo(other.mantissa);
  }

  bool operator <(Big other) => compareTo(other) < 0;
  bool operator <=(Big other) => compareTo(other) <= 0;
  bool operator >(Big other) => compareTo(other) > 0;
  bool operator >=(Big other) => compareTo(other) >= 0;

  static Big max(Big a, Big b) => a >= b ? a : b;
  static Big min(Big a, Big b) => a <= b ? a : b;

  @override
  bool operator ==(Object other) =>
      other is Big && mantissa == other.mantissa && exponent == other.exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  @override
  String toString() => toJson();
}
