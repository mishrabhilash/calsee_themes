/// Cyberpunk key faces: dark chamfered plates (top-left and bottom-right
/// cut, HUD ticks at the other two corners) traced by a neon edge line
/// that bleeds a halo onto the body; operators and `=` are solid neon
/// slabs with dark labels and a hot rim (a black boundary on the light
/// Hazard body, which has no halo).
///
/// Geometry for a key box of W × H (s = the short side): the plate
/// F0 = (m, m, W − m, H − m − d) with m = clamp(0.045·s, 2, 3.5) and the
/// plunge d = min(2, s/16); pressed it sits d lower. The chamfer is
/// `cornerPermille` of the plate's short side (≤ 30 %).
///
/// Press (motion brief Terminal row): the neon flares in frame 1 — `tint`
/// snaps to 1 at touch-down, so the halo, the edge heat, the inner bloom
/// (a thin band hugging the neon line at the top and bottom) and the face
/// flare are at peak in the first frame — and the plate plunges on
/// `hardPress`. Plates flare *toward their neon* (never so far that the
/// label drops below its floor); slabs lift toward white. On release the plate snaps back on the theme's
/// release spring while `tint` decays on `effectsDefault`: the afterglow
/// (< 5 % of the flare at 120 ms). There is no chromatic split: held to
/// ≤ 1 device px at 3× (decisions), it would hide under the widened edge
/// line, so it was dropped.
///
/// Reduce Motion: the plate seats at once, every spatial term (halo
/// spread, edge widening, the Hazard boundary thickening) swaps with the
/// seated plate instead of following `tint`, and only alphas and colours
/// fade. The lite effects tier draws the halo as one un-blurred ring and
/// the bloom as a flat band.
///
/// The halo reaches ≈ 2.5σ + 0.75 dp (≤ 7 dp) past the plate, which is
/// inset 2–3.5 dp in its cell: at most ≈ 5 dp past the cell. The keypad's
/// `Stack` clips only when a child overflows its layout, and the cells tile
/// the grid, so halos are not clipped today; were a narrow layout ever to
/// clip, the outermost halos would be cut at the keypad edge.
///
/// Label zone ([cyberLabelZoneTop]–[cyberLabelZoneBottom] of the plate's
/// height): only the opaque face, its contrast-safe flare / hover layer
/// and the perimeter edge line lie there; ticks, bloom and the hold bar
/// stay in the bands above and below.
///
/// Operator and `=` glyphs (`+ − × ÷ =`) are set 15 % larger: Oxanium
/// draws them at about 60 % of the digit height.
///
/// Cost per key: 4 draws at rest, ≤ 6 while held (one more halo draw
/// mid-transition); no saveLayer, no BackdropFilter, no Path or Paint
/// built in `paint` (geometry and the blurred halo image are cached per
/// key size; in-between faces of a theme transition use quantised
/// geometry from a second cache).
library;

import 'dart:math' as math;

import 'package:calsee_themes/engine/cyberpunk.dart'
    show cyberLabelZoneBottom, cyberLabelZoneTop;
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/cyberpunk/cyber_geometry.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/widgets.dart';

/// The label zone rows, re-exported for render tests.
const double cyberKeyLabelZoneTop = cyberLabelZoneTop;
const double cyberKeyLabelZoneBottom = cyberLabelZoneBottom;

