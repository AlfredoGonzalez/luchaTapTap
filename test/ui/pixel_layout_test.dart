import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/ui/pixel_scale.dart';

PixelLayout layout(double w, double h, double dpr, {int maxW = 270, int maxH = 480}) =>
    PixelLayout.compute(
      width: w,
      height: h,
      devicePixelRatio: dpr,
      maxVirtualWidth: maxW,
      maxVirtualHeight: maxH,
    );

void main() {
  group('a typical phone', () {
    test('360 x 640 dp at 3x is exactly 180 x 320 virtual pixels at 6 device pixels', () {
      final l = layout(360, 640, 3);
      expect([l.pixelsPerVirtual, l.virtualWidth, l.virtualHeight], [6, 180, 320]);
      expect(l.scale, 2);
      expect([l.offsetX, l.offsetY], [0, 0]);
    });

    test('a tall phone (19.5:9) grows the canvas taller, not wider', () {
      final l = layout(360, 780, 3);
      expect([l.pixelsPerVirtual, l.virtualWidth, l.virtualHeight], [6, 180, 390]);
    });

    test('a 2.625x phone uses whole device pixels, not whole dp', () {
      // 411 x 891 dp at 2.625 = 1079 x 2339 device pixels.
      final l = layout(411.4, 891.4, 2.625);
      expect(l.pixelsPerVirtual, 5);
      expect(l.pixelsPerVirtual * l.virtualWidth, lessThanOrEqualTo(1080));
      expect(l.virtualWidth, greaterThanOrEqualTo(180));
      expect(l.virtualHeight, greaterThanOrEqualTo(320));
      // Whole device pixels: scale * devicePixelRatio is an integer.
      expect(l.scale * 2.625, closeTo(5, 1e-9));
    });
  });

  group('it uses the whole window', () {
    test('a narrow tall browser window at 1x grows the canvas instead of leaving bars', () {
      final l = layout(473, 990, 1);
      expect(l.pixelsPerVirtual, 2);
      expect(l.virtualWidth, 236); // 473 / 2, not the old 180
      expect(l.virtualHeight, 480); // capped by balance.json (990 / 2 = 495)
      expect(l.offsetX, 0);
      expect(l.offsetY, 15);
    });

    test('a landscape desktop window keeps the canvas portrait-friendly', () {
      final l = layout(1920, 1080, 1);
      expect(l.pixelsPerVirtual, 3);
      expect(l.virtualWidth, 270); // capped
      expect(l.virtualHeight, 360);
      expect(l.offsetX, (1920 - 270 * 3) / 2);
    });

    test('a tablet fills most of the screen', () {
      final l = layout(768, 1024, 2);
      expect(l.pixelsPerVirtual, 6);
      expect(l.virtualWidth, 256);
      expect(l.virtualHeight, 341);
    });

    test('the canvas never exceeds the window', () {
      for (final size in [(320.0, 480.0), (360.0, 640.0), (412.0, 915.0), (800.0, 600.0), (1280.0, 720.0), (2560.0, 1440.0)]) {
        for (final dpr in [1.0, 1.5, 2.0, 2.625, 3.0, 3.5]) {
          final l = layout(size.$1, size.$2, dpr);
          expect(l.size.width, lessThanOrEqualTo(size.$1 + 1e-6), reason: '$size @$dpr');
          expect(l.size.height, lessThanOrEqualTo(size.$2 + 1e-6), reason: '$size @$dpr');
          expect(l.virtualWidth, greaterThanOrEqualTo(180));
          expect(l.virtualHeight, greaterThanOrEqualTo(320));
        }
      }
    });

    test('every virtual pixel is a whole number of device pixels', () {
      for (final dpr in [1.0, 1.25, 1.5, 2.0, 2.625, 2.75, 3.0, 3.5]) {
        final l = layout(411, 914, dpr);
        expect(l.scale * dpr, closeTo(l.pixelsPerVirtual.toDouble(), 1e-9));
      }
    });
  });

  group('limits come from balance.json', () {
    test('a smaller maximum width leaves a border', () {
      final l = layout(1920, 1080, 1, maxW: 200);
      expect(l.virtualWidth, 200);
    });

    test('a window smaller than the base design still works', () {
      final l = layout(120, 200, 1);
      expect(l.pixelsPerVirtual, 1);
      expect(l.virtualWidth, 180);
    });
  });
}
