/// Theme families (spec §5.3) and what each may generate (spec §5.2):
/// allowed shapes, styles, fonts, backgrounds and effects with **integer**
/// weights, harmony schemes, OKLCH role ranges for dark and light themes
/// (research theme-engine.md §5.3) and motion tokens plus their seeded
/// ranges (motion brief §2.3, §2.5).
///
/// Everything here is part of `engineVersion`: changing a weight, range or
/// list order changes generated themes.
library;

import 'package:calsee_themes/engine/bauhaus.dart';
import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/cyberpunk.dart';
import 'package:calsee_themes/engine/liquid_glass.dart';
import 'package:calsee_themes/engine/neo_brutalism.dart';
import 'package:calsee_themes/engine/paper_ink.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';

/// Theme families. [id] is the stable 5-bit number used in share codes and
/// JSON — never use `index`. Ids 30 (reserved) and 31 (hero, see
/// `share_code.dart`) are never families.
enum ThemeFamily {
  /// The M2 baseline theme expressed as a ThemeSpec. Never generated and
  /// never in the swipe feed.
  plain(0, enabled: false),
  m3Expressive(1, enabled: true),
  liquidGlass(2, enabled: true),
  neoPop(3, enabled: true),
  neumorphism(4, enabled: true),
  retro(5, enabled: true),
  neoBrutalism(6, enabled: true),
  claymorphism(7, enabled: true),
  pixel(8, enabled: false),
  aurora(9, enabled: false),
  y2kChrome(10, enabled: true),
  paperInk(11, enabled: true),
  terminal(12, enabled: false),
  cyberpunk(13, enabled: true),
  vaporwave(14, enabled: true),
  bauhaus(15, enabled: true);

  const ThemeFamily(this.id, {required this.enabled});

  /// Stable numeric id (0–29).
  final int id;

  /// Whether the generator and feed produce this family in this build.
  final bool enabled;

  /// Families the generator can produce now.
  static List<ThemeFamily> get enabledFamilies => [
    for (final f in values)
      if (f.enabled) f,
  ];

  /// Looks up a family by [id]; null if unknown.
  static ThemeFamily? fromId(int id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// This family's generator definition at the newest engine version
  /// (the placeholder definition for families no version has shipped).
  FamilyDefinition get definition =>
      familyDefinitionAt(this, latestDefinedEngineVersion) ??
      familyDefinitions[this]!;
}

/// Colour-harmony schemes as OKLCH hue offsets (research §5.2).
enum HarmonyScheme {
  monochrome,
  analogous,
  complementary,
  splitComplementary,
  triadic,
  duotone,
}

/// A value with an integer sampling weight.
final class Weighted<T> {
  const Weighted(this.value, this.weight);

  final T value;

  /// Non-negative integer weight.
  final int weight;
}

/// Picks from [options] by integer weight (research §9.5).
T pickWeightedValue<T>(Rng rng, List<Weighted<T>> options) =>
    options[rng.pickWeighted([for (final o in options) o.weight])].value;

/// Inclusive integer range.
final class IntRange {
  const IntRange(this.lo, this.hi);

  /// A single value.
  const IntRange.single(int v) : lo = v, hi = v;

  final int lo;
  final int hi;

  /// Uniform integer in `[lo, hi]`.
  int sample(Rng rng) => rng.nextIntIn(lo, hi);

  /// Uniform value on a grid of [step] within `[lo, hi]` (e.g. whole-dp
  /// steps of 100 for dp × 100 values).
  int sampleStep(Rng rng, int step) =>
      lo + step * rng.nextInt((hi - lo) ~/ step + 1);

  bool contains(int v) => v >= lo && v <= hi;

  int clamp(int v) => v < lo ? lo : (v > hi ? hi : v);
}

/// Chroma range: absolute (thousandths of OKLCH chroma) or relative
/// (thousandths of `maxChroma(L, h)`, then an absolute cap in thousandths).
final class ChromaRange {
  /// Absolute chroma in `[loMilli, hiMilli] / 1000`.
  const ChromaRange.abs(this.lo, this.hi) : relative = false, capMilli = 400;

  /// `rel · maxChroma(L,h)` with rel in `[lo, hi] / 1000`, capped at
  /// [capMilli] / 1000.
  const ChromaRange.rel(this.lo, this.hi, this.capMilli) : relative = true;

  final bool relative;
  final int lo;
  final int hi;
  final int capMilli;
}

/// OKLCH lightness (thousandths) + chroma range for one role.
final class RoleRange {
  const RoleRange(this.lMilli, this.chroma);

  /// Lightness × 1000.
  final IntRange lMilli;
  final ChromaRange chroma;
}

/// Role ranges for one brightness (research §5.3).
final class RoleRanges {
  const RoleRanges({
    required this.background,
    required this.surfaceOffsetMilli,
    required this.surfaceChroma,
    required this.digit,
    required this.digitDuotoneChroma,
    required this.function,
    required this.operator,
    required this.operatorMonochromeL,
    required this.equals,
    required this.labelStartLMilli,
    required this.labelMaxChromaMilli,
    required this.accentChroma,
    required this.minDigitAboveBackgroundMilli,
    this.minDigitBelowBackgroundMilli = 0,
    this.minFunctionBelowDigitMilli = 0,
    this.accentCuspOffsetMilli,
    this.accentCuspClampMilli,
  });

  final RoleRange background;

  /// Display surface lightness offset from the background × 1000 (signed).
  final IntRange surfaceOffsetMilli;
  final ChromaRange surfaceChroma;
  final RoleRange digit;

  /// Digit chroma under the duotone scheme (every surface tinted).
  final ChromaRange digitDuotoneChroma;
  final RoleRange function;
  final RoleRange operator;

  /// Operator lightness under the monochrome scheme.
  final IntRange operatorMonochromeL;
  final RoleRange equals;

  /// Label search start lightness × 1000 (solved afterwards).
  final int labelStartLMilli;

