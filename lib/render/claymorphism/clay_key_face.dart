/// Claymorphism key faces (spec §5.3 #7; motion brief §2.3
/// "Claymorphism"): big puffy squircles of opaque, matte plasticine.
///
/// - **Rest:** three stacked depth cues on the opaque face: a soft drop
///   shadow tinted from the key's own hue (`KeyColors.edge`, 4–6 dp down,
///   blurred), an inner white highlight along the top-left edge and an
///   inner darker shade ([clayInnerShade]) along the bottom-right edge.
///   No outline, no light outer shadow (that is Neumorphism).
/// - **Label zone:** inside [ClayKeyFace.labelZone] (the face deflated by
///   0.20 of the rest short side) the only colour is the face with its
///   contrast-safe state layer — exactly what the guardrails check. The
///   highlight, the cover's ramp and the shade all end at 0.20 s.
/// - **Press:** a bottom-anchored squash (X 1.04 / Y 0.92, top drop capped
///   at 10 dp) that undoes `PressScale`'s uniform scale; from frame 1 (the
///   tint snaps to 1) the drop shadow cross-fades to a 40 % smaller,
///   closer one, the highlight dims to 65 % and the 6 % state layer snaps
///   on. The 322/0.65 release rebounds tall-and-thin (Y gain 0.25, X 0.12
///   for negative press).
/// - **Reduce Motion:** no squash and no size change; the shadow pair
///   cross-fades with the tint, the shade band widens discretely.
/// - **Lite tier:** no mask filters at all — the drop shadow in two crisp
///   steps (35 % at 0.6 × the offset over 20 % at the full offset: a
///   stepped falloff, not a hard offset block) and unblurred bands ("flat
///   clay").
/// - **Clipping:** the drop shadow reaches about dy + 3σ below the cell
///   (up to ≈ 27 dp: 6 dp depth, σ 7 dp) and ≈ 15–20 dp to its sides.
///   `Keypad`'s `Stack` keeps its default `Clip.hardEdge`, so on narrow
///   layouts, where the keypad's margin is smaller than that, the outer
///   keys' shadows (the bottom row's, and the side columns' outer edges)
///   are cut flat at the keypad edge. That is accepted: `Clip.none` on the
///   keypad Stack was refused, and the label, face and inner cues are
///   never affected.
///
/// Cost: at rest 4 draws (5 on the lite tier), 3 analytic blurs on filled
/// rounded rectangles (none on the lite tier) and one clip per key; no
/// saveLayer, no BackdropFilter; the paints and mask filters are shared
/// ([ClayPaintCache]) and the derived colours are cached per painter, so
/// nothing but the painter is allocated per frame.
library;

import 'dart:collection';
import 'dart:math' as math;

