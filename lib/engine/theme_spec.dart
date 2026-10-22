/// The theme data model (spec §5.1; docs/m3-theme-engine-design.md).
///
/// A [ThemeSpec] is a pure function of (seed, family, engineVersion
/// [, accessible]). Every field is an integer, a bool, a string or an enum,
/// so `toJson` and [ThemeSpec.stableHash] are identical on every run and
/// platform. Colours are opaque-or-translucent `int` ARGB (`0xAARRGGBB`).
/// Dimensions are integers in hundredths of a dp (`…Cdp`), fractions in
/// thousandths (`…Permille`), angles in tenths of a degree (`…Tenths`).
///
/// Enums serialise by `name`: **never rename an enum value** used here
/// (add new ones instead), or shared themes stop decoding.
library;

import 'dart:convert';

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/rng.dart' show mul32;
import 'package:meta/meta.dart';

export 'package:calsee_themes/engine/families.dart' show ThemeFamily;

// ------------------------------------------------------------------ enums --

/// Light or dark base.
enum ThemeBrightness { dark, light }

/// Key outline geometry (spec §5.1 KeyShape; motion brief §6.3).
enum KeyShapeKind {
  circle,
  squircle,
  pill,
  roundedRect,
  hexagon,

  /// Material 3 Expressive shape (material_new_shapes), morphs on press.
  m3eMorph,

  /// Physical keycap (retro).
  keycap,

  /// Chamfered/cut corners.
  cut,

  /// Stepped pixel corners.
  stepped,
}

/// Material 3 Expressive shape-library ids (material_new_shapes
/// `MaterialShapes`), used when [KeyShapeKind.m3eMorph].
enum M3eShape {
  circle,
  square,
  slanted,
  arch,
  semiCircle,
  oval,
  pill,
  triangle,
  arrow,
  fan,
  diamond,
  clamShell,
  pentagon,
  gem,
  sunny,
  verySunny,
  cookie4Sided,
  cookie6Sided,
  cookie7Sided,
  cookie9Sided,
  cookie12Sided,
  ghostish,
  clover4Leaf,
  clover8Leaf,
  burst,
  softBurst,
  boom,
  softBoom,
  flower,
  puffy,
  puffyDiamond,
  pixelCircle,
  pixelTriangle,
  bun,
  heart,
}

/// How a key face is drawn (spec §5.1 KeyStyle). Descriptive: renderers
/// are chosen by family, never by style. `glass` also marks Y2K / Frutiger
/// Aero's opaque gel and chrome keys; `outlined` is drawn by Neo-brutalism
/// (with a hard shadow) and Paper & ink (sketched, without one).
enum KeyStyleKind { flat, outlined, glass, extruded, soft, clay, pixel }

/// Background kind (spec §5.1 Background).
enum BackgroundKind {
  solid,
  linearGradient,
  radialGradient,
  meshGradient,
  pattern,
  noise,
  shader,

  // Family scenes: one kind per scene, painted by the family's scene
  // painter (`backgroundScenePainters` in background_painter.dart) and
  // sampled by the family's `…SceneSamples` (guardrails.dart). The family
  // documents what each `colors` index and reused field means. Never
  // produced by the generic generator.

  /// Claymorphism: a pastel wash with soft clay spheres (claymorphism.dart).
  claySoft,

  /// Y2K / Frutiger Aero: sky, meadow or water with bubbles (y2k_aero.dart).
  aeroSky,

  /// Y2K / Frutiger Aero: an iridescent holographic sheet (y2k_aero.dart).
  chromeHolo,

  /// Paper & ink: a paper sheet with rules and grain (paper_ink.dart).
  paperSheet,

  /// Cyberpunk: a dark gradient with grid, traces and scanlines
  /// (cyberpunk.dart).
  cyberGrid,

  /// Vaporwave: a striped sun over a perspective grid (vaporwave.dart).
  vaporSunset,

  /// Bauhaus: a geometric poster composition in the margins (bauhaus.dart).
  bauhausComposition,
}

/// Overlay pattern for [BackgroundKind.pattern] (or on top of gradients).
enum BackgroundPattern { none, dots, grid, stripes, halftone, checker, waves }

/// Press verb at p = 1 (motion brief §2.3, §2.6).
enum PressVerb {
  morph,
  inflate,
  plunge,
  sink,
  travel,
  stamp,
  squash,
  step,
  fill,
  gloss,
  ink,
  invert,
}

/// Display glyph entry (motion brief §2.3).
enum EntryStyle { pop, rise, drop, stamp, segments, step, bleed, glyph }

/// Extra press effect (motion brief §2.6).
enum PressFx { none, glow, sheen, inkWash, afterglow }

/// iOS impact style (Android maps intents; motion brief §3).
enum ImpactStyle { light, soft, rigid }

/// Which spatial spring scale a family's UI motion uses.
enum MotionScheme { expressive, standard }

/// Optional ambient effect (spec §5.1 Effects). M3 ships none.
enum EffectKind { none, particles, glow, grain, scanlines }

/// Sound pack ids (research sound.md §1; motion brief §2.3).
enum SoundPackId {
  softTap,
  glass,
  pop,
  tick,
  beep,
  mechClicky,
  mechLinear,
  chiptune,
  typewriter,

  // Appended in M5 so families can pair these bundled packs; append only
  // (never reorder) so existing names/indices stay stable.
  mechTactile,
  wood,
}

/// A non-colour cue that distinguishes operator / `=` keys from digits
/// (spec §5.4). `none` means the colour/contrast rule alone must pass.
/// A family that records any other cue verifies it in its own validator.
enum OperatorCue {
  none,
  shape,
  outline,
  weight,
  ring,
  extrusion,

  /// A fill pattern only operators carry (Paper & ink's ink hatching).
  pattern,
}

/// Generated, hand-crafted hero, or device-derived variant.
enum ThemeVariant {
  generated,
  hero,

  /// M3E "Match my wallpaper" (device-dependent; not share-code
  /// reproducible).
  wallpaper,
}

T _enumByName<T extends Enum>(List<T> values, Object? name, String field) {
  if (name is String) {
    for (final v in values) {
      if (v.name == name) return v;
    }
  }
  throw FormatException('Unknown $field: $name');
}

// ------------------------------------------------------------ json utils --

