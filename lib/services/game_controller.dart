import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big.dart';
import '../core/buy_amount.dart';
import '../core/fixed_step.dart';
import '../core/finisher_gesture.dart';
import '../core/game_engine.dart';
import '../core/game_state.dart';
import '../core/rng.dart';
import '../core/save_codec.dart';
import '../data/content_bundle.dart';
import '../data/content_models.dart';
import 'ad_service.dart';
import 'billing_service.dart';
import 'save_store.dart';
import 'strings.dart';

/// Provided at startup with the validated content (see `main.dart`).
final contentProvider = Provider<ContentBundle>(
  (ref) => throw UnimplementedError('contentProvider must be overridden'),
);

/// Spanish text lookup.
final stringsProvider = Provider<Strings>(
  (ref) => Strings(ref.watch(contentProvider).strings),
);

final saveCodecProvider = Provider<SaveCodec>(
  (ref) => SaveCodec(content: ref.watch(contentProvider)),
);

/// Where the game saves. The app overrides this with a file store; tests and
/// the prototype default to memory.
final saveStoreProvider = Provider<SaveStore>((ref) => MemorySaveStore());

/// The save found at startup, if any (overridden in `main.dart`).
final initialSaveProvider = Provider<SaveData?>((ref) => null);

final adServiceProvider = Provider<AdService>((ref) => FakeAdService());

final billingServiceProvider = Provider<BillingService>(
  (ref) => FakeBillingService(
    placeholderPrice:
        ref.watch(contentProvider).strings['shop_price_placeholder'] ?? '',
  ),
);

/// Player settings, saved with the game.
class AppSettings {
  const AppSettings({
    this.sound = true,
    this.music = true,
    this.vibration = false,
    this.notices = false,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    sound: map['sound'] as bool? ?? true,
    music: map['music'] as bool? ?? true,
    vibration: map['vibration'] as bool? ?? false,
    notices: map['notices'] as bool? ?? false,
  );

  final bool sound;
  final bool music;
  final bool vibration;

  /// "Avisos": tell the player when the offline cap is full (the
  /// notifications themselves arrive in a later milestone).
  final bool notices;

  Map<String, dynamic> toMap() => {
    'sound': sound,
    'music': music,
    'vibration': vibration,
    'notices': notices,
  };

  AppSettings toggled(String name) => switch (name) {
    'sound' => AppSettings(
      sound: !sound,
      music: music,
      vibration: vibration,
      notices: notices,
    ),
    'music' => AppSettings(
      sound: sound,
      music: !music,
      vibration: vibration,
      notices: notices,
    ),
    'vibration' => AppSettings(
      sound: sound,
      music: music,
      vibration: !vibration,
      notices: notices,
    ),
    'notices' => AppSettings(
      sound: sound,
      music: music,
      vibration: vibration,
      notices: !notices,
    ),
    _ => throw ArgumentError.value(name, 'name', 'unknown setting'),
  };
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() =>
      AppSettings.fromMap(ref.read(initialSaveProvider)?.settings ?? const {});

  void toggle(String name) {
    state = state.toggled(name);
    ref.read(gameControllerProvider.notifier).saveNow();
  }

  void reset() => state = const AppSettings();
}

/// Result of using a store item.
enum ShopResult { done, cancelled, cooldown, noAd }

/// Selected buy quantity (x1, x10, x100, MAX).
final buyAmountProvider = NotifierProvider<BuyAmountNotifier, BuyAmount>(
  BuyAmountNotifier.new,
);

class BuyAmountNotifier extends Notifier<BuyAmount> {
  @override
  BuyAmount build() =>
      BuyAmount.fixed(ref.read(contentProvider).balance.buyFixedAmounts.first);

  void select(BuyAmount amount) => state = amount;
}

/// A short message shown over the arena (string key), or null.
final noticeProvider = NotifierProvider<NoticeNotifier, String?>(
  NoticeNotifier.new,
);

class NoticeNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String key) {
    _timer?.cancel();
    state = key;
    final seconds = ref.read(contentProvider).balance.ui.noticeSeconds;
    _timer = Timer(
      Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      ),
      () => state = null,
    );
  }
}

/// A hit shown in the arena: a tap, a finisher or an idle tick.
class HitEvent {
  const HitEvent({
    required this.damage,
    required this.isTap,
    required this.defeated,
    this.isBig = false,
  });

  final Big damage;
  final bool isTap;
  final bool defeated;

  /// Critical hits and finishers use the large yellow number.
  final bool isBig;
}

final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

