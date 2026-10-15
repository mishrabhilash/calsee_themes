/// Bauhaus key faces: flat primitives in flat colour — no outline, no
/// shadow, no gradient, no texture.
///
/// - **Figures** ([BauhausFigure]): every key is one rounded rectangle in
///   units of its short side s — a block (the whole key, corners ≤ 4 %), a
///   disc, a quarter-disc fan anchored on its bottom-right corner — or an
///   equilateral triangle. The silhouette is the recorded non-colour
///   operator cue: digits and function keys are blocks and operators discs
///   (or, one theme in eight, digits discs and operators blocks), `=` a big
///   disc, fan or triangle.
/// - **Labels** sit on the figure's optical centre: Jost draws `+ − × ÷ =`
///   on its maths axis, ≈ 0.04–0.125 em below the digits' centre, so those
///   labels are lifted back ([bauhausGlyphLift]); the fan's and the
///   triangle's labels move towards their centroids ([BauhausFigure.labelX]
///   / `labelY`).
/// - **Press** — a concentric figure–ground inversion: from the first
///   frame (the `tint` channel snaps to 1 at touch-down; under Reduce
///   Motion the discrete press) a ring of the resting face colour
///   (max(3 dp, 0.08 s) wide) stays and the figure inside it takes the
///   label colour while the label takes the face colour
///   ([BauhausInvertedLabel]). Inside the core the colours are the solved
///   (face, label) pair swapped, so the label keeps its exact contrast; the
///   ring keeps the silhouette visible on every ground. The uniform 0.96
///   press scale is the key widget's; there is no depth and no tint layer.
/// - **Function accent**: on ⌫ / AC, `( )` and `%` keys a quarter-disc of
///   the theme's accent colour (`KeyColors.edge` of the function group;
///   fully transparent = none) sits on the block's top-left corner, outside
///   every label.
/// - **Long press**: a bar in the face colour grows along the bottom of the
///   inverted core, half a ring width inside it so it reads as a bar, not a
///   notch in the ring, and always clear of the label (fades in place under
///   Reduce Motion).
///
/// Cost: one to four `drawRRect`s (a cached `Path` for the triangle), one
/// shared [Paint], geometry rebuilt only when the size changes; no
/// `saveLayer`, shader or blur, so the lite effects tier draws exactly the
/// same. Same-family theme changes morph the figures ([LerpableKeyFace]:
/// block ↔ disc is a true geometric morph; a triangle swaps at the
/// midpoint).
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Whether a key shows its pressed (inverted) artwork now: from the first
/// pressed frame (`tint` snaps to 1 at touch-down and decays on release),
/// or under Reduce Motion for any press (the tint fades in there, so it
/// would arrive a frame late).
bool bauhausInverted(KeyFaceMotion motion, {required bool reduceMotion}) =>
    reduceMotion
    ? effectivePress(motion.press.value, reduceMotion: true) > 0
    : motion.tint.value >= 0.5;

/// One key figure: a rounded rectangle described in units of the key's
/// short side s, or an equilateral triangle.
///
/// The base rectangle is the whole key box at [squareness] 0 and the
/// centred s × s square at 1; it is scaled by [scaleW] × [scaleH] about the
/// key centre, and its corner radii are fractions of s (an `RRect` keeps
/// adjacent radii within each side).
@immutable
final class BauhausFigure {
  const new({
    this.squareness = 0,
    this.scaleW = 1,
    this.scaleH = 1,
    this.topLeft = 0,
    this.topRight = 0,
    this.bottomRight = 0,
    this.bottomLeft = 0,
    this.triangle = false,
    this.offsetY = 0,
    this.labelX = 0,
    this.labelY = 0,
  });

  /// A block: the whole key with corners of [corner] · s.
  const new block(double corner)
    : squareness = 0,
      scaleW = 1,
      scaleH = 1,
      topLeft = corner,
      topRight = corner,
      bottomRight = corner,
      bottomLeft = corner,
      triangle = false,
      offsetY = 0,
      labelX = 0,
      labelY = 0;

