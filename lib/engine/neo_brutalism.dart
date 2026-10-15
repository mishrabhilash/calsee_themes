/// The Neo-brutalism family (spec §5.3 #6; motion brief §2.3
/// "Neo-brutalism"): thick black outlines, offset hard shadows, saturated
/// flat fills and chunky grotesque type. Pure Dart: part of the generator,
/// so every constant here is part of the family's engine-v2 definition and
/// must not change without a version bump.
///
/// - **Body** (the background): flat paper / cream (most themes), a bold
///   flat colour (a "poster" body), or — rarely — near-black with cream
///   ink. Solid, or with a faint grid / dot / stripe print in the ink.
/// - **Ink**: one near-black colour (cream on the dark body) for every
///   key outline (`KeyColors.edge`, 2–4 dp, seeded), the offset hard
///   shadow (`palette.shadow`, opaque, no blur, offset = the press depth
///   s = 3–5 dp, seeded) and, wherever it reaches the label floor, the
///   labels and display text. Outlines are ≥ 3:1 against every
///   background sample (WCAG 1.4.11, validated as
///   `GuardrailRule.brutalOutline`).
/// - **Keys**: white / pastel digit faces (charcoal on the dark body);
///   operators and `=` in saturated flat colours whose lightness sits at
///   their hue's chroma cusp (clamped to 0.72–0.90, so black ink always
///   reaches 7:1 and nothing washes out); function keys a lighter pastel
///   of a third hue. One light theme in four gives `=` an ink face with a
///   coloured label. Operators always carry a label ≥ 200 heavier than
///   digits (the recorded non-colour cue, [OperatorCue.weight]).
/// - **Display**: an outlined card in the panel colour (`palette.surface`:
///   white, or a pale highlight colour) with the same hard shadow, the
///   result set in a heavy, wide cut of the display font
///   (`TypeSpec.displayWeight`, `TypeSpec.widthPermille`).
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

/// The three body kinds.
enum NeoBrutalBody {
  /// Flat paper / cream (light).
  paper,

  /// A bold flat colour (light).
  poster,

  /// Near-black with cream ink (dark).
  ink,
}

/// Light themes: `[paper, poster]` weights.
const List<int> neoBrutalLightBodyWeights = [5, 3];

/// Paper body: lightness and chroma (thousandths), hue warm cream two
/// times in three, any hue otherwise.
const IntRange neoBrutalPaperLMilli = IntRange(945, 985);
const IntRange neoBrutalPaperChromaMilli = IntRange(6, 26);
const IntRange neoBrutalPaperHueTenths = IntRange(650, 1000);

/// Poster body: lightness and chroma as a fraction of the gamut (× 1000),
/// capped at [neoBrutalPosterChromaCapMilli].
const IntRange neoBrutalPosterLMilli = IntRange(770, 870);
const IntRange neoBrutalPosterChromaRel = IntRange(550, 850);
const int neoBrutalPosterChromaCapMilli = 170;

/// Ink on light bodies (near-black) and on the dark body (cream).
const IntRange neoBrutalInkLMilli = IntRange(120, 190);
const IntRange neoBrutalInkChromaMilli = IntRange(0, 14);
const IntRange neoBrutalCreamInkLMilli = IntRange(945, 985);
const IntRange neoBrutalCreamInkChromaMilli = IntRange(10, 30);

/// Display panel on light bodies: white (weight 3) or a pale highlight
/// colour (weight 2).
const List<int> neoBrutalPanelWeights = [3, 2];
const IntRange neoBrutalWhitePanelLMilli = IntRange(975, 1000);
const IntRange neoBrutalHighlightPanelLMilli = IntRange(890, 950);
const IntRange neoBrutalHighlightPanelChromaRel = IntRange(350, 650);