import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shared paints and blur filters of every clay painter (paint runs on
/// the UI thread only, so one set serves every key).
abstract final class ClayPaintCache {
  /// Drop shadows.
  static final Paint drop = Paint();

  /// The face base (the shade colour).
  static final Paint face = Paint();

  /// The inner highlight.
  static final Paint highlight = Paint();

  /// The cover (the face colour over the bands).
  static final Paint cover = Paint();

  /// Mask filters kept.
  static const int capacity = 32;

  static final LinkedHashMap<int, MaskFilter> _filters = LinkedHashMap();

  /// Blur filters built (tests).
  static int builds = 0;

  /// A normal blur of [sigma] (rounded to 0.25, at least 0.5), from a
  /// small LRU.
  static MaskFilter blur(double sigma) {
    final key = math.max(2, (sigma * 4).round());
    final hit = _filters.remove(key);
    if (hit != null) return _filters[key] = hit;
    builds++;
    final filter = _filters[key] = MaskFilter.blur(BlurStyle.normal, key / 4);
    while (_filters.length > capacity) {
      _filters.remove(_filters.keys.first);
    }
    return filter;
  }
}

/// Claymorphism key renderer for one theme. A same-family theme change
/// lerps shadows, highlight and sizes ([LerpableKeyFace]); the tier and
/// the label placement follow the nearer end.
final class ClayKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const ClayKeyFace({
    required this.digitShadow,
    required this.operatorShadow,
    required this.equalsShadow,
    required this.functionShadow,
    required this.highlight,
    this.depth = 5,
    this.blur = 12,
    this.shadeDepth = 0.09,
    this.cornerFraction = 0.36,
    this.pressScale = 0.92,
    this.labelFloor = ratioText,
    this.lite = false,
    super.slashedZero,
    this.layoutBase,
  });

  /// Drop shadow of digit keys (`KeyColors.edge`).
  final Color digitShadow;

  /// Drop shadow of operator keys.
  final Color operatorShadow;

  /// Drop shadow of the `=` key.
  final Color equalsShadow;

  /// Drop shadow of function keys.
  final Color functionShadow;

  /// The inner highlight (`Palette.highlight`: white at 0xA0–0xC8; the
  /// painted alpha follows [clayHighlightAlphaFor]).
  final Color highlight;

  /// Drop-shadow offset at rest, dp (= the motion depth).
  final double depth;

  /// Drop-shadow blur radius at rest, dp (σ = radius / 2).
  final double blur;

  /// Inner shade depth (OKLab L, 0.08–0.11).
  final double shadeDepth;

  /// Corner radius as a fraction of the short side (0–0.5).
  final double cornerFraction;

  /// The uniform press scale `PressScale` applies (the painter undoes it
  /// and squashes instead).
  final double pressScale;

  /// The label floor (4.5, 7 under the Accessible lock): a function key's
  /// shade never pulls its label below it on in-between frames.
  final double labelFloor;

  /// Lite effects tier: no blurs.
  final bool lite;

  /// Lite tier: the near crisp drop-shadow step (0.6 × the offset), as a
  /// fraction of the shadow's alpha.
  static const double liteNearShadow = 0.35;

  /// Lite tier: the far crisp drop-shadow step (the full offset).
  static const double liteFarShadow = 0.20;

  /// For an in-between face of a theme morph: the end it is closer to.
  final ClayKeyFace? layoutBase;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  /// The drop shadow of keys with [role].
  Color shadowFor(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digitShadow,
    KeyRole.operator => operatorShadow,
    KeyRole.equals => equalsShadow,
    _ => functionShadow,
  };

  /// The face's `(x, y)` squash at press [press] and press scale [scale]
  /// for a key [height] dp tall: bottom-anchored Y `max(0.92, 1 − a·p)`
  /// with `a = min(0.08, 10 / height)` (the top never drops more than
  /// 10 dp), X `1 + 0.04 k`; on the release overshoot (negative press) a
  /// visible tall-and-thin rebound (Y gain 0.25, X 0.12). `(1, 1)` under
  /// Reduce Motion.
  static (double, double) squash({
    required double press,
    required double scale,
    required double height,
    required bool reduceMotion,
  }) {
    if (reduceMotion) return (1, 1);
    final a = height > 0 ? math.min(0.08, 10 / height) : 0.08;
    // The floor holds the 10 dp cap through the press-in overshoot too.
    final floor = height > 0 ? math.max(0.92, 1 - 10 / height) : 0.92;
    final sy = press >= 0 ? math.max(floor, 1 - a * press) : 1 - 0.25 * press;
    final sx = scale >= 0 ? 1 + 0.04 * scale : 1 + 0.12 * scale;
    return (sx.clamp(0.92, 1.08), sy.clamp(0.92, 1.08));
  }

  /// The face rectangle in a key box of [size] for a squash of
  /// ([sx], [sy]): centred horizontally, bottom-anchored.
  static Rect faceRect(Size size, double sx, double sy) {
    final cx = size.width / 2;
    final fw = size.width * sx;
    return Rect.fromLTRB(
      cx - fw / 2,
      size.height - size.height * sy,
      cx + fw / 2,
      size.height,
    );
  }

  /// The face outline for [face] in a key box whose rest short side is
  /// [shortSide].
  RRect shapeFor(Rect face, double shortSide) => RRect.fromRectAndRadius(
    face,
    Radius.circular(
      math.max(
        0,
        math.min(
          cornerFraction.clamp(0.0, 0.5) * shortSide,
          0.5 * math.min(face.width, face.height),
        ),
      ),
    ),
  );

  /// Where the label sits on [shape] (rest short side [shortSide]): the
  /// face deflated by [clayLabelZoneInset] × short side. Only the face
  /// colour is painted inside it.
  static RRect labelZone(RRect shape, double shortSide) {
    final inset = clayLabelZoneInset * shortSide;
    final rect = shape.outerRect.deflate(inset);
    if (rect.width <= 0 || rect.height <= 0) {
      return RRect.fromRectAndRadius(
        Rect.fromCenter(center: shape.center, width: 0, height: 0),
        Radius.zero,
      );
    }
    return RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.max(0, shape.tlRadiusX - inset)),
    );
  }

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as ClayKeyFace;
    if (other is! ClayKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as ClayKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * t;
    Color color(Color x, Color y) => Color.lerp(x, y, c)!;
    final near = c < 0.5 ? a : b;
    return ClayKeyFace(
      digitShadow: color(a.digitShadow, b.digitShadow),
      operatorShadow: color(a.operatorShadow, b.operatorShadow),
      equalsShadow: color(a.equalsShadow, b.equalsShadow),
      functionShadow: color(a.functionShadow, b.functionShadow),
      highlight: color(a.highlight, b.highlight),
      depth: math.max(0, number(a.depth, b.depth)),
      blur: math.max(0, number(a.blur, b.blur)),
      shadeDepth: number(a.shadeDepth, b.shadeDepth).clamp(0.0, 0.2),
      cornerFraction: number(a.cornerFraction, b.cornerFraction).clamp(0, 0.5),
      pressScale: number(a.pressScale, b.pressScale).clamp(0.5, 1.5),
      labelFloor: math.max(a.labelFloor, b.labelFloor),
      lite: near.lite,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: faces are drawn from rounded rectangles.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      ClayKeyPainter(motion: motion, spec: spec, face: this);

  /// The label squashes with the face (and undoes the uniform press
  /// scale), by repainting only.
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      ClaySquash(
        motion: motion,
        face: this,
        reduceMotion: spec.reduceMotion,
        child: label,
      );

  @override
  bool operator ==(Object other) =>
      other is ClayKeyFace &&
      other.digitShadow == digitShadow &&
      other.operatorShadow == operatorShadow &&
      other.equalsShadow == equalsShadow &&
      other.functionShadow == functionShadow &&
      other.highlight == highlight &&
      other.depth == depth &&
      other.blur == blur &&
      other.shadeDepth == shadeDepth &&
      other.cornerFraction == cornerFraction &&
      other.pressScale == pressScale &&
      other.labelFloor == labelFloor &&
      other.lite == lite &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    ClayKeyFace,
    digitShadow,
    operatorShadow,
    equalsShadow,
    functionShadow,
    highlight,
    depth,
    blur,
    shadeDepth,
    cornerFraction,
    pressScale,
    labelFloor,
    lite,
    slashedZero,
    layoutBase,
  );
}

