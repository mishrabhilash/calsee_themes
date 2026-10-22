/// Neumorphism / Soft UI key faces (motion brief §2.3 row 4;
/// docs/m4-design.md §C; research theme-engine.md §7).
///
/// - **Rest:** the key is the surface colour, lifted by an outer pair of
///   soft shadows — the light one up-left, the dark one down-right — plus
///   a 1–1.5 dp rim (≥ 3:1 against the surface, solved by the engine) on
///   the shadow side that fades out toward the light (bottom and right
///   edges stay solid: the ≥ 3:1 segment is continuous on two sides).
///   Accessible themes draw the rim all round.
/// - **Press:** the outer pair **snaps off in frame 1** (driven by the
///   tint channel, which `KeyPressMotion` snaps to 1 at touch-down), the
///   inner pair grows to 4 dp with the press (`effectsFast`), the key
///   scales to 0.98 (`CalcThemeData.pressScale`), and — so the pressed
///   state changes more than a shadow — the rim closes all round and
///   thickens, surface-faced keys show their label in the accent colour
///   (accent-labelled operators swap to the digit ink), and accent faces
///   take the contrast-safe pressed state layer. Release follows
///   `effectsDefault`; nothing bounces (p is clamped to [0, 1]).
/// - **Reduce Motion:** the discrete pressed artwork (no outer pair, full
///   inner pair, closed rim, swapped label) with no frames between.
///
/// Cost: every blur is a filled rounded rectangle with a `MaskFilter.blur`
/// — the shape Impeller (and Skia) draw analytically, no offscreen pass —
/// and the blurred paints, gradients and geometry are cached per key size
/// in the painter, so a press frame only re-issues a handful of draws
/// with new offsets and alphas. Nothing is rebuilt per frame.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Neumorphism key renderer for one theme. A same-family theme change
/// lerps colours and sizes ([LerpableKeyFace]); the outline kind follows
/// the nearer end.
final class NeumorphicKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const NeumorphicKeyFace({
    required this.surface,
    required this.highlight,
    required this.shadow,
    required this.accent,
    required this.digitLabel,
    this.rimWidth = 1.25,
    this.shadowOffset = 3,
    this.shadowBlur = 6,
    this.innerDepth = 4,
    this.cornerFraction = 0.3,
    this.round = false,
    this.allRoundRim = false,
    super.slashedZero,
    this.layoutBase,
  });

  /// The surface (background, and the face of digit / function keys).
  final Color surface;

  /// Light shadow (up-left outside at rest; down-right inside pressed).
  final Color highlight;

  /// Dark shadow (down-right outside at rest; up-left inside pressed).
  final Color shadow;

  /// Pressed label of surface-faced keys (≥ the label floor on the
  /// surface; `GuardrailRule.softPressedLabel`).
  final Color accent;

  /// Digit ink: the pressed label of accent-labelled operators.
  final Color digitLabel;

  /// Rim stroke width at rest, dp (1–1.5).
  final double rimWidth;

  /// Outer shadow offset, dp (each shadow moves this far on both axes).
  final double shadowOffset;

  /// Outer shadow blur radius, dp (σ = radius / 2).
  final double shadowBlur;

  /// Inner shadow depth at full press, dp (brief: 4).
  final double innerDepth;

  /// Corner radius as a fraction of the short side (0–0.5).
  final double cornerFraction;

  /// Fully round outline (circle / stadium).
  final bool round;

  /// Rim on every side at rest (Accessible lock), not just the shadow side.
  final bool allRoundRim;

  /// For an in-between face of a theme morph: the end it is closer to.
  final NeumorphicKeyFace? layoutBase;

  /// Scale for a key of [size]: small keys (dense scientific layouts) get
  /// proportionally smaller shadows so neighbours do not overlap.
  double scaleFor(Size size) => math.min(1, size.shortestSide / 56);

  /// The face outline for a key box of [size].
  RRect faceFor(Size size) {
    final rect = Offset.zero & size;
    final r = round
        ? size.shortestSide / 2
        : size.shortestSide * cornerFraction.clamp(0.0, 0.5);
    return RRect.fromRectAndRadius(rect, Radius.circular(r));
  }

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as NeumorphicKeyFace;
    if (other is! NeumorphicKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as NeumorphicKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * c;
    Color color(Color x, Color y) => Color.lerp(x, y, c)!;
    final near = c < 0.5 ? a : b;
    return NeumorphicKeyFace(
      surface: color(a.surface, b.surface),
      highlight: color(a.highlight, b.highlight),
      shadow: color(a.shadow, b.shadow),
      accent: color(a.accent, b.accent),
      digitLabel: color(a.digitLabel, b.digitLabel),
      rimWidth: number(a.rimWidth, b.rimWidth),
      shadowOffset: number(a.shadowOffset, b.shadowOffset),
      shadowBlur: number(a.shadowBlur, b.shadowBlur),
      innerDepth: number(a.innerDepth, b.innerDepth),
      cornerFraction: number(a.cornerFraction, b.cornerFraction),
      round: near.round,
      allRoundRim: near.allRoundRim,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: faces are drawn from rounded rectangles.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// The label a pressed key with [style] shows, or null to keep its own:
  /// surface-faced keys take the accent, except accent-labelled operators,
  /// which take the digit ink.
  Color? pressedLabelFor(KeyStyle style) {
    if (style.fill != surface) return null;
    return style.label == accent ? digitLabel : accent;
  }

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      NeumorphicKeyPainter(motion: motion, spec: spec, face: this);

  /// Swaps the label colour while pressed (snapped with the outer shadow
  /// in frame 1; discrete under Reduce Motion), by repainting.
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) {
    final pressed = pressedLabelFor(spec.style);
    if (pressed == null) return label;
    return SoftPressedLabel(
      motion: motion,
      color: pressed,
      reduceMotion: spec.reduceMotion,
      child: label,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NeumorphicKeyFace &&
      other.surface == surface &&
      other.highlight == highlight &&
      other.shadow == shadow &&
      other.accent == accent &&
      other.digitLabel == digitLabel &&
      other.rimWidth == rimWidth &&
      other.shadowOffset == shadowOffset &&
      other.shadowBlur == shadowBlur &&
      other.innerDepth == innerDepth &&
      other.cornerFraction == cornerFraction &&
      other.round == round &&
      other.allRoundRim == allRoundRim &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    NeumorphicKeyFace,
    surface,
    highlight,
    shadow,
    accent,
    digitLabel,
    rimWidth,
    shadowOffset,
    shadowBlur,
    innerDepth,
    cornerFraction,
    round,
    allRoundRim,
    slashedZero,
    layoutBase,
  );
}

/// The press amounts of one frame (all in [0, 1]).
typedef SoftPressState = ({
  /// Outer shadow pair strength (1 at rest, 0 from the first pressed frame).
  double outer,

  /// Inner pair depth fraction (follows the press spring).
  double inner,

  /// Rim closing all round + thickening (snapped with `outer`).
  double close,
});

/// The press amounts for [motion] now: `outer` and `close` follow the
/// tint channel (snapped on at
/// touch-down, eased off on release), the inner pair follows the press;
/// under Reduce Motion everything is the discrete pressed artwork.
SoftPressState softPressState(
  KeyFaceMotion motion, {
  required bool reduceMotion,
}) {
  if (reduceMotion) {
    final on = effectivePress(motion.press.value, reduceMotion: true) > 0;
    return (outer: on ? 0 : 1, inner: on ? 1 : 0, close: on ? 1 : 0);
  }
  final tint = motion.tint.value.clamp(0.0, 1.0);
  return (
    outer: 1 - tint,
    inner: motion.press.value.clamp(0.0, 1.0),
    close: tint,
  );
}

/// Paints one Soft UI key: outer shadow pair, face (hover / accent-face
/// pressed layer), inner shadow pair, rim and long-press fill. Paints,
/// shaders and geometry are cached per size; see the library docs.
class NeumorphicKeyPainter extends CustomPainter {
  NeumorphicKeyPainter({
    required this.motion,
    required this.spec,
    required this.face,
  }) : super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final NeumorphicKeyFace face;

  // Per-size cache (a key keeps its size between frames).
  Size? _cachedSize;
  late RRect _face;
  late double _offset;
  late double _innerMax;
  late Path _facePath;
  final Paint _outerLight = Paint();
  final Paint _outerDark = Paint();
  final Paint _innerLight = Paint();
  final Paint _innerDark = Paint();
  final Paint _innerCover = Paint();
  final Paint _rimSoft = Paint()..style = PaintingStyle.stroke;
  final Paint _rimFull = Paint()..style = PaintingStyle.stroke;
  final Paint _fill = Paint();

  /// How many times the per-size cache was (re)built (tests).
  int debugCacheBuilds = 0;

  void _ensure(Size size) {
    if (_cachedSize == size) return;
    _cachedSize = size;
    debugCacheBuilds++;
    final scale = face.scaleFor(size);
    _face = face.faceFor(size);
    _facePath = Path()..addRRect(_face);
    _offset = face.shadowOffset * scale;
    _innerMax = math.min(face.innerDepth * scale, size.shortestSide / 6);
    final outerSigma = math.max(0.5, face.shadowBlur * scale / 2);
    final innerSigma = math.max(0.5, _innerMax / 2);
    _outerLight.maskFilter = MaskFilter.blur(BlurStyle.normal, outerSigma);
    _outerDark.maskFilter = MaskFilter.blur(BlurStyle.normal, outerSigma);
    _innerDark.maskFilter = MaskFilter.blur(BlurStyle.normal, innerSigma);
    _innerCover.maskFilter = MaskFilter.blur(BlurStyle.normal, innerSigma);
    _rimSoft.shader = _rimShader(size);
  }

  /// The shadow-side rim: transparent at the light corner, solid from the
  /// anti-diagonal through the bottom-left and top-right corners, so the
  /// bottom and right edges are entirely rim colour.
  Shader? _rimShader(Size size) {
    final rim = spec.style.outline;
    if (rim == null) return null;
    final w = size.width;
    final h = size.height;
    final l2 = w * w + h * h;
    if (l2 <= 0) return null;
    // Iso-lines run along the anti-diagonal (direction (w, −h)); the top-
    // left corner is at 0, both other corners at 0.5, bottom-right at 1.
    final c = size.center(Offset.zero);
    final dir = Offset(h, w) * (w * h / l2);
    return ui.Gradient.linear(
      c - dir,
      c + dir,
      [rim.withValues(alpha: 0), rim.withValues(alpha: rim.a * 0.25), rim, rim],
      const [0, 0.36, 0.49, 1],
    );
  }

  /// The press amounts this frame.
  SoftPressState get state =>
      softPressState(motion, reduceMotion: spec.reduceMotion);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _ensure(size);
    final style = spec.style;
    final s = state;

    // 1. Outer shadow pair (snaps off in frame 1).
    if (s.outer > 0.001) {
      _outerLight.color = face.highlight.withValues(
        alpha: face.highlight.a * s.outer,
      );
      _outerDark.color = face.shadow.withValues(alpha: face.shadow.a * s.outer);
      canvas
        ..drawRRect(_face.shift(Offset(-_offset, -_offset)), _outerLight)
        ..drawRRect(_face.shift(Offset(_offset, _offset)), _outerDark);
    }

    // 2. Face: hover layer for every key; accent faces also take the
    // contrast-safe pressed layer (surface faces sink instead).
    final accentFace = style.fill != face.surface;
    final layer = math.max(
      spec.hoverOverlayOpacity * motion.hover.value,
      accentFace ? spec.pressedOverlayOpacity * s.close : 0.0,
    );
    final fill = withStateLayer(style.fill, style.label, layer);
    _fill.color = fill;
    canvas.drawRRect(_face, _fill);

    // 3. Inner pair, growing to innerDepth with the press: inside the
    // face, the highlight; over it the dark shadow shifted up-left (it
    // leaves the bottom and right bands light); over both a blurred cover
    // in the face colour, inset by the depth (it leaves the top and left
    // bands dark). Three analytic rounded-rect draws.
    final depth = _innerMax * s.inner;
    if (depth > 0.05) {
      final a = s.inner.clamp(0.0, 1.0);
      _innerLight.color = Color.alphaBlend(
        face.highlight.withValues(alpha: face.highlight.a * a),
        fill,
      );
      _innerDark.color = face.shadow.withValues(alpha: face.shadow.a * a);
      _innerCover.color = fill;
      canvas
        ..save()
        ..clipRRect(_face)
        ..drawRRect(_face, _innerLight)
        ..drawRRect(_face.shift(Offset(-depth, -depth)), _innerDark)
        ..drawRRect(_face.deflate(depth), _innerCover)
        ..restore();
    }

    // 4. Rim: shadow side at rest; closes all round and thickens pressed.
    final rim = style.outline;
    if (rim != null) {
      final width = face.rimWidth * (1 + 0.5 * s.close);
      final inset = _face.deflate(width / 2);
      final full = face.allRoundRim ? 1.0 : s.close;
      if (full < 1 && _rimSoft.shader != null) {
        _rimSoft.strokeWidth = width;
        canvas.drawRRect(inset, _rimSoft);
      }
      if (full > 0.001) {
        _rimFull
          ..strokeWidth = width
          ..color = rim.withValues(alpha: rim.a * full);
        canvas.drawRRect(inset, _rimFull);
      }
    }

    // 5. Long-press fill.
    if (motion.holdFill > 0) {
      paintHoldFill(canvas, _face.outerRect, motion, spec, clip: _facePath);
    }
  }

  @override
  bool shouldRepaint(NeumorphicKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}

/// Recolours [child] (a key label) to [color] while the key is pressed —
/// from the frame the tint snaps on (discrete under Reduce Motion) — with
/// a `srcIn` colour filter, by repainting only.
class SoftPressedLabel extends SingleChildRenderObjectWidget {
  const SoftPressedLabel({
    required this.motion,
    required this.color,
    this.reduceMotion = false,
    super.child,
    super.key,
  });

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// The pressed label colour.
  final Color color;

  /// Discrete swap.
  final bool reduceMotion;

  @override
  RenderSoftPressedLabel createRenderObject(BuildContext context) =>
      RenderSoftPressedLabel(
        motion: motion,
        color: color,
        reduceMotion: reduceMotion,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSoftPressedLabel renderObject,
  ) {
    renderObject
      ..motion = motion
      ..color = color
      ..reduceMotion = reduceMotion;
  }
}

/// Render object of [SoftPressedLabel].
class RenderSoftPressedLabel extends RenderProxyBox {
  RenderSoftPressedLabel({
    required KeyFaceMotion motion,
    required Color color,
    bool reduceMotion = false,
  }) : _motion = motion,
       _color = color,
       _reduceMotion = reduceMotion;

  KeyFaceMotion _motion;
  Color _color;
  bool _reduceMotion;
  bool _pressed = false;

  /// The key's animation channels.
  KeyFaceMotion get motion => _motion;
  set motion(KeyFaceMotion value) {
    if (identical(value, _motion)) return;
    if (attached) _motion.listenable.removeListener(_changed);
    _motion = value;
    if (attached) _motion.listenable.addListener(_changed);
    _changed();
  }

  /// The pressed label colour.
  Color get color => _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  /// Discrete swap.
  bool get reduceMotion => _reduceMotion;
  set reduceMotion(bool value) {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    _changed();
  }

  /// Whether the pressed colour shows now.
  bool get showsPressed => _pressedNow();

  bool _pressedNow() =>
      softPressState(_motion, reduceMotion: _reduceMotion).close >= 0.5;

  void _changed() {
    final pressed = _pressedNow();
    if (pressed == _pressed) return;
    _pressed = pressed;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _pressed;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.listenable.addListener(_changed);
    _pressed = _pressedNow();
  }

  @override
  void detach() {
    _motion.listenable.removeListener(_changed);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_pressed) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      ColorFilter.mode(_color, BlendMode.srcIn),
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is ColorFilterLayer ? layer! as ColorFilterLayer : null,
    );
  }
}

/// The Neumorphism renderer for [spec] (family `neumorphism`).
NeumorphicKeyFace neumorphicFaceFor(ThemeSpec spec) {
  final p = spec.palette;
  final style = spec.keyStyle;
  return NeumorphicKeyFace(
    surface: Color(p.digit.face),
    highlight: Color(p.highlight),
    shadow: Color(p.shadow),
    accent: Color(p.accent),
    digitLabel: Color(p.digit.label),
    rimWidth: (style.outlineWidthCdp > 0 ? style.outlineWidthCdp : 125) / 100,
    shadowOffset:
        (style.shadowOffsetCdp > 0 ? style.shadowOffsetCdp : 300) / 100,
    shadowBlur: (style.shadowBlurCdp > 0 ? style.shadowBlurCdp : 600) / 100,
    cornerFraction: spec.keyShape.cornerFraction,
    round:
        spec.keyShape.kind == KeyShapeKind.circle ||
        spec.keyShape.kind == KeyShapeKind.pill,
    allRoundRim: spec.accessible,
    slashedZero: spec.type.slashedZero,
  );
}
