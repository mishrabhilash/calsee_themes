/// The Claymorphism family (spec §5.3 #7; motion brief §2.3 "Claymorphism";
/// design: inflated, matte, soft-touch plasticine). Pure Dart: part of the
/// generator, so every constant here is part of the family's engine-v3
/// definition and must not change without a version bump.
///
/// - **Keys** are big puffy squircles on an opaque, multi-pastel face, with
///   three stacked depth cues the guardrails check are visible: a soft
///   drop shadow tinted from the key's own hue (`KeyColors.edge`, never
///   grey, [GuardrailRule.clayShadowTint]; deep and dense on night bodies
///   so it still reads there), a white top-left highlight
///   that lifts every face by ≥ 0.025 L (`Palette.highlight`,
///   [GuardrailRule.clayHighlight]) and a darker bottom-right inner shade
///   (`KeyStyleSpec.edgeShadePermille`, [clayInnerShade]).
/// - **Lightness ladder** (both brightnesses): digits 0.915–0.950 >
///   function keys 0.80–0.86 (light ones as low as ~0.75 after they are
///   pushed below the body) > candy operators 0.68–0.78 > the deep gummy
///   `=` 0.46–0.54 (0.40–0.44 under the Accessible lock). Light bodies
///   (L 0.855–0.895; butter 0.880–0.895) sit between the digits and the
///   function keys; night bodies (plum, indigo, midnight, berry at
///   L 0.20–0.26) sit ≥ 0.15 below every key ([GuardrailRule.clayKeyBody]),
///   and the night `=` keeps ≥ 2.8:1 against the body.
/// - **Variants:** candy (contrasting triples, 45 %), tonal (one-colour
///   plasticine sets, 30 %) and night (25 %). The candy-hue rule
///   ([clayCandyHue]) keeps operators, function keys and spheres out of
///   75–130° (spreading the moved hues past the band edges rather than
///   piling them on one colour); the `=` rule ([clayEqualsHue]) keeps the
///   gummy out of 35–150° and the dull teal / petrol band and turns a red
///   `=` beside a green operator grape; night operators turn kelly green
///   to jade ([clayNightOperatorHue]); night spheres turn red-orange /
///   amber to berry and green / teal / cyan to violet, berry or cobalt
///   jewels ([clayNightSphereHue]): no mustard, olive, moss, brown or
///   slate.
/// - **Display:** a puffy pillow card in the opaque surface colour (the
///   recessed tray is retired: at phone size it read as an LCD well or a
///   Neumorphism inset); display text only ever sits on it.
/// - **Scene** ([BackgroundKind.claySoft]): a soft pastel or night-clay
///   wash with two clay spheres. `colors` holds exactly nine opaque
///   colours: `[0]` base (the keypad body, = `Palette.background`), `[1]`
///   top wash, `[2..4]` sphere A lit / body / shade, `[5..7]` sphere B lit
///   / body / shade, `[8]` sphere shadow core. `angleTenths` is the size
///   balance between the spheres (0–750, step 150). Static (no drift).
///
/// Every draw comes from the generator's named sub-streams (`style` first,
/// then `palette` and its retry streams, `background`, `shape`, `type`,
/// `motion`, `name`), so a theme is a pure function of (seed,
/// engineVersion, accessible).
library;

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/steering.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

// ------------------------------------------------------------- constants --

/// The three sub-variants.
enum ClayVariant {
  /// Light: contrasting candy triples on a pastel body.
  candy,

  /// Light: an analogous, one-colour plasticine set.
  tonal,

  /// Dark: deep plum / indigo / midnight / berry clay.
  night,
}

/// Light themes: `[candy, tonal]` weights.
const List<int> clayLightVariantWeights = [3, 2];

/// Light body hue anchors (tenths) and weights. Index 1 (peach) and 4
/// (butter) are warm: their cream digits turn cool milk.
const List<Weighted<IntRange>> clayLightBodyHues = [
  Weighted(IntRange(2900, 3100), 3), // lavender
  Weighted(IntRange(450, 650), 2), // peach
  Weighted(IntRange(1550, 1750), 2), // mint
  Weighted(IntRange(2250, 2450), 2), // sky
  Weighted(IntRange(950, 1030), 1), // butter ([clayButterAnchor])
  Weighted(IntRange(3500, 3650), 2), // rose (wraps % 3600)
];

/// The butter anchor's index in [clayLightBodyHues]. At the shared body
/// lightness and relative chroma (capped at 0.060) a 90–100° body reads
/// khaki or manila, so butter takes its own lightness
/// ([clayButterLMilli]) and absolute chroma ([clayButterChromaMilli]),
/// mapped linearly from the same draws: a clean pastel yellow.
const int clayButterAnchor = 4;
const IntRange clayButterLMilli = IntRange(880, 895);
const IntRange clayButterChromaMilli = IntRange(85, 100);

/// Night body hue anchors: hues whose maximum chroma at the shadow
/// lightness (L 0.11–0.17) is ≥ 0.05, so night shadows stay coloured.
const List<Weighted<IntRange>> clayNightBodyHues = [
  Weighted(IntRange(3150, 3350), 3), // plum
  Weighted(IntRange(2700, 2900), 3), // indigo
  Weighted(IntRange(2550, 2650), 1), // midnight blue
  Weighted(IntRange(3450, 3550), 1), // berry
];

/// How far (tenths) a steered base hue may sit from every body anchor
/// before it colours the operators instead of the body (engine v4).
const int clayAccentFallbackTenths = 300;

/// The body anchor nearest the clockwise hue range (lo, span) in tenths:
/// its index, the overlap with it (null when none) and the gap (0 when
/// they overlap). Ties go to the lower index.
({int index, int? overlapLo, int? overlapSpan, int distance}) clayAnchorFor(
  List<Weighted<IntRange>> anchors,
  int lo,
  int span,
) {
  int d(int x, int y) {
    final v = (x - y).abs() % 3600;
    return v > 1800 ? 3600 - v : v;
  }

  bool inside(int h, int from, int width) => (h - from) % 3600 <= width;
  var best = 0;
  var bestDistance = 1 << 30;
  int? bestLo;
  int? bestSpan;
  for (var i = 0; i < anchors.length; i++) {
    final a = anchors[i].value;
    final aLo = a.lo % 3600;
    final aSpan = a.hi - a.lo;
    int? oLo;
    if (inside(lo, aLo, aSpan)) {
      oLo = lo;
    } else if (inside(aLo, lo, span)) {
      oLo = aLo;
    }
    final int distance;
    int? oSpan;
    if (oLo != null) {
      final endA = (aLo + aSpan - oLo) % 3600;
      final endB = (lo + span - oLo) % 3600;
      oSpan = endA < endB ? endA : endB;
      distance = 0;
    } else {
      final x = d((lo + span) % 3600, aLo);
      final y = d((aLo + aSpan) % 3600, lo);
      distance = x < y ? x : y;
    }
    if (distance < bestDistance) {
      best = i;
      bestDistance = distance;
      bestLo = oLo;
      bestSpan = oSpan;
    }
  }
  return (
    index: best,
    overlapLo: bestLo,
    overlapSpan: bestSpan,
    distance: bestDistance,
  );
}

/// (operator, function, `=`) hue offsets from the body hue (tenths): candy
/// and night themes.
const List<Weighted<(int, int, int)>> clayCandySchemes = [
  Weighted((700, 2250, 0), 3), // berry-mint
  Weighted((1200, 2400, 600), 2), // triad
  Weighted((1800, 900, 2100), 2), // complement
  Weighted((1500, 2100, 3000), 2), // split
  Weighted((400, 1800, -400), 1), // neighbour + complementary function
];

/// (operator, function, `=`) hue offsets from the body hue (tenths): tonal
/// themes (function keys on the far side of the operators).
const List<Weighted<(int, int, int)>> clayTonalSchemes = [
  Weighted((450, -350, -450), 2),
  Weighted((-450, 350, 450), 1),
];

/// Hue jitter (± tenths) of candy and night operators, function keys and
/// `=`.
const int clayOpJitter = 150;
const int clayFnJitter = 200;
const int clayEqJitter = 150;

/// Hue jitter (± tenths) of all three tonal key hues.
const int clayTonalJitter = 100;

/// Hue jitter (± tenths) of the sphere hues and of non-cream digits.
const int claySphereJitter = 100;
const int clayDigitHueJitter = 150;

/// Cream digit hues (tenths), and the shift that turns cream into cool
/// milk on warm (peach / butter) bodies (→ 245–265°).
const IntRange clayCreamHueTenths = IntRange(750, 950);
const int clayCoolMilkShiftTenths = 1700;

/// Candy-hue rule for operators, function keys and spheres: hues inside
/// [clayCandyKeyBand] move past the nearer of [clayCandyKeyTargets] (by
/// half their depth into the band, at most [clayCandyKeyPush]).
const IntRange clayCandyKeyBand = IntRange(750, 1299);
const (int, int) clayCandyKeyTargets = (650, 1400);
const int clayCandyKeyPush = 150;

/// Candy-hue rule for `=` (both modes, normal and accessible): no moss,
/// olive or mustard gummy. Moved hues land at 5–25° (red) or 156–176°
/// (emerald).
const IntRange clayEqualsBand = IntRange(350, 1499);
const (int, int) clayEqualsTargets = (250, 1560);
const int clayEqualsPush = 200;

