import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/buy_amount.dart';
import '../core/game_state.dart';
import '../data/tutorial_models.dart';
import 'game_controller.dart';

/// Whether the tutorial runs at all. The app leaves it on; tests turn it off.
final tutorialEnabledProvider = Provider<bool>((ref) => true);

/// Where the tutorial is: the step being shown (null when it is finished or
/// off) and what the player had done when the step began.
class TutorialProgress {
  const TutorialProgress({
    this.step,
    this.baseTaps = 0,
    this.baseDefeats = 0,
    this.baseLevel = 0,
  });

  final TutorialStep? step;
  final int baseTaps;
  final int baseDefeats;
  final int baseLevel;
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialProgress>(
  TutorialNotifier.new,
);

class TutorialNotifier extends Notifier<TutorialProgress> {
  late int _index;

  List<TutorialStep> get _steps => ref.read(contentProvider).tutorial.steps;

  @override
  TutorialProgress build() {
    if (!ref.watch(tutorialEnabledProvider)) return const TutorialProgress();
    final saved = ref.read(settingsProvider).tutorialStep;
    final game = ref.read(gameControllerProvider);
    // A game that was already played never sees the tutorial.
    _index =
        saved ??
        (game.stat('taps') == 0 && game.fightNumber == 1 ? 0 : _steps.length);
    ref.listen(gameControllerProvider, (_, next) => _check(next));
    return _begin(_index);
  }

  /// Progress for the start of step [index] (the gift of coins happens here).
  TutorialProgress _begin(int index) {
    if (index >= _steps.length) return const TutorialProgress();
    final step = _steps[index];
    final controller = ref.read(gameControllerProvider.notifier);
    final id = step.ensureAffordable;
    if (id != null) {
      // Run after the build: the gift changes the game state.
      Future.microtask(() {
        final quote = controller.engine.quoteUpgrade(id, const BuyAmount.fixed(1));
        final coins = controller.engine.state.coins;
        if (coins < quote.cost) controller.grantCoins(quote.cost - coins);
      });
    }
    final game = controller.engine.state;
    return TutorialProgress(
      step: step,
      baseTaps: game.stat('taps'),
      baseDefeats: game.stat('defeats'),
      baseLevel: step.itemId == null ? 0 : game.upgradeLevel(step.itemId!),
    );
  }

  void _check(GameState game) {
    final step = state.step;
    if (step == null) return;
    final done = switch (step.advance) {
      TutorialAdvance.taps => game.stat('taps') >= state.baseTaps + step.count,
      TutorialAdvance.defeats =>
        game.stat('defeats') >= state.baseDefeats + step.count,
      TutorialAdvance.upgradeBought =>
        game.upgradeLevel(step.itemId!) > state.baseLevel,
      TutorialAdvance.ok => false,
    };
    if (done) _goTo(_index + 1);
  }

  void _goTo(int index) {
    _index = index;
    ref.read(settingsProvider.notifier).setTutorialStep(index);
    state = _begin(index);
  }

  /// "Entendido" on a step that waits for it.
  void ok() {
    if (state.step?.advance == TutorialAdvance.ok) _goTo(_index + 1);
  }

  /// "Saltar tutorial".
  void skip() {
    if (state.step != null) _goTo(_steps.length);
  }

  /// "Ver tutorial" in the settings: starts over.
  void restart() {
    if (!ref.read(tutorialEnabledProvider)) return;
    _goTo(0);
  }
}
