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
import 'clip_player.dart';
import 'fighter_shape.dart';
import 'sprite_library.dart';

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
    required this.animations,
    required this.theme,
    this.leagueOrder = 1,
    SpriteLibrary? sprites,
    this.playerMaskId,
    this.playerMaskColor = Palette.violet,
  }) : sprites = sprites ?? SpriteLibrary.empty();

  final AnimationConfig animations;

  /// Arena colors of the current league (see [setTheme]).
  ArenaTheme theme;
  int leagueOrder;

  /// Sprite sheets; fighters without one are drawn as placeholder rectangles.
  final SpriteLibrary sprites;

  /// Equipped mask (selects the recolored player sheet); null = none.
  String? playerMaskId;

  final Vector2 virtualSize;
  final FxConfig fx;
  final void Function() onTap;
  final void Function() onLuckyTap;

  /// Placeholder color of the player's head (the equipped mask's base color).
  int playerMaskColor;

  /// Opponent currently shown (updated by [showOpponent]).
  OpponentDef opponent;
  late _Fighter _player;
  late _ArenaBackdrop _backdrop;
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

    _backdrop = _ArenaBackdrop(
      size: virtualSize,
      floorY: _floorY,
      theme: theme,
      image: sprites.arenaBackground(leagueOrder, virtualSize.x),
    );
    world.add(_backdrop);
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
    sheet: sprites.player(playerMaskId),
    animations: animations,
  )..position = Vector2(_sideMargin, _floorY - regularSpriteSize);

  _Fighter _buildEnemy(OpponentDef o) {
    final size = o.size.toDouble();
    return _Fighter(
      bodyColor: Palette.byId[o.placeholderColor]!,
      accentColor: Palette.byId[o.placeholderColor]!,
      spriteSize: o.size,
      idleFps: fx.idleFps,
      flashSeconds: fx.hitFlashSeconds,
      sheet: sprites.opponent(o.sprite),
      animations: animations,
      faceLeft: true, // sheets are drawn facing right
    )..position = Vector2(virtualSize.x - _sideMargin - size, _floorY - size);
  }

  /// Shows a new opponent. When the previous one was [defeated] it falls first
  /// (the defeated clip) and the next one steps in after a short pause.
  void showOpponent(OpponentDef next, {bool defeated = false}) {
    opponent = next;
    if (!isLoaded) return;
    final old = _enemy;
    var delay = 0.0;
    if (defeated && old.hasSprite) {
      old.fall();
      delay =
          animations.clips['defeated']!.seconds +
          animations.defeatedHoldSeconds;
      old.removeAfter(delay);
    } else {
      old.removeFromParent();
    }
    _enemy = _buildEnemy(next)..hideFor(delay);
    world.add(_enemy);
  }

  /// Shows the equipped mask on the player: the recolored sheet, or the head
  /// color of the placeholder.
  void setPlayerMask(String? maskId, int color) {
    playerMaskId = maskId;
    playerMaskColor = color;
    if (!isLoaded) return;
    final position = _player.position.clone();
    _player.removeFromParent();
    _player = _buildPlayer()..position = position;
    world.add(_player);
  }

  /// A new league: the arena changes colors.
  void setTheme(ArenaTheme next, {int? league}) {
    theme = next;
    if (league != null) leagueOrder = league;
    if (isLoaded) {
      _backdrop.theme = next;
      _backdrop.image = sprites.arenaBackground(leagueOrder, virtualSize.x);
    }
  }

  /// The player throws a punch (or a kick, for the finisher).
  void playerAttack({bool kick = false}) {
    if (isLoaded) _player.punch(kick: kick);
  }

  /// Plays the animation of skill [name] (the plancha): the player flies
  /// across the arena to the opponent. Does nothing without the art.
  void playSkill(String name) {
    if (!isLoaded) return;
    final strip = sprites.skillStrip(name, playerMaskId);
    if (strip == null) return;
    final cfg = strip.config;
    final startX = _player.position.x - (cfg.cellWidth - _player.size.x) / 2;
    final endX = _enemy.position.x - cfg.cellWidth * 0.45;
    _player.hideFor(cfg.seconds);
    world.add(
      _SkillFlight(
        strip: strip,
        start: Vector2(startX.roundToDouble(), _player.position.y),
        endX: endX.roundToDouble(),
      ),
    );
  }

  /// The boss timer ran out: the player goes down for a moment and the
  /// opponent celebrates.
  void playerDefeated() {
    if (!isLoaded) return;
    _player.knockDown(animations.playerDownSeconds);
    _enemy.celebrate(animations.playerDownSeconds);
  }

  /// The player celebrates (a boss fell) for the time set in the data.
  void playerVictory() {
    if (isLoaded) _player.celebrate(animations.victorySeconds);
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

  final math.Random _random = math.Random();

  /// Reaction to a hit. A tap flashes the opponent white and floats the damage
  /// number above it; [isBig] (critical hits, finishers) uses the large yellow
  /// number. Damage from trainers ([isTap] false) does not flash: its number
  /// rises from a random spot on the opponent in a quieter color and fades.
  void hit(String damageText, {required bool isTap, bool isBig = false}) {
    if (!isLoaded) return;
    final Vector2 spawn;
    if (isTap) {
      _enemy.flash();
      _enemy.reactToHit();
      final jitter = fx.damageNumberJitterPx;
      final offset = jitter == 0
          ? 0
          : (_hitCount * 7) % (2 * jitter + 1) - jitter;
      _hitCount++;
      spawn = Vector2(
        _enemy.position.x + _enemy.size.x / 2 + offset,
        _enemy.position.y - 2,
      );
    } else {
      spawn = Vector2(
        _enemy.position.x + _random.nextDouble() * _enemy.size.x,
        _enemy.position.y + 8 + _random.nextDouble() * _enemy.size.y * 0.7,
      );
    }
    world.add(
      _DamageNumber(
        text: damageText,
        start: spawn,
        risePx: fx.damageNumberRisePx.toDouble(),
        seconds: fx.damageNumberSeconds,
        big: isBig,
        color: isTap
            ? (isBig ? Palette.sunYellow : Palette.bone)
            : Palette.byId[fx.idleNumberColor]!,
        fadeSteps: fx.fadeSteps,
      ),
    );
  }
}

