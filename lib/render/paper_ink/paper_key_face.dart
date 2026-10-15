/// Paper & ink key faces (spec §5.3 #11; motion brief §2.3 "Paper &
/// ink"): paper slips outlined by hand with a fineliner, operators in a
/// hatched ink frame, `=` a rubber stamp.
///
/// Per key, in paint order (artwork from paper_key_art.dart, cached per
/// key and size, never per theme):
/// 1. the opaque face (`KeyStyle.fill` with the hover layer) — for `=` the
///    paper slip, then the (slightly turned) stamp body in the face colour;
/// 2. the paper grain in the band around the label zone K (never in K);
/// 3. the ink wash (press): an irregular blot from the fingertip with a
///    darker tide line, both in the ink — on `=` only on the stamp body,
///    so the paper ring around it stays clean;
/// 4. role art: the operator hatch (ink at `edgeShadePermille`), the
///    stamp's inner border and its worn speckles and scratches (label
///    colour);
/// 5. the outline: pass 1 with pen-down dots, then the finer retrace
///    (not on function slips, not on the lite tier);
/// 6. the long-press "pen underline" (no shared hold fill, no pressed
///    state layer): an ink line drawn left to right under K at the pressed
///    pen width (on operators over a face-coloured halo that parts the
///    hatch); on `=` the bottom of the stamp's border thickens from 1 to
///    2.2 dp left to right instead. Nothing enters K.
///
/// Only the face fill and the wash ever cover K, so the label sits on
/// exactly the guardrail-checked face colour (the wash is validated at its
/// peak, `paperWash`).
///
/// Press channels:
/// - `tint` (snaps to 1 at touch-down): the outline **boils** to its
///   alternate drawing and the pen presses harder (1.4× width, the retrace
///   darker) — the frame-1 cue. Under Reduce Motion the boil keys off the
///   discrete pressed state (`effectivePress`).
/// - `press`: the wash grows from 10 % of the key's diagonal to 42 %
///   (± 18 % lobes), so a corner stays dry and its lobed edge and tide
///   line show, while a one-glyph label (≤ 0.32 of the diagonal from the
///   clamped centre) ends inside it. It fades in with an "ink
///   drop" of 35 % of its alpha in frame 1; on release it keeps its size
///   and dries on `releaseAlt` (effectsSlow). Reduce Motion: the peak-size
///   blot fades on `tint`.
/// - `scale` (when the motion has it; else `press`): the 1 dp drop of the
///   face and its label (release 1400/0.9). The painter repaints on
///   `press`, which settles after `scale` (800/1.0 vs ≥ 1260/0.9).
/// - `touchFraction`: the wash's centre (clamped to 30–70 %).
/// - `holdFill`: the underline's length (Reduce Motion: the whole line,
///   its opacity following the fill).
///
/// Lite effects tier: no retrace and no stamp wear (two draws fewer per
/// key). Nothing here uses saveLayer, blur or a per-key shader build; a
/// steady frame allocates no Path or Paint.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/paper_ink.dart'
    show paperWashRimFactor;
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:calsee_themes/render/paper_ink/paper_grain.dart';
import 'package:calsee_themes/render/paper_ink/paper_key_art.dart';
import 'package:flutter/widgets.dart';

/// The art kind of a key with [role].
PaperArtKind paperArtKindOf(KeyRole role) => switch (role) {
  KeyRole.digit || KeyRole.decimal || KeyRole.sign => PaperArtKind.slipDigit,
  KeyRole.operator => PaperArtKind.operator,
  KeyRole.equals => PaperArtKind.stamp,
  _ => PaperArtKind.slipFunction,
};

/// The art seed of a key: its [KeyFaceSpec.artSeed], or for specs without
/// one (tests, previews) a number from its role and size.
int paperArtSeedOf(KeyFaceSpec spec, Size size) => spec.artSeed != 0
    ? spec.artSeed
    : spec.role.index * 7919 +
          (size.width * 4).round() * 31 +
          (size.height * 4).round();

/// Labels drawn [paperLargeGlyphScale] × larger (the serif's small math
/// signs).
const Set<String> paperLargeGlyphs = {'+', '−', '×', '÷', '='};

