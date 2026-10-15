/// Y2K / Frutiger Aero key faces (spec §5.3 #10; motion brief §2.3
/// "Y2K / chrome"): opaque gel orbs (AERO, [Y2kAeroKeyFace]) or satin-metal
/// chiclets in a chrome bezel (CHROME, [Y2kChromeKeyFace]) with a hard white
/// specular cap.
///
/// - **Rest:** the face fills its cell. Its body is a vertical profile
///   derived from the opaque face colour (`y2kGelProfile`: a lighter tone
///   under the cap, the deep tone right where the cap ends, the face, a
///   brighter bottom; or `y2kMetalProfile`: a sky reflection, a dark
///   horizon line, the face, a dark band and a warm ground) with a static
///   brushed-streak tile on metal. On top: a soft edge shade (gel), a
///   caustic glow at the bottom, the specular cap over the top 42 %
///   (30 % on metal), the rim (AERO: the darker `KeyColors.edge`) or the
///   light–dark–light chrome bezel (CHROME), a catch-light along the top
///   edge (fading out down the sides), and a soft drop shadow (a deep one on dark scenes, so the keys
///   read as solid gel, not a glow). The shadow stays within a few dp of
///   the key; on narrow layouts the keypad's hard-edge clip can trim it at
///   the keypad's outer edge.
/// - **Frame-1 cue** (the tint channel snaps to 1 at touch-down): the body
///   swaps to the pressed face (`y2kPressedFace`: hue +20°, or an accent
///   tint on near-neutral faces), the cap flares and slides toward the
///   finger, the caustic brightens × 1.8, the bezel tints turn +20°.
/// - **Release:** a specular band sweeps the face once, left to right,
///   while the tint fades (never under Reduce Motion or on the lite tier).
/// - **Long press:** a label-coloured capsule fills a track across the
///   lower face (0.80–0.85 h, under the label zone), inset where the
///   corners curve in, so it reads on orbs and pills too.
/// - **Reduce Motion:** the cap shift is discrete (keyed off the
///   effective press); colour changes fade on the tint.
/// - **Lite tier:** flat body, flat cap, flat bezel, rim; no shader, no
///   blur.
///
/// Inside the label zone (`y2kLabelZoneTop`–`y2kLabelZoneBottom`) only the
/// body profile (rest and pressed) and lighter overlays are drawn, which is
/// exactly what the guardrails sample (`y2kLabelZoneSamples`).
///
/// Cost: rounded rectangles only, no saveLayer, no BackdropFilter; every
/// shader is built once per (face, colour, size) and shared by every key
/// that looks the same (a static LRU); blur only on the filled shadow
/// rounded rectangle, cached on its Paint. A press frame allocates no Path
/// or Paint.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:calsee_themes/key_role.dart';
import 'package:calsee_themes/render/key_face.dart';
import 'package:flutter/widgets.dart';

/// Whether a key of [role] wears satin metal on a CHROME face (digit and
/// function groups); operators and `=` are always gel.
bool y2kMetalRole(KeyRole role) => switch (role) {
  KeyRole.operator || KeyRole.equals => false,
  _ => true,
};

