import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_state.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'rows.dart';

/// Price text of a shop item, from the billing service (never hard-coded).
final shopPriceProvider = FutureProvider.family<String?, String>((
  ref,
  id,
) async {
  final content = ref.watch(contentProvider);
  return ref.watch(billingServiceProvider).priceOf(content.shopItem(id));
});

String _clock(double seconds) {
  final total = seconds.ceil();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// "TIENDA": permanent purchases, Belt packs and free offers for an ad.
class ShopView extends ConsumerStatefulWidget {
  const ShopView({super.key});

  @override
  ConsumerState<ShopView> createState() => _ShopViewState();
}

class _ShopViewState extends ConsumerState<ShopView> {
  String? _message;
  bool _busy = false;

  Future<void> _use(ShopItemDef item) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await ref
        .read(gameControllerProvider.notifier)
        .buyShopItem(item.id);
    if (!mounted) return;
    final strings = ref.read(stringsProvider);
    setState(() {
      _busy = false;
      _message = switch (result) {
        ShopResult.done => strings.t('shop_thanks'),
        ShopResult.noAd => strings.t('shop_no_ad'),
        ShopResult.cooldown || ShopResult.cancelled => null,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final state = ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    final children = <Widget>[];
    for (final section in ShopSection.values) {
      final items = content.shopItems
          .where((i) => i.section == section)
          .toList();
      if (items.isEmpty) continue;
      children.add(SectionHeader(strings.t('shop_${section.name}')));
      for (final item in items) {
        children.add(_row(item, state, strings, controller));
      }
    }
    return Column(
      children: [
        ViewTitleBar(title: strings.t('view_shop')),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: scale.px(sideMargin)),
            children: children,
          ),
        ),
        SizedBox(
          height: scale.px(12),
          child: Center(
            child: PixelText(
              _message ?? '',
              color: Palette.sunYellow.color,
              align: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(
    ShopItemDef item,
    GameState state,
    Strings strings,
    GameController controller,
  ) {
    final icon = PixelIcons.byKey(item.icon) ?? PixelIcons.belt;
    final owned =
        item.kind == ShopKind.purchase && state.purchases.contains(item.id);
    final Widget button;
    var detail = item.detail;
    switch (item.kind) {
      case ShopKind.purchase:
      case ShopKind.beltPack:
        final price = ref.watch(shopPriceProvider(item.id));
        button = PixelButton(
          label: owned
              ? strings.t('shop_owned')
              : (price.hasValue
                    ? (price.value ?? strings.t('shop_unavailable'))
                    : ''),
          width: 52,
          style: PixelButtonStyle.confirm,
          semanticLabel: '${strings.t('shop_buy')} ${item.name}',
          onPressed: owned || _busy || (price.hasValue && price.value == null)
              ? null
              : () => _use(item),
        );
      case ShopKind.boost:
      case ShopKind.adBelt:
        final wait = controller.adOfferWait(item.id);
        final active = item.kind == ShopKind.boost && state.boostLeft > 0;
        if (active) {
          detail = strings.t('shop_boost_active', {
            's': state.boostLeft.ceil(),
          });
        }
        button = PixelButton(
          label: wait > 0 ? _clock(wait) : strings.t('shop_watch'),
          icon: wait > 0 ? null : PixelIcons.adWatch,
          width: 52,
          style: PixelButtonStyle.secondary,
          semanticLabel: '${strings.t('shop_watch')} ${item.name}',
          onPressed: wait > 0 || _busy ? null : () => _use(item),
        );
    }
    return ListRow(
      icon: icon,
      title: item.name,
      subtitle: detail,
      trailing: button,
    );
  }
}