/// `0xAARRGGBB` → `"aarrggbb"`.
String argbToHex(int argb) =>
    (argb & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');

/// `"aarrggbb"` (or `"#aarrggbb"`) → `0xAARRGGBB`.
int argbFromHex(Object? hex) {
  if (hex is! String) throw FormatException('Expected colour hex: $hex');
  final s = hex.startsWith('#') ? hex.substring(1) : hex;
  final v = s.length == 8 ? int.tryParse(s, radix: 16) : null;
  if (v == null) throw FormatException('Bad colour hex: $hex');
  return v;
}

Map<String, Object?> _map(Object? v, String field) {
  if (v is Map<String, Object?>) return v;
  if (v is Map) return v.cast<String, Object?>();
  throw FormatException('Expected object for $field');
}

int _int(Map<String, Object?> j, String k) {
  final v = j[k];
  if (v is int) return v;
  if (v is double && v == v.roundToDouble()) return v.toInt();
  throw FormatException('Expected int for $k: $v');
}

int? _intOrNull(Map<String, Object?> j, String k) =>
    j[k] == null ? null : _int(j, k);

bool _bool(Map<String, Object?> j, String k) {
  final v = j[k];
  if (v is bool) return v;
  throw FormatException('Expected bool for $k: $v');
}

String _str(Map<String, Object?> j, String k) {
  final v = j[k];
  if (v is String) return v;
  throw FormatException('Expected string for $k: $v');
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------- colours --

/// Face, label and edge colours of one key role.
@immutable
final class KeyColors {
  const KeyColors({
    required this.face,
    required this.label,
    required this.edge,
  });

  factory KeyColors.fromJson(Object? json) {
    final j = _map(json, 'KeyColors');
    return KeyColors(
      face: argbFromHex(j['face']),
      label: argbFromHex(j['label']),
      edge: argbFromHex(j['edge']),
    );
  }

  /// Key face fill (opaque, or translucent for glass).
  final int face;

  /// Label glyph colour (solved against [face]).
  final int label;

  /// Outline / extruded side / rim colour (NeoPOP sides, outlined and
  /// accessible rims). Renderers that draw no edge ignore it.
  final int edge;

  KeyColors copyWith({int? face, int? label, int? edge}) => KeyColors(
    face: face ?? this.face,
    label: label ?? this.label,
    edge: edge ?? this.edge,
  );

  Map<String, Object?> toJson() => {
    'face': argbToHex(face),
    'label': argbToHex(label),
    'edge': argbToHex(edge),
  };

  @override
  bool operator ==(Object other) =>
      other is KeyColors &&
      other.face == face &&
      other.label == label &&
      other.edge == edge;

  @override
  int get hashCode => Object.hash(face, label, edge);

  @override
  String toString() =>
      'KeyColors(${argbToHex(face)}/${argbToHex(label)}/${argbToHex(edge)})';
}

/// Every colour role of a theme, as final quantised ARGB (what the
/// guardrails checked).
@immutable
final class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.displayText,
    required this.previewText,
    required this.error,
    required this.caret,
    required this.focusRing,
    required this.accent,
    required this.digit,
    required this.operator,
    required this.equals,
    required this.function,
    required this.shadow,
    required this.highlight,
    required this.seedColor,
    this.lcdGhost,
  });

  factory Palette.fromJson(Object? json) {
    final j = _map(json, 'Palette');
    return Palette(
      background: argbFromHex(j['background']),
      surface: argbFromHex(j['surface']),
      displayText: argbFromHex(j['displayText']),
      previewText: argbFromHex(j['previewText']),
      error: argbFromHex(j['error']),
      caret: argbFromHex(j['caret']),
      focusRing: argbFromHex(j['focusRing']),
      accent: argbFromHex(j['accent']),
      digit: KeyColors.fromJson(j['digit']),
      operator: KeyColors.fromJson(j['operator']),
      equals: KeyColors.fromJson(j['equals']),
      function: KeyColors.fromJson(j['function']),
      shadow: argbFromHex(j['shadow']),
      highlight: argbFromHex(j['highlight']),
      seedColor: argbFromHex(j['seedColor']),
      lcdGhost: j['lcdGhost'] == null ? null : argbFromHex(j['lcdGhost']),
    );
  }

  /// Calculator background behind display and keypad.
  final int background;

  /// Display surface (the solid-enough backing behind display text).
  final int surface;

  /// Expression and result text (≥ 4.5:1 on [surface]).
  final int displayText;

  /// Live preview and indicators (≥ 3:1 on [surface]; we target 4.5).
  final int previewText;

  /// Error message text (≥ 4.5:1 on [surface]).
  final int error;

  /// Expression caret (≥ 3:1 on [surface]).
  final int caret;

  /// Keyboard focus ring (≥ 3:1 against [background]).
  final int focusRing;

  /// Theme accent (chips, highlights; ≥ 3:1 where it carries meaning).
  /// Vaporwave gives it a role of its own (the title bar's end colour,
  /// vaporwave.dart).
  final int accent;

  /// Digits, `.`, `±`.
  final KeyColors digit;

  /// `+ − × ÷` and other binary operators.
  final KeyColors operator;

  /// `=`.
  final KeyColors equals;

  /// Function keys: AC/⌫, `( )`, `%`, memory, modes.
  final KeyColors function;

  /// Hard shadow / dark neumorphic shadow colour (may be translucent).
  /// Reused as family artwork ink: Paper & ink's ink, Cyberpunk's panel
  /// scanlines, Vaporwave's key and window lines, Bauhaus's display rule
  /// (see each family's library doc).
  final int shadow;

  /// Light neumorphic shadow / specular highlight (may be translucent).
  /// Reused as family artwork: Claymorphism's top-left highlight, Y2K's
  /// specular white, Paper & ink's wash, Vaporwave's title-bar start,
  /// Bauhaus's display quarter-disc (see each family's library doc).
  final int highlight;

  /// The colour the palette was derived from (M3E feeds it to
  /// `ColorScheme.fromSeed`; wallpaper variant = device colour).
  final int seedColor;

  /// Unlit ("ghost") segments of a 7-segment LCD / VFD display (Retro):
  /// faintly visible on [surface] (the LCD panel), at most 1.3:1 against
  /// it so they never compete with lit segments. Null for families
  /// without a segment display; serialised only when set, so every other
  /// theme's canonical JSON and stable hash are unchanged.
  final int? lcdGhost;

  /// Key colours for a role group.
  KeyColors keyColors(KeyGroup group) => switch (group) {
    KeyGroup.digit => digit,
    KeyGroup.operator => operator,
    KeyGroup.equals => equals,
    KeyGroup.function => function,
  };

  Palette copyWith({
    int? background,
    int? surface,
    int? displayText,
    int? previewText,
    int? error,
    int? caret,
    int? focusRing,
    int? accent,
    KeyColors? digit,
    KeyColors? operator,
    KeyColors? equals,
    KeyColors? function,
    int? shadow,
    int? highlight,
    int? seedColor,
    int? lcdGhost,
  }) => Palette(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    displayText: displayText ?? this.displayText,
    previewText: previewText ?? this.previewText,
    error: error ?? this.error,
    caret: caret ?? this.caret,
    focusRing: focusRing ?? this.focusRing,
    accent: accent ?? this.accent,
    digit: digit ?? this.digit,
    operator: operator ?? this.operator,
    equals: equals ?? this.equals,
    function: function ?? this.function,
    shadow: shadow ?? this.shadow,
    highlight: highlight ?? this.highlight,
    seedColor: seedColor ?? this.seedColor,
    lcdGhost: lcdGhost ?? this.lcdGhost,
  );

  Map<String, Object?> toJson() => {
    'background': argbToHex(background),
    'surface': argbToHex(surface),
    'displayText': argbToHex(displayText),
    'previewText': argbToHex(previewText),
    'error': argbToHex(error),
    'caret': argbToHex(caret),
    'focusRing': argbToHex(focusRing),
    'accent': argbToHex(accent),
    'digit': digit.toJson(),
    'operator': operator.toJson(),
    'equals': equals.toJson(),
    'function': function.toJson(),
    'shadow': argbToHex(shadow),
    'highlight': argbToHex(highlight),
    'seedColor': argbToHex(seedColor),
    if (lcdGhost case final ghost?) 'lcdGhost': argbToHex(ghost),
  };

  @override
  bool operator ==(Object other) =>
      other is Palette &&
      other.background == background &&
      other.surface == surface &&
      other.displayText == displayText &&
      other.previewText == previewText &&
      other.error == error &&
      other.caret == caret &&
      other.focusRing == focusRing &&
      other.accent == accent &&
      other.digit == digit &&
      other.operator == operator &&
      other.equals == equals &&
      other.function == function &&
      other.shadow == shadow &&
      other.highlight == highlight &&
      other.seedColor == seedColor &&
      other.lcdGhost == lcdGhost;

  @override
  int get hashCode => Object.hash(
    background,
    surface,
    displayText,
    previewText,
    error,
    caret,
    focusRing,
    accent,
    digit,
    operator,
    equals,
    function,
    shadow,
    highlight,
    seedColor,
    lcdGhost,
  );
}

