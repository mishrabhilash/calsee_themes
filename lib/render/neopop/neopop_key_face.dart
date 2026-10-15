/// NeoPOP key faces (motion brief §2.3 row 3; CRED look), drawn in-house
/// (no `neopop` package).
///
/// Geometry for a key box of w × h and depth d (3–5 dp, seeded):
/// - the **base** B = (d, d, w, h) is where the face sits when pressed;
/// - the **face** F = (d·p, d·p, w − d + d·p, h − d + d·p) at press p;
/// - the **extrusion** is the sweep of F to B: F ∪ B ∪ the quad between
///   their tangent points along (1, 1). It is filled with the bottom tone,
///   and the part right of the diagonal through F's bottom-right corner
///   with the side tone (two darker tones of the face).
///
/// Press: the face translates (+d, +d) and the edges collapse with it; no
/// tint. p is clamped to [0, 1] (the face never sinks below its base);
/// Reduce Motion shows the seated face with no frames between.
library;

import 'dart:math' as math;

import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/widgets.dart';

/// The two extruded-edge tones of one key group.
@immutable
final class NeoPopEdges {
  const new({required this.side, required this.bottom});

  /// Right side.
  final Color side;

  /// Bottom side (and the base footprint).
  final Color bottom;

  @override
  bool operator ==(Object other) =>
      other is NeoPopEdges && other.side == side && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(side, bottom);
}

/// Face outline kinds NeoPOP draws (anything else draws as a rounded
/// rectangle).
enum NeoPopShape {
  /// Rounded rectangle with a corner fraction.
  roundedRect,

  /// Full round (circle in a square box, stadium otherwise).
  round,
}

/// NeoPOP key renderer for one theme. A same-family theme change lerps
/// depth, corners, edge tones and shadow ([LerpableKeyFace]).
final class NeoPopKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const new({
    required this.depth,
    required this.digitEdges,
    required this.operatorEdges,
    required this.equalsEdges,
    required this.functionEdges,
    this.cornerFraction = 0,
    this.shape = NeoPopShape.roundedRect,
    this.operatorShape,
    this.shadowOffset = 0,
    this.shadowColor = const Color(0x00000000),
    super.slashedZero,
    this.layoutBase,
  });

  /// Extrusion depth d in dp (the face travel when pressed).
  final double depth;

  /// Edge tones per group.
  final NeoPopEdges digitEdges;
  final NeoPopEdges operatorEdges;
  final NeoPopEdges equalsEdges;
  final NeoPopEdges functionEdges;

  /// Corner radius as a fraction of the face's short side (0–0.5).
  final double cornerFraction;

  /// Face outline of digit and function keys.
  final NeoPopShape shape;

  /// Face outline of operator and `=` keys (non-colour cue); null =
  /// [shape].
  final NeoPopShape? operatorShape;

  /// Static hard shadow offset beyond the base, dp (0 = none).
  final double shadowOffset;

  /// Hard shadow colour.
  final Color shadowColor;

  /// For an in-between face of a theme morph: the end it is closer to
  /// (its label placement); null for a theme's own face.
  final NeoPopKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as NeoPopKeyFace;
    if (other is! NeoPopKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as NeoPopKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * t;
    Color color(Color x, Color y) => Color.lerp(x, y, c)!;
    NeoPopEdges edges(NeoPopEdges x, NeoPopEdges y) => NeoPopEdges(
      side: color(x.side, y.side),
      bottom: color(x.bottom, y.bottom),
    );
    final near = c < 0.5 ? a : b;
    return NeoPopKeyFace(
      depth: math.max(0, number(a.depth, b.depth)),
      digitEdges: edges(a.digitEdges, b.digitEdges),
      operatorEdges: edges(a.operatorEdges, b.operatorEdges),
      equalsEdges: edges(a.equalsEdges, b.equalsEdges),
      functionEdges: edges(a.functionEdges, b.functionEdges),
      cornerFraction: number(a.cornerFraction, b.cornerFraction).clamp(0, 0.5),
      shape: near.shape,
      operatorShape: near.operatorShape,
      shadowOffset: math.max(0, number(a.shadowOffset, b.shadowOffset)),
      shadowColor: color(a.shadowColor, b.shadowColor),
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: NeoPOP faces are drawn from rects.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// Edge tones for [role].
  NeoPopEdges edgesFor(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digitEdges,
    KeyRole.operator => operatorEdges,
    KeyRole.equals => equalsEdges,
    _ => functionEdges,
  };

  /// Face outline for [role].
  NeoPopShape shapeFor(KeyRole role) => switch (role) {
    KeyRole.operator || KeyRole.equals => operatorShape ?? shape,
    _ => shape,
  };

  /// The usable depth for a key box of [size] (never more than a quarter
  /// of the short side, so tiny keys keep a face).
  double depthFor(Size size) =>
      math.max(0, math.min(depth, size.shortestSide / 4));

  /// The face rectangle at press [p] (clamped) in a box of [size].
  Rect faceRect(Size size, double p) {
    final d = depthFor(size);
    final t = d * p.clamp(0.0, 1.0);
    return Rect.fromLTWH(t, t, size.width - d, size.height - d);
  }

  /// The base rectangle (the face's pressed position).
  Rect baseRect(Size size) {
    final d = depthFor(size);
    return Rect.fromLTWH(d, d, size.width - d, size.height - d);
  }

  /// The face's corner radius for [role] in a box of [size].
  double radiusFor(KeyRole role, Size size) {
    final d = depthFor(size);
    final short = math.max(0, math.min(size.width - d, size.height - d));
    return switch (shapeFor(role)) {
      NeoPopShape.round => short / 2,
      NeoPopShape.roundedRect => short * cornerFraction.clamp(0.0, 0.5),
    };
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      NeoPopKeyPainter(motion: motion, spec: spec, face: this);

  /// The label rides on the face: centred on F at rest, moving (+d, +d).
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final d = depthFor(constraints.biggest);
          return PressTranslate(
            press: motion.press,
            rest: Offset(-d / 2, -d / 2),
            travel: Offset(d, d),
            reduceMotion: spec.reduceMotion,
            child: label,
          );
        },
      );

  @override
  bool operator ==(Object other) =>
      other is NeoPopKeyFace &&
      other.depth == depth &&
      other.digitEdges == digitEdges &&
      other.operatorEdges == operatorEdges &&
      other.equalsEdges == equalsEdges &&
      other.functionEdges == functionEdges &&
      other.cornerFraction == cornerFraction &&
      other.shape == shape &&
      other.operatorShape == operatorShape &&
      other.shadowOffset == shadowOffset &&
      other.shadowColor == shadowColor &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    NeoPopKeyFace,
    depth,
    digitEdges,
    operatorEdges,
    equalsEdges,
    functionEdges,
    cornerFraction,
    shape,
    operatorShape,
    shadowOffset,
    shadowColor,
    slashedZero,
    layoutBase,
  );
}

