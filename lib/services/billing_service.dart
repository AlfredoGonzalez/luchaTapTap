import '../data/content_models.dart';

/// Store purchases (Google Play Billing). Prices come from the store and are
/// never hard-coded; entitlements are checked from the store's answer, there is
/// no server.
///
/// The real implementation is `PlayBillingService` (Android); browsers and
/// tests run on [FakeBillingService] and need no SDK.
abstract class BillingService {
  /// Price text to show on the buy button (for example "$29"), or null when
  /// the store does not offer the item right now.
  Future<String?> priceOf(ShopItemDef item);

  /// Runs the purchase flow. True when the player paid.
  Future<bool> buy(ShopItemDef item);

  /// Ids of the one-time purchases the player already owns (restore purchases).
  Future<Set<String>> restore();

  /// Purchases that finished outside a [buy] call, for example a payment that
  /// completed after the app was closed. The game must grant them.
  Stream<ShopItemDef> get delivered;
}

/// Stand-in used by the prototype: shows a placeholder price and "buys"
/// instantly. It must never ship in a release build.
class FakeBillingService implements BillingService {
  FakeBillingService({required this.placeholderPrice, this.succeeds = true});

  final String placeholderPrice;

  /// Whether purchases go through (set false to test a cancelled purchase).
  bool succeeds;

  /// Items "bought" so far, for tests.
  final List<String> bought = [];

  /// What [restore] returns.
  final Set<String> owned = {};

  @override
  Future<String?> priceOf(ShopItemDef item) async => placeholderPrice;

  @override
  Stream<ShopItemDef> get delivered => const Stream.empty();

  @override
  Future<bool> buy(ShopItemDef item) async {
    if (!succeeds) return false;
    bought.add(item.id);
    if (item.kind == ShopKind.purchase) owned.add(item.id);
    return true;
  }

  @override
  Future<Set<String>> restore() async => Set.of(owned);
}