/// The parameters every Y2K face shares. A same-variant theme change lerps
/// them ([LerpableKeyFace]); AERO ↔ CHROME are different renderer types, so
/// those swipes dissolve.
@immutable
abstract base class Y2kKeyFace extends ThemedKeyFace
    implements LerpableKeyFace {
  const new({
    required this.accentHueTenths,
    required this.shadow,
    this.capPeak = 0.8,
    this.caustic = 0.48,
    this.depthMilli = 80,
    this.deepFloorMilli = y2kDeepFloorMilli,
    this.rimWidth = 1.25,
    this.shadowOffset = 2.5,
    this.shadowBlur = 6,
    this.cornerFraction = 0.5,
    this.lite = false,
    super.slashedZero,
  });

  /// The operator face's hue (tenths): near-neutral faces tint toward it
  /// when pressed.
  final int accentHueTenths;

  /// Specular cap peak alpha a0 (pressed: min(0.95, a0 + 0.10)).
  final double capPeak;

  /// Caustic glow alpha g0 (pressed: min(0.90, 1.8 g0)).
  final double caustic;

  /// Deep-tone depth (OKLCH lightness × 1000).
  final int depthMilli;

  /// Deep-tone floor (lightness × 1000; Accessible: higher).
  final int deepFloorMilli;

  /// AERO rim stroke / CHROME bezel ring width, dp.
  final double rimWidth;

  /// Drop-shadow colour (with its alpha).
  final Color shadow;

  /// Drop-shadow offset, dp.
  final double shadowOffset;

  /// Shadow blur radius, dp (σ = blur / 2).
  final double shadowBlur;

  /// Corner radius as a fraction of the short side (0.5 = orb / pill).
  final double cornerFraction;

  /// The lite effects tier: flat artwork, no shaders or blur.
  final bool lite;

  /// Whether this face draws satin metal on digit and function keys.
  bool get chrome;

  /// Pressed cap peak a1.
  double get capPressed => math.min(0.95, capPeak + 0.10);

  /// Pressed caustic g1.
  double get causticPressed => math.min(0.90, caustic * 1.8);

  /// The face's corner radius in a box of [size].
  double radiusFor(Size size) =>
      size.shortestSide * cornerFraction.clamp(0.0, 0.5);

  /// The usable rim / bezel width in a box of [size].
  double rimFor(Size size) =>
      math.max(0, math.min(rimWidth, size.shortestSide / 8));

  @override
  CustomPainter painter(KeyFaceMotion motion, KeyFaceSpec spec) =>
      Y2kKeyPainter(motion: motion, spec: spec, face: this);

  /// Nothing to build ahead: faces are rounded rectangles.
  @override
  void prepareLerp(KeyFaceRenderer other, Iterable<Size> cellSizes) {}

  /// The shared numbers of [a] and [b] at [t] (colours and discrete
  /// fields at t clamped to [0, 1]; `shapeT` can overshoot to ~1.06).
  @protected
  ({
    int accent,
    double cap,
    double caustic,
    int depth,
    int floor,
    double rim,
    Color shadow,
    double offset,
    double blur,
    double corner,
  })
  lerpShared(Y2kKeyFace a, Y2kKeyFace b, double t) {
    final c = t.clamp(0.0, 1.0);
    double number(double x, double y) => x + (y - x) * t;
    final d =
        ((b.accentHueTenths - a.accentHueTenths) % 3600 + 5400) % 3600 - 1800;
    return (
      accent: (a.accentHueTenths + d * c).round() % 3600,
      cap: number(a.capPeak, b.capPeak).clamp(0.0, 1.0),
      caustic: number(a.caustic, b.caustic).clamp(0.0, 1.0),
      depth: number(
        a.depthMilli.toDouble(),
        b.depthMilli.toDouble(),
      ).round().clamp(0, 300),
      floor: (a.deepFloorMilli + (b.deepFloorMilli - a.deepFloorMilli) * c)
          .round(),
      rim: math.max(0, number(a.rimWidth, b.rimWidth)),
      shadow: Color.lerp(a.shadow, b.shadow, c)!,
      offset: math.max(0, number(a.shadowOffset, b.shadowOffset)),
      blur: math.max(0, number(a.shadowBlur, b.shadowBlur)),
      corner: number(a.cornerFraction, b.cornerFraction).clamp(0.0, 0.5),
    );
  }

  /// Equality of the shared fields.
  @protected
  bool sameShared(Y2kKeyFace o) =>
      o.accentHueTenths == accentHueTenths &&
      o.capPeak == capPeak &&
      o.caustic == caustic &&
      o.depthMilli == depthMilli &&
      o.deepFloorMilli == deepFloorMilli &&
      o.rimWidth == rimWidth &&
      o.shadow == shadow &&
      o.shadowOffset == shadowOffset &&
      o.shadowBlur == shadowBlur &&
      o.cornerFraction == cornerFraction &&
      o.lite == lite &&
      o.slashedZero == slashedZero;

  /// Hash of the shared fields.
  @protected
  int get sharedHash => Object.hash(
    accentHueTenths,
    capPeak,
    caustic,
    depthMilli,
    deepFloorMilli,
    rimWidth,
    shadow,
    shadowOffset,
    shadowBlur,
    cornerFraction,
    lite,
    slashedZero,
  );
}

/// AERO: every key is a gel (pearl / moonstone digits, frost / sea-glass
/// function keys, coloured gel operators and `=`) with a darker rim.
final class Y2kAeroKeyFace extends Y2kKeyFace {
  const new({
    required super.accentHueTenths,
    required super.shadow,
    super.capPeak,
    super.caustic,
    super.depthMilli,
    super.deepFloorMilli,
    super.rimWidth,
    super.shadowOffset,
    super.shadowBlur,
    super.cornerFraction,
    super.lite,
    super.slashedZero,
    this.layoutBase,
  });

  /// For an in-between face of a theme morph: the end it is closer to.
  final Y2kAeroKeyFace? layoutBase;

