/// Theme guardrails (spec §5.4; docs/m3-theme-engine-design.md "Rules";
/// research theme-engine.md §4, §6.2, §12): validate a [ThemeSpec] on its
/// final quantised ARGB values, and repair failures by OKLCH lightness
/// bisection.
///
/// Rules (ratios are never rounded; 4.499:1 fails 4.5:1):
///
/// | rule | measured against | floor (accessible) |
/// |---|---|---|
/// | digit / operator / `=` / function labels | their face | 4.5 (7) |
/// | display text, error text | every display backdrop | 4.5 (7) |
/// | preview text | every display backdrop | 3 (4.5) |
/// | caret | every display backdrop | 3 (4.5) |
/// | focus ring | every background sample | 3 (3) |
/// | operator / `=` vs digit faces | face contrast ≥ 1.5 **and** min ΔEOK over {normal, protan, deutan, tritan} ≥ 0.08, unless the spec records a non-colour cue | |
/// | `=` vs operator faces | min ΔEOK (normal + CVD) ≥ 0.05 | |
/// | LCD ghost segments (Retro) | the LCD panel | **at most** 1.3 (1.3) |
/// | soft-key rims (Neumorphism), 1–1.5 dp | every background sample | 3 (3) |
/// | soft-key pressed label (the accent) | every surface-faced key | 4.5 (7) |
/// | outlined-key outlines (Neo-brutalism), 2–4 dp | every background sample | 3 (3) |
/// | outlined-key hard shadow: opaque, no blur, offset = press depth 3–5 dp | | |
/// | glass (Liquid Glass) labels on each tint composited over every mesh hull sample (`meshHullSamples`: stops, pairwise ¼ / ½ / ¾ points, three-way centroids) | the darkest and lightest composites | 4.5 (7) |
/// | glass display text on the backing panel over every hull sample (the bare mesh is never a display backdrop) | | 4.5 (7) |
/// | glass labels under the peak press glow | every hull sample | 3 (3) |
/// | glass operator / `=` tint vs digit tint over the same sample | min ΔEOK (normal + CVD) ≥ 0.08, plus the weight cue | |
/// | glass rims under the Accessible lock (opaque, ≥ 1 dp) | every hull sample | 3 (3) |
/// | clay drop shadows (Claymorphism): alpha 0x50–0xD8, chroma ≥ min(0.040, 0.75 × maxChroma) (night ≥ 0.035), within 40° of the key's hue (night: the shadow-hue reference), composite ≤ 0.85 × the body's luminance | the scene base | |
/// | clay keys vs the body: light digits ΔEOK ≥ 0.045 (≥ 0.025 vs the top wash), light function keys ΔEOK ≥ 0.045, colour-blind ΔEOK ≥ 0.03 and ≥ 0.03 darker, night keys ≥ 0.15 L above | the scene base and spheres | |
/// | clay highlight lift on every face and the pillow panel | | ≥ 0.025 L |
/// | clay function labels on their inner shade (dark labels) or highlight (light labels) | | 4.5 (7) |
/// | clay focus ring where it crosses each key group's drop shadow (0.65 × its alpha; `focusRing` "over key shadow") | the base, top wash, sphere B and shadow core | 3 (3) |
/// | clay display panel: an opaque pillow, lighter than the body and ΔEOK ≥ 0.025 from it | | |
/// | clay style: no outline, shadow offset = press depth 4–6 dp, blur 10–14 dp, shade 0.08–0.11, white highlight 0xA0–0xC8, nine-colour `claySoft` scene | | |
/// | Y2K Aero labels on every colour of the label zone (rest and pressed gel / metal profile, `y2kLabelZoneSamples`) | the darkest zone colour | 4.5 (7) |
/// | Y2K Aero labels darker than the face and pressed face; faces ≥ L 0.735 (0.755) | | |
/// | Y2K Aero renderer contract: white highlight, cap / caustic / depth / rim / shadow ranges, no state layer | | |
/// | Y2K Aero scene: kind, six colours, overlay alpha caps, dots pattern | | |
/// | Y2K Aero display panel opaque, L ≥ 0.85 or ≤ 0.24 (text is checked on the panel and its gloss) | | |
/// | Y2K Aero focus ring, and rims under the Accessible lock | every scene sample, plain and under the key shadow | 3 (3) |
/// | Y2K Aero operator / `=` vs digit faces | contrast ≥ 1.2 or min ΔEOK (normal + CVD) ≥ 0.06, plus the weight cue | |
/// | Y2K Aero light skies: digit and function faces (every face in a meadow) vs the ground band | ΔEOK ≥ 0.08 | |
/// | paper outlines (Paper & ink), 1.25–1.75 dp | every sheet sample (paper, grain, rules) | 3 (3) |
/// | paper operator hatch at its opacity (0.60–0.75), plus the weight cue | the operator face | 3 (3) |
/// | paper `=` stamp | the digit slips | 3 (3) |
/// | paper labels under the ink wash's tide line (alpha ≤ 58) | their face | 4.5 (7) |
/// | cyber (Cyberpunk) operator cue: plates opaque, L ≤ 0.34, lighter labels; slabs opaque, L ≥ 0.64, darker labels, ≥ 3:1 against the digit plate; operator weight ≥ key + 200 | | |
/// | cyber plate edge lines (opaque, 1–1.5 dp) | their face | 3 (3) |
/// | cyber key boundary: each group's face or opaque edge | every scene sample | 3 (3) |
/// | cyber scene: static `cyberGrid`, five colours, ink alphas ≤ 24 / 72 / 56, tilt ≤ 20°, panel scanlines ≤ 48 (0 accessible), `cut` keys 12–24 %, no state layer | | |
/// | Vaporwave weight cue: operators ≥ 200 heavier | | |
/// | Vaporwave operator / `=` vs digit faces (normal vision) | min ΔEOK ≥ 0.08 | |
/// | Vaporwave accents vs digit and function faces | min ΔEOK (normal + CVD) ≥ 0.06 and contrast ≥ 1.2 | |
/// | Vaporwave scene: ten opaque colours, horizon 380–460 ‰, drift 0 or ≥ 40 s, every sample Y ≤ 0.26 (dark) / ≥ 0.17 (light) | | |
/// | Vaporwave panel, title bar and ink opaque | | |
/// | Vaporwave key edges = the ink; light themes: the ink | every scene sample | 3 (3) |
/// | Vaporwave dark themes: each key's face or ink | every plain floor sample a key can sit over | 3 (3) |
/// | Vaporwave dark themes: each key's face, ink or outer bevel highlight (so the highlighted top and left edges) | the grid at alpha k/8 over every floor sample and the horizon haze | 3 (3) |
/// | Bauhaus shape cue: digit block or disc, operator the other, `=` a disc / fan / triangle unlike the digits, corners ≤ 4 % | | |
/// | Bauhaus primaries: operator and `=` two different primaries (C ≥ 0.08, hue windows red 18–40°, yellow 82–100° at L ≥ 0.78, blue 250–280°); neutral digits; function accent distinct (ΔEOK ≥ 0.10) | | |
/// | Bauhaus scene: its encoding, a dark field (L ≤ 0.22) the digits reach 3:1 on, digit, operator and `=` faces vs ground / field, scene shapes ΔEOK ≥ 0.10 from the ground | | 1.1 (1.1) |
/// | Bauhaus panel: display rule (`shadow`) on the sheet; sheet accent (`highlight`) min ΔEOK (normal + CVD) ≥ 0.07 | the sheet | 3 (3) |
///
/// Display backdrops are the display surface, every background colour stop
/// and, for patterned backgrounds, the pattern ink composited over each
/// stop (the M2 layout draws the display straight on the background).
/// A 7-segment LCD theme (`TypeSpec.lcd`, Retro) draws the whole display
/// on an opaque LCD panel (the surface), so its only backdrop is the
/// panel: digit segments are then checked against exactly what they sit
/// on (≥ 4.5:1, 7:1 accessible), and unlit ghost segments must stay
/// ≤ 1.3:1 against it so they never read as digits.
library;