  /// Label chroma ceiling × 1000.
  final int labelMaxChromaMilli;
  final ChromaRange accentChroma;

  /// Digit face lightness must exceed background by this (× 1000; dark
  /// themes keep keys visible). 0 = no constraint.
  final int minDigitAboveBackgroundMilli;

  /// Light themes: digit faces at least this far (L × 1000) below the
  /// background, so keys never vanish into it (engine v2; 0 = off).
  final int minDigitBelowBackgroundMilli;

  /// Light themes: function faces at least this far below the digit faces
  /// (engine v2; 0 = off).
  final int minFunctionBelowDigitMilli;

  /// When set (engine v2 NeoPOP), operator and `=` lightness is drawn as
  /// this offset from the hue's chroma cusp (the lightness of its most
  /// saturated colour) and clamped to [accentCuspClampMilli], so every hue
  /// stays vivid instead of washing out to a pastel.
  final IntRange? accentCuspOffsetMilli;

  /// Clamp for cusp-relative accent lightness.
  final IntRange? accentCuspClampMilli;
}

/// The "disliked colour" rule (research §5.4, MCU DislikeAnalyzer): hues in
/// [loTenths, hiTenths] with chroma above [minChroma] and lightness below
/// [maxL] read as bile / olive and are rotated to [lowTarget] (hues below
/// the band's middle) or [highTarget].
final class BileRule {
  const BileRule({
    required this.loTenths,
    required this.hiTenths,
    required this.maxL,
    required this.lowTarget,
    required this.highTarget,
    this.minChroma = 0.05,
    this.recheckFinal = false,
    this.accessibleLightAccentBand,
  });

  /// Engine v1: 88–110°, L < 0.70, rotated just outside the band.
  static const BileRule v1 = BileRule(
    loTenths: 880,
    hiTenths: 1100,
    maxL: 0.70,
    lowTarget: 870,
    highTarget: 1110,
  );

  /// Engine v2: 75–115°, L < 0.72, rotated ≥ 20° clear (55° / 135°),
  /// re-checked on the final colours after every lightness repair; under
  /// the Accessible lock in light themes operator and `=` hues leave
  /// 50–120° before their lightness is clamped dark (a dark yellow is
  /// brown).
  static const BileRule v2 = BileRule(
    loTenths: 750,
    hiTenths: 1150,
    maxL: 0.72,
    lowTarget: 550,
    highTarget: 1350,
    recheckFinal: true,
    accessibleLightAccentBand: IntRange(500, 1200),
  );

  final int loTenths;
  final int hiTenths;
  final double maxL;
  final double minChroma;
  final int lowTarget;
  final int highTarget;

  /// Re-apply the rule to final faces after label repair moved them.
  final bool recheckFinal;

  /// Accessible light themes: accent hues inside this band (tenths) move
  /// to its nearer edge ± 5° before the dark clamp; null = off.
  final IntRange? accessibleLightAccentBand;

  /// Whether (l, c, hue) is disliked.
  bool dislikes(int hueTenths, double l, double c) =>
      c > minChroma &&
      l < maxL &&
      hueTenths >= loTenths &&
      hueTenths <= hiTenths;

  /// [hueTenths] rotated out of the band when (l, c) is disliked.
  int apply(int hueTenths, double l, double c) {
    if (!dislikes(hueTenths, l, c)) return hueTenths;
    return hueTenths < (loTenths + hiTenths) ~/ 2 ? lowTarget : highTarget;
  }
}

/// Standard dark ranges (research §5.3).
const RoleRanges standardDarkRanges = RoleRanges(
  background: RoleRange(IntRange(130, 200), ChromaRange.abs(0, 30)),
  surfaceOffsetMilli: IntRange(30, 60),
  surfaceChroma: ChromaRange.abs(0, 40),
  digit: RoleRange(IntRange(250, 360), ChromaRange.abs(10, 60)),
  digitDuotoneChroma: ChromaRange.rel(350, 600, 90),
  function: RoleRange(IntRange(400, 520), ChromaRange.abs(20, 80)),
  operator: RoleRange(IntRange(620, 820), ChromaRange.rel(550, 900, 220)),
  operatorMonochromeL: IntRange(660, 840),
  equals: RoleRange(IntRange(620, 850), ChromaRange.rel(700, 950, 240)),
  labelStartLMilli: 950,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(600, 900, 250),
  minDigitAboveBackgroundMilli: 100,
);

/// Standard light ranges (research §5.3).
const RoleRanges standardLightRanges = RoleRanges(
  background: RoleRange(IntRange(950, 990), ChromaRange.abs(0, 20)),
  surfaceOffsetMilli: IntRange(-50, -20),
  surfaceChroma: ChromaRange.abs(0, 30),
  digit: RoleRange(IntRange(880, 980), ChromaRange.abs(0, 30)),
  digitDuotoneChroma: ChromaRange.rel(250, 500, 60),
  function: RoleRange(IntRange(800, 880), ChromaRange.abs(20, 60)),
  operator: RoleRange(IntRange(500, 680), ChromaRange.rel(600, 900, 200)),
  operatorMonochromeL: IntRange(500, 680),
  equals: RoleRange(IntRange(450, 620), ChromaRange.rel(700, 950, 220)),
  labelStartLMilli: 200,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(600, 900, 250),
  minDigitAboveBackgroundMilli: 0,
);

/// Seeded motion variation (motion brief §2.5). `pressIn` is never varied.
/// Engine v2 light ranges (review: digit keys vanished into light
/// backgrounds, function keys merged with digits): background 965–990,
/// digits 870–925 and ≥ 0.04 below the background, function keys 780–850
/// and ≥ 0.05 below the digits; digit chroma still capped at 0.03.
const RoleRanges standardLightRangesV2 = RoleRanges(
  background: RoleRange(IntRange(965, 990), ChromaRange.abs(0, 20)),
  surfaceOffsetMilli: IntRange(-50, -20),
  surfaceChroma: ChromaRange.abs(0, 30),
  digit: RoleRange(IntRange(870, 925), ChromaRange.abs(0, 30)),
  digitDuotoneChroma: ChromaRange.rel(250, 500, 60),
  function: RoleRange(IntRange(780, 850), ChromaRange.abs(20, 60)),
  operator: RoleRange(IntRange(500, 680), ChromaRange.rel(600, 900, 200)),
  operatorMonochromeL: IntRange(500, 680),
  equals: RoleRange(IntRange(450, 620), ChromaRange.rel(700, 950, 220)),
  labelStartLMilli: 200,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(600, 900, 250),
  minDigitAboveBackgroundMilli: 0,
  minDigitBelowBackgroundMilli: 40,
  minFunctionBelowDigitMilli: 50,
);

/// Engine v2 NeoPOP dark ranges (review: khaki function keys, pastel
/// accents): near-neutral function faces (C ≤ 0.015) and operator / `=`
/// lightness at the hue's chroma cusp ± 0.06, clamped to 0.62–0.80.
const RoleRanges neoPopDarkRangesV2 = RoleRanges(
  background: RoleRange(IntRange(130, 190), ChromaRange.abs(0, 20)),
  surfaceOffsetMilli: IntRange(30, 60),
  surfaceChroma: ChromaRange.abs(0, 25),
  digit: RoleRange(IntRange(260, 340), ChromaRange.abs(0, 30)),
  digitDuotoneChroma: ChromaRange.rel(350, 600, 90),
  function: RoleRange(IntRange(420, 520), ChromaRange.abs(0, 15)),
  operator: RoleRange(IntRange(640, 820), ChromaRange.rel(750, 950, 240)),
  operatorMonochromeL: IntRange(660, 840),
  equals: RoleRange(IntRange(660, 860), ChromaRange.rel(800, 1000, 260)),
  labelStartLMilli: 960,
  labelMaxChromaMilli: 40,
  accentChroma: ChromaRange.rel(750, 950, 260),
  minDigitAboveBackgroundMilli: 100,
  accentCuspOffsetMilli: IntRange(-60, 60),
  accentCuspClampMilli: IntRange(620, 800),
);

final class MotionRanges {
  const MotionRanges({
    this.depthCdp,
    this.releaseStiffnessPermille = const [900, 1000, 1100],
    this.bounceJitterPermille = 0,
    this.maxSettleMs = 360,
    this.maxOvershootPermille = 100,
  });