  /// A disc of [diameter] · s, centred.
  const new disc(double diameter)
    : squareness = 1,
      scaleW = diameter,
      scaleH = diameter,
      topLeft = diameter / 2,
      topRight = diameter / 2,
      bottomRight = diameter / 2,
      bottomLeft = diameter / 2,
      triangle = false,
      offsetY = 0,
      labelX = 0,
      labelY = 0;

  /// This figure [t] of the way to [b] (t clamped to [0, 1]); a triangle
  /// and a rectangle swap at the midpoint.
  factory lerp(BauhausFigure a, BauhausFigure b, double t) {
    final c = t.clamp(0.0, 1.0);
    if (a == b) return a;
    if (a.triangle != b.triangle) return c < 0.5 ? a : b;
    double n(double x, double y) => x + (y - x) * c;
    return BauhausFigure(
      squareness: n(a.squareness, b.squareness),
      scaleW: n(a.scaleW, b.scaleW),
      scaleH: n(a.scaleH, b.scaleH),
      topLeft: n(a.topLeft, b.topLeft),
      topRight: n(a.topRight, b.topRight),
      bottomRight: n(a.bottomRight, b.bottomRight),
      bottomLeft: n(a.bottomLeft, b.bottomLeft),
      triangle: a.triangle,
      offsetY: n(a.offsetY, b.offsetY),
      labelX: n(a.labelX, b.labelX),
      labelY: n(a.labelY, b.labelY),
    );
  }

  /// Digit discs (composition "disc & block").
  static const BauhausFigure digitDisc = BauhausFigure.disc(0.94);

  /// Operator discs next to block digits.
  static const BauhausFigure operatorDisc = BauhausFigure.disc(0.80);

  /// The big `=` disc.
  static const BauhausFigure equalsDisc = BauhausFigure.disc(0.96);

  /// The `=` fan: a quarter-disc of radius 0.96 s on the bottom-right
  /// corner of the centred square; its label sits 0.05 s right of and below
  /// the key centre, towards the quarter-disc's centroid (clear of the arc,
  /// still inside the pressed core).
  static const BauhausFigure fan = BauhausFigure(
    squareness: 1,
    scaleW: 0.96,
    scaleH: 0.96,
    topLeft: 0.96,
    labelX: 0.05,
    labelY: 0.05,
  );

  /// The `=` triangle: equilateral, side s, pointing up, its centroid (the
  /// incircle centre) 0.10 s below the key centre — apex 0.477 s above and
  /// base 0.389 s below the centre, so it fills the key like the discs
  /// (area 0.433 s²) instead of floating high. Its label sits 0.06 s below
  /// the key centre, near the centroid, where the pressed core is wide
  /// enough for a Bold Text `=` at the heaviest operator weight.
  static const BauhausFigure equalsTriangle = BauhausFigure(
    squareness: 1,
    triangle: true,
    offsetY: 0.10,
    labelY: 0.06,
  );

  /// 0 = the whole key box, 1 = the centred s × s square.
  final double squareness;

  /// Width and height scale of the base rectangle.
  final double scaleW;
  final double scaleH;

  /// Corner radii, fractions of s.
  final double topLeft;
  final double topRight;
  final double bottomRight;
  final double bottomLeft;

  /// An equilateral triangle of side [scaleW] · s instead of a rectangle.
  final bool triangle;

  /// How far the figure's centre (a triangle's centroid) sits below the
  /// key centre, fraction of s.
  final double offsetY;

  /// Where the label sits relative to the key centre, fractions of s
  /// (right, down).
  final double labelX;
  final double labelY;

  /// Whether this is (close to) the whole-key block.
  bool get isBlock => !triangle && squareness < 0.5;