/// The four key colour groups (see `KeyRole` → group mapping in the
/// resolver: digit/decimal/sign → digit; operator → operator; equals →
/// equals; everything else → function).
enum KeyGroup { digit, operator, equals, function }

// ------------------------------------------------------------------ shape --

/// Key outline (spec §5.1 KeyShape).
@immutable
final class KeyShapeSpec {
  const KeyShapeSpec({
    required this.kind,
    this.cornerPermille = 300,
    this.m3eShape,
    this.morphTo,
    this.morphCornerPermille,
    this.operatorKind,
    this.operatorM3eShape,
  });

  factory KeyShapeSpec.fromJson(Object? json) {
    final j = _map(json, 'KeyShapeSpec');
    return KeyShapeSpec(
      kind: _enumByName(KeyShapeKind.values, j['kind'], 'shape kind'),
      cornerPermille: _int(j, 'cornerPermille'),
      m3eShape: j['m3eShape'] == null
          ? null
          : _enumByName(M3eShape.values, j['m3eShape'], 'm3e shape'),
      morphTo: j['morphTo'] == null
          ? null
          : _enumByName(KeyShapeKind.values, j['morphTo'], 'morph target'),
      morphCornerPermille: _intOrNull(j, 'morphCornerPermille'),
      operatorKind: j['operatorKind'] == null
          ? null
          : _enumByName(KeyShapeKind.values, j['operatorKind'], 'op shape'),
      operatorM3eShape: j['operatorM3eShape'] == null
          ? null
          : _enumByName(M3eShape.values, j['operatorM3eShape'], 'op m3e'),
    );
  }

  /// Resting shape of digit and function keys.
  final KeyShapeKind kind;

  /// Resting corner radius as a fraction of the key's short side × 1000
  /// (0 = square, 500 = fully round).
  final int cornerPermille;

  /// Material shape-library id when [kind] is [KeyShapeKind.m3eMorph].
  final M3eShape? m3eShape;

  /// Shape the key morphs to when pressed (null = no shape morph).
  final KeyShapeKind? morphTo;

  /// Pressed corner radius (fraction of short side × 1000), if it changes.
  final int? morphCornerPermille;

  /// Different resting shape for operator / `=` keys (a non-colour cue);
  /// null = same as [kind].
  final KeyShapeKind? operatorKind;

  /// Material shape-library id for operator keys when [operatorKind] is
  /// [KeyShapeKind.m3eMorph]. Bauhaus reuses it for its `=` figure (disc,
  /// half-disc, fan or triangle; bauhaus.dart).
  final M3eShape? operatorM3eShape;

  /// Corner radius as a fraction (0–0.5) of the short side.
  double get cornerFraction => cornerPermille / 1000;

  KeyShapeSpec copyWith({
    KeyShapeKind? kind,
    int? cornerPermille,
    M3eShape? m3eShape,
    KeyShapeKind? morphTo,
    int? morphCornerPermille,
    KeyShapeKind? operatorKind,
    M3eShape? operatorM3eShape,
  }) => KeyShapeSpec(
    kind: kind ?? this.kind,
    cornerPermille: cornerPermille ?? this.cornerPermille,
    m3eShape: m3eShape ?? this.m3eShape,
    morphTo: morphTo ?? this.morphTo,
    morphCornerPermille: morphCornerPermille ?? this.morphCornerPermille,
    operatorKind: operatorKind ?? this.operatorKind,
    operatorM3eShape: operatorM3eShape ?? this.operatorM3eShape,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'cornerPermille': cornerPermille,
    'm3eShape': m3eShape?.name,
    'morphTo': morphTo?.name,
    'morphCornerPermille': morphCornerPermille,
    'operatorKind': operatorKind?.name,
    'operatorM3eShape': operatorM3eShape?.name,
  };

  @override
  bool operator ==(Object other) =>
      other is KeyShapeSpec &&
      other.kind == kind &&
      other.cornerPermille == cornerPermille &&
      other.m3eShape == m3eShape &&
      other.morphTo == morphTo &&
      other.morphCornerPermille == morphCornerPermille &&
      other.operatorKind == operatorKind &&
      other.operatorM3eShape == operatorM3eShape;

  @override
  int get hashCode => Object.hash(
    kind,
    cornerPermille,
    m3eShape,
    morphTo,
    morphCornerPermille,
    operatorKind,
    operatorM3eShape,
  );
}

// ------------------------------------------------------------------ style --

/// How key faces are drawn (spec §5.1 KeyStyle).
@immutable
final class KeyStyleSpec {
  const KeyStyleSpec({
    required this.kind,
    this.outlineWidthCdp = 0,
    this.extrudeDepthCdp = 0,
    this.shadowOffsetCdp = 0,
    this.shadowBlurCdp = 0,
    this.opacityPermille = 1000,
    this.edgeShadePermille = 0,
    this.stateLayerPermille = 100,
    this.frostPermille = 0,
    this.highlightPermille = 0,
    this.refractionPermille = 0,
  });