  @override
  bool get chrome => false;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as Y2kAeroKeyFace;
    if (other is! Y2kAeroKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as Y2kAeroKeyFace;
    if (a == b) return a;
    final s = lerpShared(a, b, t);
    final near = t.clamp(0.0, 1.0) < 0.5 ? a : b;
    return Y2kAeroKeyFace(
      accentHueTenths: s.accent,
      shadow: s.shadow,
      capPeak: s.cap,
      caustic: s.caustic,
      depthMilli: s.depth,
      deepFloorMilli: s.floor,
      rimWidth: s.rim,
      shadowOffset: s.offset,
      shadowBlur: s.blur,
      cornerFraction: s.corner,
      lite: near.lite,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Y2kAeroKeyFace &&
      sameShared(other) &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(Y2kAeroKeyFace, sharedHash, layoutBase);
}

/// CHROME: satin-metal digit and function keys and candy-gel operators in
/// a light–dark–light chrome bezel tinted by the holographic foil.
final class Y2kChromeKeyFace extends Y2kKeyFace {
  const new({
    required super.accentHueTenths,
    required super.shadow,
    this.bezelTints = const [
      Color(0xFFF7EEF6),
      Color(0xFFEEEEFB),
      Color(0xFFE9F7F8),
    ],
    this.liteBezel = const Color(0xFFC4C6C9),
    super.capPeak,
    super.caustic,
    super.depthMilli,
    super.deepFloorMilli,
    super.rimWidth = 3,
    super.shadowOffset,
    super.shadowBlur,
    super.cornerFraction = 0.3,
    super.lite,
    super.slashedZero = true,
    this.layoutBase,
  });

  /// The three light bezel stops (the foil's holo colours, lightened).
  final List<Color> bezelTints;

  /// The lite tier's flat bezel colour.
  final Color liteBezel;

  /// For an in-between face of a theme morph: the end it is closer to.
  final Y2kChromeKeyFace? layoutBase;

  @override
  bool get chrome => true;

  @override
  KeyFaceRenderer get layoutFace => layoutBase ?? this;

  @override
  KeyFaceRenderer lerpTo(KeyFaceRenderer other, double t) {
    final a = layoutFace as Y2kChromeKeyFace;
    if (other is! Y2kChromeKeyFace) return t < 0.5 ? a : other;
    final b = other.layoutFace as Y2kChromeKeyFace;
    if (a == b) return a;
    final s = lerpShared(a, b, t);
    final c = t.clamp(0.0, 1.0);
    final near = c < 0.5 ? a : b;
    return Y2kChromeKeyFace(
      accentHueTenths: s.accent,
      shadow: s.shadow,
      bezelTints: [
        for (var i = 0; i < 3; i++)
          Color.lerp(_tint(a.bezelTints, i), _tint(b.bezelTints, i), c)!,
      ],
      liteBezel: Color.lerp(a.liteBezel, b.liteBezel, c)!,
      capPeak: s.cap,
      caustic: s.caustic,
      depthMilli: s.depth,
      deepFloorMilli: s.floor,
      rimWidth: s.rim,
      shadowOffset: s.offset,
      shadowBlur: s.blur,
      cornerFraction: s.corner,
      lite: near.lite,
      slashedZero: near.slashedZero,
      layoutBase: near,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Y2kChromeKeyFace &&
      sameShared(other) &&
      _sameColors(other.bezelTints, bezelTints) &&
      other.liteBezel == liteBezel &&
      other.layoutBase == layoutBase;

  @override
  int get hashCode => Object.hash(
    Y2kChromeKeyFace,
    sharedHash,
    Object.hashAll(bezelTints),
    liteBezel,
    layoutBase,
  );
}

Color _tint(List<Color> tints, int i) => tints.isEmpty
    ? const Color(0xFFF2F2F2)
    : tints[math.min(i, tints.length - 1)];

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ----------------------------------------------------------------- tones --

/// The body colours of one face colour (rest and pressed profiles, the
/// caustic glow and the deep tone), from the engine's functions so the
/// paint and the guardrails agree exactly.
@immutable
final class Y2kTones {
  const new({
    required this.rest,
    required this.pressed,
    required this.glow,
    required this.deep,
  });

  /// Computes (or recalls from a 64-entry LRU) the tones of [fill].
  factory of(
    Color fill, {
    required int depthMilli,
    required int deepFloorMilli,
    required int accentHueTenths,
    required bool metal,
  }) {
    final argb = fill.toARGB32() | 0xFF000000;
    final key = (argb, depthMilli, deepFloorMilli, accentHueTenths, metal);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final down = y2kPressedFace(argb, accentHueTenths);
    final rest = metal
        ? y2kMetalProfile(argb, depthMilli, deepFloorMilli)
        : y2kGelProfile(argb, depthMilli, deepFloorMilli);
    final pressed = metal
        ? y2kMetalProfile(down, depthMilli, deepFloorMilli - 25)
        : y2kGelProfile(down, depthMilli, deepFloorMilli - 25);
    final tones = Y2kTones(
      rest: [for (final c in rest) Color(c)],
      pressed: [for (final c in pressed) Color(c)],
      glow: Color(y2kCausticGlow(argb)),
      deep: Color(y2kDeep(argb, depthMilli, deepFloorMilli)),
    );
    _cache[key] = tones;
    while (_cache.length > 64) {
      _cache.remove(_cache.keys.first);
    }
    return tones;
  }

  static final LinkedHashMap<(int, int, int, int, bool), Y2kTones> _cache =
      LinkedHashMap();

  /// The rest body profile at `y2kGelStops` / `y2kMetalStops`.
  final List<Color> rest;

  /// The pressed body profile.
  final List<Color> pressed;

  /// The caustic glow colour.
  final Color glow;

  /// The deep tone (the gel's edge shade).
  final Color deep;

  /// The flat rest face (lite tier).
  Color get face => rest[3];

  /// The flat pressed face (lite tier).
  Color get pressedFace => pressed[3];
}

// --------------------------------------------------------------- artwork --

/// Geometry and shaders for one (face, colours, size): shared by every key
/// that looks the same, built once (static LRU).
final class _Artwork {
  new(Y2kKeyFace face, KeyFaceSpec spec, this.size, {required this.metal})
    : chrome = face.chrome {
    final w = size.width;
    final h = size.height;
    final r = face.radiusFor(size);
    final rim = face.rimFor(size);
    outer = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r));
    inner = chrome ? outer.deflate(rim) : outer;
    shadowRect = outer.shift(Offset(0, face.shadowOffset));
    rimRect = outer.deflate(rim / 2);
    catchRect = chrome ? inner.inflate(0.3) : outer.deflate(rim + 0.75);
    hairline = outer.deflate(0.375);
    // The cap: inset by the corner, over the top 42 % (30 % on metal).
    final ci = math.max(0.07 * w, 0.32 * r);
    final capBottom = (metal ? 0.30 : 0.46) * h;
    final capW = math.max<double>(0, w - 2 * ci);
    final capRect = Rect.fromLTRB(ci, 0.04 * h, w - ci, capBottom);
    final topR = Radius.elliptical(
      math.min(capW / 2, 0.9 * r),
      math.min(0.38 * h, 0.9 * r),
    );
    final bottomR = Radius.elliptical(
      math.min(capW / 2, 0.6 * r),
      math.min(0.21 * h, 0.45 * r),
    );
    cap = RRect.fromRectAndCorners(
      capRect,
      topLeft: topR,
      topRight: topR,
      bottomLeft: bottomR,
      bottomRight: bottomR,
    ).scaleRadii();
    caustic = Rect.fromCenter(
      center: Offset(0.5 * w, 1.02 * h),
      width: 0.80 * w,
      height: 0.72 * h,
    );
    sheen = Rect.fromLTRB(-0.17 * w, -h, 0.17 * w, h);
    // The long-press track: a capsule across the lower face (0.80–0.85 h,
    // under the label zone), inset where the rounded corners curve in, so
    // it stays a readable bar on orbs and pills.
    const holdTop = 0.80;
    const holdBottom = 0.85;
    final yb = holdBottom * h;
    final dy = yb - (h - r);
    final curve = dy > 0 ? r - math.sqrt(math.max(0, r * r - dy * dy)) : 0.0;
    final x0 = math.min(w / 2, curve + (chrome ? rim : 0) + 0.06 * w);
    holdTrack = Rect.fromLTRB(x0, holdTop * h, w - x0, yb);
    final tones = Y2kTones.of(
      spec.style.fill,
      depthMilli: face.depthMilli,
      deepFloorMilli: face.deepFloorMilli,
      accentHueTenths: face.accentHueTenths,
      metal: metal,
    );
    this.tones = tones;
    if (face.lite) return;
    final stops = metal ? y2kMetalStops : y2kGelStops;
    body = ui.Gradient.linear(Offset.zero, Offset(0, h), tones.rest, stops);
    bodyPressed = ui.Gradient.linear(
      Offset.zero,
      Offset(0, h),
      tones.pressed,
      stops,
    );
    final a1 = face.capPressed;
    const white = Color(0xFFFFFFFF);
    capShader = ui.Gradient.linear(
      capRect.topCenter,
      capRect.bottomCenter,
      [
        white.withValues(alpha: a1),
        white.withValues(alpha: a1 * (metal ? 0.50 : 0.62)),
        white.withValues(alpha: a1 * (metal ? 0.22 : 0.34)),
        white.withValues(alpha: a1 * (metal ? 0.16 : 0.26)),
      ],
      const [0, 0.45, 0.85, 1],
    );
    final g1 = face.causticPressed;
    causticShader = _ellipse(
      caustic,
      [
        tones.glow.withValues(alpha: g1),
        tones.glow.withValues(alpha: g1 * 0.5),
        tones.glow.withValues(alpha: 0),
      ],
      const [0, 0.5, 1],
    );
    if (!metal) {
      edgeShader = _ellipse(
        Offset.zero & size,
        [tones.deep.withValues(alpha: 0), tones.deep.withValues(alpha: 0.30)],
        const [0.90, 1],
      );
    }
    sheenShader = ui.Gradient.linear(
      Offset(sheen.left, 0),
      Offset(sheen.right, 0),
      [
        white.withValues(alpha: 0),
        white.withValues(alpha: 0.35),
        white.withValues(alpha: 0.80),
        white.withValues(alpha: 0.35),
        white.withValues(alpha: 0),
      ],
      const [0, 0.30, 0.5, 0.70, 1],
    );
    // The catch-light: full strength along the top, fading out down the
    // sides by 0.40 h (a hard cut would show as a step in the line).
    final catchAlpha = chrome ? 0.45 : 0.55;
    catchShader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, h),
      [
        white.withValues(alpha: catchAlpha),
        white.withValues(alpha: catchAlpha),
        white.withValues(alpha: 0),
        white.withValues(alpha: 0),
      ],
      const [0, 0.18, 0.40, 1],
    );
    if (chrome) {
      final t = (face as Y2kChromeKeyFace).bezelTints;
      bezel = _bezel(size, [_tint(t, 0), _tint(t, 1), _tint(t, 2)]);
      bezelPressed = _bezel(size, [
        for (var i = 0; i < 3; i++) _turn(_tint(t, i), 20),
      ]);
    }
    if (metal) streaks = _streakShader();
  }

