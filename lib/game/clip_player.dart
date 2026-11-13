import '../data/balance.dart';

/// Plays the clips of a fighter sprite sheet: which row and column to draw
/// now. Pure Dart so it is easy to test; the arena only asks for [row] and
/// [frame].
class ClipPlayer {
  ClipPlayer(this.config, {String start = 'idle'}) : _clip = start;

  final AnimationConfig config;
  String _clip;
  double _time = 0;
  String? _after = 'idle';
  bool _finished = false;
  int? _holdAt;

  /// Name of the clip being played.
  String get clip => _clip;

  /// True once a clip that does not loop has shown its last frame.
  bool get finished => _finished;

  int get row => config.rowOf(_clip);

  /// Column of the frame to draw.
  int get frame {
    final c = config.clips[_clip]!;
    final index = (_time * c.fps).floor();
    return c.loop ? index % c.frames : index.clamp(0, c.frames - 1);
  }

  /// Starts [name] from its first frame. When it ends (clips that do not loop)
  /// the player goes to [then]; null holds the last frame.
  /// [holdAt] freezes the clip on that frame until [release] (a kick held
  /// with the leg stretched out).
  void play(String name, {String? then = 'idle', int? holdAt}) {
    _clip = name;
    _holdAt = holdAt;
    _after = then;
    _time = 0;
    _finished = false;
  }

  /// Lets a held clip go on from the frame it is frozen on.
  void release() => _holdAt = null;

  void update(double dt) {
    _time += dt;
    final c = config.clips[_clip]!;
    final hold = _holdAt;
    if (hold != null) {
      final at = (hold + 0.5) / c.fps;
      if (_time > at) _time = at;
      return;
    }
    if (!c.loop && _time >= c.seconds) {
      final next = _after;
      if (next == null) {
        _time = c.seconds;
        _finished = true;
      } else {
        play(next);
      }
    }
  }
}
