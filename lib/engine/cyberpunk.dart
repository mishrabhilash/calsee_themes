/// The Cyberpunk family (new family, id 13; heroes 130–132): a night-city
/// HUD keypad. Pure Dart: part of the generator, so every constant here is
/// part of the family's engine-v3 definition and must not change without a
/// version bump once v3 ships with it.
///
/// - **Body** (the scene, `BackgroundKind.cyberGrid`): a near-black
///   blue-black, teal or plum gradient whose bottom stop (the "street
///   glow", 0.06–0.10 lighter) is tinted by a neon, under a flat 32 dp
///   grid with a brighter line every fourth, routed circuit traces with via
///   rings coming in from the screen edges, and 3 dp scanlines. The seeded
///   light variant, "Hazard", is a warm acid-yellow body (102–107°) with
///   black plates, a black HUD screen and no grid (traces and scanlines
///   only).
/// - **Plates** (digit and function keys): dark chamfered faces (OKLCH
///   L ≤ 0.305) traced by a neon edge line (`KeyColors.edge`, 1–1.5 dp)
///   that bleeds a halo onto the body; digit labels are near-white (yellow
///   on Hazard), function labels neon.
/// - **Slabs** (operator and `=` keys): solid neon faces at their hue's
///   chroma cusp with dark labels. OKLCH L: magenta 0.66–0.88 (0.76–0.88
///   under the Accessible lock), cyan 0.80–0.86 in both modes (the gamut
///   edge, at 95–100 % of its maximum chroma), acid 0.74–0.92 (0.76 on
///   Hazard and under the lock), amber and toxic 0.74–0.88 (0.76 likewise).
///   Fill versus outline is the
///   recorded non-colour cue ([OperatorCue.outline]), verified by
///   [validateCyberpunk] as a luminance polarity cue (it survives every
///   colour-vision deficiency), plus a ≥ 200 heavier operator label.
/// - **Display**: an opaque, recessed HUD screen (`palette.surface`;
///   a cyan-tinted black on Hazard, with yellow text) with faint static
///   scanlines (`palette.shadow`, translucent lighter rows; none under the
///   Accessible lock), a neon frame (inset behind a black rim on Hazard),
///   corner brackets and a segmented status rule that carries no data.
///
/// Neon bands (tenths of a degree): MAGENTA 3260–3440, CYAN 1880–2040,
/// ACID 1000–1150, TOXIC 1350–1550, AMBER 600–740. There is no red or blue
/// slab band, so no saturated-red flash is possible.
///
/// `BackgroundSpec.colors` of the scene: `[0]` body (top stop, opaque),
/// `[1]` haze (bottom stop, opaque), `[2]` grid ink (alpha 0 on Hazard),
/// `[3]` trace and via ink, `[4]` scanline ink (all three translucent ARGB).
/// `angleTenths` tilts the gradient (within ±20°); the grid cell, scan
/// pitch and trace layout are renderer constants; the scene is static
/// (`driftPeriodMs` 0).
///
/// Every draw comes from the generator's named sub-streams (`palette` and
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), so a theme is a pure function of (seed, engineVersion,
/// accessible). The palette draw order is frozen once v3 ships.
library;

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/neo_brutalism.dart'
    show neoBrutalCuspLMilli;
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

// ------------------------------------------------------------- constants --

/// The four sub-variants (engine-internal, never serialised).
enum CyberVariant {
  /// Blue-black body, magenta / cyan / acid / amber neons.
  neonNoir,

  /// Deep teal-blue body, hacker greens and yellows.
  netrunner,

  /// Plum body, club pinks.
  afterhours,

  /// The light variant: acid-yellow body, black plates, cyan edges.
  hazard,
}

/// The neon hue bands (tenths of a degree).
enum CyberBand {
  // From 326°: nearer 320° the cusp turns lavender (Vaporwave's orchid).
  magenta(IntRange(3260, 3440)),
  // To 204°: past it cyan leaves the gamut above L 0.86 (ice blue).
  cyan(IntRange(1880, 2040)),
  acid(IntRange(1000, 1150)),
  toxic(IntRange(1350, 1550)),
  amber(IntRange(600, 740));

  const CyberBand(this.hues);

  /// Hue range, tenths of a degree.
  final IntRange hues;
}

/// Dark sub-variants `[neonNoir, netrunner, afterhours]`.
const List<int> cyberDarkVariantWeights = [5, 3, 2];

/// Role schemes `[edgeFromEq, edgeFromOp]` (dark themes; always drawn).
const List<int> cyberRoleSchemeWeights = [3, 2];

/// `(operator, =)` neon pairs per variant.
const Map<CyberVariant, List<Weighted<(CyberBand, CyberBand)>>> cyberPairs = {
  // Amber only ever pairs with cyan, and is never a noir operator (an
  // amber slab on blue-black would be NeoPOP's "Electric Mango").
  CyberVariant.neonNoir: [
    Weighted((CyberBand.magenta, CyberBand.cyan), 3),
    Weighted((CyberBand.cyan, CyberBand.magenta), 2),
    Weighted((CyberBand.magenta, CyberBand.acid), 3),
    Weighted((CyberBand.cyan, CyberBand.amber), 2),
    Weighted((CyberBand.acid, CyberBand.magenta), 2),
  ],
  // No toxic / cyan pair: the two sit close under every colour-vision
  // deficiency, and separating them left a dull teal `=`.
  CyberVariant.netrunner: [
    Weighted((CyberBand.cyan, CyberBand.acid), 3),
    Weighted((CyberBand.acid, CyberBand.cyan), 2),
    Weighted((CyberBand.cyan, CyberBand.magenta), 2),
    Weighted((CyberBand.toxic, CyberBand.magenta), 4),
  ],
  CyberVariant.afterhours: [
    Weighted((CyberBand.magenta, CyberBand.cyan), 2),
    Weighted((CyberBand.magenta, CyberBand.acid), 2),
    Weighted((CyberBand.amber, CyberBand.cyan), 2),
    Weighted((CyberBand.magenta, CyberBand.toxic), 2),
    Weighted((CyberBand.cyan, CyberBand.amber), 1),
  ],
  CyberVariant.hazard: [
    Weighted((CyberBand.cyan, CyberBand.magenta), 3),
    Weighted((CyberBand.magenta, CyberBand.cyan), 1),
  ],
};

/// Dark body hue bands (tenths) per dark variant, in variant order.
const List<IntRange> cyberBodyHueTenths = [
  IntRange(2550, 2850),
  IntRange(1950, 2350),
  IntRange(3200, 3500),
];

/// Dark body chroma (thousandths) per dark variant, in variant order.
const List<IntRange> cyberBodyChromaMilli = [
  IntRange(20, 40),
  IntRange(25, 55),
  IntRange(25, 55),
];

/// Plates (digit and function faces) are never lighter than this
/// (OKLCH L): the polarity half of the operator cue.
const double cyberPlateMaxL = 0.34;

/// Slabs (operator and `=` faces) are never darker than this (OKLCH L).
const double cyberSlabMinL = 0.64;

/// Slab face contrast against the digit plate (the cue's strength).
const double cyberSlabVsPlateRatio = 3;

/// Neon edge line width range, dp × 100.
const IntRange cyberEdgeWidthCdp = IntRange(100, 150);

/// Halo blur range, dp × 100 (σ = value / 200 dp).
const IntRange cyberHaloBlurCdp = IntRange(300, 500);

/// Chamfer range (fraction of the face's short side × 1000).
const IntRange cyberCornerPermille = IntRange(120, 240);

/// The street glow: the haze (bottom stop) is this much lighter than the
/// body in dark themes (OKLCH L, thousandths).
const IntRange cyberHazeLiftMilli = IntRange(60, 100);

/// Scene grid ink alpha ceiling (the sample model stays honest).
const int cyberGridMaxAlpha = 24;

/// Scene trace and via ink alpha ceiling.
const int cyberTraceMaxAlpha = 72;

/// Scene scanline ink alpha ceiling.
const int cyberScanMaxAlpha = 56;

/// Panel scanline ink (`palette.shadow`) alpha ceiling; 0 under the
/// Accessible lock.
const int cyberPanelScanMaxAlpha = 48;

/// The scene gradient tilts at most this far from vertical (tenths).
const int cyberMaxAngleTenths = 200;

/// The operator label weight ceiling (Oxanium's `wght` maximum).
const int cyberOperatorWeightMax = 800;

/// The key label zone (fraction of the face height): only the opaque face,
/// its contrast-safe flare and hover layers and the perimeter edge line
/// (≤ 3.5 dp in: Hazard plates inset theirs behind a 1.5 dp black rim)
/// may lie between these rows, so `contrast(label, face)` is
/// the worst case a label ever sits on. Ticks, bloom bands and the hold
/// bar stay in the bands above and below.
const double cyberLabelZoneTop = 0.28;
const double cyberLabelZoneBottom = 0.72;

/// Dark ranges: documentation of what [buildCyberpunkCandidate] draws (the
/// builder never reads them; the generic generator does not run for this
/// family). Lightness in OKLCH thousandths:
///
/// - body 130–185; panel 15–40 below it (never under 95);
/// - digit plates 205–260 (and ≥ body + 60), function plates 25–45
///   lighter (up to 305), chroma 0.025–0.036 (function + 0.005);
/// - slabs (operator, `=`; the `accent…` rows): the cusp −30…+50 clamped
///   per band — magenta 660–880, cyan 800–860, acid 740–920, amber and
///   toxic 740–880; every band from 760 under the Accessible lock (cyan
///   stays 800–860); chroma 88–100 % of the gamut maximum (cyan
///   95–100 %), capped at 0.28;
/// - neon edge lines (no row of their own): the cusp −20…+40 clamped per
///   band — magenta 700–780, cyan 760–860, acid 760–920, amber and toxic
///   760–880; chroma 85–100 %, capped at 0.26. Function labels: the cusp
///   +0…+60 clamped — magenta 700–760, cyan 800–860, acid 800–920, the
///   rest 800–900 (then solved to the label floor).
const RoleRanges cyberpunkDarkRanges = RoleRanges(
  background: RoleRange(IntRange(130, 185), ChromaRange.abs(20, 55)),
  surfaceOffsetMilli: IntRange(-40, -15),
  surfaceChroma: ChromaRange.abs(12, 33),
  digit: RoleRange(IntRange(205, 260), ChromaRange.abs(25, 36)),
  digitDuotoneChroma: ChromaRange.abs(25, 36),
  function: RoleRange(IntRange(230, 305), ChromaRange.abs(30, 41)),
  operator: RoleRange(IntRange(660, 920), ChromaRange.rel(880, 1000, 280)),
  operatorMonochromeL: IntRange(740, 920),
  equals: RoleRange(IntRange(660, 920), ChromaRange.rel(880, 1000, 280)),
  labelStartLMilli: 965,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(880, 1000, 280),
  minDigitAboveBackgroundMilli: 60,
  accentCuspOffsetMilli: IntRange(-30, 50),
  accentCuspClampMilli: IntRange(660, 920),
);

/// Hazard (light) ranges, documented as [cyberpunkDarkRanges]:
///
/// - body hue 102–107° (never lime), L 900–925, chroma 95–100 % of the
///   gamut maximum (capped at 0.20);
/// - the HUD screen is an absolute L 150–170, C 0.010–0.015 black at the
///   edge hue (the offset below is from the body);
/// - black plates 170–220 (function 25–45 lighter) at the cyan edge hue;
/// - slabs: cyan 800–860, magenta 660–880 (760–880 under the Accessible
///   lock); one of the two slabs is always magenta;
/// - edge lines and function labels: cyan, 760–860 and 800–860 (the cusp
///   −20…+40 and +0…+40).
const RoleRanges cyberpunkLightRanges = RoleRanges(
  background: RoleRange(IntRange(900, 925), ChromaRange.rel(950, 1000, 200)),
  surfaceOffsetMilli: IntRange(-775, -730),
  surfaceChroma: ChromaRange.abs(10, 15),
  digit: RoleRange(IntRange(170, 220), ChromaRange.abs(8, 22)),
  digitDuotoneChroma: ChromaRange.abs(8, 22),
  function: RoleRange(IntRange(195, 265), ChromaRange.abs(13, 27)),
  operator: RoleRange(IntRange(660, 880), ChromaRange.rel(880, 1000, 280)),
  operatorMonochromeL: IntRange(800, 860),
  equals: RoleRange(IntRange(660, 880), ChromaRange.rel(880, 1000, 280)),
  labelStartLMilli: 160,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(880, 1000, 280),
  minDigitAboveBackgroundMilli: 0,
  accentCuspOffsetMilli: IntRange(-30, 50),
  accentCuspClampMilli: IntRange(660, 880),
);

/// Cyberpunk: chamfered keys (top-left and bottom-right cut, 12–24 % of the
/// short side), dark plates traced by a 1–1.5 dp neon edge with a halo,
/// neon slabs for operators and `=`. Press (Terminal row of the motion
/// brief): `hardPress` in, the neon flares in frame 1 and the plate plunges
/// 2 dp; release 4000/1.0 (seeded × {0.9, 1, 1.1}) while the glow decays
/// like phosphor on `effectsDefault` (< 5 % at 120 ms); glyph entry 115 %
/// → 100 % over 60 ms; `mech_tactile` (no seeded alternate), rigid · 0.6. The palette is built by [buildCyberpunkCandidate].
const FamilyDefinition cyberpunkDefinition = FamilyDefinition(
  family: ThemeFamily.cyberpunk,
  brightnessWeights: [3, 1],
  schemes: [Weighted(HarmonyScheme.complementary, 1)],
  shapes: [Weighted(KeyShapeKind.cut, 1)],
  cornerPermille: cyberCornerPermille,
  styles: [Weighted(KeyStyleKind.flat, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.flat,
    outlineWidthCdp: 125,
    shadowBlurCdp: 400,
    stateLayerPermille: 0,
  ),
  displayFonts: [Weighted(FontIds.oxanium, 1)],
  keyFonts: [Weighted(FontIds.oxanium, 1)],
  displayWeight: IntRange(450, 600),
  keyWeight: IntRange(500, 600),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [Weighted(BackgroundKind.cyberGrid, 1)],
  sound: SoundPackId.mechTactile,
  dark: cyberpunkDarkRanges,
  light: cyberpunkLightRanges,
  motion: MotionSpec(
    verb: PressVerb.plunge,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.hardPress,
    release: SpringToken(4000, 1000),
    depthCdp: 200,
    entry: EntryStyle.glyph,
    entryScalePermille: 1150,
    fx: PressFx.afterglow,
    impact: ImpactStyle.rigid,
    impactPermille: 600,
  ),
  motionRanges: MotionRanges(),
  nonColourOperatorCue: OperatorCue.outline,
  bile: BileRule.v2,
);

// --------------------------------------------------------------- helpers --

int _wrap(int tenths) => tenths % 3600;

/// `min(rel/1000 · maxChroma(l, h), cap/1000)`.
double _relC(int rel, int capMilli, double l, double hDeg) {
  final c = rel / 1000 * maxChroma(l, hDeg);
  final cap = capMilli / 1000;
  return c < cap ? c : cap;
}

/// Cusp lightness per hue tenth ([neoBrutalCuspLMilli]), memoised: a pure
/// function of the hue, so the cache never changes any result.
final List<int> _cuspCache = List.filled(3600, -1);

int _cuspL(int hueTenths) {
  final h = _wrap(hueTenths);
  final hit = _cuspCache[h];
  if (hit >= 0) return hit;
  return _cuspCache[h] = neoBrutalCuspLMilli(h / 10);
}

bool _opaque(int argb) => ((argb >>> 24) & 0xFF) == 255;

int _alpha(int argb) => (argb >>> 24) & 0xFF;

double _minContrastOver(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

/// The hot rim of a dark-theme slab: `oklch(min(0.97, L + 0.09), 0.55·C, h)`
/// of its final face.
int cyberHotRim(int face) {
  final f = argbToOklch(face | 0xFF000000);
  final l = f.l + 0.09 > 0.97 ? 0.97 : f.l + 0.09;
  return oklchToArgb(l, f.c * 0.55, f.h);
}

/// The encoded-sRGB half mix of two opaque colours.
int _mix(int a, int b) {
  int ch(int s) => (((a >> s) & 0xFF) + ((b >> s) & 0xFF) + 1) ~/ 2;
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

// --------------------------------------------------------------- builder --

/// Builds one unvalidated Cyberpunk candidate (the generator repairs and
/// validates it, retries with `palette/retry/n` and finally falls back to
/// a Cyberpunk hero).
ThemeSpec buildCyberpunkCandidate(
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

  // 1–2. Brightness and variant.
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final variant = dark
      ? CyberVariant.values[p.pickWeighted(cyberDarkVariantWeights)]
      : CyberVariant.hazard;

  // 3–7. Neon pair, hues and role scheme. The edge and function hues are
  // derived after the `=` separation (step 17), so they always follow the
  // final `=` hue: the edge is always one of the slab neons.
  final (opBand, pairEqBand) = pickWeightedValue(p, cyberPairs[variant]!);
  final opHue = opBand.hues.sample(p);
  final pairEqHue = pairEqBand.hues.sample(p);
  final edgeFromEq = p.pickWeighted(cyberRoleSchemeWeights) == 0;
  final hazardEdgeHue = dark ? 0 : CyberBand.cyan.hues.sample(p);

  // 8. Body.
  final int bodyL;
  final int bodyH;
  final double bodyC;
  if (dark) {
    bodyL = p.nextIntIn(130, 185);
    bodyH = cyberBodyHueTenths[variant.index].sample(p) % 3600;
    final c = cyberBodyChromaMilli[variant.index].sample(p) / 1000;
    final mx = 0.9 * maxChroma(bodyL / 1000, bodyH / 10);
    bodyC = c < mx ? c : mx;
  } else {
    bodyL = p.nextIntIn(900, 925);
    // 102–107°: the warm yellow of hero 131. From 108° red drops below
    // green (lime); L ≤ 0.925 and a 0.95 chroma factor keep it vivid
    // (C ≈ 0.19), never butter.
    bodyH = p.nextIntIn(1020, 1070);
    bodyC = _relC(p.nextIntIn(950, 1000), 200, bodyL / 1000, bodyH / 10);
  }
  final body = oklchToArgb(bodyL / 1000, bodyC, bodyH / 10);

  // 9. Haze draws (the colour follows the final hues, below).
  final hazeL = dark
      ? bodyL + cyberHazeLiftMilli.sample(p)
      : bodyL - p.nextIntIn(20, 32);
  final hazeCap = dark ? p.nextIntIn(40, 70) : 0;

  // 10–16. Face draws.
  final int digitL;
  if (dark) {
    var l = p.nextIntIn(205, 260);
    if (l < bodyL + 60) l = bodyL + 60;
    digitL = l;
  } else {
    digitL = p.nextIntIn(170, 220);
  }
  // Dark plates keep C ≥ 0.025: below it they read as generic grey
  // dark-mode buttons.
  var digitC = p.nextIntIn(dark ? 25 : 8, dark ? 36 : 22) / 1000;
  final fnL = digitL + p.nextIntIn(25, 45);
  ({int off, int rel}) draw(IntRange off, IntRange rel) =>
      (off: off.sample(p), rel: rel.sample(p));
  final opDraw = draw(const IntRange(-30, 50), const IntRange(880, 1000));
  final eqDraw = draw(const IntRange(-30, 50), const IntRange(880, 1000));
  final edgeDraw = draw(const IntRange(-20, 40), const IntRange(850, 1000));
  final fnDraw = draw(
    dark ? const IntRange(0, 60) : const IntRange(0, 40),
    const IntRange(800, 1000),
  );

  Lch neon(int hue, ({int off, int rel}) d, IntRange clamp, int cap) {
    final l = clamp.clamp(_cuspL(hue) + d.off);
    final c = _relC(d.rel, cap, l / 1000, hue / 10);
    return (l: l / 1000, c: c, h: hue / 10);
  }

  final darkLabel = (l: 0.16, c: 0.03, h: bodyH / 10);
  final yellowLabel = (l: bodyL / 1000, c: bodyC, h: bodyH / 10);

  // A label solved on its face; a final face that reads as bile is
  // rotated out of the band and re-paired.
  KeyColors key(Lch face, Lch label, int edge, {ContrastPolicy? labels}) {
    final use = labels ?? policy;
    var pair = repairPair(face, label, policy: use);
    if (bile.recheckFinal) {
      final f = argbToOklch(pair.face);
      final hue = (f.h * 10).round() % 3600;
      if (bile.dislikes(hue, f.l, f.c)) {
        pair = repairPair(
          (l: f.l, c: f.c, h: bile.apply(hue, f.l, f.c) / 10),
          label,
          policy: use,
        );
      }
    }
    return KeyColors(face: pair.face, label: pair.label, edge: edge);
  }

  // Slabs sit at their hue's chroma cusp: magenta reaches it (L 0.66–0.70,
  // a hot magenta rather than orchid) in normal themes; everything else
  // keeps 0.74 (0.76 on Hazard); every slab is ≥ 0.76 under the
  // Accessible lock (a 7:1 dark label). Acid slabs may rise to 0.92,
  // nearer their cusp (≈ 0.90–0.96): capped at 0.88 a 100–105° acid holds
  // only C ≈ 0.16 and reads as mustard. Cyan stays within 0.80–0.86 in
  // both modes: above 0.86 it leaves the gamut (C ≤ 0.127 at 203°) and
  // turns ice-blue pastel.
  IntRange slabClamp(CyberBand band) {
    if (band == CyberBand.cyan) return const IntRange(800, 860);
    final hi = band == CyberBand.acid ? 920 : 880;
    if (accessible) return IntRange(760, hi);
    if (band == CyberBand.magenta) return const IntRange(660, 880);
    return IntRange(dark ? 740 : 760, hi);
  }

  // Cyan slabs take 95–100 % of the gamut maximum (the 88–100 % draw
  // mapped onto it): any less reads as washed-out ice blue.
  ({int off, int rel}) slabDraw(CyberBand band, ({int off, int rel}) d) =>
      band == CyberBand.cyan
      ? (off: d.off, rel: 950 + ((d.rel - 880) * 50 / 120).round())
      : d;

  final opFace = neon(opHue, slabDraw(opBand, opDraw), slabClamp(opBand), 280);
  final pairEqFace = neon(
    pairEqHue,
    slabDraw(pairEqBand, eqDraw),
    slabClamp(pairEqBand),
    280,
  );
  final operator0 = key(opFace, darkLabel, 0);
  var equals0 = key(pairEqFace, darkLabel, 0);

  // 17. `=` stands apart from the operators (CVD included; no draws). A
  // cyan `=` never darkens (a darker cyan is dull teal, the dimmest key
  // on the board): it moves to the other band instead.
  var eqBand = pairEqBand;
  var eqHue = pairEqHue;
  if (minCvdDeltaE(equals0.face, operator0.face) < 0.065) {
    final opL = argbToOklch(operator0.face).l;
    final clamp = slabClamp(pairEqBand);
    final lo = clamp.lo / 1000;
    final hi = clamp.hi / 1000;
    final first = pairEqFace.l <= opL ? -0.10 : 0.10;
    var done = false;
    for (final dl in [first, -first, first * 1.4, -first * 1.4, first * 1.8]) {
      if (pairEqBand == CyberBand.cyan && dl < 0) continue;
      final l = pairEqFace.l + dl;
      if (l < lo || l > hi) continue;
      final k = key((l: l, c: pairEqFace.c, h: pairEqFace.h), darkLabel, 0);
      if (minCvdDeltaE(k.face, operator0.face) >= 0.065) {
        equals0 = k;
        done = true;
        break;
      }
    }
    if (!done) {
      eqBand = opBand == CyberBand.magenta ? CyberBand.cyan : CyberBand.magenta;
      eqHue = (eqBand.hues.lo + eqBand.hues.hi) ~/ 2;
      final l = slabClamp(eqBand).clamp(_cuspL(eqHue) + 10) / 1000;
      final rel = eqBand == CyberBand.cyan ? 975 : 940;
      equals0 = key(
        (l: l, c: _relC(rel, 280, l, eqHue / 10), h: eqHue / 10),
        darkLabel,
        0,
      );
    }
  }

  // The role scheme on the final hues: dark edges take the `=` neon (and
  // function labels the operator's) or the other way round; Hazard edges
  // and function labels are cyan.
  final edgeHue = dark ? (edgeFromEq ? eqHue : opHue) : hazardEdgeHue;
  final fnHue = dark ? (edgeFromEq ? opHue : eqHue) : edgeHue;
  final edgeBand = dark ? (edgeFromEq ? eqBand : opBand) : CyberBand.cyan;
  final fnBand = dark ? (edgeFromEq ? opBand : eqBand) : CyberBand.cyan;

  // 9. Haze (the gradient's bottom stop). Warm edge bands never tint the
  // dark haze (dark acid reads as olive, dark amber as brown): it takes
  // the pair's other neon.
  final int haze;
  final int hazeH;
  if (dark) {
    hazeH = edgeBand == CyberBand.amber || edgeBand == CyberBand.acid
        ? fnHue
        : edgeHue;
    haze = oklchToArgb(
      hazeL / 1000,
      _relC(1000, hazeCap, hazeL / 1000, hazeH / 10),
      hazeH / 10,
    );
  } else {
    hazeH = _wrap(bodyH - 40);
    haze = oklchToArgb(
      hazeL / 1000,
      _relC(1000, (bodyC * 1000).round() + 10, hazeL / 1000, hazeH / 10),
      hazeH / 10,
    );
  }

  // Plates.
  final plateHue = dark ? bodyH : edgeHue;
  {
    final mx = 0.9 * maxChroma(digitL / 1000, plateHue / 10);
    if (digitC > mx) digitC = mx;
  }
  final digitFace = (l: digitL / 1000, c: digitC, h: plateHue / 10);
  final fnFace = (l: fnL / 1000, c: digitC + 0.005, h: plateHue / 10);

  // Neon lines and labels. Acid may sit nearer its cusp (see slabClamp);
  // cyan stops at 0.86 (gamut); magenta edges sit at 0.70–0.78 and
  // magenta function labels at 0.70–0.76: a hot pink, never the lavender
  // or pastel pink of Vaporwave (≥ 5.4:1 on the plates; the Accessible
  // lock's label solve lifts them to 7:1).
  final edgeNeon = neon(edgeHue, edgeDraw, switch (edgeBand) {
    CyberBand.acid => const IntRange(760, 920),
    CyberBand.cyan => const IntRange(760, 860),
    CyberBand.magenta => const IntRange(700, 780),
    _ => const IntRange(760, 880),
  }, 260);
  final fnNeon = neon(fnHue, fnDraw, switch (fnBand) {
    CyberBand.acid => const IntRange(800, 920),
    CyberBand.cyan => const IntRange(800, 860),
    CyberBand.magenta => const IntRange(700, 760),
    _ => const IntRange(800, 900),
  }, 240);
  final lightLabel = (l: 0.965, c: 0.022, h: edgeHue / 10);

  final edgeArgb = oklchToArgb(edgeNeon.l, edgeNeon.c, edgeNeon.h);
  final blackEdge = oklchToArgb(0.17, 0.02, bodyH / 10);
  int slabEdge(int face) => dark ? cyberHotRim(face) : blackEdge;

  var digit = key(digitFace, dark ? lightLabel : yellowLabel, edgeArgb);
  // A magenta function label keeps its hot L 0.70–0.76 (≥ 5:1 on the
  // plate) in normal themes: the standard policy's 7:1 dark-face target
  // would lift it to a pastel L ≈ 0.80. The 4.5:1 floor still holds; the
  // Accessible lock solves it to 7:1 as usual.
  var function = key(
    fnFace,
    fnNeon,
    0,
    labels: fnBand == CyberBand.magenta && !accessible
        ? ContrastPolicy(minRatio: lim.labelRatio, darkFaceBoost: false)
        : null,
  );
  function = function.copyWith(edge: function.label);
  final operator = operator0.copyWith(edge: slabEdge(operator0.face));
  final equals = equals0.copyWith(edge: slabEdge(equals0.face));

  // 18. The HUD panel: a recessed screen darker than the body (dark); on
  // Hazard a cyan-tinted black screen (L 0.150–0.170) just below the
  // plates, so the display reads as the same black HUD hardware as the
  // keys rather than a light card on a saturated body.
  final int panel;
  if (dark) {
    var l = bodyL - p.nextIntIn(15, 40);
    if (l < 95) l = 95;
    panel = oklchToArgb(l / 1000, bodyC * 0.6, bodyH / 10);
  } else {
    final off = p.nextIntIn(35, 55);
    final ratio = p.nextIntIn(550, 700);
    panel = oklchToArgb(
      (150 + off - 35) / 1000,
      0.010 + (ratio - 550) / 30000,
      edgeHue / 10,
    );
  }

  // Scene inks: alphas from the background stream, identical across
  // palette retries.
  final b = Rng.stream(seed, RngTag.background);
  final kind = pickWeightedValue(b, def.backgrounds);
  final angle = (3600 + b.nextIntIn(-200, 200)) % 3600;
  // Hazard has no grid (a black grid on yellow is Neo-brutalism's poster);
  // the draw is kept so both brightnesses read the stream alike.
  final gridDraw = b.nextIntIn(12, 18);
  final gridA = dark ? gridDraw : 0;
  final traceA = dark ? b.nextIntIn(40, 64) : b.nextIntIn(28, 40);
  final scanA = dark ? b.nextIntIn(24, 36) : b.nextIntIn(12, 18);
  final panelScanA = b.nextIntIn(30, 40);
  // The grid takes the haze hue (an amber or acid grid on plum reads as
  // brown).
  final grid = withAlpha(
    dark
        ? oklchToArgb(0.72, _relC(1000, 120, 0.72, hazeH / 10), hazeH / 10)
        : oklchToArgb(0.22, 0.03, bodyH / 10),
    gridA,
  );
  final trace = withAlpha(
    dark
        ? oklchToArgb(0.72, _relC(1000, 160, 0.72, opHue / 10), opHue / 10)
        : oklchToArgb(0.24, 0.04, bodyH / 10),
    traceA,
  );
  // Dark scanlines are lighter rows (a dark ink on near-black would be
  // invisible); Hazard's scene scanlines are darker rows on the yellow
  // body. Panel scanlines are lighter rows on every (black) screen.
  final scanInk = dark
      ? oklchToArgb(0.45, _relC(1000, 80, 0.45, hazeH / 10), hazeH / 10)
      : oklchToArgb(0.35, 0.045, _wrap(bodyH - 100) / 10);
  final panelScanInk = dark
      ? scanInk
      : oklchToArgb(0.45, _relC(1000, 80, 0.45, edgeHue / 10), edgeHue / 10);
  final background = BackgroundSpec(
    kind: kind,
    colors: List.unmodifiable([
      body,
      haze,
      grid,
      trace,
      withAlpha(scanInk, scanA),
    ]),
    angleTenths: angle,
  );
  final shadow = withAlpha(panelScanInk, accessible ? 0 : panelScanA);

  // Display texts: on the panel and its scanline composite; dark display
  // text passes on every scene sample too. Hazard's yellow text lives on
  // its black screen only (the panel is opaque under every glyph).
  final samples = cyberGridSamples(background.colors);

  // Neon lines are the dark plates' key boundary (a plate is about as
  // dark as the scene): a line short of 3:1 on a scene sample — a magenta
  // at L 0.70 over a trace on a major grid line — is lifted until it holds
  // (hue and chroma kept; no draws). The function edge stays its label.
  // Hazard's black plates are their own boundary on the yellow body.
  int boundaryLine(int c) => solveOnAll(c, samples, ratioLarge) ?? c;
  if (_minContrastOver(digit.face, samples) < ratioLarge) {
    digit = digit.copyWith(edge: boundaryLine(digit.edge));
  }
  if (_minContrastOver(function.face, samples) < ratioLarge) {
    final label = boundaryLine(function.label);
    function = function.copyWith(label: label, edge: label);
  }
  final backdrops = [panel, compositeOver(shadow, panel), if (dark) ...samples];
  int on(int start, double target) =>
      solveOnAll(start, backdrops, target) ?? blackOrWhite(panel);
  final displayText = on(
    dark
        ? oklchToArgb(0.965, 0.02, edgeHue / 10)
        : oklchToArgb(bodyL / 1000, bodyC, bodyH / 10),
    lim.displayRatio,
  );
  final previewText = on(
    dark
        ? oklchToArgb(0.80, _relC(1000, 120, 0.80, edgeHue / 10), edgeHue / 10)
        : oklchToArgb(0.82, _relC(800, 140, 0.82, edgeHue / 10), edgeHue / 10),
    _previewTarget(lim),
  );
  final error = on(oklchToArgb(0.76, 0.15, 20), lim.displayRatio);
  // The caret: the operator neon (dark), the magenta slab neon (Hazard,
  // whose pair always has one, also after step 17). A magenta caret sits
  // at L 0.74 (hot pink); 0.84 would be pastel.
  final caretMagenta = !dark || opBand == CyberBand.magenta;
  final caretHue = dark || opBand == CyberBand.magenta ? opHue : eqHue;
  final caretL = caretMagenta ? 0.74 : 0.84;
  final caret = on(
    oklchToArgb(caretL, _relC(800, 220, caretL, caretHue / 10), caretHue / 10),
    lim.caretRatio,
  );
  final focus =
      solveOnAll(dark ? digit.edge : blackEdge, samples, lim.focusRingRatio) ??
      blackOrWhite(body);

  final palette = Palette(
    background: body,
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
    shadow: shadow,
    highlight: 0x00000000,
    seedColor: operator.face,
  );

  // Motion, shape, style, type, name, sound.
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
    outlineWidthCdp: cyberEdgeWidthCdp.sampleStep(st, 25),
    shadowBlurCdp: cyberHaloBlurCdp.sampleStep(st, 50),
  );
  final type = _type(Rng.stream(seed, RngTag.type), def);
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: operator.face,
    family: ThemeFamily.cyberpunk,
    dark: dark,
  );
  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.cyberpunk,
    engineVersion: engineVersion,
    brightness: dark ? ThemeBrightness.dark : ThemeBrightness.light,
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

/// The preview text target: the limit's preview ratio, never below body
/// text (4.5:1); the builder and the repair solve to the same target.
double _previewTarget(GuardrailLimits lim) =>
    lim.previewRatio < ratioText ? ratioText : lim.previewRatio;

/// One squared techno face for display and keys (a coherent HUD): display
/// 450–600, keys 500–600, operators + 200–300 capped at Oxanium's 800 (the
/// bonus stays ≥ 200 because keys are ≤ 600).
TypeSpec _type(Rng t, FamilyDefinition def) {
  final font = pickWeightedValue(t, def.displayFonts);
  final displayWeight = def.displayWeight.sampleStep(t, 50);
  final keyWeight = def.keyWeight.sampleStep(t, 50);
  final opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  return TypeSpec(
    displayFont: font,
    keyFont: font,
    displayWeight: displayWeight,
    keyWeight: keyWeight,
    operatorWeight: opWeight > cyberOperatorWeightMax
        ? cyberOperatorWeightMax
        : opWeight,
    slashedZero: t.nextChance(1, 2),
  );
}

// --------------------------------------------------------------- samples --

/// The 36 opaque colours a key edge, focus ring, toolbar icon or display
/// backdrop can sit over in a cyber grid with [colors] (`[body, haze,
/// grid, trace, scan]`), in the renderer's paint order (⊕ =
/// `compositeOver`): for each stop s in {body, haze, their encoded-sRGB
/// half mix}, the bare stop, a grid line g⊕s and a major grid line g⊕g⊕s
/// (every fourth line is drawn twice), each with and without a trace over
/// it, and the scanline ink over each of those six.
List<int> cyberGridSamples(List<int> colors) {
  final c0 = colors[0] | 0xFF000000;
  final c1 = colors[1] | 0xFF000000;
  final g = colors[2];
  final t = colors[3];
  final k = colors[4];
  final out = <int>[];
  for (final s in [c0, c1, _mix(c0, c1)]) {
    final gs = compositeOver(g, s);
    final ggs = compositeOver(g, gs);
    for (final base in [s, gs, ggs]) {
      final ts = compositeOver(t, base);
      out.addAll([base, ts, compositeOver(k, base), compositeOver(k, ts)]);
    }
  }
  return out;
}

/// Guardrail background samples of the family's scene
/// (`BackgroundKind.cyberGrid`): [cyberGridSamples]. Null (the generic
/// sampling) for a malformed scene without its five colours; `cyberScene`
/// rejects those.
List<int>? cyberpunkSceneSamples(BackgroundSpec bg) =>
    bg.colors.length == 5 ? cyberGridSamples(bg.colors) : null;

/// Everything display text of [spec] may be drawn on: the HUD panel
/// ([surfaces]) and the panel under its scanline ink (`palette.shadow`);
/// dark themes add every scene sample ([bgs]; their display text passes on
/// the bare scene too). Hazard's yellow display text sits only on its
/// opaque black screen, never on the yellow body.
List<int>? cyberpunkDisplayBackdrops(
  ThemeSpec spec,
  List<int> surfaces,
  List<int> bgs,
) {
  final scan = spec.palette.shadow;
  return [
    for (final s in surfaces) ...[s, compositeOver(scan, s)],
    if (spec.brightness == ThemeBrightness.dark) ...bgs,
  ];
}

// ------------------------------------------------------------ guardrails --

/// The family-specific guardrails (called from `validateTheme` for
/// [ThemeFamily.cyberpunk] specs only):
///
/// - `cyberOperatorCue`: the recorded fill-versus-outline cue is real.
///   Digit and function faces are opaque plates (L ≤ [cyberPlateMaxL])
///   with labels lighter than the face; operator and `=` faces are opaque
///   slabs (L ≥ [cyberSlabMinL]) with darker labels and ≥ 3:1 against the
///   digit plate; operators are ≥ 200 heavier.
/// - `cyberEdge`: the plate edge lines that carry the cue are opaque and
///   ≥ 3:1 against their faces, 1–1.5 dp wide.
/// - `cyberKeyBoundary`: every key group's face or opaque edge reaches
///   3:1 against every scene sample (WCAG 1.4.11).
/// - `cyberScene`: the scene is a static `cyberGrid` with five colours,
///   opaque stops, inks under their alpha ceilings and a tilt within ±20°;
///   the panel scanline alpha is ≤ [cyberPanelScanMaxAlpha] (0 under the
///   Accessible lock); keys are `cut` with chamfer 12–24 % and no generic
///   state layer.
List<GuardrailViolation> validateCyberpunk(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final out = <GuardrailViolation>[];
  final p = spec.palette;
  final plates = {'digit': p.digit, 'function': p.function};
  final slabs = {'operator': p.operator, 'equals': p.equals};

  // cyberOperatorCue.
  for (final MapEntry(key: name, value: k) in plates.entries) {
    final l = argbToOklch(k.face | 0xFF000000).l;
    if (!_opaque(k.face) ||
        l > cyberPlateMaxL ||
        luminanceArgb(k.label | 0xFF000000) <= luminanceArgb(k.face)) {
      out.add(
        GuardrailViolation(
          GuardrailRule.cyberOperatorCue,
          l,
          cyberPlateMaxL,
          '$name plate (opaque, L ≤ $cyberPlateMaxL, lighter label)',
        ),
      );
    }
  }
  for (final MapEntry(key: name, value: k) in slabs.entries) {
    final l = argbToOklch(k.face | 0xFF000000).l;
    if (!_opaque(k.face) ||
        l < cyberSlabMinL ||
        luminanceArgb(k.label | 0xFF000000) >= luminanceArgb(k.face)) {
      out.add(
        GuardrailViolation(
          GuardrailRule.cyberOperatorCue,
          l,
          cyberSlabMinL,
          '$name slab (opaque, L ≥ $cyberSlabMinL, darker label)',
        ),
      );
    }
    final cr = contrastRatio(k.face | 0xFF000000, p.digit.face | 0xFF000000);
    if (cr < cyberSlabVsPlateRatio) {
      out.add(
        GuardrailViolation(
          GuardrailRule.cyberOperatorCue,
          cr,
          cyberSlabVsPlateRatio,
          '$name slab vs digit plate',
        ),
      );
    }
  }
  final bonus = spec.type.operatorWeight - spec.type.keyWeight;
  if (bonus < 200) {
    out.add(
      GuardrailViolation(
        GuardrailRule.cyberOperatorCue,
        bonus.toDouble(),
        200,
        'operator weight bonus',
      ),
    );
  }

  // cyberEdge.
  for (final MapEntry(key: name, value: k) in plates.entries) {
    final ratio = _opaque(k.edge) ? contrastRatio(k.edge, k.face) : 1.0;
    if (ratio < ratioLarge) {
      out.add(
        GuardrailViolation(GuardrailRule.cyberEdge, ratio, ratioLarge, name),
      );
    }
  }
  final width = spec.keyStyle.outlineWidthCdp;
  if (!cyberEdgeWidthCdp.contains(width)) {
    out.add(
      GuardrailViolation(
        GuardrailRule.cyberEdge,
        width / 100,
        cyberEdgeWidthCdp.lo / 100,
        'edge width (dp)',
      ),
    );
  }

  // cyberKeyBoundary.
  for (final MapEntry(key: name, value: k) in {...plates, ...slabs}.entries) {
    final face = _opaque(k.face) ? _minContrastOver(k.face, bgs) : 1.0;
    final edge = _opaque(k.edge) ? _minContrastOver(k.edge, bgs) : 1.0;
    if (face < ratioLarge && edge < ratioLarge) {
      out.add(
        GuardrailViolation(
          GuardrailRule.cyberKeyBoundary,
          face > edge ? face : edge,
          ratioLarge,
          name,
        ),
      );
    }
  }

  // cyberScene.
  void scene(String detail, [double measured = 0, double required = 0]) =>
      out.add(
        GuardrailViolation(
          GuardrailRule.cyberScene,
          measured,
          required,
          detail,
        ),
      );
  final bg = spec.background;
  if (bg.kind != BackgroundKind.cyberGrid) scene('kind ${bg.kind.name}');
  if (bg.colors.length != 5) {
    scene('colours', bg.colors.length.toDouble(), 5);
  } else {
    if (!_opaque(bg.colors[0]) || !_opaque(bg.colors[1])) scene('stops');
    for (final (i, cap) in [
      (2, cyberGridMaxAlpha),
      (3, cyberTraceMaxAlpha),
      (4, cyberScanMaxAlpha),
    ]) {
      final a = _alpha(bg.colors[i]);
      if (a > cap) scene('ink $i alpha', a.toDouble(), cap.toDouble());
    }
  }
  final angle = bg.angleTenths % 3600;
  if (angle > cyberMaxAngleTenths && angle < 3600 - cyberMaxAngleTenths) {
    scene('angle', angle.toDouble(), cyberMaxAngleTenths.toDouble());
  }
  if (bg.driftPeriodMs != 0) scene('drift', bg.driftPeriodMs.toDouble());
  final scanAlpha = _alpha(p.shadow);
  if (scanAlpha > cyberPanelScanMaxAlpha ||
      (spec.accessible && scanAlpha != 0)) {
    scene(
      'panel scanline alpha',
      scanAlpha.toDouble(),
      spec.accessible ? 0 : cyberPanelScanMaxAlpha.toDouble(),
    );
  }
  if (spec.keyShape.kind != KeyShapeKind.cut ||
      !cyberCornerPermille.contains(spec.keyShape.cornerPermille)) {
    scene('shape', spec.keyShape.cornerPermille.toDouble());
  }
  if (spec.keyStyle.stateLayerPermille != 0) scene('state layer');
  return out;
}

/// Family repairs after labels and display texts (called from
/// `repairTheme` for [ThemeFamily.cyberpunk] specs only); null when
/// unreachable:
///
/// 1. the panel scanline alpha drops to 0 under the Accessible lock (and to
///    its ceiling otherwise);
/// 2. derived edges follow the final faces: the function edge is the
///    function label, dark slab rims are re-lit from their faces (Hazard
///    keeps its black boundary);
/// 3. display, error, preview and caret are re-solved on
///    [cyberpunkDisplayBackdrops] (preview to the builder's 4.5:1);
/// 4. plate edges are re-solved to 3:1 on their face (and on the scene when
///    the face is no key boundary); a slab edge is re-solved on the scene
///    when neither its face nor its edge is one.
///
/// Cue failures are not repaired: they force a retry.
Palette? repairCyberpunkExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final alpha = _alpha(p.shadow);
  final scanAlpha = spec.accessible
      ? 0
      : (alpha > cyberPanelScanMaxAlpha ? cyberPanelScanMaxAlpha : alpha);
  var out = p.copyWith(shadow: withAlpha(p.shadow, scanAlpha));
  final dark = spec.brightness == ThemeBrightness.dark;
  KeyColors relit(KeyColors k) =>
      dark && _opaque(k.face) ? k.copyWith(edge: cyberHotRim(k.face)) : k;
  out = out.copyWith(
    function: out.function.copyWith(edge: out.function.label),
    operator: relit(out.operator),
    equals: relit(out.equals),
  );

  final surfaces = _opaque(out.surface)
      ? [out.surface]
      : [for (final b in bgs) compositeOver(out.surface, b)];
  final backdrops = cyberpunkDisplayBackdrops(
    spec.copyWith(palette: out),
    surfaces,
    bgs,
  )!;
  final display = solveOnAll(out.displayText, backdrops, lim.displayRatio);
  final error = solveOnAll(out.error, backdrops, lim.displayRatio);
  final preview = solveOnAll(out.previewText, backdrops, _previewTarget(lim));
  final caret = solveOnAll(out.caret, backdrops, lim.caretRatio);
  if (display == null || error == null || preview == null || caret == null) {
    return null;
  }

  bool boundary(int c) => _opaque(c) && _minContrastOver(c, bgs) >= ratioLarge;
  KeyColors? plate(KeyColors k) {
    if (!_opaque(k.face)) return null;
    final on = [k.face, if (!boundary(k.face)) ...bgs];
    final edge = solveOnAll(k.edge | 0xFF000000, on, ratioLarge);
    return edge == null ? null : k.copyWith(edge: edge);
  }

  KeyColors? slab(KeyColors k) {
    if (boundary(k.face) || boundary(k.edge)) return k;
    final edge = solveOnAll(k.edge | 0xFF000000, bgs, ratioLarge);
    return edge == null ? null : k.copyWith(edge: edge);
  }

  final digit = plate(out.digit);
  final function = plate(out.function);
  final operator = slab(out.operator);
  final equals = slab(out.equals);
  if (digit == null || function == null || operator == null || equals == null) {
    return null;
  }
  return out.copyWith(
    displayText: display,
    error: error,
    previewText: preview,
    caret: caret,
    digit: digit,
    function: function,
    operator: operator,
    equals: equals,
  );
}
