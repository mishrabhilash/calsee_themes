/// The Liquid Glass family (spec §5.3 #2; motion brief §2.3 "Liquid
/// Glass"): translucent keys over a vivid, slowly drifting mesh-gradient
/// background, with specular highlights, a refraction hint and a jelly
/// press. Glass is for the controls: the display sits on a solid-enough
/// backing panel.
///
/// - **Background**: a mesh of a deep (dark themes) or pale (light themes)
///   base and three vivid colour blobs ([BackgroundKind.meshGradient]),
///   hues from the harmony scheme. It drifts on a 40–60 s cycle at runtime
///   (never under Reduce Motion or with ambient motion off).
/// - **Keys**: glass tints — translucent `KeyColors.face` ARGB — smoky
///   dark glass (dark themes) or milky white glass (light themes) for
///   digits, a second tone for function keys, vivid accent glass for the
///   operators and a denser jewel `=`. Rims (`KeyColors.edge`) are
///   decorative light catchers, or opaque and ≥ 3:1 under the Accessible
///   lock.
/// - **Display**: the palette `surface`, translucent but dense; every
///   display text is solved on the surface composited over the background
///   (`displayBackdrops`).
///
/// **Guardrails on composited colours** (research theme-engine.md:
/// contrast over translucent surfaces). A mesh blends its colours in every
/// proportion, so its samples are its colour hull ([meshHullSamples]):
/// the stops, every pairwise quarter point and every three-way centroid in
/// encoded sRGB (what the renderer's gradients blend in). Its darkest and
/// lightest points can lie *between* stops (encoded-sRGB blends of two
/// saturated colours are darker than either), which is why the stops alone
/// are not enough. Labels are checked on each tint composited over every
/// hull sample (4.5:1, 7:1 accessible), the display on the surface over
/// every sample, plus the glass rules in [validateGlass]: labels ≥ 3:1
/// under the peak press glow, operator / `=` tints distinct from the digit
/// tint over the same sample (ΔEOK ≥ 0.08 under every CVD), an honest
/// weight cue, and opaque ≥ 3:1 rims under the Accessible lock.
///
/// The renderer keeps those numbers true: the label zone (the middle 40 %
/// of the key's height, [glassLabelZoneTop]–[glassLabelZoneBottom]) shows
/// exactly the tint over the background; the specular highlight and
/// bottom caustic stay outside it; edge thickening only moves the face away
/// from its label; the frost underlay ([KeyStyleSpec.frostPermille]) is
/// the background's base colour, so a frosted face is still the tint over a
/// point of the hull; Reduce Transparency's solid tint is the tint
/// composited over the base colour, itself a hull sample.
///
/// Every draw comes from the generator's named sub-streams (`palette` with
/// its retry streams, `background`, `shape`, `style`, `type`, `motion`,
/// `name`), so a theme is a pure function of (seed, engineVersion,
/// accessible). The constants here are part of engine version 2's Liquid
/// Glass definition: changing one changes generated themes.
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

// --------------------------------------------------------------- tables --

/// Top of the label zone as a fraction of the key's height: the renderer
/// paints nothing but the tint (and the press glow) between this and
/// [glassLabelZoneBottom].
const double glassLabelZoneTop = 0.30;

/// Bottom of the label zone (see [glassLabelZoneTop]).
const double glassLabelZoneBottom = 0.70;

/// The floor for key labels while the press glow lights the face (a
/// transient state under the finger; WCAG 1.4.11 level).
const double glassPressedLabelRatio = ratioLarge;

/// Peak press-glow alpha range (`Palette.highlight`'s alpha, 0–255): the
/// motion brief's "+12 % luminance" glow core.
const IntRange glassGlowAlpha = IntRange(40, 60);

/// Dark mesh: blob lightness (× 1000) and relative chroma (× 1000 of
/// `maxChroma`, capped at [glassBlobChromaCapMilli]).
const IntRange glassDarkBlobLMilli = IntRange(380, 560);

/// Light mesh: blob lightness (× 1000).
const IntRange glassLightBlobLMilli = IntRange(740, 870);

/// Blob relative chroma, dark and light.
const IntRange glassDarkBlobChroma = IntRange(750, 1000);
const IntRange glassLightBlobChroma = IntRange(650, 950);

/// Blob absolute chroma caps (thousandths), dark and light.
const int glassBlobChromaCapMilli = 220;
const int glassLightBlobChromaCapMilli = 170;

