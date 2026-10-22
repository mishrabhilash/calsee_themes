/// Material 3 Expressive key faces (motion brief §2.3 row 1).
///
/// - **Press verb:** the outline morphs from its resting shape (full round
///   by default, or a Material shape-library shape) to a rounded rectangle
///   with corners of 30 % of the short side, through a cached [FlatMorph].
///   Scale 0.97 is applied by the key widget (`CalcThemeData.pressScale`).
/// - **Springs:** press-in `effectsFast`; release 800/0.6 drives the scale
///   (it may overshoot), while the corners read the same press clamped to
///   [0, 1], so they never bounce (as Compose's `effectsDefault` corners).
/// - **Frame-1 cue:** the +10 % state layer, snapped on at touch-down by
///   `KeyPressMotion` (the tint channel).
/// - **Reduce Motion:** discrete swap to the pressed outline plus the tint.
library;

import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:calsee_themes/render/shapes.dart';
import 'package:flutter/widgets.dart';

/// M3 Expressive key renderer for one theme.
///
/// Implements [LerpableKeyFace]: a same-family theme change morphs each
/// key's resting outline into the next theme's through a cached
/// [FlatMorph] ([prepareLerp] builds them ahead), following the
/// transition's shape progress — including its rubber-band past 1.
class M3eKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const M3eKeyFace({
    required this.restShape,
    this.operatorShape,
    this.pressedCornerPermille = 300,
    this.rowSquish = false,
    super.slashedZero,
    this.cache,
  });

  /// Resting outline of digit and function keys.
  final KeyGeometry restShape;

  /// Resting outline of operator and `=` keys (a non-colour cue); null =
  /// [restShape].
  final KeyGeometry? operatorShape;

  /// Pressed corner radius (fraction of the short side × 1000; brief: 300).
  final int pressedCornerPermille;

  /// Row-neighbour squish (brief: 10 % of key width, "tune"). Reserved:
  /// off by default and not drawn yet (it needs keypad-level layout).
  final bool rowSquish;

  /// Shape cache (null = [KeyShapeCache.instance]).
  final KeyShapeCache? cache;

  /// The pressed outline (same for every role).
  KeyGeometry get pressedShape =>
      KeyGeometry.roundedRect(pressedCornerPermille);

  /// Resting outline for [role].
  KeyGeometry restFor(KeyRole role) => switch (role) {
    KeyRole.operator || KeyRole.equals => operatorShape ?? restShape,
    _ => restShape,
  };

  KeyShapeCache get _cache => cache ?? KeyShapeCache.instance;

  /// The morph for [role] at [size] (cache lookup; builds on a miss).
  KeyMorph morphFor(KeyRole role, Size size) =>
      _cache.lookup(restFor(role), pressedShape, KeyShapeCache.aspectOf(size));

  /// Resets [path] to [role]'s outline at press progress [t] (clamped, see
  /// [M3eKeyPainter.morphProgress]) in unit-square space.
  void outlineInto(Path path, KeyRole role, Size size, double t) =>
      morphFor(role, size).flat.toPath(t, path);

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    if (other is! M3eKeyFace) return t < 0.5 ? this : other;
    final target = other.layoutFace as M3eKeyFace;
    if (target == this) return this;
    return M3eLerpKeyFace(from: this, to: target, t: t);
  }

  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {
    if (other is! M3eKeyFace) return;
    final target = other.layoutFace as M3eKeyFace;
    for (final size in cellSizes) {
      final aspect = KeyShapeCache.aspectOf(size);
      for (final role in const [KeyRole.digit, KeyRole.operator]) {
        final a = restFor(role);
        final b = target.restFor(role);
        if (a != b) _cache.prepare(a, b, aspect);
      }
    }
  }

  /// Builds every role's morph for keys of each of [cellSizes] ahead of
  /// time (keypad layout and theme prefetch), so no frame ever constructs
  /// a `Morph`.
  @override
  void prepare(Iterable<Size> cellSizes) {
    final shapes = {restShape, ?operatorShape};
    for (final size in cellSizes) {
      for (final shape in shapes) {
        _cache.prepare(shape, pressedShape, KeyShapeCache.aspectOf(size));
      }
    }
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      M3eKeyPainter(motion: motion, spec: spec, face: this);

  @override
  bool operator ==(Object other) =>
      other is M3eKeyFace &&
      other.runtimeType == runtimeType &&
      other.restShape == restShape &&
      other.operatorShape == operatorShape &&
      other.pressedCornerPermille == pressedCornerPermille &&
      other.rowSquish == rowSquish &&
      other.slashedZero == slashedZero &&
      identical(other.cache, cache);

  @override
  int get hashCode => Object.hash(
    M3eKeyFace,
    restShape,
    operatorShape,
    pressedCornerPermille,
    rowSquish,
    slashedZero,
  );
}

