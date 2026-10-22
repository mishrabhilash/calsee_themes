/// Bauhaus's display ([DisplayFace]): an opaque sheet (palette `surface`)
/// with a thick rule down its left edge (`shadow`: ink on paper and ochre,
/// the field's ink on grid, cream on the night sheet, red on the negative
/// variant's cream sheet — whatever stands out from both the sheet and the
/// ground it hangs into) and a quarter-disc in the `=` primary
/// (`highlight`, or the operator / rule colour when the `=` would blend
/// into the sheet) on its top-right corner — the result key echoed on the
/// sheet. Every glyph is Jost at the theme's display weight on the `wght`
/// axis (the display's generic path would set only `fontWeight`), so
/// layout, fitting and semantics are exactly the font's.
///
/// The rule and the disc stay outside the display's text padding (16 dp
/// on sheets narrower than 360 dp, else 24 dp): the rule is 8 / 10 dp
/// inside the sheet plus [BauhausDisplayFace.ruleOverhang] hanging into
/// the panel margin, the disc 14 / 22 dp. The left margin is widened by
/// that overhang, so the rule starts 12 dp inside the column — the line
/// every family's panel starts on, inside the keypad's edge. So display
/// text only ever sits on the sheet colour, which is the guardrails' only
/// display backdrop. Three `drawRRect`s, no `saveLayer`, gradient or
/// shadow (the lite effects tier draws the same).
library;

import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/painting.dart';

/// The Bauhaus display sheet.
final class BauhausDisplayFace extends DisplayFace {
  const BauhausDisplayFace({
    required this.panel,
    required this.bar,
    required this.disc,
    this.weight = 500,
    this.cornerFraction = 0,
  });

  /// The sheet colour (palette `surface`).
  final Color panel;

  /// The rule colour (palette `shadow`).
  final Color bar;

  /// The corner quarter-disc colour (palette `highlight`).
  final Color disc;

  /// Display weight (CSS) for the result line; typing is 100 lighter,
  /// messages 100 heavier, Bold Text adds its steps on top.
  final int weight;

  /// Key corner fraction; the sheet's radius follows it (0–4 dp).
  final double cornerFraction;

  /// How far the rule hangs past the sheet's left edge into the panel
  /// margin, dp ([panelMargin] is that much wider on the left).
  static const double ruleOverhang = 8;

  /// Where the rule starts, dp from the display's left edge (the panel
  /// margin every other family uses).
  static const double ruleInset = 12;

  /// The rule's width inside the sheet for a sheet of [width] dp.
  static double ruleWidthFor(double width) => width < 360 ? 8 : 10;

  /// The corner disc's radius for a sheet of [width] dp.
  static double discRadiusFor(double width) => width < 360 ? 14 : 22;

  @override
  Color get panelColor => panel;

  @override
  EdgeInsets get panelMargin =>
      const EdgeInsets.fromLTRB(ruleInset + ruleOverhang, 6, 12, 12);

  @override
  bool drawsChar(int codeUnit) => false;

  /// The display passes w300 (typing) / w400 (results) / w500 (messages),
  /// plus three steps under Bold Text; each maps onto [weight] shifted by
  /// the same amount, on the font's `wght` axis.
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final w = (weight + asked - 400).clamp(100, 900).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(weight: w, fontSize: base.fontSize),
      fontFeatures: font.features(),
    );
  }

  /// The sheet's corner radius for [rect].
  double radiusFor(Rect rect) => math.min(
    math.min(4, 100 * cornerFraction.clamp(0.0, 0.5)),
    rect.shortestSide / 4,
  );

  static final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty || !rect.isFinite) return;
    final radius = Radius.circular(radiusFor(rect));
    final paint = _paint..color = panel;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    final barW = math.min(ruleWidthFor(rect.width), rect.width / 4);
    if (barW > 0) {
      paint.color = bar;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          rect.left - ruleOverhang,
          rect.top,
          rect.left + barW,
          rect.bottom,
          topLeft: radius,
          bottomLeft: radius,
        ),
        paint,
      );
    }
    final ra = math.min(discRadiusFor(rect.width), rect.shortestSide / 2);
    if (ra > 0) {
      paint.color = disc;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(rect.right - ra, rect.top, ra, ra),
          topRight: radius,
          bottomLeft: Radius.circular(ra),
        ),
        paint,
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
    if (other is! BauhausDisplayFace) return t < 0.5 ? this : other;
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    return BauhausDisplayFace(
      panel: Color.lerp(panel, other.panel, c)!,
      bar: Color.lerp(bar, other.bar, c)!,
      disc: Color.lerp(disc, other.disc, c)!,
      weight: c < 0.5 ? weight : other.weight,
      cornerFraction:
          cornerFraction + (other.cornerFraction - cornerFraction) * c,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BauhausDisplayFace &&
      other.panel == panel &&
      other.bar == bar &&
      other.disc == disc &&
      other.weight == weight &&
      other.cornerFraction == cornerFraction;

  @override
  int get hashCode =>
      Object.hash(BauhausDisplayFace, panel, bar, disc, weight, cornerFraction);
}
