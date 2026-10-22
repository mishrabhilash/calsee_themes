/// Liquid Glass key faces (spec §5.3 #2; motion brief §2.3 "Liquid
/// Glass", §6.5–6.6).
///
/// - **Rest:** a translucent tint over the live background (the frost
///   underlay — the background's base colour — diffuses it), a contrast-
///   safe edge thickening (the lens is denser at its rim, always *away*
///   from the label), a specular band and glint across the top, a caustic
///   at the bottom where the light focuses through, a light-catching rim
///   that fades round the key, a chromatic dispersion hairline (the
///   refraction hint) and a soft shadow mostly outside the face.
///   Everything except the tint stays out of the label zone
///   (`glassLabelZoneTop`–`glassLabelZoneBottom`), which the guardrails
///   check on the tint composited over every background hull sample.
/// - **Press:** inflate to s = min(1.08, 1 + (gap − 2 dp)/key) — X = s on
///   the scale channel (release 439/0.65), Y = 1 + 0.75 (s − 1) on the
///   press channel (release 439/0.80): the de-synced axes are the jelly.
///   A radial glow from the touch point snaps its core to 50 % in frame 1
///   (the tint channel snaps to 1 at touch-down) and ramps to 100 % and
///   spreads with the press; it fades on the tint channel on release.
/// - **Reduce Motion:** no inflation (the uniform press scale is undone)
///   and a discrete 50 % glow.
/// - **Reduce Transparency** ([GlassMode.solid]): the opaque solid tint
///   (`KeyStyle.fill`), no lens or dispersion. **Frosted**: ≥ 60 % frost.
/// - **Lite tier:** flat tint and rim, flat glow; no gradient draws.
///
/// Cost: rounded rectangles only (no saveLayer, no BackdropFilter, no
/// per-key shader program); every gradient shader is built once per key
/// size and cached in the painter; the glow is one cached unit radial
/// shader moved with the canvas. A press frame allocates nothing.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/liquid_glass.dart'
    show glassLabelZoneBottom, glassLabelZoneTop;
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/glass/glass_rendering.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One key group's glass colours.
@immutable
final class GlassTint {
  const GlassTint({required this.tint, required this.rim});

  /// [a] → [b] at [t].
  factory GlassTint.lerp(GlassTint a, GlassTint b, double t) => GlassTint(
    tint: Color.lerp(a.tint, b.tint, t)!,
    rim: Color.lerp(a.rim, b.rim, t)!,
  );

  /// The translucent glass tint (`KeyColors.face`).
  final Color tint;

  /// The rim (`KeyColors.edge`): a light catcher, opaque under the
  /// Accessible lock.
  final Color rim;

  @override
  bool operator ==(Object other) =>
      other is GlassTint && other.tint == tint && other.rim == rim;

  @override
  int get hashCode => Object.hash(tint, rim);
}

/// The face and label scale `(x, y)` relative to the uniform press scale
/// `A = 1 + (pressScale − 1) × scale` that `PressScale` already applies:
/// the jelly X = 1 + (s − 1) × scale and Y = 1 + 0.75 (s − 1) × press,
/// with s capped by the key gap ([GlassKeyFace.inflationFor]); under
/// Reduce Motion `(1/A, 1/A)` (no inflation).
(double, double) glassJelly({
  required double press,
  required double scale,
  required double pressScale,
  required double inflation,
  required bool reduceMotion,
}) {
  final a = 1 + (pressScale - 1) * scale;
  if (a <= 0.01) return (1, 1);
  if (reduceMotion) return (1 / a, 1 / a);
  final x = 1 + (inflation - 1) * scale;
  final y = 1 + 0.75 * (inflation - 1) * press;
  return (x / a, y / a);
}

