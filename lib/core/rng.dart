/// Small seeded random generator (mulberry32) whose state is a single integer,
/// so it can be saved and restored: tests and replays are reproducible.
///
/// Targets the Dart VM (64-bit ints), which is what Android runs.
class SeededRng {
  SeededRng(int seed) : _state = seed & _mask;

  static const int _mask = 0xFFFFFFFF;
  static const double _range = 4294967296.0;

  int _state;

  /// Current state; pass it to [SeededRng.new] to continue the same sequence.
  int get state => _state;

  static int _imul(int a, int b) => (a * b) & _mask;

  /// Next value in `[0, 1)`.
  double nextDouble() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _imul(_state ^ (_state >>> 15), 1 | _state);
    t = ((t + _imul(t ^ (t >>> 7), 61 | t)) & _mask) ^ t;
    return ((t ^ (t >>> 14)) & _mask) / _range;
  }
}