/// Mesh drift period range, ms (motion brief §4.13: a cycle of ≥ 40 s).
const IntRange glassDriftPeriodMs = IntRange(40000, 60000);

/// Display surface (the backing panel): lightness × 1000 and the starting
/// alpha; the alpha then rises in steps of 10 until the display text
/// reaches its floor (+ 0.15) on every composited sample — glass where
/// the background allows it, denser where it must be.
const IntRange glassDarkSurfaceLMilli = IntRange(140, 220);
const IntRange glassLightSurfaceLMilli = IntRange(975, 995);
const IntRange glassDarkSurfaceAlpha = IntRange(140, 180);
const IntRange glassLightSurfaceAlpha = IntRange(140, 180);

/// Tint alphas (0–255) per role, dark and light.
const IntRange glassDarkDigitAlpha = IntRange(62, 100);
const IntRange glassDarkFunctionAlpha = IntRange(96, 130);
const IntRange glassDarkOperatorAlpha = IntRange(168, 204);
const IntRange glassDarkEqualsAlpha = IntRange(220, 240);
const IntRange glassLightDigitAlpha = IntRange(112, 160);
const IntRange glassLightFunctionAlpha = IntRange(150, 190);
const IntRange glassLightOperatorAlpha = IntRange(212, 232);
const IntRange glassLightEqualsAlpha = IntRange(228, 244);

/// Frost (backdrop diffusion) × 1000, dark and light.
const IntRange glassDarkFrost = IntRange(0, 200);
const IntRange glassLightFrost = IntRange(100, 300);

/// Specular highlight and refraction strengths × 1000.
const IntRange glassHighlight = IntRange(450, 800);
const IntRange glassRefraction = IntRange(350, 750);

/// Blob hue offsets (tenths) per harmony scheme: blob 1, blob 2, blob 3.
/// Operators take blob 2's hue, `=` blob 3's.
List<int> glassBlobOffsets(HarmonyScheme scheme) => switch (scheme) {
  HarmonyScheme.monochrome => const [0, 150, -150],
  HarmonyScheme.analogous => const [0, 400, -400],
  HarmonyScheme.complementary => const [0, 1800, 300],
  HarmonyScheme.splitComplementary => const [0, 1500, 2100],
  HarmonyScheme.triadic => const [0, 1200, 2400],
  HarmonyScheme.duotone => const [0, 1800, 1800],
};

// ------------------------------------------------------------ definition --