/// Paints one clay key: the drop shadow (cross-fading to its pressed
/// state with the tint), the face in its shade colour, the inner
/// highlight and the cover clipped to the face, and the long-press fill.
/// Repaints from the motion channels without rebuilds.
class ClayKeyPainter extends CustomPainter {
  ClayKeyPainter({required this.motion, required this.spec, required this.face})
    : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final ClayKeyFace face;

  Path? _clip;

  Color? _fill;
  Color? _label;
  Color _shade = const Color(0xFF000000);
  int _highlightAlpha = 0;

  /// Blurred draws in the last [paint] (tests: 0 on the lite tier).
  int debugBlurCount = 0;

  /// The inner shade actually painted for this key's fill (a function
  /// key's shade is reduced, never below 0.03, while its label would fall
  /// under the label floor on it — only on in-between frames).
  Color get shadeColor {
    _ensureColours(spec.style.fill, spec.style.label);
    return _shade;
  }

  void _ensureColours(Color fill, Color label) {
    if (fill == _fill && label == _label) return;
    _fill = fill;
    _label = label;
    final fillArgb = fill.toARGB32();
    var depth = (face.shadeDepth * 1000).round();
    var shade = clayInnerShade(fillArgb, depth);
    final role = spec.role;
    final functionKey = switch (role) {
      KeyRole.digit ||
      KeyRole.decimal ||
      KeyRole.sign ||
      KeyRole.operator ||
      KeyRole.equals => false,
      _ => true,
    };
    if (functionKey) {
      final labelArgb = label.toARGB32();
      while (depth > 30 && contrastRatio(labelArgb, shade) < face.labelFloor) {
        depth -= 10;
        shade = clayInnerShade(fillArgb, depth);
      }
    }
    _shade = Color(shade);
    _highlightAlpha = clayHighlightAlphaFor(
      fillArgb,
      face.highlight.toARGB32(),
    );
  }

