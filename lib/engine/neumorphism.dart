/// The Neumorphism (Soft UI) palette builder (spec §5.3 #4;
/// docs/m4-design.md §C; research theme-engine.md recommendation 7 and
/// §7.2). Pure Dart: part of the generator, so every value here is part of
/// the family's engine-v2 definition and must not change without a
/// version bump.
///
/// Classic neumorphism fails WCAG because its keys are the background
/// colour and their only edge is a blurred shadow (neumorphism.io's
/// default reaches 1.41:1). This builder keeps the look and adds:
///
/// - **Surface:** a monochrome, low-chroma base (light L 0.88–0.94, dark
///   L 0.20–0.28, C ≤ 0.02) that is the background *and* every digit and
///   function face.
/// - **Shadows:** a light and a dark shadow derived in OKLCH from the
///   surface (same hue; light L + 0.04–0.08 (dark themes + 0.03–0.06),
///   dark L − 0.10–0.18 (dark themes − 0.08–0.12), C + 0.01), stored as
///   `palette.highlight` / `palette.shadow`. The Accessible lock deepens
///   the dark shadow.
/// - **Rim:** a 1–1.5 dp stroke on the shadow side, its colour solved by
///   OKLCH lightness bisection to the *least* change that reaches ≥ 3:1
///   against the surface (WCAG 1.4.11), stored as every group's
///   `KeyColors.edge`.
/// - **Labels:** near-black / near-white ink solved to ≥ 4.5:1 (7:1 under
///   the Accessible lock and on dark faces), function keys in an
///   accent-tinted ink.
/// - **Operators:** an accent label on the surface face, or a tinted
///   accent face ≥ 0.10 lightness from it (seeded), always with a label
///   weight ≥ key weight + 200 — the recorded non-colour cue
///   ([OperatorCue.weight]). `=` is a full accent face.
/// - **Pressed:** besides the shadow swap, surface-faced keys show their
///   label in the accent colour (solved ≥ the label floor on the surface)
///   and the rim closes all round; accent-labelled operators swap to the
///   digit ink.
library;

import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

/// Soft-shadow lightness offsets from the surface (× 1000 of OKLCH L).
final class SoftShadowRanges {
  const new({
    required this.highlightMilli,
    required this.shadowMilli,
    required this.accessibleShadowMilli,
  });

  /// Light shadow: surface L + this.
  final IntRange highlightMilli;

  /// Dark shadow: surface L − this.
  final IntRange shadowMilli;

  /// Dark shadow under the Accessible lock (research §7.2.8: stronger).
  final IntRange accessibleShadowMilli;
}

/// Light themes (research §7.2.2).
const SoftShadowRanges softLightShadows = SoftShadowRanges(
  highlightMilli: IntRange(40, 80),
  shadowMilli: IntRange(100, 180),
  accessibleShadowMilli: IntRange(200, 260),
);

/// Dark themes: little headroom for highlights, so a smaller one.
const SoftShadowRanges softDarkShadows = SoftShadowRanges(
  highlightMilli: IntRange(30, 60),
  shadowMilli: IntRange(80, 120),
  accessibleShadowMilli: IntRange(120, 150),
);

/// Rim widths (dp × 100) the style stream picks from; the Accessible lock
/// always takes the widest. Inside `softRimWidthMinCdp`–`softRimWidthMaxCdp`
/// (guardrails.dart).
const List<int> softRimWidthsCdp = [100, 125, 150];

/// How the operators of a Neumorphism theme stand out (both add the
/// heavier glyph).
enum SoftOperatorStyle {
  /// Surface face, accent-coloured label.
  accentLabel,

  /// Tinted accent face ≥ 0.10 lightness from the surface.
  accentFace,
}

/// Whether [spec] (a soft-style theme) gives operators an accent label on
/// the surface face rather than a tinted face.
SoftOperatorStyle softOperatorStyleOf(ThemeSpec spec) =>
    spec.palette.operator.face == spec.palette.digit.face
    ? SoftOperatorStyle.accentLabel
    : SoftOperatorStyle.accentFace;

int _wrap(int tenths) => tenths % 3600;

double _chromaAt(ChromaRange r, int v, double l, double hDeg) {
  if (!r.relative) return v / 1000;
  final c = v / 1000 * maxChroma(l, hDeg);
  final cap = r.capMilli / 1000;
  return c < cap ? c : cap;
}

double _drawChroma(Rng p, ChromaRange r, double l, double hDeg) =>
    _chromaAt(r, p.nextIntIn(r.lo, r.hi), l, hDeg);

/// The rim colour for [surface]: same hue, chroma + 0.01, the least
/// lightness change from the surface that reaches [target] against it.
int softRimFor(int surface, {double target = ratioLarge}) {
  final s = argbToOklch(surface);
  final dark = luminanceArgb(surface) < yEqualContrast;
  return solveLightness(
        l0: s.l,
        c: s.c + 0.01,
        hDeg: s.h,
        againstArgb: surface,
        target: target,
        preferLighter: dark,
      ) ??
      blackOrWhite(surface);
}

