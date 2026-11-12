import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/finisher_gesture.dart';

import '../test_content.dart';

typedef P = ({double x, double y});

/// Points of a circle drawn on screen: [clockwise] as the player sees it
/// (y grows downward), starting at [startDeg] (0 = right, 90 = bottom).
List<P> circle({
  double cx = 90,
  double cy = 100,
  double r = 20,
  bool clockwise = true,
  double startDeg = 180, // left
  double sweepDeg = 360,
  int steps = 48,
}) {
  final result = <P>[];
  for (var i = 0; i <= steps; i++) {
    final a = (startDeg + (clockwise ? 1 : -1) * sweepDeg * i / steps) * math.pi / 180;
    result.add((x: cx + r * math.cos(a), y: cy + r * math.sin(a)));
  }
  return result;
}

void main() {
  final config = loadTestContent().balance.gesture;
  late FinisherGesture g;
  var t = 0.0;

  setUp(() {
    g = FinisherGesture(config);
    t = 0;
  });

  /// Draws [points] as one stroke.
  GestureStatus stroke(List<P> points, {double dt = 0.02}) {
    g.pointerDown(points.first.x, points.first.y, t);
    for (final p in points.skip(1)) {
      t += dt;
      g.pointerMove(p.x, p.y, t);
    }
    return g.pointerUp(t);
  }

  group('the right gesture', () {
    test('two separate circles: clockwise, then counterclockwise', () {
      // First circle starts on the left and goes over the top (clockwise).
      expect(stroke(circle(clockwise: true)), GestureStatus.drawing);
      expect(g.circlesDone, 1);
      t += 0.3;
      // Second starts on the right and goes over the top (counterclockwise).
      expect(stroke(circle(clockwise: false, startDeg: 0)), GestureStatus.success);
    });

    test('one continuous figure eight', () {
      final first = circle(cx: 60, clockwise: true);
      // Second circle continues from where the first ended (the left point of
      // the first loop) the other way round, on its own centre to the left.
      final second = circle(cx: 20, clockwise: false, startDeg: 0);
      expect(stroke([...first, ...second]), GestureStatus.success);
    });

    test('a bigger and a smaller circle still count', () {
      expect(stroke(circle(r: 40)), GestureStatus.drawing);
      expect(stroke(circle(r: 12, clockwise: false, startDeg: 0)), GestureStatus.success);
    });

    test('any starting point works', () {
      expect(stroke(circle(startDeg: 270)), GestureStatus.drawing);
      expect(stroke(circle(clockwise: false, startDeg: 90, cx: 30, cy: 40)), GestureStatus.success);
    });

    test('a slightly wobbly circle is accepted', () {
      final rng = math.Random(4);
      List<P> wobble(List<P> pts) => [
            for (final p in pts) (x: p.x + rng.nextDouble() * 1.2 - 0.6, y: p.y + rng.nextDouble() * 1.2 - 0.6),
          ];
      expect(stroke(wobble(circle())), GestureStatus.drawing);
      expect(stroke(wobble(circle(clockwise: false, startDeg: 0))), GestureStatus.success);
    });

    test('the trail records what was drawn', () {
      stroke(circle());
      expect(g.trail.length, greaterThan(20));
    });
  });

  group('wrong gestures fail', () {
    test('the second circle goes the same way', () {
      stroke(circle(clockwise: true));
      expect(stroke(circle(clockwise: true)), GestureStatus.failed);
    });

    test('the circles are in the wrong order', () {
      expect(stroke(circle(clockwise: false)), GestureStatus.failed);
    });

    test('a straight line fails as soon as the finger lifts', () {
      final line = [for (var i = 0; i <= 20; i++) (x: 20.0 + i * 3, y: 100.0)];
      expect(stroke(line), GestureStatus.failed);
    });

    test('a short arc that is lifted fails', () {
      expect(stroke(circle(sweepDeg: 90)), GestureStatus.failed);
    });

    test('tiny circles never succeed', () {
      stroke(circle(r: 3, steps: 60));
      stroke(circle(r: 3, clockwise: false, startDeg: 0, steps: 60));
      expect(g.status, isNot(GestureStatus.success));
    });

    test('a very flat ellipse never succeeds', () {
      List<P> flat(bool cw, double start) => [
            for (final p in circle(r: 30, clockwise: cw, startDeg: start))
              (x: p.x, y: 100 + (p.y - 100) * 0.2),
          ];
      stroke(flat(true, 180));
      stroke(flat(false, 0));
      expect(g.status, isNot(GestureStatus.success));
    });

    test('too slow: the time limit runs out between the circles', () {
      stroke(circle(clockwise: true));
      t += config.timeLimitSeconds + 1;
      expect(g.tick(t), GestureStatus.failed);
    });

    test('too slow: the limit also applies while drawing', () {
      final slow = circle(clockwise: true);
      expect(stroke(slow, dt: 0.3), GestureStatus.failed); // 48 steps x 0.3 s
    });
  });

  group('taps are not gestures', () {
    test('a tap does nothing', () {
      g.pointerDown(50, 50, 0);
      expect(g.pointerUp(0.05), GestureStatus.idle);
      expect(g.trail, isEmpty);
    });

    test('a tiny movement is still a tap', () {
      g.pointerDown(50, 50, 0);
      g.pointerMove(53, 51, 0.02);
      expect(g.pointerUp(0.05), GestureStatus.idle);
    });

    test('many taps never fail the gesture', () {
      for (var i = 0; i < 30; i++) {
        g.pointerDown(50.0 + i, 50, i * 0.1);
        g.pointerUp(i * 0.1 + 0.03);
      }
      expect(g.status, GestureStatus.idle);
    });

    test('a tap between the two circles is ignored', () {
      stroke(circle(clockwise: true));
      g.pointerDown(10, 10, t);
      g.pointerUp(t + 0.04);
      t += 0.2;
      expect(g.status, GestureStatus.drawing);
      expect(stroke(circle(clockwise: false, startDeg: 0)), GestureStatus.success);
    });
  });

  group('state', () {
    test('after success or failure, input is ignored until reset', () {
      stroke(circle(clockwise: false));
      expect(g.status, GestureStatus.failed);
      stroke(circle(clockwise: true));
      expect(g.status, GestureStatus.failed);
      g.reset();
      expect(g.status, GestureStatus.idle);
      expect(stroke(circle(clockwise: true)), GestureStatus.drawing);
    });

    test('the first direction can be flipped in balance.json', () {
      final flipped = loadTestContent((f) => f['balance.json']!['gesture']['firstDirection'] = 'counterclockwise')
          .balance
          .gesture;
      final r = FinisherGesture(flipped);
      void draw(List<P> pts) {
        r.pointerDown(pts.first.x, pts.first.y, t);
        for (final p in pts.skip(1)) {
          t += 0.02;
          r.pointerMove(p.x, p.y, t);
        }
        r.pointerUp(t);
      }

      draw(circle(clockwise: false));
      draw(circle(clockwise: true, startDeg: 0));
      expect(r.status, GestureStatus.success);
    });

    test('config rejects an unknown direction', () {
      expect(
        () => loadTestContent((f) => f['balance.json']!['gesture']['firstDirection'] = 'sideways'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