/// Paints one NeoPOP key: hard shadow, the two-tone extrusion between the
/// face and its base, the flat face (with the desktop hover layer only;
/// NeoPOP has no pressed tint), an optional outline and the long-press
/// fill. Repaints from the motion channels without rebuilds.
class NeoPopKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final NeoPopKeyFace face;

  final Path _quad = Path();
  final Path _clip = Path();
  final Path _faceClip = Path();

  /// Press depth used for geometry: clamped to [0, 1], discrete under
  /// Reduce Motion.
  double pressFor(double p) =>
      effectivePress(p, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    final p = pressFor(motion.press.value);
    final f = face.faceRect(size, p);
    final b = face.baseRect(size);
    if (f.width <= 0 || f.height <= 0) return;
    final r = face.radiusFor(spec.role, size);
    final faceShape = RRect.fromRectAndRadius(f, Radius.circular(r));
    final baseShape = RRect.fromRectAndRadius(b, Radius.circular(r));

    if (face.shadowOffset > 0 && face.shadowColor.a > 0) {
      canvas.drawRRect(
        baseShape.shift(Offset(face.shadowOffset, face.shadowOffset)),
        Paint()..color = face.shadowColor,
      );
    }

    final travel = b.topLeft - f.topLeft;
    if (travel.dx > 0.01) {
      final edges = face.edgesFor(spec.role);
      // Tangent points of the corner arcs along n = (1, −1)/√2.
      const k = math.sqrt1_2;
      final t1 = Offset(f.right - r + r * k, f.top + r - r * k);
      final t2 = Offset(f.left + r - r * k, f.bottom - r + r * k);
      _quad
        ..reset()
        ..moveTo(t1.dx, t1.dy)
        ..lineTo(t1.dx + travel.dx, t1.dy + travel.dy)
        ..lineTo(t2.dx + travel.dx, t2.dy + travel.dy)
        ..lineTo(t2.dx, t2.dy)
        ..close();
      void sweep(Color color) {
        final paint = Paint()..color = color;
        canvas
          ..drawRRect(baseShape, paint)
          ..drawPath(_quad, paint);
      }

      sweep(edges.bottom);
      // Side tone: the half-plane right of the diagonal through F's
      // bottom-right corner (direction (1, 1)).
      final c = Offset(f.right - r + r * k, f.bottom - r + r * k);
      final reach = (size.width + size.height) * 2;
      _clip
        ..reset()
        ..moveTo(c.dx - reach, c.dy - reach)
        ..lineTo(c.dx + reach, c.dy - reach)
        ..lineTo(c.dx + reach, c.dy + reach)
        ..close();
      canvas
        ..save()
        ..clipPath(_clip);
      sweep(edges.side);
      canvas.restore();
    }

    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    canvas.drawRRect(faceShape, Paint()..color = fill);
    final outline = style.outline;
    if (outline != null) {
      canvas.drawRRect(
        faceShape.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = outline,
      );
    }
    if (motion.holdFill > 0) {
      _faceClip
        ..reset()
        ..addRRect(faceShape);
      paintHoldFill(canvas, f, motion, spec, clip: _faceClip);
    }
  }

  @override
  bool shouldRepaint(NeoPopKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