  /// The artwork for ([face], [spec]'s fill, [size]), shared via a 64-entry
  /// LRU (the keypad's ~30 keys need a handful).
  factory of(
    Y2kKeyFace face,
    KeyFaceSpec spec,
    Size size, {
    required bool metal,
  }) {
    final key = (face, spec.style.fill, size, metal);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    final art = _Artwork(face, spec, size, metal: metal);
    _cache[key] = art;
    while (_cache.length > 64) {
      _cache.remove(_cache.keys.first);
    }
    return art;
  }

  static final LinkedHashMap<(Y2kKeyFace, Color, Size, bool), _Artwork> _cache =
      LinkedHashMap();

  final bool metal;
  final bool chrome;
  final Size size;

  /// The frame this artwork was first painted in ([Y2kRestImage]).
  int? firstFrame;
  late final RRect outer;
  late final RRect inner;
  late final RRect shadowRect;
  late final RRect rimRect;
  late final RRect catchRect;
  late final RRect hairline;
  late final RRect cap;
  late final Rect caustic;
  late final Rect sheen;
  late final Rect holdTrack;
  late final Y2kTones tones;
  ui.Shader? body;
  ui.Shader? bodyPressed;
  ui.Shader? capShader;
  ui.Shader? causticShader;
  ui.Shader? edgeShader;
  ui.Shader? sheenShader;
  ui.Shader? catchShader;
  ui.Shader? bezel;
  ui.Shader? bezelPressed;
  ui.Shader? streaks;