import 'package:calsee_themes/engine/bauhaus.dart';
import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/cyberpunk.dart';
import 'package:calsee_themes/engine/liquid_glass.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/paper_ink.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:meta/meta.dart';

/// One guardrail.
enum GuardrailRule {
  digitLabel,
  operatorLabel,
  equalsLabel,
  functionLabel,
  displayText,
  previewText,
  errorText,
  caret,
  focusRing,
  operatorVsDigit,
  equalsVsDigit,
  equalsVsOperator,

  /// Unlit LCD segments too visible against the panel (Retro; a maximum).
  lcdGhost,

  /// Soft (Neumorphism) keys: a rim below 3:1 against the background, or
  /// a rim width outside 1–1.5 dp (WCAG 1.4.11 house rule, research §7.1).
  softRim,

  /// Soft keys: the pressed label (the accent on surface-faced keys) below
  /// the label floor.
  softPressedLabel,

  /// Soft keys: the recorded weight cue is not ≥ key weight + 200.
  softOperatorCue,

  /// Soft keys: the light shadow is not lighter, or the dark shadow not
  /// darker, than the background.
  softShadow,

  /// Outlined (Neo-brutalism) keys: an outline below 3:1 against a
  /// background sample (WCAG 1.4.11), or an outline width outside 2–4 dp.
  brutalOutline,

  /// Outlined keys: the hard shadow is translucent or blurred, or its
  /// offset is not the press depth (3–5 dp).
  brutalShadow,

  /// Outlined keys: the recorded weight cue is not ≥ key weight + 200.
  brutalOperatorCue,

  /// Glass (Liquid Glass) keys: a label below 3:1 while the press glow
  /// (`Palette.highlight` at its peak) lights the face.
  glassPressedLabel,

  /// Glass keys: an operator or `=` tint not distinct (min ΔEOK over
  /// normal + CVD ≥ 0.08) from the digit tint over the same background
  /// sample.
  glassOperatorTint,

  /// Glass keys under the Accessible lock: a rim below 3:1 against a
  /// background sample, or narrower than 1 dp.
  glassRim,

  /// Glass keys: the recorded weight cue is not ≥ key weight + 200.
  glassOperatorCue,

  /// Clay (Claymorphism) keys: a drop shadow (`KeyColors.edge`) that is
  /// grey, off its key's hue, not visibly darker than the body, or outside
  /// alpha 0x50–0xD8.
  clayShadowTint,

  /// Clay keys melting into the body: light digits / function keys too
  /// close to it (ΔEOK, colour-blind ΔEOK, lightness), night keys < 0.15 L
  /// above it.
  clayKeyBody,

  /// Clay keys: the top-left highlight lifts a face (or the pillow panel)
  /// by less than 0.025 L.
  clayHighlight,

  /// Clay function keys: the label below the label floor on the inner
  /// shade (or the highlight) its long labels cross.
  clayLabelRing,

  /// Clay display panel: translucent, too close to the body, or not the
  /// raised pillow (lighter than the body).
  clayPanel,

  /// Clay renderer contract: no outline, shadow offset = press depth
  /// 4–6 dp, blur 10–14 dp, shade 0.08–0.11, a white highlight at alpha
  /// 0xA0–0xC8, a nine-colour opaque `claySoft` scene.
  clayStyle,
  // Y2K / Frutiger Aero (`y2k_aero.dart`, `validateY2kAero`).