  /// Depth range in dp × 100, sampled on whole-dp steps (null = fixed).
  final IntRange? depthCdp;

  /// Release stiffness multipliers × 1000, picked uniformly.
  final List<int> releaseStiffnessPermille;

  /// ± bounce (ζ) jitter × 1000; bouncy families only.
  final int bounceJitterPermille;

  /// Release settle ceiling.
  final int maxSettleMs;

  /// Release overshoot ceiling × 1000.
  final int maxOvershootPermille;

  /// Smallest ζ × 1000 whose overshoot `exp(−ζπ/√(1−ζ²))` is ≤ 10 %.
  static const int minZetaFor10PercentOvershoot = 591;

  /// Applies seeded variation to [base] from [rng] (the `motion` stream),
  /// clamped so overshoot ≤ 10 % and settle (≈ 4/(ζ√k)) ≤ [maxSettleMs].
  /// Integer arithmetic only.
  MotionSpec vary(MotionSpec base, Rng rng) {
    final depth = depthCdp == null
        ? base.depthCdp
        : depthCdp!.sampleStep(rng, 100);
    final kMul = rng.pick(releaseStiffnessPermille);
    var k = base.release.stiffness * kMul ~/ 1000;
    var zeta = base.release.zetaPermille;
    if (bounceJitterPermille > 0) {
      zeta += rng.nextIntIn(-bounceJitterPermille, bounceJitterPermille);
    }
    if (zeta > 1000) zeta = 1000;
    if (maxOvershootPermille <= 100 && zeta < minZetaFor10PercentOvershoot) {
      zeta = minZetaFor10PercentOvershoot;
    }
    // Settle ≈ 4 / (ζ √k) s ≤ maxSettleMs  ⇔  ζ² k ≥ (4000 / ms)².
    // In integers with ζ × 1000: z² · k · ms² ≥ 16e12.
    final ms = maxSettleMs;
    while (zeta * zeta * k * ms * ms < 16000000000000) {
      k += 10;
    }
    return base.copyWith(depthCdp: depth, release: SpringToken(k, zeta));
  }
}

/// Everything the generator needs to know about a family.
final class FamilyDefinition {
  const FamilyDefinition({
    required this.family,
    required this.brightnessWeights,
    required this.schemes,
    required this.shapes,
    required this.cornerPermille,
    required this.styles,
    required this.keyStyle,
    required this.displayFonts,
    required this.keyFonts,
    required this.displayWeight,
    required this.keyWeight,
    required this.operatorWeightBonus,
    required this.backgrounds,
    required this.sound,
    required this.dark,
    required this.light,
    required this.motion,
    required this.motionRanges,
    this.m3eShapes = const [],
    this.pressedCornerPermille,
    this.patterns = const [Weighted(BackgroundPattern.none, 1)],
    this.effects = const [Weighted(EffectKind.none, 1)],
    this.nonColourOperatorCue = OperatorCue.none,
    this.bile = BileRule.v1,
  });

  final ThemeFamily family;

  /// The disliked-colour rule this definition generates with.
  final BileRule bile;

  /// `[dark, light]` weights.
  final List<int> brightnessWeights;
  final List<Weighted<HarmonyScheme>> schemes;
  final List<Weighted<KeyShapeKind>> shapes;

  /// Material shape-library choices when the shape is
  /// [KeyShapeKind.m3eMorph].
  final List<Weighted<M3eShape>> m3eShapes;