  /// The figure's bounding rectangle in a key box of [size].
  Rect rect(Size size) {
    final s = size.shortestSide;
    final q = squareness.clamp(0.0, 1.0);
    final w = size.width + (s - size.width) * q;
    final h = size.height + (s - size.height) * q;
    final c = size.center(Offset(0, offsetY * s));
    if (triangle) {
      final side = s * scaleW;
      final height = side * math.sqrt(3) / 2;
      return Rect.fromLTRB(
        c.dx - side / 2,
        c.dy - height * 2 / 3,
        c.dx + side / 2,
        c.dy + height / 3,
      );
    }
    return Rect.fromCenter(
      center: c,
      width: math.max(0, w * scaleW),
      height: math.max(0, h * scaleH),
    );
  }

  /// The figure as a rounded rectangle in a key box of [size] (the
  /// triangle's bounding box for [triangle] figures).
  RRect rrect(Size size) {
    final s = size.shortestSide;
    Radius r(double f) => Radius.circular(math.max(0, f) * s);
    return RRect.fromRectAndCorners(
      rect(size),
      topLeft: r(topLeft),
      topRight: r(topRight),
      bottomRight: r(bottomRight),
      bottomLeft: r(bottomLeft),
    ).scaleRadii();
  }

  @override
  bool operator ==(Object other) =>
      other is BauhausFigure &&
      other.squareness == squareness &&
      other.scaleW == scaleW &&
      other.scaleH == scaleH &&
      other.topLeft == topLeft &&
      other.topRight == topRight &&
      other.bottomRight == bottomRight &&
      other.bottomLeft == bottomLeft &&
      other.triangle == triangle &&
      other.offsetY == offsetY &&
      other.labelX == labelX &&
      other.labelY == labelY;

  @override
  int get hashCode => Object.hash(
    squareness,
    scaleW,
    scaleH,
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
    triangle,
    offsetY,
    labelX,
    labelY,
  );

  @override
  String toString() =>
      'BauhausFigure(${triangle ? 'triangle ' : ''}q $squareness, '
      '$scaleW × $scaleH, r $topLeft/$topRight/$bottomRight/$bottomLeft, '
      'dy $offsetY, label ($labelX, $labelY))';
}

/// The width of the resting-colour ring a pressed key keeps, for a key of
/// short side [s]: max(3 dp, 0.08 s), never more than a quarter of s.
double bauhausRingWidth(double s) => math.min(math.max(3, 0.08 * s), s / 4);

/// The radius of the function accent's quarter-disc for a key of short
/// side [s].
double bauhausAccentRadius(double s) => 0.26 * s;

/// How far Jost's maths symbols are lifted, fractions of the font size:
/// Jost centres them on its maths axis, so at `height: 1` they sit 0.04–
/// 0.125 em below the digits (measured in the keypad: digits within 0.02
/// em of the key centre, `− ` 0.125 em low). Any other label is untouched.
const Map<String, double> bauhausGlyphLift = {
  '+': 0.10,
  '−': 0.125,
  '×': 0.10,
  '÷': 0.04,
  '=': 0.11,
};

/// The long-press bar keeps at least this far (fraction of s) below the
/// label's centre: Jost's `=` reaches ≈ 0.11 s below its centre at Bold
/// Text weights before the lift.
const double bauhausHoldBarClearance = 0.13;

/// The thinnest long-press bar drawn, dp (none below it).
const double bauhausMinHoldBar = 1.5;

/// Key roles that carry the function accent (when the theme has one).
const Set<KeyRole> bauhausAccentRoles = {
  KeyRole.backspace,
  KeyRole.clear,
  KeyRole.paren,
  KeyRole.percent,
};