  /// Y2K Aero keys: a label below the label floor on a colour of its
  /// face's label zone (the rest and pressed gel / metal body profile,
  /// `y2kLabelZoneSamples`).
  y2kLabelZone,

  /// Y2K Aero keys: a translucent face, a label not darker than its face
  /// and its pressed face, or a face below the gel floor (L 0.735; 0.755
  /// under the Accessible lock).
  y2kLabelPolarity,

  /// Y2K Aero: the renderer contract (white specular highlight, glass
  /// style kind, cap / caustic / depth / rim / shadow ranges, no state
  /// layer, opaque faces).
  y2kGloss,

  /// Y2K Aero: a malformed scene (kind, six colours, overlay alpha caps,
  /// bubble / sparkle pattern, drift).
  y2kScene,

  /// Y2K Aero: a translucent display panel or one in the mid band
  /// (neither L ≥ 0.85 nor L ≤ 0.24).
  y2kPanel,

  /// Y2K Aero: the focus ring (and, under the Accessible lock, any key
  /// rim) below 3:1 against the scene or the scene under the keys' own
  /// drop shadow (WCAG 1.4.11).
  y2kRim,

  /// Y2K Aero: the recorded weight cue is not ≥ key weight + 200.
  y2kOperatorCue,

  /// Y2K Aero: an operator or `=` face too close to the digit face
  /// (contrast < 1.2 and min ΔEOK over normal + CVD < 0.06).
  y2kAccentVsDigit,

  /// Y2K Aero light skies: a digit or function face (in a meadow, any key
  /// face) within ΔEOK 0.08 of the ground band behind the keypad.
  y2kGround,

  /// Paper & ink keys: a hand-drawn outline below 3:1 against a sheet
  /// sample (paper, grain, rules), translucent, or a width outside
  /// 1.25–1.75 dp.
  paperOutline,

  /// Paper & ink operators: the recorded cue is not the hatch
  /// ([OperatorCue.pattern]), the hatch opacity is outside 0.60–0.75, the
  /// hatch lines miss 3:1 against the operator face, or the weight bonus
  /// is below 200.
  paperOperatorCue,

  /// Paper & ink: the `=` stamp below 3:1 against the digit slips.
  paperStamp,

  /// Paper & ink: the ink wash's tide line above alpha 58, or a label
  /// below the label floor with it laid over its face.
  paperWash,

  /// Cyberpunk: the recorded fill-versus-outline cue is not real (a plate
  /// too light or with a darker label, a slab too dark, with a lighter
  /// label or under 3:1 against the digit plate, or operators not ≥ 200
  /// heavier).
  cyberOperatorCue,

  /// Cyberpunk: a plate edge line translucent or below 3:1 against its
  /// face, or an edge width outside 1–1.5 dp.
  cyberEdge,

  /// Cyberpunk: neither a key group's face nor its edge reaches 3:1
  /// against every scene sample (WCAG 1.4.11).
  cyberKeyBoundary,

  /// Cyberpunk: a malformed scene (kind, colours, ink alphas, tilt, drift,
  /// panel scanline alpha) or key shape / state layer.
  cyberScene,

  /// Vaporwave: the recorded weight cue is not ≥ key weight + 200.
  vaporOperatorCue,

  /// Vaporwave: an operator or `=` face less than ΔEOK 0.08 from the digit
  /// face (normal vision).
  vaporOperatorFace,

  /// Vaporwave: an accent face not apart from the digit or function face
  /// (min ΔEOK over normal + CVD < 0.06, or face contrast < 1.2).
  vaporAccentVsDigit,

  /// Vaporwave: a malformed sunset scene (kind, ten opaque colours,
  /// horizon, drift period) or a sample outside its luminance band.
  vaporScene,

  /// Vaporwave: a translucent panel, title-bar or ink colour.
  vaporPanel,

  /// Vaporwave: a key edge that is not the drawn ink, or (light themes) an
  /// ink below 3:1 against a scene sample.
  vaporOutline,

  /// Vaporwave dark themes: a key whose face and ink both fall below 3:1
  /// against a plain floor colour it can sit over, or whose face, ink and
  /// outer bevel highlight all do against a grid-over-floor mix (the
  /// guarantee covers the highlighted top and left edges).
  vaporBoundary,

  /// Bauhaus: the recorded shape cue is not real (digit / operator / `=`
  /// silhouettes, block corners).
  bauhausOperatorCue,

  /// Bauhaus: operator and `=` are not two different primaries, digits are
  /// not neutral, or the function accent is translucent or faint.
  bauhausPrimaries,

  /// Bauhaus: the scene's encoding, field, digit / operator / `=`
  /// visibility or a scene shape colour too close to the ground.
  bauhausScene,

  /// Bauhaus: the display panel's rule below 3:1 on the sheet, or the
  /// sheet's corner accent not distinct from it.
  bauhausPanel,
}

/// Thresholds for one theme (standard or Accessible lock).
@immutable
final class GuardrailLimits {
  const GuardrailLimits({
    required this.labelRatio,
    required this.displayRatio,
    required this.previewRatio,
    required this.caretRatio,
    this.focusRingRatio = ratioLarge,
    this.faceContrast = 1.5,
    this.cvdDeltaE = 0.08,
    this.equalsVsOperatorDeltaE = 0.05,
  });

  /// Standard limits.
  static const GuardrailLimits standard = GuardrailLimits(
    labelRatio: ratioText,
    displayRatio: ratioText,
    previewRatio: ratioLarge,
    caretRatio: ratioLarge,
  );

  /// Accessible lock: every label and display text ≥ 7:1.
  static const GuardrailLimits accessible = GuardrailLimits(
    labelRatio: ratioAccessible,
    displayRatio: ratioAccessible,
    previewRatio: ratioText,
    caretRatio: ratioText,
  );

