import 'dart:math' as math;

import '../data/balance.dart';

enum GestureStatus {
  /// Nothing being drawn (or only taps).
  idle,

  /// A circle is in progress.
  drawing,

  /// Both circles were drawn correctly.
  success,

  /// The drawing was wrong or too slow.
  failed,
}

/// Recognizes the finisher gesture: a circle in one direction and then a circle
/// in the opposite direction, drawn as one stroke (a figure eight) or as two.
///
/// Pure Dart. Positions are in virtual pixels and times in seconds. The
/// recognizer adds up how much the path turns (positive is clockwise on
/// screen); a circle is complete when it has turned [GestureConfig.loopDegrees].
class FinisherGesture {
  FinisherGesture(this.config);

  final GestureConfig config;

  GestureStatus _status = GestureStatus.idle;
  final List<({double x, double y})> _trail = [];
  final List<bool> _loops = []; // true = clockwise, in the order drawn

  // Current circle.
  final List<({double x, double y})> _loopPoints = [];
  double _loopTurn = 0;

  // Current stroke.
  bool _touching = false;
  double _strokeLength = 0;
  double _strokeTurn = 0;
  ({double x, double y})? _last;
  ({double x, double y})? _lastDir;

  double? _startedAt;

  GestureStatus get status => _status;

  /// Points drawn so far, for showing the trail.
  List<({double x, double y})> get trail => List.unmodifiable(_trail);

  /// Circles completed so far (0, 1 or 2).
  int get circlesDone => _loops.length;

  bool get isDrawing => _status == GestureStatus.drawing;

  void reset() {
    _status = GestureStatus.idle;
    _trail.clear();
    _loops.clear();
    _loopPoints.clear();
    _loopTurn = 0;
    _touching = false;
    _strokeLength = 0;
    _strokeTurn = 0;
    _last = null;
    _lastDir = null;
    _startedAt = null;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  void pointerDown(double x, double y, double t) {
    if (_status == GestureStatus.success || _status == GestureStatus.failed) return;
    _touching = true;
    _strokeLength = 0;
    _strokeTurn = 0;
    _last = (x: x, y: y);
    _lastDir = null; // a new stroke does not continue the previous direction
    if (_status == GestureStatus.drawing) {
      // A new stroke after a finished circle starts the next circle afresh,
      // so the jump between the two strokes is not part of its shape.
      if (_loopTurn.abs() < _radians(_freshLoopDegrees)) {
        _loopPoints.clear();
        _loopTurn = 0;
      }
      _trail.add((x: x, y: y));
      _loopPoints.add((x: x, y: y));
    }
  }

  /// A circle with less turning than this when the finger lifts counts as not
  /// begun, so the next stroke starts a new circle.
  static const double _freshLoopDegrees = 90;

  void pointerMove(double x, double y, double t) {
    if (!_touching || _last == null) return;
    if (_status == GestureStatus.success || _status == GestureStatus.failed) return;
    final last = _last!;
    final dx = x - last.x;
    final dy = y - last.y;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < config.sampleStep) return;

    final dir = (x: dx, y: dy);
    final previous = _lastDir;
    if (previous != null) {
      final cross = previous.x * dir.y - previous.y * dir.x;
      final dot = previous.x * dir.x + previous.y * dir.y;
      final turn = math.atan2(cross, dot);
      _strokeTurn += turn;
      if (_status == GestureStatus.drawing) _loopTurn += turn;
    }
    _lastDir = dir;
    _last = (x: x, y: y);
    _strokeLength += dist;

    if (_status == GestureStatus.idle && _strokeLength >= config.minStrokeLength) {
      // The touch is long enough to be a stroke: the attempt starts here.
      _status = GestureStatus.drawing;
      _startedAt = t;
      _loopTurn = _strokeTurn;
      _loopPoints
        ..clear()
        ..add((x: last.x, y: last.y));
      _trail.add((x: last.x, y: last.y));
    }
    if (_status != GestureStatus.drawing) return;

    _trail.add((x: x, y: y));
    _loopPoints.add((x: x, y: y));
    if (_timedOut(t)) {
      _status = GestureStatus.failed;
      return;
    }
    if (_loopTurn.abs() >= _radians(config.loopDegrees)) _finishLoop();
  }

  /// The finger was lifted. Returns the new status.
  GestureStatus pointerUp(double t) {
    if (!_touching) return _status;
    _touching = false;
    if (_status == GestureStatus.drawing) {
      if (_timedOut(t)) {
        _status = GestureStatus.failed;
      } else if (_strokeLength >= config.minStrokeLength &&
          _strokeTurn.abs() < _radians(config.minArcDegrees)) {
        // Lifted after a stroke that was not even a good arc.
        _status = GestureStatus.failed;
      }
    }
    // An idle stroke that never got long enough was just a tap: ignore it.
    return _status;
  }

  /// Checks the time limit while the finger is held still.
  GestureStatus tick(double t) {
    if (_status == GestureStatus.drawing && _timedOut(t)) _status = GestureStatus.failed;
    return _status;
  }

  bool _timedOut(double t) {
    final start = _startedAt;
    return start != null && t - start > config.timeLimitSeconds;
  }

  void _finishLoop() {
    final clockwise = _loopTurn > 0;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in _loopPoints) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final w = maxX - minX;
    final h = maxY - minY;
    final size = math.max(w, h);
    final small = math.min(w, h);
    final first = _loopPoints.first;
    final end = _loopPoints.last;
    final gap = math.sqrt(math.pow(end.x - first.x, 2) + math.pow(end.y - first.y, 2));

    final roundEnough = size >= config.minLoopSize &&
        small > 0 &&
        size / small <= config.maxLoopAspect &&
        gap <= config.closeFraction * size;
    final expectedClockwise = _loops.isEmpty ? config.firstClockwise : !config.firstClockwise;
    if (!roundEnough || clockwise != expectedClockwise) {
      _status = GestureStatus.failed;
      return;
    }
    _loops.add(clockwise);
    if (_loops.length == 2) {
      _status = GestureStatus.success;
      return;
    }
    // Start the second circle where the first ended.
    _loopPoints
      ..clear()
      ..add(end);
    _loopTurn = 0;
  }
}