/// Bauhaus key renderer for one theme.
final class BauhausKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const new({
    required this.digitFigure,
    required this.operatorFigure,
    required this.equalsFigure,
    required this.functionFigure,
    required this.accent,
    super.slashedZero,
    this.layoutBase,
  });

  /// Digits, `.`, `±`, `00`.
  final BauhausFigure digitFigure;

  /// `+ − × ÷` and other binary operators.
  final BauhausFigure operatorFigure;

  /// `=`.
  final BauhausFigure equalsFigure;

  /// Every other key (always a block).
  final BauhausFigure functionFigure;

  /// The function accent's colour (fully transparent: none).
  final Color accent;

  /// For an in-between face of a theme morph: the end it is closer to;
  /// null for a theme's own face.
  final BauhausKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  /// The figure of keys with [role].
  BauhausFigure figureFor(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digitFigure,
    KeyRole.operator => operatorFigure,
    KeyRole.equals => equalsFigure,
    _ => functionFigure,
  };

  /// Whether keys with [role] draw the accent.
  bool accentFor(KeyRole role) =>
      accent.a > 0 &&
      bauhausAccentRoles.contains(role) &&
      figureFor(role).isBlock;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as BauhausKeyFace;
    if (other is! BauhausKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as BauhausKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    final near = c < 0.5 ? a : b;
    return BauhausKeyFace(
      digitFigure: BauhausFigure.lerp(a.digitFigure, b.digitFigure, c),
      operatorFigure: BauhausFigure.lerp(a.operatorFigure, b.operatorFigure, c),
      equalsFigure: BauhausFigure.lerp(a.equalsFigure, b.equalsFigure, c),
      functionFigure: BauhausFigure.lerp(a.functionFigure, b.functionFigure, c),
      accent: _lerpAccent(a.accent, b.accent, c),
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Accents fade in and out instead of passing through black.
  static Color _lerpAccent(Color a, Color b, double t) {
    if (a.a == 0 && b.a == 0) return const Color(0x00000000);
    return Color.lerp(
      a.a == 0 ? b.withValues(alpha: 0) : a,
      b.a == 0 ? a.withValues(alpha: 0) : b,
      t,
    )!;
  }

  /// Nothing to build ahead for a lerp: rectangles are computed per size
  /// (and a triangle never lerps).
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// Builds the triangle's paths for [cellSizes] (the only path a Bauhaus
  /// key draws).
  @override
  void prepare(Iterable<Size> cellSizes) {
    for (final figure in [digitFigure, operatorFigure, equalsFigure]) {
      if (!figure.triangle) continue;
      for (final size in cellSizes) {
        if (!size.isEmpty && size.isFinite) BauhausTriangle.of(figure, size);
      }
    }
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      BauhausKeyPainter(motion: motion, spec: spec, face: this);

  /// The label never moves with the press; it swaps to the face colour
  /// while the key is inverted, and sits where the figure puts it
  /// ([BauhausFigure.labelX] / `labelY`).
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) {
    final figure = figureFor(spec.role);
    return BauhausInvertedLabel(
      motion: motion,
      pressedColor: spec.style.fill,
      reduceMotion: spec.reduceMotion,
      shift: Offset(figure.labelX, figure.labelY),
      child: label,
    );
  }

  /// The family label, with Jost's maths symbols lifted onto the digits'
  /// centre line ([bauhausGlyphLift]).
  @override
  Widget label(String text, TextStyle style) {
    final base = super.label(text, style);
    final lift = bauhausGlyphLift[text];
    final size = style.fontSize;
    if (lift == null || size == null) return base;
    return Transform.translate(offset: Offset(0, -lift * size), child: base);
  }

  @override
  bool operator ==(Object other) =>
      other is BauhausKeyFace &&
      other.digitFigure == digitFigure &&
      other.operatorFigure == operatorFigure &&
      other.equalsFigure == equalsFigure &&
      other.functionFigure == functionFigure &&
      other.accent == accent &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    BauhausKeyFace,
    digitFigure,
    operatorFigure,
    equalsFigure,
    functionFigure,
    accent,
    slashedZero,
    layoutBase,
  );
}

/// An equilateral `=` triangle's outer, inverted-core and long-press-bar
/// paths for one key size, cached (a small static LRU: the triangle never
/// lerps, so a theme change never rebuilds it).
///
/// The cache holds only paths (no GPU resources), so it is deliberately not
/// tied to `BackgroundCache.clear()`; it is bounded by [capacity].
final class BauhausTriangle {
  new _(this.outer, this.core, this.coreBounds, this.bar, this.barBounds);