  /// Limits for [spec] (its `accessible` flag).
  static GuardrailLimits forSpec(ThemeSpec spec) =>
      spec.accessible ? accessible : standard;

  /// Key labels on their faces (digits, operators, `=`, functions).
  final double labelRatio;

  /// Display (expression/result) and error text on display backdrops.
  final double displayRatio;

  /// Live preview / indicator text on display backdrops.
  final double previewRatio;

  /// Caret on display backdrops.
  final double caretRatio;

  /// Focus ring on the background (WCAG 1.4.11).
  final double focusRingRatio;

  /// Operator / `=` face vs digit face contrast.
  final double faceContrast;

  /// Operator / `=` face vs digit face min ΔEOK over normal + CVD.
  final double cvdDeltaE;

  /// `=` face vs operator face min ΔEOK over normal + CVD.
  final double equalsVsOperatorDeltaE;

  /// The label-solving policy matching these limits.
  ContrastPolicy get labelPolicy => labelRatio >= ratioAccessible
      ? ContrastPolicy.accessible
      : ContrastPolicy(minRatio: labelRatio);
}

/// A failed guardrail.
@immutable
final class GuardrailViolation {
  const GuardrailViolation(
    this.rule,
    this.measured,
    this.required, [
    this.detail = '',
  ]);

  final GuardrailRule rule;

  /// The measured value (ratio or ΔEOK); the worst sample for multi-sample
  /// rules.
  final double measured;

  /// The floor it had to reach.
  final double required;

  /// Extra context (e.g. which check of a compound rule failed).
  final String detail;

  @override
  String toString() =>
      'GuardrailViolation(${rule.name}: $measured < $required'
      '${detail.isEmpty ? '' : ', $detail'})';
}

// ---------------------------------------------------------------- samples --

/// Opaque background samples: every gradient stop and, with a pattern,
/// the pattern ink composited over each stop.
List<int> backgroundSamples(BackgroundSpec bg) {
  // Family scenes sample themselves (their own files).
  final scene = switch (bg.kind) {
    BackgroundKind.claySoft => claymorphismSceneSamples(bg),
    BackgroundKind.aeroSky ||
    BackgroundKind.chromeHolo => y2kAeroSceneSamples(bg),
    BackgroundKind.paperSheet => paperInkSceneSamples(bg),
    BackgroundKind.cyberGrid => cyberpunkSceneSamples(bg),
    BackgroundKind.vaporSunset => vaporwaveSceneSamples(bg),
    BackgroundKind.bauhausComposition => bauhausSceneSamples(bg),
    _ => null,
  };
  if (scene != null) return scene;
  final stops = [for (final c in bg.colors) c | 0xFF000000];
  if (stops.isEmpty) return const [0xFF000000];
  // A mesh blends its colours in every proportion: sample its colour hull
  // (Liquid Glass; liquid_glass.dart), whose darkest and lightest points
  // can lie between the stops.
  if (bg.kind == BackgroundKind.meshGradient) return meshHullSamples(stops);
  final out = <int>[...stops];
  if (bg.pattern != BackgroundPattern.none && bg.patternOpacityPermille > 0) {
    final inkAlpha = ((bg.patternColor >>> 24) & 0xFF) == 0
        ? 255
        : (bg.patternColor >>> 24) & 0xFF;
    final alpha = (inkAlpha * bg.patternOpacityPermille + 500) ~/ 1000;
    for (final s in stops) {
      out.add(compositeOver(withAlpha(bg.patternColor, alpha), s));
    }
  }
  return out;
}

/// Everything display text may be drawn on: the surface (composited over
/// the background when translucent) plus [backgroundSamples]. A 7-segment
/// LCD theme (`TypeSpec.lcd`) draws its display on the opaque LCD panel
/// only, so the panel is its one backdrop.
List<int> displayBackdrops(ThemeSpec spec) {
  final bgs = backgroundSamples(spec.background);
  final surface = spec.palette.surface;
  if (spec.type.lcd) {
    return ((surface >>> 24) & 0xFF) == 255
        ? [surface]
        : [compositeOver(surface, bgs.first)];
  }
  final surfaces = ((surface >>> 24) & 0xFF) == 255
      ? [surface]
      : [for (final b in bgs) compositeOver(surface, b)];
  // Liquid Glass draws every display text on its solid-enough backing
  // panel (the surface over the background), never on the bare mesh; the
  // newer families say what their display text sits on themselves.
  if (spec.family == ThemeFamily.liquidGlass) return surfaces;
  final own = switch (spec.family) {
    ThemeFamily.claymorphism => claymorphismDisplayBackdrops(
      spec,
      surfaces,
      bgs,
    ),
    ThemeFamily.y2kChrome => y2kAeroDisplayBackdrops(spec, surfaces, bgs),
    ThemeFamily.paperInk => paperInkDisplayBackdrops(spec, surfaces, bgs),
    ThemeFamily.cyberpunk => cyberpunkDisplayBackdrops(spec, surfaces, bgs),
    ThemeFamily.vaporwave => vaporwaveDisplayBackdrops(spec, surfaces, bgs),
    ThemeFamily.bauhaus => bauhausDisplayBackdrops(spec, surfaces, bgs),
    _ => null,
  };
  return own ?? [...surfaces, ...bgs];
}

/// The opaque colours a key face is seen as (composited over each
/// background sample when translucent).
List<int> faceSamples(int face, List<int> backgrounds) =>
    ((face >>> 24) & 0xFF) == 255
    ? [face]
    : [for (final b in backgrounds) compositeOver(face, b)];