  /// Resting corner (fraction of short side × 1000).
  final IntRange cornerPermille;

  /// Pressed corner (shape morph), if the family morphs.
  final int? pressedCornerPermille;
  final List<Weighted<KeyStyleKind>> styles;

  /// Style parameters (depths, outlines; sampled values come from
  /// [motion] / [motionRanges] where they are shared, e.g. NeoPOP depth).
  final KeyStyleSpec keyStyle;
  final List<Weighted<String>> displayFonts;
  final List<Weighted<String>> keyFonts;

  /// CSS weights.
  final IntRange displayWeight;
  final IntRange keyWeight;

  /// Operator label weight = key weight + this (≥ 200 is a non-colour cue).
  final IntRange operatorWeightBonus;
  final List<Weighted<BackgroundKind>> backgrounds;
  final List<Weighted<BackgroundPattern>> patterns;
  final List<Weighted<EffectKind>> effects;

  /// Default sound pack.
  final SoundPackId sound;

  /// Role ranges for dark and light themes.
  final RoleRanges dark;
  final RoleRanges light;

  /// Base motion tokens (motion brief §2.6).
  final MotionSpec motion;
  final MotionRanges motionRanges;

  /// Non-colour operator cue the family always supplies (spec §5.4), or
  /// [OperatorCue.none] if the colour/contrast rule must pass on its own.
  final OperatorCue nonColourOperatorCue;

  /// Role ranges for [brightness].
  RoleRanges ranges(ThemeBrightness brightness) =>
      brightness == ThemeBrightness.dark ? dark : light;

