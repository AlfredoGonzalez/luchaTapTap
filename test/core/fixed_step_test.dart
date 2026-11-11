import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/fixed_step.dart';

void main() {
  test('10 ticks per second: 100 ms gives one tick', () {
    final s = FixedStepper(ticksPerSecond: 10, maxCatchUpTicks: 100);
    expect(s.advance(const Duration(milliseconds: 100)), 1);
  });

  test('remainders accumulate across frames', () {
    final s = FixedStepper(ticksPerSecond: 10, maxCatchUpTicks: 100);
    var total = 0;
    for (var i = 0; i < 60; i++) {
      total += s.advance(const Duration(microseconds: 16667)); // 60 fps
    }
    expect(total, 10); // one second of frames = 10 ticks
  });

  test('result does not depend on frame rate', () {
    int run(Duration frame, int frames) {
      final s = FixedStepper(ticksPerSecond: 10, maxCatchUpTicks: 1000);
      var total = 0;
      for (var i = 0; i < frames; i++) {
        total += s.advance(frame);
      }
      return total;
    }

    expect(run(const Duration(milliseconds: 10), 1000), 100);
    expect(run(const Duration(milliseconds: 50), 200), 100);
    expect(run(const Duration(milliseconds: 250), 40), 100);
  });

  test('a long stall is capped', () {
    final s = FixedStepper(ticksPerSecond: 10, maxCatchUpTicks: 5);
    expect(s.advance(const Duration(seconds: 60)), 5);
    expect(s.advance(const Duration(milliseconds: 100)), 1); // no backlog left
  });

  test('negative time is ignored', () {
    final s = FixedStepper(ticksPerSecond: 10, maxCatchUpTicks: 5);
    expect(s.advance(const Duration(milliseconds: -50)), 0);
  });
}
