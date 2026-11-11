/// Turns variable frame times into a whole number of fixed simulation ticks.
/// The game advances in steps of 1 / ticksPerSecond so results do not depend
/// on the frame rate.
class FixedStepper {
  FixedStepper({required int ticksPerSecond, required this.maxCatchUpTicks})
      : assert(ticksPerSecond > 0),
        _stepMicros = Duration.microsecondsPerSecond ~/ ticksPerSecond;

  /// After a long stall at most this many ticks run; the rest is dropped.
  final int maxCatchUpTicks;
  final int _stepMicros;
  int _accumulatedMicros = 0;

  /// Adds [elapsed] and returns how many ticks must run now.
  int advance(Duration elapsed) {
    if (elapsed.isNegative) return 0;
    _accumulatedMicros += elapsed.inMicroseconds;
    var ticks = _accumulatedMicros ~/ _stepMicros;
    _accumulatedMicros -= ticks * _stepMicros;
    if (ticks > maxCatchUpTicks) ticks = maxCatchUpTicks;
    return ticks;
  }
}
