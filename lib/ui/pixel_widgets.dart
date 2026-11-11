import 'dart:typed_data';
import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';

import '../core/palette.dart';
import 'palette_color.dart';
import 'pixel_icon.dart';
import 'pixel_icons.dart';
import 'pixel_scale.dart';

/// The bundled pixel font (Press Start 2P, SIL OFL). Every glyph is monospaced
/// at 1 em and digits do not change width, as the style guide asks.
const String pixelFontFamily = 'PressStart2P';

/// Text at a whole-number virtual size (8 for body, 16 for titles).
/// At 8 virtual pixels each font pixel is exactly one virtual pixel.
class PixelText extends StatelessWidget {
  const PixelText(
    this.text, {
    super.key,
    this.size = 8,
    this.color,
    this.align = TextAlign.left,
    this.maxLines = 1,
    this.wrap = false,
    this.shadow,
  });

  final String text;
  final int size;
  final Color? color;
  final TextAlign align;
  final int maxLines;

  /// Breaks long text over several lines instead of clipping it.
  final bool wrap;

  /// Color of a 1-pixel drop shadow to the bottom right (titles).
  final Color? shadow;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return Text(
      text,
      textAlign: align,
      maxLines: wrap ? null : maxLines,
      overflow: TextOverflow.clip,
      softWrap: wrap,
      style: TextStyle(
        color: color ?? Palette.bone.color,
        fontFamily: pixelFontFamily,
        fontSize: scale.px(size),
        // One text line is exactly `size` virtual pixels tall; wrapped text
        // gets a 2-pixel gap between lines (at the 8-pixel size).
        height: wrap ? 1.25 : 1.0,
        letterSpacing: 0,
        decoration: TextDecoration.none,
        shadows: shadow == null
            ? null
            : [
                Shadow(
                  color: shadow!,
                  offset: Offset(scale.px(1), scale.px(1)),
                ),
              ],
      ),
    );
  }
}

enum PixelButtonStyle { main, secondary, confirm, danger, flat, gold }

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
    this.icon,
    this.semanticLabel,
  }) : assert(height >= 24, 'touch targets are at least 24 virtual pixels');

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final PixelButtonStyle style;

  /// Highlights a chosen option (the buy selector).
  final bool selected;
  final double? width;
  final double height;

  /// Small icon drawn before the label.
  final PixelIconData? icon;

  /// Spoken label when it differs from the visible text.
  final String? semanticLabel;

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;

  ({int base, int dark}) get _tones => switch (widget.style) {
    PixelButtonStyle.main => (base: Palette.luchaRed, dark: Palette.wine),
    PixelButtonStyle.secondary => (base: Palette.royal, dark: Palette.navy),
    PixelButtonStyle.confirm => (base: Palette.nopal, dark: Palette.forest),
    PixelButtonStyle.danger => (base: Palette.luchaRed, dark: Palette.wine),
    PixelButtonStyle.flat => (base: Palette.nightPurple, dark: Palette.slate),
    PixelButtonStyle.gold => (
      base: Palette.marigold,
      dark: Palette.burntOrange,
    ),
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
        : (widget.selected || widget.style == PixelButtonStyle.gold)
        ? Palette.ink
        : Palette.bone;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: SizedBox(
          width: widget.width == null ? null : scale.px(widget.width!),
          height: scale.px(widget.height),
          child: Padding(
            padding: EdgeInsets.only(
              top: _pressed && enabled ? scale.px(1) : 0,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill.color,
                border: Border.all(
                  color: Palette.ink.color,
                  width: scale.px(1),
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      PixelIcon(widget.icon!, color: textColor.color),
                      if (widget.label.isNotEmpty) SizedBox(width: scale.px(2)),
                    ],
                    if (widget.label.isNotEmpty)
                      Flexible(
                        child: PixelText(
                          widget.label,
                          color: textColor.color,
                          align: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
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
  const PixelBar({
    super.key,
    required this.fraction,
    required this.fill,
    required this.track,
    this.height = 8,
  });

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
            final pixels = (constraints.maxWidth / scale.scale * clamped)
                .floor();
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

/// 1-pixel checkerboard of Ink over the whole screen, used behind pop-ups
/// instead of a semi-transparent fill so the screen keeps strict pixel rules.
class CheckerOverlay extends StatelessWidget {
  const CheckerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _CheckerPainter(scale: scale.scale, color: Palette.ink.color),
      ),
    );
  }
}

class _CheckerPainter extends CustomPainter {
  _CheckerPainter({required this.scale, required this.color});

  final int scale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final columns = (size.width / scale).ceil();
    final rows = (size.height / scale).ceil();
    final points = <double>[];
    for (var y = 0; y < rows; y++) {
      for (var x = y.isEven ? 0 : 1; x < columns; x += 2) {
        points
          ..add((x + 0.5) * scale)
          ..add((y + 0.5) * scale);
      }
    }
    canvas.drawRawPoints(
      PointMode.points,
      Float32List.fromList(points),
      Paint()
        ..color = color
        ..strokeWidth = scale.toDouble()
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_CheckerPainter old) =>
      old.scale != scale || old.color != color;
}

/// Centered pop-up: panel up to 150 virtual pixels wide with a 16 px title,
/// content and a row of buttons.
/// Inner width of a pop-up in virtual pixels (150 minus the panel padding).
const int _dialogInnerWidth = 138;

/// 16-pixel titles when the longest word fits, otherwise 8.
int _titleSize(String title) {
  final longest = title
      .split(' ')
      .fold<int>(0, (m, w) => w.length > m ? w.length : m);
  return longest * 16 <= _dialogInnerWidth ? 16 : 8;
}

class PixelDialog extends StatelessWidget {
  const PixelDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scale = PixelScale.of(context);
    return Stack(
      children: [
        const CheckerOverlay(),
        Center(
          child: SizedBox(
            width: scale.px(150),
            child: PixelPanel(
              padding: 6,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PixelText(
                    title,
                    size: _titleSize(title),
                    align: TextAlign.center,
                    wrap: true,
                    color: Palette.sunYellow.color,
                    shadow: Palette.ink.color,
                  ),
                  SizedBox(height: scale.px(6)),
                  ...body,
                  SizedBox(height: scale.px(6)),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) SizedBox(height: scale.px(4)),
                    actions[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
