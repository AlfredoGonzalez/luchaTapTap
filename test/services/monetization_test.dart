import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucha_tap_tap/core/big.dart';
import 'package:lucha_tap_tap/data/content_models.dart';
import 'package:lucha_tap_tap/services/billing_service.dart';
import 'package:lucha_tap_tap/services/game_controller.dart';

import '../test_content.dart';

class DeliveringBilling extends FakeBillingService {
  DeliveringBilling() : super(placeholderPrice: r'$XX');
  final StreamController<ShopItemDef> controller = StreamController.broadcast();

  @override
  Stream<ShopItemDef> get delivered => controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('non-release builds always use the Google test ad unit; release needs your own', () {
    final m = loadTestContent((f) {
      f['balance.json']!['monetization'] = {
        'adLoadTimeoutSeconds': 5,
        'restoreWaitSeconds': 5,
        'purchaseWaitSeconds': 5,
        'testRewardedUnitId': 'test-unit',
      };
    }).balance.monetization;
    expect(m.unitFor(release: false), 'test-unit');
    expect(m.unitFor(release: true), isNull, reason: 'no ads until a real unit id is set');
  });

  test('a release unit id is used in release builds only', () {
    final m = loadTestContent((f) {
      f['balance.json']!['monetization'] = {
        'adLoadTimeoutSeconds': 5,
        'restoreWaitSeconds': 5,
        'purchaseWaitSeconds': 5,
        'testRewardedUnitId': 'test-unit',
        'rewardedUnitId': 'real-unit',
      };
    }).balance.monetization;
    expect(m.unitFor(release: true), 'real-unit');
    expect(m.unitFor(release: false), 'test-unit');
  });

  test('a purchase that finished while the app was closed is granted once it arrives', () async {
    final content = loadTestContent();
    final billing = DeliveringBilling();
    final container = ProviderContainer(
      overrides: [contentProvider.overrideWithValue(content), billingServiceProvider.overrideWithValue(billing)],
    );
    addTearDown(container.dispose);
    final controller = container.read(gameControllerProvider.notifier);
    final permanent = content.shopItems.firstWhere((i) => i.kind == ShopKind.purchase);
    final pack = content.shopItems.firstWhere((i) => i.kind == ShopKind.beltPack);
    final beltsBefore = controller.engine.state.belts;

    billing.controller.add(permanent);
    billing.controller.add(permanent); // a repeated delivery must not double it
    billing.controller.add(pack);
    await Future<void>.delayed(Duration.zero);

    expect(controller.engine.ownsPurchase(permanent.id), isTrue);
    expect(controller.engine.state.belts, beltsBefore + Big.fromDouble(pack.belts.toDouble()));
  });
}