/// `=` hues inside [clayEqualsDullBand] (165–245°, teal to petrol: sRGB
/// holds only C 0.07–0.12 there at the `=` lightness, so the gummy comes
/// out drab) move past the nearer of [clayEqualsDullTargets] — emerald
/// (156°) and cobalt (256°) — by half their depth into the band, at most
/// [clayEqualsDullPushDown] down (never below 150°) or
/// [clayEqualsDullPushUp] up; past the other one when the nearer target
/// lies within [clayEqualsOpGap] of the operator hue or (night) within
/// [clayNightEqualsBodyGap] of the body hue ([clayEqualsDullHue]).
const IntRange clayEqualsDullBand = IntRange(1650, 2449);
const (int, int) clayEqualsDullTargets = (1560, 2560);
const int clayEqualsDullPushDown = 60;
const int clayEqualsDullPushUp = 100;
const int clayEqualsOpGap = 450;
const int clayNightEqualsBodyGap = 600;

/// `=` chroma floor (both modes): at least min([clayEqualsChromaMilli] /
/// 1000, [clayEqualsChromaRel] / 1000 × maxChroma), so the key stays a
/// saturated gummy.
const int clayEqualsChromaMilli = 125;
const int clayEqualsChromaRel = 920;

/// A green operator (hue in [clayGreenOperatorBand]) with a red `=` (hue
/// in [clayRedEqualsBand], wrapping) reads as Christmas: the `=` turns
/// grape ([clayGrapeEquals], spread by its place in the red band).
const IntRange clayGreenOperatorBand = IntRange(1200, 1700);
const IntRange clayRedEqualsBand = IntRange(3400, 3900);
const IntRange clayGrapeEquals = IntRange(3000, 3150);

/// Night operators in [clayNightKellyBand] (kelly green on a plum or berry
/// body reads as Christmas) move to jade ([clayNightJade], spread by
/// their place in the band).
const IntRange clayNightKellyBand = IntRange(1150, 1549);
const IntRange clayNightJade = IntRange(1550, 1650);

/// Light ranges (candy and tonal). Hues come from the scheme tables.
const RoleRanges clayLightRanges = RoleRanges(
  background: RoleRange(IntRange(855, 895), ChromaRange.rel(350, 550, 60)),
  surfaceOffsetMilli: IntRange(60, 60),
  surfaceChroma: ChromaRange.abs(8, 20),
  digit: RoleRange(IntRange(925, 950), ChromaRange.abs(12, 30)),
  digitDuotoneChroma: ChromaRange.abs(12, 30),
  function: RoleRange(IntRange(800, 860), ChromaRange.rel(450, 700, 100)),
  operator: RoleRange(IntRange(690, 780), ChromaRange.rel(800, 950, 170)),
  operatorMonochromeL: IntRange(690, 780),
  equals: RoleRange(IntRange(460, 540), ChromaRange.rel(850, 1000, 200)),
  labelStartLMilli: 250,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(700, 900, 170),
  minDigitAboveBackgroundMilli: 50,
);

/// Night ranges.
const RoleRanges clayNightRanges = RoleRanges(
  background: RoleRange(IntRange(200, 260), ChromaRange.rel(450, 750, 85)),
  surfaceOffsetMilli: IntRange(60, 60),
  surfaceChroma: ChromaRange.abs(30, 70),
  digit: RoleRange(IntRange(915, 950), ChromaRange.abs(20, 45)),
  digitDuotoneChroma: ChromaRange.abs(20, 45),
  function: RoleRange(IntRange(800, 860), ChromaRange.rel(500, 750, 120)),
  operator: RoleRange(IntRange(680, 760), ChromaRange.rel(850, 1000, 180)),
  operatorMonochromeL: IntRange(680, 760),
  equals: RoleRange(IntRange(460, 540), ChromaRange.rel(850, 1000, 200)),
  labelStartLMilli: 250,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(700, 900, 160),
  minDigitAboveBackgroundMilli: 600,
);

/// Light body chroma floor (thousandths): rose and lavender bodies
/// below it read dusty.
const int clayBodyChromaFloorMilli = 32;

/// Night body chroma floor (thousandths): below it berry and plum bodies
/// read aubergine-brown (C 0.06 is in gamut for every night anchor at
/// L 0.20).
const int clayNightBodyChromaFloorMilli = 60;

/// Digit lightness cap (× 1000): the highlight stays visible (lift ≥
/// 0.025).
const int clayDigitMaxLMilli = 950;

/// Light digits sit at least this far above the body (L × 1000).
const int clayDigitAboveBodyMilli = 50;

/// Light function keys sit at least this far below the body (L × 1000).
const int clayFunctionBelowBodyMilli = 45;

/// Top wash: lightness above the base (× 1000).
const int clayTopWashLightMilli = 20;
const int clayTopWashNightMilli = 35;

/// Light sphere bodies: lightness offset from the base and absolute chroma
/// (× 1000), so they read as solid objects.
const IntRange clayLightBlobLMilli = IntRange(-100, -60);
const IntRange clayLightBlobChromaMilli = IntRange(70, 110);

/// Light spheres with a hue in [clayLightSphereWarmBand] (35–75°: tan and
/// biscuit at low chroma) get at least min([clayLightSphereWarmChromaMilli],
/// 0.9 × maxChroma): apricot, not cardboard.
const IntRange clayLightSphereWarmBand = IntRange(350, 749);
const int clayLightSphereWarmChromaMilli = 105;

/// Night sphere bodies: absolute lightness and relative chroma (× 1000,
/// capped at [clayNightBlobChromaCapMilli], at least
/// min([clayNightBlobChromaFloorMilli], 0.9 × maxChroma)): glowing jewel
/// clay 0.15–0.26 L above the body, never a dark smudge.
const IntRange clayNightBlobLMilli = IntRange(400, 460);
const IntRange clayNightBlobChromaRel = IntRange(550, 850);
const int clayNightBlobChromaCapMilli = 150;
const int clayNightBlobChromaFloorMilli = 100;

/// Night spheres: a red-orange / apricot / amber hue at L 0.40–0.46 is
/// maroon or brown, so hues in [clayNightSphereWarmBand] turn to berry
/// ([clayNightSphereWarmTarget] minus a fifth of their depth into the
/// band: 330–345°), like hero 72's sphere under coral operators.
const IntRange clayNightSphereWarmBand = IntRange(150, 899);
const int clayNightSphereWarmTarget = 3450;

/// Night spheres: green, teal and cyan hues ([clayNightSphereJewelBand])
/// read bottle-green, moss or slate on night clay, so they move to the
/// first of [clayNightSphereJewels] (violet, berry, cobalt; spread by
/// their depth into the band) that keeps [clayNightSphereBodyGap] from
/// the body hue and [clayNightSphereGap] from the other sphere
/// ([clayNightSphereHue]).
const IntRange clayNightSphereJewelBand = IntRange(1000, 2449);
const List<IntRange> clayNightSphereJewels = [
  IntRange(3000, 3150),
  IntRange(3300, 3450),
  IntRange(2550, 2650),
];
const int clayNightSphereBodyGap = 450;
const int clayNightSphereGap = 300;

/// Display panel weights `[pillow, tray]`: the recessed tray is retired
/// (weight 0: at phone size it read as an LCD well or a Neumorphism
/// inset). The palette stream still makes the draw, so every later palette
/// draw keeps its place.
const List<int> clayPanelWeights = [1, 0];

/// Light pillow lightness cap (× 1000).
const int clayPillowMaxLMilli = 965;

/// The pillow card's shaded rim: [clayInnerShade] of the surface at this
/// depth (× 1000), a little softer than a key's.
const int clayPanelShadePermille = 85;

/// Light pillow chroma: [clayPillowChromaRel] / 1000 × the body chroma,
/// clamped to [clayPillowChromaMilli] (× 1000), so the card is a pale
/// tint of the body, never grey.
const int clayPillowChromaRel = 600;
const IntRange clayPillowChromaMilli = IntRange(15, 28);

/// Function keys with a hue in [clayWarmFunctionBand] (40–75°: café au
/// lait at low chroma) get at least min([clayWarmFunctionChromaMilli],
/// 0.95 × maxChroma).
const IntRange clayWarmFunctionBand = IntRange(400, 750);
const int clayWarmFunctionChromaMilli = 80;

/// Light function keys keep at least this colour-blind ΔEOK (the minimum
/// over normal vision and the three dichromacies) from the body.
const double clayFunctionMinCvdDeltaE = 0.03;

/// Normal-mode night `=` keys keep at least [clayNightEqualsMinContrast]
/// against the body, lifted 0.01 L at a time up to
/// [clayNightEqualsMaxLMilli] (× 1000): the most important key never
/// sinks into the clay.
const double clayNightEqualsMinContrast = 2.8;
const int clayNightEqualsMaxLMilli = 580;

/// The focus ring is also solved against each key group's own drop
/// shadow at this fraction (× 1000) of its alpha over every scene colour
/// a key can sit on ([clayFocusShadowBackdrops]): the ring is drawn 2–4 dp
/// outside the key, where the soft shadow still covers up to ~62 % (depth
/// 6 dp, blur 14 dp on a 64 dp key).
const int clayFocusShadowPermille = 650;

/// Accessible lock: operator lightness floor and the `=` range (× 1000).
const int clayAccessibleOperatorMinLMilli = 725;
const IntRange clayAccessibleEqualsLMilli = IntRange(400, 440);

/// Accessible lock: night bodies are remapped linearly onto this range.
const IntRange clayAccessibleNightBodyLMilli = IntRange(200, 220);

/// Night keys sit at least this far above the body (L × 1000).
const int clayNightMinKeyAboveBodyMilli = 150;

