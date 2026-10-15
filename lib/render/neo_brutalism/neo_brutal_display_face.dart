/// Neo-brutalism's display ([DisplayFace]): an outlined card in the panel
/// colour (palette `surface`) sitting on the same offset hard shadow as the
/// keys, with every glyph set in a heavy, wide cut of the display font
/// (`TypeSpec.displayWeight` on the `wght` axis, `TypeSpec.widthPermille`
/// on `wdth` where the font has one). The font draws every glyph, so
/// layout, fitting and semantics are exactly the font's.
library;

import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/painting.dart';

/// The Neo-brutalism display card.
final class NeoBrutalDisplayFace extends DisplayFace {
  const new({
    required this.panel,
    required this.ink,
    this.outlineWidth = 3,
    this.shadowOffset = 4,
    this.cornerFraction = 0.1,
    this.weight = 800,
    this.widthPermille = 1000,
  });

  /// The card colour (palette `surface`).
  final Color panel;

  /// Outline and hard-shadow colour.
  final Color ink;

  /// Outline width, dp.
  final double outlineWidth;

  /// Hard-shadow offset, dp.
  final double shadowOffset;

  /// Key corner fraction; the card's radius follows it (capped).
  final double cornerFraction;

  /// Display weight (CSS) for the result line; the expression line is
  /// 100 lighter, Bold Text adds its steps on top.
  final int weight;

  /// `wdth` axis × 10 (1000 = 100 %).
  final int widthPermille;

  @override
  Color get panelColor => panel;

  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(12, 6, 12, 14);

  @override
  bool drawsChar(int codeUnit) => false;

  /// Heavy and wide: the display passes w300 (typing) / w400 (results) /
  /// w500 (messages), plus three steps under Bold Text; each maps onto
  /// [weight] shifted by the same amount.
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final w = (weight + asked - 400).clamp(100, 1000).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(
        weight: w,
        width: widthPermille / 10,
        fontSize: base.fontSize,
      ),
      fontFeatures: font.features(),
    );
  }

  /// The card's rectangle inside [rect] (room for the shadow on the
  /// right and bottom).
  Rect cardRect(Rect rect) {
    final s = shadowFor(rect);
    return Rect.fromLTRB(rect.left, rect.top, rect.right - s, rect.bottom - s);
  }

  /// The usable shadow offset for [rect].
  double shadowFor(Rect rect) =>
      math.max(0, math.min(shadowOffset, rect.shortestSide / 8));

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty) return;
    final s = shadowFor(rect);
    final card = cardRect(rect);
    if (card.width <= 0 || card.height <= 0) return;
    final radius = Radius.circular(
      math.min(card.shortestSide * 0.12, 4 + 40 * cornerFraction),
    );
    final shape = RRect.fromRectAndRadius(card, radius);
    if (s > 0) {
      canvas.drawRRect(shape.shift(Offset(s, s)), Paint()..color = ink);
    }
    canvas.drawRRect(shape, Paint()..color = panel);
    final w = math.min(outlineWidth, card.shortestSide / 6);
    if (w > 0) {
      canvas.drawRRect(
        shape.deflate(w / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = ink,
      );
    }
  }

  @override
  void paintGlyphs(
    Canvas canvas,
    TextPainter painter,
    String text, {
    required Offset origin,
    required Color color,
    required double fontSize,
    int start = 0,
    int? end,
    double Function(int index)? opacity,
  }) {}

  @override
  DisplayFace lerpTo(DisplayFace other, double t) {
    if (other is! NeoBrutalDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    double number(double a, double b) => a + (b - a) * c;
    return NeoBrutalDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      ink: Color.lerp(ink, other.ink, c)!,
      outlineWidth: number(outlineWidth, other.outlineWidth),
      shadowOffset: number(shadowOffset, other.shadowOffset),
      cornerFraction: number(cornerFraction, other.cornerFraction),
      weight: c < 0.5 ? weight : other.weight,
      widthPermille: c < 0.5 ? widthPermille : other.widthPermille,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NeoBrutalDisplayFace &&
      other.panel == panel &&
      other.ink == ink &&
      other.outlineWidth == outlineWidth &&
      other.shadowOffset == shadowOffset &&
      other.cornerFraction == cornerFraction &&
      other.weight == weight &&
      other.widthPermille == widthPermille;

  @override
  int get hashCode => Object.hash(
    NeoBrutalDisplayFace,
    panel,
    ink,
    outlineWidth,
    shadowOffset,
    cornerFraction,
    weight,
    widthPermille,
  );
}