/// Liquid Glass key renderer for one theme. A same-family theme change
/// lerps colours and sizes ([LerpableKeyFace]); the outline kind follows
/// the nearer end.
final class GlassKeyFace extends ThemedKeyFace implements LerpableKeyFace {
  const GlassKeyFace({
    required this.digit,
    required this.operator,
    required this.equals,
    required this.function,
    required this.frostColor,
    required this.glow,
    required this.shadow,
    this.frost = 0.15,
    this.highlight = 0.6,
    this.refraction = 0.5,
    this.shadowOffset = 2.5,
    this.shadowBlur = 8,
    this.rimWidth = 1.25,
    this.solidRim = false,
    this.cornerFraction = 0.5,
    this.round = true,
    this.pressScale = 1.08,
    this.rendering = GlassRendering.standard,
    super.slashedZero,
    this.layoutBase,
  });

  /// Smallest gap between keys the keypad lays out (spec §4.1), dp.
  static const double minGap = 8;

  final GlassTint digit;
  final GlassTint operator;
  final GlassTint equals;
  final GlassTint function;

  /// The frost underlay: the background's base colour (opaque).
  final Color frostColor;

  /// Frost (backdrop diffusion) 0–1.
  final double frost;

  /// The press glow at its peak (`Palette.highlight`).
  final Color glow;

  /// Specular highlight strength 0–1.
  final double highlight;

  /// Refraction hint strength 0–1 (edge lens, caustic, dispersion).
  final double refraction;

  /// Shadow colour, offset and blur radius (dp).
  final Color shadow;
  final double shadowOffset;
  final double shadowBlur;

  /// Rim stroke width, dp; [solidRim] draws it in one opaque colour all
  /// round (Accessible lock).
  final double rimWidth;
  final bool solidRim;

  /// Corner radius as a fraction of the short side; [round] = full round.
  final double cornerFraction;
  final bool round;

  /// The theme's press scale (`CalcThemeData.pressScale`, the token's
  /// 1.08): the inflation ceiling.
  final double pressScale;

  /// Glass mode and effects tier this face was resolved for.
  final GlassRendering rendering;

  /// For an in-between face of a theme morph: the end it is closer to.
  final GlassKeyFace? layoutBase;

  /// The colours of keys with [role].
  GlassTint tintFor(KeyRole role) => switch (role) {
    KeyRole.digit || KeyRole.decimal || KeyRole.sign => digit,
    KeyRole.operator => operator,
    KeyRole.equals => equals,
    _ => function,
  };

  /// The inflation of a key of [size]: min(pressScale, 1 + (gap − 2)/key)
  /// (motion brief §2.3: 1.075 for an 80 dp key with 8 dp gaps).
  double inflationFor(Size size) {
    final short = size.shortestSide;
    if (short <= 0) return 1;
    return math.max(1, math.min(pressScale, 1 + (minGap - 2) / short));
  }