/// Liquid Glass dark ranges (only what [buildGlassCandidate] reads): the
/// mesh base (`background`), the digit, function, operator and `=` tints,
/// label start and chroma. Tints are composited over the background, so
/// their lightness is the *glass's* colour, not the face the eye sees.
const RoleRanges glassDarkRanges = RoleRanges(
  background: RoleRange(IntRange(150, 230), ChromaRange.abs(30, 70)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(10, 30),
  digit: RoleRange(IntRange(60, 140), ChromaRange.abs(5, 20)),
  digitDuotoneChroma: ChromaRange.abs(5, 20),
  function: RoleRange(IntRange(260, 340), ChromaRange.abs(20, 50)),
  operator: RoleRange(IntRange(640, 780), ChromaRange.rel(750, 950, 220)),
  operatorMonochromeL: IntRange(640, 780),
  equals: RoleRange(IntRange(720, 860), ChromaRange.rel(700, 950, 200)),
  labelStartLMilli: 970,
  labelMaxChromaMilli: 20,
  accentChroma: ChromaRange.rel(700, 950, 200),
  minDigitAboveBackgroundMilli: 0,
);

/// Liquid Glass light ranges (see [glassDarkRanges]).
const RoleRanges glassLightRanges = RoleRanges(
  background: RoleRange(IntRange(950, 985), ChromaRange.abs(10, 30)),
  surfaceOffsetMilli: IntRange(0, 0),
  surfaceChroma: ChromaRange.abs(5, 15),
  digit: RoleRange(IntRange(990, 1000), ChromaRange.abs(0, 8)),
  digitDuotoneChroma: ChromaRange.abs(0, 8),
  function: RoleRange(IntRange(840, 900), ChromaRange.abs(20, 50)),
  operator: RoleRange(IntRange(480, 600), ChromaRange.rel(750, 950, 200)),
  operatorMonochromeL: IntRange(480, 600),
  equals: RoleRange(IntRange(420, 540), ChromaRange.rel(750, 950, 200)),
  labelStartLMilli: 200,
  labelMaxChromaMilli: 30,
  accentChroma: ChromaRange.rel(650, 900, 160),
  minDigitAboveBackgroundMilli: 0,
);

/// Liquid Glass (spec §5.3 #2; motion brief §2.3 "Liquid Glass"):
/// translucent glass keys over a vivid drifting mesh, specular highlight
/// and refraction rim, display on a solid-enough backing.
///
/// Motion: **inflate** to s = min(1.08, 1 + (gap − 2 dp)/key) — X = s,
/// Y = 1 + 0.75 (s − 1) — on the glass press spring 1755/0.85 (never
/// seeded); the glow core snaps to 50 % in frame 1 and ramps to 100 %;
/// release X on 439/0.65 (seeded × {0.9, 1, 1.1}, bounce ± 0.05) and Y on
/// 439/0.80, whose de-sync is the jelly. Rise 6 dp entry. Sound `glass`,
/// haptic soft · 0.7. Operators always carry a heavier label
/// ([OperatorCue.weight]). The palette is built by [buildGlassCandidate].
const FamilyDefinition liquidGlassDefinition = FamilyDefinition(
  family: ThemeFamily.liquidGlass,
  brightnessWeights: [3, 2],
  schemes: [
    Weighted(HarmonyScheme.analogous, 3),
    Weighted(HarmonyScheme.complementary, 2),
    Weighted(HarmonyScheme.splitComplementary, 2),
    Weighted(HarmonyScheme.triadic, 2),
  ],
  shapes: [
    Weighted(KeyShapeKind.circle, 3),
    Weighted(KeyShapeKind.roundedRect, 2),
  ],
  cornerPermille: IntRange(300, 420),
  styles: [Weighted(KeyStyleKind.glass, 1)],
  keyStyle: KeyStyleSpec(
    kind: KeyStyleKind.glass,
    outlineWidthCdp: 125,
    shadowOffsetCdp: 250,
    shadowBlurCdp: 800,
    stateLayerPermille: 80,
    frostPermille: 150,
    highlightPermille: 600,
    refractionPermille: 500,
  ),
  displayFonts: [Weighted(FontIds.robotoFlex, 1)],
  keyFonts: [
    Weighted(FontIds.robotoFlex, 3),
    Weighted(FontIds.spaceGrotesk, 1),
  ],
  displayWeight: IntRange(250, 350),
  keyWeight: IntRange(400, 500),
  operatorWeightBonus: IntRange(200, 300),
  backgrounds: [Weighted(BackgroundKind.meshGradient, 1)],
  sound: SoundPackId.glass,
  dark: glassDarkRanges,
  light: glassLightRanges,
  motion: MotionSpec(
    verb: PressVerb.inflate,
    scheme: MotionScheme.standard,
    pressIn: SpringTokens.glassPressIn,
    release: SpringToken(439, 650),
    releaseAlt: SpringToken(439, 800),
    scalePermille: 1080,
    entry: EntryStyle.rise,
    entryOffsetCdp: 600,
    entrySpring: SpringTokens.effectsDefault,
    fx: PressFx.glow,
    impact: ImpactStyle.soft,
    impactPermille: 700,
  ),
  motionRanges: MotionRanges(bounceJitterPermille: 50),
  nonColourOperatorCue: OperatorCue.weight,
  bile: BileRule.v2,
);

// ----------------------------------------------------------- mesh samples --

int _mix(int a, int b, int wa, int wb, int total) {
  int ch(int shift) =>
      (((a >> shift) & 0xFF) * wa + ((b >> shift) & 0xFF) * wb + total ~/ 2) ~/
      total;
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

int _centroid(int a, int b, int c) {
  int ch(int shift) =>
      (((a >> shift) & 0xFF) +
          ((b >> shift) & 0xFF) +
          ((c >> shift) & 0xFF) +
          1) ~/
      3;
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

/// The colour hull of a mesh with opaque [stops], sampled: every stop,
/// every pairwise ¼ / ½ / ¾ point and every three-way centroid, blended in
/// encoded sRGB (integer arithmetic, bit-exact). The darkest and lightest
/// colours a mesh can paint are among (or within a hair of) these.
List<int> meshHullSamples(List<int> stops) {
  final out = <int>[...stops];
  final n = stops.length;
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      for (var k = 1; k <= 3; k++) {
        out.add(_mix(stops[i], stops[j], 4 - k, k, 4));
      }
    }
  }
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      for (var k = j + 1; k < n; k++) {
        out.add(_centroid(stops[i], stops[j], stops[k]));
      }
    }
  }
  return out;
}

