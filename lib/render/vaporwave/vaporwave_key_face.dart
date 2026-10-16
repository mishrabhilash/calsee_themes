/// Vaporwave key faces: a square Windows-95 button. A 1 dp ink line, a
/// hard two-tone bevel (light top-left, dark bottom-right; the classic
/// Win95 joins, where the shade wins the top-right and bottom-left
/// corners) and a flat face in `KeyStyle.fill` that never moves.
///
/// Geometry for a key box of short side s, ink line o (1 dp) and bevel b
/// (2–3 dp, ≤ 6 % of s): the line fills the box's outer o, the outer bevel
/// band the next b/2, the inner band the next b/2, and the face R3 =
/// box.deflate(o + b) is exactly `KeyStyle.fill` (plus the contrast-safe
/// state layer), so the label sits on the colour the guardrails checked.
///
/// Press: the bevel inverts (Win95 `:active` — dark top-left, light
/// bottom-right) while `max(tint, press) ≥ 0.5`. `tint` snaps to 1 at
/// touch-down, so the inversion is the frame-1 cue; on release it holds
/// until the label is home and then snaps back, so the bevel never passes
/// through a flat mid-tone. The label travels (+d, +d) (d = 1–2 dp) with
/// the press; a 6 % state layer fades on `tint`. Reduce Motion: the
/// discrete pressed artwork (inverted bevel, label at +d) for any press.
/// Lite tier: identical (no gradients, blurs or shaders to drop).
library;

import 'dart:math' as math;

import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_bevel.dart';
import 'package:flutter/widgets.dart';

/// Fallback fonts for Vaporwave labels and display: Anybody lacks π, which
/// Roboto Flex (same `wght` / `wdth` axes) supplies. √ and ∛ are in
/// neither, and come from CalseeSymbols ([scriptFallbackFonts]), which
/// also draws the labels' super- and subscript runs (`KeyLabel`).
const List<String> vaporwaveFontFallback = [
  'RobotoFlex',
  ...scriptFallbackFonts,
];

/// Single-glyph maths labels drawn in Roboto Flex (same weight, normal
/// width): Anybody's `+ − × ÷ = ±` are a third of its digit height, which
/// reads as a missing label on an operator key, while Roboto Flex's are
/// full-size and keep the weight cue visible.
const Set<String> vaporwaveMathGlyphs = {'+', '−', '-', '×', '÷', '=', '±'};

/// Roboto Flex's maths glyphs are about 60 % of Anybody's digit height:
/// they are drawn this much larger.
const double vaporwaveMathGlyphScale = 1.13;

/// Bracket labels drawn [vaporwaveBracketWeightBonus] heavier: Anybody's
/// brackets are visibly lighter than its `%` and digits.
const Set<String> vaporwaveBracketLabels = {'( )', '(', ')'};
const double vaporwaveBracketWeightBonus = 100;

