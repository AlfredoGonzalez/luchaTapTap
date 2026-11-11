/// Shows rewarded ads. Ads are always optional and player-initiated.
///
/// The real implementation (AdMob, test ids until release) arrives with the
/// monetization milestone; until then the game runs on [FakeAdService] and
/// needs no SDK.
abstract class AdService {
  /// Shows a rewarded ad for [placement] and returns true when the player
  /// earned the reward. False means no ad was shown or it was not finished
  /// (no fill, offline, closed early): the caller must never block the base
  /// reward in that case.
  Future<bool> showRewarded(String placement);
}

/// Stand-in used by the prototype: "watches" an ad after a short pause.
class FakeAdService implements AdService {
  FakeAdService({
    this.succeeds = true,
    this.delay = const Duration(milliseconds: 600),
  });

  /// Whether the fake ad finishes (set false to test the no-fill path).
  bool succeeds;
  final Duration delay;

  /// Placements shown so far, for tests.
  final List<String> shown = [];

  @override
  Future<bool> showRewarded(String placement) async {
    shown.add(placement);
    await Future<void>.delayed(delay);
    return succeeds;
  }
}
