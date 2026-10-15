/// The Paper & ink family (spec §5.3 #11; motion brief §2.3 "Paper &
/// ink"): stationery and editorial print. Pure Dart: part of the
/// generator, so every constant here is part of the family's engine-v3
/// definition and must not change once a build ships it.
///
/// - **Sheet** (the background, [BackgroundKind.paperSheet]): cream laid,
///   white bond, newsprint, kraft or blue engineering paper, or for dark
///   themes indigo-black ink paper and a slate blackboard
///   ([PaperSheet]). Plain, ruled, graph or dot-grid, with a static,
///   hash-derived grain of flecks and fibres (paper_ink_scene.dart).
///   `colors` = `[paper, rule ink]`; `pattern` = the layout (none / stripes
///   = ruled / grid / dots); `patternScaleCdp` = the line pitch;
///   `patternOpacityPermille` = the line alpha (minor lines of a grid);
///   `angleTenths` = the grain strength g (0–1000 ‰); `patternColor` is
///   always 0 (the rule colour is `colors[1]`, which lerps).
/// - **Ink**: one near-neutral ink (blue-black, carbon, sepia or green-
///   black on light sheets; cream gel or chalk on dark ones) for every
///   key's hand-drawn outline (`KeyColors.edge`, ≥ 3:1 on every sheet
///   sample), the labels, the display text, the focus ring and the
///   operator hatching. `palette.shadow` is the ink (opaque; never painted
///   as a shadow), `palette.highlight` the ink wash's tide-line colour at
///   its peak alpha.
/// - **Keys**: paper slips a shade whiter than the sheet (cream card on
///   kraft; a shade lighter than the sheet on dark ones), pale blue-grey
///   function slips, operators washed with the stamp ink (or its ±30°
///   neighbour; never olive or brown on the dark sheets, where 30°–70°
///   turns wine) inside a hatched ink frame — the recorded non-colour cue,
///   [OperatorCue.pattern] — and a `=` rubber stamp in one accent ink
///   (vermilion, crimson, ultramarine, Prussian blue, viridian, methyl
///   violet, madder; peacock and burnt sienna on dark sheets) whose label
///   is knocked out to the slip / sheet colour.
/// - **Display**: an opaque ledger panel (ruled sheets) or a torn index
///   card (`palette.surface`) with the paper grain, feint rules in its
///   upper part and a red-pen margin rule; its text is checked against
///   the panel and the panel's grain and rule composites
///   ([paperInkDisplayBackdrops]).
///
/// Every draw comes from the generator's named sub-streams (`palette` and
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), each a fixed number of draws whatever the sheet, so a theme is
/// a pure function of (seed, engineVersion, accessible).
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

/// The paper sheets (light ones first). The palette stream draws the
/// brightness, then the sheet, then the tone of the dark sheets.
enum PaperSheet {
  /// Warm laid writing paper (light).
  cream,

  /// Near-white bond (light).
  ivory,

  /// Warm grey newsprint (light).
  newsprint,

  /// Kraft card; keys and display are cream card stock on it (light).
  kraft,

  /// Cool blue-white engineering paper, always a graph grid (light).
  graph,

  /// Indigo-black (tone 0) or charcoal (tone 1) "ink paper" (dark).
  inkPaper,

  /// Slate green (tone 0) or slate grey (tone 1) blackboard (dark).
  blackboard,
}

/// Light sheets `[cream, ivory, newsprint, kraft, graph]` and dark sheets
/// `[inkPaper, blackboard]` weights.
const List<int> paperInkLightSheetWeights = [4, 2, 2, 2, 3];
const List<int> paperInkDarkSheetWeights = [3, 2];

/// Tone of the dark sheets: `[0, 1]` weights — indigo ink paper and slate
/// green board are favoured; charcoal ink paper sits near Neo-brutalism's
/// dark sheets (cross-review).
const List<int> paperInkToneWeights = [3, 1];

/// An OKLCH range in engine integers (L and C × 1000, h in tenths).
typedef PaperLchRange = ({IntRange l, IntRange c, IntRange h});

/// Paper colour by sheet (dark sheets: tone 0, then tone 1).
const List<PaperLchRange> paperInkPapers = [
  (l: IntRange(945, 975), c: IntRange(18, 34), h: IntRange(780, 920)),
  (l: IntRange(965, 985), c: IntRange(6, 16), h: IntRange(850, 1000)),
  (l: IntRange(885, 925), c: IntRange(10, 20), h: IntRange(750, 950)),
  (l: IntRange(760, 840), c: IntRange(45, 65), h: IntRange(620, 740)),
  (l: IntRange(955, 980), c: IntRange(8, 20), h: IntRange(2050, 2350)),
  (l: IntRange(200, 260), c: IntRange(25, 45), h: IntRange(2600, 2850)),
  (l: IntRange(240, 295), c: IntRange(25, 42), h: IntRange(1500, 1750)),
];

/// Tone 1 of the dark sheets: charcoal ink paper, slate grey blackboard.
const List<PaperLchRange> paperInkDarkTone1Papers = [
  (l: IntRange(205, 255), c: IntRange(4, 12), h: IntRange(2400, 3000)),
  (l: IntRange(235, 290), c: IntRange(6, 14), h: IntRange(2150, 2500)),
];

/// The inks.
enum PaperInkType {
  /// Blue-black fineliner (light sheets).
  blueBlack,

  /// Carbon black, hued like the paper (light sheets).
  carbon,

  /// Sepia (light sheets).
  sepia,

  /// Green-black (light sheets).
  greenBlack,

  /// Cream gel pen (dark sheets).
  creamGel,

  /// Chalk (dark sheets).
  chalk,
}