  /// The face outline for a key box of [size].
  RRect faceFor(Size size) {
    final r = round
        ? size.shortestSide / 2
        : size.shortestSide * cornerFraction.clamp(0.0, 0.5);
    return RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
  }

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as GlassKeyFace;
    if (other is! GlassKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as GlassKeyFace;
    if (a == b) return a;
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * c;
    Color color(Color x, Color y) => Color.lerp(x, y, c)!;
    final near = c < 0.5 ? a : b;
    return GlassKeyFace(
      digit: GlassTint.lerp(a.digit, b.digit, c),
      operator: GlassTint.lerp(a.operator, b.operator, c),
      equals: GlassTint.lerp(a.equals, b.equals, c),
      function: GlassTint.lerp(a.function, b.function, c),
      frostColor: color(a.frostColor, b.frostColor),
      glow: color(a.glow, b.glow),
      shadow: color(a.shadow, b.shadow),
      frost: number(a.frost, b.frost),
      highlight: number(a.highlight, b.highlight),
      refraction: number(a.refraction, b.refraction),
      shadowOffset: number(a.shadowOffset, b.shadowOffset),
      shadowBlur: number(a.shadowBlur, b.shadowBlur),
      rimWidth: number(a.rimWidth, b.rimWidth),
      solidRim: near.solidRim,
      cornerFraction: number(a.cornerFraction, b.cornerFraction),
      round: near.round,
      pressScale: number(a.pressScale, b.pressScale),
      rendering: near.rendering,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  /// Nothing to build ahead: faces are rounded rectangles.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      GlassKeyPainter(motion: motion, spec: spec, face: this);

  /// The label inflates with the face (the jelly), by repainting.
  @override
  Widget labelLayer(KeyFaceMotion motion, KeyFaceSpec spec, Widget label) =>
      GlassInflate(
        motion: motion,
        face: this,
        reduceMotion: spec.reduceMotion,
        child: label,
      );

  @override
  bool operator ==(Object other) =>
      other is GlassKeyFace &&
      other.digit == digit &&
      other.operator == operator &&
      other.equals == equals &&
      other.function == function &&
      other.frostColor == frostColor &&
      other.frost == frost &&
      other.glow == glow &&
      other.highlight == highlight &&
      other.refraction == refraction &&
      other.shadow == shadow &&
      other.shadowOffset == shadowOffset &&
      other.shadowBlur == shadowBlur &&
      other.rimWidth == rimWidth &&
      other.solidRim == solidRim &&
      other.cornerFraction == cornerFraction &&
      other.round == round &&
      other.pressScale == pressScale &&
      other.rendering == rendering &&
      other.slashedZero == slashedZero &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hashAll([
    GlassKeyFace,
    digit,
    operator,
    equals,
    function,
    frostColor,
    frost,
    glow,
    highlight,
    refraction,
    shadow,
    shadowOffset,
    shadowBlur,
    rimWidth,
    solidRim,
    cornerFraction,
    round,
    pressScale,
    rendering,
    slashedZero,
    layoutBase,
  ]);
}

/// Paints one Liquid Glass key (see the library docs).
class GlassKeyPainter extends CustomPainter {
  GlassKeyPainter({
    required this.motion,
    required this.spec,
    required this.face,
  }) : super(repaint: motion.listenable);

  final KeyFaceMotion motion;
  final KeyFaceSpec spec;
  final GlassKeyFace face;

  static const Color _cool = Color(0xFF8AEBFF);
  static const Color _warm = Color(0xFFFFC07A);

  // Per-size caches (rebuilt only when the key's size changes).
  Size? _size;
  late RRect _rrect;
  late RRect _shadowOuter;
  late Path _clip;
  late Rect _band;
  late Rect _glint;
  late Rect _caustic;
  final Paint _fill = Paint();
  final Paint _tintPaint = Paint();
  final Paint _edgePaint = Paint();
  final Paint _bandPaint = Paint();
  final Paint _glintPaint = Paint();
  final Paint _causticPaint = Paint();
  final Paint _rimPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _hairline = Paint()..style = PaintingStyle.stroke;
  final Paint _shadowPaint = Paint();
  Paint? _glowPaint;

  /// The press glow alpha now: the core snaps to 50 % with the tint in
  /// frame 1, then ramps to 100 % with the press (discrete 50 % under
  /// Reduce Motion), and fades out with the tint.
  double get glowAlpha {
    final tint = motion.tint.value.clamp(0.0, 1.0);
    if (tint <= 0) return 0;
    final p = motion.press.value.clamp(0.0, 1.0);
    final ramp = spec.reduceMotion ? 0.5 : 0.5 + 0.5 * p;
    return face.glow.a * tint * ramp;
  }

  /// The glow centre for a key of [size]: the touch point (clamped inside
  /// the face), or the centre.
  Offset glowCenter(Size size) {
    final m = motion;
    final f = m is KeyFaceMotionDetail ? m.touchFraction : null;
    if (f == null) return size.center(Offset.zero);
    return Offset(
      size.width * f.dx.clamp(0.15, 0.85),
      size.height * f.dy.clamp(0.15, 0.85),
    );
  }

  /// The current `(x, y)` face scale relative to the press transform.
  (double, double) jellyFor(Size size) {
    final m = motion;
    final p = motion.press.value;
    final k = m is KeyFaceMotionDetail ? m.scale.value : p;
    return glassJelly(
      press: p,
      scale: k,
      pressScale: face.pressScale,
      inflation: face.inflationFor(size),
      reduceMotion: spec.reduceMotion,
    );
  }

  void _ensure(Size size) {
    if (_size == size) return;
    _size = size;
    final w = size.width;
    final h = size.height;
    _rrect = face.faceFor(size);
    _clip = Path()..addRRect(_rrect);
    _shadowOuter = RRect.fromRectAndRadius(
      Rect.fromLTRB(-0.5, 0, w + 0.5, h + face.shadowOffset),
      _rrect.tlRadius,
    );
    _shadowPaint
      ..color = face.shadow
      ..maskFilter = face.shadowBlur > 0
          ? MaskFilter.blur(BlurStyle.normal, face.shadowBlur / 2)
          : null;
    final g = face.tintFor(spec.role);
    final tint = g.tint;
    // Thickness: brighter at the top, a touch denser at the bottom; the
    // label zone is exactly the tint.
    final top = Color.alphaBlend(
      const Color(0xFFFFFFFF).withValues(alpha: 0.10 * face.highlight),
      tint,
    );
    final bottom = tint.withValues(alpha: math.min(1, tint.a + 0.06));
    _tintPaint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, h),
      [top, tint, tint, bottom],
      const [0, glassLabelZoneTop, glassLabelZoneBottom, 1],
    );
    // Lens: denser glass at the rim, away from the label's polarity.
    final away = stateLayerColor(spec.style.fill, spec.style.label);
    final edgeAlpha =
        (away == const Color(0xFF000000) ? 0.26 : 0.42) * face.refraction;
    final longest = math.max(w, h);
    final c = size.center(Offset.zero);
    final matrix = Float64List(16)
      ..[0] = w >= h ? 1 : w / h
      ..[5] = w >= h ? h / w : 1
      ..[10] = 1
      ..[12] = w >= h ? 0 : c.dx * (1 - w / h)
      ..[13] = w >= h ? c.dy * (1 - h / w) : 0
      ..[15] = 1;
    _edgePaint.shader = ui.Gradient.radial(
      c,
      longest / 2 * 1.02,
      [away.withValues(alpha: 0), away.withValues(alpha: edgeAlpha)],
      const [0.66, 1],
      TileMode.clamp,
      matrix,
    );
    // Specular band (top of the face, above the label zone) and glint.
    _band = Rect.fromLTWH(0, 0, w, h * glassLabelZoneTop);
    _bandPaint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, h * glassLabelZoneTop),
      [
        const Color(0xFFFFFFFF).withValues(alpha: 0.30 * face.highlight),
        const Color(0x00FFFFFF),
      ],
    );
    _glint = Rect.fromCenter(
      center: Offset(w * 0.34, h * 0.13),
      width: w * 0.40,
      height: h * 0.12,
    );
    _glintPaint.shader = ui.Gradient.radial(
      _glint.center,
      _glint.width / 2,
      [
        const Color(0xFFFFFFFF).withValues(alpha: 0.55 * face.highlight),
        const Color(0x00FFFFFF),
      ],
      null,
      TileMode.clamp,
      Float64List(16)
        ..[0] = 1
        ..[5] = _glint.height / _glint.width
        ..[10] = 1
        ..[13] = _glint.center.dy * (1 - _glint.height / _glint.width)
        ..[15] = 1,
    );
    // Caustic: light focused through the glass at the bottom edge.
    _caustic = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.97),
      width: w * 0.74,
      height: h * 0.26,
    );
    final light = away == const Color(0xFFFFFFFF);
    _causticPaint.shader = ui.Gradient.radial(
      _caustic.center,
      _caustic.width / 2,
      [
        const Color(
          0xFFFFFFFF,
        ).withValues(alpha: (light ? 0.42 : 0.24) * face.refraction),
        const Color(0x00FFFFFF),
      ],
      null,
      TileMode.clamp,
      Float64List(16)
        ..[0] = 1
        ..[5] = _caustic.height / _caustic.width
        ..[10] = 1
        ..[13] = _caustic.center.dy * (1 - _caustic.height / _caustic.width)
        ..[15] = 1,
    );
    // Rim: bright top-left, faint at the sides, half-bright bottom-right.
    final rim = g.rim;
    _rimPaint
      ..strokeWidth = face.rimWidth
      ..shader = face.solidRim || !face.rendering.gradients
          ? null
          : ui.Gradient.linear(
              Offset.zero,
              Offset(w, h),
              [
                rim,
                rim.withValues(alpha: rim.a * 0.16),
                rim.withValues(alpha: rim.a * 0.62),
              ],
              const [0, 0.5, 1],
            )
      ..color = rim;
    _hairline.strokeWidth = 0.8;
  }

  Paint get _glow => _glowPaint ??= Paint()
    ..shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [
        face.glow.withValues(alpha: 1),
        face.glow.withValues(alpha: 0.45),
        face.glow.withValues(alpha: 0),
      ],
      const [0, 0.45, 1],
    );

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _ensure(size);
    final rendering = face.rendering;
    final mode = rendering.mode;
    final full = rendering.gradients;
    final g = face.tintFor(spec.role);
    final (sx, sy) = jellyFor(size);
    final c = size.center(Offset.zero);
    canvas.save();
    if (sx != 1 || sy != 1) {
      canvas
        ..translate(c.dx, c.dy)
        ..scale(sx, sy)
        ..translate(-c.dx, -c.dy);
    }
    final rrect = _rrect;

    if (full && face.shadowBlur > 0 && face.shadow.a > 0) {
      canvas.drawDRRect(_shadowOuter, rrect, _shadowPaint);
    }
    if (mode == GlassMode.solid) {
      _fill
        ..shader = null
        ..color = spec.style.fill.withValues(alpha: 1);
      canvas.drawRRect(rrect, _fill);
    } else {
      final frost = mode == GlassMode.frosted
          ? math.max(face.frost, 0.6)
          : face.frost;
      if (frost > 0) {
        _fill
          ..shader = null
          ..color = face.frostColor.withValues(alpha: frost.clamp(0.0, 1.0));
        canvas.drawRRect(rrect, _fill);
      }
      if (full) {
        canvas.drawRRect(rrect, _tintPaint);
      } else {
        _fill.color = g.tint;
        canvas.drawRRect(rrect, _fill);
      }
    }

    if (full) {
      if (mode != GlassMode.solid && face.refraction > 0) {
        canvas.drawRRect(rrect, _edgePaint);
      }
      if (face.highlight > 0 || face.refraction > 0) {
        canvas
          ..save()
          ..clipRRect(rrect);
        if (face.highlight > 0) {
          canvas
            ..drawRect(_band, _bandPaint)
            ..drawOval(_glint, _glintPaint);
        }
        if (mode == GlassMode.glass && face.refraction > 0) {
          canvas.drawOval(_caustic, _causticPaint);
        }
        canvas.restore();
      }
    }

    // Hover: the contrast-safe state layer.
    final hover = spec.hoverOverlayOpacity * motion.hover.value;
    if (hover > 0) {
      _fill
        ..shader = null
        ..color = stateLayerColor(
          spec.style.fill,
          spec.style.label,
        ).withValues(alpha: hover.clamp(0.0, 1.0));
      canvas.drawRRect(rrect, _fill);
    }

    // The press glow from the touch point.
    final glow = glowAlpha;
    if (glow > 0) {
      if (!full) {
        _fill
          ..shader = null
          ..color = face.glow.withValues(alpha: glow * 0.6);
        canvas.drawRRect(rrect, _fill);
      } else {
        final p = motion.press.value.clamp(0.0, 1.0);
        final radius =
            math.max(size.width, size.height) *
            (spec.reduceMotion ? 0.9 : 0.55 + 0.5 * p);
        final center = glowCenter(size);
        canvas
          ..save()
          ..clipRRect(rrect)
          ..translate(center.dx, center.dy)
          ..scale(radius)
          ..drawCircle(
            Offset.zero,
            1,
            _glow..color = Color.fromRGBO(0, 0, 0, glow.clamp(0.0, 1.0)),
          )
          ..restore();
      }
    }

    // Rim and the dispersion hairlines (the refraction hint).
    if (face.rimWidth > 0 && g.rim.a > 0) {
      canvas.drawRRect(rrect.deflate(face.rimWidth / 2), _rimPaint);
    }
    if (full && mode == GlassMode.glass && face.refraction > 0.05) {
      final inset = face.rimWidth + 0.9;
      final edge = rrect.deflate(inset);
      canvas
        ..save()
        ..clipRRect(rrect)
        ..drawRRect(
          edge.shift(const Offset(-0.6, -0.6)),
          _hairline..color = _cool.withValues(alpha: 0.30 * face.refraction),
        )
        ..drawRRect(
          edge.shift(const Offset(0.6, 0.6)),
          _hairline..color = _warm.withValues(alpha: 0.24 * face.refraction),
        )
        ..restore();
    }

    paintHoldFill(canvas, Offset.zero & size, motion, spec, clip: _clip);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}

