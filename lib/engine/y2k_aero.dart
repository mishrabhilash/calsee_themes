/// The Y2K / Frutiger Aero family (spec §5.3 #10, enum `y2kChrome`, chip
/// label "Y2K Aero"; motion brief §2.3 "Y2K / chrome"): 2001–2008 glossy
/// optimism. Pure Dart: part of the generator, so every constant here is
/// part of the family's engine-v3 definition and must not change without a
/// version bump.
///
/// Two variants, drawn first on the `background` stream (so a seed keeps
/// its variant across palette retries and the Accessible lock):
///
/// - **AERO** (3 in 5, [BackgroundKind.aeroSky]): opaque, saturated gel
///   keys — pearl or blue-lavender moonstone digits, frost or sea-glass
///   function keys, blue and green gel operators — each with a hard white
///   specular cap over its top 42 %, a deeper tone right under the cap and
///   a light caustic at the bottom, under an azure sky with a lake horizon
///   ([Y2kScene.sky]), over sunlit grass hills ([Y2kScene.meadow]) or deep
///   in blue lagoon water with god rays ([Y2kScene.water], the dark
///   themes), with rising bubbles.
/// - **CHROME** (2 in 5, [BackgroundKind.chromeHolo]): satin-silver metal
///   digits and titanium function keys in a light–dark–light chrome bezel,
///   candy-gel operators, on pastel or black holographic foil with
///   sparkles; heavy type with a slashed zero.
///
/// **Keys are opaque where the label sits.** The renderer paints each face
/// as a vertical profile ([y2kGelProfile] / [y2kMetalProfile]) derived from
/// the opaque face colour, plus white overlays (cap, sheen, hover, brushed
/// streaks) and a lighter caustic. Inside the label zone (the middle 40 %
/// of the height, [y2kLabelZoneTop]–[y2kLabelZoneBottom]) nothing darker
/// than the profile's deep tone (floored at L 0.70, 0.735 under the
/// Accessible lock) is drawn, and every label is darker than its face, so
/// the label's worst backdrop is one of [y2kLabelZoneSamples]: the rest
/// and pressed profiles blended in every proportion the renderer can show
/// (validated as [GuardrailRule.y2kLabelZone]).
///
/// The press (motion brief "Y2K / chrome"): frame 1 swaps the body to the
/// pressed face ([y2kPressedFace]: hue +20°, or an accent tint on the
/// near-neutral pearl / silver / frost / titanium faces), flares the cap
/// and slides it toward the finger; on release a specular band sweeps the
/// face once, left to right.
///
/// Shared spec fields, as this family uses them:
///
/// | Field | Meaning here |
/// |---|---|
/// | `KeyStyleSpec.kind` | always [KeyStyleKind.glass] ("glossy"; faces are opaque) |
/// | `outlineWidthCdp` | AERO rim 1.00–1.50 dp; CHROME bezel ring 2.5–3.5 dp |
/// | `highlightPermille` | specular cap peak alpha (pressed + 0.10; ≥ 0.8 drawn on dark scenes) |
/// | `refractionPermille` | caustic glow alpha at the key's bottom (pressed × 1.8) |
/// | `edgeShadePermille` | depth of the deep tone under the cap (and the metal dark bands) |
/// | `shadowOffsetCdp` / `shadowBlurCdp` | the soft drop shadow (σ = blur / 2; offset ≤ 3 dp, blur ≥ 5 dp, so it stays within [y2kEdgeShadowAlpha] at a key's edge) |
/// | `stateLayerPermille` | 0: the pressed cue is artwork, not a state layer |
/// | `Palette.background` | the Material chrome's surface (settings, history): the horizon haze (sky, meadow), the mid water (deep water) or the foil's base |
/// | `Palette.highlight` | the specular white, always opaque white |
/// | `Palette.shadow` | the drop-shadow colour and alpha |
/// | `Palette.accent` | = the focus ring (toolbar glyphs) |
/// | `KeyColors.edge` | AERO rim / CHROME hairline (≥ 3:1 on the scene under the lock) |
/// | `BackgroundSpec.colors` | six scene colours (y2k_aero_scene.dart lists the roles) |
/// | `angleTenths` | AERO sun azimuth; CHROME holo band angle |
/// | `pattern` / `patternColor` / `patternScaleCdp` / `patternOpacityPermille` | bubbles (AERO) or sparkles (CHROME): tint, size and layout seed, opacity |
/// | `driftPeriodMs` | on / off only (periods [y2kAeroDriftMs], [y2kChromeDriftMs]) |
/// | `MotionSpec.fx` / `verb` | `sheen` / `gloss` (painted by the key face) |
///
/// Every draw comes from the generator's named sub-streams (`palette` and
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), so a theme is a pure function of (seed, engineVersion,
/// accessible). The variant is a `background` draw, so a retry keeps it;
/// brightness is the first `palette` draw, so a retry may turn a light sky
/// into deep water (the shape, style, type and motion never change).
library;

import 'dart:collection';

import 'package:calsee_themes/engine/bitexact_math.dart' show clamp01;
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/liquid_glass.dart'
    show meshHullSamples;
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

// ------------------------------------------------------------- constants --

/// The five scenes. AERO light themes are [sky] or [meadow], AERO dark
/// themes [water]; CHROME light themes [pastelHolo], dark [blackHolo].
enum Y2kScene {
  /// An azure sky over a lake horizon (light, [BackgroundKind.aeroSky]).
  sky,

  /// An azure sky over grass hills (light, [BackgroundKind.aeroSky]).
  meadow,

  /// Deep lagoon water with god rays (dark, [BackgroundKind.aeroSky]).
  water,

  /// Pastel holographic foil (light, [BackgroundKind.chromeHolo]).
  pastelHolo,

  /// Black holographic foil with jewel tones (dark,
  /// [BackgroundKind.chromeHolo]).
  blackHolo,
}

/// One gel or candy colour: hue (tenths, may run past 3600 and wrap),
/// lightness (thousandths; [waterLMilli] in the dark AERO scene), chroma as
/// a share of the gamut (thousandths) capped at [capMilli], and its weight.
final class Y2kGel {
  const new({
    required this.hue,
    required this.lMilli,
    required this.rel,
    required this.capMilli,
    required this.weight,
    this.waterLMilli,
  });

  /// Hue range, tenths of a degree (wraps at 3600).
  final IntRange hue;

  /// Lightness range × 1000.
  final IntRange lMilli;

  /// Lightness range × 1000 in deep water (dark AERO), where gels glow
  /// lighter so they never melt into moonstone digits; null = [lMilli].
  final IntRange? waterLMilli;

  /// Chroma as a share of `maxChroma(L, h)`, × 1000.
  final IntRange rel;

  /// Chroma ceiling × 1000.
  final int capMilli;

  /// Integer pick weight.
  final int weight;
}

/// AERO gels: greens (0–2) and blues (3–5), every hue range ≥ 3° inside its
/// 30° bucket (buckets 4–9).
const List<Y2kGel> y2kAeroGels = [
  // lime
  Y2kGel(
    hue: IntRange(1240, 1340),
    lMilli: IntRange(820, 880),
    waterLMilli: IntRange(820, 880),
    rel: IntRange(800, 950),
    capMilli: 200,
    weight: 2,
  ),
  // emerald
  Y2kGel(
    hue: IntRange(1400, 1540),
    lMilli: IntRange(780, 840),
    waterLMilli: IntRange(800, 850),
    rel: IntRange(750, 900),
    capMilli: 190,
    weight: 3,
  ),
  // teal
  Y2kGel(
    hue: IntRange(1700, 1880),
    lMilli: IntRange(800, 860),
    waterLMilli: IntRange(820, 870),
    rel: IntRange(800, 950),
    capMilli: 150,
    weight: 2,
  ),
  // aqua
  Y2kGel(
    hue: IntRange(1980, 2140),
    lMilli: IntRange(800, 860),
    waterLMilli: IntRange(830, 870),
    rel: IntRange(850, 980),
    capMilli: 145,
    weight: 4,
  ),
  // azure
  Y2kGel(
    hue: IntRange(2300, 2480),
    lMilli: IntRange(740, 790),
    waterLMilli: IntRange(770, 800),
    rel: IntRange(850, 980),
    capMilli: 150,
    weight: 4,
  ),
  // cornflower
  Y2kGel(
    hue: IntRange(2580, 2700),
    lMilli: IntRange(740, 780),
    waterLMilli: IntRange(770, 800),
    rel: IntRange(850, 980),
    capMilli: 135,
    weight: 2,
  ),
];

/// The AERO gels in deep water: azure and cornflower (indices 4 and 5, at
/// their weights) become one cyan-leaning azure at L 0.80–0.82, so no
/// operator or `=` shares the blue-lavender hue of the moonstone digits
/// (L ≤ 0.755) and a blue gel stands clear of them by lightness while
/// keeping its chroma (≈ 0.10–0.12; sRGB blues fade fast above L 0.8).
final List<Y2kGel> y2kWaterGels = List.unmodifiable([
  ...y2kAeroGels.take(4),
  for (final w in const [4, 2])
    Y2kGel(
      hue: const IntRange(2260, 2420),
      lMilli: const IntRange(740, 790),
      waterLMilli: const IntRange(800, 820),
      rel: const IntRange(900, 990),
      capMilli: 150,
      weight: w,
    ),
]);

/// CHROME candies (buckets 0–4, 7, 9–11), lightness capped at 0.82 so a
/// candy never matches a silver digit by lightness — except dandelion,
/// which sits at L 0.84–0.88 (a darker yellow turns ochre) and stands
/// apart from silver by its chroma and warmth (C ≈ 0.16 at 84–96°).
const List<Y2kGel> y2kChromeCandies = [
  // bubblegum (wraps past 360°)
  Y2kGel(
    hue: IntRange(3480, 3640),
    lMilli: IntRange(740, 790),
    rel: IntRange(800, 950),
    capMilli: 190,
    weight: 4,
  ),
  // strawberry
  Y2kGel(
    hue: IntRange(180, 300),
    lMilli: IntRange(740, 780),
    rel: IntRange(800, 950),
    capMilli: 170,
    weight: 2,
  ),
  // tangerine
  Y2kGel(
    hue: IntRange(480, 620),
    lMilli: IntRange(740, 790),
    rel: IntRange(850, 980),
    capMilli: 170,
    weight: 2,
  ),
  // dandelion: a golden sunflower yellow (a greener or darker one turns
  // mustard; a warm yellow keeps its distance from silver under tritan
  // CVD, where a lemon one collapses onto it)
  Y2kGel(
    hue: IntRange(840, 960),
    lMilli: IntRange(840, 880),
    rel: IntRange(900, 980),
    capMilli: 180,
    weight: 1,
  ),
  // lime
  Y2kGel(
    hue: IntRange(1240, 1340),
    lMilli: IntRange(780, 820),
    rel: IntRange(800, 950),
    capMilli: 200,
    weight: 3,
  ),
  // aqua
  Y2kGel(
    hue: IntRange(1980, 2140),
    lMilli: IntRange(760, 800),
    rel: IntRange(850, 980),
    capMilli: 145,
    weight: 4,
  ),
  // blueberry
  Y2kGel(
    hue: IntRange(2580, 2700),
    lMilli: IntRange(740, 780),
    rel: IntRange(850, 980),
    capMilli: 135,
    weight: 2,
  ),
  // grape
  Y2kGel(
    hue: IntRange(2980, 3120),
    lMilli: IntRange(740, 790),
    rel: IntRange(800, 950),
    capMilli: 160,
    weight: 2,
  ),
  // orchid
  Y2kGel(
    hue: IntRange(3220, 3380),
    lMilli: IntRange(740, 790),
    rel: IntRange(800, 950),
    capMilli: 200,
    weight: 3,
  ),
];

/// CHROME candies that pair warm pink with cool aqua or blueberry
/// (bubblegum, grape, orchid × aqua, blueberry; strawberry × aqua):
/// Vaporwave's signature, so the `=` pairing step skips them.
bool y2kVaporPair(int a, int b) {
  bool pink(int x, int other) =>
      x == 0 || x == 7 || x == 8 || (x == 1 && other == 5);
  bool cool(int x) => x == 5 || x == 6;
  return (pink(a, b) && cool(b)) || (cool(a) && pink(b, a));
}

/// AERO light scenes: `[sky, meadow]` weights (background stream).
const List<int> y2kAeroLightSceneWeights = [3, 2];

/// Lowest generated key face lightness × 1000 (standard / Accessible).
const int y2kFaceMinLMilli = 740;
const int y2kAccessibleFaceMinLMilli = 760;

/// The validator's face floor × 1000 (standard / Accessible): a little
/// under the generator's, so the shared `=` / operator separation step
/// has room ([GuardrailRule.y2kLabelPolarity]).
const int y2kFaceFloorMilli = 735;
const int y2kAccessibleFaceFloorMilli = 755;

/// Floor of the deep tone under the cap × 1000 (standard / Accessible);
/// the pressed deep tone may sit 25 lower.
const int y2kDeepFloorMilli = 700;
const int y2kAccessibleDeepFloorMilli = 735;

/// Highest key face lightness the generator moves a face to × 1000.
const int y2kFaceMaxLMilli = 920;

/// Label search start lightness × 1000 (standard / Accessible).
const int y2kLabelStartLMilli = 210;
const int y2kAccessibleLabelStartLMilli = 160;

/// AERO rim: the face 0.24 darker ([y2kAeroEdge]).
const int y2kEdgeDropMilli = 240;

/// `=` must stand this far (min ΔEOK, normal + CVD) from the operators
/// before the shared rule's 0.05 (pre-separation, as in Neo-brutalism).
const double y2kEqualsMinDeltaE = 0.065;

/// A `=` gel paler than this (OKLCH chroma) is a last resort.
const double y2kGelMinChroma = 0.085;

/// Operator / `=` vs digit: contrast ≥ [y2kAccentMinContrast] or min ΔEOK
/// (normal + CVD) ≥ [y2kAccentMinDeltaE] ([GuardrailRule.y2kAccentVsDigit]).
const double y2kAccentMinContrast = 1.2;
const double y2kAccentMinDeltaE = 0.06;

/// AERO light skies: the digit and function faces (and in a meadow the
/// gel faces too: green gels melt into grass) at least this far (ΔEOK)
/// from the ground band behind the keypad ([GuardrailRule.y2kGround]); the
/// generator aims at [y2kGroundTargetDeltaE].
const double y2kGroundMinDeltaE = 0.08;
const double y2kGroundTargetDeltaE = 0.09;

/// The label zone: the middle 40 % of the key's height, inset 12 % at the
/// sides. Only the opaque face profile and lighter overlays are drawn here.
const double y2kLabelZoneTop = 0.30;
const double y2kLabelZoneBottom = 0.70;
const double y2kLabelZoneInset = 0.12;

/// Gel body profile stops (fractions of the key's height): M, M, T, F, M, B
/// ([y2kGelProfile]).
const List<double> y2kGelStops = [0, 0.30, 0.46, 0.62, 0.80, 1];

/// Metal body profile stops: sky, sky, D1 (the horizon line), F, M, D2,
/// ground ([y2kMetalProfile]).
const List<double> y2kMetalStops = [0, 0.26, 0.34, 0.55, 0.78, 0.90, 1];

/// Peak caustic alpha inside the label zone, as a share of the caustic's
/// alpha (the oval's radial ramp where it meets the zone's bottom edge).
const double y2kCausticZoneShare = 0.111;

/// Drift period of each scene kind (constant: `driftPeriodMs` only says
/// whether the scene drifts; a transition drops it to 0).
const int y2kAeroDriftMs = 75000;
const int y2kChromeDriftMs = 85000;

/// The bubble sprite's highest alpha (its rim over its body; the glint is
/// lower and never overlaps the rim): a bubble paints its tint at most at
/// this × the pattern opacity (`y2kBubbleBodyAlpha` in the scene painter
/// lists the sprite).
const double y2kBubbleMaxAlpha = 0.85;

/// CHROME: the pearl floor (the base colour over the bottom 15 % of the
/// foil) at most at this alpha × 255.
const int y2kChromeFloorAlpha = 102;

/// Overlay caps per scene kind and brightness: `colors[5]` alpha and the
/// pattern opacity × 1000 ([GuardrailRule.y2kScene]).
int y2kLightCap(BackgroundKind kind, {required bool dark}) =>
    kind == BackgroundKind.chromeHolo ? (dark ? 36 : 102) : (dark ? 64 : 140);

/// Pattern opacity ceiling × 1000 (see [y2kLightCap]).
int y2kPatternCap(BackgroundKind kind, {required bool dark}) =>
    kind == BackgroundKind.chromeHolo ? (dark ? 240 : 700) : (dark ? 240 : 520);

/// Renderer contract ranges ([GuardrailRule.y2kGloss]). The shadow's
/// offset ≤ 3 dp and blur ≥ 5 dp keep it within [y2kEdgeShadowAlpha] just
/// outside a key's edge.
const IntRange y2kHighlightRange = IntRange(600, 950);
const IntRange y2kRefractionRange = IntRange(250, 700);
const IntRange y2kEdgeShadeRange = IntRange(40, 140);
const IntRange y2kAeroRimCdp = IntRange(100, 150);
const IntRange y2kChromeBezelCdp = IntRange(250, 350);
const IntRange y2kShadowBlurCdp = IntRange(500, 1200);
const IntRange y2kShadowOffsetCdp = IntRange(0, 300);

/// Display panel lightness bands ([GuardrailRule.y2kPanel]): light panels
/// ≥ 0.85, dark ≤ 0.24.
const int y2kPanelLightMinMilli = 850;
const int y2kPanelDarkMaxMilli = 240;

/// The key drop shadow's alpha × 255 on a dark scene.
const int y2kDarkShadowAlpha = 0x8C;

/// Display panel gloss alpha × 255 on a light / dark panel.
const int y2kLightPanelGloss = 128;
const int y2kDarkPanelGloss = 31;

// ------------------------------------------------------------ definition --

/// Y2K / Frutiger Aero (spec §5.3 #10; motion brief §2.3 "Y2K / chrome"):
/// opaque gel orbs or chrome-bezelled metal keys with a hard specular cap.
/// Press: effectsFast in, 439/0.75 out (seeded × {0.9, 1, 1.1}, ζ ± 0.05),
/// scale 0.96, a frame-1 hue +20° and cap flare, a specular sweep on
/// release; pop entry 0.88 → 1 on expressiveFast; sound `glass`. The
/// palette is built by [buildY2kAeroCandidate].
///
/// The key style kind is [KeyStyleKind.glass]: the value is semantic
/// ("glossy"), nothing keys on it (guardrails and renderers dispatch on
/// the family), and the faces are opaque.
const FamilyDefinition y2kAeroDefinition = FamilyDefinition(
  family: ThemeFamily.y2kChrome,
  brightnessWeights: [1, 4],
  schemes: [Weighted(HarmonyScheme.complementary, 1)],
  shapes: [
    Weighted(KeyShapeKind.pill, 3),
    Weighted(KeyShapeKind.roundedRect, 2),
  ],
  cornerPermille: IntRange(240, 500),
  styles: [Weighted(KeyStyleKind.glass, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.glass,
    outlineWidthCdp: 125,
    shadowOffsetCdp: 250,
    shadowBlurCdp: 600,
    edgeShadePermille: 80,
    stateLayerPermille: 0,
    highlightPermille: 800,
    refractionPermille: 480,
  ),
  displayFonts: [Weighted(FontIds.openSans, 1)],
  keyFonts: [Weighted(FontIds.openSans, 1)],
  displayWeight: IntRange(300, 750),
  keyWeight: IntRange(400, 600),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [
    Weighted(BackgroundKind.aeroSky, 3),
    Weighted(BackgroundKind.chromeHolo, 2),
  ],
  patterns: [Weighted(BackgroundPattern.dots, 1)],
  sound: SoundPackId.glass,
  dark: standardDarkRanges,
  light: standardLightRanges,
  motion: MotionSpec(
    verb: PressVerb.gloss,
    scheme: MotionScheme.expressive,
    pressIn: SpringTokens.effectsFast,
    release: SpringToken(439, 750),
    scalePermille: 960,
    entry: EntryStyle.pop,
    entryScalePermille: 800,
    entrySpring: SpringTokens.expressiveFast,
    fx: PressFx.sheen,
    impact: ImpactStyle.rigid,
    impactPermille: 700,
  ),
  motionRanges: MotionRanges(bounceJitterPermille: 50),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

// ----------------------------------------------------------- colour maths --

int _wrap(int tenths) => ((tenths % 3600) + 3600) % 3600;

/// OKLCH (hue in tenths, wrapped) → gamut-mapped opaque ARGB.
int _lch(double l, double c, int hueTenths) =>
    oklchToArgb(clamp01(l), c < 0 ? 0 : c, _wrap(hueTenths) / 10);

double _relC(int rel, int capMilli, double l, int hueTenths) {
  final c = rel / 1000 * maxChroma(clamp01(l), _wrap(hueTenths) / 10);
  final cap = capMilli / 1000;
  return c < cap ? c : cap;
}

int _hueTenths(int argb) => (argbToOklch(argb).h * 10).round() % 3600;

double _lOf(int argb) => argbToOklab(argb).$1;

/// [a] → [b] at [t] per channel in encoded sRGB (what gradients and paint
/// alpha blend in), opaque.
int y2kMix(int a, int b, double t) {
  int ch(int shift) {
    final x = (a >> shift) & 0xFF;
    final y = (b >> shift) & 0xFF;
    return (x + (y - x) * t).round().clamp(0, 255);
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// [argb] with its OKLCH lightness moved by [dLMilli] / 1000 and its chroma
/// scaled by [cPermille] / 1000 (hue kept), gamut-mapped.
int y2kTone(int argb, int dLMilli, int cPermille) {
  final x = argbToOklch(argb);
  return oklchToArgb(
    clamp01(x.l + dLMilli / 1000),
    x.c * cPermille / 1000,
    x.h,
  );
}

/// The deep tone of [face]: lightness lowered by [depthMilli] / 1000 but
/// never below [floorMilli] / 1000, chroma × 1.12.
int y2kDeep(int face, int depthMilli, int floorMilli) {
  final x = argbToOklch(face);
  final floor = floorMilli / 1000;
  final l = x.l - depthMilli / 1000;
  return oklchToArgb(l < floor ? floor : l, x.c * 1.12, x.h);
}

/// The pressed face (frame-1 cue): lightness − 0.025; a coloured gel
/// (C ≥ 0.06) keeps its chroma and turns +20°, a near-neutral face takes
/// chroma 0.07 at the accent hue + 20°.
int y2kPressedFace(int face, int accentHueTenths) {
  final x = argbToOklch(face);
  final neutral = x.c < 0.06;
  final hue = neutral ? accentHueTenths : (x.h * 10).round();
  return _lch(x.l - 0.025, neutral ? 0.07 : x.c, hue + 200);
}

/// The accent hue (tenths): the operator face's hue.
int y2kAccentHueTenths(Palette p) => _hueTenths(p.operator.face | 0xFF000000);

/// The caustic glow colour of [face]: lighter, softer.
int y2kCausticGlow(int face) => y2kTone(face, 100, 550);

/// The deep-tone floor × 1000 under the standard or Accessible lock.
int y2kDeepFloorFor({required bool accessible}) =>
    accessible ? y2kAccessibleDeepFloorMilli : y2kDeepFloorMilli;

/// The gel body colours at [y2kGelStops] for [face]: [M, M, T, F, M, B]
/// with M = F + 0.025, T the deep tone ([y2kDeep], [depthMilli] deep,
/// floored at [floorMilli]) and B = F + 0.06.
List<int> y2kGelProfile(int face, int depthMilli, int floorMilli) {
  final m = y2kTone(face, 25, 960);
  return [
    m,
    m,
    y2kDeep(face, depthMilli, floorMilli),
    face,
    m,
    y2kTone(face, 60, 850),
  ];
}

/// The satin-metal body colours at [y2kMetalStops] for [face]: a cool sky
/// reflection, a dark horizon line D1 (floored like the gel's deep tone),
/// the face, M, a dark band D2 and a warm ground reflection.
///
/// A warm (champagne) face reflects a warm-white sky in its own hue, so it
/// never wears an icy-blue cap over a beige body.
List<int> y2kMetalProfile(int face, int depthMilli, int floorMilli) {
  final x = argbToOklch(face);
  final warm = x.c >= 0.008 && x.h >= 40 && x.h <= 110;
  final sky = warm
      ? oklchToArgb(clamp01(x.l + 0.07), 0.012, x.h)
      : oklchToArgb(clamp01(x.l + 0.07), 0.02, 230);
  return [
    sky,
    sky,
    y2kDeep(face, depthMilli + 100, floorMilli),
    face,
    y2kTone(face, 25, 960),
    y2kTone(face, -60 - depthMilli, 1000),
    oklchToArgb(clamp01(x.l + 0.05), 0.015, 70),
  ];
}

final LinkedHashMap<(int, int, int, int, bool, bool), List<int>> _zoneMemo =
    LinkedHashMap();

/// Every colour a label of a key with [face] can sit on inside the label
/// zone, at rest and pressed: the body profile ([y2kGelProfile] or, for
/// [metal] faces, [y2kMetalProfile]) of the face and of its pressed face
/// ([y2kPressedFace] at [accentHueTenths]), each adjacent pair of stops
/// that reaches into the zone blended at 0, ½ and 1, every rest / pressed
/// pair blended at 0, ¼, ½, ¾ and 1 (the renderer fades the pressed body
/// over the rest body with paint alpha), plus the caustic glow at its
/// in-zone peak ([refractionPermille] at rest, × 1.8 pressed). White
/// overlays (cap, sheen, hover, streaks) only raise luminance, so they are
/// not samples: labels are always darker than their faces.
List<int> y2kLabelZoneSamples(
  int face, {
  required int accentHueTenths,
  required int depthPermille,
  required int refractionPermille,
  bool metal = false,
  bool accessible = false,
}) {
  final f = face | 0xFF000000;
  final key = (
    f,
    accentHueTenths,
    depthPermille,
    refractionPermille,
    metal,
    accessible,
  );
  final hit = _zoneMemo.remove(key);
  if (hit != null) return _zoneMemo[key] = hit;
  final floor = y2kDeepFloorFor(accessible: accessible);
  final pressed = y2kPressedFace(f, accentHueTenths);
  final rest = metal
      ? y2kMetalProfile(f, depthPermille, floor)
      : y2kGelProfile(f, depthPermille, floor);
  final down = metal
      ? y2kMetalProfile(pressed, depthPermille, floor - 25)
      : y2kGelProfile(pressed, depthPermille, floor - 25);
  final stops = metal ? y2kMetalStops : y2kGelStops;
  final out = <int>[];
  for (var i = 0; i + 1 < stops.length; i++) {
    if (stops[i + 1] <= y2kLabelZoneTop || stops[i] >= y2kLabelZoneBottom) {
      continue;
    }
    for (final s in const [0.0, 0.5, 1.0]) {
      final a = y2kMix(rest[i], rest[i + 1], s);
      final b = y2kMix(down[i], down[i + 1], s);
      for (final k in const [0.0, 0.25, 0.5, 0.75, 1.0]) {
        out.add(y2kMix(a, b, k));
      }
    }
  }
  final g0 = refractionPermille / 1000;
  final g1 = g0 * 1.8 < 0.9 ? g0 * 1.8 : 0.9;
  final m = y2kTone(f, 25, 960);
  final mDown = y2kTone(pressed, 25, 960);
  int glow(int on, int base, double alpha) => compositeOver(
    withAlpha(
      y2kCausticGlow(base),
      (255 * alpha * y2kCausticZoneShare).round(),
    ),
    on,
  );
  out
    ..add(glow(f, f, g0))
    ..add(glow(m, f, g0))
    ..add(glow(pressed, pressed, g1))
    ..add(glow(mDown, pressed, g1));
  final list = List<int>.unmodifiable(out);
  _zoneMemo[key] = list;
  while (_zoneMemo.length > 64) {
    _zoneMemo.remove(_zoneMemo.keys.first);
  }
  return list;
}

/// The AERO rim of [face]: 0.24 darker, chroma × 0.9 (≥ 0.035), turned 8°
/// toward green on yellow-greens (an olive rim reads dirty).
int y2kAeroEdge(int face) {
  final x = argbToOklch(face | 0xFF000000);
  var hue = (x.h * 10).round();
  if (hue >= 900 && hue < 1400) hue += 80;
  final c = x.c * 0.9 < 0.035 ? 0.035 : x.c * 0.9;
  return _lch(x.l - y2kEdgeDropMilli / 1000, c, hue);
}

/// The CHROME bezel hairline: a dark neutral in the digit hue.
int y2kChromeEdge(int digitHueTenths) => _lch(0.46, 0.012, digitHueTenths);

/// The display panel's gloss alpha × 255 for [surface].
int y2kPanelGlossAlpha(int surface) =>
    luminanceArgb(surface | 0xFF000000) < yEqualContrast
    ? y2kDarkPanelGloss
    : y2kLightPanelGloss;

/// The CHROME LCD glare streak's peak alpha × 255 for [surface]: half the
/// gloss (rounded up).
int y2kPanelGlareAlpha(int surface) => (y2kPanelGlossAlpha(surface) + 1) ~/ 2;

/// What display text sits on: the opaque panel, the panel under its gloss
/// band and, on a [chrome] LCD, under the gloss with the glare streak
/// crossing it (the lightest the panel gets).
List<int> y2kPanelSamples(int surface, {bool chrome = false}) {
  final s = surface | 0xFF000000;
  final gloss = compositeOver(withAlpha(0xFFFFFFFF, y2kPanelGlossAlpha(s)), s);
  return [
    s,
    gloss,
    if (chrome)
      compositeOver(withAlpha(0xFFFFFFFF, y2kPanelGlareAlpha(s)), gloss),
  ];
}

/// The scene of [bg] ([dark]: the theme's brightness; AERO light scenes
/// with a green ground are meadows).
Y2kScene y2kSceneOf(BackgroundSpec bg, {required bool dark}) {
  if (bg.kind == BackgroundKind.chromeHolo) {
    return dark ? Y2kScene.blackHolo : Y2kScene.pastelHolo;
  }
  if (dark) return Y2kScene.water;
  return y2kIsMeadow(bg) ? Y2kScene.meadow : Y2kScene.sky;
}

/// Whether an AERO light scene's ground (`colors[3]`) is grass (a yellow-
/// green to green hue) rather than a lake reflection.
bool y2kIsMeadow(BackgroundSpec bg) {
  if (bg.colors.length < 4) return false;
  final h = argbToOklch(bg.colors[3] | 0xFF000000).h;
  return h > 80 && h < 175;
}

// --------------------------------------------------------- scene samples --

final LinkedHashMap<BackgroundSpec, List<int>> _sceneMemo = LinkedHashMap();

/// Guardrail background samples of a Y2K scene: every opaque colour a key,
/// label, rim, focus ring or the toolbar can sit over. H = the colour hull
/// of `colors[0..4]` ([meshHullSamples]: stops, pairwise ¼ / ½ / ¾ points
/// and centroids — every gradient blend, hill and floor); the light
/// overlay (`colors[5]` at its alpha: sun glow, flare ghosts, god rays,
/// foil crease, all budgeted to stack ≤ that alpha) over H; CHROME's pearl
/// floor over H; and the bubble / sparkle tint at its highest alpha (a
/// bubble's rim over its body, [y2kBubbleMaxAlpha]; a sparkle is one path)
/// over all of those. Null for malformed specs (the generic sampling then
/// applies, and [GuardrailRule.y2kScene] fails).
List<int>? y2kAeroSceneSamples(BackgroundSpec bg) {
  if (bg.colors.length != 6) return null;
  final hit = _sceneMemo.remove(bg);
  if (hit != null) return _sceneMemo[bg] = hit;
  final chrome = bg.kind == BackgroundKind.chromeHolo;
  final hull = meshHullSamples([
    for (var i = 0; i < 5; i++) bg.colors[i] | 0xFF000000,
  ]);
  final base = <int>[
    ...hull,
    if (chrome)
      for (final h in hull)
        compositeOver(withAlpha(bg.colors[0], y2kChromeFloorAlpha), h),
  ];
  final lit = [for (final h in hull) compositeOver(bg.colors[5], h)];
  final out = <int>[...base, ...lit];
  if (bg.pattern != BackgroundPattern.none && bg.patternOpacityPermille > 0) {
    final o =
        bg.patternOpacityPermille / 1000 * (chrome ? 1 : y2kBubbleMaxAlpha);
    final ink = withAlpha(bg.patternColor, (255 * (o > 1 ? 1 : o)).round());
    out.addAll([
      for (final s in [...base, ...lit]) compositeOver(ink, s),
    ]);
  }
  final list = List<int>.unmodifiable(out);
  _sceneMemo[bg] = list;
  while (_sceneMemo.length > 8) {
    _sceneMemo.remove(_sceneMemo.keys.first);
  }
  return list;
}

/// The key shadow's alpha × 255 just outside a key's edge, where its rim
/// and the focus ring are seen: 0.9 of the drop shadow's alpha. The
/// shadow is the face shifted down by the offset and blurred with σ =
/// blur / 2, so directly under the bottom edge it covers Φ(offset / σ) ≤
/// Φ(3 / 2.5) ≈ 0.885 of its alpha for every style the generator draws
/// (offset 2–3 dp, blur 5–8 dp).
int y2kEdgeShadowAlpha(int shadow) {
  final a = (shadow >>> 24) & 0xFF;
  return (a * 9 + 5) ~/ 10;
}

final LinkedHashMap<(List<int>, int), List<int>> _edgeMemo = LinkedHashMap();

/// What a key rim or the focus ring is seen against: the scene samples
/// [bgs], plain and under the keys' own [shadow] ([y2kEdgeShadowAlpha]).
List<int> y2kEdgeSamples(List<int> bgs, int shadow) {
  final key = (bgs, shadow);
  final hit = _edgeMemo.remove(key);
  if (hit != null) return _edgeMemo[key] = hit;
  final s = withAlpha(shadow, y2kEdgeShadowAlpha(shadow));
  final list = List<int>.unmodifiable([
    ...bgs,
    for (final b in bgs) compositeOver(s, b),
  ]);
  _edgeMemo[key] = list;
  while (_edgeMemo.length > 8) {
    _edgeMemo.remove(_edgeMemo.keys.first);
  }
  return list;
}

/// The ground band behind an AERO light keypad: `colors[3]`, `colors[4]`
/// and their midpoint. Behind the keys the scene painter draws only these
/// and their blends (the haze ramp ends at the keypad's top edge, a
/// meadow's far field is the midpoint and its near hill's crest is
/// `colors[3]`; the lake glint, the sun's glow, flare ghosts and large
/// bubbles stay beside the calculator), plus the micro-bubbles.
List<int> y2kGroundSamples(BackgroundSpec bg) {
  final c3 = bg.colors[3] | 0xFF000000;
  final c4 = bg.colors[4] | 0xFF000000;
  return [c3, c4, y2kMix(c3, c4, 0.5)];
}

double _minDeltaE(int face, List<int> samples) {
  var m = double.infinity;
  for (final s in samples) {
    final d = deltaEOKArgb(face, s);
    if (d < m) m = d;
  }
  return m;
}

/// The luminance range of a sample list: the darkest and the lightest
/// sample and their luminances.
typedef _YRange = ({int lo, double ylo, int hi, double yhi});

/// Luminance ranges of the (immutable, memoised) sample lists, by
/// identity.
final Expando<_YRange> _ranges = Expando('y2kRanges');

_YRange _rangeOf(List<int> samples) {
  final hit = _ranges[samples];
  if (hit != null) return hit;
  var lo = samples.first;
  var hi = samples.first;
  var ylo = luminanceArgb(lo);
  var yhi = ylo;
  for (final s in samples) {
    final y = luminanceArgb(s);
    if (y < ylo) {
      ylo = y;
      lo = s;
    } else if (y > yhi) {
      yhi = y;
      hi = s;
    }
  }
  final range = (lo: lo, ylo: ylo, hi: hi, yhi: yhi);
  _ranges[samples] = range;
  return range;
}

/// The lowest contrast of [fg] (composited when translucent) over every
/// colour of [backdrops]. Exact; an opaque colour outside the samples'
/// luminance range only needs the nearer extreme.
double _minContrastOn(int fg, List<int> backdrops) {
  if (backdrops.isEmpty) return double.infinity;
  if ((fg >>> 24) == 0xFF) {
    final r = _rangeOf(backdrops);
    final y = luminanceArgb(fg);
    if (y <= r.ylo) return contrastY(y, r.ylo);
    if (y >= r.yhi) return contrastY(y, r.yhi);
  }
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

bool _accentApart(int face, int digit) =>
    contrastRatio(face, digit) >= y2kAccentMinContrast ||
    minCvdDeltaE(face, digit) >= y2kAccentMinDeltaE;

// --------------------------------------------------------------- builder --

/// One scene's colours while the palette is built.
final class _SceneColours {
  new(this.colors, this.light, this.pattern, this.hScene, this.h1);

  /// `colors[0..4]` (opaque).
  final List<int> colors;

  /// `colors[5]` with its alpha.
  final int light;

  /// The bubble / sparkle tint (opaque).
  final int pattern;

  /// The scene hue (tenths): zenith, water surface or holo A.
  final int hScene;

  /// The mid-sky hue (tenths; the holo A hue in CHROME).
  final int h1;

  // AERO light ground (crest c3, base c4), adjusted by the ground fix.
  int hg = 0;
  int h4 = 0;
  double l3 = 0;
  double l4 = 0;
  double c3 = 0;
  double c4 = 0;
}

_SceneColours _sceneColours(Rng p, Y2kScene scene, BileRule bile) {
  switch (scene) {
    case Y2kScene.sky:
    case Y2kScene.meadow:
      final sky = scene == Y2kScene.sky;
      final hs = sky ? p.nextIntIn(2300, 2520) : p.nextIntIn(2180, 2400);
      final l0 = p.nextIntIn(620, sky ? 680 : 700) / 1000;
      final c0 = _lch(
        l0,
        _relC(
          p.nextIntIn(sky ? 850 : 800, sky ? 980 : 950),
          sky ? 170 : 160,
          l0,
          hs,
        ),
        hs,
      );
      final h1 = hs - (sky ? p.nextIntIn(120, 260) : p.nextIntIn(100, 200));
      final l1 = (sky ? p.nextIntIn(800, 860) : p.nextIntIn(820, 880)) / 1000;
      final cc1 = _relC(
        sky ? p.nextIntIn(550, 750) : p.nextIntIn(500, 700),
        sky ? 120 : 100,
        l1,
        h1,
      );
      final c1 = _lch(l1, cc1, h1);
      final l2 = (sky ? p.nextIntIn(945, 975) : p.nextIntIn(930, 960)) / 1000;
      final cc2 = (sky ? p.nextIntIn(18, 35) : p.nextIntIn(25, 45)) / 1000;
      final c2 = _lch(l2, cc2, h1);
      double l3;
      double cc3;
      double l4;
      double cc4;
      int hg;
      int h4;
      if (sky) {
        // A lake under the horizon: the mid sky reflected, deeper.
        hg = h1;
        h4 = h1;
        l3 = l1 - 0.05;
        cc3 = cc1 * 1.15;
        l4 = l1 - 0.13;
        cc4 = cc1 * 1.3;
      } else {
        // Sunlit grass over a deeper green shade (a light or jade-turned
        // grass reads as neon mint).
        hg = p.nextIntIn(1340, 1500);
        l3 = p.nextIntIn(680, 760) / 1000;
        cc3 = _relC(p.nextIntIn(800, 950), 200, l3, hg);
        h4 = hg + p.nextIntIn(20, 60);
        l4 = p.nextIntIn(540, 600) / 1000;
        cc4 = _relC(p.nextIntIn(850, 980), 170, l4, h4);
      }
      final light = withAlpha(
        _lch(
          p.nextIntIn(985, 995) / 1000,
          p.nextIntIn(12, 25) / 1000,
          p.nextIntIn(850, 980),
        ),
        y2kLightCap(BackgroundKind.aeroSky, dark: false),
      );
      final s = _SceneColours(
        [c0, c1, c2, _lch(l3, cc3, hg), _lch(l4, cc4, h4)],
        light,
        _lch(0.985, 0.02, h1),
        _wrap(hs),
        _wrap(h1),
      );
      s
        ..hg = hg
        ..h4 = h4
        ..l3 = l3
        ..l4 = l4
        ..c3 = cc3
        ..c4 = cc4;
      return s;
    case Y2kScene.water:
      final hw = p.nextIntIn(2000, 2250);
      final l0 = p.nextIntIn(340, 400) / 1000;
      final c0 = _lch(l0, _relC(p.nextIntIn(750, 900), 120, l0, hw), hw);
      final h1 = hw + p.nextIntIn(150, 250);
      final l1 = p.nextIntIn(250, 300) / 1000;
      final c1 = _lch(l1, _relC(p.nextIntIn(750, 900), 110, l1, h1), h1);
      // A blue abyss, still clearly water (a near-black one reads as a
      // plain dark background behind grey keys).
      final h2 = hw + p.nextIntIn(300, 450);
      final l2 = p.nextIntIn(220, 270) / 1000;
      final cc2 = p.nextIntIn(60, 90) / 1000;
      final c2 = _lch(l2, cc2, h2);
      final c4 = _lch(l2 - 0.03, cc2 * 0.9, h2);
      final light = withAlpha(
        _lch(
          p.nextIntIn(820, 880) / 1000,
          p.nextIntIn(50, 80) / 1000,
          hw - p.nextIntIn(0, 50),
        ),
        y2kLightCap(BackgroundKind.aeroSky, dark: true),
      );
      return _SceneColours(
        [c0, c1, c2, c2, c4],
        light,
        _lch(0.94, 0.04, hw),
        _wrap(hw),
        _wrap(h1),
      );
    case Y2kScene.pastelHolo:
    case Y2kScene.blackHolo:
      final pastel = scene == Y2kScene.pastelHolo;
      final h0 = p.nextChance(1, 2)
          ? (3300 + p.nextIntIn(0, 500)) % 3600
          : p.nextHueTenths();
      int stop(int hue, IntRange l, IntRange c) {
        final lm = l.sample(p) / 1000;
        final cm = c.sample(p) / 1000;
        if (pastel) return _lch(lm, cm, _wrap(hue));
        // Dark jewel stops on amber or olive hues gamut-clamp to brown and
        // khaki (camouflage behind the keys): turn them to teal-sapphire.
        var w = _wrap(hue);
        if (w >= 400 && w <= 1350) w += 1500;
        return _lch(lm, cm, bile.apply(w, lm, cm));
      }

      final base = pastel
          ? stop(h0 + 1800, const IntRange(950, 970), const IntRange(6, 15))
          : stop(h0 + 1800, const IntRange(160, 200), const IntRange(10, 25));
      const jewelL = IntRange(300, 370);
      const jewelC = IntRange(95, 135);
      final a = pastel
          ? stop(h0, const IntRange(890, 930), const IntRange(65, 100))
          : stop(h0, jewelL, jewelC);
      final hb = h0 - p.nextIntIn(500, 700);
      final b = pastel
          ? stop(hb, const IntRange(870, 910), const IntRange(65, 100))
          : stop(hb, jewelL, jewelC);
      final hc = h0 - p.nextIntIn(1300, 1500);
      final c = pastel
          ? stop(hc, const IntRange(890, 930), const IntRange(60, 90))
          : stop(hc, jewelL, jewelC);
      final hd = h0 - p.nextIntIn(1800, 2000);
      final d = pastel
          ? stop(hd, const IntRange(900, 940), const IntRange(55, 85))
          : stop(hd, jewelL, jewelC);
      final light = withAlpha(
        pastel ? _lch(0.99, 0.008, h0) : _lch(0.90, 0.02, h0),
        y2kLightCap(BackgroundKind.chromeHolo, dark: !pastel),
      );
      return _SceneColours(
        [base, a, b, c, d],
        light,
        pastel ? _lch(0.99, 0.01, h0) : _lch(0.98, 0.01, h0),
        _wrap(h0),
        _wrap(h0),
      );
  }
}

/// Builds one unvalidated Y2K / Frutiger Aero candidate (the generator
/// repairs and validates it, retries with `palette/retry/n` and finally
/// falls back to a Y2K hero).
ThemeSpec buildY2kAeroCandidate(
  int seed,
  FamilyDefinition def,
  int engineVersion, {
  int attempt = 0,
  bool accessible = false,
}) {
  // Variant and scene parameters (background stream; the variant is the
  // first draw, so it never depends on the palette).
  final bgRng = Rng.stream(seed, RngTag.background);
  final kind = pickWeightedValue(bgRng, def.backgrounds);
  final chrome = kind == BackgroundKind.chromeHolo;
  final meadowDraw = bgRng.pickWeighted(y2kAeroLightSceneWeights) == 1;
  final angle = chrome ? 300 + bgRng.nextInt(401) : bgRng.nextInt(3600);
  final scaleStep = bgRng.nextInt(7);
  final opacityStep = bgRng.nextInt(8);

  // Style, shape and type read only the variant.
  final keyStyle = _style(Rng.stream(seed, RngTag.style), def, chrome: chrome);
  final keyShape = _shape(Rng.stream(seed, RngTag.shape), chrome: chrome);
  final type = _type(Rng.stream(seed, RngTag.type), def, chrome: chrome);

  final paletteTag = attempt == 0
      ? RngTag.palette
      : RngTag.sub(RngTag.palette, 'retry', attempt);
  final p = Rng.stream(seed, paletteTag);
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final brightness = dark ? ThemeBrightness.dark : ThemeBrightness.light;
  final scene = chrome
      ? (dark ? Y2kScene.blackHolo : Y2kScene.pastelHolo)
      : (dark ? Y2kScene.water : (meadowDraw ? Y2kScene.meadow : Y2kScene.sky));
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final bile = def.bile;
  final floor = accessible ? y2kAccessibleFaceMinLMilli : y2kFaceMinLMilli;

  // 1. Scene colours.
  final sc = _sceneColours(p, scene, bile);
  final hScene = sc.hScene;

  // 2. Operator gel.
  final waterGels = scene == Y2kScene.water;
  final table = chrome
      ? y2kChromeCandies
      : (waterGels ? y2kWaterGels : y2kAeroGels);
  int lFor(Y2kGel g) {
    final l = (waterGels ? (g.waterLMilli ?? g.lMilli) : g.lMilli).sample(p);
    return l < floor ? floor : l;
  }

  final i = p.pickWeighted([for (final g in table) g.weight]);
  final opGel = table[i];
  final opHue = _wrap(opGel.hue.sample(p));
  final opL = lFor(opGel);
  final opRel = opGel.rel.sample(p);

  // 3. `=`: blue with green in AERO; a candy 3–6 steps round the table in
  // CHROME.
  final int j;
  if (chrome) {
    // Warm-pink / cool-aqua pairs are Vaporwave's: step to the next k.
    final at = p.pickWeighted(const [2, 3, 3, 2]);
    var jj = (i + 3 + at) % table.length;
    for (var step = 1; step < 4 && y2kVaporPair(i, jj); step++) {
      jj = (i + 3 + (at + step) % 4) % table.length;
    }
    j = jj;
  } else {
    j = i >= 3
        ? const [0, 1, 2][p.pickWeighted(const [3, 3, 1])]
        : const [3, 4, 5][p.pickWeighted(const [2, 3, 1])];
  }
  final eqHueDraw = table[j].hue.sample(p);
  final eqL = lFor(table[j]);
  final eqRel = table[j].rel.sample(p);

  // 4. Digit faces.
  final int digitFace;
  final int digitHue;
  var champagne = false;
  switch (scene) {
    case Y2kScene.sky:
    case Y2kScene.meadow:
      // Pearl gel.
      digitHue = hScene;
      digitFace = _lch(
        p.nextIntIn(940, 975) / 1000,
        p.nextIntIn(8, 25) / 1000,
        hScene,
      );
    case Y2kScene.water:
      // Moonstone gel: a blue-lavender glow 45° round from the water (a
      // paler, greyer one reads as dishwater).
      digitHue = _wrap(hScene + 450);
      var l = p.nextIntIn(740, 755);
      if (l < floor) l = floor;
      digitFace = _lch(l / 1000, p.nextIntIn(55, 75) / 1000, digitHue);
    case Y2kScene.pastelHolo:
    case Y2kScene.blackHolo:
      // Satin silver, cool or (one in four) champagne.
      champagne = p.nextChance(1, 4);
      digitHue = champagne ? p.nextIntIn(700, 880) : p.nextIntIn(2300, 2620);
      final l = scene == Y2kScene.pastelHolo
          ? p.nextIntIn(890, 930)
          : p.nextIntIn(880, 920);
      final c = champagne ? p.nextIntIn(10, 22) : p.nextIntIn(4, 14);
      digitFace = _lch(l / 1000, c / 1000, digitHue);
  }

  // 5. Function faces.
  final int fnFace;
  switch (scene) {
    case Y2kScene.sky:
    case Y2kScene.meadow:
      // Frost gel: icy cyan turned off the mid sky so it reads against
      // it, or periwinkle beside an aqua operator (never its twin).
      final h = sc.h1 - 350;
      fnFace = _lch(
        p.nextIntIn(840, 890) / 1000,
        p.nextIntIn(55, 80) / 1000,
        i == 3 ? sc.h1 + 250 : (h < 1950 ? 1950 : (h > 2150 ? 2150 : h)),
      );
    case Y2kScene.water:
      // Sea glass.
      fnFace = _lch(
        p.nextIntIn(850, 900) / 1000,
        p.nextIntIn(40, 70) / 1000,
        hScene - p.nextIntIn(0, 200),
      );
    case Y2kScene.pastelHolo:
    case Y2kScene.blackHolo:
      // Titanium (beside champagne a cool graphite: a warm one reads as
      // taupe).
      var l = scene == Y2kScene.pastelHolo
          ? p.nextIntIn(760, 820)
          : p.nextIntIn(760, 800);
      if (l < floor) l = floor;
      fnFace = champagne
          ? _lch(l / 1000, p.nextIntIn(6, 12) / 1000, 2450)
          : _lch(l / 1000, p.nextIntIn(6, 18) / 1000, digitHue);
  }

  // 6. Label chroma.
  final labelC = p.nextIntIn(20, 40) / 1000;

  // 7. Display panel.
  final int surface;
  if (chrome) {
    // An ice or (one in three) pale lilac LCD: a mint one with heavy
    // digits drifts toward Retro's green LCD.
    final lilac = p.nextChance(1, 3);
    final h = lilac ? p.nextIntIn(2850, 3050) : p.nextIntIn(2050, 2250);
    surface = dark
        ? _lch(p.nextIntIn(160, 210) / 1000, p.nextIntIn(10, 30) / 1000, h)
        : _lch(p.nextIntIn(860, 910) / 1000, p.nextIntIn(40, 70) / 1000, h);
  } else {
    surface = dark
        ? _lch(p.nextIntIn(160, 210) / 1000, p.nextIntIn(20, 40) / 1000, hScene)
        : _lch(
            p.nextIntIn(895, 930) / 1000,
            p.nextIntIn(25, 45) / 1000,
            hScene,
          );
  }
  // No palette draws below: everything else is solved.

  // Operators stand apart from digits (contrast or CVD distance).
  final opFace = _apartOperator(opGel, opHue, opL, opRel, digitFace, floor);

  // `=`: the drawn entry, then its neighbours in the pairing group, each
  // at the drawn lightness and nearby: the first that stands apart from
  // the operator (CVD 0.065) and from the digits.
  final eqFaceFinal = _equalsFace(
    table,
    i: i,
    j: j,
    chrome: chrome,
    hueDraw: eqHueDraw,
    lMilli: eqL,
    rel: eqRel,
    opFace: opFace,
    digitFace: digitFace,
    floor: floor,
  );

  // AERO light: keys stand apart from the ground band behind the keypad
  // (rotate the ground hue away from the nearest key, then darken it).
  final colors = [...sc.colors];
  if (scene == Y2kScene.sky || scene == Y2kScene.meadow) {
    _groundFix(colors, sc, [
      digitFace,
      fnFace,
      if (scene == Y2kScene.meadow) ...[opFace, eqFaceFinal],
    ], sky: scene == Y2kScene.sky);
  }

  final background = BackgroundSpec(
    kind: kind,
    colors: List.unmodifiable([...colors, sc.light]),
    angleTenths: angle,
    pattern: BackgroundPattern.dots,
    patternColor: sc.pattern | 0xFF000000,
    patternScaleCdp: chrome ? 600 + 100 * scaleStep : 1400 + 200 * scaleStep,
    patternOpacityPermille: switch (scene) {
      Y2kScene.sky || Y2kScene.meadow => 380 + 20 * opacityStep,
      Y2kScene.water => 180 + 20 * (opacityStep ~/ 2),
      Y2kScene.pastelHolo => 500 + 25 * opacityStep,
      Y2kScene.blackHolo => 160 + 10 * opacityStep,
    },
    driftPeriodMs: chrome ? y2kChromeDriftMs : y2kAeroDriftMs,
  );

  // Keys: dark labels solved on every colour of the label zone; the face
  // lifts 0.03 at a time when that fails.
  final depth = keyStyle.edgeShadePermille;
  final refraction = keyStyle.refractionPermille;
  final labelL =
      (accessible ? y2kAccessibleLabelStartLMilli : y2kLabelStartLMilli) / 1000;
  (int, int) solve(int face, int accent, {required bool metal}) => _solveKey(
    face,
    accent,
    metal: metal,
    depth: depth,
    refraction: refraction,
    labelL: labelL,
    labelC: labelC,
    neutralHue: digitHue,
    ratio: lim.labelRatio,
    accessible: accessible,
  );

  final (opF, opLabel) = solve(opFace, _hueTenths(opFace), metal: false);
  final accent = _hueTenths(opF);
  final (eqF, eqLabel) = solve(eqFaceFinal, accent, metal: false);
  final (digitF, digitLabel) = solve(digitFace, accent, metal: chrome);
  final (fnF, fnLabel) = solve(fnFace, accent, metal: chrome);

  // Shadows: always a soft drop shadow (on dark scenes a deep one, so the
  // keys read as solid gel rather than Liquid Glass's glow).
  final int shadow;
  if (chrome) {
    shadow = dark
        ? withAlpha(_lch(0.06, 0.01, 2800), y2kDarkShadowAlpha)
        : withAlpha(_lch(0.36, 0.03, 2800), 0x40);
  } else {
    shadow = dark
        ? withAlpha(_lch(0.06, 0.03, hScene), y2kDarkShadowAlpha)
        : withAlpha(_lch(0.32, 0.07, hScene), 0x47);
  }

  final bgs = y2kAeroSceneSamples(background) ?? backgroundSamples(background);
  final edgeSamples = y2kEdgeSamples(bgs, shadow);
  final edgeEnds = _extremes(edgeSamples);
  int edgeFor(int face) {
    final e = chrome ? y2kChromeEdge(digitHue) : y2kAeroEdge(face);
    if (!accessible) return e;
    return _solveOpaque(e, edgeEnds, edgeSamples, ratioLarge) ??
        blackOrWhite(colors[0]);
  }

  KeyColors key(int face, int label) =>
      KeyColors(face: face, label: label, edge: edgeFor(face));

  final digit = key(digitF, digitLabel);
  final function = key(fnF, fnLabel);
  final operator = key(opF, opLabel);
  final equals = key(eqF, eqLabel);

  final ring =
      _solveOpaque(
        dark ? _lch(0.95, 0.03, hScene) : _lch(0.28, 0.08, hScene),
        edgeEnds,
        edgeSamples,
        lim.focusRingRatio,
      ) ??
      blackOrWhite(colors[0]);

  // Display texts on the panel and its gloss.
  final backdrops = y2kPanelSamples(surface, chrome: chrome);
  final panelHue = _hueTenths(surface);
  int onPanel(int start, double target, int fallback) =>
      solveOnAll(start, backdrops, target) ?? fallback;
  final displayText = onPanel(
    dark ? _lch(0.97, 0.012, panelHue) : _lch(0.22, 0.05, panelHue),
    lim.displayRatio,
    blackOrWhite(surface),
  );
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final previewText = onPanel(
    dark ? _lch(0.80, 0.04, panelHue) : _lch(0.44, 0.05, panelHue),
    previewTarget,
    displayText,
  );
  final error = onPanel(
    dark ? _lch(0.74, 0.15, 270) : _lch(0.48, 0.19, 270),
    lim.displayRatio,
    displayText,
  );
  final caretL = dark ? 0.84 : 0.52;
  final caretC0 = 0.8 * maxChroma(caretL, accent / 10);
  final caretC = caretC0 < 0.16 ? caretC0 : 0.16;
  final caret = onPanel(
    _lch(caretL, caretC, bile.apply(accent, caretL, caretC)),
    lim.caretRatio,
    displayText,
  );

  // The Material chrome (settings, history) sits on `background`: the
  // horizon haze under a sky (the saturated zenith fails text contrast),
  // the mid water in deep water, the foil's base under CHROME.
  final palette = Palette(
    background: switch (scene) {
      Y2kScene.sky || Y2kScene.meadow => colors[2],
      Y2kScene.water => colors[1],
      Y2kScene.pastelHolo || Y2kScene.blackHolo => colors[0],
    },
    surface: surface,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: ring,
    accent: ring,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: shadow,
    highlight: 0xFFFFFFFF,
    seedColor: operator.face,
  );

  final motion = def.motionRanges.vary(
    def.motion,
    Rng.stream(seed, RngTag.motion),
  );
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: operator.face,
    family: ThemeFamily.y2kChrome,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.y2kChrome,
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

/// The operator gel at [lMilli], or moved 0.03 at a time (away from the
/// digit's lightness first) until it stands apart from [digitFace].
int _apartOperator(
  Y2kGel g,
  int hue,
  int lMilli,
  int rel,
  int digitFace,
  int floor,
) {
  final face = _gelFace(g, hue, lMilli, rel);
  if (_accentApart(face, digitFace)) return face;
  final digitL = _lOf(digitFace);
  final above = _lOf(face) >= digitL;
  for (final up in [above, !above]) {
    var l = lMilli;
    for (var k = 0; k < 4; k++) {
      l += up ? 30 : -30;
      if (l > y2kFaceMaxLMilli || l < floor) break;
      final f = _gelFace(g, hue, l, rel);
      if (_accentApart(f, digitFace)) return f;
    }
  }
  return face;
}

int _gelFace(Y2kGel g, int hue, int lMilli, int rel) =>
    _lch(lMilli / 1000, _relC(rel, g.capMilli, lMilli / 1000, hue), hue);

/// The `=` face: the drawn entry [j] of [table], then its neighbours (the
/// AERO pairing group, or the next CHROME candies that are not Vaporwave
/// pairs with the operator [i]), each at the drawn lightness and nearby —
/// the first that keeps its distance from the operator (CVD 0.065) and the
/// digits and is about as vivid as the operator (chroma ≥ min(operator
/// − 0.02, 0.12): the `=` never looks weaker than the operators), else the
/// first that stays saturated; a pale one only when nothing else works.
int _equalsFace(
  List<Y2kGel> table, {
  required int i,
  required int j,
  required bool chrome,
  required int hueDraw,
  required int lMilli,
  required int rel,
  required int opFace,
  required int digitFace,
  required int floor,
}) {
  final entries = <int>[j];
  if (chrome) {
    var jj = j;
    while (entries.length < 3) {
      jj = (jj + 1) % table.length;
      if (jj != i && !y2kVaporPair(i, jj)) entries.add(jj);
    }
  } else {
    final group = j >= 3 ? const [3, 4, 5] : const [0, 1, 2];
    final at = group.indexOf(j);
    entries
      ..add(group[(at + 1) % 3])
      ..add(group[(at + 2) % 3]);
  }
  final opC = argbToOklch(opFace).c;
  final vivid = opC - 0.02 < 0.12 ? opC - 0.02 : 0.12;
  final want = vivid > y2kGelMinChroma ? vivid : y2kGelMinChroma;
  int? saturatedFace;
  int? paleFace;
  int? bestFace;
  var bestDistance = -1.0;
  int? anyFace;
  var anyDistance = -1.0;
  for (final e in entries) {
    final g = table[e];
    final hue = e == j
        ? _wrap(hueDraw)
        : _wrap(
            g.hue.lo +
                (hueDraw - table[j].hue.lo).clamp(0, g.hue.hi - g.hue.lo),
          );
    for (final l in [
      lMilli,
      lMilli + 60,
      lMilli - 60,
      lMilli - 30,
      lMilli + 30,
      floor,
    ]) {
      if (l > y2kFaceMaxLMilli || l < floor) continue;
      final f = _gelFace(g, hue, l, rel);
      final d = minCvdDeltaE(f, opFace);
      final apart = _accentApart(f, digitFace);
      if (d >= y2kEqualsMinDeltaE && apart) {
        final c = argbToOklch(f).c;
        if (c >= want) return f;
        if (c >= y2kGelMinChroma) {
          saturatedFace ??= f;
        } else {
          paleFace ??= f;
        }
      }
      if (apart && d > bestDistance) {
        bestDistance = d;
        bestFace = f;
      }
      if (d > anyDistance) {
        anyDistance = d;
        anyFace = f;
      }
    }
  }
  return saturatedFace ??
      paleFace ??
      bestFace ??
      anyFace ??
      _gelFace(table[j], hueDraw, lMilli, rel);
}

/// AERO light skies: moves the ground (`colors[3]`, `colors[4]`) until
/// every face stands [y2kGroundTargetDeltaE] apart from the ground band. A
/// lake turns its hue away from the nearest of [faces] in 12° steps (within
/// the blues), then darkens; grass darkens first (within its sunlit
/// greens), then turns (never past 150°: a jade or mint meadow reads as
/// neon, an olive one as dirty).
void _groundFix(
  List<int> colors,
  _SceneColours sc,
  List<int> faces, {
  required bool sky,
}) {
  (double, int) worst() {
    final ground = [colors[3], colors[4], y2kMix(colors[3], colors[4], 0.5)];
    var m = double.infinity;
    var face = faces.first;
    for (final f in faces) {
      final d = _minDeltaE(f, ground);
      if (d < m) {
        m = d;
        face = f;
      }
    }
    return (m, face);
  }

  void rebuild() {
    colors[3] = _lch(sc.l3, sc.c3, sc.hg);
    colors[4] = _lch(sc.l4, sc.c4, sc.h4);
  }

  void turn() {
    final lo = sky ? 1900 : 1300;
    final hi = sky ? 2550 : 1500;
    for (var r = 0; r < 3; r++) {
      final (d, face) = worst();
      if (d >= y2kGroundTargetDeltaE) return;
      final fh = _hueTenths(face);
      final away = ((sc.hg - fh) % 3600 + 5400) % 3600 - 1800;
      var step = away >= 0 ? 120 : -120;
      if (sc.hg + step > hi || sc.hg + step < lo) step = -step;
      if (sc.hg + step > hi || sc.hg + step < lo) return;
      sc
        ..hg += step
        ..h4 += step;
      rebuild();
    }
  }

  void darken() {
    final f3 = sky ? 0.66 : 0.58;
    final f4 = sky ? 0.56 : 0.52;
    for (var r = 0; r < 4; r++) {
      if (worst().$1 >= y2kGroundTargetDeltaE) return;
      sc
        ..l3 = sc.l3 - 0.04 < f3 ? f3 : sc.l3 - 0.04
        ..l4 = sc.l4 - 0.04 < f4 ? f4 : sc.l4 - 0.04;
      rebuild();
    }
  }

  if (sky) {
    turn();
    darken();
  } else {
    darken();
    turn();
  }
}

/// A dark label for [face] solved on its label zone; the face lifts 0.03
/// at a time when the label cannot reach [ratio] or would not be darker
/// than the face and the pressed face.
(int, int) _solveKey(
  int face,
  int accent, {
  required bool metal,
  required int depth,
  required int refraction,
  required double labelL,
  required double labelC,
  required int neutralHue,
  required double ratio,
  required bool accessible,
}) {
  var f = face;
  final hue = argbToOklch(f).c < 0.04 ? neutralHue : _hueTenths(f);
  final start = _lch(labelL, labelC, hue);
  for (var round = 0; round <= 6; round++) {
    final zone = y2kLabelZoneSamples(
      f,
      accentHueTenths: accent,
      depthPermille: depth,
      refractionPermille: refraction,
      metal: metal,
      accessible: accessible,
    );
    final label = _solveOpaque(start, _extremes(zone), zone, ratio);
    if (label != null) {
      final y = luminanceArgb(label);
      if (y < luminanceArgb(f) &&
          y < luminanceArgb(y2kPressedFace(f, accent))) {
        return (f, label);
      }
    }
    final x = argbToOklch(f);
    f = oklchToArgb(clamp01(x.l + 0.03), x.c, x.h);
  }
  return (f, blackOrWhite(f));
}

/// The darkest and the lightest of [samples] (by luminance): all an opaque
/// colour outside their range has to clear.
List<int> _extremes(List<int> samples) {
  final r = _rangeOf(samples);
  return [r.lo, r.hi];
}

/// [solveOnAll] against the luminance extremes [ends] of [samples] (the
/// same answer for an opaque colour, far cheaper), checked against every
/// sample, falling back to the full solve.
int? _solveOpaque(int start, List<int> ends, List<int> samples, double target) {
  final r = solveOnAll(start, ends, target);
  if (r != null && _minContrastOn(r, samples) >= target) return r;
  return solveOnAll(start, samples, target);
}

/// Gel orbs and pills (AERO) or chiclets (CHROME).
KeyShapeSpec _shape(Rng s, {required bool chrome}) {
  final kind = pickWeightedValue(
    s,
    chrome
        ? const [
            Weighted(KeyShapeKind.roundedRect, 3),
            Weighted(KeyShapeKind.pill, 1),
          ]
        : const [
            Weighted(KeyShapeKind.pill, 3),
            Weighted(KeyShapeKind.roundedRect, 2),
          ],
  );
  final corner = kind == KeyShapeKind.pill
      ? 500
      : (chrome ? const IntRange(240, 340) : const IntRange(360, 460))
            .sampleStep(s, 10);
  return KeyShapeSpec(kind: kind, cornerPermille: corner);
}

/// The renderer contract: AERO rims of 1–1.5 dp or CHROME bezels of
/// 2.5–3.5 dp, the cap's peak alpha, the caustic, the deep-tone depth and
/// the shadow, all on the `style` stream.
KeyStyleSpec _style(Rng st, FamilyDefinition def, {required bool chrome}) {
  final kind = pickWeightedValue(st, def.styles);
  final outline = chrome ? 250 + 50 * st.nextInt(3) : 100 + 25 * st.nextInt(3);
  return def.keyStyle.copyWith(
    kind: kind,
    outlineWidthCdp: outline,
    highlightPermille: const IntRange(700, 900).sampleStep(st, 20),
    refractionPermille: const IntRange(380, 600).sampleStep(st, 20),
    edgeShadePermille: const IntRange(60, 110).sampleStep(st, 10),
    shadowOffsetCdp: 200 + 50 * st.nextInt(3),
    shadowBlurCdp: 500 + 100 * st.nextInt(4),
  );
}

/// Open Sans: light and airy (AERO) or heavy with a slashed zero
/// (CHROME); operators always ≥ 200 heavier (the recorded cue).
TypeSpec _type(Rng t, FamilyDefinition def, {required bool chrome}) {
  final displayFont = pickWeightedValue(t, def.displayFonts);
  final keyFont = pickWeightedValue(t, def.keyFonts);
  final displayWeight =
      (chrome ? const IntRange(600, 750) : const IntRange(300, 400)).sampleStep(
        t,
        50,
      );
  final keyWeight =
      (chrome ? const IntRange(550, 600) : const IntRange(400, 550)).sampleStep(
        t,
        50,
      );
  final bonus = (chrome ? const IntRange(200, 250) : const IntRange(200, 300))
      .sampleStep(t, 50);
  final op = keyWeight + bonus;
  return TypeSpec(
    displayFont: displayFont,
    keyFont: keyFont,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeight: op > 800 ? 800 : op,
    slashedZero: chrome,
  );
}

// ------------------------------------------------------------ guardrails --

typedef _Group = (String, KeyColors, bool);

List<_Group> _groups(Palette p, {required bool chrome}) => [
  ('digit', p.digit, chrome),
  ('operator', p.operator, false),
  ('equals', p.equals, false),
  ('function', p.function, chrome),
];

/// The family-specific guardrails (called from `validateTheme` for
/// [ThemeFamily.y2kChrome] specs only); [bgs] are the scene samples.
List<GuardrailViolation> validateY2kAero(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final out = <GuardrailViolation>[];
  final p = spec.palette;
  final bg = spec.background;
  final chrome = bg.kind == BackgroundKind.chromeHolo;
  final accessible = spec.accessible;
  final style = spec.keyStyle;
  final accent = y2kAccentHueTenths(p);
  final faceFloor =
      (accessible ? y2kAccessibleFaceFloorMilli : y2kFaceFloorMilli) / 1000;

  void add(GuardrailRule rule, double measured, double required, String d) =>
      out.add(GuardrailViolation(rule, measured, required, d));

  for (final (name, k, metal) in _groups(p, chrome: chrome)) {
    final opaque = ((k.face >>> 24) & 0xFF) == 255;
    final zone = y2kLabelZoneSamples(
      k.face,
      accentHueTenths: accent,
      depthPermille: style.edgeShadePermille,
      refractionPermille: style.refractionPermille,
      metal: metal,
      accessible: accessible,
    );
    final r = _minContrastOn(k.label, zone);
    if (r < lim.labelRatio) {
      add(GuardrailRule.y2kLabelZone, r, lim.labelRatio, name);
    }
    final y = luminanceArgb(k.label | 0xFF000000);
    final face = k.face | 0xFF000000;
    final l = _lOf(face);
    if (!opaque ||
        y >= luminanceArgb(face) ||
        y >= luminanceArgb(y2kPressedFace(face, accent)) ||
        l < faceFloor) {
      add(GuardrailRule.y2kLabelPolarity, l, faceFloor, name);
    }
  }

  final rimRange = chrome ? y2kChromeBezelCdp : y2kAeroRimCdp;
  if (p.highlight != 0xFFFFFFFF ||
      style.kind != KeyStyleKind.glass ||
      !y2kHighlightRange.contains(style.highlightPermille) ||
      !y2kRefractionRange.contains(style.refractionPermille) ||
      !y2kEdgeShadeRange.contains(style.edgeShadePermille) ||
      !rimRange.contains(style.outlineWidthCdp) ||
      !y2kShadowBlurCdp.contains(style.shadowBlurCdp) ||
      !y2kShadowOffsetCdp.contains(style.shadowOffsetCdp) ||
      style.stateLayerPermille != 0 ||
      style.opacityPermille != 1000) {
    add(GuardrailRule.y2kGloss, 0, 1, 'renderer contract');
  }

  final dark = spec.isDark;
  final sceneOk =
      (bg.kind == BackgroundKind.aeroSky ||
          bg.kind == BackgroundKind.chromeHolo) &&
      bg.colors.length == 6 &&
      bg.colors.take(5).every((c) => (c >>> 24) == 0xFF) &&
      ((bg.colors.length < 6 ? 0 : bg.colors[5]) >>> 24) <=
          y2kLightCap(bg.kind, dark: dark) &&
      (bg.patternColor >>> 24) == 0xFF &&
      (bg.pattern == BackgroundPattern.none ||
          bg.pattern == BackgroundPattern.dots) &&
      bg.patternOpacityPermille <= y2kPatternCap(bg.kind, dark: dark) &&
      (bg.driftPeriodMs == 0 || bg.driftPeriodMs >= 40000);
  if (!sceneOk) add(GuardrailRule.y2kScene, 0, 1, 'scene');

  final surface = p.surface;
  final panelL = _lOf(surface | 0xFF000000);
  if ((surface >>> 24) != 0xFF ||
      (panelL < y2kPanelLightMinMilli / 1000 &&
          panelL > y2kPanelDarkMaxMilli / 1000)) {
    add(GuardrailRule.y2kPanel, panelL, y2kPanelLightMinMilli / 1000, 'panel');
  }

  final edges = y2kEdgeSamples(bgs, p.shadow);
  final ring = _minContrastOn(p.focusRing, edges);
  if (ring < lim.focusRingRatio) {
    add(GuardrailRule.y2kRim, ring, lim.focusRingRatio, 'focus ring');
  }
  if (accessible) {
    for (final (name, k, _) in _groups(p, chrome: chrome)) {
      final opaque = (k.edge >>> 24) == 0xFF;
      final r = opaque ? _minContrastOn(k.edge, edges) : 1.0;
      if (r < ratioLarge) add(GuardrailRule.y2kRim, r, ratioLarge, name);
    }
  }

  if (spec.nonColourOperatorCue == OperatorCue.weight) {
    final bonus = spec.type.operatorWeight - spec.type.keyWeight;
    if (bonus < 200) {
      add(GuardrailRule.y2kOperatorCue, bonus.toDouble(), 200, 'weight bonus');
    }
  }

  final digit = p.digit.face | 0xFF000000;
  for (final (name, k) in [('operator', p.operator), ('equals', p.equals)]) {
    final f = k.face | 0xFF000000;
    if (!_accentApart(f, digit)) {
      add(
        GuardrailRule.y2kAccentVsDigit,
        minCvdDeltaE(f, digit),
        y2kAccentMinDeltaE,
        name,
      );
    }
  }

  if (bg.kind == BackgroundKind.aeroSky && !dark && bg.colors.length == 6) {
    final ground = y2kGroundSamples(bg);
    final meadow = y2kIsMeadow(bg);
    for (final (name, k, _) in _groups(p, chrome: false)) {
      if (!meadow && (name == 'operator' || name == 'equals')) continue;
      final d = _minDeltaE(k.face | 0xFF000000, ground);
      if (d < y2kGroundMinDeltaE) {
        add(GuardrailRule.y2kGround, d, y2kGroundMinDeltaE, name);
      }
    }
  }
  return out;
}

/// Family-specific repairs after labels and display texts (called from
/// `repairTheme` for [ThemeFamily.y2kChrome] specs only); null =
/// unrepairable. Each key face is lifted to the gel floor and its label
/// re-solved on its label zone (the face lifting 0.03 at a time when the
/// label alone cannot reach the floor); AERO rims follow the final faces;
/// under the Accessible lock every rim, and always the focus ring, is
/// solved to 3:1 on the scene and the keys' shadow.
Palette? repairY2kAeroExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final chrome = spec.background.kind == BackgroundKind.chromeHolo;
  final accessible = spec.accessible;
  final style = spec.keyStyle;
  final floor =
      (accessible ? y2kAccessibleFaceMinLMilli : y2kFaceMinLMilli) / 1000;
  final labelL =
      (accessible ? y2kAccessibleLabelStartLMilli : y2kLabelStartLMilli) / 1000;
  final edges = y2kEdgeSamples(bgs, p.shadow);
  final digitHue = _hueTenths(p.digit.face | 0xFF000000);

  KeyColors? fix(KeyColors k, int accent, {required bool metal}) {
    var f = k.face | 0xFF000000;
    var x = argbToOklch(f);
    if (x.l < floor - 0.005) {
      f = oklchToArgb(floor, x.c, x.h);
      x = argbToOklch(f);
    }
    final labelLch = argbToOklch(k.label | 0xFF000000);
    final hue = x.c < 0.04 ? digitHue : _hueTenths(f);
    final c = labelLch.c < 0.04 ? labelLch.c : 0.04;
    for (var round = 0; round <= 6; round++) {
      final zone = y2kLabelZoneSamples(
        f,
        accentHueTenths: accent,
        depthPermille: style.edgeShadePermille,
        refractionPermille: style.refractionPermille,
        metal: metal,
        accessible: accessible,
      );
      int? label = k.label | 0xFF000000;
      bool darker(int l) {
        final y = luminanceArgb(l);
        return y < luminanceArgb(f) &&
            y < luminanceArgb(y2kPressedFace(f, accent));
      }

      if (f != (k.face | 0xFF000000) ||
          _minContrastOn(label, zone) < lim.labelRatio ||
          !darker(label)) {
        label = solveOnAll(
          _lch(labelL < labelLch.l ? labelL : labelLch.l, c, hue),
          zone,
          lim.labelRatio,
        );
      }
      if (label != null && darker(label)) {
        var edge = chrome ? k.edge | 0xFF000000 : y2kAeroEdge(f);
        if (accessible) {
          final solved = solveOnAll(edge, edges, ratioLarge);
          if (solved == null) return null;
          edge = solved;
        }
        return KeyColors(face: f, label: label, edge: edge);
      }
      f = oklchToArgb(clamp01(x.l + 0.03 * (round + 1)), x.c, x.h);
    }
    return null;
  }

  final op = fix(
    p.operator,
    _hueTenths(p.operator.face | 0xFF000000),
    metal: false,
  );
  if (op == null) return null;
  final accent = _hueTenths(op.face);
  final eq = fix(p.equals, accent, metal: false);
  final digit = fix(p.digit, accent, metal: chrome);
  final fn = fix(p.function, accent, metal: chrome);
  if (eq == null || digit == null || fn == null) return null;
  final ring = solveOnAll(p.focusRing | 0xFF000000, edges, lim.focusRingRatio);
  if (ring == null) return null;
  return p.copyWith(
    digit: digit,
    operator: op,
    equals: eq,
    function: fn,
    focusRing: ring,
    accent: ring,
    seedColor: op.face,
  );
}

/// Everything display text of [spec] may be drawn on, for
/// `displayBackdrops`: the opaque panel, the panel under its gloss band
/// and (CHROME) under the gloss and the glare ([y2kPanelSamples]);
/// display text never sits on the bare scene.
List<int>? y2kAeroDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) {
  final chrome = spec.background.kind == BackgroundKind.chromeHolo;
  return [for (final s in surfaces) ...y2kPanelSamples(s, chrome: chrome)];
}
