/// Paper & ink key artwork: hand-drawn fineliner outlines, the operator
/// hatch, the `=` rubber stamp and the ink-wash blot, built once per
/// (art seed, key size, kind) and cached ([PaperArtCache]).
///
/// The artwork depends on the key and its size only — never on a theme's
/// colours or outline width — so a Paper → Paper theme morph (which builds
/// a new painter every frame) never rebuilds a path. Widths, colours and
/// alphas are applied at paint time.
///
/// Geometry for a key box of w × h, s = the shorter side (all dp):
///
/// - **Outline**: four open sides drawn clockwise (top L→R, right T→B,
///   bottom R→L, left B→T), each a cubic (two, C1-joined, on long sides)
///   from a pen-down point 0–0.3·o before its start corner to a flick
///   0.6–1·o past its end corner (o = clamp(0.03·s, 1, 1.2)), so every
///   gutter crossing has one long tip and one short one. The ends wander
///   0.3–0.9·e inside the edge or 0.17–0.5·e outside it (e ≤ 1 dp), and
///   the bows lean inward (−0.35…+1)·a with a = clamp(0.022·s, 0.9, 1.8).
///   The geometry reaches at most [paperArtReach] (2.45 dp) outside the
///   box even with the pressed pen (1.4 × 1.75 dp). Rasterised, the
///   anti-aliased edge adds ≈ 0.2 dp and the cache's 0.5 dp size steps up
///   to 0.25 dp more on the right and bottom, so edge pixels reach
///   ≈ 2.75 dp — ≈ 3.75 dp below a pressed key (the 1 dp drop). That can
///   graze the middle 1 dp of an 8 dp key gutter, but two neighbours
///   (≤ 2.75 + 3.75 = 6.5 dp) never meet. (The keypad clips to its own
///   bounds, so on layouts whose outer keys touch its edge those tips are
///   trimmed there.)
/// - **Retrace** (pass 2): a second, lighter hand over 75–100 % of each
///   side, starting 0.5–0.9 dp inside pass 1 on two sides (≤ 0.35 dp
///   outside on the others) and ending on the other side of it, so it
///   crosses the first line like a real second pass instead of running
///   beside it like a shadow.
/// - **Boil** (variant B, the pressed frame): the same sides with every
///   end offset mirrored across the edge and every bow moved by 0.675·a —
///   each side jumps ≥ 0.6 dp in frame 1.
/// - **Label zone** K = the box deflated by b = clamp(0.2·s, 6, 18) (≤ a
///   quarter of the short side); operators narrow the horizontal band to
///   fit `mod` at their heaviest weight, function slips to fit `−GST`
///   (0.3·s at wght 800, ≈ 0.8·s wide). Nothing here ever enters K.
/// - **Hatch** (operators): 45° lines (x + y = c), spacing
///   clamp(0.065·s, 3.8, 5.5) jittered ±12 %, analytically clipped to the
///   box deflated by 3 dp minus K inflated by 1 dp. An end beside K is
///   pulled back 1–3 dp along its line, an end on the outer frame
///   0.3–1.2 dp, and each line turns ±2° about its midpoint, so the inner
///   edge is ragged like hand hatching, never a ruled rectangle.
/// - **Stamp** (`=`): a closed wobbly body inside the box deflated by
///   4 dp (≤ 1 dp wobble, rounded corners), an inner border between it
///   and K, two clusters of worn speckles near the body's edge and one or
///   two hairline scratches; body, border and wear are turned 0.6–1.5°
///   about the key's centre (less on wide keys: the far ends move ≤ 1 dp,
///   so the border stays ≥ 0.5 dp outside K).
/// - **Underline** (long press): one wobbly cubic (± 0.6 dp) across K's
///   width, halfway between K and the bottom of the box.
/// - **Wash**: an irregular 14-lobe blot (radius ±18 %) in unit space,
///   scaled to the wash radius at paint time.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:calsee_themes/engine/rng.dart' show mul32;
import 'package:flutter/painting.dart';

/// What a key's artwork shows.
enum PaperArtKind {
  /// Digit, decimal and sign slips: two passes.
  slipDigit,

