import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/game_engine.dart';
import '../data/content_bundle.dart';
import '../core/number_format.dart';
import '../core/palette.dart';
import '../data/content_models.dart';
import '../game/sprite_library.dart';
import '../services/game_controller.dart';
import '../services/strings.dart';
import 'art_icon.dart';
import 'hud.dart';
import 'palette_color.dart';
import 'panels.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';
import 'ui_state.dart';

/// Slots in the collection grid (3 columns by 4 rows).
const int _gridColumns = 3;
const int _gridSlots = 12;
const double _tileHeight = 32;

/// Mask pictures are 24 x 24 here (the old glyphs are 16 x 16).
const double _maskArtSize = 24;

String _plain(double v) => v == v.roundToDouble()
    ? v.round().toString()
    : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');

String maskBonusText(Strings strings, MaskDef mask) {
  final isHours = mask.bonusType == MaskBonusType.offlineCapHours;
  final value = isHours
      ? _plain(mask.bonusValue)
      : _plain(mask.bonusValue * 100);
  return strings.t('mask_bonus_${mask.bonusType.name}', {'n': value});
}

/// The mask's icon recolored with its own three slot colors.
Widget maskIcon(WidgetRef ref, MaskDef mask) {
  final art = ref
      .watch(spriteLibraryProvider)
      .icon(SpriteLibrary.maskIconKey(mask.id));
  if (art != null) {
    // Already in the mask's colors.
    return ArtIcon(art, size: _maskArtSize);
  }
  final data = PixelIcons.byKey(mask.icon) ?? PixelIcons.maskJaguar;
  return PixelIcon(
    data,
    recolor: {
      Palette.nightPurple: Palette.byId[mask.slotColors[0]]!,
      Palette.violet: Palette.byId[mask.slotColors[1]]!,
      Palette.lilac: Palette.byId[mask.slotColors[2]]!,
    },
  );
}

/// Whether the mask pictures exist (otherwise the small glyphs and names show).
bool _hasArt(WidgetRef ref) {
  final first = ref.watch(contentProvider).masks.first;
  return ref
          .watch(spriteLibraryProvider)
          .icon(SpriteLibrary.maskIconKey(first.id)) !=
      null;
}