  /// Shaders this artwork holds (tests: 0 on the lite tier).
  int get shaderCount => [
    body,
    bodyPressed,
    capShader,
    causticShader,
    edgeShader,
    sheenShader,
    catchShader,
    bezel,
    bezelPressed,
    streaks,
  ].whereType<ui.Shader>().length;

  static ui.Gradient _ellipse(
    Rect box,
    List<Color> colors,
    List<double> stops,
  ) {
    final w = box.width;
    final h = box.height;
    final c = box.center;
    final longest = math.max(w, h);
    if (longest <= 0) {
      return ui.Gradient.linear(Offset.zero, const Offset(1, 0), [
        colors.first,
        colors.first,
      ]);
    }
    final sx = w / longest;
    final sy = h / longest;
    final matrix = Float64List(16)
      ..[0] = sx
      ..[5] = sy
      ..[10] = 1
      ..[12] = c.dx * (1 - sx)
      ..[13] = c.dy * (1 - sy)
      ..[15] = 1;
    return ui.Gradient.radial(
      c,
      longest / 2,
      colors,
      stops,
      TileMode.clamp,
      matrix,
    );
  }

  static ui.Gradient _bezel(Size size, List<Color> tints) {
    Color dark(double l) => Color.fromARGB(
      255,
      (l * 255).round(),
      (l * 255).round(),
      ((l + 0.02).clamp(0.0, 1.0) * 255).round(),
    );
    return ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [tints[0], dark(0.42), tints[1], dark(0.56), tints[2], dark(0.47)],
      const [0, 0.20, 0.42, 0.60, 0.80, 1],
    );
  }

  static Color _turn(Color c, double degrees) {
    final hsv = HSVColor.fromColor(c);
    return hsv.withHue((hsv.hue + degrees) % 360).toColor();
  }

  static ui.ImageShader? _streakTile;

  /// The brushed-metal streak tile (built once, family-wide): fine white
  /// lines at hashed alphas 0.03–0.10, 48 × 6 dp drawn at 3×.
  static ui.ImageShader _streakShader() {
    final cached = _streakTile;
    if (cached != null) return cached;
    const scale = 3.0;
    const tw = 48.0;
    const th = 6.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    final paint = Paint()..strokeWidth = 0.5;
    var x = 0x9E3779B9;
    for (var i = 0; i < 12; i++) {
      x = (x * 1103515245 + 12345) & 0x7FFFFFFF;
      final y = (i + 0.5) * th / 12;
      final alpha = 0.03 + 0.07 * ((x >> 8) & 0xFF) / 255;
      final start = ((x >> 4) & 0x1F) / 31 * tw * 0.5;
      paint.color = const Color(0xFFFFFFFF).withValues(alpha: alpha);
      canvas.drawLine(Offset(start, y), Offset(start + tw * 0.6, y), paint);
    }
    final image = recorder.endRecording().toImageSync(
      (tw * scale).round(),
      (th * scale).round(),
    );
    final matrix = Float64List(16)
      ..[0] = 1 / scale
      ..[5] = 1 / scale
      ..[10] = 1
      ..[15] = 1;
    return _streakTile = ui.ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      matrix,
    );
  }
}