class _ArenaBackdrop extends PositionComponent {
  /// Draws the picture at 1:1, centered and sitting on the bottom edge. Where
  /// the canvas is wider or taller than the picture, its edge pixels are
  /// stretched outward so there is never a gap.
  void _renderPicture(Canvas canvas, Image picture) {
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    final w = picture.width.toDouble();
    final h = picture.height.toDouble();
    final left = ((size.x - w) / 2).floorToDouble();
    final top = size.y - h;
    // Crop sides when the canvas is narrower than the picture.
    final srcX = left < 0 ? -left : 0.0;
    final srcW = math.min(w - srcX, size.x);
    final dstX = math.max(left, 0.0);
    canvas.drawImageRect(
      picture,
      Rect.fromLTWH(srcX, 0, srcW, h),
      Rect.fromLTWH(dstX, top, srcW, h),
      paint,
    );
    if (dstX > 0) {
      canvas.drawImageRect(
        picture,
        Rect.fromLTWH(0, 0, 1, h),
        Rect.fromLTWH(0, top, dstX, h),
        paint,
      );
      canvas.drawImageRect(
        picture,
        Rect.fromLTWH(w - 1, 0, 1, h),
        Rect.fromLTWH(dstX + srcW, top, size.x - dstX - srcW, h),
        paint,
      );
    }
    if (top > 0) {
      canvas.drawImageRect(
        picture,
        Rect.fromLTWH(0, 0, w, 1),
        Rect.fromLTWH(dstX, 0, srcW, top),
        paint,
      );
      if (dstX > 0) {
        canvas.drawImageRect(
          picture,
          const Rect.fromLTWH(0, 0, 1, 1),
          Rect.fromLTWH(0, 0, dstX, top),
          paint,
        );
        canvas.drawImageRect(
          picture,
          Rect.fromLTWH(w - 1, 0, 1, 1),
          Rect.fromLTWH(dstX + srcW, 0, size.x - dstX - srcW, top),
          paint,
        );
      }
    }
  }