  /// Every other non-operator slip: one, lighter pass.
  slipFunction,

  /// Operators: two passes and the hatch.
  operator,

  /// `=`: two passes and the rubber stamp.
  stamp,
}

/// `lowbias32` (Chris Wellons): a 32-bit integer hash, bit-exact on every
/// backend (masked [mul32] products only).
int paperHash32(int value) {
  var x = value & 0xFFFFFFFF;
  x = (x ^ (x >>> 16)) & 0xFFFFFFFF;
  x = mul32(x, 0x7FEB352D);
  x = (x ^ (x >>> 15)) & 0xFFFFFFFF;
  x = mul32(x, 0x846CA68B);
  return (x ^ (x >>> 16)) & 0xFFFFFFFF;
}

/// A uniform value in [0, 1) for draw [i] of [seed].
double paperUnit(int seed, int i) =>
    (paperHash32(seed ^ mul32((i + 1) & 0xFFFFFFFF, 0x9E3779B1)) >>> 8) /
    16777216;

/// Seed salts: the kind, the retrace (pass 2), the stamp body and the
/// hatch's pulls and turns.
const int paperRetraceSalt = 0x5EC0D000;
const int paperStampSalt = 0x57A3F000;
const int paperHatchSalt = 0x4A7C4000;

int _kindSalt(PaperArtKind kind) => switch (kind) {
  PaperArtKind.slipDigit => 0x11,
  PaperArtKind.slipFunction => 0x22,
  PaperArtKind.operator => 0x33,
  PaperArtKind.stamp => 0x44,
};

/// One drawing of a key outline (pass 1 and its retrace).
final class PaperStroke {
  const new({required this.stroke, required this.sketch, required this.blobs});

  /// Pass 1: four open sides.
  final Path stroke;

  /// Pass 2: the retrace (empty for [PaperArtKind.slipFunction]).
  final Path sketch;

  /// Pen-down points of pass 1 (x, y pairs), drawn as round dots.
  final Float32List blobs;
}

/// The long-press "pen underline": one cubic whose control points sit at
/// thirds of its width, so x is linear in the curve parameter and the pen
/// tip at any fraction is found without measuring the path.
final class PaperUnderline {
  const new({
    required this.path,
    required this.left,
    required this.right,
    required this.ys,
  });

  /// The whole line (stroked; clipped at paint time as it grows).
  final Path path;

  /// Its start and end x, dp.
  final double left;
  final double right;

  /// The y of its four control points.
  final Float32List ys;

  /// The line's x at [fraction] of its width.
  double xAt(double fraction) =>
      left + (right - left) * fraction.clamp(0.0, 1.0);

  /// The line's y at [fraction] of its width.
  double yAt(double fraction) {
    final t = fraction.clamp(0.0, 1.0);
    final u = 1 - t;
    return u * u * u * ys[0] +
        3 * u * u * t * ys[1] +
        3 * u * t * t * ys[2] +
        t * t * t * ys[3];
  }
}

/// A key's cached artwork.
final class PaperKeyArt {
  const new({
    required this.size,
    required this.kind,
    required this.rest,
    required this.boil,
    required this.labelZone,
    required this.wash,
    required this.grainOffset,
    required this.underline,
    this.hatch,
    this.stampBody,
    this.border,
    this.speckles,
    this.stampAngle = 0,
  });

  /// The key box it was drawn for.
  final Size size;

  /// What it shows.
  final PaperArtKind kind;

  /// The outline at rest (variant A).
  final PaperStroke rest;

  /// The boiled outline of the pressed frame (variant B).
  final PaperStroke boil;

  /// The label zone K: no artwork but the face fill and the wash may
  /// cover it.
  final Rect labelZone;

  /// The ink-wash blot, radius ≈ 1 around the origin.
  final Path wash;

  /// Where this key's window into the shared grain tile starts (dp).
  final Offset grainOffset;

  /// The long-press pen underline.
  final PaperUnderline underline;

  /// Operator hatch lines (stroked, butt caps).
  final Path? hatch;