/// Cyberpunk key renderer for one theme. A same-family theme change lerps
/// the plunge, edge width, glow and chamfer ([LerpableKeyFace]).
final class CyberKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const CyberKeyFace({
    this.plunge = 2,
    this.edgeWidth = 1.25,
    this.haloSigma = 2,
    this.haloRest = restHalo,
    this.haloPeak = peakHalo,
    this.chamfer = 0.18,
    this.lightBody = false,
    this.lite = false,
    super.slashedZero,
    this.layoutBase,
    this.haloFar,
    this.haloFarWeight = 0,
  });

  /// The dark themes' halo opacity at rest: the neon reads as lit.
  static const double restHalo = 0.55;

  /// The dark themes' halo opacity at the frame-1 flare.
  static const double peakHalo = 1;

  /// Press plunge, dp (`motion.depthCdp`).
  final double plunge;

  /// Neon edge line width, dp (`keyStyle.outlineWidthCdp`).
  final double edgeWidth;

  /// Halo blur σ, dp (`keyStyle.shadowBlurCdp / 200`).
  final double haloSigma;

  /// Halo opacity at rest (0 on Hazard and under the Accessible lock).
  final double haloRest;

  /// Halo opacity at the frame-1 flare (0 on Hazard).
  final double haloPeak;

  /// Chamfer as a fraction of the plate's short side (≤ 0.30).
  final double chamfer;

  /// The light Hazard body: no halo, black slab boundaries, plates' neon
  /// line inset behind a black rim.
  final bool lightBody;

  /// Lite effects tier: one halo ring and a flat bloom, no blur or gradient.
  final bool lite;

  /// For an in-between face of a theme morph: the end it is closer to
  /// (label placement, halo image); null for a theme's own face.
  final CyberKeyFace? layoutBase;

  /// For an in-between face: the farther end, whose cached halo is
  /// cross-faded in at [haloFarWeight] (≤ 0.5), so the glow follows the
  /// blended chamfer instead of switching shape at the midpoint.
  final CyberKeyFace? haloFar;

  /// The farther end's share of the halo (0–0.5).
  final double haloFarWeight;

  /// The operator and `=` glyphs, drawn [operatorGlyphScale] larger.
  static const Set<String> operatorGlyphs = {'+', '−', '×', '÷', '='};

  /// Oxanium's `+ − × ÷ =` sit at about 60 % of the digit height.
  static const double operatorGlyphScale = 1.15;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  /// The end face whose cached halo this face draws (in-between faces use
  /// the nearer end's, so a transition never builds one).
  CyberKeyFace get haloSource => layoutBase ?? this;

  @override
  Widget label(String text, TextStyle style) => super.label(
    text,
    operatorGlyphs.contains(text) && style.fontSize != null
        ? style.copyWith(fontSize: style.fontSize! * operatorGlyphScale)
        : style,
  );

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as CyberKeyFace;
    if (other is! CyberKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as CyberKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    // Numbers follow t (the shape rubber-band may overshoot to 1.06);
    // opacities and lengths are clamped so an overshoot stays valid.
    double number(double x, double y) => x + (y - x) * t;
    final near = c < 0.5 ? a : b;
    final far = c < 0.5 ? b : a;
    return CyberKeyFace(
      plunge: math.max(0, number(a.plunge, b.plunge)),
      edgeWidth: math.max(0, number(a.edgeWidth, b.edgeWidth)),
      haloSigma: near.haloSigma,
      haloRest: number(a.haloRest, b.haloRest).clamp(0.0, 1.0),
      haloPeak: number(a.haloPeak, b.haloPeak).clamp(0.0, 1.0),
      chamfer: number(a.chamfer, b.chamfer).clamp(0.0, 0.3),
      lightBody: near.lightBody,
      lite: near.lite,
      slashedZero: near.slashedZero,
      layoutBase: near,
      haloFar: far,
      haloFarWeight: c < 0.5 ? c : 1 - c,
    );
  }

  /// Builds both ends' geometry and halos ahead of the transition, so the
  /// in-between faces (quantised geometry, the two ends' halos
  /// cross-faded) find them cached.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {
    (layoutFace as CyberKeyFace).prepare(cellSizes);
    if (other.layoutFace case final CyberKeyFace b) b.prepare(cellSizes);
  }

  /// Builds the plate geometry and halo for keys of [cellSizes].
  @override
  void prepare(Iterable<Size> cellSizes) {
    for (final size in cellSizes) {
      if (size.isEmpty || !size.isFinite) continue;
      final g = geometryFor(size);
      if (!lite && haloPeak > 0 && haloSigma > 0 && !g.face.isEmpty) {
        CyberHalo.forPlate(g.face, g.cut, haloSigma);
      }
    }
  }

  /// The plate geometry for a key box of [size]: the shared cache for a
  /// theme's own face; for an in-between face (its numbers change every
  /// frame) quantised values (chamfer to 1/200, edge to 0.05 dp, plunge to
  /// 0.1 dp) from a second cache, so a transition builds each step once
  /// per key size instead of every key every frame, and never evicts the
  /// steady-state entries.
  CyberKeyGeometry geometryFor(Size size) => layoutBase == null
      ? CyberKeyGeometry.cached(
          size,
          chamfer: chamfer,
          edgeWidth: edgeWidth,
          plunge: plunge,
        )
      : CyberKeyGeometry.transient(
          size,
          chamfer: (chamfer * 200).roundToDouble() / 200,
          edgeWidth: (edgeWidth * 20).roundToDouble() / 20,
          plunge: (plunge * 10).roundToDouble() / 10,
        );

  /// The plunge for a key box of [size] (never more than s/16).
  double depthFor(Size size) =>
      math.max(0, math.min(plunge, size.shortestSide / 16)).toDouble();

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      CyberKeyPainter(motion: motion, spec: spec, face: this);

  /// The label rides the plate: centred on it at rest (d/2 above the box
  /// centre), plunging d with it.
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final d = depthFor(constraints.biggest);
          return PressTranslate(
            press: motion.press,
            rest: Offset(0, -d / 2),
            travel: Offset(0, d),
            reduceMotion: spec.reduceMotion,
            child: label,
          );
        },
      );

  @override
  bool operator ==(Object other) =>
      other is CyberKeyFace &&
      other.plunge == plunge &&
      other.edgeWidth == edgeWidth &&
      other.haloSigma == haloSigma &&
      other.haloRest == haloRest &&
      other.haloPeak == haloPeak &&
      other.chamfer == chamfer &&
      other.lightBody == lightBody &&
      other.lite == lite &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase &&
      other.haloFar == haloFar &&
      other.haloFarWeight == haloFarWeight;

  @override
  int get hashCode => Object.hash(
    CyberKeyFace,
    plunge,
    edgeWidth,
    haloSigma,
    haloRest,
    haloPeak,
    chamfer,
    lightBody,
    lite,
    slashedZero,
    layoutBase,
    haloFar,
    haloFarWeight,
  );
}