/// Paints one M3 Expressive key: the morphing outline filled with the key
/// colour plus the state layer, an optional outline, and the long-press
/// fill. Repaints from the motion channels; reuses one [Path].
class M3eKeyPainter extends CustomPainter {
  M3eKeyPainter({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer (shapes).
  final M3eKeyFace face;

  final Path _path = Path();

  /// Morph progress for press [p]: clamped (corners never bounce), and
  /// discrete under Reduce Motion.
  double morphProgress(double p) =>
      effectivePress(p, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);

  /// The outline at the current press, in cell coordinates (allocates;
  /// for hit tests and the focus ring, not for painting).
  Path outline(Size size) => face
      .morphFor(spec.role, size)
      .pathFor(morphProgress(motion.press.value), size, Path());

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final style = spec.style;
    face.outlineInto(_path, spec.role, size, morphProgress(motion.press.value));

    final unit = size.longestSide;
    final unitRect = Rect.fromLTWH(
      -(size.width - unit) / 2 / unit,
      -(size.height - unit) / 2 / unit,
      size.width / unit,
      size.height / unit,
    );
    canvas.save();
    KeyMorph.applyTransform(canvas, size);
    final fill = withStateLayer(
      style.fill,
      style.label,
      stateLayerOpacity(motion, spec),
    );
    canvas.drawPath(_path, Paint()..color = fill);
    final outline = style.outline;
    if (outline != null) {
      canvas.drawPath(
        _path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 / unit
          ..color = outline,
      );
    }
    paintHoldFill(canvas, unitRect, motion, spec, clip: _path);
    canvas.restore();
  }

  @override
  bool shouldRepaint(M3eKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}

/// An M3 Expressive face part-way through a same-family theme change:
/// resting outlines morph [from] → [to] at [t] (the transition's shape
/// progress; it may pass 1 for the rubber-band). A key pressed during the
/// morph shows the press morph of the nearer theme.
final class M3eLerpKeyFace extends M3eKeyFace {
  M3eLerpKeyFace({required this.from, required this.to, required this.t})
    : super(
        restShape: (t < 0.5 ? from : to).restShape,
        operatorShape: (t < 0.5 ? from : to).operatorShape,
        pressedCornerPermille: (t < 0.5 ? from : to).pressedCornerPermille,
        slashedZero: (t < 0.5 ? from : to).slashedZero,
        cache: (t < 0.5 ? from : to).cache,
      );

  /// The outgoing theme's face.
  final M3eKeyFace from;

  /// The incoming theme's face.
  final M3eKeyFace to;

  /// Shape progress.
  final double t;

  @override
  KeyFaceRenderer get layoutFace => t < 0.5 ? from : to;

  @override
  void outlineInto(Path path, KeyRole role, Size size, double t) {
    final a = from.restFor(role);
    final b = to.restFor(role);
    if (t > 0.001 || a == b) {
      (this.t < 0.5 ? from : to).outlineInto(path, role, size, t);
      return;
    }
    _cache.lookup(a, b, KeyShapeCache.aspectOf(size)).flat.toPath(this.t, path);
  }

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) =>
      (layoutFace as M3eKeyFace).lerpTo(other, t);

  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) =>
      (layoutFace as M3eKeyFace).prepareLerp(other, cellSizes);

  @override
  bool operator ==(Object other) =>
      other is M3eLerpKeyFace &&
      other.from == from &&
      other.to == to &&
      other.t == t;

  @override
  int get hashCode => Object.hash(M3eLerpKeyFace, from, to, t);
}