/// Vaporwave key renderer for one theme. A same-family theme change lerps
/// the line, bevel, travel, corners, bevel tones and ink
/// ([LerpableKeyFace]).
final class VaporwaveKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const new({
    required this.ink,
    this.outlineWidth = 1,
    this.bevelWidth = 2.5,
    this.travel = 1,
    this.shadeDepth = 0.30,
    this.highlightMix = 0.85,
    this.cornerFraction = 0,
    this.widthPermille = 1300,
    super.slashedZero,
    this.layoutBase,
  });

  /// The ink line around every key (`Palette.shadow`).
  final Color ink;

  /// Ink line width, dp.
  final double outlineWidth;

  /// Total bevel width b, dp (two bands of b/2).
  final double bevelWidth;

  /// Label travel d when pressed, dp.
  final double travel;

  /// How much darker the outer shade is than the face (OKLab L).
  final double shadeDepth;

  /// How far the outer highlight moves toward white (0–1).
  final double highlightMix;

  /// Corner radius as a fraction of the key's short side (0–0.5).
  final double cornerFraction;

  /// `wdth` axis of the label font × 10, for labels of one or two
  /// characters.
  final int widthPermille;

  /// For an in-between face of a theme morph: the end it is closer to
  /// (its label placement); null for a theme's own face.
  final VaporwaveKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as VaporwaveKeyFace;
    if (other is! VaporwaveKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as VaporwaveKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * c;
    final near = c < 0.5 ? a : b;
    return VaporwaveKeyFace(
      ink: Color.lerp(a.ink, b.ink, c)!,
      outlineWidth: math.max(0, number(a.outlineWidth, b.outlineWidth)),
      bevelWidth: math.max(0, number(a.bevelWidth, b.bevelWidth)),
      travel: math.max(0, number(a.travel, b.travel)),
      shadeDepth: number(a.shadeDepth, b.shadeDepth).clamp(0, 1),
      highlightMix: number(a.highlightMix, b.highlightMix).clamp(0, 1),
      cornerFraction: number(a.cornerFraction, b.cornerFraction).clamp(0, 0.5),
      widthPermille: near.widthPermille,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: faces are six rounded rectangles.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// The usable ink line width in a box of [size].
  double outlineFor(Size size) =>
      math.max(0, math.min(outlineWidth, size.shortestSide / 8));

  /// The usable bevel width b in a box of [size]: at least 1.5 dp, at most
  /// 6 % of the short side.
  double bevelFor(Size size) =>
      math.min(math.max(bevelWidth, 1.5), 0.06 * size.shortestSide);

  /// Whether a box of [size] is too small for the bevel (a flat face and
  /// the ink line only).
  bool flatAt(Size size) =>
      size.shortestSide < 2 * (outlineFor(size) + bevelFor(size)) + 4;

  /// The face rectangle (where the label sits) in a box of [size].
  Rect faceRect(Size size) {
    final o = outlineFor(size);
    final inset = flatAt(size) ? o : o + bevelFor(size);
    return (Offset.zero & size).deflate(inset);
  }

  /// The corner radius of the box in [size].
  double radiusFor(Size size) =>
      size.shortestSide * cornerFraction.clamp(0.0, 0.5);

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      VaporwaveKeyPainter(motion: motion, spec: spec, face: this);

  /// Labels of one or two characters use the theme's wide cut; longer ones
  /// keep the normal width so they fit. Single maths glyphs
  /// ([vaporwaveMathGlyphs]) come from Roboto Flex at the same weight,
  /// [vaporwaveMathGlyphScale] larger; brackets are drawn
  /// [vaporwaveBracketWeightBonus] heavier.
  @override
  Widget label(String text, TextStyle style) {
    final font = BundledFont.fromFamily(style.fontFamily);
    if (!font.isBundled) return super.label(text, style);
    final weight = (style.fontWeight ?? FontWeight.w400).value.toDouble();
    if (vaporwaveMathGlyphs.contains(text)) {
      const maths = BundledFont.robotoFlex;
      final size = style.fontSize == null
          ? null
          : style.fontSize! * vaporwaveMathGlyphScale;
      return KeyLabel(
        text,
        style: style.copyWith(
          fontFamily: maths.family,
          fontFamilyFallback: scriptFallbackFonts,
          fontSize: size,
          fontVariations: maths.variations(
            weight: weight,
            width: 100,
            fontSize: size,
          ),
          fontFeatures: maths.features(),
        ),
      );
    }
    final width = text.runes.length <= 2 ? widthPermille / 10 : 100.0;
    final wght = vaporwaveBracketLabels.contains(text)
        ? math.min(900, weight + vaporwaveBracketWeightBonus).toDouble()
        : weight;
    return KeyLabel(
      text,
      style: style.copyWith(
        fontWeight: wght == weight ? null : nearestFontWeight(wght),
        fontFamilyFallback: vaporwaveFontFallback,
        fontVariations: font.variations(
          weight: wght,
          width: width,
          fontSize: style.fontSize,
        ),
        fontFeatures: font.features(slashedZero: slashedZero),
      ),
    );
  }

  /// The Win95 "content shifts right and down": the label travels (+d, +d)
  /// with the press (discretely under Reduce Motion).
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      PressTranslate(
        press: motion.press,
        rest: Offset.zero,
        travel: Offset(travel, travel),
        reduceMotion: spec.reduceMotion,
        child: label,
      );

  @override
  bool operator ==(Object other) =>
      other is VaporwaveKeyFace &&
      other.ink == ink &&
      other.outlineWidth == outlineWidth &&
      other.bevelWidth == bevelWidth &&
      other.travel == travel &&
      other.shadeDepth == shadeDepth &&
      other.highlightMix == highlightMix &&
      other.cornerFraction == cornerFraction &&
      other.widthPermille == widthPermille &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    VaporwaveKeyFace,
    ink,
    outlineWidth,
    bevelWidth,
    travel,
    shadeDepth,
    highlightMix,
    cornerFraction,
    widthPermille,
    slashedZero,
    layoutBase,
  );
}