/// Ink colour by [PaperInkType] (carbon takes the paper hue).
const List<PaperLchRange> paperInkInks = [
  (l: IntRange(180, 280), c: IntRange(30, 50), h: IntRange(2550, 2700)),
  (l: IntRange(160, 240), c: IntRange(3, 12), h: IntRange(0, 3599)),
  (l: IntRange(200, 280), c: IntRange(25, 45), h: IntRange(400, 600)),
  (l: IntRange(200, 270), c: IntRange(20, 35), h: IntRange(1600, 1800)),
  (l: IntRange(900, 960), c: IntRange(10, 24), h: IntRange(800, 1000)),
  (l: IntRange(910, 960), c: IntRange(4, 12), h: IntRange(2200, 2500)),
];

/// Ink weights on light sheets `[blueBlack, carbon, sepia, greenBlack]`.
const List<int> paperInkLightInkWeights = [3, 3, 2, 1];

/// Ink weights `[creamGel, chalk]` on ink paper and on the blackboard.
const List<int> paperInkInkPaperInkWeights = [4, 1];
const List<int> paperInkBlackboardInkWeights = [1, 4];

/// Accessible lock: light inks no lighter, dark inks no darker (× 1000).
const int paperInkAccessibleLightInkMaxL = 240;
const int paperInkAccessibleDarkInkMinL = 920;

/// The stamp inks (the `=` face, the accent, the seed colour and the name
/// accent).
enum PaperStampInk {
  vermilion,
  crimson,
  ultramarine,
  prussian,
  viridian,
  peacock,
  methylViolet,
  burntSienna,
  madder,
}

/// Stamp hue ranges (tenths) by [PaperStampInk]. No ink sits in 70°–115°
/// (a dark gold reads as olive).
const List<IntRange> paperInkStampHues = [
  IntRange(300, 400),
  IntRange(150, 250),
  IntRange(2620, 2720),
  IntRange(2400, 2500),
  IntRange(1500, 1620),
  IntRange(1950, 2050),
  IntRange(3000, 3120),
  IntRange(450, 580),
  IntRange(3450, 3550),
];

/// Stamp weights on light and dark sheets: peacock and burnt sienna go
/// grey / chocolate at the lightness a light-sheet stamp needs, so they
/// appear only as pastel gel stamps on dark sheets.
const List<int> paperInkLightStampWeights = [4, 2, 3, 2, 2, 0, 2, 0, 1];
const List<int> paperInkDarkStampWeights = [4, 2, 3, 2, 2, 1, 2, 1, 1];

/// Light-sheet stamp lightness (× 1000) by ink: as light as the knocked-out
/// label allows (≈ 4.5:1), so vermilion reads vermilion, not maroon.
const List<IntRange> paperInkLightStampL = [
  IntRange(470, 550),
  IntRange(470, 540),
  IntRange(470, 540),
  IntRange(450, 520),
  IntRange(450, 520),
  IntRange(520, 560),
  IntRange(470, 540),
  IntRange(470, 520),
  IntRange(470, 540),
];

/// Dark-sheet (pastel gel) stamp lightness × 1000.
const IntRange paperInkDarkStampL = IntRange(700, 800);

/// Stamp chroma as a fraction of the gamut × 1000, capped at 0.200 (light)
/// or 0.170 (dark).
const IntRange paperInkStampRel = IntRange(700, 950);
const int paperInkLightStampCapMilli = 200;
const int paperInkDarkStampCapMilli = 170;

/// Accessible lock: light stamps no lighter, dark stamps no darker.
const int paperInkAccessibleLightStampMaxL = 430;
const int paperInkAccessibleDarkStampMinL = 780;

/// Operator wash hue offset from the stamp: `[0, +30°, −30°]` weights.
const List<int> paperInkWashOffsetWeights = [3, 1, 1];
const List<int> paperInkWashOffsets = [0, 300, -300];

/// Dark sheets: a wash hue landing in 70°–135° (olive at L 0.3) takes the
/// other ±30° neighbour instead (same draws).
const IntRange paperInkDarkOliveHues = IntRange(700, 1350);

/// Dark sheets: a wash hue in 30°–70° (chocolate brown at L 0.3, C 0.045)
/// is mapped onto wine through maroon, 345°–20° (after the olive flip).
const IntRange paperInkDarkBrownHues = IntRange(300, 699);

/// Where [paperInkDarkBrownHues] land (tenths, linear; wraps past 360°).
const int paperInkDarkWineStart = 3450;
const int paperInkDarkWineSpan = 350;

/// The dark-sheet wash hue for [washH] (tenths): brown → wine.
int paperDarkWashHue(int washH) => paperInkDarkBrownHues.contains(washH)
    ? _wrap(
        paperInkDarkWineStart +
            (washH - paperInkDarkBrownHues.lo) *
                paperInkDarkWineSpan ~/
                (paperInkDarkBrownHues.hi + 1 - paperInkDarkBrownHues.lo),
      )
    : washH;

/// Rule ink (`colors[1]`): feint blue on writing paper, stronger blue on
/// graph paper, brown on kraft, the paper hue on ink paper, chalk on the
/// blackboard (sheet order; ink paper takes the paper hue).
const List<PaperLchRange> paperInkRules = [
  (l: IntRange(600, 700), c: IntRange(40, 70), h: IntRange(2250, 2500)),
  (l: IntRange(600, 700), c: IntRange(40, 70), h: IntRange(2250, 2500)),
  (l: IntRange(600, 700), c: IntRange(40, 70), h: IntRange(2250, 2500)),
  (l: IntRange(420, 500), c: IntRange(30, 50), h: IntRange(550, 700)),
  (l: IntRange(600, 680), c: IntRange(60, 90), h: IntRange(2100, 2350)),
  (l: IntRange(600, 700), c: IntRange(30, 50), h: IntRange(0, 3599)),
  (l: IntRange(700, 780), c: IntRange(5, 15), h: IntRange(2000, 2400)),
];