// ------------------------------------------------------------ rest image --

/// A key's rest artwork (every layer at tint 0, press 0, no hover) baked
/// into one image at the device pixel ratio, shared by every key that
/// looks the same. Impeller keeps no raster cache, so without it each
/// ambient frame (the rising bubbles) redrew ~10 gradient layers per key:
/// ~10 ms of raster for a keypad on an M-series Mac, several times that on
/// a phone GPU.
///
/// Baked only once an artwork has been painted in two different frames:
/// a theme morph builds new (lerped) artwork every frame and keeps the
/// vector path. Images are kept in a small LRU and disposed on eviction
/// (pictures that drew them keep their own reference).
final class Y2kRestImage {
  new _(this.image, this.rect, this.pixelSize);

  /// The baked layers.
  final ui.Image image;

  /// Where [image] goes in the key's box, dp (it reaches past the box by
  /// the shadow's blur).
  final Rect rect;

  /// [image]'s size in pixels.
  final Size pixelSize;

  /// Bake on the first paint instead of the second frame (tests).
  @visibleForTesting
  static bool debugBakeAtOnce = false;

  /// Images baked (tests).
  @visibleForTesting
  static int builds = 0;

  /// Images kept.
  static const int capacity = 24;

  static final LinkedHashMap<
    (_Artwork, Y2kKeyFace, Color?, double),
    Y2kRestImage
  >
  _cache = LinkedHashMap();

  /// Forgets (and disposes) every baked image (tests).
  @visibleForTesting
  static void clearCache() {
    for (final r in _cache.values) {
      r.image.dispose();
    }
    _cache.clear();
    builds = 0;
  }

  static double _devicePixelRatio() {
    // The binding's dispatcher (a test's view overrides apply), else the
    // engine's.
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view =
        dispatcher.implicitView ??
        (dispatcher.views.isEmpty ? null : dispatcher.views.first);
    final dpr = view?.devicePixelRatio ?? 1;
    return dpr > 0 && dpr.isFinite ? dpr : 1;
  }

  /// The rest image of [art] (null until it has been painted in two
  /// frames); [paint] draws the rest layers in the key's box.
  static Y2kRestImage? _of(
    _Artwork art,
    Y2kKeyFace face,
    Color? outline,
    void Function(Canvas canvas) paint,
  ) {
    final dpr = _devicePixelRatio();
    final key = (art, face, outline, dpr);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    if (!debugBakeAtOnce) {
      final frame = ui.PlatformDispatcher.instance.frameData.frameNumber;
      if (frame < 0) return null; // painted outside a frame
      if (art.firstFrame == null || art.firstFrame == frame) {
        art.firstFrame ??= frame;
        return null;
      }
    }
    builds++;
    // The box plus the shadow's blur (3σ) and the catch-light's stroke,
    // snapped to the pixel grid so the image draws 1:1.
    final sigma = face.shadowBlur / 2;
    final box = (Offset.zero & art.size)
        .expandToInclude(art.shadowRect.outerRect.inflate(3 * sigma + 1))
        .inflate(2);
    final left = (box.left * dpr).floorToDouble();
    final top = (box.top * dpr).floorToDouble();
    final w = math.max(1, (box.right * dpr).ceil() - left.toInt());
    final h = math.max(1, (box.bottom * dpr).ceil() - top.toInt());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(-left, -top)
      ..scale(dpr);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    final rest = _cache[key] = Y2kRestImage._(
      image,
      Rect.fromLTWH(left / dpr, top / dpr, w / dpr, h / dpr),
      Size(w.toDouble(), h.toDouble()),
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first)?.image.dispose();
    }
    return rest;
  }
}

// --------------------------------------------------------------- painter --

/// Paints one Y2K key (see the library docs for the layers). Repaints
/// from the motion channels without rebuilds.
class Y2kKeyPainter extends CustomPainter {
  new({required this.motion, required this.spec, required this.face})
    : metal = face.chrome && y2kMetalRole(spec.role),
      super(repaint: motion.listenable);

