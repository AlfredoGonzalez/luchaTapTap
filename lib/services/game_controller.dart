import 'dart:async';

import 'package:clock/clock.dart';
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
import 'audio_service.dart';
import 'billing_service.dart';
import 'haptics_service.dart';
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
    this.tutorialStep,
  });

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    sound: map['sound'] as bool? ?? true,
    music: map['music'] as bool? ?? true,
    vibration: map['vibration'] as bool? ?? false,
    notices: map['notices'] as bool? ?? false,
    tutorialStep: (map['tutorialStep'] as num?)?.toInt(),
  );

  final bool sound;
  final bool music;
  final bool vibration;

  /// "Avisos": tell the player when the offline cap is full (the
  /// notifications themselves arrive in a later milestone).
  final bool notices;

  /// Next tutorial step to show; past the last one means finished. Null on a
  /// save that never saw the tutorial (decided when the game starts).
  final int? tutorialStep;

  Map<String, dynamic> toMap() => {
    'sound': sound,
    'music': music,
    'vibration': vibration,
    'notices': notices,
    if (tutorialStep != null) 'tutorialStep': tutorialStep,
  };

  AppSettings copyWith({
    bool? sound,
    bool? music,
    bool? vibration,
    bool? notices,
    int? tutorialStep,
  }) => AppSettings(
    sound: sound ?? this.sound,
    music: music ?? this.music,
    vibration: vibration ?? this.vibration,
    notices: notices ?? this.notices,
    tutorialStep: tutorialStep ?? this.tutorialStep,
  );

  AppSettings toggled(String name) => switch (name) {
    'sound' => copyWith(sound: !sound),
    'music' => copyWith(music: !music),
    'vibration' => copyWith(vibration: !vibration),
    'notices' => copyWith(notices: !notices),
    _ => throw ArgumentError.value(name, 'name', 'unknown setting'),
  };
}

/// Sound output. The app overrides this with real playback; tests use the
/// silent or recording service.
final audioServiceProvider = Provider<AudioService>(
  (ref) => SilentAudioService(),
);