/// Scene layouts `[none, ruled, grid, dots]` weights by sheet.
const List<List<int>> paperInkLayoutWeights = [
  [2, 4, 0, 1],
  [2, 3, 0, 2],
  [5, 1, 0, 1],
  [4, 0, 0, 2],
  [0, 0, 1, 0],
  [2, 2, 0, 2],
  [4, 1, 1, 0],
];

/// The [BackgroundPattern] of each layout index.
const List<BackgroundPattern> paperInkLayouts = [
  BackgroundPattern.none,
  BackgroundPattern.stripes,
  BackgroundPattern.grid,
  BackgroundPattern.dots,
];

/// Line pitch (dp × 100) by layout: real stationery pitches (ruled
/// 40–48 dp; graph minor squares and dot grids 28–32 dp).
const List<List<int>> paperInkPitches = [
  [0, 0, 0],
  [4000, 4400, 4800],
  [2800, 3000, 3200],
  [2800, 3000, 3200],
];

/// A graph grid's major line every this many minor squares.
const int paperInkGridMajorEvery = 4;

/// Line alpha (‰) by layout for light sheets, ink paper and the
/// blackboard.
const List<List<IntRange>> paperInkLineAlphas = [
  [IntRange(0, 0), IntRange(0, 0), IntRange(0, 0)],
  [IntRange(220, 300), IntRange(180, 240), IntRange(140, 200)],
  [IntRange(160, 240), IntRange(120, 170), IntRange(120, 170)],
  [IntRange(260, 340), IntRange(180, 240), IntRange(180, 240)],
];

/// Grain strength g (‰) by sheet.
const List<IntRange> paperInkGrain = [
  IntRange(300, 500),
  IntRange(200, 350),
  IntRange(450, 700),
  IntRange(500, 800),
  IntRange(200, 350),
  IntRange(250, 450),
  IntRange(500, 800),
];

/// Grain tile ceilings: black flecks and fibres are drawn at ≤ 20 % and
/// white fibres / chalk dust at ≤ 14 % (each scaled by g), every primitive
/// with `BlendMode.src`, so no texel ever exceeds them.
const int paperFleckMaxPermille = 200;
const int paperFibreMaxPermille = 140;

/// Grid major lines: 1.6 × the minor alpha, capped (‰).
const int paperMajorCapPermille = 450;

/// The paper grain on key slips and the display panel, ‰ of g.
const int paperFaceGrainPermille = 500;

/// Feint-rule alpha (of 255) on the display panel; none under the
/// Accessible lock.
const int paperDisplayRuleAlpha = 56;

/// How far past its floor the red-pen error text is solved.
const double paperTextMargin = 0.05;

/// Outline (fineliner) widths, dp × 100, on 0.25 dp steps: 1.25–1.75 dp,
/// always thinner than Neo-brutalism's 2 dp minimum.
const IntRange paperInkOutlineWidthCdp = IntRange(125, 175);

/// Operator hatch ink opacity × 1000, on 0.05 steps.
const IntRange paperInkHatchPermille = IntRange(600, 750);

/// Hatch lines must reach this contrast against the operator face at
/// their opacity (visible in greyscale and under every CVD).
const double paperHatchRatio = 3;

/// The `=` stamp must reach this contrast against the digit slips.
const double paperStampRatio = 3;

/// Peak alpha (of 255) of the ink wash's tide line (`palette.highlight`);
/// the wash fill is this ÷ [paperWashRimFactor].
const int paperWashRimMaxAlpha = 58;
const double paperWashRimFactor = 1.6;

/// Light ranges (documentary unions; the builder reads the sheet tables).
const RoleRanges paperInkLightRanges = RoleRanges(
  background: RoleRange(IntRange(760, 985), ChromaRange.abs(6, 65)),
  surfaceOffsetMilli: IntRange(8, 30),
  surfaceChroma: ChromaRange.abs(3, 25),
  digit: RoleRange(IntRange(897, 992), ChromaRange.abs(3, 30)),
  digitDuotoneChroma: ChromaRange.abs(3, 30),
  function: RoleRange(IntRange(842, 957), ChromaRange.abs(12, 22)),
  operator: RoleRange(IntRange(822, 947), ChromaRange.abs(10, 75)),
  operatorMonochromeL: IntRange(822, 947),
  equals: RoleRange(IntRange(430, 550), ChromaRange.rel(700, 950, 200)),
  labelStartLMilli: 230,
  labelMaxChromaMilli: 50,
  accentChroma: ChromaRange.rel(700, 950, 200),
  minDigitAboveBackgroundMilli: 0,
);

/// Dark ranges (documentary unions).
const RoleRanges paperInkDarkRanges = RoleRanges(
  background: RoleRange(IntRange(200, 295), ChromaRange.abs(4, 45)),
  surfaceOffsetMilli: IntRange(30, 50),
  surfaceChroma: ChromaRange.abs(4, 41),
  digit: RoleRange(IntRange(235, 355), ChromaRange.abs(3, 36)),
  digitDuotoneChroma: ChromaRange.abs(3, 36),
  function: RoleRange(IntRange(270, 410), ChromaRange.abs(15, 25)),
  operator: RoleRange(IntRange(260, 400), ChromaRange.abs(10, 50)),
  operatorMonochromeL: IntRange(260, 400),
  equals: RoleRange(IntRange(700, 800), ChromaRange.rel(700, 950, 170)),
  labelStartLMilli: 930,
  labelMaxChromaMilli: 24,
  accentChroma: ChromaRange.rel(700, 950, 170),
  minDigitAboveBackgroundMilli: 35,
);