  _ArenaBackdrop({
    required Vector2 size,
    required this.floorY,
    required this.theme,
    this.image,
  }) : super(size: size);

  final double floorY;
  ArenaTheme theme;

  /// The league's arena picture, drawn bottom-aligned and centered; null draws
  /// flat colors from [theme].
  Image? image;

  @override
  void render(Canvas canvas) {
    final picture = image;
    if (picture != null) {
      _renderPicture(canvas, picture);
      return;
    }
    final paint = Paint()..isAntiAlias = false;
    // Wall.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, floorY),
      paint..color = theme.wall.color,
    );
    // Ropes.
    for (final y in [floorY - 30, floorY - 20, floorY - 10]) {
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.x, 2),
        paint..color = theme.rope.color,
      );
    }
    // Floor.
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, size.x, size.y - floorY),
      paint..color = theme.floor.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, size.x, 1),
      paint..color = Palette.ink.color,
    );
  }
}

/// A wrestler: animated from its sprite sheet when there is one, otherwise
/// the placeholder (body block, head block, 1-pixel Ink outline).
class _Fighter extends PositionComponent {
  _Fighter({
    required this.bodyColor,
    required this.accentColor,
    required int spriteSize,
    required this.idleFps,
    required this.flashSeconds,
    required this.animations,
    this.sheet,
    this.faceLeft = false,
  }) : super(size: Vector2.all(spriteSize.toDouble())) {
    if (sheet != null) _clips = ClipPlayer(animations);
  }

  final int bodyColor;
  final int accentColor;
  final int idleFps;
  final double flashSeconds;
  final AnimationConfig animations;
  final SpriteSheet? sheet;
  final bool faceLeft;
  ClipPlayer? _clips;

  bool get hasSprite => sheet != null;

  /// Idle bob of the placeholder: body drops 1 pixel on the middle frames.
  static const List<int> _idleBob = [0, 1, 1, 0];

  double _time = 0;
  double _flashLeft = 0;
  double _hiddenLeft = 0;
  double _celebrateLeft = 0;
  double? _removeLeft;
  bool _fallen = false;
  double _downLeft = 0;
  late final double _baseY = position.y;

  void flash() => _flashLeft = flashSeconds;

  /// Not drawn for [seconds] (the previous opponent is still falling).
  void hideFor(double seconds) => _hiddenLeft = seconds;

  void removeAfter(double seconds) => _removeLeft = seconds;

  void punch({bool kick = false}) {
    if (_fallen) return;
    // Sheets without the kick row (placeholders) punch instead.
    final useKick = kick && sheet?.has('kick') == true;
    _clips?.play(useKick ? 'kick' : 'attack');
  }

  void reactToHit() {
    if (!_fallen && _celebrateLeft == 0) _clips?.play('hit');
  }

  void fall() {
    _fallen = true;
    _clips?.play('defeated', then: null);
  }

  /// Knocked down (the boss won): lies on the floor for [seconds], then gets up.
  void knockDown(double seconds) {
    _fallen = true;
    _downLeft = seconds;
    _celebrateLeft = 0;
    _clips?.play('defeated', then: null);
  }

  void celebrate(double seconds) {
    _celebrateLeft = seconds;
    _clips?.play('victory', then: null);
  }

  @override
  void update(double dt) {
    _time += dt;
    if (_flashLeft > 0) _flashLeft = math.max(0, _flashLeft - dt);
    if (_hiddenLeft > 0) _hiddenLeft = math.max(0, _hiddenLeft - dt);
    final left = _removeLeft;
    if (left != null) {
      _removeLeft = left - dt;
      if (_removeLeft! <= 0) {
        removeFromParent();
        return;
      }
    }
    if (_downLeft > 0) {
      _downLeft = math.max(0, _downLeft - dt);
      if (_downLeft == 0) {
        _fallen = false;
        _clips?.play('idle');
      }
    }
    if (_celebrateLeft > 0) {
      _celebrateLeft = math.max(0, _celebrateLeft - dt);
      if (_celebrateLeft == 0) _clips?.play('idle');
    }
    final clips = _clips;
    if (clips != null) {
      clips.update(dt);
    } else {
      final frame = (_time * idleFps).floor() % _idleBob.length;
      position.y = (_baseY + _idleBob[frame]).roundToDouble();
    }
    position.x = position.x.roundToDouble();
  }

