import 'package:flutter/services.dart';

import '../data/balance.dart';

/// Vibration feedback. Whether it happens at all is the player's switch in
/// Ajustes; what each event does comes from `balance.json`.
abstract class HapticsService {
  void perform(HapticKind kind);
}

/// Android/iOS system haptics (a no-op in browsers).
class SystemHapticsService implements HapticsService {
  @override
  void perform(HapticKind kind) {
    switch (kind) {
      case HapticKind.none:
        break;
      case HapticKind.selection:
        HapticFeedback.selectionClick();
      case HapticKind.light:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

/// Records vibrations (tests).
class RecordingHapticsService implements HapticsService {
  final List<HapticKind> performed = [];

  @override
  void perform(HapticKind kind) => performed.add(kind);
}