  /// The [figure]'s paths in a key box of [size].
  factory of(BauhausFigure figure, Size size) {
    final key = (figure.scaleW, figure.offsetY, size);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final s = size.shortestSide;
    final side = s * figure.scaleW;
    final height = side * math.sqrt(3) / 2;
    final c = size.center(Offset(0, figure.offsetY * s));
    Path triangle(double k) {
      final half = side * k / 2;
      final h = height * k;
      return Path()
        ..moveTo(c.dx, c.dy - h * 2 / 3)
        ..lineTo(c.dx + half, c.dy + h / 3)
        ..lineTo(c.dx - half, c.dy + h / 3)
        ..close();
    }

    Rect bounds(double k) => Rect.fromLTRB(
      c.dx - side * k / 2,
      c.dy - height * k * 2 / 3,
      c.dx + side * k / 2,
      c.dy + height * k / 3,
    );

    // The core is the triangle inset by the ring width: the same centroid,
    // scaled by (inradius − w) / inradius; the long-press bar keeps half a
    // ring width further in.
    final inradius = height / 3;
    final w = bauhausRingWidth(s);
    double inset(double d) => inradius > d ? (inradius - d) / inradius : 0.0;
    final k = inset(w);
    final kBar = inset(w * 1.5);
    final made = _cache[key] = BauhausTriangle._(
      triangle(1),
      triangle(k),
      bounds(k),
      triangle(kBar),
      bounds(kBar),
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return made;
  }

  static final LinkedHashMap<(double, double, Size), BauhausTriangle> _cache =
      LinkedHashMap();

  /// Sizes kept.
  static const int capacity = 24;

  /// The resting triangle.
  final Path outer;

  /// The inverted core inside the ring.
  final Path core;

  /// The core's bounds.
  final Rect coreBounds;

  /// Where the long-press bar may paint: the core inset by half a ring.
  final Path bar;

  /// [bar]'s bounds.
  final Rect barBounds;
}

/// The geometry of one key at one size.
final class _KeyGeometry {
  new(BauhausFigure figure, Size size, {required bool accent})
    : s = size.shortestSide,
      triangle = figure.triangle ? BauhausTriangle.of(figure, size) : null,
      outer = figure.rrect(size) {
    final w = bauhausRingWidth(s);
    final r = outer.outerRect;
    if (triangle != null) {
      core = null;
      coreClip = null;
      barCore = null;
      barClip = null;
      barBounds = triangle!.barBounds;
    } else {
      final (c, clip) = bauhausCore(outer, w);
      core = c;
      coreClip = clip;
      // The bar keeps half a ring inside the core. Where the core is
      // stretched to the outer edge and clipped (the fan), only the clip's
      // inside counts.
      final bc = c?.deflate(w / 2);
      final bClip = clip?.deflate(w / 2);
      barCore = bc;
      barClip = bClip;
      if (bc == null || bc.width <= 0 || bc.height <= 0) {
        barBounds = Rect.zero;
      } else {
        barBounds = bClip == null
            ? bc.outerRect
            : bc.outerRect.intersect(bClip);
      }
    }
    final ra = bauhausAccentRadius(s);
    accentShape = accent && ra > 0
        ? RRect.fromRectAndCorners(
            Rect.fromLTWH(r.left, r.top, ra, ra),
            topLeft: Radius.circular(math.min(outer.tlRadiusX, ra)),
            bottomRight: Radius.circular(ra),
          )
        : null;
  }

  final double s;
  final BauhausTriangle? triangle;
  final RRect outer;
  late final RRect? core;
  late final Rect? coreClip;

