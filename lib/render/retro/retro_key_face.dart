/// Retro hardware keycaps (motion brief §2.3 "Retro hardware";
/// docs/m4-design.md §B), drawn in-house.
///
/// Geometry for a key box of w × h and travel d (2–3 dp, seeded):
/// - the **skirt** (the keycap's darker side, the palette `edge`) fills the
///   box below the cap, so at rest a band of height d shows under the face;
/// - the **cap** is the rounded rectangle (0, d·p, w, h − d + d·p): it
///   travels down by d as the key goes in and covers the skirt band;
/// - a soft contact **shadow** under the key shrinks as it travels;
/// - the **bevel**: a highlight band along the cap's top edge and a shade
///   band along its bottom edge. On touch-down they **swap** (discrete, in
///   frame 1 — the key reads as pushed in) and swap back once the release
///   passes p < 0.5. The swap keys on the tint channel, which the press
///   recognizer snaps to 1 in the touch-down frame: hardPress is only at
///   p ≈ 0.5 after one 60 Hz frame (0.2 at 120 Hz), so a p ≥ 0.5 trigger
///   would land a frame or two late.
///
/// No state-layer tint (the swap is the cue); the label rides on the cap.
/// Reduce Motion: the cap sits at its pressed position with the bevel
/// swapped, no frames between.
library;

import 'dart:math' as math;

import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/widgets.dart';