/// One unvalidated Neumorphism candidate for [seed] (the generator adds
/// repair, retries and the hero fallback). [paletteTag] is the palette
/// stream of this attempt (`palette`, then `palette/retry/n`).
ThemeSpec buildNeumorphicCandidate(
  int seed,
  FamilyDefinition def,
  int engineVersion, {
  required String paletteTag,
  required bool accessible,
}) {
  final p = Rng.stream(seed, paletteTag);
  final dark = p.pickWeighted(def.brightnessWeights) == 0;
  final brightness = dark ? ThemeBrightness.dark : ThemeBrightness.light;
  final r = def.ranges(brightness);
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;
  final bile = def.bile;

  // Hues.
  final scheme = pickWeightedValue(p, def.schemes);
  final h0 = p.nextHueTenths();
  int at(int offset) => _wrap(h0 + offset + p.nextJitterTenths(100));
  final accentHue = switch (scheme) {
    HarmonyScheme.monochrome => h0,
    HarmonyScheme.analogous => at(p.nextChance(1, 2) ? 300 : -300),
    HarmonyScheme.complementary || HarmonyScheme.duotone => at(1800),
    HarmonyScheme.splitComplementary => at(p.nextChance(1, 2) ? 1500 : 2100),
    HarmonyScheme.triadic => at(p.nextChance(1, 2) ? 1200 : 2400),
  };
  final baseH = h0 / 10;

  // Surface, display well, shadows, rim.
  final bgL = r.background.lMilli.sample(p) / 1000;
  final bgC = _drawChroma(p, r.background.chroma, bgL, baseH);
  final bg = oklchToArgb(bgL, bgC, baseH);
  final surfL = clamp01(bgL + r.surfaceOffsetMilli.sample(p) / 1000);
  final surface = oklchToArgb(
    surfL,
    _drawChroma(p, r.surfaceChroma, surfL, baseH),
    baseH,
  );
  final shadows = dark ? softDarkShadows : softLightShadows;
  final hiL = clamp01(bgL + shadows.highlightMilli.sample(p) / 1000);
  final loL = clamp01(
    bgL -
        (accessible ? shadows.accessibleShadowMilli : shadows.shadowMilli)
                .sample(p) /
            1000,
  );
  var highlight = oklchToArgb(hiL, bgC * 0.5, baseH);
  if (luminanceArgb(highlight) <= luminanceArgb(bg)) highlight = 0xFFFFFFFF;
  var shadow = oklchToArgb(loL, bgC + 0.01, baseH);
  if (luminanceArgb(shadow) >= luminanceArgb(bg)) shadow = 0xFF000000;
  final rim = softRimFor(bg);

  // Accent: label colour of accent-label operators, pressed label, caret
  // and focus ring; ≥ the label floor on the surface and the display well.
  final accentL = dark ? 0.80 : 0.48;
  final accentC = _drawChroma(p, r.accentChroma, accentL, accentHue / 10);
  final accent = _solveAccent(
    accentL,
    accentC,
    accentHue,
    [bg, surface],
    lim.labelRatio > lim.caretRatio ? lim.labelRatio : lim.caretRatio,
    bile,
  );

  // Labels.
  final labelC = p.nextIntIn(5, r.labelMaxChromaMilli) / 1000;
  int solveOn(int face, double l, double c, double hDeg) =>
      solveLabel(face, (l: l, c: c, h: hDeg), policy: policy) ??
      blackOrWhite(face);
  final ink = solveOn(bg, r.labelStartLMilli / 1000, labelC, baseH);
  final fnInk = solveOn(bg, dark ? 0.86 : 0.36, 0.05, accentHue / 10);
  final digit = KeyColors(face: bg, label: ink, edge: rim);
  final function = KeyColors(face: bg, label: fnInk, edge: rim);

  // Operators.
  final opStyle = p.nextChance(1, 2)
      ? SoftOperatorStyle.accentFace
      : SoftOperatorStyle.accentLabel;
  final opLDraw = r.operator.lMilli.sample(p);
  final opCDraw = p.nextIntIn(r.operator.chroma.lo, r.operator.chroma.hi);
  final KeyColors operator;
  if (opStyle == SoftOperatorStyle.accentLabel) {
    operator = KeyColors(face: bg, label: accent, edge: rim);
  } else {
    final bgMilli = (bgL * 1000).round();
    final opMilli = dark
        ? (opLDraw < bgMilli + 100 ? bgMilli + 100 : opLDraw)
        : (opLDraw > bgMilli - 100 ? bgMilli - 100 : opLDraw);
    operator = _accentKey(
      opMilli / 1000,
      _chromaAt(r.operator.chroma, opCDraw, opMilli / 1000, accentHue / 10),
      accentHue,
      labelStartL: dark ? 0.97 : 0.20,
      labelC: labelC,
      rim: rim,
      policy: policy,
      bile: bile,
    );
  }

  // `=`: a full accent face.
  var eqMilli = r.equals.lMilli.sample(p);
  if (accessible) {
    if (dark && eqMilli < 720) eqMilli = 720;
    if (!dark && eqMilli > 440) eqMilli = 440;
  }
  final eqCDraw = p.nextIntIn(r.equals.chroma.lo, r.equals.chroma.hi);
  final equals = _accentKey(
    eqMilli / 1000,
    _chromaAt(r.equals.chroma, eqCDraw, eqMilli / 1000, accentHue / 10),
    accentHue,
    labelStartL: dark ? 0.18 : 0.98,
    labelC: labelC,
    rim: rim,
    policy: policy,
    bile: bile,
  );

  // Display texts on the display well and the surface.
  final backdrops = [surface, bg];
  int text(double l, double c, double hDeg, double target) =>
      solveOnAll(oklchToArgb(l, c, hDeg), backdrops, target) ??
      blackOrWhite(surface);
  final displayText = text(dark ? 0.96 : 0.20, 0.012, baseH, lim.displayRatio);
  final previewText = text(
    dark ? 0.80 : 0.40,
    0.02,
    baseH,
    lim.previewRatio < ratioText ? ratioText : lim.previewRatio,
  );
  final error = text(dark ? 0.74 : 0.48, 0.15, 25, lim.displayRatio);

  final palette = Palette(
    background: bg,
    surface: surface,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: accent,
    focusRing: accent,
    accent: accent,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: shadow,
    highlight: highlight,
    seedColor: equals.face,
  );

  // Shape, style, type, motion, name.
  final s = Rng.stream(seed, RngTag.shape);
  final shapeKind = pickWeightedValue(s, def.shapes);
  final corner = def.cornerPermille.sampleStep(s, 10);
  final st = Rng.stream(seed, RngTag.style);
  final rimDraw = st.pick(softRimWidthsCdp);
  final keyStyle = def.keyStyle.copyWith(
    outlineWidthCdp: accessible ? softRimWidthsCdp.last : rimDraw,
  );
  final t = Rng.stream(seed, RngTag.type);
  final displayFont = pickWeightedValue(t, def.displayFonts);
  final keyFont = pickWeightedValue(t, def.keyFonts);
  final displayWeight = def.displayWeight.sampleStep(t, 50);
  final keyWeight = def.keyWeight.sampleStep(t, 50);
  final opWeight = keyWeight + def.operatorWeightBonus.sampleStep(t, 50);
  final motion = def.motionRanges.vary(
    def.motion,
    Rng.stream(seed, RngTag.motion),
  );
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: equals.face,
    family: def.family,
    dark: dark,
  );

  return ThemeSpec(
    seed: seed,
    family: def.family,
    engineVersion: engineVersion,
    brightness: brightness,
    accessible: accessible,
    palette: palette,
    keyShape: KeyShapeSpec(
      kind: shapeKind,
      cornerPermille: shapeKind == KeyShapeKind.circle ? 500 : corner,
    ),
    keyStyle: keyStyle,
    type: TypeSpec(
      displayFont: displayFont,
      keyFont: keyFont,
      displayWeight: displayWeight,
      keyWeight: keyWeight,
      operatorWeight: opWeight > 900 ? 900 : opWeight,
    ),
    background: BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: List.unmodifiable([bg]),
    ),
    motion: motion,
    sound: def.sound,
    name: name,
    nonColourOperatorCue: def.nonColourOperatorCue,
  );
}

