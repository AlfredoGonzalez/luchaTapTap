import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/balance.dart';
import '../data/content_models.dart';
import 'billing_service.dart';

/// Google Play Billing through `in_app_purchase`. The Play product id of each
/// item is its shop id (`mas_descanso`, `belts_20`, ...); create the products
/// in Play Console with those ids (permanent items as one-time products, belt
/// packs as consumable ones).
///
/// Prices come from the store. Ownership comes from the store's answer; there
/// is no server.
class PlayBillingService implements BillingService {
  PlayBillingService({
    required this.items,
    required this.config,
    InAppPurchase? store,
  }) : _store = store ?? InAppPurchase.instance {
    _sub = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => debugPrint('Purchase stream error: $e'),
    );
  }

  final List<ShopItemDef> items;
  final MonetizationConfig config;
  final InAppPurchase _store;
  late final StreamSubscription<List<PurchaseDetails>> _sub;

  final StreamController<ShopItemDef> _delivered =
      StreamController<ShopItemDef>.broadcast();
  final Map<String, Completer<bool>> _open = {};
  final Set<String> _restored = {};
  Map<String, ProductDetails>? _products;

  bool _isStoreItem(ShopItemDef i) =>
      i.kind == ShopKind.purchase || i.kind == ShopKind.beltPack;

  ShopItemDef? _item(String id) {
    for (final i in items) {
      if (i.id == id && _isStoreItem(i)) return i;
    }
    return null;
  }

  Future<ProductDetails?> _details(ShopItemDef item) async {
    try {
      if (_products == null) {
        if (!await _store.isAvailable()) return null;
        final response = await _store.queryProductDetails({
          for (final i in items)
            if (_isStoreItem(i)) i.id,
        });
        _products = {for (final d in response.productDetails) d.id: d};
      }
      return _products![item.id];
    } catch (e) {
      debugPrint('Could not read the store products: $e');
      return null;
    }
  }

  @override
  Stream<ShopItemDef> get delivered => _delivered.stream;

  @override
  Future<String?> priceOf(ShopItemDef item) async =>
      (await _details(item))?.price;

  @override
  Future<bool> buy(ShopItemDef item) async {
    final details = await _details(item);
    if (details == null) return false;
    final done = Completer<bool>();
    _open[item.id] = done;
    try {
      final param = PurchaseParam(productDetails: details);
      final started = item.kind == ShopKind.beltPack
          ? await _store.buyConsumable(purchaseParam: param)
          : await _store.buyNonConsumable(purchaseParam: param);
      if (!started) return false;
      return await done.future.timeout(
        Duration(milliseconds: (config.purchaseWaitSeconds * 1000).round()),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('Purchase failed: $e');
      return false;
    } finally {
      _open.remove(item.id);
    }
  }

  @override
  Future<Set<String>> restore() async {
    try {
      if (!await _store.isAvailable()) return {};
      _restored.clear();
      await _store.restorePurchases();
      // Restored purchases arrive on the stream; give the store a moment.
      await Future<void>.delayed(
        Duration(milliseconds: (config.restoreWaitSeconds * 1000).round()),
      );
      return Set.of(_restored);
    } catch (e) {
      debugPrint('Could not restore purchases: $e');
      return {};
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      final item = _item(p.productID);
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
        case PurchaseStatus.canceled:
          _open[p.productID]?.complete(false);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (item != null) {
            if (p.status == PurchaseStatus.restored) {
              _restored.add(item.id);
            } else if (_open[item.id] case final waiting?) {
              if (!waiting.isCompleted) waiting.complete(true);
            } else {
              // Paid while no purchase was open (for example before the app
              // was closed): hand it to the game now.
              _delivered.add(item);
            }
          }
      }
      if (p.pendingCompletePurchase) {
        try {
          await _store.completePurchase(p);
        } catch (e) {
          debugPrint('Could not complete a purchase: $e');
        }
      }
    }
  }

  void dispose() {
    _sub.cancel();
    _delivered.close();
  }
}
