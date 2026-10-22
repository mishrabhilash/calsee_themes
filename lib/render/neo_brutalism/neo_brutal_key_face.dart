/// Neo-brutalism key faces (spec §5.3 #6; motion brief §2.3
/// "Neo-brutalism"): a flat face with a thick ink outline sitting on an
/// offset hard shadow — CSS `box-shadow: s s 0 ink`, Duolingo's lip.
///
/// Geometry for a key box of w × h and shadow offset s (3–5 dp, seeded):
/// - the **shadow** S = (s, s, w − s, h − s) never moves;
/// - the **face** F = (s·p, s·p, w − s, h − s) at press p, outlined
///   inside its edge (2–4 dp);
/// - at p = 1 the face covers its shadow exactly: the shadow is gone.
///
/// Press: the face translates (+s, +s) into the shadow on `hardPress`; no
/// tint (only the desktop hover layer). The frame-1 cue is that geometry:
/// hardPress puts the face ≈ 0.2 s (120 Hz) – 0.5 s (60 Hz) down in the
/// first frame, i.e. 0.8–2 dp of shadow gone at the default 4 dp. p is
/// clamped to [0, 1]; Reduce Motion shows the seated face with no frames
/// in between (the discrete pressed artwork).
library;

import 'dart:math' as math;

import 'package:calsee_themes/render/fonts.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/widgets.dart';

/// Neo-brutalism key renderer for one theme. A same-family theme change
/// lerps the shadow offset, outline width, corners and ink
/// ([LerpableKeyFace]).
final class NeoBrutalKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const NeoBrutalKeyFace({
    required this.shadowOffset,
    required this.outlineWidth,
    required this.ink,
    this.cornerFraction = 0.1,
    this.widthPermille = 1000,
    super.slashedZero,
    this.layoutBase,
  });

  /// Hard-shadow offset s in dp (also the face travel when pressed).
  final double shadowOffset;

  /// Outline stroke width in dp.
  final double outlineWidth;

  /// Hard-shadow colour (and the outline when a key style has none).
  final Color ink;

  /// Corner radius as a fraction of the face's short side (0–0.5).
  final double cornerFraction;

  /// `wdth` axis of the label font × 10 (fonts that have one), for labels
  /// of one or two characters.
  final int widthPermille;

  /// For an in-between face of a theme morph: the end it is closer to
  /// (its label placement); null for a theme's own face.
  final NeoBrutalKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as NeoBrutalKeyFace;
    if (other is! NeoBrutalKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as NeoBrutalKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * t;
    final near = c < 0.5 ? a : b;
    return NeoBrutalKeyFace(
      shadowOffset: math.max(0, number(a.shadowOffset, b.shadowOffset)),
      outlineWidth: math.max(0, number(a.outlineWidth, b.outlineWidth)),
      ink: Color.lerp(a.ink, b.ink, c)!,
      cornerFraction: number(a.cornerFraction, b.cornerFraction).clamp(0, 0.5),
      widthPermille: near.widthPermille,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: faces are drawn from rects.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// The usable shadow offset for a key box of [size] (never more than a
  /// quarter of the short side, so tiny keys keep a face).
  double shadowFor(Size size) =>
      math.max(0, math.min(shadowOffset, size.shortestSide / 4));

  /// The usable outline width (never more than a sixth of the face).
  double outlineFor(Size size) {
    final s = shadowFor(size);
    final short = math.max(0, math.min(size.width - s, size.height - s));
    return math.max(0, math.min(outlineWidth, short / 6));
  }

  /// The face rectangle at press [p] (clamped) in a box of [size].
  Rect faceRect(Size size, double p) {
    final s = shadowFor(size);
    final t = s * p.clamp(0.0, 1.0);
    return Rect.fromLTWH(t, t, size.width - s, size.height - s);
  }

  /// The shadow rectangle (the face's pressed position).
  Rect shadowRect(Size size) {
    final s = shadowFor(size);
    return Rect.fromLTWH(s, s, size.width - s, size.height - s);
  }

  /// The face's corner radius in a box of [size].
  double radiusFor(Size size) {
    final s = shadowFor(size);
    final short = math.max(0, math.min(size.width - s, size.height - s));
    return short * cornerFraction.clamp(0.0, 0.5);
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      NeoBrutalKeyPainter(motion: motion, spec: spec, face: this);

  /// Labels of one or two characters use the theme's width axis (a wide,
  /// chunky cut); longer ones keep the normal width so they fit.
  @override
  Widget label(String text, TextStyle style) {
    final font = BundledFont.fromFamily(style.fontFamily);
    if (!font.isBundled) return super.label(text, style);
    final weight = (style.fontWeight ?? FontWeight.w400).value.toDouble();
    final wide = text.runes.length <= 2 ? widthPermille / 10 : 100.0;
    return KeyLabel(
      text,
      style: style.copyWith(
        fontVariations: font.variations(
          weight: weight,
          width: wide,
          fontSize: style.fontSize,
        ),
        fontFeatures: font.features(slashedZero: slashedZero),
      ),
    );
  }

  /// The label rides on the face: centred on F at rest, moving (+s, +s).
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final s = shadowFor(constraints.biggest);
          return PressTranslate(
            press: motion.press,
            rest: Offset(-s / 2, -s / 2),
            travel: Offset(s, s),
            reduceMotion: spec.reduceMotion,
            child: label,
          );
        },
      );

  @override
  bool operator ==(Object other) =>
      other is NeoBrutalKeyFace &&
      other.shadowOffset == shadowOffset &&
      other.outlineWidth == outlineWidth &&
      other.ink == ink &&
      other.cornerFraction == cornerFraction &&
      other.widthPermille == widthPermille &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    NeoBrutalKeyFace,
    shadowOffset,
    outlineWidth,
    ink,
    cornerFraction,
    widthPermille,
    slashedZero,
    layoutBase,
  );
}

/// Paints one Neo-brutalism key: the hard shadow (what the face has not
/// yet covered), the flat face (with the desktop hover layer only; no
/// pressed tint), its ink outline and the long-press fill. Repaints from
/// the motion channels without rebuilds.
class NeoBrutalKeyPainter extends CustomPainter {
  NeoBrutalKeyPainter({
    required this.motion,
    required this.spec,
    required this.face,
  }) : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final NeoBrutalKeyFace face;

  final Path _faceClip = Path();

  /// Press depth used for geometry: clamped to [0, 1], discrete under
  /// Reduce Motion.
  double pressFor(double p) =>
      effectivePress(p, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);

  /// The outline colour of this key: its style's outline, else the ink.
  Color get outlineColor => spec.style.outline ?? face.ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    final p = pressFor(motion.press.value);
    final f = face.faceRect(size, p);
    if (f.width <= 0 || f.height <= 0) return;
    final r = Radius.circular(face.radiusFor(size));
    final faceShape = RRect.fromRectAndRadius(f, r);

    // The shadow: gone once the face sits in it (no anti-aliased fringe).
    if (p < 1 && face.ink.a > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(face.shadowRect(size), r),
        Paint()..color = face.ink,
      );
    }

    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    canvas.drawRRect(faceShape, Paint()..color = fill);
    final w = face.outlineFor(size);
    if (w > 0) {
      canvas.drawRRect(
        faceShape.deflate(w / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..color = outlineColor,
      );
    }
    if (motion.holdFill > 0) {
      _faceClip
        ..reset()
        ..addRRect(faceShape.deflate(w));
      paintHoldFill(canvas, f.deflate(w), motion, spec, clip: _faceClip);
    }
  }

  @override
  bool shouldRepaint(NeoBrutalKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