  factory KeyStyleSpec.fromJson(Object? json) {
    final j = _map(json, 'KeyStyleSpec');
    int optional(String k) => j[k] == null ? 0 : _int(j, k);
    return KeyStyleSpec(
      kind: _enumByName(KeyStyleKind.values, j['kind'], 'style kind'),
      outlineWidthCdp: _int(j, 'outlineWidthCdp'),
      extrudeDepthCdp: _int(j, 'extrudeDepthCdp'),
      shadowOffsetCdp: _int(j, 'shadowOffsetCdp'),
      shadowBlurCdp: _int(j, 'shadowBlurCdp'),
      opacityPermille: _int(j, 'opacityPermille'),
      edgeShadePermille: _int(j, 'edgeShadePermille'),
      stateLayerPermille: _int(j, 'stateLayerPermille'),
      frostPermille: optional('frostPermille'),
      highlightPermille: optional('highlightPermille'),
      refractionPermille: optional('refractionPermille'),
    );
  }

  final KeyStyleKind kind;

  /// Outline / rim stroke width, dp × 100 (0 = none).
  final int outlineWidthCdp;

  /// Extruded side depth (NeoPOP), dp × 100.
  final int extrudeDepthCdp;

  /// Hard or soft shadow offset, dp × 100.
  final int shadowOffsetCdp;

  /// Shadow blur radius, dp × 100 (0 = hard shadow).
  final int shadowBlurCdp;

  /// Face opacity × 1000 (glass < 1000).
  final int opacityPermille;

  /// How much darker the extruded sides are than the face, × 1000 of OKLab
  /// lightness (NeoPOP), when [KeyColors.edge] is derived at render time.
  /// Reused: Claymorphism's inner shade, Y2K's deep band under the gloss
  /// cap, Paper & ink's hatch opacity, Vaporwave's bevel shade.
  final int edgeShadePermille;

  /// Pressed state-layer opacity × 1000 (M3E +10 %).
  final int stateLayerPermille;

  /// Glass: how much of the backdrop the glass diffuses × 1000 (0 = clear,
  /// 1000 = the solid tint). The renderer lays the background's base
  /// colour under the tint at this opacity, so the face is still the tint
  /// composited over a point of the background's colour hull (what the
  /// guardrails sample). Liquid Glass only; serialised only when set, so
  /// every other theme's canonical JSON and stable hash are unchanged.
  final int frostPermille;

  /// Glass: specular highlight strength × 1000 (serialised only when set).
  /// Also Y2K's gloss-cap alpha and Vaporwave's bevel-highlight mix.
  final int highlightPermille;

  /// Glass: refraction hint strength × 1000 — edge lensing and dispersion
  /// (serialised only when set). Also Y2K's caustic alpha.
  final int refractionPermille;

  KeyStyleSpec copyWith({
    KeyStyleKind? kind,
    int? outlineWidthCdp,
    int? extrudeDepthCdp,
    int? shadowOffsetCdp,
    int? shadowBlurCdp,
    int? opacityPermille,
    int? edgeShadePermille,
    int? stateLayerPermille,
    int? frostPermille,
    int? highlightPermille,
    int? refractionPermille,
  }) => KeyStyleSpec(
    kind: kind ?? this.kind,
    outlineWidthCdp: outlineWidthCdp ?? this.outlineWidthCdp,
    extrudeDepthCdp: extrudeDepthCdp ?? this.extrudeDepthCdp,
    shadowOffsetCdp: shadowOffsetCdp ?? this.shadowOffsetCdp,
    shadowBlurCdp: shadowBlurCdp ?? this.shadowBlurCdp,
    opacityPermille: opacityPermille ?? this.opacityPermille,
    edgeShadePermille: edgeShadePermille ?? this.edgeShadePermille,
    stateLayerPermille: stateLayerPermille ?? this.stateLayerPermille,
    frostPermille: frostPermille ?? this.frostPermille,
    highlightPermille: highlightPermille ?? this.highlightPermille,
    refractionPermille: refractionPermille ?? this.refractionPermille,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'outlineWidthCdp': outlineWidthCdp,
    'extrudeDepthCdp': extrudeDepthCdp,
    'shadowOffsetCdp': shadowOffsetCdp,
    'shadowBlurCdp': shadowBlurCdp,
    'opacityPermille': opacityPermille,
    'edgeShadePermille': edgeShadePermille,
    'stateLayerPermille': stateLayerPermille,
    if (frostPermille != 0) 'frostPermille': frostPermille,
    if (highlightPermille != 0) 'highlightPermille': highlightPermille,
    if (refractionPermille != 0) 'refractionPermille': refractionPermille,
  };

  @override
  bool operator ==(Object other) =>
      other is KeyStyleSpec &&
      other.kind == kind &&
      other.outlineWidthCdp == outlineWidthCdp &&
      other.extrudeDepthCdp == extrudeDepthCdp &&
      other.shadowOffsetCdp == shadowOffsetCdp &&
      other.shadowBlurCdp == shadowBlurCdp &&
      other.opacityPermille == opacityPermille &&
      other.edgeShadePermille == edgeShadePermille &&
      other.stateLayerPermille == stateLayerPermille &&
      other.frostPermille == frostPermille &&
      other.highlightPermille == highlightPermille &&
      other.refractionPermille == refractionPermille;

  @override
  int get hashCode => Object.hash(
    kind,
    outlineWidthCdp,
    extrudeDepthCdp,
    shadowOffsetCdp,
    shadowBlurCdp,
    opacityPermille,
    edgeShadePermille,
    stateLayerPermille,
    frostPermille,
    highlightPermille,
    refractionPermille,
  );
}

// ------------------------------------------------------------------- type --

/// Typography (spec §5.1 Typography). Font ids are the stable strings of
/// `BundledFont.id` (`lib/themes/render/fonts.dart`), see [FontIds].
@immutable
final class TypeSpec {
  const TypeSpec({
    required this.displayFont,
    required this.keyFont,
    this.displayWeight = 400,
    this.keyWeight = 500,
    this.operatorWeight = 500,
    this.widthPermille = 1000,
    this.tabular = true,
    this.slashedZero = false,
    this.lcd = false,
  });

  factory TypeSpec.fromJson(Object? json) {
    final j = _map(json, 'TypeSpec');
    return TypeSpec(
      displayFont: _str(j, 'displayFont'),
      keyFont: _str(j, 'keyFont'),
      displayWeight: _int(j, 'displayWeight'),
      keyWeight: _int(j, 'keyWeight'),
      operatorWeight: _int(j, 'operatorWeight'),
      widthPermille: _int(j, 'widthPermille'),
      tabular: _bool(j, 'tabular'),
      slashedZero: _bool(j, 'slashedZero'),
      lcd: _bool(j, 'lcd'),
    );
  }