/// See [paperLargeGlyphs].
const double paperLargeGlyphScale = 1.35;

/// Labels drawn [paperMediumGlyphScale] × larger: Newsreader's brackets and
/// `±` are hairline beside its digits.
const Set<String> paperMediumGlyphs = {'( )', '(', ')', '±'};

/// See [paperMediumGlyphs].
const double paperMediumGlyphScale = 1.12;

/// How much larger than the shared label size [text] is set.
double paperLabelScale(String text) => paperLargeGlyphs.contains(text)
    ? paperLargeGlyphScale
    : (paperMediumGlyphs.contains(text) ? paperMediumGlyphScale : 1);

/// The wash's radius at touch-down and at its peak, × the key's diagonal
/// (the blot's lobes vary it ± 18 %).
const double paperWashStartSpread = 0.10;
const double paperWashPeakSpread = 0.42;

/// The wash's centre stays within this band of the key (fractions), so
/// the label always ends inside the blot and a corner stays dry.
const double paperWashTouchMin = 0.30;
const double paperWashTouchMax = 0.70;

/// The underline's width, × the pass-1 pen (the pressed pen's 1.4 ×), and
/// its halo on operators, dp each side.
const double paperUnderlinePen = 1.4;
const double paperUnderlineHalo = 1;

/// The `=` border's bottom side at the end of a long press, dp.
const double paperStampHoldWidth = 2.2;

/// Outline width while pressed (the pen pressing harder), × the rest
/// width.
const double paperPressedPen = 1.4;

/// Paper & ink key renderer for one theme. A same-family theme change
/// lerps every colour and number ([LerpableKeyFace]); the artwork is the
/// key's own and does not change.
final class PaperKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const new({
    required this.ink,
    required this.wash,
    required this.slip,
    this.outlineWidth = 1.5,
    this.hatchAlpha = 0.65,
    this.depth = 1,
    this.cornerFraction = 0.04,
    this.grain = 0,
    this.lite = false,
    super.slashedZero,
    this.layoutBase,
  });

  /// The ink (palette `shadow`): outlines and hatch when a key style has
  /// no outline.
  final Color ink;

  /// The ink wash's tide-line colour at its peak alpha (palette
  /// `highlight`); the blot fills at that alpha ÷ 1.6.
  final Color wash;

  /// The digit slip colour: the paper ring around the `=` stamp.
  final Color slip;

  /// Fineliner width of pass 1, dp (the retrace is 0.55 ×).
  final double outlineWidth;

  /// Operator hatch opacity (0–1).
  final double hatchAlpha;

  /// The face's press drop, dp.
  final double depth;

  /// Face corner radius as a fraction of the key's short side (0–0.5).
  final double cornerFraction;

  /// Paper grain opacity on the slips (0–1; half the sheet's).
  final double grain;

  /// Lite effects tier: no retrace, no stamp speckles.
  final bool lite;

  /// For an in-between face of a theme morph: the end it is closer to;
  /// null for a theme's own face.
  final PaperKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as PaperKeyFace;
    if (other is! PaperKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as PaperKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * t;
    final near = c < 0.5 ? a : b;
    return PaperKeyFace(
      ink: Color.lerp(a.ink, b.ink, c)!,
      wash: Color.lerp(a.wash, b.wash, c)!,
      slip: Color.lerp(a.slip, b.slip, c)!,
      // Clamped to the ends: the shape rubber-band (t ≈ 1.06) must not
      // push the pen past the family's 1.75 dp cap.
      outlineWidth: number(a.outlineWidth, b.outlineWidth).clamp(
        math.min(a.outlineWidth, b.outlineWidth),
        math.max(a.outlineWidth, b.outlineWidth),
      ),
      hatchAlpha: number(a.hatchAlpha, b.hatchAlpha).clamp(0.0, 1.0),
      depth: math.max(0, number(a.depth, b.depth)),
      cornerFraction: number(a.cornerFraction, b.cornerFraction).clamp(0, 0.5),
      grain: number(a.grain, b.grain).clamp(0.0, 1.0),
      lite: near.lite,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: the artwork is theme-independent and cached
  /// per key.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// Warms the shared paper grain tile (art seeds are not known here).
  @override
  void prepare(Iterable<Size> cellSizes) {
    if (grain > 0) PaperTextures.grain;
  }

  /// The usable pass-1 width on a key whose short side is [s] (≤ s / 24).
  double penFor(double s) => math.max(0, math.min(outlineWidth, s / 24));

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      PaperKeyPainter(motion: motion, spec: spec, face: this);

  /// Newsreader draws `+ − × ÷ =` small (at its x-height): they are set
  /// 35 % larger than the other labels so the operators hold their own
  /// beside the digits; its hairline brackets and `±` 12 % larger
  /// ([paperLabelScale]).
  ///
  /// Newsreader has no √ ∛ π ʸ ˣ ⁻ ₓ: those scientific labels fall back to
  /// the platform font, glyph by glyph (scientific mode has not shipped).
  @override
  Widget label(String text, TextStyle style) {
    final size = style.fontSize;
    final scale = paperLabelScale(text);
    final scaled = size != null && scale != 1
        ? style.copyWith(fontSize: size * scale)
        : style;
    return super.label(text, scaled);
  }

  /// The label drops with the face (the `scale` channel when the motion
  /// has it).
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      PressTranslate(
        press: motion is KeyFaceMotionDetail ? motion.scale : motion.press,
        rest: Offset.zero,
        travel: Offset(0, depth),
        reduceMotion: spec.reduceMotion,
        child: label,
      );

  @override
  bool operator ==(Object other) =>
      other is PaperKeyFace &&
      other.ink == ink &&
      other.wash == wash &&
      other.slip == slip &&
      other.outlineWidth == outlineWidth &&
      other.hatchAlpha == hatchAlpha &&
      other.depth == depth &&
      other.cornerFraction == cornerFraction &&
      other.grain == grain &&
      other.lite == lite &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    PaperKeyFace,
    ink,
    wash,
    slip,
    outlineWidth,
    hatchAlpha,
    depth,
    cornerFraction,
    grain,
    lite,
    slashedZero,
    layoutBase,
  );
}