/// The colour glass diffuses the background to: the three-way centroid
/// of a mesh's blobs (exactly one of [meshHullSamples]) — the vivid
/// middle of the mesh — or the base colour for other backgrounds. The
/// renderer's frost underlay and Reduce Transparency's solid tint (the
/// tint composited over it) use it, so both are checked colours.
int glassDiffuseColor(BackgroundSpec bg) {
  final c = bg.colors;
  if (bg.kind == BackgroundKind.meshGradient && c.length >= 4) {
    return _centroid(c[1] | 0xFF000000, c[2] | 0xFF000000, c[3] | 0xFF000000);
  }
  return (c.isEmpty ? 0 : c.first) | 0xFF000000;
}

// ------------------------------------------------------------- guardrails --

double _minOver(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

/// The colours a glass face shows under the press glow [glow] at its
/// peak: the glow composited over the tint over every background sample.
List<int> glassPressedSamples(int face, int glow, List<int> bgs) => [
  for (final b in bgs) compositeOver(glow, compositeOver(face, b)),
];

/// Smallest label contrast of [k] under the peak press glow [glow].
double glassPressedLabelContrast(KeyColors k, int glow, List<int> bgs) =>
    _minOver(k.label, glassPressedSamples(k.face, glow, bgs));

/// Smallest ΔEOK (normal + CVD) between [face] and [digit] composited over
/// the same background sample.
double glassTintDistance(int face, int digit, List<int> bgs) {
  var m = double.infinity;
  for (final b in bgs) {
    final d = minCvdDeltaELabs(
      cvdLabs(compositeOver(face, b)),
      cvdLabs(compositeOver(digit, b)),
    );
    if (d < m) m = d;
  }
  return m;
}

/// Smallest rim width the Accessible lock accepts, dp × 100.
const int glassAccessibleRimMinCdp = 100;

/// The Liquid Glass rules (see the library docs); `validateTheme` adds
/// them for the family. [bgs] are the background samples.
List<GuardrailViolation> validateGlass(
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
    final r = glassPressedLabelContrast(k, p.highlight, bgs);
    if (r < glassPressedLabelRatio) {
      out.add(
        GuardrailViolation(
          GuardrailRule.glassPressedLabel,
          r,
          glassPressedLabelRatio,
          name,
        ),
      );
    }
  }
  for (final (name, k) in [('operator', p.operator), ('equals', p.equals)]) {
    final d = glassTintDistance(k.face, p.digit.face, bgs);
    if (d < lim.cvdDeltaE) {
      out.add(
        GuardrailViolation(
          GuardrailRule.glassOperatorTint,
          d,
          lim.cvdDeltaE,
          name,
        ),
      );
    }
  }
  if (spec.accessible) {
    for (final MapEntry(key: name, value: k) in groups.entries) {
      final opaque = ((k.edge >>> 24) & 0xFF) == 255;
      final r = opaque ? _minOver(k.edge, bgs) : 1.0;
      if (r < ratioLarge) {
        out.add(
          GuardrailViolation(GuardrailRule.glassRim, r, ratioLarge, name),
        );
      }
    }
    if (spec.keyStyle.outlineWidthCdp < glassAccessibleRimMinCdp) {
      out.add(
        GuardrailViolation(
          GuardrailRule.glassRim,
          spec.keyStyle.outlineWidthCdp / 100,
          glassAccessibleRimMinCdp / 100,
          'rim width (dp)',
        ),
      );
    }
  }
  if (spec.nonColourOperatorCue == OperatorCue.weight) {
    final bonus = spec.type.operatorWeight - spec.type.keyWeight;
    if (bonus < 200) {
      out.add(
        GuardrailViolation(
          GuardrailRule.glassOperatorCue,
          bonus.toDouble(),
          200,
          'operator weight bonus',
        ),
      );
    }
  }
  return out;
}

bool _keepsPolarity(int label, List<int> samples, {required bool light}) {
  final y = luminanceArgb(label);
  for (final s in samples) {
    final sy = luminanceArgb(s);
    if (light ? y <= sy : y >= sy) return false;
  }
  return true;
}