  /// Display (expression/result) font id.
  final String displayFont;

  /// Key label font id.
  final String keyFont;

  /// CSS-style weights (100–1000).
  final int displayWeight;
  final int keyWeight;

  /// Operator / `=` label weight (≥ keyWeight + 200 counts as a
  /// non-colour cue).
  final int operatorWeight;

  /// `wdth` axis × 10 (1000 = 100 %), where the font supports it.
  final int widthPermille;

  /// Tabular figures.
  final bool tabular;

  /// Slashed zero where supported.
  final bool slashedZero;

  /// 7-segment LCD display (retro).
  final bool lcd;

  TypeSpec copyWith({
    String? displayFont,
    String? keyFont,
    int? displayWeight,
    int? keyWeight,
    int? operatorWeight,
    int? widthPermille,
    bool? tabular,
    bool? slashedZero,
    bool? lcd,
  }) => TypeSpec(
    displayFont: displayFont ?? this.displayFont,
    keyFont: keyFont ?? this.keyFont,
    displayWeight: displayWeight ?? this.displayWeight,
    keyWeight: keyWeight ?? this.keyWeight,
    operatorWeight: operatorWeight ?? this.operatorWeight,
    widthPermille: widthPermille ?? this.widthPermille,
    tabular: tabular ?? this.tabular,
    slashedZero: slashedZero ?? this.slashedZero,
    lcd: lcd ?? this.lcd,
  );

  Map<String, Object?> toJson() => {
    'displayFont': displayFont,
    'keyFont': keyFont,
    'displayWeight': displayWeight,
    'keyWeight': keyWeight,
    'operatorWeight': operatorWeight,
    'widthPermille': widthPermille,
    'tabular': tabular,
    'slashedZero': slashedZero,
    'lcd': lcd,
  };

  @override
  bool operator ==(Object other) =>
      other is TypeSpec &&
      other.displayFont == displayFont &&
      other.keyFont == keyFont &&
      other.displayWeight == displayWeight &&
      other.keyWeight == keyWeight &&
      other.operatorWeight == operatorWeight &&
      other.widthPermille == widthPermille &&
      other.tabular == tabular &&
      other.slashedZero == slashedZero &&
      other.lcd == lcd;

  @override
  int get hashCode => Object.hash(
    displayFont,
    keyFont,
    displayWeight,
    keyWeight,
    operatorWeight,
    widthPermille,
    tabular,
    slashedZero,
    lcd,
  );
}

// ------------------------------------------------------------- background --

/// Background (spec §5.1 Background).
@immutable
final class BackgroundSpec {
  /// [colors] must be unmodifiable (a const literal, or wrapped with
  /// `List.unmodifiable`): specs are deeply immutable and cache their
  /// stable hash. The generator, `copyWith` and `fromJson` all comply.
  const BackgroundSpec({
    required this.kind,
    required this.colors,
    this.angleTenths = 0,
    this.pattern = BackgroundPattern.none,
    this.patternColor = 0,
    this.patternScaleCdp = 0,
    this.patternOpacityPermille = 0,
    this.driftPeriodMs = 0,
  });

  factory BackgroundSpec.fromJson(Object? json) {
    final j = _map(json, 'BackgroundSpec');
    final colors = j['colors'];
    if (colors is! List) throw const FormatException('Expected colors list');
    return BackgroundSpec(
      kind: _enumByName(BackgroundKind.values, j['kind'], 'background'),
      colors: List.unmodifiable(colors.map(argbFromHex)),
      angleTenths: _int(j, 'angleTenths'),
      pattern: _enumByName(BackgroundPattern.values, j['pattern'], 'pattern'),
      patternColor: argbFromHex(j['patternColor']),
      patternScaleCdp: _int(j, 'patternScaleCdp'),
      patternOpacityPermille: _int(j, 'patternOpacityPermille'),
      driftPeriodMs: _int(j, 'driftPeriodMs'),
    );
  }

  final BackgroundKind kind;

  /// Solid: one colour. Gradients: stops in order (evenly spaced). Mesh:
  /// control colours. Family scenes (`claySoft` … `bauhausComposition`):
  /// the scene's colour roles by index, documented by the family.
  final List<int> colors;

  /// Linear gradient direction, tenths of a degree (0 = top → bottom).
  /// Family scenes reuse it as a scene parameter (sphere layout, sun
  /// azimuth or holo angle, paper grain strength, gradient tilt, horizon
  /// height, poster orientation); same-family transitions lerp it along
  /// the shorter arc.
  final int angleTenths;

  final BackgroundPattern pattern;

  /// Pattern ink (usually translucent).
  final int patternColor;

  /// Pattern cell size, dp × 100.
  final int patternScaleCdp;

  /// Pattern opacity × 1000.
  final int patternOpacityPermille;

  /// Slow drift period for animated backgrounds (0 = static). Disabled by
  /// Reduce Motion at runtime.
  final int driftPeriodMs;

  /// The base colour (first stop).
  int get base => colors.first;

  BackgroundSpec copyWith({
    BackgroundKind? kind,
    List<int>? colors,
    int? angleTenths,
    BackgroundPattern? pattern,
    int? patternColor,
    int? patternScaleCdp,
    int? patternOpacityPermille,
    int? driftPeriodMs,
  }) => BackgroundSpec(
    kind: kind ?? this.kind,
    colors: colors == null ? this.colors : List.unmodifiable(colors),
    angleTenths: angleTenths ?? this.angleTenths,
    pattern: pattern ?? this.pattern,
    patternColor: patternColor ?? this.patternColor,
    patternScaleCdp: patternScaleCdp ?? this.patternScaleCdp,
    patternOpacityPermille:
        patternOpacityPermille ?? this.patternOpacityPermille,
    driftPeriodMs: driftPeriodMs ?? this.driftPeriodMs,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'colors': [for (final c in colors) argbToHex(c)],
    'angleTenths': angleTenths,
    'pattern': pattern.name,
    'patternColor': argbToHex(patternColor),
    'patternScaleCdp': patternScaleCdp,
    'patternOpacityPermille': patternOpacityPermille,
    'driftPeriodMs': driftPeriodMs,
  };

  @override
  bool operator ==(Object other) =>
      other is BackgroundSpec &&
      other.kind == kind &&
      _listEq(other.colors, colors) &&
      other.angleTenths == angleTenths &&
      other.pattern == pattern &&
      other.patternColor == patternColor &&
      other.patternScaleCdp == patternScaleCdp &&
      other.patternOpacityPermille == patternOpacityPermille &&
      other.driftPeriodMs == driftPeriodMs;

  @override
  int get hashCode => Object.hash(
    kind,
    Object.hashAll(colors),
    angleTenths,
    pattern,
    patternColor,
    patternScaleCdp,
    patternOpacityPermille,
    driftPeriodMs,
  );
}