  void _blurred(Paint paint, double sigma) {
    if (face.lite) {
      paint.maskFilter = null;
    } else {
      paint.maskFilter = ClayPaintCache.blur(sigma);
      debugBlurCount++;
    }
  }

  /// One drop shadow of [shape] at [weight] of the shadow's alpha: blurred
  /// (σ [sigma]) on [inset]-deflated rounded rectangle [dy] below the face;
  /// on the lite tier two crisp steps of the whole shape instead —
  /// [ClayKeyFace.liteNearShadow] at 0.6 · [dy] over
  /// [ClayKeyFace.liteFarShadow] at [dy] — a stepped falloff with no blur,
  /// never one hard offset block.
  void _dropShadow(
    Canvas canvas,
    RRect shape,
    Color shadow,
    double weight,
    double inset,
    double dy,
    double sigma,
  ) {
    final drop = ClayPaintCache.drop;
    if (face.lite) {
      drop
        ..maskFilter = null
        ..color = shadow.withValues(
          alpha: shadow.a * weight * ClayKeyFace.liteFarShadow,
        );
      canvas.drawRRect(shape.shift(Offset(0, dy)), drop);
      drop.color = shadow.withValues(
        alpha: shadow.a * weight * ClayKeyFace.liteNearShadow,
      );
      canvas.drawRRect(shape.shift(Offset(0, 0.6 * dy)), drop);
      return;
    }
    drop.color = shadow.withValues(alpha: shadow.a * weight);
    _blurred(drop, sigma);
    canvas.drawRRect(shape.deflate(inset).shift(Offset(0, dy)), drop);
  }

