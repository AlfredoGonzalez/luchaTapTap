import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/buy_amount.dart';
import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../data/tutorial_models.dart';
import 'game_controller.dart';

/// Whether the tutorial runs at all. The app leaves it on; tests turn it off.
final tutorialEnabledProvider = Provider<bool>((ref) => true);

/// Where the tutorial is: the step being shown (null when there is none right
/// now) and what the player had done when the step began.
class TutorialProgress {
  const TutorialProgress({
    this.step,
    this.baseTaps = 0,
    this.baseDefeats = 0,
    this.baseLevel = 0,
    this.baseFinishers = 0,
  });

  final TutorialStep? step;
  final int baseTaps;
  final int baseDefeats;
  final int baseLevel;
  final int baseFinishers;
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialProgress>(
  TutorialNotifier.new,
);

/// Shows the steps of `tutorial.json` one at a time: the first step, in file
/// order, that is not done yet, whose `after` step is done and whose `when`
/// condition holds. Finished steps are saved by id.
class TutorialNotifier extends Notifier<TutorialProgress> {
  final Set<String> _done = {};

  List<TutorialStep> get _steps => ref.read(contentProvider).tutorial.steps;

  GameEngine get _engine => ref.read(gameControllerProvider.notifier).engine;

  @override
  TutorialProgress build() {
    _done.clear();
    if (!ref.watch(tutorialEnabledProvider)) return const TutorialProgress();
    final saved = ref.read(settingsProvider);
    final game = ref.read(gameControllerProvider);
    final ids = [for (final s in _steps) s.id];
    if (saved.tutorialDone != null) {
      _done.addAll(saved.tutorialDone!);
    } else if (saved.tutorialStep != null) {
      // A save from the first tutorial: its steps were the first ones in the
      // file, in order.
      _done.addAll(ids.take(saved.tutorialStep!));
    } else if (game.stat('taps') > 0 || game.fightNumber > 1) {
      // A game already played never sees the tutorial.
      _done.addAll(ids);
    }
    if (saved.tutorialDone == null) {
      // Remember the decision (after the build: it changes the settings).
      final decided = _done.toList();
      Future.microtask(
        () => ref.read(settingsProvider.notifier).setTutorialDone(decided),
      );
    }
    ref.listen(gameControllerProvider, (_, next) => _check(next));
    return _pick(game);
  }

  bool _holds(TutorialWhen when, GameState game) {
    switch (when) {
      case TutorialWhen.start:
        return true;
      case TutorialWhen.trainerAffordable:
        return [
          for (final t in _engine.content.trainers)
            if (_engine.isTrainerUnlocked(t))
              _engine.quoteTrainer(t.id, const BuyAmount.fixed(1)).canBuy,
        ].contains(true);
      case TutorialWhen.comboFull:
        return _engine.finisherReady;
      case TutorialWhen.luckyAppears:
        return game.lucky != null;
      case TutorialWhen.skillUnlocked:
        return [
          for (final s in _engine.content.skills)
            _engine.quoteSkill(s.id).failure != BuyFailure.locked,
        ].contains(true);
      case TutorialWhen.bossGate:
        return _engine.bossGateReady;
      case TutorialWhen.canPrestige:
        return _engine.prestigePreview().canPrestige;
    }
  }

  /// The next step that may begin now, if any.
  TutorialProgress _pick(GameState game) {
    for (final step in _steps) {
      if (_done.contains(step.id)) continue;
      if (step.after != null && !_done.contains(step.after)) continue;
      if (!_holds(step.when, game)) continue;
      return _begin(step, game);
    }
    return const TutorialProgress();
  }

  /// Progress for the start of [step] (the gift of coins happens here).
  TutorialProgress _begin(TutorialStep step, GameState game) {
    final controller = ref.read(gameControllerProvider.notifier);
    final id = step.ensureAffordable;
    if (id != null) {
      // Run after the build: the gift changes the game state.
      Future.microtask(() {
        final quote = controller.engine.quoteUpgrade(
          id,
          const BuyAmount.fixed(1),
        );
        final coins = controller.engine.state.coins;
        if (coins < quote.cost) controller.grantCoins(quote.cost - coins);
      });
    }
    final item = step.itemId;
    return TutorialProgress(
      step: step,
      baseTaps: game.stat('taps'),
      baseDefeats: game.stat('defeats'),
      baseFinishers: game.stat('finishers'),
      baseLevel: item == null
          ? 0
          : (step.advance == TutorialAdvance.trainerBought
                ? game.trainerLevel(item)
                : game.upgradeLevel(item)),
    );
  }

  void _check(GameState game) {
    final step = state.step;
    if (step == null) {
      final next = _pick(game);
      if (next.step != null) state = next;
      return;
    }
    final done = switch (step.advance) {
      TutorialAdvance.taps => game.stat('taps') >= state.baseTaps + step.count,
      TutorialAdvance.defeats =>
        game.stat('defeats') >= state.baseDefeats + step.count,
      TutorialAdvance.upgradeBought =>
        game.upgradeLevel(step.itemId!) > state.baseLevel,
      TutorialAdvance.trainerBought =>
        game.trainerLevel(step.itemId!) > state.baseLevel,
      TutorialAdvance.finisherUsed =>
        game.stat('finishers') > state.baseFinishers,
      TutorialAdvance.viewOpened || TutorialAdvance.ok => false,
    };
    if (done) _finish(step);
  }

  void _finish(TutorialStep step) {
    _done.add(step.id);
    ref.read(settingsProvider.notifier).setTutorialDone(_done.toList());
    state = _pick(ref.read(gameControllerProvider));
  }

  /// "Entendido" on a step that waits for it.
  void ok() {
    final step = state.step;
    if (step != null && step.advance == TutorialAdvance.ok) _finish(step);
  }

  /// The player opened the screen called [name] (a tab of the navigation bar).
  void viewOpened(String name) {
    final step = state.step;
    if (step != null &&
        step.advance == TutorialAdvance.viewOpened &&
        step.itemId == name) {
      _finish(step);
    }
  }

  /// "Saltar": the tutorial ends (every step counts as done).
  void skip() {
    if (state.step == null) return;
    _done.addAll([for (final s in _steps) s.id]);
    ref.read(settingsProvider.notifier).setTutorialDone(_done.toList());
    state = const TutorialProgress();
  }

  /// "Ver tutorial" in the settings: starts over.
  void restart() {
    if (!ref.read(tutorialEnabledProvider)) return;
    _done.clear();
    ref.read(settingsProvider.notifier).setTutorialDone(const []);
    state = _pick(ref.read(gameControllerProvider));
  }
}