  /// The `=` stamp body (filled; already turned by [stampAngle]).
  final Path? stampBody;

  /// The `=` stamp's inner border (stroked), in the stamp's own frame:
  /// paint it turned by [stampAngle] about the key's centre.
  final RRect? border;

  /// The `=` stamp's worn speckles and scratches (filled; already turned).
  final Path? speckles;

  /// The `=` stamp's turn about the key's centre, radians (0 otherwise).
  final double stampAngle;
}

/// The label band b of a key of [size] and [kind] as (horizontal,
/// vertical).
(double, double) paperLabelBand(Size size, PaperArtKind kind) {
  final s = size.shortestSide;
  final cap = 0.25 * s;
  var b = (0.2 * s).clamp(6.0, 18.0);
  if (b > cap) b = cap;
  switch (kind) {
    case PaperArtKind.operator:
      // `mod` / `logₓ` at the operator weight (+ Bold Text) must fit.
      var bx = math
          .min(0.2 * s, (size.width - 0.66 * s - 4) / 2)
          .clamp(5.0, 18.0);
      if (bx > cap) bx = cap;
      return (bx, b);
    case PaperArtKind.slipFunction:
      // `+GST` / `−GST` at 0.3·s (≈ 2.6 em at wght 800 with Bold Text)
      // must fit: K takes all but ≥ 4 dp each side of the width.
      final bx = ((size.width - 0.8 * s - 2) / 2)
          .clamp(math.min(4, b), b)
          .toDouble();
      return (bx, b);
    case PaperArtKind.slipDigit || PaperArtKind.stamp:
      return (b, b);
  }
}

/// The label zone K of a key of [size] and [kind].
Rect paperLabelZone(Size size, PaperArtKind kind) {
  final (bx, by) = paperLabelBand(size, kind);
  return Rect.fromLTRB(bx, by, size.width - bx, size.height - by);
}

/// How far any key artwork reaches outside its box, dp (pressed pen
/// included; the 1 dp press drop comes on top at the bottom).
const double paperArtReach = 2.45;

/// Wobble amplitude a, overshoot o and end wander e for a key whose
/// shorter side is [s].
({double a, double o, double e}) paperStrokeScale(double s) => (
  a: (0.022 * s).clamp(0.9, 1.8),
  o: (0.03 * s).clamp(1.0, 1.2),
  e: (s / 48).clamp(0.4, 1.0),
);

/// Builds a key's artwork (cache misses only).
PaperKeyArt buildPaperKeyArt(int artSeed, Size size, PaperArtKind kind) {
  final seed = (artSeed ^ _kindSalt(kind)) & 0xFFFFFFFF;
  final twoPass = kind != PaperArtKind.slipFunction;
  final zone = paperLabelZone(size, kind);
  final stamp = kind == PaperArtKind.stamp;
  final angle = stamp ? paperStampAngle(seed, size) : 0.0;
  final border = stamp ? _stampBorder(size, zone) : null;
  // Body and wear are built upright, then turned about the key's centre
  // (the border is turned at paint time: it stays an RRect).
  final turn = angle == 0
      ? null
      : _rotationAbout(size.center(Offset.zero), angle);
  Path turned(Path p) => turn == null ? p : p.transform(turn);
  return PaperKeyArt(
    size: size,
    kind: kind,
    rest: _outline(seed, size, boiled: false, retrace: twoPass),
    boil: _outline(seed, size, boiled: true, retrace: twoPass),
    labelZone: zone,
    wash: _washBlot(seed),
    grainOffset: Offset(paperUnit(seed, 900) * 160, paperUnit(seed, 901) * 160),
    underline: _underline(seed, size, zone),
    hatch: kind == PaperArtKind.operator ? _hatch(seed, size, zone) : null,
    stampBody: stamp ? turned(_stampBody(seed, size)) : null,
    border: border,
    speckles: border != null
        ? turned(_speckles(seed, size, zone, border, angle))
        : null,
    stampAngle: angle,
  );
}