final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => SystemHapticsService(),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() =>
      AppSettings.fromMap(ref.read(initialSaveProvider)?.settings ?? const {});

  void toggle(String name) {
    state = state.toggled(name);
    final controller = ref.read(gameControllerProvider.notifier);
    controller.syncAudio();
    controller.saveNow();
  }

  void reset() => state = const AppSettings();

  /// Remembers how far the tutorial went (saved with the game).
  void setTutorialStep(int step) {
    state = state.copyWith(tutorialStep: step);
    ref.read(gameControllerProvider.notifier).saveNow();
  }
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
    this.isKick = false,
  });

  final Big damage;
  final bool isTap;
  final bool defeated;

  /// Critical hits and finishers use the large yellow number.
  final bool isBig;

  /// The finisher: the player kicks instead of punching.
  final bool isKick;
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
  final StreamController<String> _skillUsed =
      StreamController<String>.broadcast();
  final StreamController<void> _bossLost = StreamController<void>.broadcast();
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

  /// A skill was used (its id), for its animation.
  Stream<String> get skillUsed => _skillUsed.stream;

  /// The boss timer ran out (the player lost the fight).
  Stream<void> get bossLost => _bossLost.stream;

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
      _bossLost.close();
      _skillUsed.close();
      gestureTrail.dispose();
      gestureCircles.dispose();
    });
    // Purchases that finished while no purchase was open (paid, then the app
    // closed) are granted when the store reports them.
    final delivered = ref.read(billingServiceProvider).delivered.listen(
      _grantDelivered,
    );
    ref.onDispose(delivered.cancel);
    // Start the music once the providers are ready.
    Future.microtask(syncAudio);
    return _engine.state;
  }

  // ---------------------------------------------------------------------------
  // Time

  void _onPoll() {
    if (!ref.mounted) {
      _timer?.cancel();
      return;
    }
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
    final wasBoss = _engine.isBossFight;
    for (var i = 0; i < ticks; i++) {
      final outcome = _engine.tick();
      damage += outcome.damageDealt;
      defeated = defeated || outcome.defeats > 0;
      timedOut = timedOut || outcome.bossTimedOut;
    }
    if (defeated && wasBoss) _afterBossWin();
    _publish();
    if (!damage.isZero) {
      _hits.add(HitEvent(damage: damage, isTap: false, defeated: defeated));
    }
    if (timedOut) _bossLost.add(null); // the defeat tip waits for "Aceptar"
  }

  void _publish() {
    state = _engine.state;
    syncAudio();
  }

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
        _sfx(Sfx.error);
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
    ref.read(audioServiceProvider).pause();
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
    ref.read(audioServiceProvider).resume();
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

  // Sound, music and vibration -------------------------------------------

  void _sfx(Sfx sfx) {
    if (!ref.read(settingsProvider).sound) return;
    final audio = ref.read(contentProvider).balance.audio;
    ref
        .read(audioServiceProvider)
        .playSfx(sfx, volume: (audio.master * audio.sfx).clamp(0.0, 1.0));
  }

  void _buzz(String event) {
    if (!ref.read(settingsProvider).vibration) return;
    final kind = ref.read(contentProvider).balance.haptics.of(event);
    ref.read(hapticsServiceProvider).perform(kind);
  }

  MusicTrack? _musicNow;
  double _musicVolumeNow = -1;

  /// Plays the music that fits the screen (boss music during a boss fight) at
  /// the volume the settings allow. Called after every state change; the audio
  /// service is only touched when something actually changed.
  void syncAudio() {
    final audio = ref.read(audioServiceProvider);
    final settings = ref.read(settingsProvider);
    if (!settings.music) {
      if (_musicNow != null) audio.stopMusic();
      _musicNow = null;
      _musicVolumeNow = -1;
      return;
    }
    final levels = ref.read(contentProvider).balance.audio;
    final volume = (levels.master * levels.music).clamp(0.0, 1.0);
    final track = _engine.isBossFight ? MusicTrack.boss : MusicTrack.main;
    if (track == _musicNow && volume == _musicVolumeNow) return;
    _musicNow = track;
    _musicVolumeNow = volume;
    audio.playMusic(track, volume: volume);
  }

  /// Pop-ups play a small sound when they open and close.
  void popupSound({required bool open}) =>
      _sfx(open ? Sfx.popupOpen : Sfx.popupClose);

  void _afterDefeat({required bool wasBoss}) =>
      wasBoss ? _afterBossWin() : _sfx(Sfx.hit);

  void _afterBossWin() {
    _sfx(Sfx.victory);
    _buzz('victory');
  }

  void tap() {
    final wasBoss = _engine.isBossFight;
    final outcome = _engine.tap();
    if (outcome.damageDealt.isZero) return; // the boss intro is showing
    if (outcome.defeats > 0) {
      _afterDefeat(wasBoss: wasBoss);
    } else {
      _sfx(outcome.isCrit ? Sfx.crit : Sfx.tap);
    }
    _buzz(outcome.isCrit ? 'crit' : 'tap');
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
    final wasBoss = _engine.isBossFight;
    final outcome = _engine.finisher();
    if (outcome == null) return;
    _sfx(Sfx.finisher);
    _buzz('finisher');
    if (outcome.defeats > 0) _afterDefeat(wasBoss: wasBoss);
    _publish();
    _hits.add(
      HitEvent(
        damage: outcome.damageDealt,
        isTap: true,
        defeated: outcome.defeats > 0,
        isBig: true,
        isKick: true,
      ),
    );
  }

  void _afterBuy(BuyQuote quote) {
    if (quote.canBuy) {
      _publish();
      _sfx(Sfx.buy);
      _buzz('buy');
    } else {
      _sfx(Sfx.error);
    }
  }

  BuyQuote buyUpgrade(String id) {
    final quote = _engine.buyUpgrade(id, ref.read(buyAmountProvider));
    _afterBuy(quote);
    return quote;
  }

  BuyQuote buyTrainer(String id) {
    final quote = _engine.buyTrainer(id, ref.read(buyAmountProvider));
    _afterBuy(quote);
    return quote;
  }

  BuyQuote buySkill(String id) {
    final quote = _engine.buySkill(id);
    _afterBuy(quote);
    return quote;
  }

  void useSkill(String id) {
    final wasBoss = _engine.isBossFight;
    final result = _engine.useSkill(id);
    if (!result.ok) return;
    _sfx(Sfx.crit);
    _skillUsed.add(id);
    if (result.outcome.defeats > 0) _afterDefeat(wasBoss: wasBoss);
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
    if (!_engine.challengeBoss()) return;
    _sfx(Sfx.bossIntro);
    _buzz('bossIntro');
    _publish();
  }

  /// "Aceptar" on the defeat tip: back to the farming fight.
  void acknowledgeBossLoss() {
    if (_engine.acknowledgeBossLoss()) _publish();
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
    _afterBuy(quote);
    return quote;
  }

  BuyQuote buyMask(String id) {
    final quote = _engine.buyMask(id);
    _afterBuy(quote);
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

  void _grantDelivered(ShopItemDef item) {
    if (item.kind == ShopKind.purchase) {
      if (_engine.ownsPurchase(item.id)) return;
      _engine.grantPurchase(item.id);
    } else if (item.kind == ShopKind.beltPack) {
      _engine.grantBeltPack(item.id);
    } else {
      return;
    }
    _publish();
    saveNow();
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

  /// Gives coins that do not count as earned (the tutorial's gift).
  void grantCoins(Big amount) {
    _engine.grantCoins(amount);
    _publish();
  }

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