  /// This definition with [dark], [light] or [bile] replaced (a later
  /// engine version's revision of a family).
  FamilyDefinition revise({
    RoleRanges? dark,
    RoleRanges? light,
    BileRule? bile,
  }) => FamilyDefinition(
    family: family,
    brightnessWeights: brightnessWeights,
    schemes: schemes,
    shapes: shapes,
    cornerPermille: cornerPermille,
    styles: styles,
    keyStyle: keyStyle,
    displayFonts: displayFonts,
    keyFonts: keyFonts,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeightBonus: operatorWeightBonus,
    backgrounds: backgrounds,
    sound: sound,
    dark: dark ?? this.dark,
    light: light ?? this.light,
    motion: motion,
    motionRanges: motionRanges,
    m3eShapes: m3eShapes,
    pressedCornerPermille: pressedCornerPermille,
    patterns: patterns,
    effects: effects,
    nonColourOperatorCue: nonColourOperatorCue,
    bile: bile ?? this.bile,
  );
}

/// Stable font ids (match `BundledFont.id` in lib/themes/render/fonts.dart).
abstract final class FontIds {
  static const String platform = 'platform';
  static const String robotoFlex = 'roboto_flex';
  static const String spaceGrotesk = 'space_grotesk';
  static const String nunito = 'nunito';
  static const String openSans = 'open_sans';
  static const String newsreader = 'newsreader';
  static const String oxanium = 'oxanium';
  static const String anybody = 'anybody';
  static const String jost = 'jost';
}

// ------------------------------------------------------------ definitions --

const List<Weighted<String>> _robotoFlex = [Weighted(FontIds.robotoFlex, 1)];
const List<Weighted<String>> _spaceGrotesk = [
  Weighted(FontIds.spaceGrotesk, 1),
];
const List<Weighted<String>> _platformFont = [Weighted(FontIds.platform, 1)];

/// Material 3 Expressive (spec §5.3 #1; motion brief §2.3 row 1): tonal
/// palettes, shape-morphing keys (full round → 30 % of the short side),
/// scale 0.97, +10 % state layer snapped in frame 1, pop entry.
const FamilyDefinition m3ExpressiveDefinition = FamilyDefinition(
  family: ThemeFamily.m3Expressive,
  brightnessWeights: [1, 1],
  schemes: [
    Weighted(HarmonyScheme.monochrome, 2),
    Weighted(HarmonyScheme.analogous, 4),
    Weighted(HarmonyScheme.complementary, 2),
    Weighted(HarmonyScheme.splitComplementary, 1),
    Weighted(HarmonyScheme.triadic, 1),
    Weighted(HarmonyScheme.duotone, 1),
  ],
  shapes: [Weighted(KeyShapeKind.m3eMorph, 1)],
  m3eShapes: [
    Weighted(M3eShape.circle, 8),
    Weighted(M3eShape.square, 3),
    Weighted(M3eShape.pill, 2),
    Weighted(M3eShape.cookie4Sided, 2),
    Weighted(M3eShape.cookie6Sided, 2),
    Weighted(M3eShape.clover4Leaf, 1),
    Weighted(M3eShape.sunny, 1),
    Weighted(M3eShape.softBurst, 1),
    Weighted(M3eShape.pentagon, 1),
    Weighted(M3eShape.gem, 1),
  ],
  cornerPermille: IntRange.single(500),
  pressedCornerPermille: 300,
  styles: [Weighted(KeyStyleKind.flat, 1)],
  keyStyle: KeyStyleSpec(kind: KeyStyleKind.flat),
  displayFonts: _robotoFlex,
  keyFonts: _robotoFlex,
  displayWeight: IntRange(300, 500),
  keyWeight: IntRange(450, 650),
  operatorWeightBonus: IntRange(100, 200),
  backgrounds: [
    Weighted(BackgroundKind.solid, 5),
    Weighted(BackgroundKind.linearGradient, 2),
  ],
  sound: SoundPackId.softTap,
  dark: standardDarkRanges,
  light: standardLightRanges,
  motion: MotionSpec(
    verb: PressVerb.morph,
    scheme: MotionScheme.expressive,
    pressIn: SpringTokens.effectsFast,
    release: SpringTokens.expressiveFast,
    releaseAlt: SpringTokens.effectsDefault,
    scalePermille: 970,
    cornerPermille: 300,
    squishPermille: 100,
    stateLayerSnap: true,
    entry: EntryStyle.pop,
    entryScalePermille: 850,
    entrySpring: SpringTokens.expressiveFast,
    impact: ImpactStyle.light,
  ),
  motionRanges: MotionRanges(bounceJitterPermille: 50),
);

/// NeoPOP (spec §5.3 #3; motion brief §2.3 row 3): dark base, bright flat
/// colours, hard extruded edges; the face translates (+d, +d) with
/// d = 3–5 dp (seeded), no tint, release haptic, drop entry.
const FamilyDefinition neoPopDefinition = FamilyDefinition(
  family: ThemeFamily.neoPop,
  brightnessWeights: [1, 0],
  schemes: [
    Weighted(HarmonyScheme.complementary, 4),
    Weighted(HarmonyScheme.triadic, 3),
    Weighted(HarmonyScheme.splitComplementary, 2),
    Weighted(HarmonyScheme.analogous, 1),
    Weighted(HarmonyScheme.duotone, 1),
  ],
  shapes: [Weighted(KeyShapeKind.roundedRect, 1)],
  cornerPermille: IntRange(0, 80),
  styles: [Weighted(KeyStyleKind.extruded, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.extruded,
    extrudeDepthCdp: 300,
    edgeShadePermille: 180,
    stateLayerPermille: 0,
  ),
  displayFonts: _spaceGrotesk,
  keyFonts: _spaceGrotesk,
  displayWeight: IntRange(500, 700),
  keyWeight: IntRange(600, 700),
  operatorWeightBonus: IntRange(0, 100),
  backgrounds: [
    Weighted(BackgroundKind.solid, 6),
    Weighted(BackgroundKind.pattern, 2),
  ],
  patterns: [
    Weighted(BackgroundPattern.none, 4),
    Weighted(BackgroundPattern.dots, 2),
    Weighted(BackgroundPattern.grid, 1),
    Weighted(BackgroundPattern.stripes, 1),
  ],
  sound: SoundPackId.pop,
  dark: RoleRanges(
    background: RoleRange(IntRange(130, 190), ChromaRange.abs(0, 20)),
    surfaceOffsetMilli: IntRange(30, 60),
    surfaceChroma: ChromaRange.abs(0, 25),
    digit: RoleRange(IntRange(260, 340), ChromaRange.abs(0, 30)),
    digitDuotoneChroma: ChromaRange.rel(350, 600, 90),
    function: RoleRange(IntRange(420, 520), ChromaRange.abs(10, 60)),
    operator: RoleRange(IntRange(640, 820), ChromaRange.rel(750, 950, 240)),
    operatorMonochromeL: IntRange(660, 840),
    equals: RoleRange(IntRange(660, 860), ChromaRange.rel(800, 1000, 260)),
    labelStartLMilli: 960,
    labelMaxChromaMilli: 40,
    accentChroma: ChromaRange.rel(750, 950, 260),
    minDigitAboveBackgroundMilli: 100,
  ),
  light: standardLightRanges,
  motion: MotionSpec(
    verb: PressVerb.plunge,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.hardPress,
    release: SpringTokens.effectsDefault,
    depthCdp: 300,
    entry: EntryStyle.drop,
    entryOffsetCdp: -600,
    entrySpring: SpringTokens.hardPress,
    impact: ImpactStyle.rigid,
    impactPermille: 900,
    releaseHaptic: true,
    releaseImpactPermille: 400,
  ),
  motionRanges: MotionRanges(depthCdp: IntRange(300, 500)),
);

/// Neumorphism light ranges (research theme-engine.md §7.2): a near-white
/// monochrome base (L 0.88–0.94, C ≤ 0.02) that is also every digit and
/// function face; operators either keep it (accent labels) or take a
/// tinted face ≥ 0.10 darker; `=` is a full accent face. Mid-band bases
/// (L 0.46–0.67) are avoided: they cannot carry 7:1 labels.
const RoleRanges neumorphismLightRanges = RoleRanges(
  background: RoleRange(IntRange(880, 940), ChromaRange.abs(4, 20)),
  surfaceOffsetMilli: IntRange(-20, -8),
  surfaceChroma: ChromaRange.abs(4, 20),
  digit: RoleRange(IntRange(880, 940), ChromaRange.abs(4, 20)),
  digitDuotoneChroma: ChromaRange.abs(4, 20),
  function: RoleRange(IntRange(880, 940), ChromaRange.abs(4, 20)),
  operator: RoleRange(IntRange(700, 790), ChromaRange.abs(80, 150)),
  operatorMonochromeL: IntRange(700, 790),
  equals: RoleRange(IntRange(440, 560), ChromaRange.rel(650, 900, 180)),
  labelStartLMilli: 220,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(700, 950, 200),
  minDigitAboveBackgroundMilli: 0,
);

/// Neumorphism dark ranges (research §7.2): a charcoal base (L 0.20–0.28,
/// C ≤ 0.02); tinted operator faces ≥ 0.10 lighter than it; a light
/// accent `=` with dark ink.
const RoleRanges neumorphismDarkRanges = RoleRanges(
  background: RoleRange(IntRange(200, 280), ChromaRange.abs(4, 20)),
  surfaceOffsetMilli: IntRange(-40, -15),
  surfaceChroma: ChromaRange.abs(4, 20),
  digit: RoleRange(IntRange(200, 280), ChromaRange.abs(4, 20)),
  digitDuotoneChroma: ChromaRange.abs(4, 20),
  function: RoleRange(IntRange(200, 280), ChromaRange.abs(4, 20)),
  operator: RoleRange(IntRange(330, 420), ChromaRange.abs(60, 110)),
  operatorMonochromeL: IntRange(330, 420),
  equals: RoleRange(IntRange(720, 830), ChromaRange.rel(600, 900, 180)),
  labelStartLMilli: 950,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(600, 900, 180),
  minDigitAboveBackgroundMilli: 0,
);

/// Neumorphism / Soft UI (spec §5.3 #4; motion brief §2.3 row 4;
/// docs/m4-design.md §C). Keys are the surface itself, lifted by a light
/// (top-left) and dark (bottom-right) soft shadow pair derived in OKLCH
/// from it, plus the contrast fixes classic neumorphism lacks (research
/// recommendation 7): a 1–1.5 dp rim on the shadow side solved to ≥ 3:1
/// against the surface, labels ≥ 4.5:1 (7:1 accessible), operators with
/// an accent face or accent label *and* a heavier glyph (recorded as
/// [OperatorCue.weight]), and a pressed state that also swaps the label
/// colour and closes the rim (validated: `GuardrailRule.softPressedLabel`).
///
/// Motion: the outer pair snaps off in frame 1, the inner pair grows to
/// 4 dp on `effectsFast`, scale 0.98, release on `effectsDefault`, never
/// bounces. Sound `tick`, haptic soft · 0.5. The palette itself is built
/// by `buildNeumorphicCandidate` (neumorphism.dart).
const FamilyDefinition neumorphismDefinition = FamilyDefinition(
  family: ThemeFamily.neumorphism,
  brightnessWeights: [2, 3],
  schemes: [
    Weighted(HarmonyScheme.monochrome, 3),
    Weighted(HarmonyScheme.analogous, 3),
    Weighted(HarmonyScheme.complementary, 2),
  ],
  shapes: [
    Weighted(KeyShapeKind.roundedRect, 3),
    Weighted(KeyShapeKind.circle, 1),
  ],
  cornerPermille: IntRange(200, 360),
  styles: [Weighted(KeyStyleKind.soft, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.soft,
    outlineWidthCdp: 125,
    shadowOffsetCdp: 300,
    shadowBlurCdp: 600,
    stateLayerPermille: 60,
  ),
  displayFonts: _robotoFlex,
  keyFonts: _robotoFlex,
  displayWeight: IntRange(300, 400),
  keyWeight: IntRange(400, 500),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [Weighted(BackgroundKind.solid, 1)],
  sound: SoundPackId.tick,
  dark: neumorphismDarkRanges,
  light: neumorphismLightRanges,
  motion: MotionSpec(
    verb: PressVerb.sink,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.effectsFast,
    release: SpringTokens.effectsDefault,
    depthCdp: 600,
    scalePermille: 980,
    entry: EntryStyle.rise,
    entryOffsetCdp: 400,
    entrySpring: SpringTokens.effectsDefault,
    impact: ImpactStyle.soft,
    impactPermille: 500,
  ),
  motionRanges: MotionRanges(),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

/// Retro pocket (black / charcoal body) ranges: graphite digit keys at
/// least 0.08 above the body, a function step lighter, muted accent
/// operators and a stronger accent `=` (docs/m4-design.md §B). Only the
/// lightness / chroma ranges are read (by `buildRetroCandidate`); hues
/// come from the Retro tables in retro.dart.
const RoleRanges retroPocketRanges = RoleRanges(
  background: RoleRange(IntRange(170, 240), ChromaRange.abs(0, 12)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(0, 0),
  digit: RoleRange(IntRange(300, 360), ChromaRange.abs(0, 15)),
  digitDuotoneChroma: ChromaRange.abs(0, 15),
  function: RoleRange(IntRange(420, 480), ChromaRange.abs(0, 20)),
  operator: RoleRange(IntRange(600, 700), ChromaRange.rel(450, 650, 120)),
  operatorMonochromeL: IntRange(600, 700),
  equals: RoleRange(IntRange(620, 720), ChromaRange.rel(700, 900, 170)),
  labelStartLMilli: 950,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(600, 900, 160),
  minDigitAboveBackgroundMilli: 80,
);

/// Retro desk (beige / cream body) ranges: cream digit keys above the
/// body (or dark-brown ones, see retro.dart), dark grey function keys,
/// muted accent operators and a stronger accent `=`.
const RoleRanges retroDeskRanges = RoleRanges(
  background: RoleRange(IntRange(790, 860), ChromaRange.abs(18, 42)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(0, 0),
  digit: RoleRange(IntRange(910, 960), ChromaRange.abs(8, 25)),
  digitDuotoneChroma: ChromaRange.abs(8, 25),
  function: RoleRange(IntRange(400, 460), ChromaRange.abs(10, 25)),
  operator: RoleRange(IntRange(560, 660), ChromaRange.rel(450, 650, 120)),
  operatorMonochromeL: IntRange(560, 660),
  equals: RoleRange(IntRange(540, 640), ChromaRange.rel(700, 900, 170)),
  labelStartLMilli: 170,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(600, 900, 160),
  minDigitAboveBackgroundMilli: 0,
);

/// Retro hardware (spec §5.3 #5; motion brief §2.3 "Retro hardware";
/// docs/m4-design.md §B): a 90s desk or pocket calculator. Keycaps with a
/// top-highlight / bottom-shadow bevel that swaps on touch-down (frame 1)
/// and 2–3 dp of travel (seeded, whole dp), `hardPress` in and 1200/0.7
/// out; a 7-segment LCD (or VFD) display drawn by an in-house segment
/// painter (`TypeSpec.lcd`), segments on 30 ms / off 50 ms; sound `beep`
/// (desk themes sometimes `mech_clicky`), haptic rigid plus a release
/// tick. Operators always carry a heavier label ([OperatorCue.weight]).
/// The palette is built by `buildRetroCandidate` (retro.dart).
const FamilyDefinition retroDefinition = FamilyDefinition(
  family: ThemeFamily.retro,
  brightnessWeights: [1, 1],
  schemes: [Weighted(HarmonyScheme.monochrome, 1)],
  shapes: [Weighted(KeyShapeKind.keycap, 1)],
  cornerPermille: IntRange(100, 220),
  styles: [Weighted(KeyStyleKind.extruded, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.extruded,
    extrudeDepthCdp: 250,
    edgeShadePermille: 110,
    shadowOffsetCdp: 100,
    shadowBlurCdp: 200,
    stateLayerPermille: 0,
  ),
  displayFonts: _robotoFlex,
  keyFonts: [
    Weighted(FontIds.robotoFlex, 1),
    Weighted(FontIds.spaceGrotesk, 1),
  ],
  displayWeight: IntRange(400, 500),
  keyWeight: IntRange(450, 500),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [
    Weighted(BackgroundKind.solid, 3),
    Weighted(BackgroundKind.linearGradient, 1),
  ],
  sound: SoundPackId.beep,
  dark: retroPocketRanges,
  light: retroDeskRanges,
  motion: MotionSpec(
    verb: PressVerb.travel,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.hardPress,
    release: SpringToken(1200, 700),
    depthCdp: 250,
    entry: EntryStyle.segments,
    impact: ImpactStyle.rigid,
    releaseHaptic: true,
    releaseImpactPermille: 350,
  ),
  motionRanges: MotionRanges(depthCdp: IntRange(200, 300)),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

/// A disabled family: motion tokens from the brief, generic everything
/// else. Filled in when the family ships.
FamilyDefinition placeholderFamilyDefinition(
  ThemeFamily family,
  MotionSpec motion, {
  required KeyShapeKind shape,
  required KeyStyleKind style,
  required SoundPackId sound,
  MotionRanges motionRanges = const MotionRanges(),
}) => FamilyDefinition(
  family: family,
  brightnessWeights: const [1, 1],
  schemes: const [Weighted(HarmonyScheme.analogous, 1)],
  shapes: [Weighted(shape, 1)],
  cornerPermille: const IntRange(200, 300),
  styles: [Weighted(style, 1)],
  keyStyle: KeyStyleSpec(kind: style),
  displayFonts: _platformFont,
  keyFonts: _platformFont,
  displayWeight: const IntRange(400, 400),
  keyWeight: const IntRange(500, 500),
  operatorWeightBonus: const IntRange(100, 100),
  backgrounds: const [Weighted(BackgroundKind.solid, 1)],
  sound: sound,
  dark: standardDarkRanges,
  light: standardLightRanges,
  motion: motion,
  motionRanges: motionRanges,
);

/// Definitions for every family (disabled ones are placeholders).
final Map<ThemeFamily, FamilyDefinition> familyDefinitions = {
  ThemeFamily.plain: placeholderFamilyDefinition(
    ThemeFamily.plain,
    const MotionSpec(
      verb: PressVerb.fill,
      scheme: MotionScheme.standard,
      pressIn: SpringTokens.effectsFast,
      release: SpringTokens.effectsDefault,
      scalePermille: 950,
      entry: EntryStyle.rise,
      impact: ImpactStyle.light,
    ),
    shape: KeyShapeKind.roundedRect,
    style: KeyStyleKind.flat,
    sound: SoundPackId.softTap,
  ),
  ThemeFamily.m3Expressive: m3ExpressiveDefinition,
  // M5: Liquid Glass (liquid_glass.dart).
  ThemeFamily.liquidGlass: liquidGlassDefinition,
  ThemeFamily.neoPop: neoPopDefinition,
  ThemeFamily.neumorphism: neumorphismDefinition,
  ThemeFamily.retro: retroDefinition,
  // M5: Neo-brutalism (neo_brutalism.dart).
  ThemeFamily.neoBrutalism: neoBrutalismDefinition,
  // Claymorphism (claymorphism.dart).
  ThemeFamily.claymorphism: claymorphismDefinition,
  ThemeFamily.pixel: placeholderFamilyDefinition(
    ThemeFamily.pixel,
    const MotionSpec(
      verb: PressVerb.step,
      scheme: MotionScheme.standard,
      pressIn: SpringTokens.hardPress,
      release: SpringTokens.effectsDefault,
      depthCdp: 300,
      stepMs: 67,
      entry: EntryStyle.step,
      impact: ImpactStyle.rigid,
      impactPermille: 600,
    ),
    shape: KeyShapeKind.stepped,
    style: KeyStyleKind.pixel,
    sound: SoundPackId.chiptune,
  ),
  ThemeFamily.aurora: placeholderFamilyDefinition(
    ThemeFamily.aurora,
    const MotionSpec(
      verb: PressVerb.fill,
      scheme: MotionScheme.standard,
      pressIn: SpringTokens.effectsFast,
      release: SpringTokens.standardFast,
      scalePermille: 970,
      entry: EntryStyle.rise,
      impact: ImpactStyle.light,
      impactPermille: 600,
    ),
    shape: KeyShapeKind.circle,
    style: KeyStyleKind.flat,
    sound: SoundPackId.softTap,
  ),
  // Y2K / Frutiger Aero (y2k_aero.dart).
  ThemeFamily.y2kChrome: y2kAeroDefinition,
  // Paper & ink (paper_ink.dart).
  ThemeFamily.paperInk: paperInkDefinition,
  ThemeFamily.terminal: placeholderFamilyDefinition(
    ThemeFamily.terminal,
    const MotionSpec(
      verb: PressVerb.invert,
      scheme: MotionScheme.standard,
      pressIn: SpringTokens.hardPress,
      release: SpringTokens.effectsFast,
      entry: EntryStyle.glyph,
      fx: PressFx.afterglow,
      impact: ImpactStyle.rigid,
      impactPermille: 500,
    ),
    shape: KeyShapeKind.roundedRect,
    style: KeyStyleKind.flat,
    sound: SoundPackId.mechClicky,
  ),
  // Cyberpunk (cyberpunk.dart).
  ThemeFamily.cyberpunk: cyberpunkDefinition,
  // Vaporwave (vaporwave.dart).
  ThemeFamily.vaporwave: vaporwaveDefinition,
  // Bauhaus (bauhaus.dart).
  ThemeFamily.bauhaus: bauhausDefinition,
};

// ------------------------------------------------------------ versioning --

/// The generator definitions of every **shipped** family, per engine
/// version (design doc "Rules": ThemeSpec is a pure function of (seed,
/// family, engineVersion)). A version's map is frozen once released: a
/// change to any definition, or shipping another family, is a new version
/// entry plus a new golden fixture. Families missing from a version's map
/// are refused by the generator, the feed and share codes at that version.
final Map<int, Map<ThemeFamily, FamilyDefinition>> familyDefinitionsByVersion =
    {
      1: {
        ThemeFamily.m3Expressive: m3ExpressiveDefinition,
        ThemeFamily.neoPop: neoPopDefinition,
      },
      // v2 (M3 review): light-theme key separation, the wider bile rule
      // re-checked on final colours, NeoPOP neon accents and neutral
      // function keys.
      2: {
        ThemeFamily.m3Expressive: m3ExpressiveDefinition.revise(
          light: standardLightRangesV2,
          bile: BileRule.v2,
        ),
        ThemeFamily.neoPop: neoPopDefinition.revise(
          dark: neoPopDarkRangesV2,
          light: standardLightRangesV2,
          bile: BileRule.v2,
        ),
        // M4 (docs/m4-design.md §C): Neumorphism ships at v2 without a
        // version bump. Adding a family leaves every other family's v2
        // output unchanged (definitions are per family and the generator
        // dispatches on the family's key style), and the theme of the day
        // stays on v1 with its fixed family list.
        ThemeFamily.neumorphism: neumorphismDefinition,
        // M4 (docs/m4-design.md §B): Retro hardware ships at v2 the same
        // way — additive, no other family's v2 output changes; its palette
        // is built by `buildRetroCandidate` (retro.dart).
        ThemeFamily.retro: retroDefinition,
        // M5: Liquid Glass ships at v2 the same way — additive, no other
        // family's v2 output changes; its palette is built by
        // `buildGlassCandidate` (liquid_glass.dart), pinned by
        // fixtures/liquid_glass_v2.json.
        ThemeFamily.liquidGlass: liquidGlassDefinition,
        // M5: Neo-brutalism ships at v2 the same way — additive, no other
        // family's v2 output changes; its palette is built by
        // `buildNeoBrutalCandidate` (neo_brutalism.dart), pinned by
        // fixtures/neo_brutalism_v2.json.
        ThemeFamily.neoBrutalism: neoBrutalismDefinition,
      },
      // v3: one pocket Retro theme in three plays the 8-bit chiptune pack
      // instead of the calculator beep (buildRetroCandidate, on the sound
      // stream, so the look of every theme is unchanged). Other families'
      // output is the same as v2 apart from the version number.
      3: {
        ThemeFamily.m3Expressive: m3ExpressiveDefinition.revise(
          light: standardLightRangesV2,
          bile: BileRule.v2,
        ),
        ThemeFamily.neoPop: neoPopDefinition.revise(
          dark: neoPopDarkRangesV2,
          light: standardLightRangesV2,
          bile: BileRule.v2,
        ),
        ThemeFamily.neumorphism: neumorphismDefinition,
        ThemeFamily.retro: retroDefinition,
        ThemeFamily.liquidGlass: liquidGlassDefinition,
        ThemeFamily.neoBrutalism: neoBrutalismDefinition,
        // Claymorphism ships at v3 the same way — additive, no other
        // family's v3 output changes; its palette is built by
        // `buildClaymorphismCandidate` (claymorphism.dart), pinned by
        // fixtures/claymorphism_v3.json.
        ThemeFamily.claymorphism: claymorphismDefinition,
        // Y2K / Frutiger Aero ships at v3 the same way — additive, no other
        // family's v3 output changes; its palette is built by
        // `buildY2kAeroCandidate` (y2k_aero.dart), pinned by
        // fixtures/y2k_aero_v3.json.
        ThemeFamily.y2kChrome: y2kAeroDefinition,
        // Paper & ink ships at v3 the same way — additive, no other
        // family's v3 output changes; its palette and sheet are built by
        // `buildPaperInkCandidate` (paper_ink.dart), pinned by
        // fixtures/paper_ink_v3.json.
        ThemeFamily.paperInk: paperInkDefinition,
        // Cyberpunk ships at v3 the same way — additive, no other family's
        // v3 output changes; its palette is built by
        // `buildCyberpunkCandidate` (cyberpunk.dart), pinned by
        // fixtures/cyberpunk_v3.json.
        ThemeFamily.cyberpunk: cyberpunkDefinition,
        // Vaporwave ships at v3 the same way — additive, no other family's
        // v3 output changes; its palette and sunset scene are built by
        // `buildVaporwaveCandidate` (vaporwave.dart), pinned by
        // fixtures/vaporwave_v3.json.
        ThemeFamily.vaporwave: vaporwaveDefinition,
        // Bauhaus ships at v3 the same way — additive, no other family's
        // v3 output changes; its palette is built by
        // `buildBauhausCandidate` (bauhaus.dart), pinned by
        // fixtures/bauhaus_v3.json.
        ThemeFamily.bauhaus: bauhausDefinition,
      },
    };

/// The newest engine version with definitions.
int get latestDefinedEngineVersion =>
    familyDefinitionsByVersion.keys.reduce((a, b) => a > b ? a : b);

/// [family]'s definition at [engineVersion], or null when that version did
/// not ship it (or is unknown).
FamilyDefinition? familyDefinitionAt(ThemeFamily family, int engineVersion) =>
    familyDefinitionsByVersion[engineVersion]?[family];

/// Whether [engineVersion] generates [family].
bool familyShippedAt(ThemeFamily family, int engineVersion) =>
    familyDefinitionAt(family, engineVersion) != null;