  /// Where the long-press bar may paint (rounded rectangles; the triangle
  /// has its own path): [barCore] clipped by [barClip], within [barBounds].
  late final RRect? barCore;
  late final Rect? barClip;
  late final Rect barBounds;
  late final RRect? accentShape;
}

/// The pressed core of [outer] inset by [w]: its true inner offset (each
/// radius less w, arcs keeping their centres). When an arc is wider than
/// the inset side (the fan's and half-disc's big arcs) the side whose
/// corners are both sharp goes back to the outer edge and the second value
/// is the inset rectangle to clip it by. Null when nothing is left.
(RRect?, Rect?) bauhausCore(RRect outer, double w) {
  final r = outer.outerRect;
  final inset = r.deflate(w);
  if (inset.width <= 0 || inset.height <= 0) return (null, null);
  double inner(double radius) => math.max(0, radius - w);
  final tl = inner(outer.tlRadiusX);
  final tr = inner(outer.trRadiusX);
  final br = inner(outer.brRadiusX);
  final bl = inner(outer.blRadiusX);
  var left = inset.left;
  var top = inset.top;
  var right = inset.right;
  var bottom = inset.bottom;
  var clip = false;
  const eps = 0.01;
  if (tl + tr > inset.width + eps || bl + br > inset.width + eps) {
    if (tr == 0 && br == 0) {
      right = r.right;
      clip = true;
    } else if (tl == 0 && bl == 0) {
      left = r.left;
      clip = true;
    }
  }
  if (tl + bl > inset.height + eps || tr + br > inset.height + eps) {
    if (bl == 0 && br == 0) {
      bottom = r.bottom;
      clip = true;
    } else if (tl == 0 && tr == 0) {
      top = r.top;
      clip = true;
    }
  }
  final core = RRect.fromLTRBAndCorners(
    left,
    top,
    right,
    bottom,
    topLeft: Radius.circular(tl),
    topRight: Radius.circular(tr),
    bottomRight: Radius.circular(br),
    bottomLeft: Radius.circular(bl),
  ).scaleRadii();
  return (core, clip ? inset : null);
}

/// Paints one Bauhaus key: the figure (with the desktop hover layer at
/// rest), its inverted core while pressed, the function accent and the
/// long-press bar. Repaints from the motion channels without rebuilds.
class BauhausKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final BauhausKeyFace face;

  /// One paint for every key (painting is single-threaded; each draw sets
  /// its colour first).
  static final Paint _paint = Paint()..isAntiAlias = true;

  Size? _size;
  _KeyGeometry? _geometry;

  /// This key's figure.
  BauhausFigure get figure => face.figureFor(spec.role);

  /// Whether the key shows its inverted artwork now.
  bool get inverted => bauhausInverted(motion, reduceMotion: spec.reduceMotion);

