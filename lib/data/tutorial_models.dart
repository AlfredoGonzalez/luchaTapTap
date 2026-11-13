import 'content_exception.dart';
import 'json_reader.dart';

/// What finishes a tutorial step.
enum TutorialAdvance {
  /// The player taps the arena [TutorialStep.count] more times.
  taps,

  /// The player defeats [TutorialStep.count] more opponents.
  defeats,

  /// The player buys a level of upgrade [TutorialStep.itemId].
  upgradeBought,

  /// The player hires a level of trainer [TutorialStep.itemId].
  trainerBought,

  /// The player lands a finisher (the kick).
  finisherUsed,

  /// The player opens the screen called [TutorialStep.itemId] (a tab).
  viewOpened,

  /// The player presses the "Entendido" button.
  ok,
}

/// When a step may begin (besides its `after` step being done).
enum TutorialWhen {
  /// At once.
  start,

  /// The player can afford some trainer.
  trainerAffordable,

  /// The combo meter is full.
  comboFull,

  /// A lucky belt is on screen.
  luckyAppears,

  /// A skill has become available.
  skillUnlocked,

  /// The player stands in front of a boss and may challenge it.
  bossGate,

  /// Changing the mask is worth a belt.
  canPrestige,
}

/// One step: everything dark except [targets], a text from the coach, and
/// what the player has to do to move on.
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.targets,
    required this.textKey,
    required this.advance,
    this.when = TutorialWhen.start,
    this.after,
    this.count = 1,
    this.itemId,
    this.ensureAffordable,
  });

  factory TutorialStep.fromReader(JsonReader r) {
    final advance = r.object('advance');
    final type = advance.string('type');
    final kind = TutorialAdvance.values.where((a) => a.name == type);
    if (kind.isEmpty) {
      throw ContentException(
        'tutorial.json: unknown advance type "$type" in "${r.string('id')}"',
      );
    }
    final whenName = r.has('when') ? r.string('when') : 'start';
    final when = TutorialWhen.values.where((w) => w.name == whenName);
    if (when.isEmpty) {
      throw ContentException(
        'tutorial.json: unknown "when" "$whenName" in "${r.string('id')}"',
      );
    }
    final targets = r.strings('targets');
    if (targets.isEmpty) {
      throw ContentException(
        'tutorial.json: step "${r.string('id')}" needs at least one target',
      );
    }
    return TutorialStep(
      id: r.string('id'),
      targets: targets,
      textKey: r.string('text'),
      advance: kind.first,
      when: when.first,
      after: r.optionalString('after'),
      count: advance.has('count') ? advance.integer('count', min: 1) : 1,
      itemId: advance.optionalString('id'),
      ensureAffordable: r.optionalString('ensureAffordable'),
    );
  }

  final String id;

  /// Ids of the UI elements that stay lit (see `TutorialTarget`).
  final List<String> targets;
  final String textKey;
  final TutorialAdvance advance;

  /// What has to be true for the step to begin, and the step that must be
  /// finished before it (the intro steps chain with `after`).
  final TutorialWhen when;
  final String? after;
  final int count;
  final String? itemId;

  /// Upgrade the player must be able to afford at the start of the step; if
  /// they cannot, the missing coins are given.
  final String? ensureAffordable;
}

class TutorialDef {
  const TutorialDef({
    required this.coachName,
    required this.coachBodyColor,
    required this.coachAccentColor,
    required this.charsPerSecond,
    required this.mouthEveryChars,
    required this.steps,
  });

  factory TutorialDef.fromReader(JsonReader r) {
    final coach = r.object('coach');
    final steps = [for (final s in r.objects('steps')) TutorialStep.fromReader(s)];
    final seen = <String>{};
    for (final s in steps) {
      if (!seen.add(s.id)) {
        throw ContentException('tutorial.json: duplicate step id "${s.id}"');
      }
      final needsId =
          s.advance == TutorialAdvance.upgradeBought ||
          s.advance == TutorialAdvance.trainerBought ||
          s.advance == TutorialAdvance.viewOpened;
      if (needsId && s.itemId == null) {
        throw ContentException(
          'tutorial.json: step "${s.id}" needs advance.id',
        );
      }
    }
    for (final s in steps) {
      if (s.after != null && !seen.contains(s.after)) {
        throw ContentException(
          'tutorial.json: step "${s.id}" comes after unknown step "${s.after}"',
        );
      }
    }
    return TutorialDef(
      coachName: coach.string('name'),
      coachBodyColor: coach.string('bodyColor'),
      coachAccentColor: coach.string('accentColor'),
      charsPerSecond: coach.number('charsPerSecond', min: 0, minExclusive: true),
      mouthEveryChars: coach.integer('mouthEveryChars', min: 1),
      steps: List.unmodifiable(steps),
    );
  }

  final String coachName;
  final String coachBodyColor;
  final String coachAccentColor;

  /// The coach's text types out at this speed, and the mouth opens and
  /// closes every [mouthEveryChars] characters while it does.
  final double charsPerSecond;
  final int mouthEveryChars;
  final List<TutorialStep> steps;
}