/// Solves a glass key: the label (from [label]) on [tint] at [alpha]
/// composited over every one of [bgs], to [target]. When no label of the
/// same polarity reaches it, the tint moves away from the label (0.04 in
/// lightness) and densifies (+14 alpha) for up to [rounds] rounds. Null
/// when unreachable.
KeyColors? solveGlassKey({
  required Lch tint,
  required int alpha,
  required Lch label,
  required List<int> bgs,
  required double target,
  required int edge,
  int rounds = 14,
}) {
  final light = label.l > 0.5;
  final start = oklchToArgb(label.l, label.c, label.h);
  var l = tint.l;
  var a = alpha;
  for (var i = 0; i < rounds; i++) {
    final face = withAlpha(oklchToArgb(l, tint.c, tint.h), a);
    final samples = faceSamples(face, bgs);
    final solved = solveOnAll(start, samples, target);
    if (solved != null && _keepsPolarity(solved, samples, light: light)) {
      return KeyColors(face: face, label: solved, edge: edge);
    }
    l = clamp01(l + (light ? -0.04 : 0.04));
    a = a + 14 > 250 ? 250 : a + 14;
  }
  return null;
}

/// Repairs translucent glass keys whose labels miss the floor on some
/// composited sample: re-solves the label, then moves and densifies the
/// tint ([solveGlassKey]). Opaque keys are left to the generic repair.
/// Null when a key cannot reach the floor.
Palette? repairGlassKeys(Palette p, GuardrailLimits lim, List<int> bgs) {
  KeyColors? fix(KeyColors k) {
    if (((k.face >>> 24) & 0xFF) == 255) return k;
    if (_minOver(k.label, faceSamples(k.face, bgs)) >= lim.labelRatio) {
      return k;
    }
    return solveGlassKey(
      tint: argbToOklch(k.face | 0xFF000000),
      alpha: (k.face >>> 24) & 0xFF,
      label: argbToOklch(k.label),
      bgs: bgs,
      target: lim.labelRatio,
      edge: k.edge,
    );
  }

  final digit = fix(p.digit);
  final op = fix(p.operator);
  var eq = fix(p.equals);
  final fn = fix(p.function);
  if (digit == null || op == null || eq == null || fn == null) return null;
  if (((eq.face >>> 24) & 0xFF) != 255) {
    eq = separateGlassEquals(eq, op, digit, lim, bgs);
    if (eq == null) return null;
  }
  return p.copyWith(
    digit: digit,
    operator: op,
    equals: eq,
    function: fn,
    surface: densifyGlassSurface(p.surface, p.displayText, lim, bgs),
  );
}

/// The display backing [surface] made denser (alpha + 10 at a time) until
/// a text of [text]'s polarity reaches the display and preview floors
/// (+ 0.15) on it composited over every background sample.
int densifyGlassSurface(
  int surface,
  int text,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final preview = lim.previewRatio < ratioText ? ratioText : lim.previewRatio;
  final target =
      (lim.displayRatio > preview ? lim.displayRatio : preview) + 0.15;
  var a = (surface >>> 24) & 0xFF;
  final light =
      luminanceArgb(text | 0xFF000000) > luminanceArgb(surface | 0xFF000000);
  while (a < 255) {
    final panels = faceSamples(withAlpha(surface, a), bgs);
    final probe = solveOnAll(text | 0xFF000000, panels, target);
    if (probe != null && _keepsPolarity(probe, panels, light: light)) break;
    a = a + 10 > 255 ? 255 : a + 10;
  }
  return withAlpha(surface, a);
}

/// Keeps the `=` glass apart from the operators over any two background
/// samples (the generic `equalsVsOperator` rule compares every pair) and
/// from the digit tint over the same sample (`glassOperatorTint`): when
/// it is too close, its tint moves 0.06 at a time in lightness — away
/// from the operator's first, then the other way — at an alpha of at
/// least 230 (a denser jewel varies less across the mesh), re-solving the
/// label each step. Null when no step works.
KeyColors? separateGlassEquals(
  KeyColors eq,
  KeyColors op,
  KeyColors digit,
  GuardrailLimits lim,
  List<int> bgs,
) {
  final opLabs = [for (final s in faceSamples(op.face, bgs)) cvdLabs(s)];
  bool ok(KeyColors e) {
    if (glassTintDistance(e.face, digit.face, bgs) < lim.cvdDeltaE) {
      return false;
    }
    for (final s in faceSamples(e.face, bgs)) {
      final labs = cvdLabs(s);
      for (final o in opLabs) {
        if (minCvdDeltaELabs(labs, o) < lim.equalsVsOperatorDeltaE) {
          return false;
        }
      }
    }
    return true;
  }

  if (ok(eq)) return eq;
  final tint = argbToOklch(eq.face | 0xFF000000);
  final alpha = (eq.face >>> 24) & 0xFF;
  final label = argbToOklch(eq.label);
  final opL = argbToOklch(op.face | 0xFF000000).l;
  for (final up in [tint.l >= opL, tint.l < opL]) {
    var l = tint.l;
    for (var i = 0; i < 6; i++) {
      l = clamp01(l + (up ? 0.06 : -0.06));
      final k = solveGlassKey(
        tint: (l: l, c: tint.c, h: tint.h),
        alpha: alpha < 230 ? 230 : alpha,
        label: l < 0.62
            ? (l: 0.98, c: label.c, h: label.h)
            : (l: 0.18, c: label.c, h: label.h),
        bgs: bgs,
        target: lim.labelRatio,
        edge: eq.edge,
      );
      if (k != null && ok(k)) return k;
    }
  }
  return null;
}