/// A column-major 4 × 4 matrix turning by [angle] radians about [c].
Float64List _rotationAbout(Offset c, double angle) {
  final cos = math.cos(angle);
  final sin = math.sin(angle);
  return Float64List.fromList([
    cos, sin, 0, 0, //
    -sin, cos, 0, 0, //
    0, 0, 1, 0, //
    c.dx - cos * c.dx + sin * c.dy, c.dy - sin * c.dx - cos * c.dy, 0, 1,
  ]);
}

/// The `=` stamp's turn, radians: ±(0.6–1.5)°, less where the stamp's far
/// ends would move more than the room between its border and K (≤ 1 dp)
/// or between its body and K.
double paperStampAngle(int seed, Size size) {
  final st = (seed ^ paperStampSalt) & 0xFFFFFFFF;
  final t = (Offset.zero & size).deflate(paperStampInset);
  if (t.width <= 2 || t.height <= 2) return 0;
  final (_, by) = paperLabelBand(size, PaperArtKind.stamp);
  final amp = math.min(1, 0.012 * size.shortestSide);
  final room = math.min(1, by - paperStampInset - amp - 0.5).toDouble();
  if (room <= 0) return 0;
  final most = room / (0.5 * math.max(t.width, t.height));
  final want = (0.6 + 0.9 * paperUnit(st, 40)) * math.pi / 180;
  final a = math.min(want, most);
  return paperUnit(st, 41) < 0.5 ? -a : a;
}

/// The pen underline: halfway between K's bottom and the box's, across
/// K's width, wobbling ± 0.6 dp.
PaperUnderline _underline(int seed, Size size, Rect zone) {
  final y = (zone.bottom + size.height) / 2;
  double wobble(int i, double scale) =>
      y + 0.6 * scale * (paperUnit(seed, 800 + i) * 2 - 1);
  final ys = Float32List.fromList([
    wobble(0, 0.5),
    wobble(1, 1),
    wobble(2, 1),
    wobble(3, 0.5),
  ]);
  final l = zone.left;
  final r = zone.right;
  final w = r - l;
  final path = Path()
    ..moveTo(l, ys[0])
    ..cubicTo(l + w / 3, ys[1], l + 2 * w / 3, ys[2], r, ys[3]);
  return PaperUnderline(path: path, left: l, right: r, ys: ys);
}

PaperStroke _outline(
  int seed,
  Size size, {
  required bool boiled,
  required bool retrace,
}) {
  final w = size.width;
  final h = size.height;
  final s = size.shortestSide;
  final k = paperStrokeScale(s);
  final corners = [Offset.zero, Offset(w, 0), Offset(w, h), Offset(0, h)];
  final stroke = Path();
  final sketch = Path();
  final blobs = Float32List(8);
  for (var i = 0; i < 4; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % 4];
    final start = _side(
      stroke,
      seed,
      i,
      a,
      b,
      s,
      amp: k.a,
      over: k.o,
      wander: k.e,
      boiled: boiled,
    );
    blobs[i * 2] = start.dx;
    blobs[i * 2 + 1] = start.dy;
    if (retrace) {
      _retraceSide(
        sketch,
        (seed ^ paperRetraceSalt) & 0xFFFFFFFF,
        i,
        a,
        b,
        s,
        amp: k.a * 0.8,
        over: k.o * 0.6,
        wander: k.e * 0.8,
        boiled: boiled,
      );
    }
  }
  return PaperStroke(stroke: stroke, sketch: sketch, blobs: blobs);
}

/// A bow parameter in [0, 1) and its boiled partner (0.5 away).
double _bow(double t, {required bool boiled}) =>
    boiled ? (t < 0.5 ? t + 0.5 : t - 0.5) : t;

/// The inward bow offset for parameter [t] at amplitude [amp].
double _bowOffset(double t, double amp) => amp * (-0.35 + 1.35 * t);