/// Connects the pure-Dart [GameEngine] to the app: runs the fixed tick,
/// applies actions immediately, saves, and handles the app going to the
/// background and coming back (offline earnings).
class GameController extends Notifier<GameState> with WidgetsBindingObserver {
  /// How often the timer wakes up to check whether a tick is due. This is only
  /// polling granularity; the simulation itself advances in fixed steps.
  static const Duration _pollInterval = Duration(milliseconds: 25);

  late final GameEngine _engine;
  late final FixedStepper _stepper;
  late final FinisherGesture _gesture;
  late final SaveCodec _codec;
  late final SaveStore _store;
  // `clock.stopwatch()` is the real clock in the app and the fake clock in
  // widget tests, so progress can be tested without waiting.
  final Stopwatch _clock = clock.stopwatch();
  final StreamController<HitEvent> _hits =
      StreamController<HitEvent>.broadcast();
  Duration _lastElapsed = Duration.zero;
  Duration _lastSaveElapsed = Duration.zero;
  Timer? _timer;
  DateTime? _backgroundAt;
  bool _active = true;
  Future<void> _pendingSave = Future.value();

  GameEngine get engine => _engine;

  /// Points of the finisher gesture being drawn (virtual pixels), for the trail.
  final ValueNotifier<List<Offset>> gestureTrail = ValueNotifier(const []);

  /// Circles of the finisher gesture already done (0 to 2).
  final ValueNotifier<int> gestureCircles = ValueNotifier(0);

  /// Taps, finishers and idle hits, for floating damage numbers and flashes.
  Stream<HitEvent> get hits => _hits.stream;

