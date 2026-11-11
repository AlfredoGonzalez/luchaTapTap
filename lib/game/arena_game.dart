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
    required this.onLuckyTap,
    required this.opponent,
    this.playerMaskColor = Palette.violet,
  });

  final Vector2 virtualSize;
  final FxConfig fx;
  final void Function() onTap;
  final void Function() onLuckyTap;

  /// Placeholder color of the player's head (the equipped mask's base color).
  int playerMaskColor;

  /// Opponent currently shown (updated by [showOpponent]).
  OpponentDef opponent;
  late _Fighter _player;
  _LuckyPickup? _lucky;
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
    _player = _buildPlayer();
    _enemy = _buildEnemy(opponent);
    world.addAll([_player, _enemy, _TapArea(size: virtualSize, onTap: onTap)]);
  }

  _Fighter _buildPlayer() => _Fighter(
        bodyColor: Palette.luchaRed,
        accentColor: playerMaskColor,
        spriteSize: regularSpriteSize,
        idleFps: fx.idleFps,
        flashSeconds: fx.hitFlashSeconds,
      )..position = Vector2(_sideMargin, _floorY - regularSpriteSize);

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

  /// Shows the equipped mask's color on the player's head.
  void setPlayerMask(int color) {
    playerMaskColor = color;
    if (!isLoaded) return;
    final position = _player.position.clone();
    _player.removeFromParent();
    _player = _buildPlayer()..position = position;
    world.add(_player);
  }

  /// Shows (or removes) the lucky pickup at a fractional position.
  void setLucky({required bool visible, double x = 0.5, double y = 0.5}) {
    if (!isLoaded) return;
    if (!visible) {
      _lucky?.removeFromParent();
      _lucky = null;
      return;
    }
    if (_lucky != null) return;
    final margin = _LuckyPickup.spriteSize;
    _lucky = _LuckyPickup(
      onTap: onLuckyTap,
      position: Vector2(
        (margin.x + x * (virtualSize.x - 3 * margin.x)).roundToDouble(),
        (margin.y + y * (_floorY - 3 * margin.y)).roundToDouble(),
      ),
    );
    world.add(_lucky!);
  }

  /// Reaction to a hit: flash the opponent and float the damage number.
  /// [isBig] (critical hits, finishers) uses the large yellow number.
  void hit(String damageText, {required bool isTap, bool isBig = false}) {
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
      big: isBig,
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

/// A floating belt that pays coins when tapped quickly.
class _LuckyPickup extends PositionComponent with TapCallbacks {
  _LuckyPickup({required this.onTap, required Vector2 position})
      : super(position: position, size: spriteSize.clone(), priority: 20);

  static final Vector2 spriteSize = Vector2(14, 8);

  final void Function() onTap;

  @override
  void render(Canvas canvas) {
    final paint = Paint()..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint..color = Palette.ink.color);
    canvas.drawRect(Rect.fromLTWH(1, 1, size.x - 2, size.y - 2), paint..color = Palette.marigold.color);
    canvas.drawRect(Rect.fromLTWH(1, 1, size.x - 2, 2), paint..color = Palette.sunYellow.color);
    canvas.drawRect(Rect.fromLTWH(size.x / 2 - 2, 2, 4, 4), paint..color = Palette.luchaRed.color);
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();

  // A generous touch area: the sprite is small but touch targets are not.
  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= -8 && point.y >= -8 && point.x <= size.x + 8 && point.y <= size.y + 8;
}

class _DamageNumber extends TextComponent {
  _DamageNumber({
    required String text,
    required this.start,
    required this.risePx,
    required this.seconds,
    this.big = false,
  }) : super(
          text: text,
          anchor: Anchor.bottomCenter,
          textRenderer: TextPaint(
            style: TextStyle(
              color: (big ? Palette.sunYellow : Palette.bone).color,
              fontSize: big ? 16 : 8,
              height: 1,
              shadows: [Shadow(color: Palette.ink.color, offset: const Offset(1, 1))],
            ),
          ),
        );

  final Vector2 start;
  final double risePx;
  final double seconds;
  final bool big;
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