/// One side of pass 1 from corner [a] to [b]; returns its pen-down point.
Offset _side(
  Path path,
  int seed,
  int i,
  Offset a,
  Offset b,
  double s, {
  required double amp,
  required double over,
  required double wander,
  required bool boiled,
  double bias = 0,
  double? biasEnd,
  double from = 0,
  double to = 1,
}) {
  double u(int k) => paperUnit(seed, i * 8 + k);
  final length = (b - a).distance;
  if (length <= 0) return a;
  final dir = (b - a) / length;
  final nrm = Offset(-dir.dy, dir.dx); // inward for clockwise sides
  // Ends: a short pen-down before the start corner, a flick past the end.
  final u0 = boiled ? 1 - u(0) : u(0);
  final u1 = boiled ? 1 - u(1) : u(1);
  final preStart = over * 0.3 * u0;
  final postEnd = over * (0.6 + 0.4 * u1);
  final sign2 = u(2) < 0.5 ? -1.0 : 1.0;
  final sign3 = u(3) < 0.5 ? -1.0 : 1.0;
  // Normal offsets are inward-positive; outward ones are damped so the
  // stroke stays within [paperArtReach] of the box.
  double end(double sign, double v) {
    final raw = sign * wander * (0.3 + 0.6 * v);
    return raw < 0 ? raw * 0.55 : raw;
  }

  final e0 = end(boiled ? -sign2 : sign2, u(6));
  final e3 = end(boiled ? -sign3 : sign3, u(7));
  final startAlong = from <= 0 ? -preStart : from * length;
  final endAlong = to >= 1 ? length + postEnd : to * length;
  final p0 = a + dir * startAlong + nrm * (e0 + bias);
  final bias1 = biasEnd ?? bias;
  final p3 = a + dir * endAlong + nrm * (e3 + bias1);
  final span = endAlong - startAlong;
  final b1 = _bowOffset(_bow(u(4), boiled: boiled), amp);
  final b2 = _bowOffset(_bow(u(5), boiled: boiled), amp);
  path.moveTo(p0.dx, p0.dy);
  if (span > 1.6 * s) {
    // Long sides (the wide `0`): two cubics joined C1 at a wandering
    // midpoint.
    final um = _bow(paperUnit(seed, 40 + i), boiled: boiled);
    final mid =
        a +
        dir * (startAlong + span / 2) +
        nrm * ((bias + bias1 + e0 + e3) / 2 + _bowOffset(um, amp) * 0.6);
    final third = span / 6;
    final c1 = p0 + dir * third + nrm * b1;
    final c2 = mid - dir * third;
    final c3 = mid + dir * third;
    final c4 = p3 - dir * third + nrm * b2;
    path
      ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, mid.dx, mid.dy)
      ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, p3.dx, p3.dy);
  } else {
    final c1 = p0 + (p3 - p0) / 3 + nrm * b1;
    final c2 = p0 + (p3 - p0) * (2 / 3) + nrm * b2;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy);
  }
  return p0;
}

/// One side of the retrace: 75–100 % of the side, biased off pass 1 —
/// inward on two sides, slightly outward on the others.
void _retraceSide(
  Path path,
  int seed,
  int i,
  Offset a,
  Offset b,
  double s, {
  required double amp,
  required double over,
  required double wander,
  required bool boiled,
}) {
  double u(int k) => paperUnit(seed, 64 + i * 4 + k);
  final inward = (i + (seed & 1)).isEven;
  final bias = inward ? 0.5 + 0.4 * u(0) : -(0.15 + 0.2 * u(0));
  final biasEnd = -bias * (0.3 + 0.4 * paperUnit(seed, 120 + i));
  final from = u(1) < 0.4 ? 0.0 : 0.04 + 0.16 * u(2);
  final to = u(3) < 0.4 ? 1.0 : 0.8 + 0.16 * u(2);
  _side(
    path,
    seed,
    i,
    a,
    b,
    s,
    amp: amp,
    over: over,
    wander: wander,
    boiled: boiled,
    bias: bias,
    biasEnd: biasEnd,
    from: from,
    to: to,
  );
}

