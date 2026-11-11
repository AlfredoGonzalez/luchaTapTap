import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/palette.dart';
import '../game/arena_game.dart';
import '../services/game_controller.dart';
import 'pixel_scale.dart';

/// Hosts the Flame arena. The whole arena is the tap area.
class ArenaView extends ConsumerStatefulWidget {
  const ArenaView({super.key, required this.virtualHeight});

  /// Height of the arena zone in virtual pixels.
  final double virtualHeight;

  @override
  ConsumerState<ArenaView> createState() => _ArenaViewState();
}

class _ArenaViewState extends ConsumerState<ArenaView> {
  late final ArenaGame _game;
  StreamSubscription<HitEvent>? _hits;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(gameControllerProvider.notifier);
    final content = ref.read(contentProvider);
    _game = ArenaGame(
      virtualSize: Vector2(virtualWidth.toDouble(), widget.virtualHeight),
      fx: content.balance.fx,
      onTap: controller.tap,
      onLuckyTap: controller.collectLucky,
      opponent: controller.engine.opponent,
      playerMaskColor: _maskColor(controller),
    );
    _hits = controller.hits.listen(
      (e) => _game.hit(formatBig(e.damage), isTap: e.isTap, isBig: e.isBig),
    );
    ref.listenManual(gameControllerProvider, (previous, next) {
      if (previous?.fightNumber != next.fightNumber) {
        _game.showOpponent(controller.engine.opponent);
      }
      if (previous?.equippedMask != next.equippedMask) {
        _game.setPlayerMask(_maskColor(controller));
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GameWidget(game: _game);
}
