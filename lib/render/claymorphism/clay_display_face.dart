/// Claymorphism's display ([DisplayFace]): a puffy pillow card in the
/// opaque surface colour — a soft drop shadow, a lit top-left rim and a
/// shaded bottom-right rim as wide as a key's (≈ 9 dp, 11 dp at the
/// bottom), with its edge lined up with the key faces below. (The
/// recessed tray is retired: it read as an LCD well or a Neumorphism
/// inset.) Display text is set in rounded heavy Nunito
/// (`TypeSpec.displayWeight` on the `wght` axis); Nunito lacks ˣ ʸ ₓ ⁻ ∛,
/// which fall back to the platform font.
///
/// The bands live in a ring *outside* the padded display box R: the card
/// is drawn on R grown by 12 dp (14 dp at the bottom), and its cover — R
/// grown by 6 dp, blurred by σ 1.5 dp — is fully opaque exactly at R
/// (6 dp = 4 σ). Only R's extreme corners, outside an arc of the card
/// radius − 12 dp, keep a trace of the ring; display text keeps ≥ 16 dp
/// side padding (`DisplayMetrics.horizontal`), clear of them. So every
/// display text, indicator and preview line sits on [ClayDisplayFace.panel]
/// alone — the colour the guardrails check display text against.
library;

import 'dart:math' as math;

import 'package:calsee_themes/display_face.dart';
import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/render/claymorphism/clay_key_face.dart';
import 'package:calsee_themes/render/fonts.dart';
import 'package:flutter/painting.dart';

/// The Claymorphism display card.
final class ClayDisplayFace extends DisplayFace {
  const ClayDisplayFace({
    required this.panel,
    required this.shade,
    required this.highlight,
    required this.shadow,
    this.weight = 700,
    this.lite = false,
  });

  /// How far the card reaches outside the padded display box at the top
  /// and sides, dp ([bandOutsetBottom] at the bottom).
  static const double bandOutset = 12;

  /// How far the card reaches below the padded display box, dp.
  static const double bandOutsetBottom = 14;

  /// How far the cover reaches outside the padded display box, dp: its
  /// blur (σ [coverSigma]) is spent exactly there.
  static const double coverOutset = 6;

  /// The cover's blur, dp.
  static const double coverSigma = 1.5;

  /// The largest card corner radius, dp.
  static const double maxRadius = 34;

  /// The card colour (palette `surface`, opaque).
  final Color panel;

  /// The shaded rim (the panel's inner shade).
  final Color shade;

  /// The lit rim's light (`Palette.highlight`).
  final Color highlight;

  /// The card's drop shadow (`Palette.shadow`).
  final Color shadow;

  /// Display weight (CSS) for the result line; typing is 100 lighter,
  /// messages 100 heavier, Bold Text adds its steps on top.
  final int weight;

  /// Lite effects tier: no blurs.
  final bool lite;

  @override
  Color get panelColor => panel;

  /// With the card grown 12 dp past the padded box, its edge sits 10 dp
  /// in from the display's sides — in line with the key faces below.
  @override
  EdgeInsets get panelMargin => const EdgeInsets.fromLTRB(22, 14, 22, 22);

  @override
  bool drawsChar(int codeUnit) => false;

  /// Rounded and heavy: the display passes w300 (typing) / w400 (results)
  /// / w500 (messages), plus three steps under Bold Text; each maps onto
  /// [weight] shifted by the same amount, set on the `wght` axis (the
  /// font's default instance is its lightest).
  @override
  TextStyle textStyle(TextStyle base) {
    final font = BundledFont.fromFamily(base.fontFamily);
    if (!font.isBundled) return base;
    final asked = (base.fontWeight ?? FontWeight.w400).value;
    final w = (weight + asked - 400).clamp(200, 1000).toDouble();
    return base.copyWith(
      fontWeight: nearestFontWeight(w),
      fontVariations: font.variations(weight: w, fontSize: base.fontSize),
      fontFeatures: font.features(),
    );
  }

  /// The card's bounds for the padded display box [rect]: [rect] grown by
  /// [bandOutset] (by [bandOutsetBottom] at the bottom).
  static Rect cardRect(Rect rect) => Rect.fromLTRB(
    rect.left - bandOutset,
    rect.top - bandOutset,
    rect.right + bandOutset,
    rect.bottom + bandOutsetBottom,
  );

  /// The card's rounded rectangle for the padded display box [rect].
  RRect shapeFor(Rect rect) {
    final w = cardRect(rect);
    return RRect.fromRectAndRadius(
      w,
      Radius.circular(math.min(0.22 * w.shortestSide, maxRadius)),
    );
  }

  /// The cover's rounded rectangle for the padded display box [rect]
  /// (opaque from [rect] inward).
  RRect coverFor(Rect rect) {
    final radius = shapeFor(rect).tlRadiusX - coverOutset;
    return RRect.fromRectAndRadius(
      rect.inflate(coverOutset),
      Radius.circular(math.max(0, radius)),
    );
  }

  static final Paint _drop = Paint();
  static final Paint _base = Paint();
  static final Paint _lit = Paint();
  static final Paint _cover = Paint();

  Paint _paint(Paint paint, Color color, double sigma) => paint
    ..color = color
    ..maskFilter = lite ? null : ClayPaintCache.blur(sigma);

  /// Paints the card around [rect]: its soft drop shadow, the shaded rim
  /// colour, the lit top-left wall and the cover, whose ramp ends exactly
  /// at [rect].
  @override
  void paintPanel(Canvas canvas, Rect rect) {
    if (rect.isEmpty) return;
    final rr = shapeFor(rect);
    final hiAlpha =
        clayHighlightAlphaFor(panel.toARGB32(), highlight.toARGB32()) / 255;
    final alpha = math.min(0xB3 / 255, shadow.a * 1.6) * (lite ? 0.5 : 1);
    canvas
      ..drawRRect(
        rr.deflate(8).shift(const Offset(0, 10)),
        _paint(_drop, shadow.withValues(alpha: alpha), 12),
      )
      ..drawRRect(rr, _base..color = shade)
      ..save()
      ..clipRRect(rr);
    final lit = Color.alphaBlend(highlight.withValues(alpha: hiAlpha), panel);
    canvas
      ..drawRRect(rr.shift(const Offset(-9, -9)), _paint(_lit, lit, 3.5))
      ..drawRRect(coverFor(rect), _paint(_cover, panel, coverSigma))
      ..restore();
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
    if (other is! ClayDisplayFace) return super.lerpTo(other, t);
    if (other == this) return this;
    final c = t.clamp(0.0, 1.0);
    if (c <= 0) return this;
    if (c >= 1) return other;
    Color color(Color a, Color b) => Color.lerp(a, b, c)!;
    final near = c < 0.5 ? this : other;
    return ClayDisplayFace(
      panel: color(panel, other.panel),
      shade: color(shade, other.shade),
      highlight: color(highlight, other.highlight),
      shadow: color(shadow, other.shadow),
      weight: near.weight,
      lite: near.lite,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ClayDisplayFace &&
      other.panel == panel &&
      other.shade == shade &&
      other.highlight == highlight &&
      other.shadow == shadow &&
      other.weight == weight &&
      other.lite == lite;

  @override
  int get hashCode => Object.hash(
    ClayDisplayFace,
    panel,
    shade,
    highlight,
    shadow,
    weight,
    lite,
  );
}