/// The wash blot: 14 lobes around the origin, radius 1 ± 18 %.
Path _washBlot(int seed) {
  const lobes = 14;
  final radii = [
    for (var i = 0; i < lobes; i++) 0.82 + 0.36 * paperUnit(seed, 200 + i),
  ];
  Offset at(int i) {
    final angle = 2 * math.pi * i / lobes;
    final r = radii[i % lobes];
    return Offset(math.cos(angle) * r, math.sin(angle) * r);
  }

  // A closed Catmull-Rom spline through the lobe tips, as cubics.
  final path = Path();
  final start = at(0);
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < lobes; i++) {
    final p0 = at(i - 1 + lobes);
    final p1 = at(i);
    final p2 = at(i + 1);
    final p3 = at(i + 2);
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// Hatch spacing for a key whose shorter side is [s].
double paperHatchSpacing(double s) => (0.065 * s).clamp(3.8, 5.5);

/// Hatch line width for a key whose shorter side is [s] (≥ 1 dp, so it
/// keeps its validated contrast on 1× screens).
double paperHatchWidth(double s) => (0.014 * s).clamp(1.0, 1.25);

/// The inset of the hatch frame's outer edge (fixed: the outline width
/// lerps, the artwork does not).
const double paperHatchInset = 3;

/// The inset of the `=` stamp body (fixed, for the same reason).
const double paperStampInset = 4;

Path _hatch(int seed, Size size, Rect zone) {
  final s = size.shortestSide;
  final outer = (Offset.zero & size).deflate(paperHatchInset);
  final path = Path();
  if (outer.isEmpty) return path;
  final hs = paperHatchSpacing(s);
  // Lines x + y = c across the frame, c from the top-left corner on.
  var c = outer.left + outer.top + paperUnit(seed, 300) * hs;
  final cMax = outer.right + outer.bottom;
  var n = 0;
  var draw = 0;
  // The hand's pulls and turns: their own draw stream.
  final hand = (seed ^ paperHatchSalt) & 0xFFFFFFFF;
  void segment(
    double x0,
    double x1,
    double ca, {
    required bool kStart,
    required bool kEnd,
  }) {
    final i = draw++;
    if (x1 - x0 < 0.6) return;
    // Pull each end back along the line (dp; ÷ √2 in x): further beside K
    // than on the outer frame — hand hatching stops short and unevenly.
    double pull(int k, {required bool besideK}) {
      final u = paperUnit(hand, i * 3 + k);
      return (besideK ? 1.0 + 2.0 * u : 0.3 + 0.9 * u) / math.sqrt2;
    }

    final a = x0 + pull(0, besideK: kStart);
    final b = x1 - pull(1, besideK: kEnd);
    if (b - a < 0.6) return;
    // Turn the line ±2° about its midpoint (≤ 0.44 dp at the ends of the
    // longest segments; the ≥ 1 dp pull and K's 1 dp margin absorb it).
    final turn = (paperUnit(hand, i * 3 + 2) * 2 - 1) * 2 * math.pi / 180;
    final cos = math.cos(turn);
    final sin = math.sin(turn);
    final mx = (a + b) / 2;
    final my = ca - mx;
    final dx = (b - a) / 2;
    final dy = -dx;
    final ex = dx * cos - dy * sin;
    final ey = dx * sin + dy * cos;
    path
      ..moveTo(mx - ex, my - ey)
      ..lineTo(mx + ex, my + ey);
  }

  while (c < cMax && n < 400) {
    // x range of the line inside the outer frame.
    final lo = math.max(outer.left, c - outer.bottom);
    final hi = math.min(outer.right, c - outer.top);
    if (hi > lo) {
      // Minus the label zone (with a 1 dp margin).
      final k = zone.inflate(1);
      final klo = math.max(k.left, c - k.bottom);
      final khi = math.min(k.right, c - k.top);
      if (khi <= klo || khi <= lo || klo >= hi) {
        segment(lo, hi, c, kStart: false, kEnd: false);
      } else {
        segment(lo, math.min(klo, hi), c, kStart: false, kEnd: klo < hi);
        segment(math.max(khi, lo), hi, c, kStart: khi > lo, kEnd: false);
      }
    }
    n++;
    c += hs * (0.88 + 0.24 * paperUnit(seed, 500 + n));
  }
  return path;
}

Path _stampBody(int seed, Size size) {
  final s = size.shortestSide;
  final t = (Offset.zero & size).deflate(paperStampInset);
  final path = Path();
  if (t.width <= 2 || t.height <= 2) {
    if (!t.isEmpty) path.addRect(t);
    return path;
  }
  final st = (seed ^ paperStampSalt) & 0xFFFFFFFF;
  final amp = math.min(1, 0.012 * s).toDouble();
  final r = math.min(0.06 * s, math.min(t.width, t.height) / 3);
  final q = [t.topLeft, t.topRight, t.bottomRight, t.bottomLeft];
  for (var i = 0; i < 4; i++) {
    final a = q[i];
    final b = q[(i + 1) % 4];
    final length = (b - a).distance;
    final dir = (b - a) / length;
    final nrm = Offset(-dir.dy, dir.dx);
    final p0 = a + dir * r;
    final p3 = b - dir * r;
    final b1 = amp * (paperUnit(st, i * 4) * 2 - 1);
    final b2 = amp * (paperUnit(st, i * 4 + 1) * 2 - 1);
    final c1 = p0 + (p3 - p0) / 3 + nrm * b1;
    final c2 = p0 + (p3 - p0) * (2 / 3) + nrm * b2;
    if (i == 0) path.moveTo(p0.dx, p0.dy);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p3.dx, p3.dy);
    final next = q[(i + 2) % 4];
    final nDir = (next - b) / (next - b).distance;
    final end = b + nDir * r;
    path.quadraticBezierTo(b.dx, b.dy, end.dx, end.dy);
  }
  return path..close();
}