/// Drop-shadow offset at rest (= the motion depth), dp × 100, step 100.
const IntRange clayShadowCdp = IntRange(400, 600);

/// Drop-shadow blur radius, dp × 100, step 200.
const IntRange clayShadowBlurCdp = IntRange(1000, 1400);

/// Inner bottom-right shade depth (L × 1000), step 10.
const IntRange clayInnerShadePermille = IntRange(80, 110);

/// White highlight alpha (0xA0–0xC8), step 10.
const IntRange clayHighlightAlpha = IntRange(160, 200);

/// The smallest lightness lift the highlight must give every face.
const double clayMinHighlightLift = 0.025;

/// Drop-shadow alpha per [KeyGroup] (digit, operator, equals, function).
/// Night shadows are denser: on a body at L 0.20–0.26 a lighter one
/// cannot be seen.
const List<int> clayShadowAlpha = [0x5C, 0x70, 0x7A, 0x66];
const List<int> clayNightShadowAlpha = [0xB8, 0xCC, 0xD6, 0xC2];

/// Lowest and highest drop-shadow alpha the guardrail accepts.
const int clayShadowAlphaMin = 0x50;
const int clayShadowAlphaMax = 0xD8;

/// Night drop shadows: lightness [clayNightShadowL] (the body less
/// 0.14, at least 0.07) and chroma ≥ [clayNightShadowMinChroma] (capped
/// by the gamut); a hue qualifies when maxChroma there is ≥ that too.
const double clayNightShadowDrop = 0.14;
const double clayNightShadowMinL = 0.07;
const double clayNightShadowMinChroma = 0.04;

/// The label zone of a clay key: its face deflated by this fraction of the
/// rest short side. Inside it the renderer paints only the face colour
/// (the highlight, cover ramp and inner shade end at 0.20 s).
const double clayLabelZoneInset = 0.20;

/// The pressed drop shadow: offset and blur × this (× 1000) — "the shadow
/// is 40 % smaller from frame 1".
const int clayPressedShadowPermille = 600;

/// Squash stretch at full press (X 1.04; Y is the motion scale 0.92).
const int claySquashStretchPermille = 1040;