/// Paper & ink (spec §5.3 #11; motion brief §2.3 "Paper & ink"): outlined
/// paper slips (rounded-rect fills, 2–6 % corners, under a hand-drawn
/// fineliner outline). Press: the outline "boils" to an alternate stroke
/// in frame 1 (`tint`), an ink wash spreads from the fingertip to its peak
/// and dries on `effectsSlow` (`releaseAlt`), the slip drops 1 dp
/// (`release` 1400/0.9, seeded × {0.9, 1, 1.1}); display glyphs bleed in
/// from 104 %; sound `typewriter`, haptic soft · 0.6. The palette is built
/// by [buildPaperInkCandidate].
const FamilyDefinition paperInkDefinition = FamilyDefinition(
  family: ThemeFamily.paperInk,
  brightnessWeights: [2, 7],
  schemes: [Weighted(HarmonyScheme.analogous, 1)],
  shapes: [Weighted(KeyShapeKind.roundedRect, 1)],
  cornerPermille: IntRange(20, 60),
  styles: [Weighted(KeyStyleKind.outlined, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.outlined,
    outlineWidthCdp: 150,
    edgeShadePermille: 650,
    stateLayerPermille: 0,
  ),
  displayFonts: [Weighted(FontIds.newsreader, 1)],
  keyFonts: [Weighted(FontIds.newsreader, 1)],
  displayWeight: IntRange(350, 450),
  keyWeight: IntRange(400, 500),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [Weighted(BackgroundKind.paperSheet, 1)],
  patterns: [
    Weighted(BackgroundPattern.none, 1),
    Weighted(BackgroundPattern.stripes, 1),
    Weighted(BackgroundPattern.grid, 1),
    Weighted(BackgroundPattern.dots, 1),
  ],
  sound: SoundPackId.typewriter,
  dark: paperInkDarkRanges,
  light: paperInkLightRanges,
  motion: MotionSpec(
    verb: PressVerb.ink,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.effectsFast,
    release: SpringTokens.standardFast,
    releaseAlt: SpringTokens.effectsSlow,
    depthCdp: 100,
    entry: EntryStyle.bleed,
    entryScalePermille: 1040,
    fx: PressFx.inkWash,
    impact: ImpactStyle.soft,
    impactPermille: 600,
  ),
  motionRanges: MotionRanges(),
  nonColourOperatorCue: OperatorCue.pattern,
  bile: BileRule.v2,
);

// ---------------------------------------------------------------- samples --

/// The grain strength g (‰, 0–1000) of a paper sheet [bg].
int paperGrainOf(BackgroundSpec bg) {
  final g = bg.angleTenths;
  return g < 0 ? 0 : (g > 1000 ? 1000 : g);
}

/// Alpha (of 255) of the darkest black grain texel at grain [g] ‰.
int paperFleckAlpha(int g) =>
    (255 * paperFleckMaxPermille * g + 500000) ~/ 1000000;

/// Alpha (of 255) of the lightest white grain texel at grain [g] ‰.
int paperFibreAlpha(int g) =>
    (255 * paperFibreMaxPermille * g + 500000) ~/ 1000000;

/// Alpha (of 255) for [permille].
int paperAlpha(int permille) => (255 * permille + 500) ~/ 1000;

/// [base] with the extreme grain texels at grain [g] ‰ over it: the base,
/// the darkest fleck over it, the lightest fibre over it.
List<int> paperGrainBases(int base, int g) {
  final b = base | 0xFF000000;
  return [
    b,
    compositeOver(withAlpha(0xFF000000, paperFleckAlpha(g)), b),
    compositeOver(withAlpha(0xFFFFFFFF, paperFibreAlpha(g)), b),
  ];
}

/// Guardrail background samples of a paper sheet, in painter order (paper,
/// grain, lines): the grain bases, then each line ink over each base
/// (ruled / dots: the rule; grid: minor and major lines). These are
/// ceilings: rasterising only lowers a texel's coverage.
List<int>? paperInkSceneSamples(BackgroundSpec bg) {
  if (bg.colors.isEmpty) return null;
  final paper = bg.colors.first | 0xFF000000;
  final bases = paperGrainBases(paper, paperGrainOf(bg));
  if (bg.colors.length < 2) return bases;
  final rule = bg.colors[1] | 0xFF000000;
  final op = bg.patternOpacityPermille;
  List<int> over(int permille) => [
    for (final b in bases)
      compositeOver(withAlpha(rule, paperAlpha(permille)), b),
  ];
  return switch (bg.pattern) {
    BackgroundPattern.none => bases,
    BackgroundPattern.stripes ||
    BackgroundPattern.dots => [...bases, ...over(op)],
    BackgroundPattern.grid => [
      ...bases,
      ...over(op),
      ...over(_majorPermille(op)),
    ],
    // Not generated: the painter falls back to a plain gradient of the
    // two colours.
    _ => [paper, rule],
  };
}

int _majorPermille(int minor) {
  final m = minor * 8 ~/ 5;
  return m > paperMajorCapPermille ? paperMajorCapPermille : m;
}

/// The display panel's colours under text: [panel] with the panel grain
/// (half the sheet's) and, outside the Accessible lock, the feint rules
/// over each.
List<int> paperPanelSamples(
  int panel,
  BackgroundSpec bg, {
  required bool accessible,
}) {
  final g = paperGrainOf(bg) * paperFaceGrainPermille ~/ 1000;
  final bases = paperGrainBases(panel, g);
  if (accessible || bg.colors.length < 2) return bases;
  final rule = bg.colors[1] | 0xFF000000;
  return [
    ...bases,
    for (final b in bases)
      compositeOver(withAlpha(rule, paperDisplayRuleAlpha), b),
  ];
}

/// Display text sits only on the opaque panel (the face draws it, with
/// the grain and the feint rules; the red margin rule stays left of the
/// text): the panel samples are the only backdrops.
List<int>? paperInkDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) => paperPanelSamples(
  surfaces.first,
  spec.background,
  accessible: spec.accessible,
);