/// The press glow [glow] dimmed (alpha in steps of 4) until every label of
/// [p] keeps [glassPressedLabelRatio] under it.
int fitGlassGlow(Palette p, int glow, List<int> bgs) {
  var a = (glow >>> 24) & 0xFF;
  bool ok(int g) {
    for (final k in [p.digit, p.operator, p.equals, p.function]) {
      if (glassPressedLabelContrast(k, g, bgs) < glassPressedLabelRatio) {
        return false;
      }
    }
    return true;
  }

  while (a > 0 && !ok(withAlpha(glow, a))) {
    a = a - 4 < 0 ? 0 : a - 4;
  }
  return withAlpha(glow, a);
}

/// Repairs the glass extras: the press glow (dimmed until labels keep
/// 3:1 under it) and, under the Accessible lock, opaque rims solved to
/// ≥ 3:1 on every background sample. Null when a rim is unreachable.
Palette? repairGlassExtras(
  Palette p,
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
) {
  var out = p.copyWith(highlight: fitGlassGlow(p, p.highlight, bgs));
  if (spec.accessible) {
    KeyColors? rimmed(KeyColors k) {
      final edge = solveOnAll(k.edge | 0xFF000000, bgs, ratioLarge);
      return edge == null ? null : k.copyWith(edge: edge);
    }

    final digit = rimmed(out.digit);
    final op = rimmed(out.operator);
    final eq = rimmed(out.equals);
    final fn = rimmed(out.function);
    if (digit == null || op == null || eq == null || fn == null) return null;
    out = out.copyWith(digit: digit, operator: op, equals: eq, function: fn);
  }
  return out;
}

// --------------------------------------------------------------- builder --

int _wrap(int tenths) => tenths % 3600;

double _relChroma(int rel, int capMilli, double l, double hDeg) {
  final c = rel / 1000 * maxChroma(l, hDeg);
  final cap = capMilli / 1000;
  return c < cap ? c : cap;
}

