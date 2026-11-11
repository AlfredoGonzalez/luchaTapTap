import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PanelTab { upgrades, skills, masks, talents }

final panelTabProvider = NotifierProvider<PanelTabNotifier, PanelTab>(PanelTabNotifier.new);

class PanelTabNotifier extends Notifier<PanelTab> {
  @override
  PanelTab build() => PanelTab.upgrades;

  void select(PanelTab tab) => state = tab;
}

/// Pop-ups opened by the player (the offline earnings pop-up is driven by the
/// game state instead).
enum GameDialog { prestige, debug }

final dialogProvider = NotifierProvider<DialogNotifier, GameDialog?>(DialogNotifier.new);

class DialogNotifier extends Notifier<GameDialog?> {
  @override
  GameDialog? build() => null;

  void open(GameDialog dialog) => state = dialog;
  void close() => state = null;
}
