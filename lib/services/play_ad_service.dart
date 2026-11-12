import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../data/balance.dart';
import 'ad_service.dart';

/// Rewarded ads through AdMob (`google_mobile_ads`). Rewarded only: no
/// banners, no interstitials, and an ad is only ever shown when the player
/// asks for the reward.
///
/// Non-release builds use Google's test unit; release builds use the id from
/// `balance.json` (`monetization.rewardedUnitId`) and have no ads until it is
/// set.
class PlayAdService implements AdService {
  PlayAdService({required this.config, this.release = kReleaseMode});

  final MonetizationConfig config;
  final bool release;
  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= MobileAds.instance
      .initialize()
      .then<void>((_) {})
      .catchError((Object e) {
        debugPrint('Could not start the ads SDK: $e');
        _init = null;
      });

  @override
  Future<bool> showRewarded(String placement) async {
    final unit = config.unitFor(release: release);
    if (unit == null) return false;
    try {
      await _ensureInitialized();
      final ad = await _load(unit);
      if (ad == null) return false;
      return await _show(ad);
    } catch (e) {
      debugPrint('Rewarded ad failed ($placement): $e');
      return false;
    }
  }

  Future<RewardedAd?> _load(String unit) {
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: unit,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (error) {
          debugPrint('No ad: ${error.message}');
          loaded.complete(null);
        },
      ),
    );
    return loaded.future.timeout(
      Duration(milliseconds: (config.adLoadTimeoutSeconds * 1000).round()),
      onTimeout: () => null,
    );
  }

  Future<bool> _show(RewardedAd ad) {
    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }
}