/// Claymorphism (spec §5.3 #7; motion brief §2.3 "Claymorphism"): opaque
/// squircle keys with a coloured drop shadow, an inner top-left highlight
/// and an inner bottom-right shade. Press: a bottom-anchored squash
/// (X 1.04 / Y 0.92) on 1755/0.85, the shadow 40 % smaller from frame 1, a
/// visible tall-and-thin rebound on 322/0.65; the display pops glyphs in
/// from 0.86; sound `pop`, haptic soft · 0.8. The palette is built by
/// [buildClaymorphismCandidate].
const FamilyDefinition claymorphismDefinition = FamilyDefinition(
  family: ThemeFamily.claymorphism,
  brightnessWeights: [1, 3],
  // Metadata only: the builder uses clayCandySchemes / clayTonalSchemes.
  schemes: [Weighted(HarmonyScheme.splitComplementary, 1)],
  shapes: [Weighted(KeyShapeKind.squircle, 1)],
  cornerPermille: IntRange(300, 420),
  styles: [Weighted(KeyStyleKind.clay, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.clay,
    shadowOffsetCdp: 500,
    shadowBlurCdp: 1200,
    edgeShadePermille: 90,
    stateLayerPermille: 60,
  ),
  displayFonts: [Weighted(FontIds.nunito, 1)],
  keyFonts: [Weighted(FontIds.nunito, 1)],
  displayWeight: IntRange(700, 800),
  keyWeight: IntRange(700, 800),
  operatorWeightBonus: IntRange(100, 200),
  backgrounds: [Weighted(BackgroundKind.claySoft, 1)],
  sound: SoundPackId.pop,
  dark: clayNightRanges,
  light: clayLightRanges,
  motion: MotionSpec(
    verb: PressVerb.squash,
    scheme: MotionScheme.expressive,
    pressIn: SpringTokens.glassPressIn,
    release: SpringToken(322, 650),
    depthCdp: 500,
    scalePermille: 920,
    stateLayerSnap: true,
    entry: EntryStyle.pop,
    entryScalePermille: 860,
    impact: ImpactStyle.soft,
  ),
  motionRanges: MotionRanges(depthCdp: clayShadowCdp, bounceJitterPermille: 50),
  bile: BileRule.v2,
);

// --------------------------------------------------------------- helpers --

int _wrap(int tenths) => tenths % 3600;

int _hueDistance(int a, int b) {
  final d = (a - b).abs() % 3600;
  return d > 1800 ? 3600 - d : d;
}

double _min(double a, double b) => a < b ? a : b;

double _max(double a, double b) => a > b ? a : b;

double _clamp(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

int _hueTenths(Lch c) => (c.h * 10).round() % 3600;

double _lightness(int argb) => argbToOklab(argb | 0xFF000000).$1;

/// The candy-hue rule: [hue] inside [band] leaves it on the side of
/// whichever of [targets] is circularly nearer [pivot] (the hue itself for
/// candy and night themes, the body hue for tonal ones; ties go to the
/// first). It lands on the target pushed away from the band by half the
/// hue's depth into the band from that side, at most [maxPush] — so the
/// band stays empty without piling every moved hue onto one colour.
/// Pure integer tenths.
int clayCandyHue(
  int hue,
  IntRange band,
  (int, int) targets,
  int pivot, {
  int maxPush = 0,
}) {
  final h = _wrap(hue);
  if (!band.contains(h)) return h;
  final (a, b) = targets;
  if (_hueDistance(a, pivot) <= _hueDistance(b, pivot)) {
    final push = (h - band.lo) ~/ 2;
    return _wrap(a - (push < maxPush ? push : maxPush));
  }
  final push = (band.hi - h) ~/ 2;
  return _wrap(b + (push < maxPush ? push : maxPush));
}

/// The `=` fold out of the dull teal / petrol band (both modes): [hue]
/// (tenths) inside [clayEqualsDullBand] lands past the nearer of
/// [clayEqualsDullTargets] (by half its depth into the band, at most
/// [clayEqualsDullPushDown] / [clayEqualsDullPushUp]), or past the other
/// one when the nearer target lies within [clayEqualsOpGap] of [opHue] or
/// (given [nightBodyHue]) within [clayNightEqualsBodyGap] of the night
/// body hue. Pure integer tenths.
int clayEqualsDullHue(int hue, int opHue, {int? nightBodyHue}) {
  final h = _wrap(hue);
  const band = clayEqualsDullBand;
  if (!band.contains(h)) return h;
  final (lo, hi) = clayEqualsDullTargets;
  int capped(int push, int cap) => push < cap ? push : cap;
  final down = lo - capped((h - band.lo) ~/ 2, clayEqualsDullPushDown);
  final up = hi + capped((band.hi - h) ~/ 2, clayEqualsDullPushUp);
  bool clash(int target) =>
      _hueDistance(target, opHue) < clayEqualsOpGap ||
      (nightBodyHue != null &&
          _hueDistance(target, nightBodyHue) < clayNightEqualsBodyGap);
  final downFirst = h - lo <= hi - h;
  if (clash(downFirst ? lo : hi)) return downFirst ? up : down;
  return downFirst ? down : up;
}

/// [range]'s point at [num] / [den] of the way (integer tenths); its
/// middle for an empty source range ([den] 0: a centred steered draw).
int _spread(IntRange range, int num, int den) => den == 0
    ? range.lo + (range.hi - range.lo) ~/ 2
    : range.lo + num * (range.hi - range.lo) ~/ den;

/// The full `=` hue rule after the scheme draw: the candy band
/// ([clayEqualsBand], leaving on the side of [pivot], or the other side
/// when that lands within [clayEqualsOpGap] of [opHue]), the dull band
/// ([clayEqualsDullHue]) and grape for a red `=` beside a green operator
/// ([clayGrapeEquals]). Pure integer tenths.
int clayEqualsHue(int hue, int opHue, {int? pivot, int? nightBodyHue}) {
  int candyFrom(int p) => clayCandyHue(
    hue,
    clayEqualsBand,
    clayEqualsTargets,
    p,
    maxPush: clayEqualsPush,
  );
  var candy = candyFrom(pivot ?? _wrap(hue));
  if (clayEqualsBand.contains(_wrap(hue)) &&
      _hueDistance(candy, opHue) < clayEqualsOpGap) {
    // Leaving on that side would land beside the operator: the other.
    final (lo, hi) = clayEqualsTargets;
    candy = candyFrom(
      _hueDistance(candy, lo) < _hueDistance(candy, hi) ? hi : lo,
    );
  }
  final h = clayEqualsDullHue(candy, opHue, nightBodyHue: nightBodyHue);
  final red = _wrap(h - clayRedEqualsBand.lo);
  final span = clayRedEqualsBand.hi - clayRedEqualsBand.lo;
  if (clayGreenOperatorBand.contains(_wrap(opHue)) && red <= span) {
    return _spread(clayGrapeEquals, red, span);
  }
  return h;
}

/// Night operators: kelly green ([clayNightKellyBand]) turns jade
/// ([clayNightJade]). Pure integer tenths.
int clayNightOperatorHue(int hue) {
  final h = _wrap(hue);
  const band = clayNightKellyBand;
  if (!band.contains(h)) return h;
  return _spread(clayNightJade, h - band.lo, band.hi - band.lo);
}

/// The night sphere hue rule after the candy rule: red-orange / amber
/// ([clayNightSphereWarmBand]) turns berry; green, teal and cyan
/// ([clayNightSphereJewelBand]) take the first jewel of
/// [clayNightSphereJewels] at least [clayNightSphereBodyGap] from
/// [bodyHue] and (given [other], the other sphere's hue)
/// [clayNightSphereGap] from it — else the jewel that misses those gaps
/// by the least. Pure integer tenths.
int clayNightSphereHue(int hue, int bodyHue, {int? other}) {
  var h = _wrap(hue);
  const warm = clayNightSphereWarmBand;
  if (warm.contains(h)) h = clayNightSphereWarmTarget - (h - warm.lo) ~/ 5;
  const band = clayNightSphereJewelBand;
  if (!band.contains(h)) return h;
  final depth = h - band.lo;
  final span = band.hi - band.lo;
  var best = -1;
  var bestMargin = -3600;
  for (final jewel in clayNightSphereJewels) {
    final t = _spread(jewel, depth, span);
    final bodyMargin = _hueDistance(t, bodyHue) - clayNightSphereBodyGap;
    final otherMargin = other == null
        ? bodyMargin
        : _hueDistance(t, other) - clayNightSphereGap;
    final margin = bodyMargin < otherMargin ? bodyMargin : otherMargin;
    if (margin >= 0) return t;
    if (margin > bestMargin) {
      best = t;
      bestMargin = margin;
    }
  }
  return best;
}

/// The highlight alpha the renderer actually paints on [face] (and the
/// guardrail checks): the `Palette.highlight` alpha × 1.0 (face L ≥ 0.80),
/// 0.75 (≥ 0.62), 0.55 (≥ 0.40) or 0.35 (darker, e.g. a night pillow).
int clayHighlightAlphaFor(int face, int highlight) {
  final l = _lightness(face);
  final permille = l >= 0.80
      ? 1000
      : l >= 0.62
      ? 750
      : l >= 0.40
      ? 550
      : 350;
  final a = (highlight >>> 24) & 0xFF;
  return (a * permille + 500) ~/ 1000;
}

/// [face] under the painted highlight (white at [clayHighlightAlphaFor]),
/// opaque: the lit top-left rim of a clay key.
int clayHighlightComposite(int face, int highlight) => compositeOver(
  withAlpha(highlight | 0x00FFFFFF, clayHighlightAlphaFor(face, highlight)),
  face | 0xFF000000,
);

/// The inner bottom-right shade of [face]: L − [depthPermille] / 1000,
/// chroma × 1.12 (gamut-mapped), opaque.
int clayInnerShade(int face, int depthPermille) {
  final f = argbToOklch(face | 0xFF000000);
  final l = _max(0, f.l - depthPermille / 1000);
  return oklchToArgb(l, f.c * 1.12, f.h);
}

/// The night drop-shadow lightness for a body of lightness [baseL].
double clayNightShadowL(double baseL) =>
    _max(clayNightShadowMinL, baseL - clayNightShadowDrop);

/// The night drop-shadow hue (tenths) for [face] at shadow lightness [l]:
/// the face hue (bile-applied) when the face has C ≥ 0.035 and
/// maxChroma(l, hue) ≥ [clayNightShadowMinChroma], else the body hue
/// turned 10° at a time toward 270° (≤ 6 steps) until maxChroma(l, hue)
/// reaches it.
int clayNightShadowHue(
  int face,
  int bodyHueTenths,
  double l, {
  BileRule bile = BileRule.v2,
}) {
  const minC = clayNightShadowMinChroma;
  final f = argbToOklch(face | 0xFF000000);
  if (f.c >= 0.035) {
    final hue = bile.apply(_hueTenths(f), l, 0.1);
    if (maxChroma(l, hue / 10) >= minC) return hue;
  }
  var hue = bile.apply(_wrap(bodyHueTenths), l, 0.1);
  for (var i = 0; i < 6 && maxChroma(l, hue / 10) < minC; i++) {
    // Clockwise distance to 270°; turn the shorter way, 10° at a time.
    final d = _wrap(2700 - hue);
    if (d == 0) break;
    final up = d <= 1800;
    final left = up ? d : 3600 - d;
    final step = left < 100 ? left : 100;
    hue = _wrap(hue + (up ? step : -step));
  }
  return hue;
}

/// A key group's drop-shadow colour (`KeyColors.edge`): coloured, darker
/// than the body, never grey, bile-safe. [bodyHueTenths], [baseL] and
/// [baseC] describe the body (`colors[0]`). [GuardrailRule.clayShadowTint]
/// accepts alpha [clayShadowAlphaMin]–[clayShadowAlphaMax], chroma ≥
/// min(0.040, 0.75 × maxChroma) (night ≥ 0.035) and a hue within 40° of
/// the key's own (bile-applied; at night the [clayNightShadowHue]
/// reference, which falls back to the body hue for faces with no chroma
/// at the shadow lightness).
int clayDropShadow(
  int face, {
  required int bodyHueTenths,
  required bool dark,
  required KeyGroup group,
  double baseL = 0,
  double baseC = 0,
  BileRule bile = BileRule.v2,
}) {
  final f = argbToOklch(face | 0xFF000000);
  final alpha = (dark ? clayNightShadowAlpha : clayShadowAlpha)[group.index];
  if (dark) {
    final l = clayNightShadowL(baseL);
    final hue = clayNightShadowHue(face, bodyHueTenths, l, bile: bile);
    final c = _min(
      maxChroma(l, hue / 10),
      _max(clayNightShadowMinChroma, baseC),
    );
    return withAlpha(oklchToArgb(l, c, hue / 10), alpha);
  }
  var hue = f.c >= 0.035 ? _hueTenths(f) : _wrap(bodyHueTenths);
  final l = _clamp(f.l - 0.40, 0.32, 0.52);
  // Forced chroma: yellow-band shadows always rotate (a dark yellow is
  // brown).
  hue = bile.apply(hue, l, 0.1);
  final c = _min(_clamp(f.c * 1.25, 0.07, 0.16), maxChroma(l, hue / 10));
  return withAlpha(oklchToArgb(l, c, hue / 10), alpha);
}

/// The four drop shadows of [p] for a scene whose body is [base] (the
/// generator and the repair share this, so they agree exactly).
Palette _withEdges(Palette p, int base, {required bool dark}) {
  final b = argbToOklch(base | 0xFF000000);
  final bodyHue = _hueTenths(b);
  KeyColors edged(KeyColors k, KeyGroup g) => k.copyWith(
    edge: clayDropShadow(
      k.face,
      bodyHueTenths: bodyHue,
      dark: dark,
      group: g,
      baseL: b.l,
      baseC: b.c,
    ),
  );
  return p.copyWith(
    digit: edged(p.digit, KeyGroup.digit),
    operator: edged(p.operator, KeyGroup.operator),
    equals: edged(p.equals, KeyGroup.equals),
    function: edged(p.function, KeyGroup.function),
  );
}

int _mixHalf(int a, int b) {
  int ch(int shift) => (((a >> shift) & 0xFF) + ((b >> shift) & 0xFF) + 1) ~/ 2;
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// The index pairs whose encoded-sRGB ½ mixes [claymorphismSceneSamples]
/// adds to the nine stops (the gradients' midpoints a key, label or ring
/// can sit over).
const List<(int, int)> claySceneMixPairs = [
  (0, 1),
  (2, 3),
  (3, 4),
  (5, 6),
  (6, 7),
  (3, 0),
  (4, 0),
  (6, 0),
  (7, 0),
  (3, 1),
  (6, 1),
  (8, 0),
  (8, 1),
];

/// Guardrail background samples of a [BackgroundKind.claySoft] scene: its
/// nine stops plus the ½ mixes of [claySceneMixPairs] (22 colours). Null
/// unless the scene has exactly nine colours.
List<int>? claymorphismSceneSamples(BackgroundSpec bg) {
  if (bg.colors.length != 9) return null;
  final c = [for (final x in bg.colors) x | 0xFF000000];
  return [...c, for (final (i, j) in claySceneMixPairs) _mixHalf(c[i], c[j])];
}

/// The scene colours a key (hence its drop shadow and the focus ring
/// drawn round it) can sit on: the base, the top wash and their mix,
/// sphere B (lit, body, shade and their mixes) and the spheres' shadow
/// core (and its mix with the base). Sphere A stays behind the toolbar,
/// the card or a gutter, never under the keypad.
List<int> clayFocusShadowBackdrops(List<int> colors) {
  final c = [for (final x in colors) x | 0xFF000000];
  return [
    c[0],
    c[1],
    _mixHalf(c[0], c[1]),
    c[5],
    c[6],
    c[7],
    _mixHalf(c[5], c[6]),
    _mixHalf(c[6], c[7]),
    c[8],
    _mixHalf(c[8], c[0]),
  ];
}

/// Every colour the focus ring can cross where it runs over a key's own
/// drop shadow: each key group's shadow at [clayFocusShadowPermille] of
/// its alpha over each of [clayFocusShadowBackdrops] (40 colours). The
/// generator, the validator and the repair share it.
List<int> clayFocusShadowSamples(Palette p, List<int> colors) {
  final backs = clayFocusShadowBackdrops(colors);
  return [
    for (final k in [p.digit, p.operator, p.equals, p.function])
      for (final x in backs)
        compositeOver(
          withAlpha(
            k.edge,
            (((k.edge >>> 24) & 0xFF) * clayFocusShadowPermille + 500) ~/ 1000,
          ),
          x,
        ),
  ];
}

/// Clay display text only ever sits on the opaque pillow card (the
/// renderer's cover is opaque over every part of the padded display box
/// text can use), so the surface is its only backdrop.
List<int>? claymorphismDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) => surfaces;

/// Whether the display panel of [spec] is the raised pillow: its surface
/// is lighter than the body. [GuardrailRule.clayPanel] requires it (the
/// recessed tray is retired).
bool clayPanelRaised(ThemeSpec spec) {
  final colors = spec.background.colors;
  if (colors.isEmpty) return true;
  return luminanceArgb(spec.palette.surface | 0xFF000000) >
      luminanceArgb(colors.first | 0xFF000000);
}

// --------------------------------------------------------------- builder --

/// Builds one unvalidated Claymorphism candidate (the generator repairs
/// and validates it, retries with `palette/retry/n` and finally falls back
/// to a Claymorphism hero).
ThemeSpec buildClaymorphismCandidate(
  int seed,
  FamilyDefinition def,
  int engineVersion, {
  int attempt = 0,
  bool accessible = false,
  Steering? steering,
}) {
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final bile = def.bile;

  // Style first: the label solve needs the shade depth and the highlight.
  final st = Rng.stream(seed, RngTag.style);
  final styleKind = pickWeightedValue(st, def.styles);
  final blurCdp = clayShadowBlurCdp.sampleStep(st, 200);
  final shadePermille = clayInnerShadePermille.sampleStep(st, 10);
  final highlightAlpha = clayHighlightAlpha.sampleStep(st, 10);
  final highlight = withAlpha(0xFFFFFFFF, highlightAlpha);

  // Palette.
  final paletteTag = attempt == 0
      ? RngTag.palette
      : RngTag.sub(RngTag.palette, 'retry', attempt);
  final p = Rng.stream(seed, paletteTag);
  final drawnDark = p.pickWeighted(def.brightnessWeights) == 0;
  final steeredBrightness = steering?.brightnessFor(def);
  final dark = steeredBrightness == null
      ? drawnDark
      : steeredBrightness == ThemeBrightness.dark;
  final brightness = dark ? ThemeBrightness.dark : ThemeBrightness.light;
  final ranges = def.ranges(brightness);
  final variant = dark
      ? ClayVariant.night
      : ClayVariant.values[p.pickWeighted(clayLightVariantWeights)];
  final tonal = variant == ClayVariant.tonal;
  final anchors = dark ? clayNightBodyHues : clayLightBodyHues;
  final drawnAnchor = p.pickWeighted([for (final a in anchors) a.weight]);
  final drawnBodyHue = _wrap(anchors[drawnAnchor].value.sample(p));
  // Steering (engine v4): the body stays on one of the family's anchors —
  // the one nearest the intent's base hue, inside their overlap. A base
  // hue far from every anchor colours the operators instead. Steered hues
  // come from their own sub-stream.
  final ir = steering == null ? null : Rng.stream(seed, intentTag(paletteTag));
  final baseDraw = ir?.nextU32();
  var anchor = drawnAnchor;
  var bodyHue = drawnBodyHue;
  int? baseAsAccent;
  final target = steering?.baseRange;
  if (steering != null && target != null) {
    final m = clayAnchorFor(anchors, target.lo, target.span);
    anchor = m.index;
    final a = anchors[anchor].value;
    if (m.overlapSpan != null) {
      bodyHue = _wrap(steering.pickIn(m.overlapLo!, m.overlapSpan!, baseDraw!));
    } else {
      bodyHue = _wrap(steering.pickIn(a.lo, a.hi - a.lo, baseDraw!));
      if (m.distance > clayAccentFallbackTenths) {
        baseAsAccent = steering.pickIn(target.lo, target.span, baseDraw);
      }
    }
  }
  final steeredOpHue =
      (ir == null ? null : steering!.accentHue(ir, 0)) ?? baseAsAccent;
  final steeredEqHue = ir == null ? null : steering!.accentHue(ir, 1);
  final butter = !dark && anchor == clayButterAnchor;
  final warmBody = !dark && (anchor == 1 || butter);
  var baseLMilli = ranges.background.lMilli.sample(p);
  if (butter) {
    final r = ranges.background.lMilli;
    baseLMilli = _spread(clayButterLMilli, baseLMilli - r.lo, r.hi - r.lo);
  }
  if (dark && accessible) {
    final lo = ranges.background.lMilli.lo;
    final span = ranges.background.lMilli.hi - lo;
    const target = clayAccessibleNightBodyLMilli;
    baseLMilli =
        target.lo + (baseLMilli - lo) * (target.hi - target.lo) ~/ span;
  }
  final baseRel = p.nextIntIn(
    ranges.background.chroma.lo,
    ranges.background.chroma.hi,
  );
  final scheme = pickWeightedValue(
    p,
    tonal ? clayTonalSchemes : clayCandySchemes,
  );
  final jOp = tonal ? clayTonalJitter : clayOpJitter;
  final jFn = tonal ? clayTonalJitter : clayFnJitter;
  final jEq = tonal ? clayTonalJitter : clayEqJitter;
  final drawnOpHue = _wrap(bodyHue + scheme.$1 + p.nextJitterTenths(jOp));
  final rawFnHue = _wrap(bodyHue + scheme.$2 + p.nextJitterTenths(jFn));
  final drawnEqHue = _wrap(bodyHue + scheme.$3 + p.nextJitterTenths(jEq));
  final rawOpHue = steeredOpHue ?? drawnOpHue;
  final rawEqHue = steeredEqHue ?? drawnEqHue;
  final opSign = scheme.$1 >= 0 ? 1 : -1;
  final srcA = tonal ? _wrap(bodyHue + 300 * opSign) : rawOpHue;
  final srcB = tonal ? _wrap(bodyHue - 300 * opSign) : rawFnHue;
  final rawBlobAHue = _wrap(srcA + p.nextJitterTenths(claySphereJitter));
  final rawBlobBHue = _wrap(srcB + p.nextJitterTenths(claySphereJitter));
  int blobL() => dark
      ? clayNightBlobLMilli.sample(p)
      : baseLMilli + clayLightBlobLMilli.sample(p);
  int blobC() => dark
      ? clayNightBlobChromaRel.sample(p)
      : clayLightBlobChromaMilli.sample(p);
  final blobALMilli = blobL();
  final blobAC = blobC();
  final blobBLMilli = blobL();
  final blobBC = blobC();
  final cream = dark ? p.nextChance(1, 2) : p.nextChance(2, 3);
  final digitHue = cream
      ? _wrap(
          clayCreamHueTenths.sample(p) +
              (warmBody ? clayCoolMilkShiftTenths : 0),
        )
      : _wrap(bodyHue + p.nextJitterTenths(clayDigitHueJitter));
  var digitLMilli = ranges.digit.lMilli.sample(p);
  final digitCMilli = p.nextIntIn(
    ranges.digit.chroma.lo,
    ranges.digit.chroma.hi,
  );
  var fnLMilli = ranges.function.lMilli.sample(p);
  final fnRel = p.nextIntIn(
    ranges.function.chroma.lo,
    ranges.function.chroma.hi,
  );
  var opLMilli = ranges.operator.lMilli.sample(p);
  final opRel = p.nextIntIn(
    ranges.operator.chroma.lo,
    ranges.operator.chroma.hi,
  );
  var eqLMilli = ranges.equals.lMilli.sample(p);
  final eqRel = p.nextIntIn(ranges.equals.chroma.lo, ranges.equals.chroma.hi);
  // Retired draws (the tray pick and the old pillow chroma): kept so the
  // label chroma below keeps its place in the stream.
  p
    ..pickWeighted(clayPanelWeights)
    ..nextIntIn(ranges.surfaceChroma.lo, ranges.surfaceChroma.hi);
  final labelCMilli = p.nextIntIn(25, ranges.labelMaxChromaMilli);

  // ---- derived (no draws) ----
  // Candy and night hues leave the band on their own nearer side; tonal
  // ones on the side of the body their scheme put them (the operator and
  // sphere A on one side, function keys, `=` and sphere B on the other),
  // so the moved operator and function hues never meet.
  final pivotA = tonal ? srcA : null;
  final pivotB = tonal ? srcB : null;
  int candy(int h, int? pivot) => clayCandyHue(
    h,
    clayCandyKeyBand,
    clayCandyKeyTargets,
    pivot ?? h,
    maxPush: clayCandyKeyPush,
  );
  int candyOp(int h) {
    final c = candy(h, pivotA);
    return dark ? clayNightOperatorHue(c) : c;
  }

  int candyFn(int h) => candy(h, pivotB);
  final opHue = candyOp(rawOpHue);
  var fnHue = candyFn(rawFnHue);

  // Body.
  final baseL = baseLMilli / 1000;
  final int bodyHueFinal;
  final double baseC;
  if (dark) {
    final c = _min(
      baseRel / 1000 * maxChroma(baseL, bodyHue / 10),
      ranges.background.chroma.capMilli / 1000,
    );
    baseC = _max(c, clayNightBodyChromaFloorMilli / 1000);
    bodyHueFinal = bile.apply(bodyHue, baseL, baseC);
  } else if (butter) {
    final r = ranges.background.chroma;
    baseC = _min(
      _spread(clayButterChromaMilli, baseRel - r.lo, r.hi - r.lo) / 1000,
      maxChroma(baseL, bodyHue / 10),
    );
    bodyHueFinal = bodyHue;
  } else {
    final c = _min(
      baseRel / 1000 * maxChroma(baseL, bodyHue / 10),
      ranges.background.chroma.capMilli / 1000,
    );
    baseC = _max(c, clayBodyChromaFloorMilli / 1000);
    bodyHueFinal = bodyHue;
  }
  final base = oklchToArgb(baseL, baseC, bodyHueFinal / 10);

  // `=`: the candy band, the dull band, grape beside a green operator.
  int candyEq(int h) => clayEqualsHue(
    h,
    opHue,
    pivot: pivotB,
    nightBodyHue: dark ? bodyHueFinal : null,
  );

  var eqHue = candyEq(rawEqHue);
  final topWash = dark
      ? oklchToArgb(
          baseL + clayTopWashNightMilli / 1000,
          baseC,
          bodyHueFinal / 10,
        )
      : oklchToArgb(
          baseL + clayTopWashLightMilli / 1000,
          baseC * 0.8,
          bodyHueFinal / 10,
        );

  // Spheres: (lit, body, shade, hue). Night spheres leave the warm and
  // green-teal bands (sphere B also keeps clear of sphere A).
  (int, int, int, int) sphere(
    int rawHue,
    int? pivot,
    int lMilli,
    int cDraw, {
    int? other,
  }) {
    var hue = candy(rawHue, pivot);
    if (dark) hue = clayNightSphereHue(hue, bodyHueFinal, other: other);
    final l = lMilli / 1000;
    double c;
    if (dark) {
      double night(int h) {
        final max = maxChroma(l, h / 10);
        return _max(
          _min(cDraw / 1000 * max, clayNightBlobChromaCapMilli / 1000),
          _min(clayNightBlobChromaFloorMilli / 1000, 0.9 * max),
        );
      }

      c = night(hue);
      final rotated = bile.apply(hue, l, c);
      if (rotated != hue) {
        hue = rotated;
        c = _min(c, maxChroma(l, hue / 10));
      }
    } else {
      final max = maxChroma(l, hue / 10);
      c = _min(cDraw / 1000, _min(0.12, max));
      if (clayLightSphereWarmBand.contains(hue)) {
        c = _max(c, _min(clayLightSphereWarmChromaMilli / 1000, 0.9 * max));
      }
    }
    final h = hue / 10;
    final body = oklchToArgb(l, c, h);
    final int lit;
    final int shade;
    if (dark) {
      lit = oklchToArgb(l + 0.070, c * 0.9, h);
      shade = oklchToArgb(_max(0.12, l - 0.070), c * 0.9, h);
    } else {
      lit = oklchToArgb(_min(0.975, l + 0.050), c * 0.75, h);
      shade = oklchToArgb(l - 0.075, _min(c * 1.10, 0.12), h);
    }
    return (lit, body, shade, hue);
  }

  final (aLit, aBody, aShade, aHue) = sphere(
    rawBlobAHue,
    pivotA,
    blobALMilli,
    blobAC,
  );
  final (bLit, bBody, bShade, _) = sphere(
    rawBlobBHue,
    pivotB,
    blobBLMilli,
    blobBC,
    other: aHue,
  );
  final shadowCore = dark
      ? oklchToArgb(_max(0.10, baseL - 0.080), baseC * 0.8, bodyHueFinal / 10)
      : oklchToArgb(baseL - 0.085, _min(baseC + 0.02, 0.08), bodyHueFinal / 10);
  final colors = List<int>.unmodifiable([
    base,
    topWash,
    aLit,
    aBody,
    aShade,
    bLit,
    bBody,
    bShade,
    shadowCore,
  ]);
  final b = Rng.stream(seed, RngTag.background);
  final background = BackgroundSpec(
    kind: pickWeightedValue(b, def.backgrounds),
    colors: colors,
    angleTenths: 150 * b.nextInt(6),
  );

  // Surface: the pillow card, 0.06 L above the body (a pale tint of it
  // in light themes, the body's own chroma at night).
  final surface = dark
      ? oklchToArgb(baseL + 0.060, baseC, bodyHueFinal / 10)
      : oklchToArgb(
          _min(clayPillowMaxLMilli / 1000, baseL + 0.060),
          _clamp(
            clayPillowChromaRel / 1000 * baseC,
            clayPillowChromaMilli.lo / 1000,
            clayPillowChromaMilli.hi / 1000,
          ),
          bodyHueFinal / 10,
        );

  // Faces.
  if (!dark) {
    final floor = baseLMilli + clayDigitAboveBodyMilli;
    if (digitLMilli < floor) digitLMilli = floor;
    if (digitLMilli > clayDigitMaxLMilli) digitLMilli = clayDigitMaxLMilli;
    final cap = baseLMilli - clayFunctionBelowBodyMilli;
    if (fnLMilli > cap) fnLMilli = cap;
  }
  if (accessible && opLMilli < clayAccessibleOperatorMinLMilli) {
    opLMilli = clayAccessibleOperatorMinLMilli;
  }
  if (accessible) {
    final r = ranges.equals.lMilli;
    const t = clayAccessibleEqualsLMilli;
    eqLMilli = t.lo + (eqLMilli - r.lo) * (t.hi - t.lo) ~/ (r.hi - r.lo);
  }

  int digitFace() =>
      oklchToArgb(digitLMilli / 1000, digitCMilli / 1000, digitHue / 10);
  int accentFace(
    int hue,
    int lMilli,
    int rel,
    ChromaRange range, {
    bool warmFloor = false,
    bool equalsFloor = false,
  }) {
    final l = lMilli / 1000;
    final cap = range.capMilli / 1000;
    double chroma(int h) {
      final max = maxChroma(l, h / 10);
      var c = _min(rel / 1000 * max, cap);
      if (equalsFloor) {
        c = _max(
          c,
          _min(clayEqualsChromaMilli / 1000, clayEqualsChromaRel / 1000 * max),
        );
      }
      if (!warmFloor || !clayWarmFunctionBand.contains(h)) return c;
      return _max(c, _min(clayWarmFunctionChromaMilli / 1000, 0.95 * max));
    }

    var c = chroma(hue);
    final h = bile.apply(hue, l, c);
    if (h != hue) c = chroma(h);
    return oklchToArgb(l, c, h / 10);
  }

  int fnFace() => accentFace(
    fnHue,
    fnLMilli,
    fnRel,
    ranges.function.chroma,
    warmFloor: true,
  );
  int opFace() => accentFace(opHue, opLMilli, opRel, ranges.operator.chroma);
  int eqFace() => accentFace(
    eqHue,
    eqLMilli,
    eqRel,
    ranges.equals.chroma,
    equalsFloor: true,
  );

  var digit = digitFace();
  var function = fnFace();
  var op = opFace();
  var eq = eqFace();

  // 1. Operators away from digits.
  bool opOk() =>
      contrastRatio(op, digit) >= 1.60 && minCvdDeltaE(op, digit) >= 0.10;
  final opFloor = accessible ? clayAccessibleOperatorMinLMilli : 640;
  while (!opOk() && opLMilli - 20 >= opFloor) {
    opLMilli -= 20;
    op = opFace();
  }
  for (
    var i = 0;
    i < 4 && !opOk() && digitLMilli + 15 <= clayDigitMaxLMilli;
    i++
  ) {
    digitLMilli += 15;
    digit = digitFace();
  }
  // 2. `=` away from the operators (a quarter turn either way, else a
  // half turn: the first that clears, or the best), and (normal-mode
  // night) off the body.
  if (minCvdDeltaE(eq, op) < 0.065) {
    final from = eqHue;
    var bestHue = eqHue;
    var best = eq;
    var bestDe = minCvdDeltaE(eq, op);
    for (final turn in const [900, -900, 1800]) {
      eqHue = candyEq(_wrap(from + turn));
      eq = eqFace();
      final de = minCvdDeltaE(eq, op);
      if (de > bestDe) {
        bestHue = eqHue;
        best = eq;
        bestDe = de;
      }
      if (de >= 0.065) break;
    }
    eqHue = bestHue;
    eq = best;
  }
  if (dark && !accessible) {
    while (contrastRatio(eq, base) < clayNightEqualsMinContrast &&
        eqLMilli + 10 <= clayNightEqualsMaxLMilli) {
      eqLMilli += 10;
      eq = eqFace();
    }
  }
  // 3. Light function keys below the body, for every eye (generation
  // backstop): darker 0.015 L at a time while the inner shade still
  // holds a dark label at the floor, then (still too close for a
  // colour-blind eye) a turn of the hue.
  if (!dark) {
    final bodyL = _lightness(base);
    bool fnOk(int f) =>
        deltaEOKArgb(f, base) >= 0.045 &&
        bodyL - _lightness(f) >= 0.03 &&
        minCvdDeltaE(f, base) >= clayFunctionMinCvdDeltaE;
    bool ringOk(int f) =>
        contrastRatio(0xFF000000, clayInnerShade(f, shadePermille)) >=
        lim.labelRatio + 0.2;
    for (var i = 0; i < 6 && !fnOk(function); i++) {
      fnLMilli -= 15;
      final next = fnFace();
      if (!ringOk(next)) {
        fnLMilli += 15;
        break;
      }
      function = next;
    }
    if (!fnOk(function)) {
      final from = fnHue;
      for (final turn in const [300, -300, 600, -600]) {
        fnHue = candyFn(_wrap(from + turn));
        final next = fnFace();
        if (fnOk(next) && ringOk(next)) {
          function = next;
          break;
        }
        fnHue = from;
      }
    }
  }

  // 4. Labels (the function label also on its inner shade), then the
  // candy + bile re-check on the final faces.
  final labelC = labelCMilli / 1000;
  Lch darkStart(int face) =>
      (l: ranges.labelStartLMilli / 1000, c: labelC, h: argbToOklch(face).h);
  const creamStart = (l: 0.985, c: 0.012, h: 85.0);
  KeyColors keyFor(int face, Lch start, {bool ring = false}) {
    final f = argbToOklch(face);
    final pair = repairPair(f, start, policy: policy);
    var label = pair.label;
    if (ring) {
      label =
          solveOnAll(label, [
            pair.face,
            clayInnerShade(pair.face, shadePermille),
          ], lim.labelRatio) ??
          label;
    }
    return KeyColors(face: pair.face, label: label, edge: 0);
  }

  // The final faces' hues are re-checked by the bile rule only: a hue the
  // builder placed on a band edge may drift a tenth into the band when
  // quantised, and must not be folded again for that.
  KeyColors recheck(
    KeyColors k,
    Lch start,
    int Function(int) rule, {
    bool ring = false,
  }) {
    final f = argbToOklch(k.face);
    final hue = _hueTenths(f);
    if (bile.apply(hue, f.l, f.c) == hue) return k;
    final rotated = bile.apply(rule(bile.apply(hue, f.l, f.c)), f.l, f.c);
    return keyFor(oklchToArgb(f.l, f.c, rotated / 10), start, ring: ring);
  }

  final digitKey = keyFor(digit, darkStart(digit));
  var fnKey = keyFor(function, darkStart(function), ring: true);
  var opKey = keyFor(op, darkStart(op));
  var eqKey = keyFor(eq, creamStart);
  if (bile.recheckFinal) {
    fnKey = recheck(fnKey, darkStart(function), candyFn, ring: true);
    opKey = recheck(opKey, darkStart(op), candyOp);
    eqKey = recheck(eqKey, creamStart, candyEq);
  }

  // 5. Texts on the panel; the focus ring on the scene.
  final bgs = claymorphismSceneSamples(background)!;
  final backdrops = [surface];
  int onAll(int start, List<int> on, double target, int fallback) =>
      solveOnAll(start, on, target) ?? fallback;
  final h = bodyHueFinal / 10;
  final opH = opHue / 10;
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final displayText = onAll(
    dark ? oklchToArgb(0.97, 0.015, h) : oklchToArgb(0.27, 0.045, h),
    backdrops,
    lim.displayRatio,
    blackOrWhite(surface),
  );
  final previewText = onAll(
    dark ? oklchToArgb(0.80, 0.030, h) : oklchToArgb(0.44, 0.035, h),
    backdrops,
    previewTarget,
    blackOrWhite(surface),
  );
  final error = onAll(
    dark ? oklchToArgb(0.76, 0.14, 22) : oklchToArgb(0.50, 0.17, 25),
    backdrops,
    lim.displayRatio,
    blackOrWhite(surface),
  );
  final caretL = dark ? 0.80 : 0.52;
  final caret = onAll(
    oklchToArgb(
      caretL,
      _min(0.8 * maxChroma(caretL, opH), dark ? 0.14 : 0.17),
      opH,
    ),
    backdrops,
    lim.caretRatio,
    displayText,
  );
  final edged = _withEdges(
    Palette(
      background: base,
      surface: surface,
      displayText: displayText,
      previewText: previewText,
      error: error,
      caret: caret,
      focusRing: 0,
      accent: caret,
      digit: digitKey,
      operator: opKey,
      equals: eqKey,
      function: fnKey,
      shadow: dark
          ? withAlpha(oklchToArgb(0.08, 0.03, h), 0x80)
          : withAlpha(oklchToArgb(0.32, 0.06, h), 0x40),
      highlight: highlight,
      seedColor: opKey.face,
    ),
    base,
    dark: dark,
  );
  // The ring on the scene and where it crosses a key's own shadow.
  final focusL = dark ? 0.88 : 0.42;
  final focus = onAll(
    oklchToArgb(
      focusL,
      dark ? 0.08 : _min(0.8 * maxChroma(focusL, opH), 0.12),
      opH,
    ),
    [...bgs, ...clayFocusShadowSamples(edged, colors)],
    lim.focusRingRatio,
    blackOrWhite(base),
  );
  final palette = edged.copyWith(focusRing: focus);

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
  final keyStyle = def.keyStyle.copyWith(
    kind: styleKind,
    shadowOffsetCdp: motion.depthCdp,
    shadowBlurCdp: blurCdp,
    edgeShadePermille: shadePermille,
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  String generatedName() => generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: palette.operator.face,
    family: ThemeFamily.claymorphism,
    dark: dark,
  );
  final name = steering?.nameOr(generatedName) ?? generatedName();

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.claymorphism,
    engineVersion: engineVersion,
    variant: steering == null ? ThemeVariant.generated : ThemeVariant.steered,
    intent: steering?.intent.forSpec,
    intentCentred: steering?.centred ?? false,
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

/// Rounded heavy Nunito for the display and keys; operators 100–200
/// heavier (not a recorded cue: the colour rules pass on their own).
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
  );
}

// ------------------------------------------------------------- guardrails --

const List<(String, KeyGroup)> _groups = [
  ('digit', KeyGroup.digit),
  ('operator', KeyGroup.operator),
  ('equals', KeyGroup.equals),
  ('function', KeyGroup.function),
];

KeyColors _keyOf(Palette p, KeyGroup g) => switch (g) {
  KeyGroup.digit => p.digit,
  KeyGroup.operator => p.operator,
  KeyGroup.equals => p.equals,
  KeyGroup.function => p.function,
};

/// The colour a clay function label must also reach the label floor on:
/// the inner shade for labels darker than the face, the highlight
/// composite for lighter ones.
int clayLabelRingColor(KeyColors k, int edgeShadePermille, int highlight) =>
    luminanceArgb(k.label | 0xFF000000) < luminanceArgb(k.face | 0xFF000000)
    ? clayInnerShade(k.face, edgeShadePermille)
    : clayHighlightComposite(k.face, highlight);

/// The family guardrails (called from `validateTheme` for
/// [ThemeFamily.claymorphism] specs only): coloured, darker drop shadows
/// ([GuardrailRule.clayShadowTint]), keys standing off the body
/// ([GuardrailRule.clayKeyBody]), a visible highlight on every face
/// ([GuardrailRule.clayHighlight]), function labels legible where they
/// cross the shade ring ([GuardrailRule.clayLabelRing]), the focus ring
/// where it crosses a key's own drop shadow ([GuardrailRule.focusRing],
/// "over key shadow"), an opaque, distinct display panel
/// ([GuardrailRule.clayPanel]) and the renderer contract
/// ([GuardrailRule.clayStyle]).
List<GuardrailViolation> validateClaymorphism(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final out = <GuardrailViolation>[];
  final p = spec.palette;
  final style = spec.keyStyle;
  final bg = spec.background;

  // Renderer contract first: the other rules read the scene colours.
  void styleFail(String field, double measured, double required) => out.add(
    GuardrailViolation(GuardrailRule.clayStyle, measured, required, field),
  );
  if (style.outlineWidthCdp != 0) {
    styleFail('outlineWidthCdp', style.outlineWidthCdp.toDouble(), 0);
  }
  if (style.shadowOffsetCdp != spec.motion.depthCdp ||
      !clayShadowCdp.contains(style.shadowOffsetCdp)) {
    styleFail(
      'shadowOffsetCdp = motion.depthCdp',
      style.shadowOffsetCdp.toDouble(),
      clayShadowCdp.lo.toDouble(),
    );
  }
  if (!clayShadowBlurCdp.contains(style.shadowBlurCdp)) {
    styleFail(
      'shadowBlurCdp',
      style.shadowBlurCdp.toDouble(),
      clayShadowBlurCdp.lo.toDouble(),
    );
  }
  if (!clayInnerShadePermille.contains(style.edgeShadePermille)) {
    styleFail(
      'edgeShadePermille',
      style.edgeShadePermille.toDouble(),
      clayInnerShadePermille.lo.toDouble(),
    );
  }
  final hiAlpha = (p.highlight >>> 24) & 0xFF;
  if ((p.highlight & 0x00FFFFFF) != 0x00FFFFFF ||
      !clayHighlightAlpha.contains(hiAlpha)) {
    styleFail(
      'highlight (white, alpha 0xA0–0xC8)',
      hiAlpha.toDouble(),
      clayHighlightAlpha.lo.toDouble(),
    );
  }
  final sceneOk =
      bg.kind == BackgroundKind.claySoft &&
      bg.colors.length == 9 &&
      bg.colors.every((c) => (c >>> 24) & 0xFF == 0xFF);
  if (!sceneOk) {
    styleFail('background (claySoft, 9 opaque colours)', 0, 9);
    return out;
  }

  final base = bg.colors[0];
  final baseLch = argbToOklch(base);
  final baseL = baseLch.l;
  final baseY = luminanceArgb(base);
  final bodyHue = _hueTenths(baseLch);
  final dark = spec.isDark;

  // Shadows: own hue, coloured, darker than the body.
  for (final (name, g) in _groups) {
    final k = _keyOf(p, g);
    final alpha = (k.edge >>> 24) & 0xFF;
    void tint(double measured, double required, String what) => out.add(
      GuardrailViolation(
        GuardrailRule.clayShadowTint,
        measured,
        required,
        '$name $what',
      ),
    );
    if (alpha < clayShadowAlphaMin || alpha > clayShadowAlphaMax) {
      tint(alpha.toDouble(), clayShadowAlphaMin.toDouble(), 'alpha');
      continue;
    }
    final e = argbToOklch(k.edge | 0xFF000000);
    final eHue = _hueTenths(e);
    final int ref;
    final double minC;
    if (dark) {
      ref = clayNightShadowHue(k.face, bodyHue, clayNightShadowL(baseL));
      minC = 0.035;
    } else {
      final f = argbToOklch(k.face | 0xFF000000);
      final raw = f.c >= 0.035 ? _hueTenths(f) : bodyHue;
      ref = BileRule.v2.apply(raw, e.l, 0.1);
      minC = _min(0.040, 0.75 * maxChroma(e.l, e.h));
    }
    if (e.c < minC) tint(e.c, minC, 'chroma');
    final dh = _hueDistance(eHue, ref);
    if (dh > 400) tint(dh / 10, 40, 'hue');
    final darkened = luminanceArgb(compositeOver(k.edge, base));
    if (darkened > 0.85 * baseY) tint(darkened, 0.85 * baseY, 'darkening');
  }

  // Keys stand off the body.
  void body(String name, double measured, double required) => out.add(
    GuardrailViolation(GuardrailRule.clayKeyBody, measured, required, name),
  );
  if (dark) {
    final cr = contrastRatio(p.digit.face, base);
    if (cr < 3) body('digit contrast', cr, 3);
    for (final (name, g) in _groups) {
      final d = _lightness(_keyOf(p, g).face) - baseL;
      if (d < clayNightMinKeyAboveBodyMilli / 1000) {
        body('$name lightness', d, clayNightMinKeyAboveBodyMilli / 1000);
      }
    }
  } else {
    final c = bg.colors;
    for (final x in [c[0], c[3], c[6]]) {
      final d = deltaEOKArgb(p.digit.face, x);
      if (d < 0.045) body('digit', d, 0.045);
    }
    final wash = deltaEOKArgb(p.digit.face, c[1]);
    if (wash < 0.025) body('digit vs wash', wash, 0.025);
    final fnDe = deltaEOKArgb(p.function.face, base);
    if (fnDe < 0.045) body('function', fnDe, 0.045);
    final fnDl = baseL - _lightness(p.function.face);
    if (fnDl < 0.03) body('function lightness', fnDl, 0.03);
    final fnCvd = minCvdDeltaE(p.function.face, base);
    if (fnCvd < clayFunctionMinCvdDeltaE) {
      body('function (colour-blind)', fnCvd, clayFunctionMinCvdDeltaE);
    }
  }

  // The highlight lifts every face and the pillow panel.
  double lift(int face) =>
      _lightness(clayHighlightComposite(face, p.highlight)) - _lightness(face);
  for (final (name, g) in _groups) {
    final d = lift(_keyOf(p, g).face);
    if (d < clayMinHighlightLift) {
      out.add(
        GuardrailViolation(
          GuardrailRule.clayHighlight,
          d,
          clayMinHighlightLift,
          name,
        ),
      );
    }
  }
  {
    final d = lift(p.surface);
    if (d < clayMinHighlightLift) {
      out.add(
        GuardrailViolation(
          GuardrailRule.clayHighlight,
          d,
          clayMinHighlightLift,
          'panel',
        ),
      );
    }
  }

  // Function labels where they cross the ring.
  final ring = clayLabelRingColor(
    p.function,
    style.edgeShadePermille,
    p.highlight,
  );
  final ringCr = contrastRatio(p.function.label, ring);
  if (ringCr < lim.labelRatio) {
    out.add(
      GuardrailViolation(GuardrailRule.clayLabelRing, ringCr, lim.labelRatio),
    );
  }

  // The focus ring where it crosses a key's own drop shadow.
  var ringWorst = double.infinity;
  for (final x in clayFocusShadowSamples(p, bg.colors)) {
    final cr = contrastRatio(p.focusRing, x);
    if (cr < ringWorst) ringWorst = cr;
  }
  if (ringWorst < lim.focusRingRatio) {
    out.add(
      GuardrailViolation(
        GuardrailRule.focusRing,
        ringWorst,
        lim.focusRingRatio,
        'over key shadow',
      ),
    );
  }

  // The display panel: an opaque pillow, lighter than and distinct from
  // the body.
  final surfaceAlpha = (p.surface >>> 24) & 0xFF;
  final panelDe = deltaEOKArgb(p.surface, base);
  if (surfaceAlpha != 255) {
    out.add(
      GuardrailViolation(
        GuardrailRule.clayPanel,
        surfaceAlpha.toDouble(),
        255,
        'opaque',
      ),
    );
  } else if (panelDe < 0.025) {
    out.add(
      GuardrailViolation(GuardrailRule.clayPanel, panelDe, 0.025, 'vs body'),
    );
  } else if (!clayPanelRaised(spec)) {
    out.add(
      GuardrailViolation(
        GuardrailRule.clayPanel,
        luminanceArgb(p.surface | 0xFF000000),
        baseY,
        'raised (lighter than the body)',
      ),
    );
  }
  return out;
}

/// Family repairs after labels and display texts (called from
/// `repairTheme` for [ThemeFamily.claymorphism] specs only): lifts light
/// digits / darkens light function keys off the body, raises the
/// highlight, re-solves the function label on its ring, recomputes every
/// drop shadow from the final faces and re-solves the focus ring over
/// them. Null when unrepairable.
Palette? repairClaymorphismExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final bg = spec.background;
  if (bg.colors.length != 9) return null;
  final base = bg.colors[0] | 0xFF000000;
  final baseL = _lightness(base);
  final dark = spec.isDark;
  final policy = lim.labelPolicy;
  final shade = spec.keyStyle.edgeShadePermille;
  var out = p;

  KeyColors? moved(KeyColors k, double dl) {
    final f = argbToOklch(k.face);
    final face = oklchToArgb(_clamp(f.l + dl, 0, 1), f.c, f.h);
    return repairKeyLabel(k.copyWith(face: face), policy, [face]);
  }

  // 1. Keys off the body (light themes; night ranges make it unreachable).
  if (dark) {
    for (final (_, g) in _groups) {
      if (_lightness(_keyOf(out, g).face) - baseL <
          clayNightMinKeyAboveBodyMilli / 1000) {
        return null;
      }
    }
  } else {
    final c = bg.colors;
    bool digitOk(int f) =>
        deltaEOKArgb(f, c[0]) >= 0.045 &&
        deltaEOKArgb(f, c[3]) >= 0.045 &&
        deltaEOKArgb(f, c[6]) >= 0.045 &&
        deltaEOKArgb(f, c[1]) >= 0.025;
    for (var i = 0; i < 4 && !digitOk(out.digit.face); i++) {
      if (_lightness(out.digit.face) + 0.015 >
          clayDigitMaxLMilli / 1000 + 1e-9) {
        break;
      }
      final k = moved(out.digit, 0.015);
      if (k == null) return null;
      out = out.copyWith(digit: k);
    }
    if (!digitOk(out.digit.face)) return null;
    bool fnOk(int f) =>
        deltaEOKArgb(f, base) >= 0.045 &&
        baseL - _lightness(f) >= 0.03 &&
        minCvdDeltaE(f, base) >= clayFunctionMinCvdDeltaE;
    for (var i = 0; i < 6 && !fnOk(out.function.face); i++) {
      final k = moved(out.function, -0.015);
      if (k == null) return null;
      out = out.copyWith(function: k);
    }
    if (!fnOk(out.function.face)) return null;
  }

  // 2. The highlight.
  bool lifted(int face, int highlight) =>
      _lightness(clayHighlightComposite(face, highlight)) - _lightness(face) >=
      clayMinHighlightLift;
  bool allLifted(Palette x) =>
      lifted(x.digit.face, x.highlight) &&
      lifted(x.operator.face, x.highlight) &&
      lifted(x.equals.face, x.highlight) &&
      lifted(x.function.face, x.highlight) &&
      lifted(x.surface, x.highlight);
  while (!allLifted(out)) {
    final a = (out.highlight >>> 24) & 0xFF;
    if (a >= clayHighlightAlpha.hi) break;
    final next = a + 8 > clayHighlightAlpha.hi ? clayHighlightAlpha.hi : a + 8;
    out = out.copyWith(highlight: withAlpha(0xFFFFFFFF, next));
  }
  if (!lifted(out.digit.face, out.highlight)) {
    final floor = _max(baseL + clayDigitAboveBodyMilli / 1000, 0.915);
    for (var i = 0; i < 6 && !lifted(out.digit.face, out.highlight); i++) {
      if (_lightness(out.digit.face) - 0.01 < floor - 1e-9) break;
      final k = moved(out.digit, -0.01);
      if (k == null) return null;
      out = out.copyWith(digit: k);
    }
  }
  if (!allLifted(out)) return null;

  // 3. The function label on its ring.
  final ring = clayLabelRingColor(out.function, shade, out.highlight);
  if (contrastRatio(out.function.label, ring) < lim.labelRatio) {
    final label = solveOnAll(out.function.label, [
      out.function.face,
      ring,
    ], lim.labelRatio);
    if (label == null) return null;
    out = out.copyWith(function: out.function.copyWith(label: label));
  }

  // 4. Drop shadows from the final faces, then the focus ring where it
  // crosses them.
  out = _withEdges(out, base, dark: dark);
  final ringOn = [...bgs, ...clayFocusShadowSamples(out, bg.colors)];
  final ringFix = solveOnAll(out.focusRing, ringOn, lim.focusRingRatio);
  if (ringFix == null) return null;
  return out.copyWith(focusRing: ringFix);
}
