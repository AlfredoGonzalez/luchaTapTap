import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../game/arena_game.dart';
import '../services/game_controller.dart';
import 'ui_state.dart';

/// Hosts the Flame arena. The whole arena is the tap area.
class ArenaView extends ConsumerStatefulWidget {
  const ArenaView({
    super.key,
    required this.virtualWidth,
    required this.virtualHeight,
  });

  /// Size of the arena zone in virtual pixels.
  final int virtualWidth;
  final double virtualHeight;

  @override
  ConsumerState<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends ConsumerState<ArenaView> {
  late final ArenaGame _game;
  StreamSubscription<HitEvent>? _hits;
  StreamSubscription<void>? _bossLost;

  /// The fight number changed since the last hit event (that case already
  /// handled the defeat animation).
  bool _fightChanged = false;

  Big _idleDamage = Big.zero;
  final Stopwatch _idleWatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    final controller = ref.read(gameControllerProvider.notifier);
    final content = ref.read(contentProvider);
    _game = ArenaGame(
      virtualSize: Vector2(
        widget.virtualWidth.toDouble(),
        widget.virtualHeight,
      ),
      fx: content.balance.fx,
      onTap: controller.tap,
      onLuckyTap: controller.collectLucky,
      opponent: controller.engine.opponent,
      animations: content.balance.animations,
      theme: content
          .fightInfo(controller.engine.state.fightNumber)
          .league
          .theme,
      leagueOrder: content
          .fightInfo(controller.engine.state.fightNumber)
          .league
          .order,
      sprites: ref.read(spriteLibraryProvider),
      playerMaskId: controller.engine.equippedMaskDef?.id,
      playerMaskColor: _maskColor(controller),
    );
    _hits = controller.hits.listen((e) {
      if (e.isTap) {
        _game.playerAttack();
        _game.hit(formatBig(e.damage), isTap: true, isBig: e.isBig);
      } else {
        // Trainer damage arrives every tick: show it as one number per
        // `idleNumberEverySeconds` with the total of that time.
        _idleDamage += e.damage;
        final every = content.balance.fx.idleNumberEverySeconds;
        if (_idleWatch.elapsedMicroseconds >=
            every * Duration.microsecondsPerSecond) {
          _game.hit(formatBig(_idleDamage), isTap: false);
          _idleDamage = Big.zero;
          _idleWatch.reset();
        }
      }
      // The fight before a boss repeats with the same number: the opponent
      // still falls and a new one steps in.
      if (e.defeated && !_fightChanged) {
        _game.showOpponent(controller.engine.opponent, defeated: true);
      }
      _fightChanged = false;
    });
    _bossLost = controller.bossLost.listen((_) => _game.playerDefeated());
    ref.listenManual(gameControllerProvider, (previous, next) {
      if (previous != null && previous.fightNumber != next.fightNumber) {
        // Moving forward means the opponent was beaten; a boss win also makes
        // the player celebrate. Going back (boss gate, prestige) is not a win.
        _fightChanged = true;
        final won = next.fightNumber > previous.fightNumber;
        final bossFell = won && content.fightInfo(previous.fightNumber).isBoss;
        final league = content.fightInfo(next.fightNumber).league;
        _game.setTheme(league.theme, league: league.order);
        _game.showOpponent(controller.engine.opponent, defeated: won);
        if (bossFell) _game.playerVictory();
      } else if (previous == null) {
        _game.showOpponent(controller.engine.opponent);
      }
      if (previous?.equippedMask != next.equippedMask) {
        _game.setPlayerMask(
          controller.engine.equippedMaskDef?.id,
          _maskColor(controller),
        );
      }
      final lucky = next.lucky;
      _game.setLucky(
        visible: lucky != null,
        x: lucky?.x ?? 0.5,
        y: lucky?.y ?? 0.5,
      );
    });
  }

  /// Base color (the middle of the three slot colors) of the equipped mask.
  int _maskColor(GameController controller) {
    final mask = controller.engine.equippedMaskDef;
    return mask == null ? Palette.violet : Palette.byId[mask.slotColors[1]]!;
  }

  @override
  void dispose() {
    _hits?.cancel();
    _bossLost?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
