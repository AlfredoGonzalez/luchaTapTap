import 'package:flutter/widgets.dart';

import '../core/palette.dart';
import 'palette_color.dart';
import 'pixel_scale.dart';

/// Text at a whole-number virtual size (8 for body, 16 for titles).
/// Placeholder typeface until the pixel font is chosen (open question).
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.size = 8,
    this.color,
    this.align = TextAlign.left,
    this.maxLines = 1,
  });

  final String text;
  final int size;
  final Color? color;
  final TextAlign align;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return Text(
      text,
      textAlign: align,
      maxLines: maxLines,
      overflow: TextOverflow.clip,
      softWrap: false,
      style: TextStyle(
        color: color ?? Palette.bone.color,
        fontSize: scale.px(size),
        height: 1.0, // one text line is exactly `size` virtual pixels tall
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: TextDecoration.none,
      ),
    );
  }
}

enum PixelButtonStyle { main, secondary, confirm }

/// Button with the three states of the style guide: normal, pressed (moves 1
/// pixel down and uses the darker tone) and disabled (Slate with Fog text).
/// Always at least 24 virtual pixels tall.
class PixelButton extends StatefulWidget {
  const PixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = PixelButtonStyle.main,
    this.selected = false,
    this.width,
    this.height = 24,
  }) : assert(height >= 24, 'touch targets are at least 24 virtual pixels');

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final PixelButtonStyle style;

  /// Highlights a chosen option (the buy selector).
  final bool selected;
  final double? width;
  final double height;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  ({int base, int dark}) get _tones => switch (widget.style) {
        PixelButtonStyle.main => (base: Palette.luchaRed, dark: Palette.wine),
        PixelButtonStyle.secondary => (base: Palette.royal, dark: Palette.navy),
        PixelButtonStyle.confirm => (base: Palette.nopal, dark: Palette.forest),
      };

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final enabled = widget.onPressed != null;
    final tones = _tones;
    final fill = !enabled
        ? Palette.slate
        : widget.selected
            ? Palette.marigold
            : (_pressed ? tones.dark : tones.base);
    final textColor = !enabled
        ? Palette.fog
        : widget.selected
            ? Palette.ink
            : Palette.bone;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: SizedBox(
        width: widget.width == null ? null : scale.px(widget.width!),
        height: scale.px(widget.height),
        child: Padding(
          padding: EdgeInsets.only(top: _pressed && enabled ? scale.px(1) : 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill.color,
              border: Border.all(color: Palette.ink.color, width: scale.px(1)),
            ),
            child: Center(child: PixelText(widget.label, color: textColor.color, align: TextAlign.center)),
          ),
        ),
      ),
    );
  }
}

/// Night Purple panel with a 1-pixel Ink outline.
class PixelPanel extends StatelessWidget {
  const PixelPanel({super.key, required this.child, this.padding = 2});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.nightPurple.color,
        border: Border.all(color: Palette.ink.color, width: scale.px(1)),
      ),
      child: Padding(padding: EdgeInsets.all(scale.px(padding)), child: child),
    );
  }
}

/// Bar with a 1-pixel Ink outline: [fraction] of [fill] over [track].
class PixelBar extends StatelessWidget {
  const PixelBar({super.key, required this.fraction, required this.fill, required this.track, this.height = 8});

  final double fraction;
  final int fill;
  final int track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    final clamped = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return SizedBox(
      height: scale.px(height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: track.color,
          border: Border.all(color: Palette.ink.color, width: scale.px(1)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Whole virtual pixels only.
            final pixels = (constraints.maxWidth / scale.scale * clamped).floor();
            return Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: scale.px(pixels),
                height: double.infinity,
                child: ColoredBox(color: fill.color),
              ),
            );
          },
        ),
      ),
    );
  }
}