  @override
  void render(Canvas canvas) {
    if (_hiddenLeft > 0) return;
    final sheet = this.sheet;
    final clips = _clips;
    if (sheet == null || clips == null) {
      paintFighter(
        canvas,
        Size(size.x, size.y),
        bodyColor: bodyColor,
        accentColor: accentColor,
        flashing: _flashLeft > 0,
      );
      return;
    }
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
    if (_flashLeft > 0) {
      paint.colorFilter = ColorFilter.mode(
        Palette.white.color,
        BlendMode.srcATop,
      );
    }
    canvas.save();
    if (faceLeft) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawImageRect(
      sheet.image,
      sheet.frameRect(clips.clip, clips.frame),
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint,
    );
    canvas.restore();
  }
}

/// The player flying across the arena for a skill (the plancha): the strip's
/// frames play in order while the sprite travels to the opponent during the
/// first `travelFrames`, then stays where it landed until the strip ends.
class _SkillFlight extends PositionComponent {
  _SkillFlight({
    required this.strip,
    required Vector2 start,
    required this.endX,
  }) : _startX = start.x,
       super(
         position: start,
         size: Vector2(strip.cellWidth.toDouble(), strip.cellHeight.toDouble()),
         priority: 5,
       );

  final SkillStrip strip;
  final double _startX;
  final double endX;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    final cfg = strip.config;
    if (_age >= cfg.seconds) {
      removeFromParent();
      return;
    }
    final travel = cfg.travelFrames / cfg.fps;
    final t = (_age / travel).clamp(0.0, 1.0);
    final eased = 1 - (1 - t) * (1 - t); // fast start, soft landing
    position.x = (_startX + (endX - _startX) * eased).roundToDouble();
  }

  @override
  void render(Canvas canvas) {
    final cfg = strip.config;
    final frame = (_age * cfg.fps).floor().clamp(0, cfg.frames - 1);
    canvas.drawImageRect(
      strip.image,
      strip.frameRect(frame),
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none,
    );
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
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      paint..color = Palette.ink.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      paint..color = Palette.marigold.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, 2),
      paint..color = Palette.sunYellow.color,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x / 2 - 2, 2, 4, 4),
      paint..color = Palette.luchaRed.color,
    );
  }

  @override
  void onTapDown(TapDownEvent event) => onTap();

  // A generous touch area: the sprite is small but touch targets are not.
  @override
  bool containsLocalPoint(Vector2 point) =>
      point.x >= -8 &&
      point.y >= -8 &&
      point.x <= size.x + 8 &&
      point.y <= size.y + 8;
}

class _DamageNumber extends TextComponent {
  _DamageNumber({
    required String text,
    required this.start,
    required this.risePx,
    required this.seconds,
    required this.color,
    required this.fadeSteps,
    this.big = false,
  }) : super(
         text: text,
         anchor: Anchor.bottomCenter,
         textRenderer: _paint(color, big, 1),
       );

  final Vector2 start;
  final double risePx;
  final double seconds;
  final bool big;
  final int color;
  final int fadeSteps;
  double _age = 0;
  int _step = 0;

  static TextPaint _paint(int color, bool big, double opacity) => TextPaint(
    style: TextStyle(
      color: color.color.withValues(alpha: opacity),
      fontSize: big ? 16 : 8,
      height: 1,
      shadows: [
        Shadow(
          color: Palette.ink.color.withValues(alpha: opacity),
          offset: const Offset(1, 1),
        ),
      ],
    ),
  );

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
    // Fade out over the second half, in whole steps (no soft transparency).
    final fade = ((_age / seconds - 0.5) * 2).clamp(0.0, 1.0);
    final step = (fade * fadeSteps).floor();
    if (step != _step) {
      _step = step;
      textRenderer = _paint(color, big, 1 - step / fadeSteps);
    }
    position = Vector2(
      start.x.roundToDouble(),
      (start.y - risePx * (_age / seconds)).roundToDouble(),
    );
  }
}