/// Hue schemes as `(=, function)` offsets from the operator hue (tenths).
const List<Weighted<(int, int)>> neoBrutalHueSchemes = [
  Weighted((1800, 900), 3), // complementary + a quarter turn
  Weighted((1200, 2400), 3), // triadic
  Weighted((1500, 2100), 2), // split complementary
  Weighted((900, 1800), 2), // tetradic
];

/// Outline width range, dp × 100 (sampled on 0.5 dp steps).
const IntRange neoBrutalOutlineWidthCdp = IntRange(200, 400);

/// Hard-shadow offset range, dp × 100 (= the press depth s).
const IntRange neoBrutalShadowCdp = IntRange(300, 500);

/// Light themes: one in four gives `=` an ink face.
const int neoBrutalInkEqualsChance = 4;

/// Light ranges. Only the lightness / chroma ranges are read (by
/// [buildNeoBrutalCandidate]); hues come from [neoBrutalHueSchemes].
/// Operator and `=` lightness is the hue's chroma cusp + an offset,
/// clamped to 0.72–0.90.
const RoleRanges neoBrutalLightRanges = RoleRanges(
  background: RoleRange(IntRange(945, 985), ChromaRange.abs(6, 26)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(0, 12),
  digit: RoleRange(IntRange(965, 1000), ChromaRange.abs(0, 12)),
  digitDuotoneChroma: ChromaRange.rel(250, 450, 70),
  function: RoleRange(IntRange(830, 920), ChromaRange.rel(450, 750, 160)),
  operator: RoleRange(IntRange(720, 900), ChromaRange.rel(850, 1000, 260)),
  operatorMonochromeL: IntRange(720, 900),
  equals: RoleRange(IntRange(720, 900), ChromaRange.rel(850, 1000, 260)),
  labelStartLMilli: 150,
  labelMaxChromaMilli: 14,
  accentChroma: ChromaRange.rel(600, 900, 160),
  minDigitAboveBackgroundMilli: 0,
  accentCuspOffsetMilli: IntRange(-40, 60),
  accentCuspClampMilli: IntRange(720, 900),
);

/// Dark ranges: a near-black body, charcoal digit keys ≥ 0.10 above it,
/// saturated operators / `=` and pastel function keys as in the light
/// themes.
const RoleRanges neoBrutalDarkRanges = RoleRanges(
  background: RoleRange(IntRange(150, 215), ChromaRange.abs(0, 25)),
  surfaceOffsetMilli: IntRange(50, 90),
  surfaceChroma: ChromaRange.abs(0, 25),
  digit: RoleRange(IntRange(300, 360), ChromaRange.abs(0, 25)),
  digitDuotoneChroma: ChromaRange.abs(0, 25),
  function: RoleRange(IntRange(830, 920), ChromaRange.rel(450, 750, 160)),
  operator: RoleRange(IntRange(720, 900), ChromaRange.rel(850, 1000, 260)),
  operatorMonochromeL: IntRange(720, 900),
  equals: RoleRange(IntRange(720, 900), ChromaRange.rel(850, 1000, 260)),
  labelStartLMilli: 960,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(600, 900, 160),
  minDigitAboveBackgroundMilli: 100,
  accentCuspOffsetMilli: IntRange(-40, 60),
  accentCuspClampMilli: IntRange(720, 900),
);

/// Neo-brutalism (spec §5.3 #6; motion brief §2.3 "Neo-brutalism"):
/// outlined rounded-rect keys (corners 0–20 % of the short side) sitting
/// on an offset hard shadow. Press: the face translates (+s, +s) into its
/// shadow, which collapses to 0 (s = 3–5 dp, seeded, whole dp);
/// `hardPress` in, 2500/1.0 out (seeded × {0.9, 1, 1.1}); no tint; the
/// display stamps new glyphs in from 1.12 → 1 on `hardPress`; sound
/// `mech_linear`, haptic rigid · 1.0. The palette is built by
/// [buildNeoBrutalCandidate].
const FamilyDefinition neoBrutalismDefinition = FamilyDefinition(
  family: ThemeFamily.neoBrutalism,
  brightnessWeights: [1, 8],
  schemes: [Weighted(HarmonyScheme.complementary, 1)],
  shapes: [Weighted(KeyShapeKind.roundedRect, 1)],
  cornerPermille: IntRange(0, 200),
  styles: [Weighted(KeyStyleKind.outlined, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.outlined,
    outlineWidthCdp: 300,
    shadowOffsetCdp: 400,
    stateLayerPermille: 0,
  ),
  displayFonts: [
    Weighted(FontIds.robotoFlex, 3),
    Weighted(FontIds.spaceGrotesk, 1),
  ],
  keyFonts: [
    Weighted(FontIds.robotoFlex, 3),
    Weighted(FontIds.spaceGrotesk, 2),
  ],
  displayWeight: IntRange(700, 900),
  keyWeight: IntRange(600, 700),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [
    Weighted(BackgroundKind.solid, 5),
    Weighted(BackgroundKind.pattern, 3),
  ],
  patterns: [
    Weighted(BackgroundPattern.grid, 3),
    Weighted(BackgroundPattern.dots, 3),
    Weighted(BackgroundPattern.stripes, 1),
  ],
  sound: SoundPackId.mechLinear,
  dark: neoBrutalDarkRanges,
  light: neoBrutalLightRanges,
  motion: MotionSpec(
    verb: PressVerb.stamp,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.hardPress,
    release: SpringToken(2500, 1000),
    depthCdp: 400,
    entry: EntryStyle.stamp,
    entryScalePermille: 1120,
    entrySpring: SpringTokens.hardPress,
    impact: ImpactStyle.rigid,
    impactPermille: 1000,
  ),
  motionRanges: MotionRanges(depthCdp: neoBrutalShadowCdp),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

// --------------------------------------------------------------- builder --

int _wrap(int tenths) => tenths % 3600;

int _hueDistance(int a, int b) {
  final d = (a - b).abs() % 3600;
  return d > 1800 ? 3600 - d : d;
}

/// The lightness × 1000 (20-step grid, 0.40–0.98) where hue [hDeg]
/// reaches its highest in-gamut chroma.
int neoBrutalCuspLMilli(double hDeg) {
  var best = 400;
  var bestC = -1.0;
  for (var l = 400; l <= 980; l += 20) {
    final c = maxChroma(l / 1000, hDeg);
    if (c > bestC) {
      bestC = c;
      best = l;
    }
  }
  return best;
}

/// Builds one unvalidated Neo-brutalism candidate (the generator repairs
/// and validates it, retries with `palette/retry/n` and finally falls back
/// to a Neo-brutalism hero).
ThemeSpec buildNeoBrutalCandidate(
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
  final ranges = def.ranges(brightness);
  final body = dark
      ? NeoBrutalBody.ink
      : NeoBrutalBody.values[p.pickWeighted(neoBrutalLightBodyWeights)];
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final bile = def.bile;

  // Hues: operator, `=` and function from a scheme.
  final opHue = p.nextHueTenths();
  final (eqOffset, fnOffset) = pickWeightedValue(p, neoBrutalHueSchemes);
  var eqHue = _wrap(opHue + eqOffset + p.nextJitterTenths(120));
  final fnHue = _wrap(opHue + fnOffset + p.nextJitterTenths(120));

  // Body: paper, poster colour (the hue furthest from the key hues) or ink.
  final int bodyL;
  final int bodyHue;
  final double bodyC;
  switch (body) {
    case NeoBrutalBody.paper:
      bodyL = neoBrutalPaperLMilli.sample(p);
      bodyHue = p.nextChance(2, 3)
          ? neoBrutalPaperHueTenths.sample(p)
          : p.nextHueTenths();
      bodyC = neoBrutalPaperChromaMilli.sample(p) / 1000;
    case NeoBrutalBody.poster:
      bodyL = neoBrutalPosterLMilli.sample(p);
      var bestOffset = 0;
      var bestDistance = -1;
      for (var k = 0; k < 24; k++) {
        final h = _wrap(opHue + k * 150);
        var d = _hueDistance(h, opHue);
        for (final other in [eqHue, fnHue]) {
          final x = _hueDistance(h, other);
          if (x < d) d = x;
        }
        if (d > bestDistance) {
          bestDistance = d;
          bestOffset = k * 150;
        }
      }
      var hue = _wrap(opHue + bestOffset + p.nextJitterTenths(100));
      // A dark-ish yellow-green poster reads as bile: push it to the
      // band's edge (poster bodies are light, so this is rare).
      hue = bile.apply(hue, bodyL / 1000, 0.1);
      bodyHue = hue;
      final rel = neoBrutalPosterChromaRel.sample(p) / 1000;
      final c = rel * maxChroma(bodyL / 1000, hue / 10);
      bodyC = c < neoBrutalPosterChromaCapMilli / 1000
          ? c
          : neoBrutalPosterChromaCapMilli / 1000;
    case NeoBrutalBody.ink:
      bodyL = ranges.background.lMilli.sample(p);
      bodyHue = p.nextHueTenths();
      bodyC =
          p.nextIntIn(
            ranges.background.chroma.lo,
            ranges.background.chroma.hi,
          ) /
          1000;
  }
  final bodyArgb = oklchToArgb(bodyL / 1000, bodyC, bodyHue / 10);

  // Ink: near-black (light bodies) or cream (the dark body).
  final int ink;
  final int darkInk;
  {
    final inkL = neoBrutalInkLMilli.sample(p);
    final inkC = neoBrutalInkChromaMilli.sample(p);
    final inkHue = p.nextChance(1, 2) ? bodyHue : opHue;
    darkInk = oklchToArgb(inkL / 1000, inkC / 1000, inkHue / 10);
    if (dark) {
      ink = oklchToArgb(
        neoBrutalCreamInkLMilli.sample(p) / 1000,
        neoBrutalCreamInkChromaMilli.sample(p) / 1000,
        neoBrutalPaperHueTenths.sample(p) / 10,
      );
    } else {
      ink = darkInk;
    }
  }
  final darkInkLch = argbToOklch(darkInk);
  final creamLch = dark
      ? argbToOklch(ink)
      : (l: 0.975, c: 0.012, h: neoBrutalPaperHueTenths.lo / 10);

  // Faces (lightness × 1000).
  Lch saturated(int hueTenths, IntRange cuspOffset, IntRange clamp) {
    final hDeg = hueTenths / 10;
    var lMilli = clamp.clamp(neoBrutalCuspLMilli(hDeg) + cuspOffset.sample(p));
    if (accessible && lMilli < 740) lMilli = 740;
    final l = lMilli / 1000;
    final rel = p.nextIntIn(
      ranges.operator.chroma.lo,
      ranges.operator.chroma.hi,
    );
    final c = rel / 1000 * maxChroma(l, hDeg);
    final cap = ranges.operator.chroma.capMilli / 1000;
    return (l: l, c: c < cap ? c : cap, h: hDeg);
  }

  final cuspOffset = ranges.accentCuspOffsetMilli!;
  final cuspClamp = ranges.accentCuspClampMilli!;
  final opFace = saturated(opHue, cuspOffset, cuspClamp);
  var eqFace = saturated(eqHue, cuspOffset, cuspClamp);
  final inkEquals = !dark && p.nextChance(1, neoBrutalInkEqualsChance);

  final Lch fnFace;
  {
    final l = ranges.function.lMilli.sample(p) / 1000;
    final rel = p.nextIntIn(
      ranges.function.chroma.lo,
      ranges.function.chroma.hi,
    );
    final c = rel / 1000 * maxChroma(l, fnHue / 10);
    final cap = ranges.function.chroma.capMilli / 1000;
    fnFace = (l: l, c: c < cap ? c : cap, h: fnHue / 10);
  }

  final Lch digitFace;
  if (dark) {
    var l = ranges.digit.lMilli.sample(p);
    if (l < bodyL + ranges.minDigitAboveBackgroundMilli) {
      l = bodyL + ranges.minDigitAboveBackgroundMilli;
    }
    if (accessible && l > 400) l = 400;
    digitFace = (
      l: l / 1000,
      c: p.nextIntIn(ranges.digit.chroma.lo, ranges.digit.chroma.hi) / 1000,
      h: bodyHue / 10,
    );
  } else if (p.nextChance(1, 3)) {
    // Pastel digits, tinted toward the function hue's neighbour.
    final hue = _wrap(fnHue + 1800 + p.nextJitterTenths(300));
    final l = p.nextIntIn(905, 950) / 1000;
    final range = ranges.digitDuotoneChroma;
    final c = p.nextIntIn(range.lo, range.hi) / 1000 * maxChroma(l, hue / 10);
    digitFace = (
      l: l,
      c: c < range.capMilli / 1000 ? c : range.capMilli / 1000,
      h: hue / 10,
    );
  } else {
    digitFace = (
      l: ranges.digit.lMilli.sample(p) / 1000,
      c: p.nextIntIn(ranges.digit.chroma.lo, ranges.digit.chroma.hi) / 1000,
      h: (p.nextChance(1, 2) ? bodyHue : opHue) / 10,
    );
  }

  // Keys: ink labels wherever they reach the floor (repairPair keeps the
  // start colour when it already passes), cream on dark faces.
  KeyColors key(Lch face) {
    final start = face.l < 0.58 ? creamLch : darkInkLch;
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

  final digit = key(digitFace);
  final function = key(fnFace);
  final operator = key(opFace);
  KeyColors equalsKey() {
    if (inkEquals) {
      // An ink `=` with a label in the operator colour.
      final pair = repairPair(
        darkInkLch,
        argbToOklch(operator.face),
        policy: policy,
      );
      return KeyColors(face: pair.face, label: pair.label, edge: ink);
    }
    return key(eqFace);
  }

  var equals = equalsKey();
  if (minCvdDeltaE(equals.face, operator.face) < 0.065) {
    // `=` must stand apart from the operators (CVD included): move it
    // 0.12 in lightness inside the cusp clamp, else a quarter turn.
    final o = argbToOklch(operator.face).l;
    final up = eqFace.l >= o
        ? eqFace.l + 0.12 <= 0.92
        : eqFace.l - 0.12 < (accessible ? 0.74 : 0.72);
    final l = clamp01(eqFace.l + (up ? 0.12 : -0.12));
    eqFace = (l: l, c: eqFace.c, h: eqFace.h);
    equals = key(eqFace);
    if (minCvdDeltaE(equals.face, operator.face) < 0.065) {
      eqHue = _wrap(eqHue + 900);
      eqFace = saturated(eqHue, cuspOffset, cuspClamp);
      equals = key(eqFace);
    }
  }

  // Display panel.
  final int panel;
  if (dark) {
    final l = bodyL + ranges.surfaceOffsetMilli.sample(p);
    panel = oklchToArgb(
      l / 1000,
      p.nextIntIn(ranges.surfaceChroma.lo, ranges.surfaceChroma.hi) / 1000,
      bodyHue / 10,
    );
  } else if (p.pickWeighted(neoBrutalPanelWeights) == 0) {
    panel = oklchToArgb(
      neoBrutalWhitePanelLMilli.sample(p) / 1000,
      p.nextIntIn(ranges.surfaceChroma.lo, ranges.surfaceChroma.hi) / 1000,
      bodyHue / 10,
    );
  } else {
    final hue = p.nextChance(1, 2) ? fnHue : _wrap(eqHue + 600);
    final l = neoBrutalHighlightPanelLMilli.sample(p) / 1000;
    final rel = neoBrutalHighlightPanelChromaRel.sample(p) / 1000;
    final c = rel * maxChroma(l, hue / 10);
    panel = oklchToArgb(l, c < 0.14 ? c : 0.14, bile.apply(hue, l, c) / 10);
  }

  // Background: flat, or printed with the ink.
  final background = _background(
    Rng.stream(seed, RngTag.background),
    def,
    bodyArgb,
    darkInk: darkInk,
    ink: ink,
    dark: dark,
  );
  final bgs = backgroundSamples(background);
  final backdrops = [panel, ...bgs];

  int onAll(int start, List<int> on, double target, int fallback) =>
      solveOnAll(start, on, target) ?? fallback;
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final displayText = onAll(
    dark ? ink : darkInk,
    backdrops,
    lim.displayRatio,
    blackOrWhite(panel),
  );
  final previewText = onAll(
    dark
        ? oklchToArgb(0.80, 0.02, creamLch.h)
        : oklchToArgb(0.40, darkInkLch.c, darkInkLch.h),
    backdrops,
    previewTarget,
    blackOrWhite(panel),
  );
  final error = onAll(
    oklchToArgb(dark ? 0.74 : 0.50, dark ? 0.15 : 0.19, 27),
    backdrops,
    lim.displayRatio,
    blackOrWhite(panel),
  );
  final caretL = dark ? 0.82 : 0.48;
  final caretC = 0.8 * maxChroma(caretL, opHue / 10);
  final caret = onAll(
    oklchToArgb(caretL, caretC < 0.18 ? caretC : 0.18, opHue / 10),
    backdrops,
    lim.caretRatio,
    displayText,
  );
  final focus = onAll(ink, bgs, lim.focusRingRatio, blackOrWhite(bodyArgb));

  final palette = Palette(
    background: bodyArgb,
    surface: panel,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: focus,
    accent: focus,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: ink | 0xFF000000,
    highlight: 0x00000000,
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
    outlineWidthCdp: neoBrutalOutlineWidthCdp.sampleStep(st, 50),
    shadowOffsetCdp: motion.depthCdp,
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: operator.face,
    family: ThemeFamily.neoBrutalism,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.neoBrutalism,
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

/// Chunky type: a heavy, wide display cut; key labels in Roboto Flex
/// (600–700, operators + 200–300) or Space Grotesk (500, operators at its
/// heaviest 700, so the weight cue is real on both).
TypeSpec _type(Rng t, FamilyDefinition def) {
  final displayFont = pickWeightedValue(t, def.displayFonts);
  final keyFont = pickWeightedValue(t, def.keyFonts);
  final displayWeight = def.displayWeight.sampleStep(t, 50);
  var keyWeight = def.keyWeight.sampleStep(t, 50);
  var opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  if (keyFont == FontIds.spaceGrotesk) {
    keyWeight = 500;
    opWeight = 700;
  }
  return TypeSpec(
    displayFont: displayFont,
    keyFont: keyFont,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeight: opWeight > 900 ? 900 : opWeight,
    widthPermille: 1000 + 50 * t.nextInt(6),
  );
}

BackgroundSpec _background(
  Rng b,
  FamilyDefinition def,
  int body, {
  required int darkInk,
  required int ink,
  required bool dark,
}) {
  final kind = pickWeightedValue(b, def.backgrounds);
  if (kind != BackgroundKind.pattern) {
    return BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: List.unmodifiable([body]),
    );
  }
  final pattern = pickWeightedValue(b, def.patterns);
  return BackgroundSpec(
    kind: BackgroundKind.pattern,
    colors: List.unmodifiable([body]),
    pattern: pattern,
    patternColor: (dark ? ink : darkInk) | 0xFF000000,
    patternScaleCdp: 1600 + 200 * b.nextInt(7),
    patternOpacityPermille: dark ? b.nextIntIn(60, 110) : b.nextIntIn(50, 100),
  );
}
