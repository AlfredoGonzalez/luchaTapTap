import '../data/content_bundle.dart';
import 'ad_service.dart';
import 'billing_service.dart';

AdService createAdService(ContentBundle content) => FakeAdService();

BillingService createBillingService(ContentBundle content) =>
    FakeBillingService(
      placeholderPrice: content.strings['shop_price_placeholder'] ?? '',
    );