/// Paints one Cyberpunk key. Repaints from the motion channels without
/// rebuilds; every Paint is a field and every Path comes from the cached
/// geometry.
class CyberKeyPainter extends CustomPainter {
  CyberKeyPainter({
    required this.motion,
    required this.spec,
    required this.face,
  }) : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final CyberKeyFace face;

  /// Slab flare (state-layer opacity at the frame-1 flare): the neon goes
  /// hot toward white, lightly (the halo carries the flare; more washes
  /// magenta and acid toward pastel).
  static const double slabFlare = 0.10;

  /// Plate flare: the face moves this far toward its neon edge at the
  /// frame-1 flare (Hazard: [hazardPlateFlare]), capped by
  /// [plateFlareLimit].
  static const double plateFlare = 0.14;

  /// Hazard plate flare toward the cyan line.
  static const double hazardPlateFlare = 0.10;

  /// Edge heat: the edge colour moves this far toward white at the flare.
  static const double edgeHeat = 0.45;

  /// Lite tier: the glow ring's opacity at full halo.
  static const double liteRingAlpha = 0.30;

  /// Lite tier: the flat bloom band's opacity at the flare.
  static const double liteBloomAlpha = 0.10;

  /// How far (0–[reach]) a plate of [fill] may move toward [neon] before
  /// its [label] would drop below `min(rest contrast, floor)`, the floor
  /// being 7:1 for a label resting at ≥ 7:1 (it may be the Accessible
  /// lock's) and 4.5:1 otherwise: the flare never costs a label its floor.
  static double plateFlareLimit(
    Color fill,
    Color label,
    Color neon,
    double reach,
  ) {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
    }