/// Inflates its child (the key label) with the glass jelly
/// ([glassJelly]) by repainting on the press and scale channels.
class GlassInflate extends SingleChildRenderObjectWidget {
  const GlassInflate({
    required this.motion,
    required this.face,
    this.reduceMotion = false,
    super.child,
    super.key,
  });

  final KeyFaceMotion motion;
  final GlassKeyFace face;
  final bool reduceMotion;

  @override
  RenderGlassInflate createRenderObject(BuildContext context) =>
      RenderGlassInflate(
        motion: motion,
        face: face,
        reduceMotion: reduceMotion,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassInflate renderObject,
  ) {
    renderObject
      ..motion = motion
      ..face = face
      ..reduceMotion = reduceMotion;
  }
}

/// Render object of [GlassInflate].
class RenderGlassInflate extends RenderProxyBox {
  RenderGlassInflate({
    required KeyFaceMotion motion,
    required GlassKeyFace face,
    required bool reduceMotion,
  }) : _motion = motion,
       _face = face,
       _reduceMotion = reduceMotion;

  KeyFaceMotion _motion;
  GlassKeyFace _face;
  bool _reduceMotion;

  Listenable get _channels {
    final m = _motion;
    return m is KeyFaceMotionDetail
        ? Listenable.merge([m.press, m.scale])
        : m.press;
  }

  Listenable? _listening;

  KeyFaceMotion get motion => _motion;
  set motion(KeyFaceMotion value) {
    if (identical(value, _motion)) return;
    _unlisten();
    _motion = value;
    if (attached) _listen();
    markNeedsPaint();
  }

  GlassKeyFace get face => _face;
  set face(GlassKeyFace value) {
    if (value == _face) return;
    _face = value;
    markNeedsPaint();
  }

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

  /// The label's `(x, y)` scale now.
  (double, double) get currentScale {
    final m = _motion;
    final p = m.press.value;
    return glassJelly(
      press: p,
      scale: m is KeyFaceMotionDetail ? m.scale.value : p,
      pressScale: _face.pressScale,
      inflation: _face.inflationFor(size),
      reduceMotion: _reduceMotion,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final (sx, sy) = currentScale;
    if (sx == 1 && sy == 1) {
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    final c = size.center(Offset.zero);
    final transform = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(sx, sy, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }
}