// ----------------------------------------------------------------- motion --

/// Mass-1 spring, integer-encoded so hashing stays bit-exact (motion brief
/// §2.6). Convert with `SpringDescription.withDampingRatio(mass: 1,
/// stiffness: k, ratio: zetaPermille / 1000)` in the render layer.
@immutable
final class SpringToken {
  const SpringToken(this.stiffness, this.zetaPermille);

  factory SpringToken.fromJson(Object? json) {
    if (json is List && json.length == 2 && json[0] is int && json[1] is int) {
      return SpringToken(json[0] as int, json[1] as int);
    }
    throw FormatException('Expected [k, zeta*1000]: $json');
  }

  /// k (N/m with mass 1).
  final int stiffness;

  /// Damping ratio ζ × 1000 (bounce = 1 − ζ).
  final int zetaPermille;

  /// ζ as a double.
  double get dampingRatio => zetaPermille / 1000;

  List<int> toJson() => [stiffness, zetaPermille];

  @override
  bool operator ==(Object other) =>
      other is SpringToken &&
      other.stiffness == stiffness &&
      other.zetaPermille == zetaPermille;

  @override
  int get hashCode => Object.hash(stiffness, zetaPermille);

  @override
  String toString() => 'SpringToken($stiffness, $zetaPermille)';
}

/// The shared spring scale (motion brief §2.1), as integers.
abstract final class SpringTokens {
  static const SpringToken expressiveFast = SpringToken(800, 600);
  static const SpringToken expressiveNormal = SpringToken(380, 800);
  static const SpringToken expressiveSlow = SpringToken(200, 800);
  static const SpringToken standardFast = SpringToken(1400, 900);
  static const SpringToken standardNormal = SpringToken(700, 900);
  static const SpringToken standardSlow = SpringToken(300, 900);
  static const SpringToken effectsFast = SpringToken(3800, 1000);
  static const SpringToken effectsDefault = SpringToken(1600, 1000);
  static const SpringToken effectsSlow = SpringToken(800, 1000);

  /// Ours: 39 ms to 90 %, hard plunk families.
  static const SpringToken hardPress = SpringToken(10000, 1000);

  /// `withDurationAndBounce(150 ms, 0.15)`.
  static const SpringToken glassPressIn = SpringToken(1755, 850);

  /// Release starts no earlier than this after touch-down (ms).
  static const int minPressMs = 40;

  /// Reduce Motion fades (ms).
  static const int fadeFastMs = 100;
  static const int fadeMs = 150;

  /// (fast, normal, slow) spatial springs of [scheme].
  static (SpringToken, SpringToken, SpringToken) scale(MotionScheme scheme) =>
      switch (scheme) {
        MotionScheme.expressive => (
          expressiveFast,
          expressiveNormal,
          expressiveSlow,
        ),
        MotionScheme.standard => (standardFast, standardNormal, standardSlow),
      };
}

/// Per-theme motion tokens (spec §5.1 Motion; motion brief §2.3, §2.6).
/// Integers only. Runtime adjustments (Reduce Motion, input amplitude,
/// battery tier) are applied by the render layer and never stored here.
@immutable
final class MotionSpec {
  const MotionSpec({
    required this.verb,
    required this.scheme,
    required this.pressIn,
    required this.release,
    required this.entry,
    required this.impact,
    this.releaseAlt,
    this.depthCdp = 0,
    this.scalePermille = 1000,
    this.cornerPermille = 0,
    this.squishPermille = 0,
    this.stateLayerSnap = false,
    this.entryScalePermille = 1000,
    this.entryOffsetCdp = 0,
    this.entrySpring,
    this.fx = PressFx.none,
    this.stepMs = 0,
    this.impactPermille = 800,
    this.releaseHaptic = false,
    this.releaseImpactPermille = 0,
  });

  factory MotionSpec.fromJson(Object? json) {
    final j = _map(json, 'MotionSpec');
    return MotionSpec(
      verb: _enumByName(PressVerb.values, j['verb'], 'verb'),
      scheme: _enumByName(MotionScheme.values, j['scheme'], 'scheme'),
      pressIn: SpringToken.fromJson(j['pressIn']),
      release: SpringToken.fromJson(j['release']),
      releaseAlt: j['releaseAlt'] == null
          ? null
          : SpringToken.fromJson(j['releaseAlt']),
      depthCdp: _int(j, 'depthCdp'),
      scalePermille: _int(j, 'scalePermille'),
      cornerPermille: _int(j, 'cornerPermille'),
      squishPermille: _int(j, 'squishPermille'),
      stateLayerSnap: _bool(j, 'stateLayerSnap'),
      entry: _enumByName(EntryStyle.values, j['entry'], 'entry'),
      entryScalePermille: _int(j, 'entryScalePermille'),
      entryOffsetCdp: _int(j, 'entryOffsetCdp'),
      entrySpring: j['entrySpring'] == null
          ? null
          : SpringToken.fromJson(j['entrySpring']),
      fx: _enumByName(PressFx.values, j['fx'], 'fx'),
      stepMs: _int(j, 'stepMs'),
      impact: _enumByName(ImpactStyle.values, j['impact'], 'impact'),
      impactPermille: _int(j, 'impactPermille'),
      releaseHaptic: _bool(j, 'releaseHaptic'),
      releaseImpactPermille: _int(j, 'releaseImpactPermille'),
    );
  }

  final PressVerb verb;

  /// UI motion scale (`=`, panels, theme shapes).
  final MotionScheme scheme;

  /// Press-in spring (never seeded: frame-1 feedback is identical across
  /// themes of a family).
  final SpringToken pressIn;

  /// Release spring (seeded × {0.9, 1.0, 1.1}).
  final SpringToken release;

  /// Second release spring: M3E corners, glass Y axis.
  final SpringToken? releaseAlt;

  /// dp × 100: translate depth (NeoPOP d), travel, or shadow size.
  final int depthCdp;

  /// Pressed scale × 1000 (< 1000 shrinks, > 1000 inflates).
  final int scalePermille;

  /// Pressed corner as a fraction of the short side × 1000 (M3E 300).
  final int cornerPermille;

  /// M3E row-neighbour squish × 1000 of key width.
  final int squishPermille;

  /// Snap a state layer in frame 1 (M3E +10 %).
  final bool stateLayerSnap;

  final EntryStyle entry;

  /// Display glyph entry start scale × 1000 (M3E pop 850 → 1000).
  final int entryScalePermille;

  /// Display glyph entry start offset, dp × 100 (NeoPOP drop −600 → 0).
  final int entryOffsetCdp;

  /// Spring for the display entry (null = [release]).
  final SpringToken? entrySpring;

  final PressFx fx;

  /// 0 = continuous; Pixel samples at 67 ms.
  final int stepMs;