    final rest = ratio(label, fill);
    final floor = math.min(rest, rest >= 7 ? 7.0 : 4.5);
    bool ok(double f) => ratio(label, Color.lerp(fill, neon, f)!) >= floor;
    if (ok(reach)) return reach;
    var lo = 0.0;
    var hi = reach;
    for (var i = 0; i < 14; i++) {
      final mid = (lo + hi) / 2;
      if (ok(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  late final double _plateReach = plateFlareLimit(
    spec.style.fill,
    spec.style.label,
    spec.style.outline ?? spec.style.label,
    face.lightBody ? hazardPlateFlare : plateFlare,
  );

  /// The face colour at glow [g] and hover [hover]: plates move toward
  /// their neon (within [plateFlareLimit]), slabs lift toward white; hover
  /// adds the contrast-safe state layer.
  Color faceColor(double g, {double hover = 0}) {
    final style = spec.style;
    final hoverLayer = spec.hoverOverlayOpacity * hover;
    if (slab) {
      return withStateLayer(
        style.fill,
        style.label,
        math.max(slabFlare * g, hoverLayer),
      );
    }
    final f = _plateReach * g.clamp(0.0, 1.0);
    final lit = f > 0
        ? Color.lerp(style.fill, style.outline ?? style.label, f)!
        : style.fill;
    return withStateLayer(lit, style.label, hoverLayer);
  }

  final Paint _halo = Paint()..filterQuality = FilterQuality.low;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _fill = Paint();
  final Paint _bloom = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.miter;
  final Paint _tick = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.butt
    ..strokeJoin = StrokeJoin.miter;
  final Paint _hold = Paint();
  Color? _haloTint;
  Color? _bloomTint;
  CyberKeyGeometry? _geometry;
  Size? _geometrySize;

  /// Whether this key is a slab (operator or `=`).
  bool get slab => spec.role == KeyRole.operator || spec.role == KeyRole.equals;

  /// Press depth used for geometry: clamped to [0, 1], discrete under
  /// Reduce Motion.
  double pressFor(double p) =>
      effectivePress(p, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);

  /// The glow strength (the frame-1 flare and its afterglow).
  double get glow => motion.tint.value.clamp(0.0, 1.0);

  /// The spatial glow term (halo spread, edge widening): [glow], or under
  /// Reduce Motion a discrete swap with the seated plate.
  double spatialGlow(double p) => spec.reduceMotion ? p : glow;

  /// The halo opacity now (0 when the theme has no halo).
  double haloAlpha() {
    if (face.haloPeak <= 0) return 0;
    final hover = motion.hover.value.clamp(0.0, 1.0);
    return (face.haloRest +
            (face.haloPeak - face.haloRest) * glow +
            0.15 * hover)
        .clamp(0.0, 1.0);
  }

  CyberKeyGeometry _ensure(Size size) {
    final g = _geometry;
    if (g != null && _geometrySize == size) return g;
    _geometrySize = size;
    return _geometry = face.geometryFor(size);
  }

  /// Draws the halo of [source] (an end face) around [f0] at [alpha].
  void _drawHalo(
    Canvas canvas,
    Size size,
    Rect f0,
    CyberKeyFace source,
    double alpha,
    double spread,
  ) {
    if (alpha <= 0) return;
    final g = identical(source, face) ? _geometry! : source.geometryFor(size);
    final halo = CyberHalo.forPlate(g.face, g.cut, source.haloSigma);
    _halo.color = Color.fromRGBO(0, 0, 0, alpha);
    final dst = f0.inflate(halo.pad + 0.75 * spread);
    // Nine-slice corners (and the exact small-key images) are drawn at one
    // image pixel per canvas unit, so the halo (rasterised at
    // CyberHalo.scale×) is drawn in a canvas scaled down by that factor.
    const k = CyberHalo.scale;
    final scaled = Rect.fromLTRB(
      dst.left * k,
      dst.top * k,
      dst.right * k,
      dst.bottom * k,
    );
    canvas
      ..save()
      ..scale(1 / k);
    if (halo.center == null) {
      canvas.drawImageRect(
        halo.image,
        Offset.zero &
            Size(halo.image.width.toDouble(), halo.image.height.toDouble()),
        scaled,
        _halo,
      );
    } else {
      canvas.drawImageNine(halo.image, halo.center!, scaled, _halo);
    }
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final geo = _ensure(size);
    final f0 = geo.face;
    if (f0.width <= 0 || f0.height <= 0) return;
    final style = spec.style;
    final outline = style.outline ?? style.label;
    final g = glow;
    final p = pressFor(motion.press.value);
    final gs = spatialGlow(p);
    final w = geo.edge;
    final hazardSlab = slab && face.lightBody;

    canvas
      ..save()
      ..translate(0, geo.depth * p);

    // 1. Halo: the blurred plate (lite: one ring), in the edge colour
    // (plates) or the face colour (slabs).
    final haloA = haloAlpha();
    if (haloA > 0) {
      final tint = slab ? style.fill : outline;
      if (face.lite) {
        _ring.color = tint.withValues(alpha: tint.a * haloA * liteRingAlpha);
        canvas.drawPath(geo.liteRing, _ring);
      } else if (face.haloSigma > 0) {
        if (_haloTint != tint) {
          _haloTint = tint;
          _halo.colorFilter = ColorFilter.mode(tint, BlendMode.srcIn);
        }
        // In-between faces cross-fade the two ends' cached halos (their
        // chamfers bracket the blended one), so a transition never builds
        // a halo and the glow never jumps shape at the midpoint.
        final far = face.haloFar;
        final wFar = far == null || far.haloSigma <= 0 || far.lite
            ? 0.0
            : face.haloFarWeight.clamp(0.0, 0.5);
        final a = haloA * tint.a;
        _drawHalo(canvas, size, f0, face.haloSource, a * (1 - wFar), gs);
        if (wFar > 0) _drawHalo(canvas, size, f0, far!, a * wFar, gs);
      }
    }

    // 2. Face, with the flare and hover layers (contrast-safe).
    _fill.color = faceColor(g, hover: motion.hover.value);
    canvas.drawPath(geo.facePath, _fill);

    // 3. Inner bloom (plates): the neon soaking into thin bands just
    // inside the top and bottom edge lines.
    if (!slab && g > 0) {
      if (face.lite) {
        _bloom
          ..shader = null
          ..colorFilter = null
          ..color = outline.withValues(alpha: outline.a * liteBloomAlpha * g);
      } else {
        if (_bloomTint != outline) {
          _bloomTint = outline;
          _bloom.colorFilter = ColorFilter.mode(outline, BlendMode.srcIn);
        }
        _bloom
          ..shader = geo.bloomShader
          ..color = Color.fromRGBO(0, 0, 0, g);
      }
      canvas.drawPath(geo.bloomPath, _bloom);
    }

    // 4. Edge line: heats toward white and widens at the flare; Hazard
    // slabs keep their black boundary (their only key boundary) and
    // thicken it instead.
    final edgePath = !slab && face.lightBody ? geo.insetEdgePath : geo.edgePath;
    if (w > 0) {
      if (hazardSlab) {
        _stroke
          ..color = outline
          ..strokeWidth = w + 1.5 * gs;
      } else {
        _stroke
          ..color = Color.lerp(outline, const Color(0xFFFFFFFF), edgeHeat * g)!
          ..strokeWidth = w + 0.5 * gs;
      }
      canvas.drawPath(edgePath, _stroke);
    }

    // 5. HUD ticks at the square corners.
    final tickAlpha = slab ? (hazardSlab ? 0.55 + 0.45 * g : 0.55) : 0.75;
    final tickColor = slab ? style.label : outline;
    _tick.color = tickColor.withValues(alpha: tickColor.a * tickAlpha);
    canvas.drawPath(
      !slab && face.lightBody ? geo.insetTickPath : geo.tickPath,
      _tick,
    );

    // 6. Long-press charge bar along the bottom of the plate (fades in
    // place under Reduce Motion).
    final hold = motion.holdFill;
    if (hold > 0 && g > 0) {
      final rm = spec.reduceMotion;
      final r = geo.inner;
      final h = r.height * 0.06;
      _hold.color = style.label.withValues(alpha: (rm ? hold : 1) * g);
      canvas
        ..save()
        ..clipPath(geo.innerPath)
        ..drawRect(
          Rect.fromLTWH(
            r.left,
            r.bottom - h,
            rm ? r.width : r.width * hold.clamp(0.0, 1.0),
            h,
          ),
          _hold,
        )
        ..restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CyberKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
