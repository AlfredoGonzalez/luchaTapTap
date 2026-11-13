import 'rng.dart';

/// Settings of the kick challenge (they live in `balance.json`, `kick`).
class KickSettings {
  const KickSettings({
    required this.targets,
    required this.circleSeconds,
    required this.startDelaySeconds,
    required this.gapSeconds,
    required this.minMoveFraction,
  });

  /// Circles the player has to tap, one after the other.
  final int targets;

  /// Seconds a circle takes to shrink to nothing.
  final double circleSeconds;

  /// Wait between the full combo bar and the first circle.
  final double startDelaySeconds;

  /// Wait between a tapped circle and the next one.
  final double gapSeconds;

  /// Each circle appears at least this fraction of the area's size away from
  /// the previous one, so the finger has to travel.
  final double minMoveFraction;
}

enum KickStatus { idle, active, success, failed }

/// The kick: once the combo bar is full, [KickSettings.targets] circles show up
/// one at a time at random places; each one shrinks and vanishes. Tapping every
/// circle in time lands the kick; letting one vanish loses it. Pure Dart: the
/// screen only asks where the circle is and tells when it was tapped.
class KickChallenge {
  KickChallenge(this.settings, this._rng);

  final KickSettings settings;
  final SeededRng _rng;

  KickStatus _status = KickStatus.idle;
  int _hits = 0;
  bool _circleOn = false;
  double _wait = 0;
  double _age = 0;
  double _x = 0.5;
  double _y = 0.5;

  KickStatus get status => _status;
  bool get isActive => _status == KickStatus.active;

  /// Circles tapped so far.
  int get hits => _hits;

  /// A circle is on screen now.
  bool get circleVisible => _circleOn;

  /// Where the circle is, as fractions (0 to 1) of the play area.
  double get x => _x;
  double get y => _y;

  /// How much of the circle's life is left, from 1 (just appeared) to 0.
  double get remaining =>
      _circleOn ? (1 - _age / settings.circleSeconds).clamp(0.0, 1.0) : 0;

  /// Starts a new challenge: the first circle comes after the start delay.
  void start() {
    _status = KickStatus.active;
    _hits = 0;
    _circleOn = false;
    _wait = settings.startDelaySeconds;
    _age = 0;
  }

  void reset() {
    _status = KickStatus.idle;
    _hits = 0;
    _circleOn = false;
  }

  /// Moves time forward by [dt] seconds.
  void tick(double dt) {
    if (_status != KickStatus.active) return;
    if (!_circleOn) {
      _wait -= dt;
      if (_wait <= 0) _spawn();
      return;
    }
    _age += dt;
    if (_age >= settings.circleSeconds) {
      _circleOn = false;
      _status = KickStatus.failed;
    }
  }

  /// The player tapped the circle. False when there was none to tap.
  bool hit() {
    if (_status != KickStatus.active || !_circleOn) return false;
    _hits++;
    _circleOn = false;
    if (_hits >= settings.targets) {
      _status = KickStatus.success;
    } else {
      _wait = settings.gapSeconds;
    }
    return true;
  }

  void _spawn() {
    var nx = _rng.nextDouble();
    var ny = _rng.nextDouble();
    // Not too close to where the last circle was (the first one is free).
    if (_hits > 0) {
      for (var i = 0; i < 12; i++) {
        final dx = nx - _x;
        final dy = ny - _y;
        if (dx * dx + dy * dy >=
            settings.minMoveFraction * settings.minMoveFraction) {
          break;
        }
        nx = _rng.nextDouble();
        ny = _rng.nextDouble();
      }
    }
    _x = nx;
    _y = ny;
    _age = 0;
    _circleOn = true;
  }
}
