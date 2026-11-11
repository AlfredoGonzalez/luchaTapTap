import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App flow: studio splash, loading screen, then the game.
enum AppStage { splash, loading, game }

/// Where the app starts; tests start at [AppStage.game].
final initialAppStageProvider = Provider<AppStage>((ref) => AppStage.splash);

final appStageProvider = NotifierProvider<AppStageNotifier, AppStage>(
  AppStageNotifier.new,
);

class AppStageNotifier extends Notifier<AppStage> {
  @override
  AppStage build() => ref.read(initialAppStageProvider);

  void show(AppStage stage) => state = stage;
}

/// What fills the screen between the HUD and the navigation bar. `fight` is
/// the main screen (the "Mejoras" tab); the others replace the arena.
enum GameView { fight, skills, masks, talents, shop, settings, credits }

final viewProvider = NotifierProvider<ViewNotifier, GameView>(ViewNotifier.new);

class ViewNotifier extends Notifier<GameView> {
  @override
  GameView build() => GameView.fight;

  void show(GameView view) => state = view;

  /// Back (Android back button, "Volver"): credits return to settings,
  /// everything else to the fight.
  void back() =>
      state = state == GameView.credits ? GameView.settings : GameView.fight;
}

/// Pop-ups opened by the player (the offline earnings pop-up and the boss
/// intro are driven by the game state instead).
enum GameDialog { prestige, debug, privacy, deleteData }

final dialogProvider = NotifierProvider<DialogNotifier, GameDialog?>(
  DialogNotifier.new,
);

class DialogNotifier extends Notifier<GameDialog?> {
  @override
  GameDialog? build() => null;

  void open(GameDialog dialog) => state = dialog;
  void close() => state = null;
}

/// Selected skill, mask and talent (shown in the detail panel of each view).
final selectedSkillProvider = NotifierProvider<SelectionNotifier, String?>(
  SelectionNotifier.new,
);
final selectedMaskProvider = NotifierProvider<SelectionNotifier, String?>(
  SelectionNotifier.new,
);
final selectedTalentProvider = NotifierProvider<SelectionNotifier, String?>(
  SelectionNotifier.new,
);

class SelectionNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String id) => state = id;
}