  @override
  GameState build() {
    final content = ref.read(contentProvider);
    _codec = ref.read(saveCodecProvider);
    _store = ref.read(saveStoreProvider);
    final save = ref.read(initialSaveProvider);

    _engine = GameEngine(
      content: content,
      state: save?.state,
      rng: save == null ? null : SeededRng(save.rngState),
    )..repair();
    if (save != null) {
      // Cold start: everything since the last save counts as time away.
      _engine.applyOffline(clock.now().toUtc().difference(save.lastSeen));
    }

    _gesture = FinisherGesture(content.balance.gesture);
    _stepper = FixedStepper(
      ticksPerSecond: content.balance.ticksPerSecond,
      maxCatchUpTicks: content.balance.maxCatchUpTicks,
    );
    _clock.start();
    _timer = Timer.periodic(_pollInterval, (_) => _onPoll());
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
      _hits.close();
      gestureTrail.dispose();
      gestureCircles.dispose();
    });
    return _engine.state;
  }

  // ---------------------------------------------------------------------------
  // Time

  void _onPoll() {
    final now = _clock.elapsed;
    if (!_active) {
      _lastElapsed = now;
      return;
    }
    final balance = ref.read(contentProvider).balance;
    if ((now - _lastSaveElapsed).inMicroseconds >=
        balance.saveIntervalSeconds * Duration.microsecondsPerSecond) {
      saveNow();
    }
    _pollGesture(now);
    final ticks = _stepper.advance(now - _lastElapsed);
    _lastElapsed = now;
    if (ticks == 0) return;
    var damage = Big.zero;
    var defeated = false;
    var timedOut = false;
    for (var i = 0; i < ticks; i++) {
      final outcome = _engine.tick();
      damage += outcome.damageDealt;
      defeated = defeated || outcome.defeats > 0;
      timedOut = timedOut || outcome.bossTimedOut;
    }
    _publish();
    if (!damage.isZero) {
      _hits.add(HitEvent(damage: damage, isTap: false, defeated: defeated));
    }
    if (timedOut) ref.read(noticeProvider.notifier).show('boss_failed');
  }

  void _publish() => state = _engine.state;

  double _seconds(Duration d) => d.inMicroseconds / Duration.microsecondsPerSecond;

  // ---------------------------------------------------------------------------
  // Finisher gesture: two circles in opposite directions

  /// A finger went down in the arena (position in virtual pixels). The gesture
  /// only counts while the combo meter is full.
  void gesturePointerDown(double x, double y) {
    if (!_engine.finisherReady || _engine.awaitingBossStart) return;
    _gesture.pointerDown(x, y, _seconds(_clock.elapsed));
    _afterGesture();
  }

  void gesturePointerMove(double x, double y) {
    if (!_engine.finisherReady) return;
    _gesture.pointerMove(x, y, _seconds(_clock.elapsed));
    _afterGesture();
  }

  void gesturePointerUp() {
    if (!_engine.finisherReady) return;
    _gesture.pointerUp(_seconds(_clock.elapsed));
    _afterGesture();
  }

  void _pollGesture(Duration now) {
    if (!_engine.finisherReady) {
      if (_gesture.status != GestureStatus.idle) _resetGesture();
      return;
    }
    if (_gesture.isDrawing) {
      _gesture.tick(_seconds(now));
      _afterGesture();
    }
  }

  void _resetGesture() {
    _gesture.reset();
    gestureTrail.value = const [];
    gestureCircles.value = 0;
  }

  void _afterGesture() {
    switch (_gesture.status) {
      case GestureStatus.success:
        _resetGesture();
        finisher();
      case GestureStatus.failed:
        _resetGesture();
        _engine.failFinisher();
        _publish();
        ref.read(noticeProvider.notifier).show('gesture_failed');
      case GestureStatus.drawing:
        gestureTrail.value = [for (final p in _gesture.trail) Offset(p.x, p.y)];
        gestureCircles.value = _gesture.circlesDone;
      case GestureStatus.idle:
        break;
    }
  }

  @override
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        saveNow();
      case AppLifecycleState.paused:
        onBackground();
      case AppLifecycleState.resumed:
        onForeground();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// The app left the screen: save right away and remember when.
  void onBackground() {
    if (!_active) return;
    _active = false;
    _backgroundAt = clock.now().toUtc();
    saveNow();
  }

  /// The app is back: whatever idle progress happened while away is simulated
  /// and shown in the offline earnings pop-up.
  void onForeground() {
    final left = _backgroundAt;
    _backgroundAt = null;
    _lastElapsed = _clock.elapsed;
    _active = true;
    if (left == null) return;
    _engine.applyOffline(clock.now().toUtc().difference(left));
    _publish();
    saveNow();
  }

  // ---------------------------------------------------------------------------
  // Saving

  /// Writes the save now (also called every `saveIntervalSeconds` and when the
  /// app goes to the background). Writes are queued so they never overlap.
  Future<void> saveNow() {
    _lastSaveElapsed = _clock.elapsed;
    final data = SaveData(
      saveVersion: _codec.currentVersion,
      lastSeen: clock.now().toUtc(),
      rngState: _engine.rng.state,
      state: _engine.state,
      settings: ref.read(settingsProvider).toMap(),
    );
    _pendingSave = _pendingSave.then((_) => _store.save(data)).catchError((
      Object e,
    ) {
      debugPrint('Could not save the game: $e');
    });
    return _pendingSave;
  }

  // ---------------------------------------------------------------------------
  // Player actions

  void _haptic() {
    if (ref.read(settingsProvider).vibration) HapticFeedback.lightImpact();
  }

  void tap() {
    final outcome = _engine.tap();
    if (outcome.damageDealt.isZero) return; // the boss intro is showing
    _haptic();
    _publish();
    _hits.add(
      HitEvent(
        damage: outcome.damageDealt,
        isTap: true,
        defeated: outcome.defeats > 0,
        isBig: outcome.isCrit,
      ),
    );
  }

  void finisher() {
    final outcome = _engine.finisher();
    if (outcome == null) return;
    _haptic();
    _publish();
    _hits.add(
      HitEvent(
        damage: outcome.damageDealt,
        isTap: true,
        defeated: outcome.defeats > 0,
        isBig: true,
      ),
    );
  }

  BuyQuote buyUpgrade(String id) {
    final quote = _engine.buyUpgrade(id, ref.read(buyAmountProvider));
    if (quote.canBuy) _publish();
    return quote;
  }

  BuyQuote buyTrainer(String id) {
    final quote = _engine.buyTrainer(id, ref.read(buyAmountProvider));
    if (quote.canBuy) _publish();
    return quote;
  }

  BuyQuote buySkill(String id) {
    final quote = _engine.buySkill(id);
    if (quote.canBuy) _publish();
    return quote;
  }

  void useSkill(String id) {
    final result = _engine.useSkill(id);
    if (!result.ok) return;
    _publish();
    if (result.outcome.damageDealt > Big.zero) {
      _hits.add(
        HitEvent(
          damage: result.outcome.damageDealt,
          isTap: true,
          defeated: result.outcome.defeats > 0,
          isBig: true,
        ),
      );
    }
  }

  /// "¡A PELEAR!": the boss intro is over, the countdown starts.
  void startBoss() {
    _engine.startBoss();
    _publish();
  }

  /// "¡JEFE!": leave the farming fight for the boss (its intro shows).
  void challengeBoss() {
    if (_engine.challengeBoss()) _publish();
  }

  /// "Volver" on the boss intro: back to the farming fight.
  void abandonBoss() {
    if (_engine.abandonBoss()) _publish();
  }

  void collectLucky() {
    if (_engine.collectLucky() != null) _publish();
  }

  BuyQuote buyTalent(String id) {
    final quote = _engine.buyTalent(id);
    if (quote.canBuy) _publish();
    return quote;
  }

  BuyQuote buyMask(String id) {
    final quote = _engine.buyMask(id);
    if (quote.canBuy) _publish();
    return quote;
  }

  void equipMask(String id) {
    if (_engine.equipMask(id)) _publish();
  }

  bool prestige() {
    final done = _engine.prestige();
    if (done) {
      _publish();
      saveNow();
    }
    return done;
  }

  /// Pays the offline earnings, doubled when [watchAd] is true and the ad is
  /// finished. Returns false when the ad was asked for but not completed; in
  /// that case nothing is paid yet so the player can still collect the base
  /// amount.
  Future<bool> collectOffline({bool watchAd = false}) async {
    var multiplier = 1.0;
    if (watchAd) {
      final ok = await ref
          .read(adServiceProvider)
          .showRewarded('offline_double');
      if (!ok) return false;
      multiplier = ref.read(contentProvider).balance.offline.adMultiplier;
    }
    _engine.collectOffline(multiplier: multiplier);
    _publish();
    saveNow();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Shop and settings

  int get _nowMs => clock.now().toUtc().millisecondsSinceEpoch;

  /// Uses a shop item: real-money items go through the billing service, the
  /// free offers through a rewarded ad (and a cooldown from the data).
  Future<ShopResult> buyShopItem(String id) async {
    final item = _engine.content.shopItem(id);
    switch (item.kind) {
      case ShopKind.purchase:
      case ShopKind.beltPack:
        final paid = await ref.read(billingServiceProvider).buy(item);
        if (!paid) return ShopResult.cancelled;
        if (item.kind == ShopKind.purchase) {
          _engine.grantPurchase(id);
        } else {
          _engine.grantBeltPack(id);
        }
      case ShopKind.boost:
      case ShopKind.adBelt:
        if (_engine.adOfferWait(id, _nowMs) > 0) return ShopResult.cooldown;
        final watched = await ref
            .read(adServiceProvider)
            .showRewarded('shop_$id');
        if (!watched) return ShopResult.noAd;
        if (!_engine.claimAdOffer(id, _nowMs)) return ShopResult.cooldown;
    }
    _publish();
    saveNow();
    return ShopResult.done;
  }

  /// Asks the store for the one-time purchases the player owns and grants them
  /// again. Returns how many were restored.
  Future<int> restorePurchases() async {
    final owned = await ref.read(billingServiceProvider).restore();
    var restored = 0;
    for (final id in owned) {
      final known = _engine.content.shopItems.any(
        (i) => i.id == id && i.kind == ShopKind.purchase,
      );
      if (known && !_engine.ownsPurchase(id)) {
        _engine.grantPurchase(id);
        restored++;
      }
    }
    if (restored > 0) {
      _publish();
      saveNow();
    }
    return restored;
  }

  /// Seconds until the rewarded-ad offer [id] is ready again (0 when ready).
  double adOfferWait(String id) => _engine.adOfferWait(id, _nowMs);

  /// Deletes the whole save and starts a new game ("Borrar datos").
  Future<void> deleteAllData() async {
    await _pendingSave;
    await _store.delete();
    _engine.resetAll();
    ref.read(settingsProvider.notifier).reset();
    _publish();
  }

  // ---------------------------------------------------------------------------
  // Debug tools (opened from the debug panel in debug builds)

  void debugAddCoins(double amount) {
    _engine.debugAddCoins(Big.fromDouble(amount));
    _publish();
  }

  void debugSkipFight() {
    _engine.debugSkipFights(1);
    _publish();
  }

  void debugGoToBoss() {
    _engine.debugGoToBoss();
    _publish();
  }

  /// Runs [minutes] of normal play time at once (all systems tick).
  void debugFastForward(int minutes) {
    final ticks =
        minutes * 60 * ref.read(contentProvider).balance.ticksPerSecond;
    for (var i = 0; i < ticks; i++) {
      _engine.tick();
    }
    _publish();
  }

  /// Pretends the app was closed for [hours] and shows the offline pop-up.
  void debugSimulateAbsence(int hours) {
    _engine.applyOffline(Duration(hours: hours));
    _publish();
  }
}