  /// Haptic profile: impact style and intensity × 1000 on touch-down.
  final ImpactStyle impact;
  final int impactPermille;

  /// Also fire a haptic on release (NeoPOP, Retro).
  final bool releaseHaptic;

  /// Release haptic intensity × 1000.
  final int releaseImpactPermille;

  MotionSpec copyWith({
    PressVerb? verb,
    MotionScheme? scheme,
    SpringToken? pressIn,
    SpringToken? release,
    SpringToken? releaseAlt,
    int? depthCdp,
    int? scalePermille,
    int? cornerPermille,
    int? squishPermille,
    bool? stateLayerSnap,
    EntryStyle? entry,
    int? entryScalePermille,
    int? entryOffsetCdp,
    SpringToken? entrySpring,
    PressFx? fx,
    int? stepMs,
    ImpactStyle? impact,
    int? impactPermille,
    bool? releaseHaptic,
    int? releaseImpactPermille,
  }) => MotionSpec(
    verb: verb ?? this.verb,
    scheme: scheme ?? this.scheme,
    pressIn: pressIn ?? this.pressIn,
    release: release ?? this.release,
    releaseAlt: releaseAlt ?? this.releaseAlt,
    depthCdp: depthCdp ?? this.depthCdp,
    scalePermille: scalePermille ?? this.scalePermille,
    cornerPermille: cornerPermille ?? this.cornerPermille,
    squishPermille: squishPermille ?? this.squishPermille,
    stateLayerSnap: stateLayerSnap ?? this.stateLayerSnap,
    entry: entry ?? this.entry,
    entryScalePermille: entryScalePermille ?? this.entryScalePermille,
    entryOffsetCdp: entryOffsetCdp ?? this.entryOffsetCdp,
    entrySpring: entrySpring ?? this.entrySpring,
    fx: fx ?? this.fx,
    stepMs: stepMs ?? this.stepMs,
    impact: impact ?? this.impact,
    impactPermille: impactPermille ?? this.impactPermille,
    releaseHaptic: releaseHaptic ?? this.releaseHaptic,
    releaseImpactPermille: releaseImpactPermille ?? this.releaseImpactPermille,
  );

  Map<String, Object?> toJson() => {
    'verb': verb.name,
    'scheme': scheme.name,
    'pressIn': pressIn.toJson(),
    'release': release.toJson(),
    'releaseAlt': releaseAlt?.toJson(),
    'depthCdp': depthCdp,
    'scalePermille': scalePermille,
    'cornerPermille': cornerPermille,
    'squishPermille': squishPermille,
    'stateLayerSnap': stateLayerSnap,
    'entry': entry.name,
    'entryScalePermille': entryScalePermille,
    'entryOffsetCdp': entryOffsetCdp,
    'entrySpring': entrySpring?.toJson(),
    'fx': fx.name,
    'stepMs': stepMs,
    'impact': impact.name,
    'impactPermille': impactPermille,
    'releaseHaptic': releaseHaptic,
    'releaseImpactPermille': releaseImpactPermille,
  };

  @override
  bool operator ==(Object other) =>
      other is MotionSpec &&
      other.verb == verb &&
      other.scheme == scheme &&
      other.pressIn == pressIn &&
      other.release == release &&
      other.releaseAlt == releaseAlt &&
      other.depthCdp == depthCdp &&
      other.scalePermille == scalePermille &&
      other.cornerPermille == cornerPermille &&
      other.squishPermille == squishPermille &&
      other.stateLayerSnap == stateLayerSnap &&
      other.entry == entry &&
      other.entryScalePermille == entryScalePermille &&
      other.entryOffsetCdp == entryOffsetCdp &&
      other.entrySpring == entrySpring &&
      other.fx == fx &&
      other.stepMs == stepMs &&
      other.impact == impact &&
      other.impactPermille == impactPermille &&
      other.releaseHaptic == releaseHaptic &&
      other.releaseImpactPermille == releaseImpactPermille;

  @override
  int get hashCode => Object.hashAll([
    verb,
    scheme,
    pressIn,
    release,
    releaseAlt,
    depthCdp,
    scalePermille,
    cornerPermille,
    squishPermille,
    stateLayerSnap,
    entry,
    entryScalePermille,
    entryOffsetCdp,
    entrySpring,
    fx,
    stepMs,
    impact,
    impactPermille,
    releaseHaptic,
    releaseImpactPermille,
  ]);
}

// ---------------------------------------------------------------- effects --

/// Optional ambient effect (spec §5.1 Effects). M3 families use [none].
/// Effects never animate behind the display text (spec §5.4).
@immutable
final class EffectsSpec {
  const EffectsSpec({
    this.kind = EffectKind.none,
    this.intensityPermille = 0,
    this.color = 0,
    this.densityPermille = 0,
  });

  factory EffectsSpec.fromJson(Object? json) {
    final j = _map(json, 'EffectsSpec');
    return EffectsSpec(
      kind: _enumByName(EffectKind.values, j['kind'], 'effect'),
      intensityPermille: _int(j, 'intensityPermille'),
      color: argbFromHex(j['color']),
      densityPermille: _int(j, 'densityPermille'),
    );
  }

  /// No effect.
  static const EffectsSpec none = EffectsSpec();

  final EffectKind kind;
  final int intensityPermille;
  final int color;
  final int densityPermille;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'intensityPermille': intensityPermille,
    'color': argbToHex(color),
    'densityPermille': densityPermille,
  };

  @override
  bool operator ==(Object other) =>
      other is EffectsSpec &&
      other.kind == kind &&
      other.intensityPermille == intensityPermille &&
      other.color == color &&
      other.densityPermille == densityPermille;

  @override
  int get hashCode =>
      Object.hash(kind, intensityPermille, color, densityPermille);
}

// ------------------------------------------------------------- ThemeSpec --

/// A complete theme (spec §5.1). Immutable; `==` compares every field;
/// [hashCode] is [stableHash], identical on every run and platform.
@immutable
final class ThemeSpec {
  const ThemeSpec({
    required this.seed,
    required this.family,
    required this.engineVersion,
    required this.brightness,
    required this.palette,
    required this.keyShape,
    required this.keyStyle,
    required this.type,
    required this.background,
    required this.motion,
    required this.sound,
    required this.name,
    this.variant = ThemeVariant.generated,
    this.heroId,
    this.seedHueTenths,
    this.accessible = false,
    this.effects = EffectsSpec.none,
    this.nonColourOperatorCue = OperatorCue.none,
  });

