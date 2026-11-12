import '../data/content_bundle.dart';
import 'ad_service.dart';
import 'billing_service.dart';
import 'play_ad_service.dart';
import 'play_billing_service.dart';

AdService createAdService(ContentBundle content) =>
    PlayAdService(config: content.balance.monetization);

BillingService createBillingService(ContentBundle content) =>
    PlayBillingService(
      items: content.shopItems,
      config: content.balance.monetization,
    );
