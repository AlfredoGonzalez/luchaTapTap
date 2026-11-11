import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../core/palette.dart';
import '../data/balance.dart';
import '../data/content_models.dart';
import '../ui/palette_color.dart';

/// Placeholder arena: flat rectangles in palette colors. Final sprites replace
/// the fighters later without changing this game's API.
///
/// Everything is laid out on the virtual canvas (180 wide) at whole pixels.
class ArenaGame extends FlameGame {
  ArenaGame({
    required this.virtualSize,
    required this.fx,
    required this.onTap,
    required this.opponent,
  });

  final Vector2 virtualSize;
  final FxConfig fx;
  final void Function() onTap;

  /// Opponent currently shown (updated by [showOpponent]).
  OpponentDef opponent;
  late final _Fighter _player;
  late _Fighter _enemy;
  int _hitCount = 0;

  /// Floor line: fighters stand with their feet here.
  double get _floorY => virtualSize.y - _floorHeight;
  static const double _floorHeight = 18;
  static const double _sideMargin = 14;

  @override
  Color backgroundColor() => Palette.navy.color;

  @override
  Future<void> onLoad() async {
    camera.viewport = FixedResolutionViewport(resolution: virtualSize);
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    world.add(_ArenaBackdrop(size: virtualSize, floorY: _floorY));
    _player = _Fighter(
      bodyColor: Palette.luchaRed,
      accentColor: Palette.violet, // the mask: reserved mask colors
      spriteSize: regularSpriteSize,
      idleFps: fx.idleFps,
      flashSeconds: fx.hitFlashSeconds,
    )..position = Vector2(_sideMargin, _floorY - regularSpriteSize);
    _enemy = _buildEnemy(opponent);
    world.addAll([_player, _enemy, _TapArea(size: virtualSize, onTap: onTap)]);
  }

  _Fighter _buildEnemy(OpponentDef o) {
    final size = o.size.toDouble();
    return _Fighter(
      bodyColor: Palette.byId[o.placeholderColor]!,
      accentColor: Palette.byId[o.placeholderColor]!,
      spriteSize: o.size,
      idleFps: fx.idleFps,
      flashSeconds: fx.hitFlashSeconds,
    )..position = Vector2(virtualSize.x - _sideMargin - size, _floorY - size);
  }

  /// Shows a new opponent (after a defeat).
  void showOpponent(OpponentDef next) {
    opponent = next;
    if (!isLoaded) return;
    _enemy.removeFromParent();
    _enemy = _buildEnemy(next);
    world.add(_enemy);
  }

  /// Reaction to a hit: flash the opponent and float the damage number.
  void hit(String damageText, {required bool isTap}) {
    if (!isLoaded) return;
    _enemy.flash();
    if (!isTap) return;
    final jitter = fx.damageNumberJitterPx;
    final offset = jitter == 0 ? 0 : (_hitCount * 7) % (2 * jitter + 1) - jitter;
    _hitCount++;
    final spawn = Vector2(
      _enemy.position.x + _enemy.size.x / 2 + offset,
      _enemy.position.y - 2,
    );
    world.add(_DamageNumber(
      text: damageText,
      start: spawn,
      risePx: fx.damageNumberRisePx.toDouble(),
      seconds: fx.damageNumberSeconds,
    ));
  }
}

class _ArenaBackdrop extends PositionComponent {
  _ArenaBackdrop({required Vector2 size, required this.floorY}) : super(size: size);

  final double floorY;

  @override
  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    // Wall.
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, floorY), paint..color = Palette.navy.color);
    // Ropes.
    for (final y in [floorY - 30, floorY - 20, floorY - 10]) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.x, 2), paint..color = Palette.luchaRed.color);
    }
    // Floor.
    canvas.drawRect(Rect.fromLTWH(0, floorY, size.x, size.y - floorY), paint..color = Palette.sand.color);
    canvas.drawRect(Rect.fromLTWH(0, floorY, size.x, 1), paint..color = Palette.ink.color);
  }
}

/// A placeholder wrestler: body block, head block, 1-pixel Ink outline.
class _Fighter extends PositionComponent {
  _Fighter({
    required this.bodyColor,
    required this.accentColor,
    required int spriteSize,
    required this.idleFps,
    required this.flashSeconds,
  }) : super(size: Vector2.all(spriteSize.toDouble()));

  final int bodyColor;
  final int accentColor;
  final int idleFps;
  final double flashSeconds;

  /// Idle bob: body drops 1 pixel on the middle frames, like the 4-frame idle.
  static const List<int> _idleBob = [0, 1, 1, 0];

  double _time = 0;
  double _flashLeft = 0;
  late final double _baseY = position.y;

  void flash() => _flashLeft = flashSeconds;

  @override
  void update(double dt) {
    _time += dt;
    if (_flashLeft > 0) _flashLeft = math.max(0, _flashLeft - dt);
    final frame = (_time * idleFps).floor() % _idleBob.length;
    position.y = (_baseY + _idleBob[frame]).roundToDouble();
    position.x = position.x.roundToDouble();
  }

  @override
  void render(Canvas canvas) {
    final flashing = _flashLeft > 0;
    final paint = Paint()..isAntiAlias = false;
    final w = size.x;
    final h = size.y;
    final headSize = (w * 0.42).roundToDouble();
    final bodyTop = headSize - 2;

    void block(Rect rect, int color) {
      canvas.drawRect(rect, paint..color = Palette.ink.color);
      canvas.drawRect(rect.deflate(1), paint..color = (flashing ? Palette.white : color).color);
    }

    // Legs, torso, head (head uses the accent color: the mask).
    block(Rect.fromLTWH(w * 0.22, h * 0.72, w * 0.22, h * 0.28), bodyColor);
    block(Rect.fromLTWH(w * 0.56, h * 0.72, w * 0.22, h * 0.28), bodyColor);
    block(Rect.fromLTWH(w * 0.16, bodyTop, w * 0.68, h * 0.72 - bodyTop), bodyColor);
    block(Rect.fromLTWH((w - headSize) / 2, 0, headSize, headSize), accentColor);
  }
}

class _TapArea extends PositionComponent with TapCallbacks {
  _TapArea({required Vector2 size, required this.onTap}) : super(size: size);

  final void Function() onTap;

  @override
  void onTapDown(TapDownEvent event) => onTap();
}

class _DamageNumber extends TextComponent {
  _DamageNumber({
    required String text,
    required this.start,
    required this.risePx,
    required this.seconds,
  }) : super(
          text: text,
          anchor: Anchor.bottomCenter,
          textRenderer: TextPaint(
            style: TextStyle(
              color: Palette.bone.color,
              fontSize: 8,
              height: 1,
              shadows: [Shadow(color: Palette.ink.color, offset: const Offset(1, 1))],
            ),
          ),
        );

  final Vector2 start;
  final double risePx;
  final double seconds;
  double _age = 0;

  @override
  void onMount() {
    super.onMount();
    position = start.clone();
    priority = 10;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= seconds) {
      removeFromParent();
      return;
    }
    position = Vector2(start.x.roundToDouble(), (start.y - risePx * (_age / seconds)).roundToDouble());
  }
}