/// Builds one unvalidated Liquid Glass candidate (the generator repairs
/// and validates it, retries with `palette/retry/n` and finally falls back
/// to a Liquid Glass hero).
ThemeSpec buildGlassCandidate(
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
  final scheme = pickWeightedValue(p, def.schemes);
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final bile = def.bile;
  final h0 = p.nextHueTenths();
  final offsets = glassBlobOffsets(scheme);
  final blobHues = [
    for (final o in offsets) _wrap(h0 + o + p.nextJitterTenths(100)),
  ];

  // Mesh: base + three vivid blobs.
  final baseL = ranges.background.lMilli.sample(p) / 1000;
  final baseC =
      p.nextIntIn(ranges.background.chroma.lo, ranges.background.chroma.hi) /
      1000;
  final baseHue = blobHues.first;
  final base = oklchToArgb(baseL, baseC, baseHue / 10);
  final blobL = dark ? glassDarkBlobLMilli : glassLightBlobLMilli;
  final blobRel = dark ? glassDarkBlobChroma : glassLightBlobChroma;
  final blobCap = dark ? glassBlobChromaCapMilli : glassLightBlobChromaCapMilli;
  final blobs = <int>[];
  final blobLch = <Lch>[];
  for (var i = 0; i < 3; i++) {
    var lMilli = blobL.sample(p);
    if (accessible && dark && lMilli > 480) lMilli -= 80;
    final l = lMilli / 1000;
    final rel = blobRel.sample(p);
    var hue = blobHues[i];
    final c0 = _relChroma(rel, blobCap, l, hue / 10);
    hue = bile.apply(hue, l, c0);
    final c = _relChroma(rel, blobCap, l, hue / 10);
    blobs.add(oklchToArgb(l, c, hue / 10));
    blobLch.add((l: l, c: c, h: hue / 10));
  }
  final b = Rng.stream(seed, RngTag.background);
  final drift = glassDriftPeriodMs.sampleStep(b, 5000);
  final background = BackgroundSpec(
    kind: BackgroundKind.meshGradient,
    colors: List.unmodifiable([base, ...blobs]),
    angleTenths: b.nextInt(3600),
    driftPeriodMs: drift,
  );
  final bgs = backgroundSamples(background);

  // Rims: decorative light catchers, opaque and ≥ 3:1 when accessible.
  final rimAlpha = dark ? p.nextIntIn(110, 160) : p.nextIntIn(200, 240);
  int rim(double hDeg) {
    final decorative = withAlpha(oklchToArgb(0.99, 0.01, hDeg), rimAlpha);
    if (!accessible) return decorative;
    final start = dark
        ? oklchToArgb(0.95, 0.02, hDeg)
        : oklchToArgb(0.32, 0.04, hDeg);
    return solveOnAll(start, bgs, ratioLarge) ?? blackOrWhite(base);
  }

  final policyTarget = lim.labelRatio;
  final labelC = p.nextIntIn(4, ranges.labelMaxChromaMilli) / 1000;
  Lch labelFor(double tintL, double hDeg) => tintL < 0.62
      ? (l: 0.98, c: labelC, h: hDeg)
      : (l: 0.18, c: labelC, h: hDeg);

  KeyColors? key(Lch tint, int alpha, {Lch? label}) => solveGlassKey(
    tint: tint,
    alpha: alpha,
    label: label ?? labelFor(tint.l, tint.h),
    bgs: bgs,
    target: policyTarget,
    edge: rim(tint.h),
  );

  // Digits: smoky (dark) or milky (light) glass.
  final h0Deg = baseHue / 10;
  final digitTint = (
    l: ranges.digit.lMilli.sample(p) / 1000,
    c: p.nextIntIn(ranges.digit.chroma.lo, ranges.digit.chroma.hi) / 1000,
    h: h0Deg,
  );
  final digitAlpha = (dark ? glassDarkDigitAlpha : glassLightDigitAlpha).sample(
    p,
  );
  // Function keys: a second, denser tone of the base hue.
  final fnTint = (
    l: ranges.function.lMilli.sample(p) / 1000,
    c: p.nextIntIn(ranges.function.chroma.lo, ranges.function.chroma.hi) / 1000,
    h: h0Deg,
  );
  final fnAlpha = (dark ? glassDarkFunctionAlpha : glassLightFunctionAlpha)
      .sample(p);
  // Operators: vivid glass in blob 2's hue; `=`: denser, blob 3's hue.
  Lch accentTint(RoleRange r, double hDeg) {
    var lMilli = r.lMilli.sample(p);
    if (accessible) {
      // 7:1 labels exist only on faces with Y ≤ 0.1 or ≥ 0.3: keep the
      // accent glass out of the mid-tones.
      lMilli = dark
          ? (lMilli < 760 ? 760 : lMilli)
          : (lMilli > 440 ? 440 : lMilli);
    }
    final l = lMilli / 1000;
    final rel = p.nextIntIn(r.chroma.lo, r.chroma.hi);
    var hue = (hDeg * 10).round() % 3600;
    hue = bile.apply(hue, l, _relChroma(rel, r.chroma.capMilli, l, hue / 10));
    return (
      l: l,
      c: _relChroma(rel, r.chroma.capMilli, l, hue / 10),
      h: hue / 10,
    );
  }

  final opTint = accentTint(ranges.operator, blobLch[1].h);
  final eqTint = accentTint(ranges.equals, blobLch[2].h);
  final opAlpha = (dark ? glassDarkOperatorAlpha : glassLightOperatorAlpha)
      .sample(p);
  final eqAlpha = (dark ? glassDarkEqualsAlpha : glassLightEqualsAlpha).sample(
    p,
  );

  final digitKey = key(digitTint, digitAlpha);
  final fnKey = key(fnTint, fnAlpha);
  final opKey = key(opTint, opAlpha);
  var eqKey = key(eqTint, eqAlpha);
  if (eqKey != null && opKey != null && digitKey != null) {
    eqKey = separateGlassEquals(eqKey, opKey, digitKey, lim, bgs);
  }

  // Display backing: dense surface glass; texts solved on it composited
  // over every sample.
  final surfaceL =
      (dark ? glassDarkSurfaceLMilli : glassLightSurfaceLMilli).sample(p) /
      1000;
  final surfaceC =
      p.nextIntIn(ranges.surfaceChroma.lo, ranges.surfaceChroma.hi) / 1000;
  var surfaceAlpha = (dark ? glassDarkSurfaceAlpha : glassLightSurfaceAlpha)
      .sample(p);
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final textTarget =
      (lim.displayRatio > previewTarget ? lim.displayRatio : previewTarget) +
      0.15;
  final textStart = oklchToArgb(dark ? 0.98 : 0.16, 0.012, h0Deg);
  int surface;
  List<int> panels;
  while (true) {
    surface = withAlpha(oklchToArgb(surfaceL, surfaceC, h0Deg), surfaceAlpha);
    panels = faceSamples(surface, bgs);
    final probe = solveOnAll(textStart, panels, textTarget);
    if (surfaceAlpha >= 250 ||
        (probe != null && _keepsPolarity(probe, panels, light: dark))) {
      break;
    }
    surfaceAlpha = surfaceAlpha + 10 > 250 ? 250 : surfaceAlpha + 10;
  }
  int onPanel(double l, double c, double hDeg, double target) =>
      solveOnAll(oklchToArgb(l, c, hDeg), panels, target) ??
      blackOrWhite(panels.first);
  final displayText = onPanel(
    dark ? 0.98 : 0.16,
    0.012,
    h0Deg,
    lim.displayRatio,
  );
  final previewText = onPanel(dark ? 0.80 : 0.42, 0.03, h0Deg, previewTarget);
  final error = onPanel(dark ? 0.74 : 0.50, 0.16, 25, lim.displayRatio);
  final accentL = dark ? 0.84 : 0.46;
  final accentStart = oklchToArgb(
    accentL,
    _relChroma(
      p.nextIntIn(ranges.accentChroma.lo, ranges.accentChroma.hi),
      ranges.accentChroma.capMilli,
      accentL,
      opTint.h,
    ),
    opTint.h,
  );
  final caret =
      solveOnAll(accentStart, panels, lim.caretRatio) ??
      blackOrWhite(panels.first);
  final focusRing =
      solveOnAll(accentStart, bgs, lim.focusRingRatio) ?? blackOrWhite(base);

  final glow = withAlpha(oklchToArgb(1, 0, 0), glassGlowAlpha.sample(p));
  final shadow = dark
      ? withAlpha(oklchToArgb(0.08, 0.02, h0Deg), 96)
      : withAlpha(oklchToArgb(0.30, 0.06, h0Deg), 46);

  final digit = digitKey ?? _fallbackKey(base);
  final function = fnKey ?? _fallbackKey(base);
  final operator = opKey ?? _fallbackKey(base);
  final equals = eqKey ?? _fallbackKey(base);
  var palette = Palette(
    background: base,
    surface: surface,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: focusRing,
    accent: caret,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: shadow,
    highlight: glow,
    seedColor: operator.face | 0xFF000000,
  );
  palette = palette.copyWith(highlight: fitGlassGlow(palette, glow, bgs));

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
    outlineWidthCdp: accessible
        ? 150 + 25 * st.nextInt(3)
        : 100 + 25 * st.nextInt(3),
    shadowOffsetCdp: 200 + 50 * st.nextInt(3),
    shadowBlurCdp: 600 + 100 * st.nextInt(5),
    opacityPermille: ((digit.face >>> 24) & 0xFF) * 1000 ~/ 255,
    frostPermille: (dark ? glassDarkFrost : glassLightFrost).sampleStep(st, 50),
    highlightPermille: glassHighlight.sampleStep(st, 50),
    refractionPermille: glassRefraction.sampleStep(st, 50),
  );
  final t = Rng.stream(seed, RngTag.type);
  final keyWeight = def.keyWeight.sampleStep(t, 50);
  final opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  final type = TypeSpec(
    displayFont: pickWeightedValue(t, def.displayFonts),
    keyFont: pickWeightedValue(t, def.keyFonts),
    displayWeight: def.displayWeight.sampleStep(t, 50),
    keyWeight: keyWeight,
    operatorWeight: opWeight > 900 ? 900 : opWeight,
  );
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: operator.face | 0xFF000000,
    family: ThemeFamily.liquidGlass,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.liquidGlass,
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

/// A key that fails validation on purpose (an unsolvable attempt): the
/// generator then retries with the next palette stream.
KeyColors _fallbackKey(int base) =>
    KeyColors(face: withAlpha(base, 128), label: base, edge: base);
