import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/fixed_step.dart';
import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../data/content_bundle.dart';
import 'strings.dart';

/// Provided at startup with the validated content (see `main.dart`).
final contentProvider = Provider<ContentBundle>(
  (ref) => throw UnimplementedError('contentProvider must be overridden'),
);

/// Selected buy quantity (x1, x10, x100, MAX).
final buyAmountProvider = NotifierProvider<BuyAmountNotifier, BuyAmount>(
  BuyAmountNotifier.new,
);

class BuyAmountNotifier extends Notifier<BuyAmount> {
  @override
  BuyAmount build() => BuyAmount.fixed(ref.read(contentProvider).balance.buyFixedAmounts.first);

  void select(BuyAmount amount) => state = amount;
}

/// A hit shown in the arena: a tap or an idle tick that dealt damage.
class HitEvent {
  const HitEvent({required this.damage, required this.isTap, required this.defeated});

  final Big damage;
  final bool isTap;
  final bool defeated;
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

/// Connects the pure-Dart [GameEngine] to the UI: runs the fixed tick, applies
/// taps and purchases immediately, and publishes the new state.
class GameController extends Notifier<GameState> {
  /// How often the timer wakes up to check whether a tick is due. This is only
  /// polling granularity; the simulation itself advances in fixed steps.
  static const Duration _pollInterval = Duration(milliseconds: 25);

  late final GameEngine _engine;
  late final FixedStepper _stepper;
  // `clock.stopwatch()` is the real clock in the app and the fake clock in
  // widget tests, so tick progress can be tested without waiting.
  final Stopwatch _clock = clock.stopwatch();
  final StreamController<HitEvent> _hits = StreamController<HitEvent>.broadcast();
  Duration _lastElapsed = Duration.zero;
  Timer? _timer;

  GameEngine get engine => _engine;

  /// Taps and idle hits, for floating damage numbers and flashes.
  Stream<HitEvent> get hits => _hits.stream;

  @override
  GameState build() {
    final content = ref.read(contentProvider);
    _engine = GameEngine(content: content);
    _stepper = FixedStepper(
      ticksPerSecond: content.balance.ticksPerSecond,
      maxCatchUpTicks: content.balance.maxCatchUpTicks,
    );
    _clock.start();
    _timer = Timer.periodic(_pollInterval, (_) => _onPoll());
    ref.onDispose(() {
      _timer?.cancel();
      _hits.close();
    });
    return _engine.state;
  }

  void _onPoll() {
    final now = _clock.elapsed;
    final ticks = _stepper.advance(now - _lastElapsed);
    _lastElapsed = now;
    if (ticks == 0) return;
    var damage = Big.zero;
    var defeated = false;
    for (var i = 0; i < ticks; i++) {
      final outcome = _engine.tick();
      damage += outcome.damageDealt;
      defeated = defeated || outcome.defeats > 0;
    }
    state = _engine.state;
    if (!damage.isZero) {
      _hits.add(HitEvent(damage: damage, isTap: false, defeated: defeated));
    }
  }

  void tap() {
    final outcome = _engine.tap();
    state = _engine.state;
    _hits.add(HitEvent(damage: outcome.damageDealt, isTap: true, defeated: outcome.defeats > 0));
  }

  BuyQuote buyUpgrade(String id) {
    final quote = _engine.buyUpgrade(id, ref.read(buyAmountProvider));
    if (quote.canBuy) state = _engine.state;
    return quote;
  }

  BuyQuote buyTrainer(String id) {
    final quote = _engine.buyTrainer(id, ref.read(buyAmountProvider));
    if (quote.canBuy) state = _engine.state;
    return quote;
  }
}


/// Spanish text lookup.
final stringsProvider = Provider<Strings>(
  (ref) => Strings(ref.watch(contentProvider).strings),
);