/// Paints one Paper & ink key (see the library comment). Repaints from
/// the motion channels without rebuilds.
class PaperKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours, role and art seed.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final PaperKeyFace face;

  // Shared by every key (painting is single-threaded and every use sets
  // what it reads): a theme morph builds a new painter per key per frame.
  static final Paint _fill = Paint();
  static final Paint _grain = Paint();
  static final Paint _wash = Paint();
  static final Paint _tide = Paint()..style = PaintingStyle.stroke;
  static final Paint _line = Paint()..style = PaintingStyle.stroke;
  static final Paint _hatch = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt;
  static final Paint _pen = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _dot = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _under = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Whether the outline shows its boiled (pressed) drawing.
  bool get boiled => spec.reduceMotion
      ? effectivePress(motion.press.value, reduceMotion: true) > 0.5
      : motion.tint.value >= 0.5;

  /// The face's drop now (0–1 of [PaperKeyFace.depth]).
  double get drop {
    final m = motion;
    final v = m is KeyFaceMotionDetail ? m.scale.value : m.press.value;
    return effectivePress(v, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);
  }

  /// The wash's opacity factor (0–1 of its peak) and radius (× the key's
  /// diagonal) now.
  (double, double) get washState {
    final p = motion.press.value.clamp(0.0, 1.0);
    final tint = motion.tint.value.clamp(0.0, 1.0);
    if (spec.reduceMotion) return (tint, paperWashPeakSpread);
    final alpha = math.max(0.35 * tint, p);
    final grow = (p / math.max(tint, 0.001)).clamp(0.0, 1.0);
    return (
      alpha,
      paperWashStartSpread +
          (paperWashPeakSpread - paperWashStartSpread) * grow,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final kind = paperArtKindOf(spec.role);
    final art = PaperArtCache.instance.lookup(
      paperArtSeedOf(spec, size),
      size,
      kind,
    );
    final style = spec.style;
    final s = size.shortestSide;
    final box = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      box,
      Radius.circular(face.cornerFraction.clamp(0.0, 0.5) * s),
    );
    final ink = style.outline ?? face.ink;
    final dy = face.depth * drop;

    canvas.save();
    if (dy != 0) canvas.translate(0, dy);

    // 1. The face (hover layer only: the press is the ink wash).
    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    final body = art.stampBody;
    if (kind == PaperArtKind.stamp && body != null) {
      canvas
        ..drawRRect(shape, _fill..color = face.slip)
        ..drawPath(body, _fill..color = fill);
    } else {
      canvas.drawRRect(shape, _fill..color = fill);
    }

    // 2. Paper grain around the label zone (each key its own window into
    // the shared tile).
    final zone = art.labelZone;
    if (face.grain > 0 && zone.width > 0 && zone.height > 0) {
      final o = art.grainOffset;
      _grain
        ..shader = PaperTextures.grain
        ..color = Color.fromRGBO(0, 0, 0, face.grain);
      canvas
        ..save()
        ..translate(-o.dx, -o.dy)
        ..drawDRRect(
          shape.shift(o),
          RRect.fromRectXY(zone.shift(o), 0, 0),
          _grain,
        )
        ..restore();
    }

    // 3. The ink wash.
    final peak = face.wash.a;
    if (peak > 0.002) {
      final (amount, spread) = washState;
      if (amount > 0.002) {
        final rim = peak * amount;
        final fillAlpha = rim / paperWashRimFactor;
        final lineAlpha = ((rim - fillAlpha) / (1 - fillAlpha)).clamp(0.0, 1.0);
        final r =
            math.sqrt(size.width * size.width + size.height * size.height) *
            spread;
        final m = motion;
        final touch = m is KeyFaceMotionDetail ? m.touchFraction : null;
        final c = touch == null
            ? box.center
            : Offset(
                size.width *
                    touch.dx.clamp(paperWashTouchMin, paperWashTouchMax),
                size.height *
                    touch.dy.clamp(paperWashTouchMin, paperWashTouchMax),
              );
        canvas.save();
        // On `=` the ink deepens on the stamp only: the paper ring stays
        // clean (a greyed ring reads as a disabled key).
        if (kind == PaperArtKind.stamp && body != null) {
          canvas.clipPath(body);
        } else {
          canvas.clipRRect(shape);
        }
        canvas
          ..translate(c.dx, c.dy)
          ..scale(r)
          ..drawPath(
            art.wash,
            _wash..color = face.wash.withValues(alpha: fillAlpha),
          );
        if (lineAlpha > 0.002) {
          _tide
            ..strokeWidth = 1.2 / r
            ..color = face.wash.withValues(alpha: lineAlpha);
          canvas.drawPath(art.wash, _tide);
        }
        canvas.restore();
      }
    }

    // 4. Role art, all outside the label zone.
    final hatch = art.hatch;
    if (hatch != null) {
      _hatch
        ..strokeWidth = paperHatchWidth(s)
        ..color = ink.withValues(alpha: ink.a * face.hatchAlpha);
      canvas.drawPath(hatch, _hatch);
    }
    final border = art.border;
    final hasBorder = border != null && !border.outerRect.isEmpty;
    if (hasBorder) {
      _line
        ..strokeWidth = 1
        ..color = style.label.withValues(alpha: style.label.a * 0.8);
      canvas.save();
      _turnStamp(canvas, art, size);
      canvas
        ..drawRRect(border, _line)
        ..restore();
    }
    final speckles = art.speckles;
    if (speckles != null && !face.lite) {
      canvas.drawPath(
        speckles,
        _fill..color = style.label.withValues(alpha: style.label.a * 0.65),
      );
    }

    // 5. The outline: boiled and pressed harder from frame 1.
    final pressed = boiled;
    final stroke = pressed ? art.boil : art.rest;
    var sw = face.penFor(s);
    if (pressed) sw *= paperPressedPen;
    if (sw > 0 && ink.a > 0) {
      _pen
        ..strokeWidth = sw
        ..color = ink;
      _dot
        ..strokeWidth = sw * 1.1
        ..color = ink;
      canvas
        ..drawPath(stroke.stroke, _pen)
        ..drawRawPoints(ui.PointMode.points, stroke.blobs, _dot);
      if (kind != PaperArtKind.slipFunction && !face.lite) {
        _pen
          ..strokeWidth = sw * 0.55
          ..color = ink.withValues(alpha: ink.a * (pressed ? 0.9 : 0.7));
        canvas.drawPath(stroke.sketch, _pen);
      }
    }

    // 6. The pen underline (long press).
    final hold = motion.holdFill.clamp(0.0, 1.0);
    final holdTint = motion.tint.value.clamp(0.0, 1.0);
    if (hold > 0 && holdTint > 0) {
      final rm = spec.reduceMotion;
      final fraction = rm ? 1.0 : hold;
      final alpha = (rm ? hold : 1) * holdTint;
      if (kind == PaperArtKind.stamp && border != null && hasBorder) {
        _stampHold(canvas, art, size, border, fraction, alpha, style.label);
      } else if (body != null && kind == PaperArtKind.stamp) {
        canvas
          ..save()
          ..clipPath(body);
        _underline(canvas, art, face.penFor(s), fraction, alpha, style.label);
        canvas.restore();
      } else {
        if (hatch != null) {
          // The halo parts the hatch (and fades with the line).
          _underline(
            canvas,
            art,
            face.penFor(s),
            fraction,
            alpha,
            fill,
            halo: paperUnderlineHalo,
          );
        }
        _underline(canvas, art, face.penFor(s), fraction, alpha, ink);
      }
    }
    canvas.restore();
  }

  /// Turns the canvas by the stamp's angle about the key's centre.
  static void _turnStamp(Canvas canvas, PaperKeyArt art, Size size) {
    if (art.stampAngle == 0) return;
    final c = size.center(Offset.zero);
    canvas
      ..translate(c.dx, c.dy)
      ..rotate(art.stampAngle)
      ..translate(-c.dx, -c.dy);
  }

  /// The pen underline drawn to [fraction] of its width in [color] at
  /// [alpha], its leading end a round pen tip; [halo] widens it by that
  /// much each side (for the face-coloured halo drawn under the ink).
  static void _underline(
    Canvas canvas,
    PaperKeyArt art,
    double pen,
    double fraction,
    double alpha,
    Color color, {
    double halo = 0,
  }) {
    final line = art.underline;
    final width = pen * paperUnderlinePen + 2 * halo;
    if (width <= 0 || alpha <= 0) return;
    final x = line.xAt(fraction);
    _under
      ..strokeWidth = width
      ..color = color.withValues(alpha: color.a * alpha.clamp(0.0, 1.0));
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(-width, -width, x, art.size.height + width))
      ..drawPath(line.path, _under)
      ..restore();
    // The leading end: the pen's round tip (the clip cut it square).
    _fill.color = _under.color;
    canvas.drawCircle(Offset(x, line.yAt(fraction)), width / 2, _fill);
  }

  /// `=`: the bottom side of the stamp's border thickens from 1 dp to
  /// [paperStampHoldWidth] to [fraction] of its width, in the label
  /// colour. It grows outward only (its inner edge stays put, ≥ 0.5 dp
  /// outside K even at the stamp's widest turn), clipped to the stamp
  /// body.
  static void _stampHold(
    Canvas canvas,
    PaperKeyArt art,
    Size size,
    RRect border,
    double fraction,
    double alpha,
    Color label,
  ) {
    final body = art.stampBody;
    // From the stroke's inner edge (0.5 dp in from its centre line) out.
    const out = paperStampHoldWidth - 0.5;
    final r = border.outerRect;
    // Corner to corner: the stroke's outer edges, not its centre line.
    final x = r.left - out + (r.width + 2 * out) * fraction.clamp(0.0, 1.0);
    canvas.save();
    if (body != null) canvas.clipPath(body);
    _turnStamp(canvas, art, size);
    canvas
      ..clipRRect(border.inflate(out))
      ..drawRect(
        Rect.fromLTRB(r.left - out, r.bottom - 0.5, x, r.bottom + out),
        _fill..color = label.withValues(alpha: label.a * alpha.clamp(0.0, 1.0)),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(PaperKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