/// The accent colour at (l, c, hue) solved to [target] on every one of
/// [backdrops], with disliked (bile) hues rotated out before and after
/// the lightness solve.
int _solveAccent(
  double l,
  double c,
  int hueTenths,
  List<int> backdrops,
  double target,
  BileRule bile,
) {
  int solve(int hue) =>
      solveOnAll(oklchTenthsToArgb(l, c, hue), backdrops, target) ??
      blackOrWhite(backdrops.first);
  final hue = bile.apply(hueTenths, l, c);
  var accent = solve(hue);
  final f = argbToOklch(accent);
  final finalHue = (f.h * 10).round() % 3600;
  final rotated = bile.apply(finalHue, f.l, f.c);
  if (rotated != finalHue) accent = solve(rotated);
  return accent;
}

/// An accent-faced key at (l, c, hue): bile hues rotated out, label
/// repaired with the face (`repairPair`), and re-checked on the final face.
KeyColors _accentKey(
  double l,
  double c,
  int hueTenths, {
  required double labelStartL,
  required double labelC,
  required int rim,
  required ContrastPolicy policy,
  required BileRule bile,
}) {
  final hue = bile.apply(hueTenths, l, c);
  var pair = repairPair(
    (l: l, c: c, h: hue / 10),
    (l: labelStartL, c: labelC, h: hue / 10),
    policy: policy,
  );
  final f = argbToOklch(pair.face);
  final finalHue = (f.h * 10).round() % 3600;
  final rotated = bile.apply(finalHue, f.l, f.c);
  if (rotated != finalHue) {
    pair = repairPair(
      (l: f.l, c: f.c, h: rotated / 10),
      (l: labelStartL, c: labelC, h: rotated / 10),
      policy: policy,
    );
  }
  return KeyColors(face: pair.face, label: pair.label, edge: rim);
}
