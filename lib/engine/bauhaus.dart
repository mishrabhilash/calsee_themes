/// The Bauhaus family (id 15): the Weimar / Dessau poster and the workshop
/// toy — only red, yellow and blue plus black and cream (sometimes ochre),
/// only primitives (block, disc, quarter-disc, half-disc, triangle, bar),
/// flat opaque colour, no shadow, gradient, outline, texture or glow. Pure
/// Dart: part of the generator, so every constant here is part of the
/// family's engine-v3 definition and must not change once it ships.
///
/// - **Silhouettes carry meaning** (the recorded non-colour cue,
///   [OperatorCue.shape]): digit and function keys are blocks, operators
///   discs, `=` a big disc, a quarter-disc fan or a triangle — or, one
///   theme in eight, digits are discs, operators blocks and `=` a triangle
///   (Kandinsky's circle / square / triangle; [BauhausComposition]). `KeyShapeSpec.kind` is the digit silhouette,
///   `operatorKind` the operator one and `operatorM3eShape` the `=` figure
///   (read only by the Bauhaus renderer and [validateBauhaus]; every other
///   reader looks at it only under `KeyShapeKind.m3eMorph`).
/// - **Primaries at fixed lightness**: red (25–33°; 25–28° crimson at the
///   Accessible lock's darker lightness), a warm yellow (88–92°, always
///   light: never a disliked dark yellow) and ultramarine blue
///   (260–268°); operator and `=` are always two different primaries, and
///   function keys are ink, cream, graphite or the third primary.
/// - **Five variants** ([BauhausVariant]): parchment `paper`, `grid` (an
///   ink field behind the keypad so the key gaps read as thick black
///   rules), warm `ochre` stock, `night` (graphite on warm black) and
///   `negative` (cream blocks on warm black).
/// - **Display**: an opaque sheet (`surface`) with a thick rule (`shadow`:
///   ink — the field's ink on grid —, cream on the night sheet, red on the
///   negative's cream sheet) and
///   a quarter-disc in the `=` primary (`highlight`); every display text
///   sits on the sheet only.
/// - **Scene** ([BackgroundKind.bauhausComposition]): the ground, the grid
///   field behind the keypad, a small masthead (bar, square, triangle,
///   disc) in the free middle of the toolbar and, where the screen has
///   margins beside the calculator column, a poster composition in them.
///   `BackgroundSpec.colors` = `[ground, field, blue, red, triangle,
///   sceneInk]`; `angleTenths` ∈ {0, 900, 1800, 2700} mirrors / flips it.
/// - **Press**: a concentric figure–ground inversion (the renderer keeps a
///   ring of the resting face and swaps face and label inside it in the
///   first frame), uniform scale 0.96, no depth, no tint layer.
///
/// Every draw comes from the generator's named sub-streams (`palette` and
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), so a theme is a pure function of (seed, engineVersion,
/// accessible). The shape, style, type and motion streams never read the
/// palette stream, so a retry or the Accessible lock changes colours only.
library;

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

// ------------------------------------------------------------- constants --

/// The five sub-variants. Never stored: [bauhausVariantOf] derives it.
enum BauhausVariant {
  /// Parchment ground, cream digit blocks, ink function blocks.
  paper,

  /// Parchment ground with an ink field behind the keypad: cream digit
  /// blocks set into a black grid, function keys in the third primary.
  grid,

  /// Warm ochre stock, cream digit blocks, ink function blocks.
  ochre,

  /// Warm black, graphite digits, cream function keys, a graphite sheet.
  night,

  /// Warm black, cream digits, graphite function keys, a cream sheet.
  negative,
}

/// Light themes: `[paper, grid, ochre]` weights.
const List<int> bauhausLightVariantWeights = [5, 4, 2];

/// Dark themes: `[night, negative]` weights (the negative is the stronger
/// poster, and night alone sits close to a stock dark calculator).
const List<int> bauhausDarkVariantWeights = [2, 3];

/// The three primaries.
enum BauhausPrimary { red, yellow, blue }

/// How one primary is drawn: hue, lightness (standard and under the
/// Accessible lock) and chroma relative to the gamut edge, capped.
final class BauhausPrimaryRanges {
  const BauhausPrimaryRanges({
    required this.hueTenths,
    required this.lMilli,
    required this.accessibleLMilli,
    required this.relChroma,
    required this.capMilli,
    this.accessibleHueTenths,
  });

  /// OKLCH hue, tenths of a degree.
  final IntRange hueTenths;

  /// The hue under the Accessible lock (null: [hueTenths]).
  final IntRange? accessibleHueTenths;

  /// Lightness × 1000.
  final IntRange lMilli;

  /// Lightness × 1000 under the Accessible lock.
  final IntRange accessibleLMilli;

  /// Chroma as a fraction of `maxChroma(L, h)` × 1000.
  final IntRange relChroma;

  /// Chroma ceiling × 1000.
  final int capMilli;
}

/// Bauhaus red (cream labels 4.5:1, 7:1 at the accessible lightness). At
/// the Accessible lock's darker lightness the orange end (29–33°) reads as
/// brick next to ochre, so the lock draws the crimson end only.
const BauhausPrimaryRanges bauhausRed = BauhausPrimaryRanges(
  hueTenths: IntRange(250, 330),
  accessibleHueTenths: IntRange(250, 280),
  lMilli: IntRange(500, 555),
  accessibleLMilli: IntRange(430, 460),
  relChroma: IntRange(880, 970),
  capMilli: 210,
);

/// Bauhaus yellow: always light (ink labels ≥ 10:1), never a dark yellow,
/// and warm (the cool end past 92° reads as a lemon highlighter next to
/// parchment and red).
const BauhausPrimaryRanges bauhausYellow = BauhausPrimaryRanges(
  hueTenths: IntRange(880, 920),
  lMilli: IntRange(840, 870),
  accessibleLMilli: IntRange(840, 870),
  relChroma: IntRange(920, 1000),
  capMilli: 175,
);

/// Yellow when it is an operator or `=` face on parchment: at most L 0.85,
/// over a parchment of at least L 0.905
/// ([bauhausParchmentUnderYellowLMilli]), so the disc stays ≥ 1.10:1 off
/// the ground ([bauhausKeyVisibility]) — hue alone would carry it, and
/// tritan vision loses most of that.
const BauhausPrimaryRanges bauhausYellowOnParchment = BauhausPrimaryRanges(
  hueTenths: IntRange(880, 920),
  lMilli: IntRange(840, 850),
  accessibleLMilli: IntRange(840, 850),
  relChroma: IntRange(920, 1000),
  capMilli: 175,
);

/// Ultramarine for keys in the light variants (cream labels ≥ 6:1).
const BauhausPrimaryRanges bauhausBlue = BauhausPrimaryRanges(
  hueTenths: IntRange(2600, 2680),
  lMilli: IntRange(400, 470),
  accessibleLMilli: IntRange(380, 430),
  relChroma: IntRange(900, 1000),
  capMilli: 160,
);

/// The lighter ultramarine of the dark variants' scene (never a key: blue
/// on warm black is only ≈ 2.4:1). Its cap lets it reach ultramarine
/// chroma at this lightness instead of a cornflower.
const BauhausPrimaryRanges bauhausSceneBlue = BauhausPrimaryRanges(
  hueTenths: IntRange(2600, 2680),
  lMilli: IntRange(520, 580),
  accessibleLMilli: IntRange(520, 580),
  relChroma: IntRange(850, 950),
  capMilli: 185,
);

/// Neutral hue (warm), tenths: every neutral but the ochre ground uses it.
const IntRange bauhausNeutralHueTenths = IntRange(700, 950);

/// Ink (near-black) lightness and chroma × 1000.
const IntRange bauhausInkLMilli = IntRange(170, 200);
const IntRange bauhausInkChromaMilli = IntRange(0, 8);

/// Cream lightness and chroma × 1000.
const IntRange bauhausCreamLMilli = IntRange(955, 975);
const IntRange bauhausCreamChromaMilli = IntRange(12, 22);

/// Parchment ground (paper and grid).
const IntRange bauhausParchmentLMilli = IntRange(885, 915);
const IntRange bauhausParchmentChromaMilli = IntRange(16, 30);

/// Parchment lightness under yellow operator or `=` discs (paper).
const IntRange bauhausParchmentUnderYellowLMilli = IntRange(905, 915);

/// Ochre stock: lightness, chroma and its own hue — the tan of the stock
/// itself (the warmer end reads as apricot, the greener and stronger end
/// as mustard).
const IntRange bauhausOchreLMilli = IntRange(790, 850);
const IntRange bauhausOchreChromaMilli = IntRange(55, 80);
const IntRange bauhausOchreHueTenths = IntRange(720, 800);

/// Warm black ground (night and negative).
const IntRange bauhausBlackLMilli = IntRange(150, 190);
const IntRange bauhausBlackChromaMilli = IntRange(0, 10);

/// The grid variant's ink field behind the keypad.
const IntRange bauhausFieldLMilli = IntRange(150, 190);
const IntRange bauhausFieldChromaMilli = IntRange(0, 6);

/// Light display sheet (paper, grid).
const IntRange bauhausSheetLMilli = IntRange(985, 1000);
const IntRange bauhausSheetChromaMilli = IntRange(0, 6);

/// `=` figures for block digits: big disc, quarter-disc fan, triangle.
const List<Weighted<M3eShape>> bauhausBlockEqualsFigures = [
  Weighted(M3eShape.circle, 4),
  Weighted(M3eShape.fan, 2),
  Weighted(M3eShape.triangle, 2),
];

/// One theme in three (style stream) leaves the function keys' corner
/// accent off.
const int bauhausAccentOnNumerator = 2;
const int bauhausAccentOnDenominator = 3;

/// A primary assignment: operator, `=` and (grid) the function face.
typedef BauhausAssignment = ({
  BauhausPrimary op,
  BauhausPrimary eq,
  BauhausPrimary? fn,
});

/// Paper: blue discs and a red `=` most often.
const List<Weighted<BauhausAssignment>> bauhausPaperAssignments = [
  Weighted((op: BauhausPrimary.blue, eq: BauhausPrimary.red, fn: null), 5),
  Weighted((op: BauhausPrimary.red, eq: BauhausPrimary.blue, fn: null), 1),
  Weighted((op: BauhausPrimary.yellow, eq: BauhausPrimary.red, fn: null), 2),
  Weighted((op: BauhausPrimary.yellow, eq: BauhausPrimary.blue, fn: null), 1),
  Weighted((op: BauhausPrimary.red, eq: BauhausPrimary.yellow, fn: null), 1),
];

/// Grid: function keys take the third primary.
const List<Weighted<BauhausAssignment>> bauhausGridAssignments = [
  Weighted((
    op: BauhausPrimary.blue,
    eq: BauhausPrimary.red,
    fn: BauhausPrimary.yellow,
  ), 4),
  Weighted((
    op: BauhausPrimary.red,
    eq: BauhausPrimary.blue,
    fn: BauhausPrimary.yellow,
  ), 1),
  Weighted((
    op: BauhausPrimary.blue,
    eq: BauhausPrimary.yellow,
    fn: BauhausPrimary.red,
  ), 1),
];

/// Ochre: no yellow keys (yellow on ochre is hue-adjacent and faint).
const List<Weighted<BauhausAssignment>> bauhausOchreAssignments = [
  Weighted((op: BauhausPrimary.blue, eq: BauhausPrimary.red, fn: null), 3),
  Weighted((op: BauhausPrimary.red, eq: BauhausPrimary.blue, fn: null), 2),
];

/// Night and negative: no blue keys (blue on warm black is too dark). Red
/// operator discs most often — yellow operators on warm black sit close to
/// NeoPOP's amber-on-black and to a stock dark calculator.
const List<Weighted<BauhausAssignment>> bauhausDarkAssignments = [
  Weighted((op: BauhausPrimary.red, eq: BauhausPrimary.yellow, fn: null), 4),
  Weighted((op: BauhausPrimary.yellow, eq: BauhausPrimary.red, fn: null), 2),
];

/// The four key compositions (shape stream; see [bauhausCompositionOf]).
enum BauhausComposition {
  /// Block digits and function keys, disc operators, a big disc `=`.
  blockDisc,

  /// Block digits, disc operators, a quarter-disc fan `=`.
  blockFan,

  /// Disc digits, block operators and function keys, a triangle `=`
  /// (Kandinsky's circle / square / triangle).
  discBlock,

  /// Block digits, disc operators, a triangle `=`.
  blockTriangle,
}

/// Light ranges (the paper variant; grid and ochre are in the builder).
/// Only the definition-sanity test reads these: the builder draws from the
/// per-variant constants above, which these mirror.
const RoleRanges bauhausLightRanges = RoleRanges(
  background: RoleRange(IntRange(885, 915), ChromaRange.abs(16, 30)),
  surfaceOffsetMilli: IntRange(70, 115),
  surfaceChroma: ChromaRange.abs(0, 6),
  digit: RoleRange(IntRange(975, 995), ChromaRange.abs(0, 8)),
  digitDuotoneChroma: ChromaRange.abs(0, 8),
  function: RoleRange(IntRange(180, 210), ChromaRange.abs(0, 8)),
  operator: RoleRange(IntRange(400, 880), ChromaRange.rel(880, 1000, 210)),
  operatorMonochromeL: IntRange(400, 880),
  equals: RoleRange(IntRange(400, 880), ChromaRange.rel(880, 1000, 210)),
  labelStartLMilli: 185,
  labelMaxChromaMilli: 22,
  accentChroma: ChromaRange.rel(880, 1000, 210),
  minDigitAboveBackgroundMilli: 60,
);

/// Dark ranges (the night variant; negative is in the builder).
const RoleRanges bauhausDarkRanges = RoleRanges(
  background: RoleRange(IntRange(150, 190), ChromaRange.abs(0, 10)),
  surfaceOffsetMilli: IntRange(95, 120),
  surfaceChroma: ChromaRange.abs(0, 10),
  digit: RoleRange(IntRange(250, 320), ChromaRange.abs(0, 10)),
  digitDuotoneChroma: ChromaRange.abs(0, 10),
  function: RoleRange(IntRange(920, 950), ChromaRange.abs(14, 24)),
  operator: RoleRange(IntRange(500, 880), ChromaRange.rel(880, 1000, 210)),
  operatorMonochromeL: IntRange(500, 880),
  equals: RoleRange(IntRange(500, 880), ChromaRange.rel(880, 1000, 210)),
  labelStartLMilli: 965,
  labelMaxChromaMilli: 22,
  accentChroma: ChromaRange.rel(880, 1000, 210),
  minDigitAboveBackgroundMilli: 100,
);

/// Bauhaus: flat primaries, primitive silhouettes, a figure–ground
/// inversion on press (`hardPress` in, `effectsDefault` out seeded
/// × {0.9, 1, 1.1}, ζ 1, scale 0.96, no depth), a pop entry 0.90 → 1 on
/// `effectsDefault`, Jost type and the `wood` pack (the workshop's wooden
/// building toys). The palette is built by [buildBauhausCandidate].
const FamilyDefinition bauhausDefinition = FamilyDefinition(
  family: ThemeFamily.bauhaus,
  brightnessWeights: [1, 4],
  // Metadata: red / yellow / blue is a triad.
  schemes: [Weighted(HarmonyScheme.triadic, 1)],
  shapes: [
    Weighted(KeyShapeKind.roundedRect, 7),
    Weighted(KeyShapeKind.circle, 1),
  ],
  cornerPermille: IntRange(0, 40),
  styles: [Weighted(KeyStyleKind.flat, 1)],
  keyStyle: KeyStyleSpec(kind: KeyStyleKind.flat, stateLayerPermille: 0),
  displayFonts: [Weighted(FontIds.jost, 1)],
  keyFonts: [Weighted(FontIds.jost, 1)],
  displayWeight: IntRange(500, 600),
  keyWeight: IntRange(450, 550),
  operatorWeightBonus: IntRange(100, 200),
  backgrounds: [Weighted(BackgroundKind.bauhausComposition, 1)],
  sound: SoundPackId.wood,
  dark: bauhausDarkRanges,
  light: bauhausLightRanges,
  motion: MotionSpec(
    // Truthful metadata: the press is a figure–ground inversion.
    verb: PressVerb.invert,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.hardPress,
    release: SpringTokens.effectsDefault,
    scalePermille: 960,
    entry: EntryStyle.pop,
    entryScalePermille: 900,
    entrySpring: SpringTokens.effectsDefault,
    impact: ImpactStyle.rigid,
  ),
  motionRanges: MotionRanges(),
  nonColourOperatorCue: OperatorCue.shape,
  bile: BileRule.v2,
);

// --------------------------------------------------------------- palette --

/// Every value the palette stream draws for one Bauhaus theme, in draw
/// order (see [drawBauhausPalette]); [assembleBauhausPalette] turns it into
/// a [Palette] and the scene colours without further draws. Public so the
/// hero tool and the tests can build palettes from chosen values.
final class BauhausDraw {
  const BauhausDraw({
    required this.variant,
    required this.assignment,
    required this.neutralHue,
    required this.red,
    required this.yellow,
    required this.blue,
    required this.ink,
    required this.cream,
    required this.ground,
    required this.field,
    required this.digit,
    required this.function,
    required this.panel,
  });

  /// The sub-variant.
  final BauhausVariant variant;

  /// Operator, `=` and (grid) function primaries.
  final BauhausAssignment assignment;

  /// The warm neutral hue, tenths.
  final int neutralHue;

  /// The three primaries (blue is the scene blue in the dark variants).
  final Lch red;
  final Lch yellow;
  final Lch blue;

  /// Near-black and cream.
  final Lch ink;
  final Lch cream;

  /// The ground (`palette.background`).
  final Lch ground;

  /// The grid variant's keypad field (null: none).
  final Lch? field;

  /// The digit face.
  final Lch digit;

  /// A neutral function face (null: the function keys take
  /// `BauhausAssignment.fn`).
  final Lch? function;

  /// The display sheet.
  final Lch panel;

  /// Whether this is a dark theme.
  bool get dark =>
      variant == BauhausVariant.night || variant == BauhausVariant.negative;

  /// The colour of [primary].
  Lch primary(BauhausPrimary primary) => switch (primary) {
    BauhausPrimary.red => red,
    BauhausPrimary.yellow => yellow,
    BauhausPrimary.blue => blue,
  };
}

/// One primary from [p]: lightness, hue, then relative chroma.
Lch _drawPrimary(Rng p, BauhausPrimaryRanges r, {required bool accessible}) {
  final l = (accessible ? r.accessibleLMilli : r.lMilli).sample(p) / 1000;
  final hue =
      ((accessible ? r.accessibleHueTenths : null) ?? r.hueTenths).sample(p) /
      10;
  final rel = r.relChroma.sample(p) / 1000;
  final c = rel * maxChroma(l, hue);
  final cap = r.capMilli / 1000;
  return (l: l, c: c < cap ? c : cap, h: hue);
}

Lch _neutral(Rng p, IntRange l, IntRange c, int hueTenths) =>
    (l: l.sample(p) / 1000, c: c.sample(p) / 1000, h: hueTenths / 10);

/// Draws every palette value of one theme from the palette stream [p] in
/// the family's fixed order: brightness, variant, assignment, neutral hue,
/// red / yellow / blue, ink, cream, ground, field (grid), digit face,
/// function face (neutral ones), panel.
BauhausDraw drawBauhausPalette(
  Rng p,
  FamilyDefinition def, {
  required bool accessible,
}) {
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final variant = dark
      ? (p.pickWeighted(bauhausDarkVariantWeights) == 0
            ? BauhausVariant.night
            : BauhausVariant.negative)
      : BauhausVariant.values[p.pickWeighted(bauhausLightVariantWeights)];
  final assignment = pickWeightedValue(p, switch (variant) {
    BauhausVariant.paper => bauhausPaperAssignments,
    BauhausVariant.grid => bauhausGridAssignments,
    BauhausVariant.ochre => bauhausOchreAssignments,
    BauhausVariant.night || BauhausVariant.negative => bauhausDarkAssignments,
  });
  final hue = bauhausNeutralHueTenths.sample(p);
  // Yellow discs on parchment get a darker yellow over a lighter
  // parchment (same draws, narrower ranges).
  final yellowOnParchment =
      variant == BauhausVariant.paper &&
      (assignment.op == BauhausPrimary.yellow ||
          assignment.eq == BauhausPrimary.yellow);
  final red = _drawPrimary(p, bauhausRed, accessible: accessible);
  final yellow = _drawPrimary(
    p,
    yellowOnParchment ? bauhausYellowOnParchment : bauhausYellow,
    accessible: accessible,
  );
  final blue = _drawPrimary(
    p,
    dark ? bauhausSceneBlue : bauhausBlue,
    accessible: accessible,
  );
  final ink = _neutral(p, bauhausInkLMilli, bauhausInkChromaMilli, hue);
  final cream = _neutral(p, bauhausCreamLMilli, bauhausCreamChromaMilli, hue);

  final Lch ground;
  switch (variant) {
    case BauhausVariant.paper:
    case BauhausVariant.grid:
      ground = _neutral(
        p,
        yellowOnParchment
            ? bauhausParchmentUnderYellowLMilli
            : bauhausParchmentLMilli,
        bauhausParchmentChromaMilli,
        hue,
      );
    case BauhausVariant.ochre:
      final l = bauhausOchreLMilli.sample(p);
      final c = bauhausOchreChromaMilli.sample(p);
      // Ochre is always light (L ≥ 0.79), so the bile rule never rotates
      // it; applied for the record.
      final h = def.bile.apply(
        bauhausOchreHueTenths.sample(p),
        l / 1000,
        c / 1000,
      );
      ground = (l: l / 1000, c: c / 1000, h: h / 10);
    case BauhausVariant.night:
    case BauhausVariant.negative:
      ground = _neutral(p, bauhausBlackLMilli, bauhausBlackChromaMilli, hue);
  }
  final field = variant == BauhausVariant.grid
      ? _neutral(p, bauhausFieldLMilli, bauhausFieldChromaMilli, hue)
      : null;

  final groundL = (ground.l * 1000).round();
  final digit = switch (variant) {
    BauhausVariant.paper => _neutral(
      p,
      const IntRange(975, 995),
      const IntRange(0, 8),
      hue,
    ),
    BauhausVariant.grid => _neutral(
      p,
      const IntRange(955, 985),
      const IntRange(6, 16),
      hue,
    ),
    BauhausVariant.ochre => _neutral(
      p,
      const IntRange(950, 980),
      const IntRange(10, 22),
      hue,
    ),
    BauhausVariant.night => _neutral(
      p,
      IntRange(groundL + 100, groundL + 130),
      const IntRange(0, 10),
      hue,
    ),
    BauhausVariant.negative => _neutral(
      p,
      const IntRange(940, 970),
      const IntRange(12, 22),
      hue,
    ),
  };
  final function = switch (variant) {
    BauhausVariant.grid => null,
    BauhausVariant.paper || BauhausVariant.ochre => _neutral(
      p,
      const IntRange(180, 210),
      const IntRange(0, 8),
      hue,
    ),
    BauhausVariant.night => _neutral(
      p,
      const IntRange(920, 950),
      const IntRange(14, 24),
      hue,
    ),
    BauhausVariant.negative => _neutral(
      p,
      const IntRange(300, 340),
      const IntRange(0, 10),
      hue,
    ),
  };
  final panel = switch (variant) {
    BauhausVariant.paper || BauhausVariant.grid => _neutral(
      p,
      bauhausSheetLMilli,
      bauhausSheetChromaMilli,
      hue,
    ),
    BauhausVariant.ochre => _neutral(
      p,
      const IntRange(955, 975),
      const IntRange(8, 16),
      hue,
    ),
    BauhausVariant.night => _neutral(
      p,
      IntRange(groundL + 95, groundL + 120),
      const IntRange(0, 10),
      hue,
    ),
    BauhausVariant.negative => _neutral(
      p,
      const IntRange(930, 960),
      const IntRange(10, 20),
      hue,
    ),
  };
  return BauhausDraw(
    variant: variant,
    assignment: assignment,
    neutralHue: hue,
    red: red,
    yellow: yellow,
    blue: blue,
    ink: ink,
    cream: cream,
    ground: ground,
    field: field,
    digit: digit,
    function: function,
    panel: panel,
  );
}

int _argb(Lch c) => oklchToArgb(c.l, c.c, c.h) | 0xFF000000;

/// The scene colours of [d] (`BackgroundSpec.colors`): ground, keypad field
/// (= ground without one), blue, red, the triangle colour (yellow; cream
/// on ochre, where yellow would vanish) and the scene ink (bars,
/// quarter-disc).
List<int> bauhausSceneColors(BauhausDraw d) {
  final ground = _argb(d.ground);
  final field = d.field;
  final sceneInk = switch (d.variant) {
    BauhausVariant.paper || BauhausVariant.ochre => _argb(d.ink),
    BauhausVariant.grid => _argb(field!),
    BauhausVariant.night || BauhausVariant.negative => _argb(d.cream),
  };
  return List.unmodifiable([
    ground,
    if (field == null) ground else _argb(field),
    _argb(d.blue),
    _argb(d.red),
    if (d.variant == BauhausVariant.ochre) _argb(d.cream) else _argb(d.yellow),
    sceneInk,
  ]);
}

/// The display sheet's corner accent: the `=` face when it stands out from
/// the sheet (min ΔEOK over normal + CVD ≥ [bauhausDisplayAccentDeltaE]),
/// else the operator face, else the rule colour [bar].
int bauhausDisplayAccent(int equals, int operator, int bar, int surface) {
  for (final c in [equals, operator]) {
    if (minCvdDeltaE(c | 0xFF000000, surface) >= bauhausDisplayAccentDeltaE) {
      return c | 0xFF000000;
    }
  }
  return bar | 0xFF000000;
}

/// The display accent's floor against the sheet.
const double bauhausDisplayAccentDeltaE = 0.07;

/// The function keys' corner accent colour of [d] (before the style
/// stream's on/off). On grid, where the function blocks are a primary set
/// into the ink field, the accent is the `=` primary (an ink corner there
/// read as one oddly rounded corner, not an accent).
int bauhausFunctionAccent(BauhausDraw d) => switch (d.variant) {
  BauhausVariant.paper =>
    d.assignment.op != BauhausPrimary.yellow &&
            d.assignment.eq != BauhausPrimary.yellow
        ? _argb(d.yellow)
        : _argb(d.red),
  BauhausVariant.grid => _argb(d.primary(d.assignment.eq)),
  BauhausVariant.ochre || BauhausVariant.negative => _argb(d.yellow),
  BauhausVariant.night => _argb(d.red),
};

/// Builds the palette of [d]: labels solved on their faces (ink on light
/// faces, cream on dark ones, kept when they already pass), display texts
/// on the sheet only, the focus ring on the scene samples [bgs]
/// (`[ground]` or `[ground, field]`). [accentOn] (style stream) decides
/// `function.edge`: the accent colour, or fully transparent for none.
Palette assembleBauhausPalette(
  BauhausDraw d, {
  required bool accentOn,
  required bool accessible,
  required List<int> bgs,
}) {
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final ink = _argb(d.ink);
  final cream = _argb(d.cream);
  final ground = _argb(d.ground);

  KeyColors key(Lch face, {int? edge}) {
    final start = face.l >= 0.62 ? d.ink : d.cream;
    final pair = repairPair(face, start, policy: policy);
    return KeyColors(
      face: pair.face,
      label: pair.label,
      edge: edge ?? pair.face,
    );
  }

  final digit = key(d.digit);
  final operator = key(d.primary(d.assignment.op));
  final equals = key(d.primary(d.assignment.eq));
  final fnPrimary = d.assignment.fn;
  final fnFace = fnPrimary == null ? d.function! : d.primary(fnPrimary);
  final function = key(
    fnFace,
    edge: accentOn ? bauhausFunctionAccent(d) : 0x00000000,
  );

  final panel = _argb(d.panel);
  final lightPanel = d.panel.l >= 0.6;
  // The rule hangs past the sheet into the ground: ink on the light
  // grounds, cream on the night sheet, and red on the negative's cream
  // sheet (ink would vanish into the black ground beside it).
  final bar = switch (d.variant) {
    BauhausVariant.grid => _argb(d.field!),
    BauhausVariant.night => cream,
    BauhausVariant.negative => _argb(d.red),
    BauhausVariant.paper || BauhausVariant.ochre => ink,
  };
  int onPanel(int start, double target, int fallback) =>
      solveOnAll(start, [panel], target) ?? fallback;
  final displayText = onPanel(
    lightPanel ? ink : cream,
    lim.displayRatio,
    blackOrWhite(panel),
  );
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final previewText = onPanel(
    lightPanel
        ? oklchToArgb(0.42, d.ink.c, d.neutralHue / 10)
        : oklchToArgb(0.78, 0.010, d.neutralHue / 10),
    previewTarget,
    blackOrWhite(panel),
  );
  final error = onPanel(
    oklchToArgb(lightPanel ? 0.50 : 0.74, lightPanel ? 0.19 : 0.15, 27),
    lim.displayRatio,
    blackOrWhite(panel),
  );
  final int caretStart;
  if (lightPanel) {
    final maxC = maxChroma(0.52, d.red.h);
    caretStart = oklchToArgb(0.52, maxC < 0.20 ? maxC : 0.20, d.red.h);
  } else {
    caretStart = _argb(d.yellow);
  }
  final caret = onPanel(caretStart, lim.caretRatio, displayText);

  final int ringStart;
  switch (d.variant) {
    case BauhausVariant.paper:
    case BauhausVariant.ochre:
      ringStart = ink;
    case BauhausVariant.grid:
      final op = d.primary(d.assignment.op);
      final maxC = maxChroma(0.58, op.h);
      final cap = d.assignment.op == BauhausPrimary.red ? 0.20 : 0.14;
      ringStart = oklchToArgb(0.58, maxC < cap ? maxC : cap, op.h);
    case BauhausVariant.night:
    case BauhausVariant.negative:
      ringStart = _argb(d.yellow);
  }
  final focus =
      solveOnAll(ringStart, bgs, lim.focusRingRatio) ?? blackOrWhite(ground);

  return Palette(
    background: ground,
    surface: panel,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: focus,
    accent: equals.face,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: bar,
    highlight: bauhausDisplayAccent(equals.face, operator.face, bar, panel),
    seedColor: operator.face,
  );
}

// --------------------------------------------------------------- builder --

/// Builds one unvalidated Bauhaus candidate (the generator repairs and
/// validates it, retries with `palette/retry/n` and finally falls back to
/// a Bauhaus hero).
ThemeSpec buildBauhausCandidate(
  int seed,
  FamilyDefinition def,
  int engineVersion, {
  int attempt = 0,
  bool accessible = false,
}) {
  final paletteTag = attempt == 0
      ? RngTag.palette
      : RngTag.sub(RngTag.palette, 'retry', attempt);
  final draw = drawBauhausPalette(
    Rng.stream(seed, paletteTag),
    def,
    accessible: accessible,
  );
  final brightness = draw.dark ? ThemeBrightness.dark : ThemeBrightness.light;

  // Background stream: the one scene kind, then its orientation.
  final b = Rng.stream(seed, RngTag.background);
  final background = BackgroundSpec(
    kind: pickWeightedValue(b, def.backgrounds),
    colors: bauhausSceneColors(draw),
    angleTenths: 900 * b.nextInt(4),
  );

  // Style stream: one draw, the function keys' corner accent.
  final st = Rng.stream(seed, RngTag.style);
  final accentOn = st.nextChance(
    bauhausAccentOnNumerator,
    bauhausAccentOnDenominator,
  );
  final palette = assembleBauhausPalette(
    draw,
    accentOn: accentOn,
    accessible: accessible,
    bgs: bauhausSceneSamples(background)!,
  );

  // Shape stream: the digit silhouette, corners, then the `=` figure
  // (always the triangle beside disc digits).
  final s = Rng.stream(seed, RngTag.shape);
  final kind = pickWeightedValue(s, def.shapes);
  final corner = def.cornerPermille.sampleStep(s, 10);
  final blocks = kind == KeyShapeKind.roundedRect;
  final keyShape = KeyShapeSpec(
    kind: kind,
    cornerPermille: corner,
    operatorKind: blocks ? KeyShapeKind.circle : KeyShapeKind.roundedRect,
    operatorM3eShape: blocks
        ? pickWeightedValue(s, bauhausBlockEqualsFigures)
        : M3eShape.triangle,
  );

  final motion = def.motionRanges.vary(
    def.motion,
    Rng.stream(seed, RngTag.motion),
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: palette.operator.face,
    family: ThemeFamily.bauhaus,
    dark: draw.dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.bauhaus,
    engineVersion: engineVersion,
    brightness: brightness,
    accessible: accessible,
    palette: palette,
    keyShape: keyShape,
    keyStyle: def.keyStyle,
    type: type,
    background: background,
    motion: motion,
    sound: def.sound,
    name: name,
    nonColourOperatorCue: def.nonColourOperatorCue,
  );
}

/// Jost everywhere: display 500–600, keys 450–550, operators and `=`
/// 100–200 heavier (not a cue: the silhouettes are).
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

// ----------------------------------------------------------- derivations --

/// The variant of a Bauhaus [spec] (not stored): grid ⇔ a keypad field;
/// ochre ⇔ light with a ground below L 0.87; night ⇔ dark with digits
/// below L 0.5.
BauhausVariant bauhausVariantOf(ThemeSpec spec) {
  final colors = spec.background.colors;
  if (!spec.isDark) {
    if (colors.length > 1 && colors[1] != colors[0]) {
      return BauhausVariant.grid;
    }
    return argbToOklch(spec.palette.background).l < 0.87
        ? BauhausVariant.ochre
        : BauhausVariant.paper;
  }
  return argbToOklch(spec.palette.digit.face).l < 0.5
      ? BauhausVariant.night
      : BauhausVariant.negative;
}

/// The key composition of [shape] (null when it is not a Bauhaus one).
BauhausComposition? bauhausCompositionOf(KeyShapeSpec shape) {
  if (shape.kind == KeyShapeKind.circle) {
    return shape.operatorKind == KeyShapeKind.roundedRect &&
            shape.operatorM3eShape == M3eShape.triangle
        ? BauhausComposition.discBlock
        : null;
  }
  if (shape.kind != KeyShapeKind.roundedRect ||
      shape.operatorKind != KeyShapeKind.circle) {
    return null;
  }
  return switch (shape.operatorM3eShape) {
    M3eShape.circle => BauhausComposition.blockDisc,
    M3eShape.fan => BauhausComposition.blockFan,
    M3eShape.triangle => BauhausComposition.blockTriangle,
    _ => null,
  };
}

/// The primary [argb] reads as (chroma ≥ 0.08 and the hue inside one
/// window: red 18–40°, yellow 82–100° with L ≥ 0.78, blue 250–280°), or
/// null.
BauhausPrimary? bauhausPrimaryOf(int argb) {
  final c = argbToOklch(argb | 0xFF000000);
  if (c.c < bauhausPrimaryMinChroma) return null;
  if (c.h >= 18 && c.h <= 40) return BauhausPrimary.red;
  if (c.h >= 82 && c.h <= 100 && c.l >= 0.78) return BauhausPrimary.yellow;
  if (c.h >= 250 && c.h <= 280) return BauhausPrimary.blue;
  return null;
}

/// Lowest chroma a primary face may have (after repairs).
const double bauhausPrimaryMinChroma = 0.08;

/// Highest chroma of a neutral face.
const double bauhausNeutralMaxChroma = 0.03;

/// Highest corner radius of a block, permille of the short side (blocks
/// stay square next to discs).
const int bauhausMaxCornerPermille = 40;

/// Lowest contrast between the digit face and what it sits on (ground or
/// field).
const double bauhausDigitVisibility = 1.10;

/// Lowest contrast between an operator or `=` face and what it sits on
/// (ground or field): the silhouette is the recorded cue, so it must not
/// rest on hue alone.
const double bauhausKeyVisibility = 1.10;

/// Lowest ΔEOK between each scene shape colour and the ground.
const double bauhausSceneShapeDeltaE = 0.10;

/// Lowest ΔEOK between the function keys' corner accent and their face.
const double bauhausAccentDeltaE = 0.10;

// ------------------------------------------------------------- guardrails --

/// Steered Bauhaus (engine v5): the least chroma of an operator or `=`
/// accent, and how far apart (degrees) their hues must sit.
const double bauhausSteeredAccentMinChroma = 0.08;
const double bauhausSteeredAccentApartDeg = 40;

/// How far (tenths) a steered second colour must sit from the first to
/// colour Bauhaus's `=` key (a margin over [bauhausSteeredAccentApartDeg]).
const int bauhausSteeredEqualsApartTenths = 500;

/// The Bauhaus rules (called from `validateTheme` for Bauhaus specs only):
///
/// - [GuardrailRule.bauhausOperatorCue]: the recorded shape cue is real —
///   digit silhouette block or disc, operator silhouette the other one,
///   `=` a disc, fan or triangle that differs from the digits, blocks no
///   rounder than 4 %.
/// - [GuardrailRule.bauhausPrimaries]: operator and `=` are two different
///   primaries ([bauhausPrimaryOf]); digits are neutral; function keys
///   neutral or a primary; the function accent opaque or off and distinct
///   from the function face.
/// - [GuardrailRule.bauhausScene]: the scene's encoding (kind, 6 colours,
///   no pattern, static, a quarter-turn orientation, colour 0 = the
///   background), a dark field that the digits stand out on, digit,
///   operator and `=` faces visible on what they sit on, every scene shape
///   colour distinct from the ground.
/// - [GuardrailRule.bauhausPanel]: sheet, rule and accent opaque; the
///   rule ≥ 3:1 on the sheet (WCAG 1.4.11); the accent distinct from the
///   sheet (min ΔEOK over normal + CVD ≥ 0.07).
List<GuardrailViolation> validateBauhaus(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final out = <GuardrailViolation>[];
  final p = spec.palette;
  final shape = spec.keyShape;

  // Operator cue.
  void cue(String detail) => out.add(
    GuardrailViolation(GuardrailRule.bauhausOperatorCue, 0, 1, detail),
  );
  const silhouettes = {KeyShapeKind.roundedRect, KeyShapeKind.circle};
  const equalsFigures = {M3eShape.circle, M3eShape.fan, M3eShape.triangle};
  if (spec.nonColourOperatorCue != OperatorCue.shape) cue('cue not recorded');
  if (!silhouettes.contains(shape.kind)) cue('digit silhouette');
  if (!silhouettes.contains(shape.operatorKind) ||
      shape.operatorKind == shape.kind) {
    cue('operator silhouette');
  }
  if (!equalsFigures.contains(shape.operatorM3eShape) ||
      (shape.kind == KeyShapeKind.circle &&
          shape.operatorM3eShape == M3eShape.circle)) {
    cue('= figure');
  }
  if (shape.cornerPermille < 0 ||
      shape.cornerPermille > bauhausMaxCornerPermille) {
    cue('block corners');
  }

  // Primaries.
  void primaries(double measured, double required, String detail) => out.add(
    GuardrailViolation(
      GuardrailRule.bauhausPrimaries,
      measured,
      required,
      detail,
    ),
  );
  // A steered theme (engine v5) takes its accents from the intent: two
  // strong accents of different hues stand in for two primaries.
  final steered = spec.variant == ThemeVariant.steered;
  final op = bauhausPrimaryOf(p.operator.face);
  final eq = bauhausPrimaryOf(p.equals.face);
  final opLch = argbToOklch(p.operator.face);
  final eqLch = argbToOklch(p.equals.face);
  if (steered) {
    if (opLch.c < bauhausSteeredAccentMinChroma) {
      primaries(opLch.c, bauhausSteeredAccentMinChroma, 'operator accent');
    }
    if (eqLch.c < bauhausSteeredAccentMinChroma) {
      primaries(eqLch.c, bauhausSteeredAccentMinChroma, '= accent');
    }
    final d = (opLch.h - eqLch.h).abs() % 360;
    final apart = d > 180 ? 360 - d : d;
    if (apart < bauhausSteeredAccentApartDeg) {
      primaries(
        apart,
        bauhausSteeredAccentApartDeg,
        'operator and = share a hue',
      );
    }
  } else {
    if (op == null) {
      primaries(opLch.c, 0.08, 'operator primary');
    }
    if (eq == null) {
      primaries(eqLch.c, 0.08, '= primary');
    }
    if (op != null && op == eq) {
      primaries(0, 1, 'operator and = share a hue');
    }
  }
  final digitC = argbToOklch(p.digit.face).c;
  if (digitC >= bauhausNeutralMaxChroma) {
    primaries(digitC, bauhausNeutralMaxChroma, 'digit not neutral');
  }
  final fnC = argbToOklch(p.function.face).c;
  if (fnC >= bauhausNeutralMaxChroma &&
      bauhausPrimaryOf(p.function.face) == null &&
      !(steered && fnC >= bauhausSteeredAccentMinChroma)) {
    primaries(fnC, bauhausNeutralMaxChroma, 'function neither');
  }
  final accent = p.function.edge;
  final accentAlpha = (accent >>> 24) & 0xFF;
  if (accentAlpha != 0) {
    final d = accentAlpha == 255 ? deltaEOKArgb(accent, p.function.face) : 0.0;
    if (d < bauhausAccentDeltaE) {
      primaries(d, bauhausAccentDeltaE, 'function accent');
    }
  }

  // Scene.
  void scene(double measured, double required, String detail) => out.add(
    GuardrailViolation(GuardrailRule.bauhausScene, measured, required, detail),
  );
  final bg = spec.background;
  final colors = bg.colors;
  if (bg.kind != BackgroundKind.bauhausComposition) scene(0, 1, 'kind');
  if (bg.pattern != BackgroundPattern.none ||
      bg.patternOpacityPermille != 0 ||
      bg.driftPeriodMs != 0) {
    scene(0, 1, 'static, no pattern');
  }
  if (bg.angleTenths < 0 ||
      bg.angleTenths > 2700 ||
      bg.angleTenths % 900 != 0) {
    scene(bg.angleTenths.toDouble(), 0, 'orientation');
  }
  if (colors.length != 6) {
    scene(colors.length.toDouble(), 6, 'colours');
  } else {
    final ground = colors[0] | 0xFF000000;
    final field = colors[1] | 0xFF000000;
    if (colors[0] != p.background) scene(0, 1, 'ground = background');
    final digit = p.digit.face | 0xFF000000;
    if (field != ground) {
      final l = argbToOklch(field).l;
      final cr = contrastRatio(digit, field);
      if (l > 0.22) scene(l, 0.22, 'field not dark');
      if (cr < ratioLarge) scene(cr, ratioLarge, 'digits on the field');
    }
    final under = field != ground ? field : ground;
    final visible = contrastRatio(digit, under);
    if (visible < bauhausDigitVisibility) {
      scene(visible, bauhausDigitVisibility, 'digits on the ground');
    }
    for (final (face, what) in [
      (p.operator.face, 'operators'),
      (p.equals.face, '='),
    ]) {
      final cr = contrastRatio(face | 0xFF000000, under);
      if (cr < bauhausKeyVisibility) {
        scene(cr, bauhausKeyVisibility, '$what on the ground');
      }
    }
    for (var i = 2; i < 6; i++) {
      final d = deltaEOKArgb(colors[i] | 0xFF000000, ground);
      if (d < bauhausSceneShapeDeltaE) {
        scene(d, bauhausSceneShapeDeltaE, 'scene colour $i on the ground');
      }
    }
  }

  // Display.
  void display(double measured, double required, String detail) => out.add(
    GuardrailViolation(GuardrailRule.bauhausPanel, measured, required, detail),
  );
  bool opaque(int c) => ((c >>> 24) & 0xFF) == 0xFF;
  if (!opaque(p.surface) || !opaque(p.shadow) || !opaque(p.highlight)) {
    display(0, 1, 'opaque sheet, rule and accent');
  }
  final rule = contrastRatio(p.shadow, p.surface);
  if (rule < ratioLarge) display(rule, ratioLarge, 'rule on the sheet');
  final mark = minCvdDeltaE(p.highlight | 0xFF000000, p.surface | 0xFF000000);
  if (mark < bauhausDisplayAccentDeltaE) {
    display(mark, bauhausDisplayAccentDeltaE, 'accent on the sheet');
  }
  return out;
}

/// Family repairs after labels and display texts: the sheet opaque, the
/// rule re-solved to ≥ 3:1 on it, and `accent` / `highlight` following the
/// (possibly repaired) `=` face ([bauhausDisplayAccent]). Faces are never
/// touched here. Null when the rule cannot reach 3:1.
Palette? repairBauhausExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final surface = p.surface | 0xFF000000;
  final shadow = solveOnAll(p.shadow | 0xFF000000, [surface], ratioLarge);
  if (shadow == null) return null;
  return p.copyWith(
    surface: surface,
    shadow: shadow,
    accent: p.equals.face,
    highlight: bauhausDisplayAccent(
      p.equals.face,
      p.operator.face,
      shadow,
      surface,
    ),
  );
}

/// Guardrail background samples of the scene: the ground, plus the grid
/// field when there is one. Nothing else is ever painted under a key,
/// label, focus ring, toolbar control (icons and the mode button) or
/// display text (the scene keeps its shapes in the toolbar's free middle,
/// clear of the mode button, and in the screen margins).
List<int>? bauhausSceneSamples(BackgroundSpec bg) {
  if (bg.colors.isEmpty) return const [0xFF000000];
  final ground = bg.colors[0] | 0xFF000000;
  final field = bg.colors.length > 1 ? bg.colors[1] | 0xFF000000 : ground;
  return field == ground ? [ground] : [ground, field];
}

/// Display text only ever sits on the opaque sheet (the rule and the
/// accent stay outside the display's text padding), so the sheet is the
/// only backdrop (Liquid Glass precedent).
List<int>? bauhausDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) => surfaces;