// ------------------------------------------------------------ guardrails --

double _minContrastOn(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

/// Contrast of the operator hatch (the operator edge ink at
/// [edgeShadePermille]) against the operator face.
double paperHatchContrast(KeyColors op, int edgeShadePermille) {
  final face = op.face | 0xFF000000;
  final hatch = compositeOver(
    withAlpha(op.edge, paperAlpha(edgeShadePermille)),
    face,
  );
  return contrastRatio(hatch, face);
}

/// The lowest label contrast of [p]'s four key groups under the wash
/// tide line [rim] (any alpha) laid over the face.
double paperWashLabelContrast(Palette p, int rim) {
  var m = double.infinity;
  for (final k in [p.digit, p.operator, p.equals, p.function]) {
    final r = contrastRatio(k.label, compositeOver(rim, k.face | 0xFF000000));
    if (r < m) m = r;
  }
  return m;
}

/// [rim] with its alpha lowered in steps of 2 until every label keeps
/// [GuardrailLimits.labelRatio] under it (0 at worst).
int fitPaperWash(Palette p, int rim, GuardrailLimits lim) {
  var a = (rim >>> 24) & 0xFF;
  if (a > paperWashRimMaxAlpha) a = paperWashRimMaxAlpha;
  while (a > 0 &&
      paperWashLabelContrast(p, withAlpha(rim, a)) < lim.labelRatio) {
    a = a - 2 < 0 ? 0 : a - 2;
  }
  return withAlpha(rim, a);
}

/// The Paper & ink rules (on top of the generic ones):
///
/// - [GuardrailRule.paperOutline]: every key's outline (`KeyColors.edge`)
///   opaque and ≥ 3:1 against every sheet sample; width 1.25–1.75 dp.
/// - [GuardrailRule.paperOperatorCue]: the recorded cue is
///   [OperatorCue.pattern]; the hatch opacity is 0.60–0.75 and the hatch
///   lines reach 3:1 against the operator face at it; operators are ≥ 200
///   heavier than digits as well.
/// - [GuardrailRule.paperStamp]: the `=` stamp ≥ 3:1 against the digit
///   slips (it reads as solid ink on paper).
/// - [GuardrailRule.paperWash]: the wash tide line's alpha ≤ 58 and every
///   label keeps the label floor with it laid over its face.
List<GuardrailViolation> validatePaperInk(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final p = spec.palette;
  final out = <GuardrailViolation>[];
  final groups = {
    'digit': p.digit,
    'operator': p.operator,
    'equals': p.equals,
    'function': p.function,
  };
  for (final MapEntry(key: name, value: k) in groups.entries) {
    final opaque = ((k.edge >>> 24) & 0xFF) == 255;
    final r = opaque ? _minContrastOn(k.edge, bgs) : 1.0;
    if (r < ratioLarge) {
      out.add(
        GuardrailViolation(GuardrailRule.paperOutline, r, ratioLarge, name),
      );
    }
  }
  final width = spec.keyStyle.outlineWidthCdp;
  if (!paperInkOutlineWidthCdp.contains(width)) {
    out.add(
      GuardrailViolation(
        GuardrailRule.paperOutline,
        width / 100,
        paperInkOutlineWidthCdp.lo / 100,
        'outline width (dp)',
      ),
    );
  }

  if (spec.nonColourOperatorCue != OperatorCue.pattern) {
    out.add(
      const GuardrailViolation(GuardrailRule.paperOperatorCue, 0, 1, 'cue'),
    );
  }
  final shade = spec.keyStyle.edgeShadePermille;
  if (!paperInkHatchPermille.contains(shade)) {
    out.add(
      GuardrailViolation(
        GuardrailRule.paperOperatorCue,
        shade / 1000,
        paperInkHatchPermille.lo / 1000,
        'hatch opacity',
      ),
    );
  }
  final hatch = paperHatchContrast(p.operator, shade);
  if (hatch < paperHatchRatio) {
    out.add(
      GuardrailViolation(
        GuardrailRule.paperOperatorCue,
        hatch,
        paperHatchRatio,
        'hatch contrast',
      ),
    );
  }
  final bonus = spec.type.operatorWeight - spec.type.keyWeight;
  if (bonus < 200) {
    out.add(
      GuardrailViolation(
        GuardrailRule.paperOperatorCue,
        bonus.toDouble(),
        200,
        'operator weight bonus',
      ),
    );
  }

  final stamp = contrastRatio(p.equals.face, p.digit.face);
  if (stamp < paperStampRatio) {
    out.add(GuardrailViolation(GuardrailRule.paperStamp, stamp, 3));
  }

  final rimAlpha = (p.highlight >>> 24) & 0xFF;
  if (rimAlpha > paperWashRimMaxAlpha) {
    out.add(
      GuardrailViolation(
        GuardrailRule.paperWash,
        rimAlpha.toDouble(),
        paperWashRimMaxAlpha.toDouble(),
        'maximum alpha',
      ),
    );
  }
  final washed = paperWashLabelContrast(p, p.highlight);
  if (washed < lim.labelRatio) {
    out.add(
      GuardrailViolation(GuardrailRule.paperWash, washed, lim.labelRatio),
    );
  }
  return out;
}

/// The Paper & ink repairs (after labels and display texts): the ink
/// re-solved to ≥ 3:1 on every sheet sample (outlines, hatch, shadow), the
/// stamp darkened (light) / lightened (dark) until it stands 3:1 off the
/// digit slips, the operator face moved away from the ink until its hatch
/// shows, and the wash refitted. Null when unreachable.
Palette? repairPaperInkExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final ink = solveOnAll(p.shadow | 0xFF000000, bgs, ratioLarge);
  if (ink == null) return null;
  var out = p.copyWith(
    digit: p.digit.copyWith(edge: ink),
    operator: p.operator.copyWith(edge: ink),
    equals: p.equals.copyWith(edge: ink),
    function: p.function.copyWith(edge: ink),
    shadow: ink,
  );
  final policy = lim.labelPolicy;
  final dark = spec.isDark;

  if (contrastRatio(out.equals.face, out.digit.face) < paperStampRatio) {
    final face = argbToOklch(out.equals.face);
    var l = face.l;
    KeyColors? fixed;
    for (var i = 0; i < 6 && fixed == null; i++) {
      l = clamp01(l + (dark ? 0.04 : -0.04));
      final pair = repairPair(
        (l: l, c: face.c, h: face.h),
        argbToOklch(out.equals.label),
        policy: policy,
      );
      if (contrastRatio(pair.face, out.digit.face) >= paperStampRatio) {
        fixed = out.equals.copyWith(face: pair.face, label: pair.label);
      }
    }
    if (fixed == null) return null;
    out = out.copyWith(equals: fixed);
  }

  final shade = spec.keyStyle.edgeShadePermille;
  if (paperHatchContrast(out.operator, shade) < paperHatchRatio) {
    final face = argbToOklch(out.operator.face);
    final inkL = argbToOklch(ink).l;
    var l = face.l;
    KeyColors? fixed;
    for (var i = 0; i < 4 && fixed == null; i++) {
      l = clamp01(l + (inkL < face.l ? 0.02 : -0.02));
      final k = repairKeyLabel(
        out.operator.copyWith(face: oklchToArgb(l, face.c, face.h)),
        policy,
        bgs,
      );
      if (k != null && paperHatchContrast(k, shade) >= paperHatchRatio) {
        fixed = k;
      }
    }
    if (fixed == null) return null;
    out = out.copyWith(operator: fixed);
  }

  final rimAlpha = (out.highlight >>> 24) & 0xFF;
  return out.copyWith(
    highlight: fitPaperWash(
      out,
      withAlpha(
        ink,
        rimAlpha < paperWashRimMaxAlpha ? rimAlpha : paperWashRimMaxAlpha,
      ),
      lim,
    ),
  );
}