  factory ThemeSpec.fromJson(Object? json) {
    final j = _map(json, 'ThemeSpec');
    final format = _int(j, 'format');
    if (format != jsonFormat) {
      throw FormatException('Unsupported ThemeSpec format $format');
    }
    final familyId = _int(j, 'family');
    final family = ThemeFamily.fromId(familyId);
    if (family == null) throw FormatException('Unknown family $familyId');
    return ThemeSpec(
      seed: _int(j, 'seed'),
      family: family,
      engineVersion: _int(j, 'engineVersion'),
      variant: _enumByName(ThemeVariant.values, j['variant'], 'variant'),
      heroId: _intOrNull(j, 'heroId'),
      seedHueTenths: _intOrNull(j, 'seedHueTenths'),
      brightness: _enumByName(
        ThemeBrightness.values,
        j['brightness'],
        'brightness',
      ),
      accessible: _bool(j, 'accessible'),
      palette: Palette.fromJson(j['palette']),
      keyShape: KeyShapeSpec.fromJson(j['keyShape']),
      keyStyle: KeyStyleSpec.fromJson(j['keyStyle']),
      type: TypeSpec.fromJson(j['type']),
      background: BackgroundSpec.fromJson(j['background']),
      motion: MotionSpec.fromJson(j['motion']),
      effects: EffectsSpec.fromJson(j['effects']),
      sound: _enumByName(SoundPackId.values, j['sound'], 'sound'),
      name: _str(j, 'name'),
      nonColourOperatorCue: _enumByName(
        OperatorCue.values,
        j['nonColourOperatorCue'],
        'operator cue',
      ),
    );
  }

  /// Parses [source] produced by [toJsonString].
  factory ThemeSpec.fromJsonString(String source) =>
      ThemeSpec.fromJson(jsonDecode(source));

  /// Version of the JSON layout (not the generator; see [engineVersion]).
  static const int jsonFormat = 1;

  /// 32-bit unsigned seed.
  final int seed;

  final ThemeFamily family;

  /// Generator version that produced this theme (share codes carry it).
  final int engineVersion;

  final ThemeVariant variant;

  /// Hero id when [variant] is [ThemeVariant.hero].
  final int? heroId;

  /// The base hue (tenths of a degree) that replaced the palette draw, for
  /// the [ThemeVariant.wallpaper] variant ("Match my wallpaper"); null
  /// otherwise. Serialised only when set, so every other theme's canonical
  /// JSON and stable hash are unchanged.
  final int? seedHueTenths;

  final ThemeBrightness brightness;

  /// Generated under the Accessible lock (labels ≥ 7:1, rims ≥ 3:1).
  final bool accessible;

  final Palette palette;
  final KeyShapeSpec keyShape;
  final KeyStyleSpec keyStyle;
  final TypeSpec type;
  final BackgroundSpec background;
  final MotionSpec motion;
  final EffectsSpec effects;

  /// Default sound pack (a user-pinned pack overrides it at runtime and is
  /// not part of the theme).
  final SoundPackId sound;

  /// Generated name, e.g. "Mango Midnight".
  final String name;

  /// The non-colour cue the family supplies for operator / `=` keys, if
  /// the guardrail relies on it (spec §5.4).
  final OperatorCue nonColourOperatorCue;

  /// Whether this is a dark theme.
  bool get isDark => brightness == ThemeBrightness.dark;

  ThemeSpec copyWith({
    int? seed,
    ThemeFamily? family,
    int? engineVersion,
    ThemeVariant? variant,
    int? heroId,
    int? seedHueTenths,
    ThemeBrightness? brightness,
    bool? accessible,
    Palette? palette,
    KeyShapeSpec? keyShape,
    KeyStyleSpec? keyStyle,
    TypeSpec? type,
    BackgroundSpec? background,
    MotionSpec? motion,
    EffectsSpec? effects,
    SoundPackId? sound,
    String? name,
    OperatorCue? nonColourOperatorCue,
  }) => ThemeSpec(
    seed: seed ?? this.seed,
    family: family ?? this.family,
    engineVersion: engineVersion ?? this.engineVersion,
    variant: variant ?? this.variant,
    heroId: heroId ?? this.heroId,
    seedHueTenths: seedHueTenths ?? this.seedHueTenths,
    brightness: brightness ?? this.brightness,
    accessible: accessible ?? this.accessible,
    palette: palette ?? this.palette,
    keyShape: keyShape ?? this.keyShape,
    keyStyle: keyStyle ?? this.keyStyle,
    type: type ?? this.type,
    background: background ?? this.background,
    motion: motion ?? this.motion,
    effects: effects ?? this.effects,
    sound: sound ?? this.sound,
    name: name ?? this.name,
    nonColourOperatorCue: nonColourOperatorCue ?? this.nonColourOperatorCue,
  );

  /// Canonical JSON (fixed key order, colours as `aarrggbb`).
  Map<String, Object?> toJson() => {
    'format': jsonFormat,
    'seed': seed,
    'family': family.id,
    'engineVersion': engineVersion,
    'variant': variant.name,
    'heroId': heroId,
    'seedHueTenths': ?seedHueTenths,
    'brightness': brightness.name,
    'accessible': accessible,
    'palette': palette.toJson(),
    'keyShape': keyShape.toJson(),
    'keyStyle': keyStyle.toJson(),
    'type': type.toJson(),
    'background': background.toJson(),
    'motion': motion.toJson(),
    'effects': effects.toJson(),
    'sound': sound.name,
    'name': name,
    'nonColourOperatorCue': nonColourOperatorCue.name,
  };

  /// [toJson] encoded as a compact string (byte-identical everywhere).
  String toJsonString() => jsonEncode(toJson());

  /// FNV-1a-32 over the UTF-8 bytes of [toJsonString]: identical on every
  /// run and platform (unlike `Object.hash`, which is seeded per process).
  int get stableHash => _hashCache[this] ??= stableHash32(toJsonString());

  static final Expando<int> _hashCache = Expando<int>('ThemeSpec.stableHash');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThemeSpec &&
          other.seed == seed &&
          other.family == family &&
          other.engineVersion == engineVersion &&
          other.variant == variant &&
          other.heroId == heroId &&
          other.seedHueTenths == seedHueTenths &&
          other.brightness == brightness &&
          other.accessible == accessible &&
          other.palette == palette &&
          other.keyShape == keyShape &&
          other.keyStyle == keyStyle &&
          other.type == type &&
          other.background == background &&
          other.motion == motion &&
          other.effects == effects &&
          other.sound == sound &&
          other.name == name &&
          other.nonColourOperatorCue == nonColourOperatorCue;

  @override
  int get hashCode => stableHash;

  @override
  String toString() =>
      'ThemeSpec(${family.name}, seed: 0x${seed.toRadixString(16)}, '
      'v$engineVersion, "$name")';
}

/// FNV-1a-32 over the UTF-8 encoding of [s] (32-bit safe on the web).
int stableHash32(String s) {
  var h = 0x811C9DC5;
  for (final byte in utf8.encode(s)) {
    h = mul32((h ^ byte) & 0xFFFFFFFF, 0x01000193);
  }
  return h;
}
