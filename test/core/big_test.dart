import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/core/number_format.dart';

Big b(double v) => Big.fromDouble(v);

void main() {
  group('Big basics', () {
    test('normalizes mantissa to [1, 10)', () {
      expect(b(1234.5).mantissa, closeTo(1.2345, 1e-12));
      expect(b(1234.5).exponent, 3);
      expect(b(0.015).exponent, -2);
      expect(b(0.15).mantissa, 1.5); // no 1.4999999999999998 noise
    });

    test('zero and one', () {
      expect(Big.zero.isZero, isTrue);
      expect(b(0), Big.zero);
      expect(b(1), Big.one);
    });

    test('rejects negative, NaN and infinity', () {
      expect(() => b(-1), throwsArgumentError);
      expect(() => b(double.nan), throwsArgumentError);
      expect(() => b(double.infinity), throwsArgumentError);
    });

    test('comparison', () {
      expect(b(5) < b(6), isTrue);
      expect(b(1000) > b(999.99), isTrue);
      expect(Big.zero < b(0.001), isTrue);
      expect(b(5) >= b(5), isTrue);
      expect(Big.powOf(10, 400) > Big.powOf(10, 399), isTrue);
    });
  });

  group('Big arithmetic', () {
    test('addition', () {
      expect((b(1.5) + b(2.5)).toDouble(), closeTo(4, 1e-12));
      expect((b(999) + b(1)).toDouble(), closeTo(1000, 1e-9));
      expect(b(5) + Big.zero, b(5));
      expect(Big.zero + b(5), b(5));
    });

    test('adding a negligible value is ignored, not corrupting', () {
      final huge = Big.powOf(10, 100);
      expect(huge + b(1), huge);
    });

    test('everyday integer math stays exact', () {
      expect(b(1000) - b(204), b(796));
      expect(b(0.1) + b(0.2), b(0.30000000000000004)); // plain double semantics
      expect((b(1000) - b(204)).toDouble(), 796.0);
    });

    test('subtraction clamps at zero', () {
      expect((b(10) - b(4)).toDouble(), closeTo(6, 1e-12));
      expect(b(4) - b(10), Big.zero);
      expect(b(5) - b(5), Big.zero);
    });

    test('multiplication and division', () {
      expect((b(12) * b(12)).toDouble(), closeTo(144, 1e-9));
      expect((b(144) / b(12)).toDouble(), closeTo(12, 1e-9));
      expect(b(5) * Big.zero, Big.zero);
      expect(() => b(5) / Big.zero, throwsArgumentError);
    });

    test('works far beyond double range', () {
      final a = Big.powOf(10, 1000);
      final c = a * a;
      expect(c.exponent, 2000);
      expect((c / a), a);
      expect(a.toDouble(), double.infinity);
    });

    test('powOf matches dart pow in the normal range', () {
      expect(Big.powOf(1.55, 10).toDouble(), closeTo(math.pow(1.55, 10), 1e-9));
      expect(Big.powOf(1.15, 0), Big.one);
      expect(Big.powOf(1.15, 1).toDouble(), 1.15);
    });

    test('powOf stays accurate beyond double range', () {
      // 1.55^3000 = 10^(3000*log10(1.55))
      final value = Big.powOf(1.55, 3000);
      expect(value.log10(), closeTo(3000 * 0.19033169817029893, 1e-6));
    });

    test('sqrt', () {
      expect(b(144).sqrt().toDouble(), closeTo(12, 1e-9));
      expect(b(1000000).sqrt().toDouble(), closeTo(1000, 1e-9));
      expect(b(200).sqrt().toDouble(), closeTo(14.142135, 1e-5));
      expect(Big.powOf(10, 1001).sqrt().log10(), closeTo(500.5, 1e-9));
    });

    test('floor and ceil', () {
      expect(b(12.9).floor(), b(12));
      expect(b(0.5).floor(), Big.zero);
      expect(b(12.1).ceil(), b(13));
      expect(b(12).ceil(), b(12));
      expect(b(12.000000000000002).ceil(), b(12)); // float noise is absorbed
      expect(b(0.3).ceil(), b(1));
    });
  });

  group('Big json', () {
    test('round trip is exact', () {
      for (final v in [Big.zero, b(1), b(1.15), b(123456.789), Big.powOf(1.55, 5000)]) {
        expect(Big.fromJson(v.toJson()), v);
      }
    });

    test('rejects garbage', () {
      expect(() => Big.fromJson('banana'), throwsFormatException);
    });
  });

  group('formatBig', () {
    test('small numbers', () {
      expect(formatBig(Big.zero), '0');
      expect(formatBig(b(7)), '7');
      expect(formatBig(b(999)), '999');
      expect(formatBig(b(1.5)), '1.5');
      expect(formatBig(b(0.25)), '0.25');
    });

    test('thousands, millions, billions', () {
      expect(formatBig(b(1000)), '1K');
      expect(formatBig(b(1234)), '1.2K');
      expect(formatBig(b(12345)), '12.3K');
      expect(formatBig(b(123456)), '123.4K');
      expect(formatBig(b(3.4e6)), '3.4M');
      expect(formatBig(b(5.6e9)), '5.6B');
      expect(formatBig(b(7.8e12)), '7.8T');
    });

    test('truncates instead of rounding up', () {
      expect(formatBig(b(999999)), '999.9K');
      expect(formatBig(b(1999)), '1.9K');
    });

    test('letters after T, scientific after letters', () {
      expect(formatBig(b(1.2e15)), '1.2aa');
      expect(formatBig(b(1.2e18)), '1.2ab');
      expect(formatBig(Big.powOf(10, 3 * (5 + 26 * 26) + 1)), endsWith('e${3 * (5 + 26 * 26) + 1}'));
    });
  });
}
