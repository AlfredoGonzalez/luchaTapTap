import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:lucha_tap_tap/data/content_models.dart';
import 'package:lucha_tap_tap/services/play_billing_service.dart';

import '../test_content.dart';

/// A store we control from the test.
class FakeStore extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> stream = StreamController.broadcast();
  bool available = true;
  bool startsPurchase = true;
  final List<String> consumable = [];
  final List<String> nonConsumable = [];
  final List<String> completed = [];
  List<PurchaseDetails> toRestore = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async => ProductDetailsResponse(
    productDetails: [
      for (final id in identifiers)
        ProductDetails(id: id, title: id, description: '', price: r'$29', rawPrice: 29, currencyCode: 'MXN'),
    ],
    notFoundIDs: [],
  );

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    nonConsumable.add(purchaseParam.productDetails.id);
    return startsPurchase;
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam, bool autoConsume = true}) async {
    consumable.add(purchaseParam.productDetails.id);
    return startsPurchase;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase.productID);

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    stream.add(toRestore);
  }

  void emit(String id, PurchaseStatus status, {bool needsCompletion = false}) {
    final p = PurchaseDetails(
      productID: id,
      verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
      transactionDate: null,
      status: status,
    )..pendingCompletePurchase = needsCompletion;
    stream.add([p]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late InAppPurchase wrapper;
  late FakeStore store;
  late PlayBillingService billing;
  late List<ShopItemDef> items;
  late ShopItemDef permanent;
  late ShopItemDef pack;

  setUpAll(() async {
    // Touching the singleton registers the Android implementation, which tries
    // to reach a platform channel that does not exist in tests; swallow that
    // error here. Our fake is installed after it, in setUp.
    runZonedGuarded(() => wrapper = InAppPurchase.instance, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  setUp(() {
    store = FakeStore();
    InAppPurchasePlatform.instance = store;
    final content = loadTestContent((f) {
      f['balance.json']!['monetization'] = {
        'adLoadTimeoutSeconds': 1,
        'restoreWaitSeconds': 0.05,
        'purchaseWaitSeconds': 0.3,
        'testRewardedUnitId': 'test-unit',
      };
    });
    items = content.shopItems;
    permanent = items.firstWhere((i) => i.kind == ShopKind.purchase);
    pack = items.firstWhere((i) => i.kind == ShopKind.beltPack);
    billing = PlayBillingService(items: items, config: content.balance.monetization, store: wrapper);
  });

  tearDown(() => billing.dispose());

  test('the price comes from the store; unavailable store means no price', () async {
    expect(await billing.priceOf(permanent), r'$29');
    store.available = false;
    final fresh = PlayBillingService(items: items, config: loadTestContent().balance.monetization, store: wrapper);
    addTearDown(fresh.dispose);
    expect(await fresh.priceOf(permanent), isNull);
  });

  test('a permanent item is bought as non-consumable and a belt pack as consumable', () async {
    final a = billing.buy(permanent);
    await Future<void>.delayed(Duration.zero);
    store.emit(permanent.id, PurchaseStatus.purchased, needsCompletion: true);
    expect(await a, isTrue);
    expect(store.nonConsumable, [permanent.id]);

    final b = billing.buy(pack);
    await Future<void>.delayed(Duration.zero);
    store.emit(pack.id, PurchaseStatus.purchased);
    expect(await b, isTrue);
    expect(store.consumable, [pack.id]);
    expect(store.completed, [permanent.id], reason: 'only purchases that ask for it are completed');
  });

  test('cancelled or failed purchases are not granted', () async {
    final a = billing.buy(permanent);
    await Future<void>.delayed(Duration.zero);
    store.emit(permanent.id, PurchaseStatus.canceled);
    expect(await a, isFalse);

    store.startsPurchase = false;
    expect(await billing.buy(pack), isFalse);
  });

  test('a purchase that never answers stops waiting after the data-defined time', () async {
    expect(await billing.buy(permanent), isFalse);
  });

  test('a payment that arrives with no purchase open is delivered to the game', () async {
    final seen = <String>[];
    final sub = billing.delivered.listen((i) => seen.add(i.id));
    addTearDown(sub.cancel);
    store.emit(pack.id, PurchaseStatus.purchased, needsCompletion: true);
    await Future<void>.delayed(Duration.zero);
    expect(seen, [pack.id]);
    expect(store.completed, [pack.id]);
  });

  test('restore returns the permanent purchases the store reports', () async {
    store.toRestore = [
      PurchaseDetails(
        productID: permanent.id,
        verificationData: PurchaseVerificationData(localVerificationData: '', serverVerificationData: '', source: 'test'),
        transactionDate: null,
        status: PurchaseStatus.restored,
      ),
    ];
    expect(await billing.restore(), {permanent.id});
    store.available = false;
    expect(await billing.restore(), isEmpty);
  });
}