  /// The key's animation channels.
  final KeyFaceMotion motion;

  /// Colours and role.
  final KeyFaceSpec spec;

  /// The theme's renderer.
  final Y2kKeyFace face;

  /// Whether this key wears satin metal (CHROME digit / function keys).
  final bool metal;

  _Artwork? _art;
  Size? _size;

  final Paint _shadowPaint = Paint();
  final Paint _fill = Paint();
  final Paint _bodyPaint = Paint();
  final Paint _pressedPaint = Paint();
  final Paint _streakPaint = Paint();
  final Paint _edgePaint = Paint();
  final Paint _causticPaint = Paint();
  final Paint _capPaint = Paint();
  final Paint _sheenPaint = Paint();
  final Paint _bezelPaint = Paint();
  final Paint _bezelPressedPaint = Paint();
  final Paint _rimPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _catchPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0xFFFFFFFF);
  final Paint _hairlinePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.75;

  /// Shaders the current artwork holds (tests: 0 on the lite tier).
  @visibleForTesting
  int get debugShaderCount => _art?.shaderCount ?? 0;

  /// Whether the shadow paint carries a blur (tests: false on the lite
  /// tier).
  @visibleForTesting
  bool get debugHasBlur => _shadowPaint.maskFilter != null;

  /// Press depth for spatial artwork: clamped to [0, 1], discrete under
  /// Reduce Motion.
  double pressFor(double p) =>
      effectivePress(p, reduceMotion: spec.reduceMotion).clamp(0.0, 1.0);

  /// The cap's press shift at tint [k] in a box of [size]: 0.03 h down and
  /// toward the finger (discrete under Reduce Motion).
  Offset capShift(Size size, double k) {
    final ks = spec.reduceMotion ? pressFor(motion.press.value) : k;
    if (ks <= 0) return Offset.zero;
    final m = motion;
    final tf = m is KeyFaceMotionDetail ? m.touchFraction : null;
    final dx = tf == null ? 0.0 : (tf.dx.clamp(0.15, 0.85) - 0.5) * 0.12;
    return Offset(dx * size.width * ks, 0.03 * size.height * ks);
  }

  void _ensure(Size size) {
    if (_size == size && _art != null) return;
    _size = size;
    final art = _art = _Artwork.of(face, spec, size, metal: metal);
    final lite = face.lite;
    _shadowPaint
      ..color = face.shadow
      ..maskFilter = !lite && face.shadowBlur > 0
          ? MaskFilter.blur(BlurStyle.normal, face.shadowBlur / 2)
          : null;
    _bodyPaint.shader = art.body;
    _pressedPaint.shader = art.bodyPressed;
    _streakPaint.shader = art.streaks;
    _edgePaint.shader = art.edgeShader;
    _causticPaint.shader = art.causticShader;
    _capPaint.shader = art.capShader;
    _sheenPaint.shader = art.sheenShader;
    _catchPaint.shader = art.catchShader;
    _bezelPaint.shader = art.bezel;
    _bezelPressedPaint.shader = art.bezelPressed;
    _rimPaint.strokeWidth = face.rimFor(size);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || size.width < 1 || size.height < 1) return;
    _ensure(size);
    final art = _art!;
    final p = pressFor(motion.press.value);
    final k = motion.tint.value.clamp(0.0, 1.0);
    final hover = spec.hoverOverlayOpacity * motion.hover.value;
    // A key at rest (no tint, press, sweep or hover) on the full tier is
    // one image draw: its ~10 layers, baked once per look.
    if (!face.lite && k <= 0 && p <= 0.02 && hover <= 0) {
      final rest = Y2kRestImage._of(
        art,
        face,
        spec.style.outline,
        (c) => _paintLayers(c, size, art, p: 0, k: 0, hover: 0),
      );
      if (rest != null) {
        canvas.drawImageRect(
          rest.image,
          Offset.zero & rest.pixelSize,
          rest.rect,
          _imagePaint,
        );
        return;
      }
    }
    _paintLayers(canvas, size, art, p: p, k: k, hover: hover);
  }

  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.low;

  void _paintLayers(
    Canvas canvas,
    Size size,
    _Artwork art, {
    required double p,
    required double k,
    required double hover,
  }) {
    final full = !face.lite;
    final rm = spec.reduceMotion;
    final bounds = Offset.zero & size;

    // L0: the drop shadow.
    if (full && face.shadowBlur > 0 && face.shadow.a > 0) {
      canvas.drawRRect(art.shadowRect, _shadowPaint);
    }

    // L1: the chrome bezel, its pressed turn, the outer hairline.
    if (face.chrome && face.rimFor(size) > 0) {
      if (full) {
        canvas.drawDRRect(art.outer, art.inner, _bezelPaint);
        if (k > 0) {
          _bezelPressedPaint.color = Color.fromRGBO(0, 0, 0, k);
          canvas.drawDRRect(art.outer, art.inner, _bezelPressedPaint);
        }
      } else {
        _fill
          ..shader = null
          ..color = (face as Y2kChromeKeyFace).liteBezel;
        canvas.drawDRRect(art.outer, art.inner, _fill);
      }
      final outline = spec.style.outline;
      if (outline != null) {
        _hairlinePaint.color = outline;
        canvas.drawRRect(art.hairline, _hairlinePaint);
      }
    }

    canvas
      ..save()
      ..clipRRect(art.inner);
    // L2–L3: the body at rest, the pressed body faded over it on the tint.
    if (full) {
      if (k < 0.999) canvas.drawRect(bounds, _bodyPaint);
      if (k > 0) {
        _pressedPaint.color = Color.fromRGBO(0, 0, 0, k);
        canvas.drawRect(bounds, _pressedPaint);
      }
      // L3b: brushed streaks (metal); L4: the gel's edge shade.
      if (metal) {
        canvas.drawRect(bounds, _streakPaint);
      } else {
        canvas.drawRect(bounds, _edgePaint);
      }
      // L5: the caustic, brighter pressed.
      final g1 = face.causticPressed;
      if (g1 > 0) {
        final g = face.caustic + (g1 - face.caustic) * k;
        _causticPaint.color = Color.fromRGBO(0, 0, 0, (g / g1).clamp(0.0, 1.0));
        canvas.drawOval(art.caustic, _causticPaint);
      }
      // L6: the specular cap, flaring and sliding toward the finger.
      final a1 = face.capPressed;
      if (a1 > 0) {
        final a = face.capPeak + (a1 - face.capPeak) * k;
        _capPaint.color = Color.fromRGBO(0, 0, 0, (a / a1).clamp(0.0, 1.0));
        final shift = capShift(size, k);
        canvas
          ..save()
          ..translate(shift.dx, shift.dy)
          ..drawRRect(art.cap, _capPaint)
          ..restore();
      }
      // L7: the release sweep, once left to right while the press springs
      // back and the tint fades (never at rest, pressed or under Reduce
      // Motion).
      if (!rm && k < 0.999 && p > 0.02) {
        final alpha = ((1 - k) * 4).clamp(0.0, 1.0);
        final x = (-0.45 + 1.90 * (1 - p)) * size.width;
        if (alpha > 0) {
          _sheenPaint.color = Color.fromRGBO(0, 0, 0, alpha);
          canvas
            ..save()
            ..translate(x, size.height / 2)
            ..rotate(20 * math.pi / 180)
            ..drawRect(art.sheen, _sheenPaint)
            ..restore();
        }
      }
    } else {
      _fill
        ..shader = null
        ..color = art.tones.face;
      if (k < 0.999) canvas.drawRect(bounds, _fill);
      if (k > 0) {
        _fill.color = art.tones.pressedFace.withValues(alpha: k);
        canvas.drawRect(bounds, _fill);
      }
      _fill.color = const Color(0xFFFFFFFF)
          .withValues(alpha: (face.capPeak * 0.45).clamp(0.0, 1.0));
      canvas.drawRRect(art.cap, _fill);
    }
    // L8: hover, the contrast-safe (white) state layer.
    if (hover > 0) {
      _fill
        ..shader = null
        ..color = stateLayerColor(
          spec.style.fill,
          spec.style.label,
        ).withValues(alpha: hover.clamp(0.0, 1.0));
      canvas.drawRect(bounds, _fill);
    }
    canvas.restore();

    // L9: the AERO rim.
    final outline = spec.style.outline;
    if (!face.chrome && outline != null && _rimPaint.strokeWidth > 0) {
      _rimPaint.color = outline;
      canvas.drawRRect(art.rimRect, _rimPaint);
    }

    // L10: the catch-light along the top edge, fading out down the sides.
    if (full) canvas.drawRRect(art.catchRect, _catchPaint);

    // L11: the long-press bar, filling the track from the left (Reduce
    // Motion: the whole track fades in).
    final fill = motion.holdFill;
    final track = art.holdTrack;
    if (fill > 0 && k > 0 && track.width > 0) {
      final width = rm ? track.width : track.width * fill.clamp(0.0, 1.0);
      _fill
        ..shader = null
        ..color = spec.style.label.withValues(
          alpha: ((rm ? fill : 1) * k).clamp(0.0, 1.0),
        );
      canvas.drawRRect(
        RRect.fromLTRBR(
          track.left,
          track.top,
          track.left + width,
          track.bottom,
          Radius.circular(track.height / 2),
        ),
        _fill,
      );
    }
  }

  @override
  bool shouldRepaint(Y2kKeyPainter oldDelegate) =>
      !identical(oldDelegate.motion, motion) ||
      oldDelegate.spec != spec ||
      oldDelegate.face != face;
}