  @override
  void paint(Canvas canvas, Size size) {
    debugBlurCount = 0;
    if (size.isEmpty) return;
    final style = spec.style;
    final m = motion;
    final p = m.press.value;
    final k = m is KeyFaceMotionDetail ? m.scale.value : p;
    final t = m.tint.value.clamp(0.0, 1.0);
    final rm = spec.reduceMotion;
    final pe = effectivePress(p, reduceMotion: rm).clamp(0.0, 1.0);
    final s = size.shortestSide;
    final g = (s / 64).clamp(0.5, 1.0);
    final a = 1 + (face.pressScale - 1) * k;
    final (sx, sy) = ClayKeyFace.squash(
      press: p,
      scale: k,
      height: size.height,
      reduceMotion: rm,
    );
    final f = ClayKeyFace.faceRect(size, sx, sy);
    if (f.width <= 0 || f.height <= 0) return;
    final shape = face.shapeFor(f, s);
    _ensureColours(style.fill, style.label);

    final c = size.center(Offset.zero);
    canvas.save();
    if (a > 0.01 && a != 1) {
      canvas
        ..translate(c.dx, c.dy)
        ..scale(1 / a)
        ..translate(-c.dx, -c.dy);
    }

    // 1–2. The drop shadow: rest and pressed states cross-fade with the
    // tint (frame 1: only the 40 % smaller, closer one).
    final shadow = face.shadowFor(spec.role);
    if (shadow.a > 0) {
      final dy = face.depth * g;
      final restSigma = math.max(0.5, face.blur / 2 * g);
      final pressedSigma = math.max(
        0.5,
        restSigma * clayPressedShadowPermille / 1000,
      );
      if (1 - t > 0.01) {
        _dropShadow(canvas, shape, shadow, 1 - t, 0.03 * s, dy, restSigma);
      }
      if (t > 0.01) {
        _dropShadow(
          canvas,
          shape,
          shadow,
          t,
          0.06 * s,
          dy * clayPressedShadowPermille / 1000,
          pressedSigma,
        );
      }
    }

    // 3. The face base in the shade colour (the anti-aliased silhouette).
    final opacity = stateLayerOpacity(m, spec);
    final fill = withStateLayer(style.fill, style.label, opacity);
    final shade = withStateLayer(_shade, style.label, opacity);
    final base = ClayPaintCache.face
      ..color = shade
      ..maskFilter = null;
    canvas
      ..drawRRect(shape, base)
      // 4. Bands clipped to the face (an anti-aliased clip, not a layer).
      ..save()
      ..clipRRect(shape);

    // 5. The inner highlight, shifted up-left: the bottom-right band keeps
    // the shade.
    final o = (0.10 + 0.03 * pe) * s;
    final hiAlpha = _highlightAlpha / 255 * (1 - 0.35 * t);
    final lit = Color.alphaBlend(
      face.highlight.withValues(alpha: hiAlpha.clamp(0.0, 1.0)),
      fill,
    );
    final hi = ClayPaintCache.highlight..color = lit;
    _blurred(hi, math.max(0.5, 0.040 * s));
    canvas.drawRRect(shape.shift(Offset(-o, -o)), hi);

    // 6. The cover: the exact face colour from 0.06 s inward (opaque from
    // 0.20 s, the label zone).
    final cover = ClayPaintCache.cover..color = fill;
    _blurred(cover, math.max(0.5, 0.035 * s));
    canvas
      ..drawRRect(shape.deflate(0.060 * s), cover)
      ..restore();

    // 8. The long-press fill (≤ the 6 % state layer, away from the label).
    if (m.holdFill > 0) {
      final clip = (_clip ??= Path())
        ..reset()
        ..addRRect(shape);
      paintHoldFill(canvas, f, m, spec, clip: clip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ClayKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}

/// Paints [child] (the key label) squashed with the clay face: the
/// inverse of `PressScale`'s uniform scale about the centre, then the
/// bottom-anchored squash ([ClayKeyFace.squash]); only the inverse under
/// Reduce Motion. Repaints on the press and scale channels.
class ClaySquash extends SingleChildRenderObjectWidget {
  const ClaySquash({
    required this.motion,
    required this.face,
    this.reduceMotion = false,
    super.child,
    super.key,
  });

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// The theme's renderer (its press scale).
  final ClayKeyFace face;

  /// No squash (the inverse scale only).
  final bool reduceMotion;

  @override
  RenderClaySquash createRenderObject(BuildContext context) =>
      RenderClaySquash(motion: motion, face: face, reduceMotion: reduceMotion);

  @override
  void updateRenderObject(BuildContext context, RenderClaySquash renderObject) {
    renderObject
      ..motion = motion
      ..face = face
      ..reduceMotion = reduceMotion;
  }
}

/// Render object of [ClaySquash].
class RenderClaySquash extends RenderProxyBox {
  RenderClaySquash({
    required KeyFaceMotion motion,
    required ClayKeyFace face,
    required bool reduceMotion,
  }) : _motion = motion,
       _face = face,
       _reduceMotion = reduceMotion;

  KeyFaceMotion _motion;
  ClayKeyFace _face;
  bool _reduceMotion;
  Listenable? _listening;

  Listenable get _channels {
    final m = _motion;
    return m is KeyFaceMotionDetail
        ? Listenable.merge([m.press, m.scale])
        : m.press;
  }

  /// The key's animation channels.
  KeyFaceMotion get motion => _motion;
  set motion(KeyFaceMotion value) {
    if (identical(value, _motion)) return;
    _unlisten();
    _motion = value;
    if (attached) _listen();
    markNeedsPaint();
  }

  /// The theme's renderer.
  ClayKeyFace get face => _face;
  set face(ClayKeyFace value) {
    if (value == _face) return;
    _face = value;
    markNeedsPaint();
  }

  /// No squash.
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    markNeedsPaint();
  }

  void _listen() => (_listening = _channels).addListener(markNeedsPaint);

  void _unlisten() {
    _listening?.removeListener(markNeedsPaint);
    _listening = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  /// The label's paint transform now (identity at rest).
  Matrix4 get currentTransform {
    final m = _motion;
    final p = m.press.value;
    final k = m is KeyFaceMotionDetail ? m.scale.value : p;
    final a = 1 + (_face.pressScale - 1) * k;
    final (sx, sy) = ClayKeyFace.squash(
      press: p,
      scale: k,
      height: size.height,
      reduceMotion: _reduceMotion,
    );
    final c = size.center(Offset.zero);
    final transform = Matrix4.identity();
    if (a > 0.01 && a != 1) {
      transform
        ..translateByDouble(c.dx, c.dy, 0, 1)
        ..scaleByDouble(1 / a, 1 / a, 1, 1)
        ..translateByDouble(-c.dx, -c.dy, 0, 1);
    }
    if (sx != 1 || sy != 1) {
      transform
        ..translateByDouble(c.dx, size.height, 0, 1)
        ..scaleByDouble(sx, sy, 1, 1)
        ..translateByDouble(-c.dx, -size.height, 0, 1);
    }
    return transform;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final transform = currentTransform;
    if (transform.isIdentity()) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }
}
