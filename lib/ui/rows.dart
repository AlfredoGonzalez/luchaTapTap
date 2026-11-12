import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/palette.dart';
import '../services/game_controller.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';
import 'pixel_widgets.dart';

const double rowHeight = 26;
const double rowGap = 2;
const double costButtonWidth = 56;

/// Flashes Sun Yellow for the data-defined time when [value] goes up (a
/// successful purchase), as the style guide asks.
class FlashOnIncrease extends ConsumerStatefulWidget {
  const FlashOnIncrease({super.key, required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  ConsumerState<FlashOnIncrease> createState() => _FlashOnIncreaseState();
}

class _FlashOnIncreaseState extends ConsumerState<FlashOnIncrease> {
  Timer? _timer;
  bool _flashing = false;

  @override
  void didUpdateWidget(FlashOnIncrease old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) {
      final seconds = ref.read(contentProvider).balance.ui.purchaseFlashSeconds;
      _timer?.cancel();
      setState(() => _flashing = true);
      _timer = Timer(
        Duration(
          microseconds: (seconds * Duration.microsecondsPerSecond).round(),
        ),
        () {
          if (mounted) setState(() => _flashing = false);
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: _flashing ? Palette.sunYellow.color : const Color(0x00000000),
    child: widget.child,
  );
}

/// One list row: 16 x 16 icon, two lines of text and a trailing button.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.icon,
    this.iconWidget,
    this.titleColor,
    this.selected = false,
    this.onTap,
    this.height = rowHeight,
    this.progress,
    this.onInfo,
    this.infoLabel = '',
  });

  final String title;
  final String subtitle;
  final Widget trailing;
  final PixelIconData? icon;

  /// Replaces [icon] when the icon needs a recolor.
  final Widget? iconWidget;
  final Color? titleColor;
  final bool selected;
  final VoidCallback? onTap;
  final double height;

  /// Optional 0..1 progress drawn as a 1-pixel bar on the row's bottom edge
  /// (progress to the next milestone).
  final double? progress;

  /// Shows a small "i" on the icon; tapping the icon area calls this (the
  /// touch area is 24 pixels wide). [infoLabel] is its accessibility label.
  final VoidCallback? onInfo;
  final String infoLabel;

  Widget _iconArea(PixelScale scale) {
    final art = SizedBox(
      width: scale.px(16),
      height: scale.px(16),
      child:
          iconWidget ??
          (icon == null
              ? ColoredBox(color: Palette.slate.color)
              : PixelIcon(icon!, color: Palette.bone.color)),
    );
    if (onInfo == null) return art;
    // 24 x 26 touch area with a tiny "i" badge in the corner of the icon.
    return Semantics(
      container: true,
      button: true,
      label: infoLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onInfo,
        child: SizedBox(
          width: scale.px(24),
          height: scale.px(height),
          child: Center(
            child: SizedBox(
              width: scale.px(18),
              height: scale.px(18),
              child: Stack(
                children: [
                  Positioned(left: 0, top: 0, child: art),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.royal.color,
                        border: Border.all(
                          color: Palette.ink.color,
                          width: scale.px(1),
                        ),
                      ),
                      child: SizedBox(
                        width: scale.px(10),
                        height: scale.px(10),
                        child: Center(
                          child: PixelText('i', color: Palette.bone.color),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final row = SizedBox(
      height: scale.px(height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Palette.slate.color : null,
          border: Border(
            top: BorderSide(color: Palette.slate.color, width: scale.px(1)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: scale.px(2)),
            _iconArea(scale),
            SizedBox(width: scale.px(onInfo == null ? 4 : 0)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelText(title, color: titleColor),
                  SizedBox(height: scale.px(2)),
                  PixelText(subtitle, color: Palette.fog.color),
                ],
              ),
            ),
            trailing,
            SizedBox(width: scale.px(2)),
          ],
        ),
      ),
    );
    final bar = progress;
    final shown = bar == null
        ? row
        : Stack(
            children: [
              row,
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                height: scale.px(1),
                child: Row(
                  children: [
                    Expanded(
                      flex: (bar * 1000).round(),
                      child: ColoredBox(color: Palette.sunYellow.color),
                    ),
                    Expanded(
                      flex: 1000 - (bar * 1000).round(),
                      child: ColoredBox(color: Palette.slate.color),
                    ),
                  ],
                ),
              ),
            ],
          );
    return onTap == null
        ? shown
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: shown,
          );
  }
}

/// Price button: an icon (coin or belt) and the cost. Disabled style when it
/// cannot be bought.
class CostButton extends StatelessWidget {
  const CostButton({
    super.key,
    required this.cost,
    required this.enabled,
    required this.onPressed,
    this.icon,
    this.semanticLabel,
  });

  final String cost;
  final bool enabled;
  final VoidCallback onPressed;
  final PixelIconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => PixelButton(
    label: cost,
    icon: icon ?? PixelIcons.coin,
    width: costButtonWidth,
    height: 24,
    semanticLabel: semanticLabel,
    onPressed: enabled ? onPressed : null,
  );
}

/// Section header inside a list (`PARA SIEMPRE`).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return SizedBox(
      height: scale.px(12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(left: scale.px(2)),
          child: PixelText(text, color: Palette.fog.color),
        ),
      ),
    );
  }
}