double _minContrast(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

double _minFaceContrast(List<int> a, List<int> b) {
  var m = double.infinity;
  for (final x in a) {
    for (final y in b) {
      final r = contrastRatio(x, y);
      if (r < m) m = r;
    }
  }
  return m;
}

double _minCvd(List<int> a, List<int> b) {
  // Each colour's normal + CVD OKLab once, not once per pair (identical
  // results; translucent faces compare dozens of composited samples).
  final la = [for (final x in a) cvdLabs(x)];
  final lb = [for (final y in b) cvdLabs(y)];
  var m = double.infinity;
  for (final x in la) {
    for (final y in lb) {
      final d = minCvdDeltaELabs(x, y);
      if (d < m) m = d;
    }
  }
  return m;
}

// ------------------------------------------------------------- validation --

/// Every guardrail [spec] fails (empty = ships).
List<GuardrailViolation> validateTheme(
  ThemeSpec spec, {
  GuardrailLimits? limits,
}) {
  final lim = limits ?? GuardrailLimits.forSpec(spec);
  final p = spec.palette;
  final out = <GuardrailViolation>[];
  final bgs = backgroundSamples(spec.background);
  final backdrops = displayBackdrops(spec);

  void ratio(GuardrailRule rule, double measured, double required) {
    if (measured < required) {
      out.add(GuardrailViolation(rule, measured, required));
    }
  }

  void label(GuardrailRule rule, KeyColors k) => ratio(
    rule,
    _minContrast(k.label, faceSamples(k.face, bgs)),
    lim.labelRatio,
  );

  label(GuardrailRule.digitLabel, p.digit);
  label(GuardrailRule.operatorLabel, p.operator);
  label(GuardrailRule.equalsLabel, p.equals);
  label(GuardrailRule.functionLabel, p.function);
  ratio(
    GuardrailRule.displayText,
    _minContrast(p.displayText, backdrops),
    lim.displayRatio,
  );
  ratio(
    GuardrailRule.errorText,
    _minContrast(p.error, backdrops),
    lim.displayRatio,
  );
  ratio(
    GuardrailRule.previewText,
    _minContrast(p.previewText, backdrops),
    lim.previewRatio,
  );
  ratio(GuardrailRule.caret, _minContrast(p.caret, backdrops), lim.caretRatio);
  ratio(
    GuardrailRule.focusRing,
    _minContrast(p.focusRing, bgs),
    lim.focusRingRatio,
  );

  final digit = faceSamples(p.digit.face, bgs);
  final op = faceSamples(p.operator.face, bgs);
  final eq = faceSamples(p.equals.face, bgs);
  if (spec.nonColourOperatorCue == OperatorCue.none) {
    void distinct(GuardrailRule rule, List<int> face) {
      final cr = _minFaceContrast(face, digit);
      if (cr < lim.faceContrast) {
        out.add(GuardrailViolation(rule, cr, lim.faceContrast, 'contrast'));
        return;
      }
      final de = _minCvd(face, digit);
      if (de < lim.cvdDeltaE) {
        out.add(GuardrailViolation(rule, de, lim.cvdDeltaE, 'cvd'));
      }
    }

    distinct(GuardrailRule.operatorVsDigit, op);
    distinct(GuardrailRule.equalsVsDigit, eq);
  }
  final eqOp = _minCvd(eq, op);
  if (eqOp < lim.equalsVsOperatorDeltaE) {
    out.add(
      GuardrailViolation(
        GuardrailRule.equalsVsOperator,
        eqOp,
        lim.equalsVsOperatorDeltaE,
      ),
    );
  }
  final ghost = p.lcdGhost;
  if (ghost != null) {
    var worst = 0.0;
    for (final b in backdrops) {
      final r = contrastRatio(compositeOver(ghost, b), b);
      if (r > worst) worst = r;
    }
    if (worst > lcdGhostMaxRatio) {
      out.add(
        GuardrailViolation(
          GuardrailRule.lcdGhost,
          worst,
          lcdGhostMaxRatio,
          'maximum',
        ),
      );
    }
  }
  if (spec.keyStyle.kind == KeyStyleKind.soft) {
    _validateSoft(spec, lim, bgs, out);
  }
  // Scoped by family (not by `KeyStyleKind.outlined`): Paper & ink draws
  // outlined keys too, without the hard shadow. Neo-brutalism is the only
  // family whose specs are outlined at engine v1–v3, so no output changes.
  if (spec.family == ThemeFamily.neoBrutalism) {
    _validateBrutal(spec, bgs, out);
  }
  if (spec.family == ThemeFamily.liquidGlass) {
    out.addAll(validateGlass(spec, lim, bgs));
  }
  out.addAll(switch (spec.family) {
    ThemeFamily.claymorphism => validateClaymorphism(spec, lim, bgs),
    ThemeFamily.y2kChrome => validateY2kAero(spec, lim, bgs),
    ThemeFamily.paperInk => validatePaperInk(spec, lim, bgs),
    ThemeFamily.cyberpunk => validateCyberpunk(spec, lim, bgs),
    ThemeFamily.vaporwave => validateVaporwave(spec, lim, bgs),
    ThemeFamily.bauhaus => validateBauhaus(spec, lim, bgs),
    _ => const <GuardrailViolation>[],
  });
  return out;
}

/// Lowest and highest outline width of outlined keys, dp × 100.
const int brutalOutlineMinCdp = 200;
const int brutalOutlineMaxCdp = 400;

/// Lowest and highest hard-shadow offset of outlined keys, dp × 100.
const int brutalShadowMinCdp = 300;
const int brutalShadowMaxCdp = 500;

/// The Neo-brutalism rules: every key outline (`KeyColors.edge`) ≥ 3:1
/// against every background sample at 2–4 dp; an opaque, unblurred hard
/// shadow offset by the press depth (3–5 dp); an honest weight cue.
void _validateBrutal(
  ThemeSpec spec,
  List<int> bgs,
  List<GuardrailViolation> out,
) {
  final p = spec.palette;
  final groups = {
    'digit': p.digit,
    'operator': p.operator,
    'equals': p.equals,
    'function': p.function,
  };
  for (final MapEntry(key: name, value: k) in groups.entries) {
    final edge = ((k.edge >>> 24) & 0xFF) == 255 ? k.edge : 0;
    final ratio = edge == 0 ? 1.0 : _minContrast(edge, bgs);
    if (ratio < ratioLarge) {
      out.add(
        GuardrailViolation(
          GuardrailRule.brutalOutline,
          ratio,
          ratioLarge,
          name,
        ),
      );
    }
  }
  final style = spec.keyStyle;
  final width = style.outlineWidthCdp;
  if (width < brutalOutlineMinCdp || width > brutalOutlineMaxCdp) {
    out.add(
      GuardrailViolation(
        GuardrailRule.brutalOutline,
        width / 100,
        brutalOutlineMinCdp / 100,
        'outline width (dp)',
      ),
    );
  }
  final offset = style.shadowOffsetCdp;
  if (((p.shadow >>> 24) & 0xFF) != 255 ||
      style.shadowBlurCdp != 0 ||
      offset < brutalShadowMinCdp ||
      offset > brutalShadowMaxCdp ||
      offset != spec.motion.depthCdp) {
    out.add(
      GuardrailViolation(
        GuardrailRule.brutalShadow,
        offset / 100,
        brutalShadowMinCdp / 100,
        'hard shadow (opaque, no blur, offset = press depth)',
      ),
    );
  }
  if (spec.nonColourOperatorCue == OperatorCue.weight) {
    final bonus = spec.type.operatorWeight - spec.type.keyWeight;
    if (bonus < 200) {
      out.add(
        GuardrailViolation(
          GuardrailRule.brutalOperatorCue,
          bonus.toDouble(),
          200,
          'operator weight bonus',
        ),
      );
    }
  }
}

/// Re-solves outlined keys' outlines to ≥ 3:1 on every background sample
/// (the shadow keeps the digit outline's ink). Null when unreachable.
Palette? _repairBrutal(Palette p, List<int> bgs) {
  KeyColors? outlined(KeyColors k) {
    final edge = solveOnAll(k.edge | 0xFF000000, bgs, ratioLarge);
    return edge == null ? null : k.copyWith(edge: edge);
  }

  final digit = outlined(p.digit);
  final op = outlined(p.operator);
  final eq = outlined(p.equals);
  final fn = outlined(p.function);
  if (digit == null || op == null || eq == null || fn == null) return null;
  return p.copyWith(
    digit: digit,
    operator: op,
    equals: eq,
    function: fn,
    shadow: p.shadow | 0xFF000000,
  );
}

/// Lowest and highest soft-key rim width the guardrail accepts, dp × 100.
const int softRimWidthMinCdp = 100;
const int softRimWidthMaxCdp = 150;

/// The Neumorphism rules (research recommendation 7, §7.2): every key's
/// rim (`KeyColors.edge`) ≥ 3:1 against every background sample at
/// 1–1.5 dp; the accent ≥ the label floor on every surface-faced key (it
/// is their pressed label); an honest weight cue; shadows on the right
/// side of the surface.
void _validateSoft(
  ThemeSpec spec,
  GuardrailLimits lim,
  List<int> bgs,
  List<GuardrailViolation> out,
) {
  final p = spec.palette;
  final groups = {
    'digit': p.digit,
    'operator': p.operator,
    'equals': p.equals,
    'function': p.function,
  };
  for (final MapEntry(key: name, value: k) in groups.entries) {
    final rim = _minContrast(k.edge, bgs);
    if (rim < ratioLarge) {
      out.add(GuardrailViolation(GuardrailRule.softRim, rim, ratioLarge, name));
    }
  }
  final width = spec.keyStyle.outlineWidthCdp;
  if (width < softRimWidthMinCdp || width > softRimWidthMaxCdp) {
    out.add(
      GuardrailViolation(
        GuardrailRule.softRim,
        width / 100,
        softRimWidthMinCdp / 100,
        'rim width (dp)',
      ),
    );
  }
  for (final MapEntry(key: name, value: k) in groups.entries) {
    if (k.face != p.digit.face) continue;
    final pressed = _minContrast(p.accent, faceSamples(k.face, bgs));
    if (pressed < lim.labelRatio) {
      out.add(
        GuardrailViolation(
          GuardrailRule.softPressedLabel,
          pressed,
          lim.labelRatio,
          name,
        ),
      );
    }
  }
  if (spec.nonColourOperatorCue == OperatorCue.weight) {
    final bonus = spec.type.operatorWeight - spec.type.keyWeight;
    if (bonus < 200) {
      out.add(
        GuardrailViolation(
          GuardrailRule.softOperatorCue,
          bonus.toDouble(),
          200,
          'operator weight bonus',
        ),
      );
    }
  }
  final bgY = luminanceArgb(p.background | 0xFF000000);
  final hiY = luminanceArgb(compositeOver(p.highlight, p.background));
  final loY = luminanceArgb(compositeOver(p.shadow, p.background));
  if (hiY <= bgY && bgY < 1) {
    out.add(GuardrailViolation(GuardrailRule.softShadow, hiY, bgY, 'light'));
  }
  if (loY >= bgY && bgY > 0) {
    out.add(GuardrailViolation(GuardrailRule.softShadow, loY, bgY, 'dark'));
  }
}

/// Re-solves soft-key rims (≥ 3:1 on every background sample) and the
/// accent (≥ the label floor on every surface-faced key and ≥ the caret
/// floor on the display backdrops); accent-labelled operators follow the
/// accent. Null when unreachable.
Palette? _repairSoft(
  Palette p,
  Palette original,
  GuardrailLimits lim,
  List<int> bgs,
  List<int> displayBackdrops,
) {
  KeyColors? rimmed(KeyColors k) {
    final edge = solveOnAll(k.edge, bgs, ratioLarge);
    return edge == null ? null : k.copyWith(edge: edge);
  }

  final digit = rimmed(p.digit);
  final op = rimmed(p.operator);
  final eq = rimmed(p.equals);
  final fn = rimmed(p.function);
  if (digit == null || op == null || eq == null || fn == null) return null;
  final surfaceFaces = [
    for (final k in [digit, op, eq, fn])
      if (k.face == digit.face) k.face,
  ];
  final target = lim.labelRatio > lim.caretRatio
      ? lim.labelRatio
      : lim.caretRatio;
  final accent = solveOnAll(p.accent, [
    ...surfaceFaces,
    ...displayBackdrops,
  ], target);
  if (accent == null) return null;
  final accentLabelled =
      original.operator.label == original.accent &&
      original.operator.face == original.digit.face;
  return p.copyWith(
    digit: digit,
    operator: accentLabelled ? op.copyWith(label: accent) : op,
    equals: eq,
    function: fn,
    accent: accent,
    caret: accent,
    focusRing: accent,
  );
}

/// The ceiling for unlit LCD segments against the LCD panel.
const double lcdGhostMaxRatio = 1.3;

/// The ghost-segment colour for an LCD [panel] lit by [segment]: the panel
/// moved toward the segment colour in OKLab until it reaches [ratio]
/// against the panel (default 1.15, comfortably inside
/// [lcdGhostMaxRatio]). Pure and bit-exact (OKLab lerp + bisection).
int lcdGhostColor(int panel, int segment, {double ratio = 1.15}) {
  final p = panel | 0xFF000000;
  final s = segment | 0xFF000000;
  if (contrastRatio(s, p) <= ratio) return s;
  var lo = 0.0;
  var hi = 1.0;
  var best = p;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) / 2;
    final c = lerpArgbOklab(p, s, mid);
    if (contrastRatio(c, p) <= ratio) {
      best = c;
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return best;
}

/// Whether [spec] passes every guardrail.
bool passesGuardrails(ThemeSpec spec, {GuardrailLimits? limits}) =>
    validateTheme(spec, limits: limits).isEmpty;

// ----------------------------------------------------------------- repair --

/// Moves the OKLCH lightness of [argb] (keeping chroma and hue) until it
/// reaches [target] against **every** colour in [backdrops]; tries a
/// neutral, then black/white. Null if unreachable.
int? solveOnAll(int argb, List<int> backdrops, double target) {
  if (_minContrast(argb, backdrops) >= target) return argb;
  final lch = argbToOklch(argb);
  // Binding backdrop: the one closest in luminance on the text's side.
  var meanY = 0.0;
  for (final b in backdrops) {
    meanY += luminanceArgb(b);
  }
  meanY /= backdrops.length;
  final lighter = luminanceArgb(argb) >= meanY;
  var binding = backdrops.first;
  for (final b in backdrops) {
    final y = luminanceArgb(b);
    final by = luminanceArgb(binding);
    if (lighter ? y > by : y < by) binding = b;
  }
  for (final c in [lch.c, 0.0]) {
    final solved = solveLightness(
      l0: lch.l,
      c: c,
      hDeg: lch.h,
      againstArgb: binding,
      target: target,
      preferLighter: lighter,
    );
    if (solved != null && _minContrast(solved, backdrops) >= target) {
      return solved;
    }
  }
  for (final bw in [0xFFFFFFFF, 0xFF000000]) {
    if (_minContrast(bw, backdrops) >= target) return bw;
  }
  return null;
}

/// Re-solves [k]'s label on its (opaque) face to [policy]; moves the face
/// as well when the label alone cannot reach it. Null for translucent
/// faces that fail.
KeyColors? repairKeyLabel(
  KeyColors k,
  ContrastPolicy policy,
  List<int> backgrounds,
) {
  if (_minContrast(k.label, faceSamples(k.face, backgrounds)) >=
      policy.minRatio) {
    return k;
  }
  if (((k.face >>> 24) & 0xFF) != 255) return null;
  final labelLch = argbToOklch(k.label);
  final solved = solveLabel(k.face, labelLch, policy: policy);
  if (solved != null) return k.copyWith(label: solved);
  final pair = repairPair(argbToOklch(k.face), labelLch, policy: policy);
  return k.copyWith(face: pair.face, label: pair.label);
}

bool _distinct(int face, int digit, GuardrailLimits lim) =>
    contrastRatio(face, digit) >= lim.faceContrast &&
    minCvdDeltaE(face, digit) >= lim.cvdDeltaE;

/// Moves [k]'s face lightness away from [digitFace] in 0.06 steps (up to
/// [rounds]) until it is distinct from it (and, if [avoid] is given,
/// ΔE ≥ [avoidDeltaE] from that face too), re-solving the label each step.
KeyColors? separateFromDigit(
  KeyColors k,
  int digitFace,
  GuardrailLimits lim, {
  int? avoid,
  double avoidDeltaE = 0,
  int rounds = 6,
}) {
  bool ok(int face) =>
      _distinct(face, digitFace, lim) &&
      (avoid == null || minCvdDeltaE(face, avoid) >= avoidDeltaE);
  if (ok(k.face)) return k;
  if (((k.face >>> 24) & 0xFF) != 255) return null;
  final face = argbToOklch(k.face);
  final digitL = argbToOklab(digitFace).$1;
  final policy = lim.labelPolicy;
  // Try moving away from the digit face first, then the other way past it.
  for (final up in [face.l >= digitL, face.l < digitL]) {
    var l = face.l;
    for (var i = 0; i < rounds; i++) {
      l = clamp01(l + (up ? 0.06 : -0.06));
      final f = oklchToArgb(l, face.c, face.h);
      if (!ok(f)) continue;
      final fixed = repairKeyLabel(k.copyWith(face: f), policy, [f]);
      if (fixed != null && ok(fixed.face)) return fixed;
    }
  }
  return null;
}

/// Repairs every failing guardrail of [spec] (labels, display texts, then
/// operator/`=` distinctness), and returns the repaired spec, or null if it
/// still fails. A passing spec is returned unchanged.
ThemeSpec? repairTheme(ThemeSpec spec, {GuardrailLimits? limits}) {
  final lim = limits ?? GuardrailLimits.forSpec(spec);
  var violations = validateTheme(spec, limits: lim);
  if (violations.isEmpty) return spec;
  final rules = {for (final v in violations) v.rule};
  var p = spec.palette;
  final bgs = backgroundSamples(spec.background);
  final policy = lim.labelPolicy;

  // 1. Operator / `=` faces away from digits (re-solving their labels).
  if (spec.nonColourOperatorCue == OperatorCue.none) {
    if (rules.contains(GuardrailRule.operatorVsDigit)) {
      final op = separateFromDigit(p.operator, p.digit.face, lim);
      if (op == null) return null;
      p = p.copyWith(operator: op);
    }
    if (rules.contains(GuardrailRule.equalsVsDigit) ||
        rules.contains(GuardrailRule.equalsVsOperator)) {
      final eq = separateFromDigit(
        p.equals,
        p.digit.face,
        lim,
        avoid: p.operator.face,
        avoidDeltaE: lim.equalsVsOperatorDeltaE,
      );
      if (eq == null) return null;
      p = p.copyWith(equals: eq);
    }
  } else if (rules.contains(GuardrailRule.equalsVsOperator)) {
    final eq = separateFromDigit(
      p.equals,
      p.operator.face,
      lim.copyWithDistinct(faceContrast: 1, cvdDeltaE: 0.05),
    );
    if (eq == null) return null;
    p = p.copyWith(equals: eq);
  }

  // Glass: translucent tints and their labels (liquid_glass.dart).
  if (spec.family == ThemeFamily.liquidGlass) {
    final glass = repairGlassKeys(p, lim, bgs);
    if (glass == null) return null;
    p = glass;
  }

  // 2. Labels.
  final digit = repairKeyLabel(p.digit, policy, bgs);
  final op = repairKeyLabel(p.operator, policy, bgs);
  final eq = repairKeyLabel(p.equals, policy, bgs);
  final fn = repairKeyLabel(p.function, policy, bgs);
  if (digit == null || op == null || eq == null || fn == null) return null;
  p = p.copyWith(digit: digit, operator: op, equals: eq, function: fn);

  // 3. Display texts.
  final backdrops = displayBackdrops(spec.copyWith(palette: p));
  final display = solveOnAll(p.displayText, backdrops, lim.displayRatio);
  final error = solveOnAll(p.error, backdrops, lim.displayRatio);
  final preview = solveOnAll(p.previewText, backdrops, lim.previewRatio);
  final caret = solveOnAll(p.caret, backdrops, lim.caretRatio);
  final ring = solveOnAll(p.focusRing, bgs, lim.focusRingRatio);
  if (display == null ||
      error == null ||
      preview == null ||
      caret == null ||
      ring == null) {
    return null;
  }
  p = p.copyWith(
    displayText: display,
    error: error,
    previewText: preview,
    caret: caret,
    focusRing: ring,
  );
  if (rules.contains(GuardrailRule.lcdGhost)) {
    p = p.copyWith(lcdGhost: lcdGhostColor(backdrops.first, p.displayText));
  }
  if (spec.keyStyle.kind == KeyStyleKind.soft) {
    final soft = _repairSoft(p, spec.palette, lim, bgs, backdrops);
    if (soft == null) return null;
    p = soft;
  }
  if (spec.family == ThemeFamily.neoBrutalism) {
    final brutal = _repairBrutal(p, bgs);
    if (brutal == null) return null;
    p = brutal;
  }
  if (spec.family == ThemeFamily.liquidGlass) {
    final glass = repairGlassExtras(p, spec, lim, bgs);
    if (glass == null) return null;
    p = glass;
  }
  final extras = switch (spec.family) {
    ThemeFamily.claymorphism => repairClaymorphismExtras(p, spec, lim, bgs),
    ThemeFamily.y2kChrome => repairY2kAeroExtras(p, spec, lim, bgs),
    ThemeFamily.paperInk => repairPaperInkExtras(p, spec, lim, bgs),
    ThemeFamily.cyberpunk => repairCyberpunkExtras(p, spec, lim, bgs),
    ThemeFamily.vaporwave => repairVaporwaveExtras(p, spec, lim, bgs),
    ThemeFamily.bauhaus => repairBauhausExtras(p, spec, lim, bgs),
    _ => p,
  };
  if (extras == null) return null;
  p = extras;

  final repaired = spec.copyWith(palette: p);
  violations = validateTheme(repaired, limits: lim);
  return violations.isEmpty ? repaired : null;
}

extension on GuardrailLimits {
  GuardrailLimits copyWithDistinct({
    required double faceContrast,
    required double cvdDeltaE,
  }) => GuardrailLimits(
    labelRatio: labelRatio,
    displayRatio: displayRatio,
    previewRatio: previewRatio,
    caretRatio: caretRatio,
    focusRingRatio: focusRingRatio,
    faceContrast: faceContrast,
    cvdDeltaE: cvdDeltaE,
    equalsVsOperatorDeltaE: equalsVsOperatorDeltaE,
  );
}