/// The `=` stamp's inner border: a 1 dp line between the stamp body's
/// edge and the label zone, its inner edge ≥ 1.5 dp outside K (none on
/// keys too small for that).
RRect _stampBorder(Size size, Rect zone) {
  final s = size.shortestSide;
  final t = (Offset.zero & size).deflate(paperStampInset);
  final (_, by) = paperLabelBand(size, PaperArtKind.stamp);
  // Border centre at 4 + 1.5 + inset from the box edge, inner edge 0.5
  // further in: ≤ b − 1.5.
  final inset = math.min(0.075 * s, by - 7.5);
  if (inset < 0) return RRect.zero;
  final rect = t.deflate(inset + 1.5);
  if (rect.isEmpty) return RRect.zero;
  return RRect.fromRectAndRadius(rect, Radius.circular(0.03 * s));
}

/// The `=` stamp's wear, built upright: two clusters of speckles near the
/// body's edge (on different sides, denser at their centres) and one or
/// two hairline scratches (0.5 × 4–8 dp) running along a side. Everything
/// keeps 1.5 dp off K — plus how far the stamp's turn ([angle]) can move
/// a point — and off the border line, inside the body.
Path _speckles(int seed, Size size, Rect zone, RRect border, double angle) {
  final path = Path();
  final t = (Offset.zero & size).deflate(paperStampInset + 1);
  if (t.isEmpty) return path;
  final shift =
      0.5 *
      math.sqrt(t.width * t.width + t.height * t.height) *
      math.sin(angle.abs());
  final keepOut = zone.inflate(1.5 + shift);
  final inner = border.outerRect.deflate(1.5);
  final outer = border.outerRect.inflate(1.5);
  bool allowed(Rect r) {
    if (r.overlaps(keepOut)) return false;
    // Off the border line (± 1.5 dp).
    if (!border.outerRect.isEmpty &&
        r.overlaps(outer) &&
        !(inner.contains(r.topLeft) && inner.contains(r.bottomRight))) {
      return false;
    }
    return t.contains(r.topLeft) && t.contains(r.bottomRight);
  }

  // A point [inset] dp in from t's [side] (0 top, 1 right, 2 bottom,
  // 3 left), [along] of the way along it.
  Offset onSide(int side, double along, double inset) => switch (side) {
    0 => Offset(t.left + along * t.width, t.top + inset),
    1 => Offset(t.right - inset, t.top + along * t.height),
    2 => Offset(t.left + along * t.width, t.bottom - inset),
    _ => Offset(t.left + inset, t.top + along * t.height),
  };

  final first = (paperUnit(seed, 600) * 4).floor() % 4;
  final second = (first + 1 + (paperUnit(seed, 601) * 3).floor() % 3) % 4;
  var i = 0;
  for (final side in [first, second]) {
    final centre = onSide(side, 0.15 + 0.7 * paperUnit(seed, 602 + side), 1.6);
    final count = 7 + (paperUnit(seed, 606 + side) * 5).floor();
    var placed = 0;
    for (var k = 0; k < 48 && placed < count; k++, i++) {
      // Spread along the side (± 6 dp, denser near the centre) more than
      // across it (± 1.6 dp); smaller dots further out.
      final a = paperUnit(seed, 620 + i * 3) * 2 - 1;
      final across = (paperUnit(seed, 621 + i * 3) * 2 - 1) * 1.6;
      final along = a * a.abs() * 6;
      final p =
          centre +
          (side.isEven ? Offset(along, across) : Offset(across, along));
      final r = 0.3 + 0.55 * paperUnit(seed, 622 + i * 3) * (1 - 0.6 * a.abs());
      final dot = Rect.fromCircle(center: p, radius: r);
      if (!allowed(dot)) continue;
      path.addOval(dot);
      placed++;
    }
  }
  final scratches = paperUnit(seed, 760) < 0.5 ? 1 : 2;
  var drawn = 0;
  for (var k = 0; k < 8 && drawn < scratches; k++) {
    final side = (paperUnit(seed, 761 + k * 4) * 4).floor() % 4;
    final start = onSide(
      side,
      0.1 + 0.6 * paperUnit(seed, 762 + k * 4),
      1.0 + 1.5 * paperUnit(seed, 763 + k * 4),
    );
    final length = 4 + 4 * paperUnit(seed, 764 + k * 4);
    final tilt = (paperUnit(seed, 765 + k * 4) * 2 - 1) * 0.25;
    final heading = (side.isEven ? 0.0 : math.pi / 2) + tilt;
    final dir = Offset(math.cos(heading), math.sin(heading));
    final end = start + dir * length;
    final half = Offset(-dir.dy, dir.dx) * 0.25;
    if (!allowed(Rect.fromPoints(start, end).inflate(0.3))) continue;
    path
      ..moveTo(start.dx + half.dx, start.dy + half.dy)
      ..lineTo(end.dx + half.dx, end.dy + half.dy)
      ..lineTo(end.dx - half.dx, end.dy - half.dy)
      ..lineTo(start.dx - half.dx, start.dy - half.dy)
      ..close();
    drawn++;
  }
  return path;
}