/// Paints one Vaporwave key: the ink line, the two bevel bands (raised or
/// inverted), the face with its state layer, and the long-press fill.
/// Repaints from the motion channels without rebuilds; no `saveLayer`, no
/// clip, no shader, one reused [Paint] and [Path].
class VaporwaveKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final VaporwaveKeyFace face;

  final Paint _paint = Paint();
  final Path _faceClip = Path();

  /// Whether the bevel shows sunken: `max(tint, press) ≥ 0.5`, with the
  /// press discrete under Reduce Motion.
  bool get sunken {
    final p = effectivePress(
      motion.press.value,
      reduceMotion: spec.reduceMotion,
    ).clamp(0.0, 1.0);
    final t = motion.tint.value.clamp(0.0, 1.0);
    return math.max(p, t) >= 0.5;
  }

  void _rrect(Canvas canvas, Rect rect, double radius, Color color) {
    if (rect.width <= 0 || rect.height <= 0) return;
    _paint.color = color;
    if (radius <= 0) {
      canvas.drawRect(rect, _paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        _paint,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    final box = Offset.zero & size;
    final o = face.outlineFor(size);
    final r = face.radiusFor(size);
    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    _rrect(canvas, box, r, face.ink);
    final Rect inner;
    if (face.flatAt(size)) {
      inner = box.deflate(o);
      _rrect(canvas, inner, math.max(0, r - o), fill);
    } else {
      final b = face.bevelFor(size);
      final half = b / 2;
      final tones = vaporBevelTones(
        style.fill,
        face.shadeDepth,
        face.highlightMix,
      );
      final down = sunken;
      final tlOuter = down ? tones.shadeOuter : tones.hiOuter;
      final tlInner = down ? tones.shadeInner : tones.hiInner;
      final brInner = down ? tones.hiInner : tones.shadeInner;
      final brOuter = down ? tones.hiOuter : tones.shadeOuter;
      final r1 = box.deflate(o);
      final r2 = r1.deflate(half);
      inner = r1.deflate(b);
      final rad1 = math.max(0, r - o).toDouble();
      final rad2 = math.max(0, rad1 - half).toDouble();
      // Each band: the shade fills it, the highlight covers all but its
      // bottom and right edges (Win95 joins).
      _rrect(canvas, r1, rad1, brOuter);
      _rrect(
        canvas,
        Rect.fromLTRB(r1.left, r1.top, r1.right - half, r1.bottom - half),
        rad1,
        tlOuter,
      );
      _rrect(canvas, r2, rad2, brInner);
      _rrect(
        canvas,
        Rect.fromLTRB(r2.left, r2.top, r2.right - half, r2.bottom - half),
        rad2,
        tlInner,
      );
      _rrect(canvas, inner, math.max(0, rad2 - half), fill);
    }
    if (motion.holdFill > 0 && !inner.isEmpty) {
      _faceClip
        ..reset()
        ..addRect(inner);
      paintHoldFill(canvas, inner, motion, spec, clip: _faceClip);
    }
  }

  @override
  bool shouldRepaint(VaporwaveKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