// --------------------------------------------------------------- builder --

int _wrap(int tenths) => tenths % 3600;

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

double _capped(double c, int capMilli) {
  final cap = capMilli / 1000;
  return c < cap ? c : cap;
}

/// Builds one unvalidated Paper & ink candidate (the generator repairs and
/// validates it, retries with `palette/retry/n` and finally falls back to
/// a Paper & ink hero).
ThemeSpec buildPaperInkCandidate(
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
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final bile = def.bile;

  // P1–P3: brightness, sheet, tone.
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final brightness = dark ? ThemeBrightness.dark : ThemeBrightness.light;
  final sheetPick = p.pickWeighted(
    dark ? paperInkDarkSheetWeights : paperInkLightSheetWeights,
  );
  final sheet = PaperSheet.values[dark ? 5 + sheetPick : sheetPick];
  final tone = p.pickWeighted(paperInkToneWeights);
  final kraft = sheet == PaperSheet.kraft;

  // P4–P6: paper.
  final paperRange = dark && tone == 1
      ? paperInkDarkTone1Papers[sheet.index - 5]
      : paperInkPapers[sheet.index];
  final paperL = paperRange.l.sample(p);
  final paperC = paperRange.c.sample(p);
  final paperH = paperRange.h.sample(p);
  final paper = oklchToArgb(paperL / 1000, paperC / 1000, paperH / 10);

  // P7–P10: ink.
  final inkPick = p.pickWeighted(switch (sheet) {
    PaperSheet.inkPaper => paperInkInkPaperInkWeights,
    PaperSheet.blackboard => paperInkBlackboardInkWeights,
    _ => paperInkLightInkWeights,
  });
  final inkType = PaperInkType.values[dark ? 4 + inkPick : inkPick];
  final inkRange = paperInkInks[inkType.index];
  var inkL = inkRange.l.sample(p);
  final inkC = inkRange.c.sample(p);
  final inkHueDraw = inkRange.h.sample(p);
  final inkH = inkType == PaperInkType.carbon ? paperH : inkHueDraw;
  if (accessible) {
    inkL = dark
        ? (inkL < paperInkAccessibleDarkInkMinL
              ? paperInkAccessibleDarkInkMinL
              : inkL)
        : (inkL > paperInkAccessibleLightInkMaxL
              ? paperInkAccessibleLightInkMaxL
              : inkL);
  }
  final inkLch = (l: inkL / 1000, c: inkC / 1000, h: inkH / 10);
  final ink = oklchToArgb(inkLch.l, inkLch.c, inkLch.h);

  // P11–P14: the stamp.
  final stampInk = p.pickWeighted(
    dark ? paperInkDarkStampWeights : paperInkLightStampWeights,
  );
  final stampH = paperInkStampHues[stampInk].sample(p);
  var stampL = (dark ? paperInkDarkStampL : paperInkLightStampL[stampInk])
      .sample(p);
  final stampRel = paperInkStampRel.sample(p);
  if (accessible) {
    stampL = dark
        ? (stampL < paperInkAccessibleDarkStampMinL
              ? paperInkAccessibleDarkStampMinL
              : stampL)
        : (stampL > paperInkAccessibleLightStampMaxL
              ? paperInkAccessibleLightStampMaxL
              : stampL);
  }
  final stampCap = dark
      ? paperInkDarkStampCapMilli
      : paperInkLightStampCapMilli;

  // P15–P18: the operator wash.
  final washOffsetPick = p.pickWeighted(paperInkWashOffsetWeights);
  final washJitter = p.nextJitterTenths(100);
  final washCMilli = dark ? p.nextIntIn(42, 50) : p.nextIntIn(45, 75);
  final washDL = dark ? p.nextIntIn(25, 45) : p.nextIntIn(45, 75);

  // P19–P24: slips.
  final digitDL = dark ? p.nextIntIn(35, 60) : p.nextIntIn(12, 28);
  final cardL = p.nextIntIn(935, 960);
  final cardC = p.nextIntIn(18, 30);
  final cardH = p.nextIntIn(800, 900);
  final fnDL = p.nextIntIn(35, 55);
  final fnC = dark ? p.nextIntIn(15, 25) : p.nextIntIn(12, 22);

  // P25–P27: rule ink.
  final ruleRange = paperInkRules[sheet.index];
  final ruleL = ruleRange.l.sample(p);
  final ruleC = ruleRange.c.sample(p);
  final ruleHueDraw = ruleRange.h.sample(p);
  final ruleH = sheet == PaperSheet.inkPaper ? paperH : ruleHueDraw;
  final rule = oklchToArgb(ruleL / 1000, ruleC / 1000, ruleH / 10);

  // P28–P29: the display panel.
  final panelA = p.nextIntIn(dark ? 30 : 975, dark ? 50 : 995);
  final panelB = p.nextIntIn(0, 22);
  final int panel;
  if (dark) {
    panel = oklchToArgb(
      (paperL + panelA) / 1000,
      paperC * 0.9 / 1000,
      paperH / 10,
    );
  } else if (sheet == PaperSheet.graph) {
    final l = paperL + 8 + (panelA - 975) * 7 ~/ 20;
    panel = oklchToArgb((l > 995 ? 995 : l) / 1000, paperC / 2000, paperH / 10);
  } else if (kraft) {
    panel = oklchToArgb(
      (950 + (panelA - 975)) / 1000,
      (15 + panelB * 10 ~/ 22) / 1000,
      85,
    );
  } else {
    panel = oklchToArgb(
      panelA / 1000,
      (3 + panelB * 7 ~/ 22) / 1000,
      paperH / 10,
    );
  }

  // Faces (lightness × 1000).
  final int digitL;
  final Lch digitFace;
  if (kraft) {
    digitL = cardL;
    digitFace = (l: cardL / 1000, c: cardC / 1000, h: cardH / 10);
  } else if (dark) {
    var l = paperL + digitDL;
    if (accessible && l > 340) l = 340;
    digitL = l;
    digitFace = (l: l / 1000, c: paperC * 0.8 / 1000, h: paperH / 10);
  } else {
    final l = paperL + digitDL;
    digitL = l > 992 ? 992 : l;
    digitFace = (l: digitL / 1000, c: paperC * 0.6 / 1000, h: paperH / 10);
  }
  final Lch fnFace;
  {
    var l = dark ? digitL + fnDL : digitL - fnDL;
    if (dark && accessible && l > 380) l = 380;
    // Kraft: a darker cream card (the brown rule hue at low chroma reads
    // pinkish grey); elsewhere the rule hue.
    fnFace = (l: l / 1000, c: fnC / 1000, h: (kraft ? cardH : ruleH) / 10);
  }

  // The style stream (independent of the palette stream) fixes the hatch
  // opacity the operator face must carry.
  final st = Rng.stream(seed, RngTag.style);
  final keyStyle = def.keyStyle.copyWith(
    kind: pickWeightedValue(st, def.styles),
    outlineWidthCdp: paperInkOutlineWidthCdp.sampleStep(st, 25),
    edgeShadePermille: paperInkHatchPermille.sampleStep(st, 50),
    shadowOffsetCdp: 0,
    stateLayerPermille: 0,
  );

  final Lch opFace;
  {
    var offset = paperInkWashOffsets[washOffsetPick];
    var washH = _wrap(stampH + offset + washJitter);
    if (dark && paperInkDarkOliveHues.contains(washH)) {
      offset = -offset;
      washH = _wrap(stampH + offset + washJitter);
    }
    if (dark) washH = paperDarkWashHue(washH);
    var l = dark ? digitL + washDL : digitL - washDL;
    if (dark && accessible && l > 380) l = 380;
    double chroma(int lMilli) =>
        _capped(0.9 * maxChroma(lMilli / 1000, washH / 10), washCMilli);
    // Light sheets: the hatch (the operator cue) must show on the wash —
    // lighten the face until it does.
    if (!dark) {
      while (l < 970 &&
          paperHatchContrast(
                KeyColors(
                  face: oklchToArgb(l / 1000, chroma(l), washH / 10),
                  label: ink,
                  edge: ink,
                ),
                keyStyle.edgeShadePermille,
              ) <
              paperHatchRatio + 0.05) {
        l += 10;
      }
    }
    opFace = (l: l / 1000, c: chroma(l), h: washH / 10);
  }

  final stampChroma = _capped(
    stampRel / 1000 * maxChroma(stampL / 1000, stampH / 10),
    stampCap,
  );
  var eqFace = (l: stampL / 1000, c: stampChroma, h: stampH / 10);

  // Keys: ink labels (repairPair keeps the ink when it passes); the stamp
  // label knocked out to the slip (light) or the sheet (dark).
  final paperLch = argbToOklch(paper);
  final eqLabelStart = dark ? paperLch : digitFace;
  KeyColors key(Lch face, Lch start) {
    var pair = repairPair(face, start, policy: policy);
    if (bile.recheckFinal) {
      final f = argbToOklch(pair.face);
      final hue = (f.h * 10).round() % 3600;
      final rotated = bile.apply(hue, f.l, f.c);
      if (rotated != hue) {
        pair = repairPair(
          (l: f.l, c: f.c, h: rotated / 10),
          start,
          policy: policy,
        );
      }
    }
    return KeyColors(face: pair.face, label: pair.label, edge: ink);
  }

  final digit = key(digitFace, inkLch);
  final function = key(fnFace, inkLch);
  final operator = key(opFace, inkLch);
  var equals = key(eqFace, eqLabelStart);
  if (minCvdDeltaE(equals.face, operator.face) < 0.065) {
    // `=` must stand apart from the operators (CVD included): move the
    // stamp 0.10 further from the slips, inside the lock clamps.
    var l = eqFace.l + (dark ? 0.10 : -0.10);
    if (accessible) {
      l = dark
          ? (l < paperInkAccessibleDarkStampMinL / 1000
                ? paperInkAccessibleDarkStampMinL / 1000
                : l)
          : (l > paperInkAccessibleLightStampMaxL / 1000
                ? paperInkAccessibleLightStampMaxL / 1000
                : l);
    }
    eqFace = (l: clamp01(l), c: eqFace.c, h: eqFace.h);
    equals = key(eqFace, eqLabelStart);
  }

  // The sheet.
  final background = _background(
    Rng.stream(seed, RngTag.background),
    sheet,
    paper: paper,
    rule: rule,
  );
  final bgs = paperInkSceneSamples(background)!;

  // Outlines: the ink, re-solved to 3:1 on every sheet sample.
  final edge = solveOnAll(ink, bgs, ratioLarge) ?? blackOrWhite(paper);
  KeyColors edged(KeyColors k) => k.copyWith(edge: edge);

  // Display texts on the panel and its grain / rule composites.
  final backdrops = paperPanelSamples(
    panel,
    background,
    accessible: accessible,
  );
  int onAll(int start, List<int> on, double target, int fallback) =>
      solveOnAll(start, on, target) ?? fallback;
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final displayText = onAll(
    ink,
    backdrops,
    lim.displayRatio,
    blackOrWhite(panel),
  );
  final previewText = onAll(
    oklchToArgb(dark ? 0.78 : 0.42, inkLch.c, inkLch.h),
    backdrops,
    previewTarget,
    blackOrWhite(panel),
  );
  // The red pen is solved 0.05 past its floor: it lands right on it, and
  // the theme transition's OKLab round trip (at its rubber-band frames)
  // could otherwise take it a hair under on a grain fleck.
  final error = onAll(
    oklchToArgb(dark ? 0.76 : 0.50, dark ? 0.12 : 0.17, 27),
    backdrops,
    lim.displayRatio + paperTextMargin,
    blackOrWhite(panel),
  );
  final caretL = dark ? 0.80 : 0.46;
  final caretC = 0.8 * maxChroma(caretL, stampH / 10);
  final caret = onAll(
    oklchToArgb(caretL, caretC < 0.18 ? caretC : 0.18, stampH / 10),
    backdrops,
    lim.caretRatio,
    displayText,
  );
  final focus = onAll(edge, bgs, lim.focusRingRatio, blackOrWhite(paper));

  var palette = Palette(
    background: paper,
    surface: panel,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: focus,
    accent: equals.face,
    digit: edged(digit),
    operator: edged(operator),
    equals: edged(equals),
    function: edged(function),
    shadow: edge | 0xFF000000,
    highlight: withAlpha(edge, paperWashRimMaxAlpha),
    seedColor: equals.face,
  );
  palette = palette.copyWith(
    highlight: fitPaperWash(palette, palette.highlight, lim),
  );

  // Motion, shape, type, name.
  final motion = def.motionRanges.vary(
    def.motion,
    Rng.stream(seed, RngTag.motion),
  );
  final s = Rng.stream(seed, RngTag.shape);
  final keyShape = KeyShapeSpec(
    kind: pickWeightedValue(s, def.shapes),
    cornerPermille: def.cornerPermille.sampleStep(s, 10),
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  // The name accent is the stamp (the family's one chromatic ink), not the
  // operator face `generateThemeName` documents: Paper's operator faces
  // are faint washes, often too pale to name a colour.
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: equals.face,
    family: ThemeFamily.paperInk,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.paperInk,
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

/// Serif type: a light editorial display cut (the display face floors it
/// at 350, 400 for small text and under the Accessible lock), key labels
/// 400–500 and operators 200–300 heavier (≤ 800, the font's heaviest).
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
    operatorWeight: opWeight > 800 ? 800 : opWeight,
  );
}

/// The sheet: layout, pitch, line alpha and grain (four draws, always).
BackgroundSpec _background(
  Rng b,
  PaperSheet sheet, {
  required int paper,
  required int rule,
}) {
  final layout = b.pickWeighted(paperInkLayoutWeights[sheet.index]);
  final pitch = paperInkPitches[layout][b.nextInt(3)];
  final cls = switch (sheet) {
    PaperSheet.inkPaper => 1,
    PaperSheet.blackboard => 2,
    _ => 0,
  };
  final alpha = paperInkLineAlphas[layout][cls].sample(b);
  final grain = paperInkGrain[sheet.index].sample(b);
  return BackgroundSpec(
    kind: BackgroundKind.paperSheet,
    colors: List.unmodifiable([paper | 0xFF000000, rule | 0xFF000000]),
    angleTenths: _clampInt(grain, 0, 1000),
    pattern: paperInkLayouts[layout],
    patternScaleCdp: pitch,
    patternOpacityPermille: layout == 0 ? 0 : alpha,
  );
}