  _KeyGeometry _geometryFor(Size size) {
    final cached = _geometry;
    if (cached != null && size == _size) return cached;
    _size = size;
    return _geometry = _KeyGeometry(
      figure,
      size,
      accent: face.accentFor(spec.role),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    final g = _geometryFor(size);
    final style = spec.style;
    final on = inverted;
    final paint = _paint;
    paint.color = on
        ? style.fill
        : withStateLayer(
            style.fill,
            style.label,
            (spec.hoverOverlayOpacity * motion.hover.value).clamp(0.0, 1.0),
          );
    final triangle = g.triangle;
    if (triangle != null) {
      canvas.drawPath(triangle.outer, paint);
    } else {
      canvas.drawRRect(g.outer, paint);
    }
    if (on) {
      paint.color = style.label;
      _drawCore(canvas, g, paint);
    }
    final accentShape = g.accentShape;
    if (accentShape != null) {
      paint.color = face.accent;
      canvas.drawRRect(accentShape, paint);
    }
    final hold = motion.holdFill;
    if (on && hold > 0) _paintHold(canvas, size, g, paint, hold);
  }

  void _drawCore(Canvas canvas, _KeyGeometry g, Paint paint) {
    final triangle = g.triangle;
    if (triangle != null) {
      canvas.drawPath(triangle.core, paint);
      return;
    }
    final core = g.core;
    if (core == null) return;
    final clip = g.coreClip;
    if (clip == null) {
      canvas.drawRRect(core, paint);
      return;
    }
    canvas
      ..save()
      ..clipRect(clip)
      ..drawRRect(core, paint)
      ..restore();
  }

  /// The long-press bar: the face colour along the bottom of the inverted
  /// core, half a ring width inside it, growing left to right (fading in
  /// place under Reduce Motion). At most 0.07 s tall and never higher than
  /// [bauhausHoldBarClearance] below the label's centre, so it never
  /// touches the glyph (none when that leaves under [bauhausMinHoldBar]).
  void _paintHold(
    Canvas canvas,
    Size size,
    _KeyGeometry g,
    Paint paint,
    double hold,
  ) {
    final b = g.barBounds;
    if (b.isEmpty) return;
    final labelY = size.height / 2 + figure.labelY * g.s;
    final h = math.min(
      math.min(0.07 * g.s, b.height / 3),
      b.bottom - (labelY + bauhausHoldBarClearance * g.s),
    );
    if (h < bauhausMinHoldBar) return;
    final rm = spec.reduceMotion;
    final f = hold.clamp(0.0, 1.0);
    final bar = Rect.fromLTWH(b.left, b.bottom - h, b.width * (rm ? 1 : f), h);
    paint.color = spec.style.fill.withValues(
      alpha: spec.style.fill.a * (rm ? f : 1),
    );
    canvas.save();
    final triangle = g.triangle;
    if (triangle != null) {
      canvas.clipPath(triangle.bar);
    } else {
      final clip = g.barClip;
      if (clip != null) canvas.clipRect(clip);
      final core = g.barCore;
      if (core != null) canvas.clipRRect(core);
    }
    canvas
      ..drawRect(bar, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(BauhausKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}

/// Recolours a Bauhaus key's label to its face colour while the key is
/// inverted ([bauhausInverted]), by a colour filter that exists only then
/// (the `⌫` icon too), and paints it [shift] · s from where it is laid out
/// (s = this box's short side, the key cell's). A label wider or taller
/// than the cell less the pressed ring (plus 1 dp) is scaled down to fit
/// ([bauhausLabelScale]: `+GST` at Bold Text on 64 dp business keys), so
/// it never touches the ring. The label never moves with the press.
class BauhausInvertedLabel extends SingleChildRenderObjectWidget {
  const new({
    required this.motion,
    required this.pressedColor,
    this.reduceMotion = false,
    this.shift = Offset.zero,
    super.child,
    super.key,
  });

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// The label colour while inverted (the key's face colour).
  final Color pressedColor;

  /// Discrete press (Reduce Motion).
  final bool reduceMotion;

  /// Where the label is painted relative to its layout, fractions of the
  /// box's short side (right, down).
  final Offset shift;

  @override
  RenderBauhausInvertedLabel createRenderObject(BuildContext context) =>
      RenderBauhausInvertedLabel(
        motion: motion,
        pressedColor: pressedColor,
        reduceMotion: reduceMotion,
        shift: shift,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBauhausInvertedLabel renderObject,
  ) {
    renderObject
      ..motion = motion
      ..pressedColor = pressedColor
      ..reduceMotion = reduceMotion
      ..shift = shift;
  }
}

/// How much a label of natural size [labelWidth] × [labelHeight] is scaled
/// in a key cell of [cell]: to fit inside the pressed ring plus 1 dp, never
/// up and never below half size (1 when the cell has no room at all).
double bauhausLabelScale(Size cell, double labelWidth, double labelHeight) {
  final inset = bauhausRingWidth(cell.shortestSide) + 1;
  final w = cell.width - 2 * inset;
  final h = cell.height - 2 * inset;
  if (w <= 0 || h <= 0) return 1;
  var scale = 1.0;
  if (labelWidth > w) scale = w / labelWidth;
  if (labelHeight * scale > h) scale = h / labelHeight;
  return scale.clamp(0.5, 1.0);
}

/// Render object of [BauhausInvertedLabel]: fills its (bounded) cell, lays
/// the child out over it — scaled down when the label would not fit
/// inside the ring ([bauhausLabelScale]) — paints it directly at rest,
/// through a `srcIn` colour filter while inverted, and toggles compositing
/// only when that state flips. The [shift] and the scale apply to
/// painting, hit testing and paint transforms alike.
class RenderBauhausInvertedLabel extends RenderProxyBox {
  new({
    required this._motion,
    required this._pressedColor,
    this._reduceMotion = false,
    this._shift = Offset.zero,
  });

  KeyFaceMotion _motion;
  Color _pressedColor;
  bool _reduceMotion;
  Offset _shift;
  bool _inverted = false;

  /// The key's animation channels.
  KeyFaceMotion get motion => _motion;
  set motion(KeyFaceMotion value) {
    if (identical(value, _motion)) return;
    if (attached) _motion.listenable.removeListener(_changed);
    _motion = value;
    if (attached) _motion.listenable.addListener(_changed);
    _changed();
  }

  /// The label colour while inverted.
  Color get pressedColor => _pressedColor;
  set pressedColor(Color value) {
    if (value == _pressedColor) return;
    _pressedColor = value;
    markNeedsPaint();
  }

  /// Discrete press (Reduce Motion).
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    _changed();
  }

  /// The paint offset, fractions of the box's short side.
  Offset get shift => _shift;
  set shift(Offset value) {
    if (value == _shift) return;
    _shift = value;
    markNeedsPaint();
  }

  /// Whether the label shows the pressed colour now.
  bool get showsInverted => _inverted;

  void _changed() {
    final inverted = bauhausInverted(_motion, reduceMotion: _reduceMotion);
    if (inverted == _inverted) return;
    _inverted = inverted;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _inverted;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.listenable.addListener(_changed);
    _inverted = bauhausInverted(_motion, reduceMotion: _reduceMotion);
  }

  @override
  void detach() {
    _motion.listenable.removeListener(_changed);
    super.detach();
  }

  /// The label's scale (1 unless it had to shrink to fit).
  double get labelScale => _scale;
  double _scale = 1;

  final LayerHandle<TransformLayer> _transform = LayerHandle();

  Offset get _shiftOffset => _shift * size.shortestSide;

  Matrix4 get _childTransform {
    final d = _shiftOffset;
    return Matrix4.translationValues(d.dx, d.dy, 0)
      ..multiply(Matrix4.diagonal3Values(_scale, _scale, 1));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.hasBoundedWidth && constraints.hasBoundedHeight
      ? constraints.biggest
      : super.computeDryLayout(constraints);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight) {
      _scale = 1;
      super.performLayout();
      return;
    }
    size = constraints.biggest;
    _scale = bauhausLabelScale(
      size,
      child.getMaxIntrinsicWidth(double.infinity),
      child.getMaxIntrinsicHeight(double.infinity),
    );
    child.layout(BoxConstraints.tight(size / _scale));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _childTransform,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_childTransform);

  /// Paints the child at [offset], scaled about it by [labelScale].
  void _paintScaled(PaintingContext context, Offset offset) {
    final child = this.child!;
    if (_scale == 1) {
      _transform.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _transform.layer = context.pushTransform(
      needsCompositing,
      offset,
      Matrix4.diagonal3Values(_scale, _scale, 1),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _transform.layer,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final at = offset + _shiftOffset;
    if (!_inverted) {
      layer = null;
      _paintScaled(context, at);
      return;
    }
    layer = context.pushColorFilter(
      at,
      ColorFilter.mode(_pressedColor, BlendMode.srcIn),
      _paintScaled,
      oldLayer: layer is ColorFilterLayer ? layer! as ColorFilterLayer : null,
    );
  }

  @override
  void dispose() {
    _transform.layer = null;
    super.dispose();
  }
}
