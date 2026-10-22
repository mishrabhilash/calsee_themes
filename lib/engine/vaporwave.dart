/// The Vaporwave family (family id 14): late-night mall-soft and outrun.
/// A striped retro sun sinking into a neon perspective-grid floor under a
/// sunset sky, with a floating Windows-95-era window for the display and
/// chunky bevelled buttons in pastel periwinkle, lavender, lilac or baby
/// pink (function keys also peach), plus hot-pink, magenta, violet or
/// coral and cyan or aqua accents. Pure
/// Dart: part of the generator, so every constant here is part of the
/// family's engine-v3 definition and must not change without a version
/// bump once a build ships it.
///
/// - **Scene** (`BackgroundKind.vaporSunset`, painted by
///   `render/vaporwave/vaporwave_scene.dart`): one of four variants —
///   `dusk` and `midnight` (dark), `pastel` and `aqua` (light). Its ten
///   `BackgroundSpec.colors` are, in order: sky top (also
///   `Palette.background`), sky middle, horizon glow, sun top, sun middle,
///   sun bottom, floor at the horizon, floor at the bottom, grid lines and
///   the horizon line (also the haze over the far floor). `angleTenths` is
///   the horizon height in permille of
///   the scene when the painter has no display rectangle to anchor it to
///   (380–460); `driftPeriodMs` (48 s) switches the grid's slow drift on.
/// - **Keys**: square Win95 buttons (corners 0, 10 or 20 ‰ of the key's
///   short side: at most about 2 dp on desktop), a 1 dp ink line
///   (`Palette.shadow` = every `KeyColors.edge`), a hard two-tone bevel
///   derived from the face at paint time, and a face that never moves:
///   the bevel inverts in frame 1 and the label travels (+d, +d). Digit and
///   function faces are pastels at Win95-grey lightness (L 0.79–0.83);
///   the warm accent sits below them (L 0.66–0.71; 0.72–0.75 under the
///   Accessible lock) and the cool accent above (L 0.88–0.92), so
///   operators and `=` stand apart in lightness as well as hue. Operators
///   always carry a label ≥ 200 heavier ([OperatorCue.weight]).
/// - **Display**: an opaque client panel (`Palette.surface`) inside a
///   bevelled window whose titleless title bar runs from
///   `Palette.highlight` to `Palette.accent` (the accent pair, or a
///   classic navy → teal).
///
/// Every draw comes from the generator's named sub-streams (`palette` and
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), so a theme is a pure function of (seed, engineVersion,
/// accessible).
library;

import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

// ------------------------------------------------------------- constants --

/// The four scene variants.
enum VaporScene {
  /// Dark: indigo → violet sky, hot-pink glow, neon magenta grid.
  dusk,

  /// Dark: navy sky, magenta haze, electric-violet grid.
  midnight,

  /// Light: pink-lilac sky, butter → hot-pink sun, lilac grid.
  pastel,

  /// Light: periwinkle → aqua → pink sky, teal grid.
  aqua,
}

/// Dark themes: `[dusk, midnight]` weights.
const List<int> vaporwaveDarkSceneWeights = [3, 2];

/// Light themes: `[pastel, aqua]` weights.
const List<int> vaporwaveLightSceneWeights = [3, 2];

/// One accent of a pair: centre hue (tenths), ± jitter (tenths), and
/// whether it is the warm (darker) or the cool (lighter) neon.
typedef VaporAccent = ({int hueTenths, int jitterTenths, bool warm});

/// Accent pairs: operator and `=` are always one warm and one cool neon.
const List<({VaporAccent op, VaporAccent eq, int weight})>
vaporwaveAccentPairs = [
  // pink / cyan
  (
    op: (hueTenths: 3550, jitterTenths: 80, warm: true),
    eq: (hueTenths: 2050, jitterTenths: 80, warm: false),
    weight: 4,
  ),
  // cyan / pink
  (
    op: (hueTenths: 2050, jitterTenths: 80, warm: false),
    eq: (hueTenths: 3550, jitterTenths: 80, warm: true),
    weight: 4,
  ),
  // magenta / aqua
  (
    op: (hueTenths: 3300, jitterTenths: 80, warm: true),
    eq: (hueTenths: 1800, jitterTenths: 60, warm: false),
    weight: 2,
  ),
  // aqua / magenta
  (
    op: (hueTenths: 1800, jitterTenths: 60, warm: false),
    eq: (hueTenths: 3300, jitterTenths: 80, warm: true),
    weight: 2,
  ),
  // violet / cyan
  (
    op: (hueTenths: 3000, jitterTenths: 60, warm: true),
    eq: (hueTenths: 2050, jitterTenths: 80, warm: false),
    weight: 2,
  ),
  // coral / aqua
  (
    op: (hueTenths: 350, jitterTenths: 60, warm: true),
    eq: (hueTenths: 1800, jitterTenths: 60, warm: false),
    weight: 2,
  ),
];

/// Warm accent lightness (× 1000), and its range under the Accessible lock
/// (the same draw mapped onto it, so both modes draw alike).
const IntRange vaporwaveWarmLMilli = IntRange(660, 710);
const int vaporwaveWarmAccessibleFloorMilli = 720;
const IntRange vaporwaveWarmAccessibleLMilli = IntRange(720, 750);

/// Cool accent lightness (× 1000).
const IntRange vaporwaveCoolLMilli = IntRange(880, 920);

/// Accent chroma: `rel × maxChroma(L, h)`, rel in permille, capped.
const IntRange vaporwaveAccentChromaRel = IntRange(850, 1000);
const int vaporwaveAccentChromaCapMilli = 200;

/// Pastel key hues: `(centre, ± jitter, weight)` in tenths, ordered by hue
/// (peach, mint, periwinkle, lavender, lilac, baby pink).
const List<({int hueTenths, int jitterTenths, int weight})> vaporwavePastels = [
  (hueTenths: 500, jitterTenths: 60, weight: 1),
  (hueTenths: 1800, jitterTenths: 100, weight: 2),
  (hueTenths: 2650, jitterTenths: 80, weight: 1),
  (hueTenths: 3000, jitterTenths: 80, weight: 3),
  (hueTenths: 3300, jitterTenths: 80, weight: 2),
  (hueTenths: 3550, jitterTenths: 80, weight: 2),
];

/// The pastels a digit face may take: periwinkle, lavender, lilac and baby
/// pink (indices 2–5). Peach and mint are function-key colours only (beige
/// digits read as a 90s office PC, Retro's keycaps); a draw of either
/// becomes lavender before the search for a hue clear of the accents.
const int vaporwaveDigitPastelFirst = 2;
const int vaporwaveDigitPastelLast = 5;
const int vaporwaveDigitPastelRemap = 3;

/// Function-key pastel: `(digit index + step) % 6`, step weights.
const List<({int step, int weight})> vaporwaveFunctionSteps = [
  (step: 3, weight: 2),
  (step: 2, weight: 1),
  (step: 4, weight: 1),
];

/// Digit and function faces: Win95-grey lightness, pastel chroma (the
/// digit floor 0.048 keeps every face at C ≥ 0.045 after 8-bit rounding).
const IntRange vaporwaveDigitLMilli = IntRange(790, 830);
const IntRange vaporwaveDigitChromaMilli = IntRange(48, 70);
const IntRange vaporwaveFunctionLMilli = IntRange(790, 830);
const IntRange vaporwaveFunctionChromaMilli = IntRange(55, 80);

/// Faces with a hue in 340–80° (baby pink, peach) map their chroma draw
/// onto this range instead: at L 0.8 a peach or pink below C 0.065 reads
/// as cardboard or dusty rose, not pastel.
const IntRange vaporwaveWarmPastelChromaMilli = IntRange(65, 85);
const IntRange vaporwaveWarmPastelHueTenths = IntRange(3400, 800);

/// Minimum hue distances (tenths) of the digit pastel from the warm and
/// cool accents, and of the function pastel from both and the digit.
const int vaporwaveDigitWarmGap = 450;
const int vaporwaveDigitCoolGap = 600;
const int vaporwaveFunctionWarmGap = 450;
const int vaporwaveFunctionCoolGap = 600;
const int vaporwaveFunctionDigitGap = 600;

/// Where a scene colour's hue comes from.
enum VaporHue {
  /// Drawn from the entry's range (`nextIntIn(lo, hi) % 3600`).
  drawn,

  /// The accent pair's warm hue (no draw).
  warm,

  /// The accent pair's cool hue (no draw).
  cool,
}

/// One scene colour: lightness (× 1000), chroma (absolute, or relative to
/// the gamut and capped) and hue.
final class VaporTone {
  const VaporTone(
    this.lMilli,
    this.chroma, [
    this.hueTenths = const IntRange(0, 0),
    this.hue = VaporHue.drawn,
  ]);

  final IntRange lMilli;
  final ChromaRange chroma;

  /// Drawn hue range in tenths (`hi` may exceed 3600: it wraps).
  final IntRange hueTenths;
  final VaporHue hue;
}

/// Scene colour tables, indices 0–9 as documented in the library comment.
const Map<VaporScene, List<VaporTone>> vaporwaveSceneTones = {
  VaporScene.dusk: [
    VaporTone(
      IntRange(170, 210),
      ChromaRange.abs(70, 100),
      IntRange(2850, 2950),
    ),
    VaporTone(
      IntRange(300, 350),
      ChromaRange.abs(120, 150),
      IntRange(3100, 3200),
    ),
    VaporTone(
      IntRange(400, 460),
      ChromaRange.rel(850, 1000, 180),
      IntRange(3250, 3400),
    ),
    VaporTone(
      IntRange(640, 660),
      ChromaRange.rel(900, 1000, 250),
      IntRange(300, 400),
    ),
    VaporTone(
      IntRange(600, 640),
      ChromaRange.rel(900, 1000, 230),
      IntRange(0, 100),
    ),
    VaporTone(
      IntRange(560, 600),
      ChromaRange.rel(900, 1000, 240),
      IntRange(3300, 3450),
    ),
    VaporTone(
      IntRange(250, 290),
      ChromaRange.abs(90, 120),
      IntRange(3050, 3150),
    ),
    VaporTone(
      IntRange(120, 150),
      ChromaRange.abs(40, 60),
      IntRange(2850, 2950),
    ),
    VaporTone(
      IntRange(600, 630),
      ChromaRange.rel(900, 1000, 260),
      IntRange(3300, 3400),
    ),
    VaporTone(
      IntRange(620, 650),
      ChromaRange.rel(900, 1000, 240),
      IntRange(0, 0),
      VaporHue.warm,
    ),
  ],
  VaporScene.midnight: [
    VaporTone(
      IntRange(130, 160),
      ChromaRange.abs(40, 70),
      IntRange(2600, 2700),
    ),
    VaporTone(
      IntRange(220, 260),
      ChromaRange.abs(80, 110),
      IntRange(2850, 2950),
    ),
    VaporTone(
      IntRange(360, 420),
      ChromaRange.rel(850, 1000, 180),
      IntRange(3200, 3350),
    ),
    // A cooler night sun than dusk's: hot pink → magenta → violet.
    VaporTone(
      IntRange(640, 660),
      ChromaRange.rel(900, 1000, 250),
      IntRange(3500, 3650),
    ),
    VaporTone(
      IntRange(600, 640),
      ChromaRange.rel(900, 1000, 230),
      IntRange(3300, 3400),
    ),
    VaporTone(
      IntRange(560, 600),
      ChromaRange.rel(900, 1000, 240),
      IntRange(2950, 3100),
    ),
    VaporTone(
      IntRange(200, 230),
      ChromaRange.abs(50, 80),
      IntRange(2700, 2800),
    ),
    VaporTone(IntRange(90, 120), ChromaRange.abs(20, 40), IntRange(2650, 2750)),
    VaporTone(
      IntRange(600, 640),
      ChromaRange.rel(900, 1000, 250),
      IntRange(2900, 3050),
    ),
    VaporTone(
      IntRange(620, 650),
      ChromaRange.rel(900, 1000, 240),
      IntRange(0, 0),
      VaporHue.warm,
    ),
  ],
  VaporScene.pastel: [
    VaporTone(
      IntRange(820, 860),
      ChromaRange.abs(50, 80),
      IntRange(3150, 3300),
    ),
    VaporTone(
      IntRange(860, 900),
      ChromaRange.abs(50, 80),
      IntRange(3450, 3600),
    ),
    VaporTone(IntRange(900, 930), ChromaRange.abs(50, 70), IntRange(400, 600)),
    VaporTone(
      IntRange(880, 920),
      ChromaRange.rel(800, 1000, 130),
      IntRange(850, 950),
    ),
    VaporTone(
      IntRange(780, 820),
      ChromaRange.rel(800, 1000, 140),
      IntRange(500, 600),
    ),
    VaporTone(
      IntRange(680, 720),
      ChromaRange.rel(850, 1000, 180),
      IntRange(3550, 3650),
    ),
    // A lilac floor a clear step below the pastel keys, with a pale pink
    // neon grid.
    VaporTone(
      IntRange(660, 700),
      ChromaRange.abs(80, 100),
      IntRange(3000, 3100),
    ),
    VaporTone(
      IntRange(580, 620),
      ChromaRange.abs(100, 120),
      IntRange(2950, 3050),
    ),
    VaporTone(
      IntRange(900, 930),
      ChromaRange.abs(40, 60),
      IntRange(3300, 3450),
    ),
    VaporTone(
      IntRange(640, 680),
      ChromaRange.rel(850, 1000, 200),
      IntRange(0, 0),
      VaporHue.warm,
    ),
  ],
  VaporScene.aqua: [
    VaporTone(
      IntRange(840, 880),
      ChromaRange.abs(50, 80),
      IntRange(2500, 2650),
    ),
    VaporTone(
      IntRange(880, 910),
      ChromaRange.abs(40, 60),
      IntRange(1900, 2100),
    ),
    VaporTone(
      IntRange(890, 920),
      ChromaRange.abs(50, 70),
      IntRange(3450, 3600),
    ),
    VaporTone(
      IntRange(860, 900),
      ChromaRange.rel(800, 1000, 100),
      IntRange(3450, 3550),
    ),
    VaporTone(
      IntRange(760, 800),
      ChromaRange.rel(850, 1000, 150),
      IntRange(3400, 3500),
    ),
    VaporTone(
      IntRange(660, 700),
      ChromaRange.rel(850, 1000, 200),
      IntRange(3300, 3400),
    ),
    // A mauve floor a clear step below the pastel keys, with a light
    // neon grid in the cool accent's hue.
    VaporTone(
      IntRange(680, 720),
      ChromaRange.abs(60, 80),
      IntRange(3150, 3300),
    ),
    VaporTone(
      IntRange(580, 620),
      ChromaRange.abs(80, 100),
      IntRange(3050, 3200),
    ),
    VaporTone(
      IntRange(880, 920),
      ChromaRange.rel(900, 1000, 120),
      IntRange(0, 0),
      VaporHue.cool,
    ),
    VaporTone(
      IntRange(640, 680),
      ChromaRange.rel(850, 1000, 220),
      IntRange(0, 0),
      VaporHue.warm,
    ),
  ],
};

/// Night scenes keep every colour at or below this luminance (and day
/// scenes at or above [vaporwaveLightSceneMinY]), so one focus-ring colour
/// is legible on the whole scene.
const double vaporwaveDarkSceneMaxY = 0.250;
const double vaporwaveLightSceneMinY = 0.185;

/// The validator's band (a little looser than the generator's clamp).
const double vaporwaveDarkSceneCheckY = 0.26;
const double vaporwaveLightSceneCheckY = 0.17;

/// Day scenes: the digit and function faces against the far floor (the
/// generator darkens the far floor until it is reached).
const double vaporwaveLightKeyFloorContrast = 1.35;

/// Day scenes: the grid against the near floor (the table guarantees it).
const double vaporwaveLightGridFloorContrast = 1.8;

/// The lowest sun stripes must read against the horizon glow behind them:
/// night skies lower the glow until ΔEOK(sun bottom, glow) reaches this.
const double vaporwaveSunGlowDeltaE = 0.09;

/// Ink (key lines, window frame; `Palette.shadow`).
const IntRange vaporwaveLightInkLMilli = IntRange(200, 260);
const IntRange vaporwaveLightInkChromaMilli = IntRange(50, 80);
const IntRange vaporwaveLightInkHueTenths = IntRange(2850, 2950);
const IntRange vaporwaveDarkInkLMilli = IntRange(100, 140);
const IntRange vaporwaveDarkInkChromaMilli = IntRange(30, 50);

/// Display client panel (`Palette.surface`).
const IntRange vaporwaveLightSurfaceLMilli = IntRange(965, 985);
const IntRange vaporwaveLightSurfaceChromaMilli = IntRange(10, 22);
const IntRange vaporwaveDarkSurfaceLMilli = IntRange(160, 210);
const IntRange vaporwaveDarkSurfaceChromaMilli = IntRange(40, 70);

/// Title bar: `[sunset (the accent pair), classic (navy → teal)]` weights.
const List<int> vaporwaveTitleWeights = [3, 2];

/// A title bar whose start (`Palette.highlight`) is darker than this
/// OKLab lightness is the classic navy one (navy L ≤ 0.34; every warm
/// accent is ≥ 0.56).
const double vaporwaveClassicTitleMaxL = 0.45;

/// The horizon height when the scene has no display rectangle, permille
/// of the scene height (`BackgroundSpec.angleTenths`).
const int vaporwaveHorizonMinPermille = 380;
const int vaporwaveHorizonMaxPermille = 460;

/// The scene's drift period (one grid-line cycle), ms.
const int vaporwaveDriftPeriodMs = 48000;

/// Accent vs digit / function separation (normal and simulated CVD), and
/// the face contrast that keeps accents a lightness step away.
const double vaporwaveAccentBodyDeltaE = 0.06;
const double vaporwaveAccentBodyContrast = 1.2;

/// Operator / `=` vs digit ΔEOK (normal vision; CVD is covered by
/// [vaporwaveAccentBodyDeltaE] and the weight cue).
const double vaporwaveOperatorFaceDeltaE = 0.08;

/// Shape, style and type ranges.
const IntRange vaporwaveCornerPermille = IntRange(0, 20);
const int vaporwaveOutlineWidthCdp = 100;
const List<int> vaporwaveBevelCdp = [200, 300];
const IntRange vaporwaveEdgeShadePermille = IntRange(260, 340);
const IntRange vaporwaveHighlightPermille = IntRange(800, 950);
const int vaporwaveStateLayerPermille = 60;

/// Role ranges, for documentation only (the builder draws from the
/// tables above): pastel keys at L 0.79–0.83, the warm accent below them
/// (0.66–0.71) and the cool one above (0.88–0.92).
const RoleRanges _vaporwaveRanges = RoleRanges(
  background: RoleRange(IntRange(130, 880), ChromaRange.abs(40, 100)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(10, 70),
  digit: RoleRange(vaporwaveDigitLMilli, ChromaRange.abs(48, 85)),
  digitDuotoneChroma: ChromaRange.abs(48, 85),
  function: RoleRange(vaporwaveFunctionLMilli, ChromaRange.abs(55, 85)),
  operator: RoleRange(IntRange(660, 920), ChromaRange.rel(850, 1000, 200)),
  operatorMonochromeL: IntRange(660, 920),
  equals: RoleRange(IntRange(660, 920), ChromaRange.rel(850, 1000, 200)),
  labelStartLMilli: 210,
  labelMaxChromaMilli: 80,
  accentChroma: ChromaRange.rel(850, 1000, 200),
  minDigitAboveBackgroundMilli: 0,
);

/// Vaporwave: square Win95 buttons with a hard two-tone bevel that
/// inverts on touch-down (frame 1, on `tint`) while the label travels
/// (+d, +d) with d = 1–2 dp (seeded); `effectsFast` in, 439/0.8 out
/// (seeded × {0.9, 1, 1.1}, ζ ± 0.05); no scale (it would blur the 1 dp
/// line and bevel); a 6 % contrast-safe state layer; display glyphs rise
/// 6 dp on standard.normal; sound `softTap`, haptic light · 0.6. The palette
/// and the sunset scene are built by [buildVaporwaveCandidate].
const FamilyDefinition vaporwaveDefinition = FamilyDefinition(
  family: ThemeFamily.vaporwave,
  brightnessWeights: [5, 4],
  schemes: [Weighted(HarmonyScheme.complementary, 1)],
  shapes: [Weighted(KeyShapeKind.roundedRect, 1)],
  cornerPermille: vaporwaveCornerPermille,
  styles: [Weighted(KeyStyleKind.extruded, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.extruded,
    outlineWidthCdp: vaporwaveOutlineWidthCdp,
    extrudeDepthCdp: 200,
    edgeShadePermille: 300,
    shadowOffsetCdp: 100,
    stateLayerPermille: vaporwaveStateLayerPermille,
    highlightPermille: 850,
  ),
  displayFonts: [Weighted(FontIds.anybody, 1)],
  keyFonts: [Weighted(FontIds.anybody, 1)],
  displayWeight: IntRange(450, 600),
  keyWeight: IntRange(450, 550),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [Weighted(BackgroundKind.vaporSunset, 1)],
  sound: SoundPackId.softTap,
  dark: _vaporwaveRanges,
  light: _vaporwaveRanges,
  motion: MotionSpec(
    verb: PressVerb.sink,
    scheme: MotionScheme.expressive,
    pressIn: SpringTokens.effectsFast,
    release: SpringToken(439, 800),
    depthCdp: 100,
    entry: EntryStyle.rise,
    entryOffsetCdp: 600,
    entrySpring: SpringTokens.standardNormal,
    impact: ImpactStyle.light,
    impactPermille: 600,
  ),
  motionRanges: MotionRanges(
    depthCdp: IntRange(100, 200),
    bounceJitterPermille: 50,
  ),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

// --------------------------------------------------------------- helpers --

int _wrap(int tenths) => tenths % 3600;

int _hueDistance(int a, int b) {
  final d = (a - b).abs() % 3600;
  return d > 1800 ? 3600 - d : d;
}

bool _opaque(int argb) => ((argb >>> 24) & 0xFF) == 255;

/// An encoded-sRGB mix `(a·wa + b·wb) / total` per channel (what a
/// gradient or an anti-aliased edge between the two shows).
int _mix(int a, int b, int wa, int wb, int total) {
  int ch(int shift) =>
      (((a >> shift) & 0xFF) * wa + ((b >> shift) & 0xFF) * wb + total ~/ 2) ~/
      total;
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// The alpha of the horizon line's glow underlay on night scenes (0–255).
const int vaporwaveGlowAlpha = 77;

/// The strongest alpha of the haze in the horizon line's colour that
/// fades out over the floor's far 12 % (0–255): night scenes, and the
/// lighter day-scene haze.
const int vaporwaveHazeAlpha = 71;
const int vaporwaveHazeAlphaLight = 51;

/// Adjacent colour pairs whose ¼ / ½ / ¾ mixes the scene can show: the
/// sky, sun and floor gradients, grid and horizon lines anti-aliased over
/// the floor and sky, and the sun's edges and stripe gaps over the sky.
const List<(int, int)> _vaporMixPairs = [
  (0, 1),
  (1, 2),
  (3, 4),
  (4, 5),
  (6, 7),
  (8, 6),
  (8, 7),
  (9, 2),
  (9, 6),
  (3, 1),
  (3, 2),
  (4, 1),
  (4, 2),
  (5, 1),
  (5, 2),
];

/// Every opaque colour of a Vaporwave scene with the ten [stops]: the
/// stops, the ¼ / ½ / ¾ mixes of [_vaporMixPairs], the horizon glow over
/// the sky and the floor, and the horizon haze over the far floor (58
/// samples).
List<int> vaporwaveSamplesOf(List<int> stops) {
  final s = [for (final c in stops) c | 0xFF000000];
  final out = <int>[...s];
  for (final (i, j) in _vaporMixPairs) {
    for (var k = 1; k <= 3; k++) {
      out.add(_mix(s[i], s[j], 4 - k, k, 4));
    }
  }
  final glow = withAlpha(s[9], vaporwaveGlowAlpha);
  out
    ..add(compositeOver(glow, s[2]))
    ..add(compositeOver(glow, s[6]))
    ..add(compositeOver(withAlpha(s[9], vaporwaveHazeAlpha), s[6]));
  return out;
}

/// The plain surfaces a key is seen against: keys only ever cover the
/// floor (the painter puts the horizon above the keypad in every layout),
/// so the two floor stops, the floor gradient between them and the grid
/// colour. The colours in between the grid and the floor, which the
/// painter shows too, are [vaporwaveKeyMixSamplesOf].
List<int> vaporwaveKeySamplesOf(List<int> stops) {
  final s = [for (final c in stops) c | 0xFF000000];
  return [
    s[6],
    s[7],
    for (var k = 1; k <= 3; k++) _mix(s[6], s[7], 4 - k, k, 4),
    s[8],
  ];
}

/// The in-between colours a key can sit over: the grid at alpha k / 8
/// (k = 1…7) over each floor sample and over the horizon haze, plus the
/// haze itself. The painter really draws them behind the top key rows:
/// the far end of every floor ray and the far cross lines fade in with
/// alpha, the haze fades out, and every line has anti-aliased edges.
/// Midway between a dark floor and a bright grid neither a warm face nor
/// the dark ink reaches 3:1, so the boundary rule counts the key's outer
/// bevel highlight there ([vaporwaveBevelHighlight]).
List<int> vaporwaveKeyMixSamplesOf(List<int> stops) {
  final s = [for (final c in stops) c | 0xFF000000];
  final haze = compositeOver(withAlpha(s[9], vaporwaveHazeAlpha), s[6]);
  final floors = [
    s[6],
    s[7],
    for (var k = 1; k <= 3; k++) _mix(s[6], s[7], 4 - k, k, 4),
    haze,
  ];
  return [
    for (final f in floors)
      for (var k = 1; k <= 7; k++) _mix(s[8], f, k, 8 - k, 8),
    haze,
  ];
}

/// The outer bevel highlight of a key [face] (drawn just inside the ink
/// line on the top and left edges at rest, on the bottom and right while
/// pressed): with face = (L, C, h) and m = [highlightPermille] / 1000
/// (× 0.6 when L < 0.5), the colour (L + (1 − L)·m, 0.6·C, h). The key
/// painter's bevel (`render/vaporwave/vaporwave_bevel.dart`) uses this
/// exact formula, so the guardrail measures what is drawn.
int vaporwaveBevelHighlight(int face, int highlightPermille) {
  final f = argbToOklch(face | 0xFF000000);
  final m = highlightPermille / 1000 * (f.l < 0.5 ? 0.6 : 1.0);
  return oklchToArgb(clamp01(f.l + (1 - f.l) * m), f.c * 0.6, f.h) | 0xFF000000;
}

/// The highlight permille a key style draws with (the renderer's default
/// for a style without one).
int _highlightPermilleOf(KeyStyleSpec style) =>
    style.highlightPermille > 0 ? style.highlightPermille : 850;

/// Whether [bg] is a well-formed Vaporwave scene (ten opaque colours).
bool vaporwaveSceneWellFormed(BackgroundSpec bg) =>
    bg.kind == BackgroundKind.vaporSunset &&
    bg.colors.length == 10 &&
    bg.colors.every(_opaque);

/// A colour of [lMilli], chroma and hue, with relative chroma resolved.
int _tone(int lMilli, ChromaRange range, int chromaDraw, int hueTenths) {
  final l = lMilli / 1000;
  final h = hueTenths / 10;
  double c;
  if (range.relative) {
    c = chromaDraw / 1000 * maxChroma(l, h);
    final cap = range.capMilli / 1000;
    if (c > cap) c = cap;
  } else {
    c = chromaDraw / 1000;
  }
  return oklchToArgb(l, c, h);
}

/// An accent face colour at [lMilli] and hue, chroma `rel × maxChroma`.
Lch _accent(int lMilli, int hueTenths, int relPermille) {
  final l = lMilli / 1000;
  final h = hueTenths / 10;
  var c = relPermille / 1000 * maxChroma(l, h);
  const cap = vaporwaveAccentChromaCapMilli / 1000;
  if (c > cap) c = cap;
  return (l: l, c: c, h: h);
}

/// Whether accent face [a] stands apart from body face [b] (normal and
/// CVD ΔEOK, and face contrast).
bool vaporwaveAccentApart(int a, int b) =>
    minCvdDeltaE(a, b) >= vaporwaveAccentBodyDeltaE &&
    contrastRatio(a, b) >= vaporwaveAccentBodyContrast;

// --------------------------------------------------------------- builder --

/// Builds one unvalidated Vaporwave candidate (the generator repairs and
/// validates it, retries with `palette/retry/n` and finally falls back to
/// a Vaporwave hero).
ThemeSpec buildVaporwaveCandidate(
  int seed,
  FamilyDefinition def,
  int engineVersion, {
  int attempt = 0,
  bool accessible = false,
}) {
  final paletteTag = attempt == 0
      ? RngTag.palette
      : RngTag.sub(RngTag.palette, 'retry', attempt);
  final p = Rng.stream(seed, paletteTag);
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final brightness = dark ? ThemeBrightness.dark : ThemeBrightness.light;
  final scene = dark
      ? (p.pickWeighted(vaporwaveDarkSceneWeights) == 0
            ? VaporScene.dusk
            : VaporScene.midnight)
      : (p.pickWeighted(vaporwaveLightSceneWeights) == 0
            ? VaporScene.pastel
            : VaporScene.aqua);
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final bile = def.bile;

  // Accent pair: one warm (darker) and one cool (lighter) neon.
  final pair =
      vaporwaveAccentPairs[p.pickWeighted([
        for (final x in vaporwaveAccentPairs) x.weight,
      ])];
  final opHue = _wrap(
    pair.op.hueTenths + p.nextJitterTenths(pair.op.jitterTenths),
  );
  final eqHue = _wrap(
    pair.eq.hueTenths + p.nextJitterTenths(pair.eq.jitterTenths),
  );
  int accentL({required bool warm}) {
    final band = warm ? vaporwaveWarmLMilli : vaporwaveCoolLMilli;
    final l = band.sample(p);
    if (warm && accessible) {
      // The same draw, mapped onto the Accessible lock's lighter band.
      return _remap(l, vaporwaveWarmLMilli, vaporwaveWarmAccessibleLMilli);
    }
    return l;
  }

  final opL = accentL(warm: pair.op.warm);
  final eqL = accentL(warm: pair.eq.warm);
  final opRel = vaporwaveAccentChromaRel.sample(p);
  final eqRel = vaporwaveAccentChromaRel.sample(p);
  final warmHue = pair.op.warm ? opHue : eqHue;
  final coolHue = pair.op.warm ? eqHue : opHue;

  // Pastel key faces: the digit hue clear of both accents, the function
  // hue clear of both and of the digit.
  final digitDraw = p.pickWeighted([
    for (final x in vaporwavePastels) x.weight,
  ]);
  final digitIdx0 = digitDraw < vaporwaveDigitPastelFirst
      ? vaporwaveDigitPastelRemap
      : digitDraw;
  final u = p.nextIntIn(-1000, 1000);
  final step =
      vaporwaveFunctionSteps[p.pickWeighted([
            for (final x in vaporwaveFunctionSteps) x.weight,
          ])]
          .step;
  final u2 = p.nextIntIn(-1000, 1000);
  final digitLMilli = vaporwaveDigitLMilli.sample(p);
  final digitCMilli = vaporwaveDigitChromaMilli.sample(p);
  final fnLMilli = vaporwaveFunctionLMilli.sample(p);
  final fnCMilli = vaporwaveFunctionChromaMilli.sample(p);
  int pastelHue(int idx, int jitter) {
    final e = vaporwavePastels[idx];
    return _wrap(e.hueTenths + (jitter * e.jitterTenths) ~/ 1000);
  }

  // The digit pastel nearest the drawn one (searching outward: +0, +1,
  // −1, +2, −2, +3, −3, inside periwinkle … baby pink) that clears both
  // accents, so a rejected entry lands on its neighbour rather than
  // piling onto the first entry after it.
  var digitIdx = digitIdx0;
  {
    var best = -100000;
    for (final k in const [0, 1, -1, 2, -2, 3, -3]) {
      final idx = digitIdx0 + k;
      if (idx < vaporwaveDigitPastelFirst || idx > vaporwaveDigitPastelLast) {
        continue;
      }
      final h = pastelHue(idx, u);
      final score = _min2(
        _hueDistance(h, warmHue) - vaporwaveDigitWarmGap,
        _hueDistance(h, coolHue) - vaporwaveDigitCoolGap,
      );
      if (score >= 0) {
        digitIdx = idx;
        break;
      }
      if (score > best) {
        best = score;
        digitIdx = idx;
      }
    }
  }
  final digitHue = pastelHue(digitIdx, u);
  var fnIdx = (digitIdx + step) % vaporwavePastels.length;
  {
    final start = fnIdx;
    var best = -100000;
    for (var k = 0; k < vaporwavePastels.length; k++) {
      final idx = (start + k) % vaporwavePastels.length;
      final h = pastelHue(idx, u2);
      final score = _min2(
        _min2(
          _hueDistance(h, warmHue) - vaporwaveFunctionWarmGap,
          _hueDistance(h, coolHue) - vaporwaveFunctionCoolGap,
        ),
        _hueDistance(h, digitHue) - vaporwaveFunctionDigitGap,
      );
      if (score >= 0) {
        fnIdx = idx;
        break;
      }
      if (score > best) {
        best = score;
        fnIdx = idx;
      }
    }
  }
  final fnHue = pastelHue(fnIdx, u2);

  // Label start: deep indigo ink (every face is light).
  final lblL = 180 + 10 * p.nextInt(7);
  final lblC = p.nextIntIn(40, 80);
  final lblH = 2850 + p.nextJitterTenths(50);
  final labelStart = (l: lblL / 1000, c: lblC / 1000, h: lblH / 10);

  // Scene colours 0–9, then the luminance band (no draws).
  final tones = vaporwaveSceneTones[scene]!;
  final colors = <int>[];
  for (final t in tones) {
    var l = t.lMilli.sample(p);
    final chroma = p.nextIntIn(t.chroma.lo, t.chroma.hi);
    final hue = switch (t.hue) {
      VaporHue.drawn => _wrap(t.hueTenths.sample(p)),
      VaporHue.warm => warmHue,
      VaporHue.cool => coolHue,
    };
    var c = _tone(l, t.chroma, chroma, hue);
    for (var i = 0; i < 20; i++) {
      final y = luminanceArgb(c);
      if (dark ? y <= vaporwaveDarkSceneMaxY : y >= vaporwaveLightSceneMinY) {
        break;
      }
      l += dark ? -10 : 10;
      c = _tone(l, t.chroma, chroma, hue);
    }
    colors.add(c);
  }
  if (dark) {
    // The lowest sun stripes read against the glow behind them.
    final glow = argbToOklch(colors[2]);
    var l = glow.l;
    for (var i = 0; i < 10; i++) {
      if (deltaEOKArgb(colors[5], colors[2]) >= vaporwaveSunGlowDeltaE) break;
      l -= 0.02;
      colors[2] = oklchToArgb(l, glow.c, glow.h);
    }
  }

  // Ink and the display's client panel.
  final int ink;
  if (dark) {
    final l = vaporwaveDarkInkLMilli.sample(p) / 1000;
    final c = vaporwaveDarkInkChromaMilli.sample(p) / 1000;
    ink = oklchToArgb(l, c, argbToOklch(colors[0]).h);
  } else {
    final l = vaporwaveLightInkLMilli.sample(p) / 1000;
    final c = vaporwaveLightInkChromaMilli.sample(p) / 1000;
    ink = oklchToArgb(l, c, vaporwaveLightInkHueTenths.sample(p) / 10);
  }
  final int surface;
  {
    final l =
        (dark ? vaporwaveDarkSurfaceLMilli : vaporwaveLightSurfaceLMilli)
            .sample(p) /
        1000;
    final c =
        (dark
                ? vaporwaveDarkSurfaceChromaMilli
                : vaporwaveLightSurfaceChromaMilli)
            .sample(p) /
        1000;
    surface = oklchToArgb(
      l,
      c,
      dark ? argbToOklch(colors[0]).h : digitHue / 10,
    );
  }

  // Title bar scheme (sunset: the accent pair; classic: navy → teal).
  final classic = p.pickWeighted(vaporwaveTitleWeights) == 1;
  int? navy;
  int? teal;
  if (classic) {
    navy = oklchToArgb(
      p.nextIntIn(280, 340) / 1000,
      p.nextIntIn(120, 150) / 1000,
      p.nextIntIn(2620, 2700) / 10,
    );
    teal = oklchToArgb(
      p.nextIntIn(520, 580) / 1000,
      p.nextIntIn(90, 110) / 1000,
      p.nextIntIn(2080, 2180) / 10,
    );
  }

  // Keys.
  KeyColors key(Lch face) {
    var pair = repairPair(face, labelStart, policy: policy);
    if (bile.recheckFinal) {
      final f = argbToOklch(pair.face);
      final hue = (f.h * 10).round() % 3600;
      final rotated = bile.apply(hue, f.l, f.c);
      if (rotated != hue) {
        pair = repairPair(
          (l: f.l, c: f.c, h: rotated / 10),
          labelStart,
          policy: policy,
        );
      }
    }
    return KeyColors(face: pair.face, label: pair.label, edge: ink);
  }

  // Peach and baby pink take the richer chroma band (same draw, mapped).
  int pastelChroma(int drawn, IntRange band, int hue) =>
      _hueIn(hue, vaporwaveWarmPastelHueTenths)
      ? _remap(drawn, band, vaporwaveWarmPastelChromaMilli)
      : drawn;
  var digitFace = (
    l: digitLMilli / 1000,
    c: pastelChroma(digitCMilli, vaporwaveDigitChromaMilli, digitHue) / 1000,
    h: digitHue / 10,
  );
  var fnFace = (
    l: fnLMilli / 1000,
    c: pastelChroma(fnCMilli, vaporwaveFunctionChromaMilli, fnHue) / 1000,
    h: fnHue / 10,
  );
  var digit = key(digitFace);
  var function = key(fnFace);
  var opFace = _accent(opL, opHue, opRel);
  var eqFace = _accent(eqL, eqHue, eqRel);
  var operator = key(opFace);
  var equals = key(eqFace);

  // `=` apart from the operators (CVD included): the cool accent up, the
  // warm one down, both at a fixed relative chroma.
  final warmFloor = accessible
      ? vaporwaveWarmAccessibleFloorMilli / 1000
      : vaporwaveWarmLMilli.lo / 1000 - 0.04;
  if (minCvdDeltaE(equals.face, operator.face) < 0.065) {
    Lch moved(Lch f, {required bool warm}) {
      final l = warm
          ? (f.l - 0.03 < warmFloor ? warmFloor : f.l - 0.03)
          : (f.l + 0.05 > 0.95 ? 0.95 : f.l + 0.05);
      return _accent((l * 1000).round(), (f.h * 10).round(), 920);
    }

    opFace = moved(opFace, warm: pair.op.warm);
    eqFace = moved(eqFace, warm: pair.eq.warm);
    operator = key(opFace);
    equals = key(eqFace);
  }

  // Accents a lightness step away from the pastel keys: warm down, cool
  // up, in 0.02 steps.
  (Lch, KeyColors) apart(Lch face, KeyColors k, {required bool warm}) {
    var f = face;
    var out = k;
    for (var i = 0; i < 6; i++) {
      if (vaporwaveAccentApart(out.face, digit.face) &&
          vaporwaveAccentApart(out.face, function.face)) {
        break;
      }
      final l = warm ? f.l - 0.02 : f.l + 0.02;
      if (warm ? l < warmFloor : l > 0.96) break;
      f = _accent((l * 1000).round(), (f.h * 10).round(), 920);
      out = key(f);
    }
    return (f, out);
  }

  (opFace, operator) = apart(opFace, operator, warm: pair.op.warm);
  (eqFace, equals) = apart(eqFace, equals, warm: pair.eq.warm);

  // An accent at its limit (the warm floor under the Accessible lock):
  // the pastel key steps away from it instead (up from a warm accent, down
  // from a cool one), at most four 0.02 steps.
  for (var round = 0; round < 4; round++) {
    var moved = false;
    for (final (accent, warm) in [
      (operator.face, pair.op.warm),
      (equals.face, pair.eq.warm),
    ]) {
      final dl = warm ? 0.02 : -0.02;
      if (!vaporwaveAccentApart(accent, function.face)) {
        fnFace = (l: fnFace.l + dl, c: fnFace.c, h: fnFace.h);
        function = key(fnFace);
        moved = true;
      }
      if (!vaporwaveAccentApart(accent, digit.face)) {
        digitFace = (l: digitFace.l + dl, c: digitFace.c, h: digitFace.h);
        digit = key(digitFace);
        moved = true;
      }
    }
    if (!moved) break;
  }

  if (!dark) {
    // Day scenes: the pastel keys stand a step off the far floor in
    // lightness, not only by their ink line (the far floor darkens in
    // 0.01 steps, never below the scene's luminance band).
    final far = argbToOklch(colors[6]);
    var l = far.l;
    for (var i = 0; i < 12; i++) {
      final worst = _min2d(
        contrastRatio(digit.face, colors[6]),
        contrastRatio(function.face, colors[6]),
      );
      if (worst >= vaporwaveLightKeyFloorContrast) break;
      l -= 0.01;
      final next = oklchToArgb(l, far.c, far.h);
      if (luminanceArgb(next) < vaporwaveLightSceneMinY) break;
      colors[6] = next;
    }
  }

  final background = BackgroundSpec(
    kind: BackgroundKind.vaporSunset,
    colors: List.unmodifiable(colors),
    angleTenths:
        vaporwaveHorizonMinPermille +
        10 * Rng.stream(seed, RngTag.background).nextInt(9),
    driftPeriodMs: vaporwaveDriftPeriodMs,
  );
  final bgs = backgroundSamples(background);

  // Display texts on the client panel; the focus ring on the scene.
  int onPanel(int start, double target, int fallback) =>
      solveOnAll(start, [surface], target) ?? fallback;
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final panelFallback = blackOrWhite(surface);
  final displayText = onPanel(
    dark
        ? oklchToArgb(0.96, 0.025, warmHue / 10)
        : oklchToArgb(0.24, 0.07, 285),
    lim.displayRatio,
    panelFallback,
  );
  // The live result in the cool neon (dark) or a deep violet (light).
  final previewC = _min2d(0.11, 0.95 * maxChroma(0.80, coolHue / 10));
  final previewText = onPanel(
    dark
        ? oklchToArgb(0.80, previewC, coolHue / 10)
        : oklchToArgb(0.44, 0.10, 300),
    previewTarget,
    panelFallback,
  );
  final error = onPanel(
    dark ? oklchToArgb(0.76, 0.14, 25) : oklchToArgb(0.50, 0.19, 25),
    lim.displayRatio,
    panelFallback,
  );
  final caretL = dark ? 0.80 : 0.50;
  final caretC = 0.8 * maxChroma(caretL, opHue / 10);
  final caret = onPanel(
    oklchToArgb(caretL, caretC < 0.18 ? caretC : 0.18, opHue / 10),
    lim.caretRatio,
    displayText,
  );
  final focus =
      solveOnAll(
        dark
            ? oklchToArgb(0.98, 0.02, warmHue / 10)
            : oklchToArgb(0.24, 0.08, 285),
        bgs,
        lim.focusRingRatio,
      ) ??
      blackOrWhite(colors[0]);

  final warmFace = pair.op.warm ? operator.face : equals.face;
  final coolFace = pair.op.warm ? equals.face : operator.face;
  final palette = Palette(
    background: colors[0],
    surface: surface | 0xFF000000,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: focus,
    accent: (teal ?? coolFace) | 0xFF000000,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: ink | 0xFF000000,
    highlight: (navy ?? warmFace) | 0xFF000000,
    seedColor: operator.face,
  );

  // Motion, shape, style, type, name.
  final motion = def.motionRanges.vary(
    def.motion,
    Rng.stream(seed, RngTag.motion),
  );
  final s = Rng.stream(seed, RngTag.shape);
  final keyShape = KeyShapeSpec(
    kind: pickWeightedValue(s, def.shapes),
    cornerPermille: def.cornerPermille.sampleStep(s, 10),
  );
  final st = Rng.stream(seed, RngTag.style);
  final keyStyle = def.keyStyle.copyWith(
    kind: pickWeightedValue(st, def.styles),
    outlineWidthCdp: vaporwaveOutlineWidthCdp,
    extrudeDepthCdp: vaporwaveBevelCdp[st.nextInt(vaporwaveBevelCdp.length)],
    edgeShadePermille: vaporwaveEdgeShadePermille.sampleStep(st, 20),
    highlightPermille: vaporwaveHighlightPermille.sampleStep(st, 50),
    shadowOffsetCdp: motion.depthCdp,
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: operator.face,
    family: ThemeFamily.vaporwave,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.vaporwave,
    engineVersion: engineVersion,
    brightness: brightness,
    accessible: accessible,
    palette: palette,
    keyShape: keyShape,
    keyStyle: keyStyle,
    type: type,
    background: background,
    motion: motion,
    sound: def.sound,
    name: name,
    nonColourOperatorCue: def.nonColourOperatorCue,
  );
}

int _min2(int a, int b) => a < b ? a : b;

double _min2d(double a, double b) => a < b ? a : b;

/// [v] (inside [from]) mapped linearly onto [to], rounded.
int _remap(int v, IntRange from, IntRange to) {
  final span = from.hi - from.lo;
  if (span <= 0) return to.lo;
  return to.lo + ((v - from.lo) * (to.hi - to.lo) + span ~/ 2) ~/ span;
}

/// Whether [hueTenths] lies in [range] (which may wrap past 3600: lo > hi).
bool _hueIn(int hueTenths, IntRange range) {
  final h = _wrap(hueTenths);
  return range.lo <= range.hi
      ? h >= range.lo && h <= range.hi
      : h >= range.lo || h <= range.hi;
}

/// An extended 90s grotesque everywhere: display 450–600, keys 450–550,
/// operators 200–300 heavier; key labels of ≤ 2 characters at 120–140 %
/// width (the display at ≤ 130 %).
TypeSpec _type(Rng t, FamilyDefinition def) {
  final displayFont = pickWeightedValue(t, def.displayFonts);
  final keyFont = pickWeightedValue(t, def.keyFonts);
  final displayWeight = def.displayWeight.sampleStep(t, 50);
  final keyWeight = def.keyWeight.sampleStep(t, 50);
  final opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  return TypeSpec(
    displayFont: displayFont,
    keyFont: keyFont,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeight: opWeight > 900 ? 900 : opWeight,
    widthPermille: 1200 + 50 * t.nextInt(5),
    slashedZero: t.nextChance(1, 2),
  );
}

// ------------------------------------------------------------ guardrails --

/// The family-specific guardrails (called from `validateTheme` for
/// [ThemeFamily.vaporwave] specs only):
///
/// - [GuardrailRule.vaporOperatorCue]: the recorded weight cue is real
///   (operators ≥ 200 heavier).
/// - [GuardrailRule.vaporOperatorFace]: operator and `=` faces ΔEOK ≥ 0.08
///   from the digit face (normal vision).
/// - [GuardrailRule.vaporAccentVsDigit]: both accents stand apart from the
///   digit and function faces under every simulated CVD (ΔEOK ≥ 0.06) and
///   in lightness (contrast ≥ 1.2).
/// - [GuardrailRule.vaporScene]: a well-formed scene (ten opaque colours,
///   horizon 380–460 ‰, drift 0 or ≥ 40 s) inside its luminance band.
/// - [GuardrailRule.vaporPanel]: the panel, title-bar and ink colours are
///   opaque.
/// - [GuardrailRule.vaporOutline]: every key edge is the drawn ink, and in
///   light themes the ink is ≥ 3:1 on every scene sample (WCAG 1.4.11:
///   pastel keys on a pastel floor are delimited by it).
/// - [GuardrailRule.vaporBoundary]: in dark themes every key is delimited
///   (≥ 3:1) from every plain floor colour it can sit over by its face or
///   its ink, and from every in-between grid-over-floor colour by its
///   face, its ink or its outer bevel highlight. The guarantee therefore
///   covers the highlighted top and left edges of a key at rest; on the
///   bottom and right edges only the ink and the face are counted.
List<GuardrailViolation> validateVaporwave(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final out = <GuardrailViolation>[];
  final p = spec.palette;
  if (spec.nonColourOperatorCue != OperatorCue.weight ||
      spec.type.operatorWeight - spec.type.keyWeight < 200) {
    out.add(
      GuardrailViolation(
        GuardrailRule.vaporOperatorCue,
        (spec.type.operatorWeight - spec.type.keyWeight).toDouble(),
        200,
        'operator weight bonus',
      ),
    );
  }
  for (final (name, k) in [('operator', p.operator), ('equals', p.equals)]) {
    final de = deltaEOKArgb(k.face, p.digit.face);
    if (de < vaporwaveOperatorFaceDeltaE) {
      out.add(
        GuardrailViolation(
          GuardrailRule.vaporOperatorFace,
          de,
          vaporwaveOperatorFaceDeltaE,
          name,
        ),
      );
    }
    for (final (bodyName, body) in [
      ('digit', p.digit),
      ('function', p.function),
    ]) {
      final cvd = minCvdDeltaE(k.face, body.face);
      if (cvd < vaporwaveAccentBodyDeltaE) {
        out.add(
          GuardrailViolation(
            GuardrailRule.vaporAccentVsDigit,
            cvd,
            vaporwaveAccentBodyDeltaE,
            '$name vs $bodyName (cvd)',
          ),
        );
      }
      final cr = contrastRatio(k.face, body.face);
      if (cr < vaporwaveAccentBodyContrast) {
        out.add(
          GuardrailViolation(
            GuardrailRule.vaporAccentVsDigit,
            cr,
            vaporwaveAccentBodyContrast,
            '$name vs $bodyName (contrast)',
          ),
        );
      }
    }
  }
  final bg = spec.background;
  final wellFormed = vaporwaveSceneWellFormed(bg);
  if (!wellFormed) {
    out.add(
      GuardrailViolation(
        GuardrailRule.vaporScene,
        bg.colors.length.toDouble(),
        10,
        'scene kind and colours',
      ),
    );
  }
  if (bg.angleTenths < vaporwaveHorizonMinPermille ||
      bg.angleTenths > vaporwaveHorizonMaxPermille) {
    out.add(
      GuardrailViolation(
        GuardrailRule.vaporScene,
        bg.angleTenths.toDouble(),
        vaporwaveHorizonMinPermille.toDouble(),
        'horizon (permille)',
      ),
    );
  }
  if (bg.driftPeriodMs != 0 && bg.driftPeriodMs < 40000) {
    out.add(
      GuardrailViolation(
        GuardrailRule.vaporScene,
        bg.driftPeriodMs.toDouble(),
        40000,
        'drift period (ms)',
      ),
    );
  }
  if (wellFormed) {
    for (final s in bgs) {
      final y = luminanceArgb(s);
      if (spec.isDark
          ? y > vaporwaveDarkSceneCheckY
          : y < vaporwaveLightSceneCheckY) {
        out.add(
          GuardrailViolation(
            GuardrailRule.vaporScene,
            y,
            spec.isDark ? vaporwaveDarkSceneCheckY : vaporwaveLightSceneCheckY,
            'scene luminance band',
          ),
        );
        break;
      }
    }
  }
  for (final (name, c) in [
    ('surface', p.surface),
    ('highlight', p.highlight),
    ('accent', p.accent),
    ('shadow', p.shadow),
  ]) {
    if (!_opaque(c)) {
      out.add(
        GuardrailViolation(
          GuardrailRule.vaporPanel,
          ((c >>> 24) & 0xFF) / 255,
          1,
          '$name translucent',
        ),
      );
    }
  }
  final groups = [
    ('digit', p.digit),
    ('operator', p.operator),
    ('equals', p.equals),
    ('function', p.function),
  ];
  for (final (name, k) in groups) {
    if (k.edge != p.shadow) {
      out.add(
        GuardrailViolation(
          GuardrailRule.vaporOutline,
          0,
          1,
          '$name edge is not the ink',
        ),
      );
    }
  }
  if (!spec.isDark) {
    var worst = double.infinity;
    for (final s in bgs) {
      final r = contrastRatio(p.shadow | 0xFF000000, s);
      if (r < worst) worst = r;
    }
    if (worst < ratioLarge) {
      out.add(
        GuardrailViolation(
          GuardrailRule.vaporOutline,
          worst,
          ratioLarge,
          'ink',
        ),
      );
    }
  } else if (wellFormed) {
    final keySamples = vaporwaveKeySamplesOf(bg.colors);
    final mixes = _luminances(vaporwaveKeyMixSamplesOf(bg.colors));
    final hp = _highlightPermilleOf(spec.keyStyle);
    for (final (name, k) in groups) {
      final worst = _worstBoundary(k.face, p.shadow, keySamples);
      if (worst < ratioLarge) {
        out.add(
          GuardrailViolation(
            GuardrailRule.vaporBoundary,
            worst,
            ratioLarge,
            name,
          ),
        );
      }
      final lit = _worstBoundaryLit(
        k.face,
        p.shadow,
        vaporwaveBevelHighlight(k.face, hp),
        mixes,
      );
      if (lit < ratioLarge) {
        out.add(
          GuardrailViolation(
            GuardrailRule.vaporBoundary,
            lit,
            ratioLarge,
            '$name (grid over floor)',
          ),
        );
      }
    }
  }
  return out;
}

/// The worst over [samples] of `max(contrast(face, s), contrast(ink, s))`.
double _worstBoundary(int face, int ink, List<int> samples) {
  var worst = double.infinity;
  for (final s in samples) {
    final a = contrastRatio(face | 0xFF000000, s);
    final b = contrastRatio(ink | 0xFF000000, s);
    final m = a > b ? a : b;
    if (m < worst) worst = m;
  }
  return worst;
}

List<double> _luminances(List<int> colors) => [
  for (final c in colors) luminanceArgb(c),
];

double _ratioY(double a, double b) =>
    a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);

/// The worst over the sample luminances [samplesY] of the best contrast
/// of the face, the ink and the outer bevel highlight.
double _worstBoundaryLit(
  int face,
  int ink,
  int highlight,
  List<double> samplesY,
) {
  final f = luminanceArgb(face | 0xFF000000);
  final i = luminanceArgb(ink | 0xFF000000);
  final h = luminanceArgb(highlight | 0xFF000000);
  var worst = double.infinity;
  for (final y in samplesY) {
    var m = _ratioY(f, y);
    final b = _ratioY(i, y);
    if (b > m) m = b;
    final c = _ratioY(h, y);
    if (c > m) m = c;
    if (m < worst) worst = m;
  }
  return worst;
}

/// Family-specific repairs after labels and display texts (called from
/// `repairTheme` for [ThemeFamily.vaporwave] specs only); null =
/// unrepairable:
///
/// 1. the panel, title-bar and ink colours forced opaque;
/// 2. light themes: the ink re-solved to ≥ 3:1 on every scene sample;
///    every key edge set to the ink;
/// 3. dark themes: a key that is not delimited from the floor (and the
///    grid-over-floor mixes, counting its bevel highlight) gets a darker
///    ink, then its face lifted in 0.02 steps;
/// 4. accents moved away from the pastel keys (warm down, cool up, 0.02
///    steps, labels re-solved);
/// 5. a sunset title bar and the seed colour follow the accent faces.
Palette? repairVaporwaveExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final policy = lim.labelPolicy;
  var ink = p.shadow | 0xFF000000;
  if (!spec.isDark) {
    final solved = solveOnAll(ink, bgs, ratioLarge);
    if (solved == null) return null;
    ink = solved;
  }
  final wellFormed = vaporwaveSceneWellFormed(spec.background);
  final keySamples = wellFormed
      ? vaporwaveKeySamplesOf(spec.background.colors)
      : bgs;
  final mixes = wellFormed
      ? _luminances(vaporwaveKeyMixSamplesOf(spec.background.colors))
      : const <double>[];
  final hp = _highlightPermilleOf(spec.keyStyle);
  var digit = p.digit.copyWith(edge: ink);
  var function = p.function.copyWith(edge: ink);
  var operator = p.operator.copyWith(edge: ink);
  var equals = p.equals.copyWith(edge: ink);

  if (spec.isDark) {
    bool delimited(KeyColors k) =>
        _worstBoundary(k.face, ink, keySamples) >= ratioLarge &&
        _worstBoundaryLit(
              k.face,
              ink,
              vaporwaveBevelHighlight(k.face, hp),
              mixes,
            ) >=
            ratioLarge;
    if (![digit, function, operator, equals].every(delimited)) {
      // A darker ink first (it widens what the line alone covers).
      final lch = argbToOklch(ink);
      for (var l = lch.l - 0.04; l >= 0; l -= 0.04) {
        ink = oklchToArgb(l, lch.c, lch.h);
        digit = digit.copyWith(edge: ink);
        function = function.copyWith(edge: ink);
        operator = operator.copyWith(edge: ink);
        equals = equals.copyWith(edge: ink);
        if ([digit, function, operator, equals].every(delimited)) break;
      }
    }
    KeyColors? lift(KeyColors k) {
      var out = k;
      for (var i = 0; i < 8 && !delimited(out); i++) {
        final f = argbToOklch(out.face);
        final face = oklchToArgb(clamp01(f.l + 0.02), f.c, f.h);
        out = repairKeyLabel(out.copyWith(face: face), policy, [face]) ?? out;
      }
      return delimited(out) ? out : null;
    }

    final d = lift(digit);
    final fn = lift(function);
    final op = lift(operator);
    final eq = lift(equals);
    if (d == null || fn == null || op == null || eq == null) return null;
    digit = d;
    function = fn;
    operator = op;
    equals = eq;
  }

  // Accents away from the pastel keys.
  KeyColors? apart(KeyColors k) {
    bool ok(KeyColors x) =>
        vaporwaveAccentApart(x.face, digit.face) &&
        vaporwaveAccentApart(x.face, function.face) &&
        deltaEOKArgb(x.face, digit.face) >= vaporwaveOperatorFaceDeltaE;
    if (ok(k)) return k;
    final f = argbToOklch(k.face);
    final bodyL = argbToOklch(digit.face).l;
    final up = f.l > bodyL;
    final floor = spec.accessible
        ? vaporwaveWarmAccessibleFloorMilli / 1000
        : 0.56;
    var l = f.l;
    var out = k;
    for (var i = 0; i < 6; i++) {
      l += up ? 0.02 : -0.02;
      if (up ? l > 0.97 : l < floor) break;
      final face = oklchToArgb(l, f.c, f.h);
      out = repairKeyLabel(out.copyWith(face: face), policy, [face]) ?? out;
      if (ok(out)) return out;
    }
    return null;
  }

  final op = apart(operator);
  final eq = apart(equals);
  if (op == null || eq == null) return null;
  final movedAccents = op.face != p.operator.face || eq.face != p.equals.face;
  operator = op;
  equals = eq;

  // A sunset title bar runs from the warm accent (the darker one) to the
  // cool one; a classic bar starts from navy (L < 0.40) and stays.
  var highlight = p.highlight | 0xFF000000;
  var accent = p.accent | 0xFF000000;
  final sunset = argbToOklch(highlight).l >= vaporwaveClassicTitleMaxL;
  if (sunset && movedAccents) {
    final opWarm = luminanceArgb(operator.face) < luminanceArgb(equals.face);
    highlight = (opWarm ? operator.face : equals.face) | 0xFF000000;
    accent = (opWarm ? equals.face : operator.face) | 0xFF000000;
  }
  return p.copyWith(
    surface: p.surface | 0xFF000000,
    highlight: highlight,
    accent: accent,
    shadow: ink,
    digit: digit,
    function: function,
    operator: operator,
    equals: equals,
    seedColor: operator.face,
  );
}

/// Guardrail background samples of the family's scene
/// (`BackgroundKind.vaporSunset`): the ten colours, the ¼ / ½ / ¾ mixes of
/// every pair the painter blends or anti-aliases, the horizon glow and the
/// horizon haze ([vaporwaveSamplesOf]). Null (the generic stops) for a
/// malformed scene.
List<int>? vaporwaveSceneSamples(BackgroundSpec bg) =>
    bg.kind == BackgroundKind.vaporSunset && bg.colors.length == 10
    ? vaporwaveSamplesOf(bg.colors)
    : null;

/// Everything display text of [spec] may be drawn on: Vaporwave draws
/// every display glyph on the window's opaque client panel (the surface),
/// never on the scene, so [surfaces] alone.
List<int>? vaporwaveDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) => surfaces;