/// Retro keycap renderer for one theme. A same-family theme change lerps
/// travel, corners, skirt tones and bevel strengths ([LerpableKeyFace]).
final class RetroKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const RetroKeyFace({
    required this.travel,
    required this.digitSkirt,
    required this.operatorSkirt,
    required this.equalsSkirt,
    required this.functionSkirt,
    this.cornerFraction = 0.15,
    this.highlight = const Color(0x8CFFFFFF),
    this.shade = const Color(0x47000000),
    this.shadowColor = const Color(0x47000000),
    super.slashedZero,
    this.layoutBase,
  });

  /// Key travel d in dp (the visible skirt band at rest).
  final double travel;

  /// Skirt (side) colour per key group.
  final Color digitSkirt;
  final Color operatorSkirt;
  final Color equalsSkirt;
  final Color functionSkirt;

  /// Cap corner radius as a fraction of its short side (0–0.5).
  final double cornerFraction;

  /// Bevel highlight (translucent white).
  final Color highlight;

  /// Bevel shade (translucent black).
  final Color shade;

  /// Contact shadow under the key.
  final Color shadowColor;

  /// For an in-between face of a theme morph: the end it is closer to.
  final RetroKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  /// The skirt colour for [role].
  Color skirtFor(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digitSkirt,
    KeyRole.operator => operatorSkirt,
    KeyRole.equals => equalsSkirt,
    _ => functionSkirt,
  };

  /// Travel usable in a box of [size] (at most a sixth of the short side).
  double travelFor(Size size) =>
      math.max(0, math.min(travel, size.shortestSide / 6));

  /// The cap rectangle at press [p] in a box of [size]. p may overshoot a
  /// little on the bouncy release (1200/0.7): the cap rises ≤ 0.1 dp.
  Rect capRect(Size size, double p) {
    final d = travelFor(size);
    final y = d * p.clamp(-0.2, 1.0);
    return Rect.fromLTWH(0, y, size.width, size.height - d);
  }

  /// Bevel band thickness for a cap of [size].
  static double bevelFor(Size size) =>
      (size.shortestSide * 0.045).clamp(1.0, 3.5);

  /// Whether the bevel is swapped (pressed artwork) for [press] / [tint]:
  /// from the touch-down frame (tint snapped to 1) until the release
  /// passes p < 0.5; under Reduce Motion whenever the key is down.
  static bool bevelSwapped({
    required double press,
    required double tint,
    bool reduceMotion = false,
  }) {
    if (reduceMotion) return press > 0.01;
    return tint >= 0.999 || press >= 0.5;
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      RetroKeyPainter(motion: motion, spec: spec, face: this);

  /// The label rides on the cap: centred on it at rest, travelling down.
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final d = travelFor(constraints.biggest);
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
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as RetroKeyFace;
    if (other is! RetroKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as RetroKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    Color color(Color x, Color y) => Color.lerp(x, y, c)!;
    final near = c < 0.5 ? a : b;
    return RetroKeyFace(
      travel: math.max(0, a.travel + (b.travel - a.travel) * t),
      digitSkirt: color(a.digitSkirt, b.digitSkirt),
      operatorSkirt: color(a.operatorSkirt, b.operatorSkirt),
      equalsSkirt: color(a.equalsSkirt, b.equalsSkirt),
      functionSkirt: color(a.functionSkirt, b.functionSkirt),
      cornerFraction:
          (a.cornerFraction + (b.cornerFraction - a.cornerFraction) * t).clamp(
            0.0,
            0.5,
          ),
      highlight: color(a.highlight, b.highlight),
      shade: color(a.shade, b.shade),
      shadowColor: color(a.shadowColor, b.shadowColor),
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: keycaps are drawn from rects.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  @override
  bool operator ==(Object other) =>
      other is RetroKeyFace &&
      other.travel == travel &&
      other.digitSkirt == digitSkirt &&
      other.operatorSkirt == operatorSkirt &&
      other.equalsSkirt == equalsSkirt &&
      other.functionSkirt == functionSkirt &&
      other.cornerFraction == cornerFraction &&
      other.highlight == highlight &&
      other.shade == shade &&
      other.shadowColor == shadowColor &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    RetroKeyFace,
    travel,
    digitSkirt,
    operatorSkirt,
    equalsSkirt,
    functionSkirt,
    cornerFraction,
    highlight,
    shade,
    shadowColor,
    slashedZero,
    layoutBase,
  );
}

/// Paints one Retro keycap: contact shadow, skirt, cap with its bevel
/// (swapped while pressed), the desktop hover layer, an optional outline
/// and the long-press bar. Repaints from the motion channels only.
class RetroKeyPainter extends CustomPainter {
  RetroKeyPainter({
    required this.motion,
    required this.spec,
    required this.face,
  }) : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final RetroKeyFace face;

  final Path _clip = Path();

  /// Whether the pressed (swapped) bevel shows now.
  bool get swapped => RetroKeyFace.bevelSwapped(
    press: motion.press.value,
    tint: motion.tint.value,
    reduceMotion: spec.reduceMotion,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    final p = effectivePress(
      motion.press.value,
      reduceMotion: spec.reduceMotion,
    );
    final d = face.travelFor(size);
    final cap = face.capRect(size, p);
    if (cap.width <= 0 || cap.height <= 0) return;
    final r = math.min(cap.width, cap.height) * face.cornerFraction;
    final radius = Radius.circular(r);
    final capShape = RRect.fromRectAndRadius(cap, radius);
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, d, size.width, size.height - d),
      radius,
    );

    // Contact shadow: soft, under the base, shrinking as the key goes in.
    final lift = (1 - p.clamp(0.0, 1.0)) * d;
    if (face.shadowColor.a > 0 && d > 0) {
      canvas.drawRRect(
        base.shift(Offset(0, lift * 0.6 + 0.5)),
        Paint()
          ..color = face.shadowColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.8 + lift * 0.6),
      );
    }
    // Skirt: the keycap's side, visible below the cap.
    canvas.drawRRect(base, Paint()..color = face.skirtFor(spec.role));

    // Cap with its bevel bands.
    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    final down = swapped;
    final topBand = down ? face.shade : face.highlight;
    final bottomBand = down
        ? face.highlight.withValues(alpha: face.highlight.a * 0.6)
        : face.shade;
    final bw = math.min(RetroKeyFace.bevelFor(cap.size), cap.height / 4);
    canvas
      ..save()
      ..clipRRect(capShape)
      ..drawRRect(capShape, Paint()..color = fill)
      ..drawRRect(capShape, Paint()..color = bottomBand)
      ..drawRRect(capShape.shift(Offset(0, -bw)), Paint()..color = fill)
      ..drawRRect(capShape.shift(Offset(0, -bw)), Paint()..color = topBand);
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cap.left + bw * 0.6,
        cap.top + bw,
        cap.right - bw * 0.6,
        cap.bottom - bw,
      ),
      Radius.circular(math.max(0, r - bw * 0.6)),
    );
    canvas
      ..drawRRect(inner, Paint()..color = fill)
      ..restore();

    final outline = style.outline;
    if (outline != null) {
      canvas.drawRRect(
        capShape.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = outline,
      );
    }
    if (motion.holdFill > 0) {
      _clip
        ..reset()
        ..addRRect(capShape);
      paintHoldFill(canvas, cap, motion, spec, clip: _clip);
    }
  }

  @override
  bool shouldRepaint(RetroKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