/// The family's art cache: an LRU of [PaperKeyArt] keyed by (art seed,
/// size, kind). Never keyed by theme: the same keys share their drawings
/// across every Paper & ink theme and every morph frame.
final class PaperArtCache {
  new({this.capacity = 256});

  /// The app-wide cache.
  static final PaperArtCache instance = PaperArtCache();

  /// Entries kept.
  final int capacity;

  final LinkedHashMap<(int, double, double, PaperArtKind), PaperKeyArt>
  _entries = LinkedHashMap();

  /// Artwork built so far (tests).
  int builds = 0;

  /// The artwork for ([artSeed], [size], [kind]), built on a miss. Sizes
  /// are quantised to 0.5 dp (a resizing desktop window does not rebuild
  /// every key's art every frame; 0.25 dp of drift is invisible).
  PaperKeyArt lookup(int artSeed, Size size, PaperArtKind kind) {
    final w = (size.width * 2).round() / 2;
    final h = (size.height * 2).round() / 2;
    final key = (artSeed, w, h, kind);
    final hit = _entries.remove(key);
    if (hit != null) return _entries[key] = hit;
    builds++;
    final art = _entries[key] = buildPaperKeyArt(artSeed, Size(w, h), kind);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return art;
  }

  /// Forgets everything (tests).
  void clear() {
    _entries.clear();
    builds = 0;
  }
}