/// "MÁSCARAS": the collection grid (locked masks are `???`) and a detail panel
/// with the bonus and the equip, buy or locked state.
class MasksView extends ConsumerWidget {
  const MasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    ref.watch(gameControllerProvider);
    final strings = ref.watch(stringsProvider);
    final content = ref.watch(contentProvider);
    final engine = ref.read(gameControllerProvider.notifier).engine;
    final owned = content.masks.where((m) => engine.ownsMask(m.id)).length;
    final selectedId =
        ref.watch(selectedMaskProvider) ??
        engine.state.equippedMask ??
        content.masks.first.id;
    final selected = content.mask(selectedId);
    return Column(
      children: [
        ViewTitleBar(
          title: strings.t('view_masks'),
          trailing: PixelText(
            strings.t('masks_count', {'a': owned, 'b': content.masks.length}),
            color: Palette.fog.color,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(scale.px(sideMargin)),
            child: Column(
              children: [
                for (var row = 0; row < _gridSlots ~/ _gridColumns; row++) ...[
                  if (row > 0) SizedBox(height: scale.px(2)),
                  SizedBox(
                    height: scale.px(_tileHeight),
                    child: Row(
                      children: [
                        for (var col = 0; col < _gridColumns; col++) ...[
                          if (col > 0) SizedBox(width: scale.px(2)),
                          Expanded(
                            child: _tile(
                              ref,
                              strings,
                              engine,
                              content,
                              row * _gridColumns + col,
                              selectedId,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        DetailPanel(
          children: [
            _Detail(
              mask: selected,
              engine: engine,
              total: content.masks.length,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile(
    WidgetRef ref,
    Strings strings,
    GameEngine engine,
    ContentBundle content,
    int slot,
    String selectedId,
  ) {
    if (slot >= content.masks.length) {
      return _Tile(
        name: null,
        icon: null,
        selected: false,
        showName: !_hasArt(ref),
      );
    }
    final mask = content.masks[slot];
    final owned = engine.ownsMask(mask.id);
    return _Tile(
      name: owned ? mask.name : null,
      showName: !_hasArt(ref),
      icon: owned ? maskIcon(ref, mask) : null,
      selected: mask.id == selectedId,
      equipped: engine.state.equippedMask == mask.id,
      semanticLabel: owned ? mask.name : strings.t('mask_locked'),
      onTap: () => ref.read(selectedMaskProvider.notifier).select(mask.id),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.showName,
    this.equipped = false,
    this.semanticLabel,
    this.onTap,
  });

  final String? name;

  /// False when the masks have pictures: the 24 x 24 picture fills the tile
  /// and the name shows in the detail panel.
  final bool showName;
  final Widget? icon;
  final bool selected;
  final bool equipped;
  final String? semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (selected ? Palette.slate : Palette.nightPurple).color,
            border: Border.all(
              color:
                  (equipped
                          ? Palette.sunYellow
                          : (selected ? Palette.marigold : Palette.ink))
                      .color,
              width: scale.px(1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon ?? const PixelIcon(PixelIcons.maskLocked),
              if (showName) SizedBox(height: scale.px(2)),
              if (showName)
                ClipRect(
                  child: PixelText(
                    name ?? '???',
                    color: (name == null ? Palette.dust : Palette.bone).color,
                    align: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({
    required this.mask,
    required this.engine,
    required this.total,
  });

  final MaskDef mask;
  final GameEngine engine;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = PixelScale.of(context);
    final strings = ref.watch(stringsProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final owned = engine.ownsMask(mask.id);
    final equipped = engine.state.equippedMask == mask.id;

    final Widget button;
    final String info;
    if (owned) {
      info = maskBonusText(strings, mask);
      button = PixelButton(
        label: equipped
            ? strings.t('mask_equipped_big')
            : strings.t('mask_equip'),
        style: PixelButtonStyle.confirm,
        selected: equipped,
        onPressed: equipped ? null : () => controller.equipMask(mask.id),
      );
    } else {
      switch (mask.unlockRule) {
        case MaskUnlockRule.belts:
          final quote = engine.quoteMask(mask.id);
          info = strings.t('mask_unlock_belts_short', {
            'n': _plain(mask.unlockValue),
          });
          button = PixelButton(
            label: formatBigShort(quote.cost),
            icon: PixelIcons.belt,
            onPressed: quote.canBuy ? () => controller.buyMask(mask.id) : null,
          );
        case MaskUnlockRule.league:
          info = strings.t('mask_unlock_league', {
            'n': _plain(mask.unlockValue),
          });
          button = PixelButton(
            label: strings.t('mask_locked'),
            onPressed: null,
          );
        case MaskUnlockRule.shop:
          info = strings.t('mask_unlock_shop');
          button = PixelButton(
            label: strings.t('mask_locked'),
            onPressed: null,
          );
        case MaskUnlockRule.starter:
          info = maskBonusText(strings, mask);
          button = PixelButton(
            label: strings.t('mask_locked'),
            onPressed: null,
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: scale.px(_maskArtSize),
              height: scale.px(_maskArtSize),
              child: Center(
                child: owned
                    ? maskIcon(ref, mask)
                    : const PixelIcon(PixelIcons.maskLocked),
              ),
            ),
            SizedBox(width: scale.px(4)),
            Expanded(
              child: PixelText(
                owned ? mask.name : strings.t('mask_locked'),
                color: Palette.sunYellow.color,
              ),
            ),
          ],
        ),
        SizedBox(height: scale.px(3)),

        PixelText(info, wrap: true),
        SizedBox(height: scale.px(3)),
        SizedBox(width: double.infinity, child: button),
      ],
    );
  }
}
