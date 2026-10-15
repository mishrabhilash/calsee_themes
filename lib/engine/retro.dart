/// The Retro hardware family's palette builder (spec §5.3 #5; motion brief
/// §2.3 "Retro hardware"; docs/m4-design.md §B): a 90s desk or pocket
/// calculator.
///
/// - **Body** (the background): beige/cream moulded plastic (a light
///   theme, "desk") or black/charcoal plastic (a dark theme, "pocket"),
///   solid or with a faint top-to-bottom sheen.
/// - **Keys**: muted keycaps — cream or dark-brown digits on a desk body,
///   graphite on a pocket body — function keys a step away, and a single
///   coloured accent (orange, red, green, blue or teal) for `=` and, in two
///   themes out of three, the operators; otherwise operators are a
///   contrasting neutral. Operators always carry a heavier label weight
///   (recorded as [OperatorCue.weight], the non-colour cue).
/// - **Display**: a 7-segment panel ([TypeSpec.lcd]) whose colour is the
///   palette `surface`: a grey-green / grey-yellow TN LCD with near-black
///   segments, or (one theme in four) a VFD — dark glass with bright cyan
///   or green segments. `displayText` is the lit segment colour (≥ 4.5:1 on
///   the panel, 7:1 accessible), [Palette.lcdGhost] the unlit segments
///   (≈ 1.10–1.20:1, never above 1.3:1).
///
/// Every draw comes from the same named sub-streams as the generic
/// pipeline (`palette` with its retry streams, `background`, `shape`,
/// `style`, `type`, `motion`, `sound`, `name`), so a Retro theme is a pure
/// function of (seed, engineVersion, accessible). The constants here are
/// part of engine version 2's Retro definition: changing one changes
/// generated themes and needs a version bump.
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

/// The two display technologies a Retro theme can have.
enum RetroPanel {
  /// Twisted-nematic LCD: light grey-green / grey-yellow panel, dark
  /// segments.
  lcd,

  /// Vacuum fluorescent display: dark glass, bright cyan / green segments.
  vfd,
}

/// `[lcd, vfd]` weights: the VFD is the minority variant.
const List<int> retroPanelWeights = [3, 1];

/// Desk (beige) body hue range, tenths of a degree (warm cream).
const IntRange retroDeskHueTenths = IntRange(650, 950);

/// Desk body chroma range, thousandths (always below the bile rule's
/// chroma floor, so beige is never "disliked").
const IntRange retroDeskChromaMilli = IntRange(18, 42);

/// LCD panel: lightness, hue (grey-green to grey-yellow) and chroma.
const IntRange retroLcdLMilli = IntRange(740, 820);
const IntRange retroLcdHueTenths = IntRange(950, 1350);
const IntRange retroLcdChromaMilli = IntRange(25, 55);

/// VFD panel: dark blue-green glass.
const IntRange retroVfdLMilli = IntRange(140, 190);
const IntRange retroVfdHueTenths = IntRange(1900, 2300);
const IntRange retroVfdChromaMilli = IntRange(8, 25);

/// VFD phosphor hues (tenths): cyan, then green.
const List<Weighted<int>> retroVfdSegmentHues = [
  Weighted(1950, 3),
  Weighted(1550, 2),
];

/// The accent hues of `=` (and accent operators), tenths of a degree:
/// orange, red, green, blue, teal — the colours real keypads used. Bile
/// hues (75–115°) are never offered.
const List<Weighted<int>> retroAccentHues = [
  Weighted(550, 4),
  Weighted(270, 3),
  Weighted(1450, 2),
  Weighted(2600, 2),
  Weighted(1950, 1),
];

/// Ghost-segment contrast against the panel × 100, LCD and VFD.
const IntRange retroLcdGhostRatio = IntRange(110, 118);
const IntRange retroVfdGhostRatio = IntRange(106, 112);

/// Builds one unvalidated Retro candidate (the generator repairs and
/// validates it, retries with `palette/retry/n` and finally falls back to
/// a Retro hero).
ThemeSpec buildRetroCandidate(
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
  final pocket = p.pickWeighted(def.brightnessWeights) == 0;
  final brightness = pocket ? ThemeBrightness.dark : ThemeBrightness.light;
  final ranges = def.ranges(brightness);
  final panelKind = RetroPanel.values[p.pickWeighted(retroPanelWeights)];
  final lim = accessible
      ? GuardrailLimits.accessible
      : GuardrailLimits.standard;
  final policy = lim.labelPolicy;

  // Body.
  final bodyL = ranges.background.lMilli.sample(p);
  final int bodyHue;
  final int bodyC;
  if (pocket) {
    bodyHue = p.nextHueTenths();
    bodyC = p.nextIntIn(
      ranges.background.chroma.lo,
      ranges.background.chroma.hi,
    );
  } else {
    bodyHue = retroDeskHueTenths.sample(p);
    bodyC = retroDeskChromaMilli.sample(p);
  }
  final body = oklchToArgb(bodyL / 1000, bodyC / 1000, bodyHue / 10);

  // Accent.
  final accentHue = _wrap(
    pickWeightedValue(p, retroAccentHues) + p.nextJitterTenths(80),
  );
  final accentOps = p.nextChance(2, 3);

  // Key faces (lightness × 1000, chroma × 1000, hue tenths).
  final lightDigits = !pocket && p.nextChance(3, 5);
  final keyHue = bodyHue;
  var digitL = ranges.digit.lMilli.sample(p);
  var fnL = ranges.function.lMilli.sample(p);
  if (!pocket && !lightDigits) {
    // Dark-brown digits on beige: function keys a light warm grey.
    digitL = 300 + p.nextInt(81); // 0.30–0.38
    fnL = 680 + p.nextInt(61); // 0.68–0.74
  }
  if (pocket && digitL < bodyL + 80) digitL = bodyL + 80;
  final digitC = p.nextIntIn(ranges.digit.chroma.lo, ranges.digit.chroma.hi);
  final fnC = p.nextIntIn(ranges.function.chroma.lo, ranges.function.chroma.hi);

  var opL = ranges.operator.lMilli.sample(p);
  var eqL = ranges.equals.lMilli.sample(p);
  final opRel = p.nextIntIn(
    ranges.operator.chroma.lo,
    ranges.operator.chroma.hi,
  );
  final eqRel = p.nextIntIn(ranges.equals.chroma.lo, ranges.equals.chroma.hi);
  var neutralOpL = pocket
      ? 640 +
            p.nextInt(81) // light grey on graphite
      : (lightDigits ? 300 + p.nextInt(61) : 830 + p.nextInt(51));
  final neutralOpC = p.nextIntIn(0, 15);

  if (accessible) {
    // 7:1 labels exist only on faces with Y ≤ 0.1 (white) or ≥ 0.3
    // (black): keep every face out of the mid-tones.
    int out(int l) => l > 440 && l < 700 ? (l < 570 ? 440 : 700) : l;
    digitL = out(digitL);
    fnL = out(fnL);
    neutralOpL = out(neutralOpL);
    opL = pocket ? (opL < 720 ? 720 : opL) : (opL > 450 ? 450 : opL);
    eqL = pocket ? (eqL < 720 ? 720 : eqL) : (eqL > 440 ? 440 : eqL);
  }
  if (accentOps && (eqL - opL).abs() < 80) {
    final hi = accessible && !pocket ? 440 : ranges.equals.lMilli.hi;
    eqL = opL + 80 <= hi ? opL + 80 : opL - 80;
  }

  Lch accent(int lMilli, int rel, int cap) {
    final l = lMilli / 1000;
    final c = rel / 1000 * maxChroma(l, accentHue / 10);
    return (l: l, c: c < cap / 1000 ? c : cap / 1000, h: accentHue / 10);
  }

  final digitFace = (l: digitL / 1000, c: digitC / 1000, h: keyHue / 10);
  final fnFace = (l: fnL / 1000, c: fnC / 1000, h: keyHue / 10);
  final opFace = accentOps
      ? accent(opL, opRel, ranges.operator.chroma.capMilli)
      : (l: neutralOpL / 1000, c: neutralOpC / 1000, h: keyHue / 10);
  final eqFace = accent(eqL, eqRel, ranges.equals.chroma.capMilli);

  final labelChroma = p.nextIntIn(8, ranges.labelMaxChromaMilli) / 1000;
  KeyColors key(Lch face) {
    final start = face.l < 0.58 ? 0.97 : 0.17;
    final pair = repairPair(face, (
      l: start,
      c: labelChroma,
      h: face.h,
    ), policy: policy);
    final f = pair.faceLch;
    // The keycap skirt: a darker tone of the face (light faces) or a
    // slightly lighter one (near-black faces, so it still reads).
    final skirtL = f.l < 0.26 ? f.l + 0.06 : f.l - 0.11;
    return KeyColors(
      face: pair.face,
      label: pair.label,
      edge: oklchToArgb(clamp01(skirtL), f.c * 0.9, f.h),
    );
  }

  final digit = key(digitFace);
  final function = key(fnFace);
  final operator = key(opFace);
  var equals = key(eqFace);
  if (minCvdDeltaE(equals.face, operator.face) < 0.065) {
    // `=` must stand apart from the operators: move it 0.10 in lightness.
    final f = argbToOklch(equals.face);
    final o = argbToOklch(operator.face);
    final up = f.l >= o.l ? f.l + 0.10 <= 0.92 : f.l - 0.10 < 0.12;
    equals = key((l: clamp01(f.l + (up ? 0.10 : -0.10)), c: f.c, h: f.h));
  }

  // Panel and segments.
  final vfd = panelKind == RetroPanel.vfd;
  final int panel;
  final int segmentStart;
  final int previewStart;
  final int errorStart;
  final int caretStart;
  final int ghostRatio;
  if (vfd) {
    final hue = retroVfdHueTenths.sample(p) / 10;
    panel = oklchToArgb(
      retroVfdLMilli.sample(p) / 1000,
      retroVfdChromaMilli.sample(p) / 1000,
      hue,
    );
    final segHue =
        _wrap(
          pickWeightedValue(p, retroVfdSegmentHues) + p.nextJitterTenths(80),
        ) /
        10;
    final segL = p.nextIntIn(840, 900) / 1000;
    final segC = p.nextIntIn(600, 900) / 1000 * maxChroma(segL, segHue);
    segmentStart = oklchToArgb(segL, segC < 0.16 ? segC : 0.16, segHue);
    previewStart = oklchToArgb(0.70, 0.07, segHue);
    errorStart = oklchToArgb(0.74, 0.15, 40);
    caretStart = oklchToArgb(0.82, 0.12, segHue);
    ghostRatio = retroVfdGhostRatio.sample(p);
  } else {
    final hue = retroLcdHueTenths.sample(p);
    final panelL = retroLcdLMilli.sample(p) / 1000;
    panel = oklchToArgb(panelL, retroLcdChromaMilli.sample(p) / 1000, hue / 10);
    // Segments: warm black (the panel's hue) or the blue-black of
    // twisted-nematic cells.
    final segHue = p.nextChance(1, 2)
        ? _wrap(hue + p.nextJitterTenths(150))
        : p.nextIntIn(2400, 2700);
    final segL = p.nextIntIn(180, 260) / 1000;
    final segC = p.nextIntIn(10, 30) / 1000;
    segmentStart = oklchToArgb(segL, segC, segHue / 10);
    previewStart = oklchToArgb(0.40, segC, segHue / 10);
    errorStart = oklchToArgb(0.34, 0.12, 25);
    caretStart = oklchToArgb(0.30, 0.10, accentHue / 10);
    ghostRatio = retroLcdGhostRatio.sample(p);
  }
  final panels = [panel];
  int onPanel(int start, double target) =>
      solveOnAll(start, panels, target) ?? blackOrWhite(panel);
  final previewTarget = lim.previewRatio < ratioText
      ? ratioText
      : lim.previewRatio;
  final displayText = onPanel(segmentStart, lim.displayRatio);
  final previewText = onPanel(previewStart, previewTarget);
  final error = onPanel(errorStart, lim.displayRatio);
  final caret = onPanel(caretStart, lim.caretRatio);
  final ghost = lcdGhostColor(panel, displayText, ratio: ghostRatio / 100);

  // Body: solid, or a faint moulded sheen.
  final background = _background(
    Rng.stream(seed, RngTag.background),
    def,
    bodyL,
    bodyC,
    bodyHue,
    body,
  );
  final bgs = backgroundSamples(background);

  // Accent (chips, focus ring) on the body.
  final accentL = pocket ? 0.80 : 0.45;
  final accentC = 0.7 * maxChroma(accentL, accentHue / 10);
  final accentArgb =
      solveOnAll(
        oklchToArgb(accentL, accentC < 0.16 ? accentC : 0.16, accentHue / 10),
        bgs,
        lim.focusRingRatio,
      ) ??
      blackOrWhite(body);

  final palette = Palette(
    background: body,
    surface: panel,
    displayText: displayText,
    previewText: previewText,
    error: error,
    caret: caret,
    focusRing: accentArgb,
    accent: accentArgb,
    digit: digit,
    operator: operator,
    equals: equals,
    function: function,
    shadow: pocket ? 0x8C000000 : 0x47000000,
    highlight: pocket ? 0x2EFFFFFF : 0x8CFFFFFF,
    seedColor: equals.face,
    lcdGhost: ghost,
  );

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
    extrudeDepthCdp: motion.depthCdp,
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
    widthPermille: 750 + 50 * t.nextInt(3),
    lcd: true,
  );
  // Desk calculators click one time in three; pocket ones beep (motion
  // brief §2.3), and from engine v3 one pocket theme in three plays
  // 8-bit chiptune instead.
  final soundRng = Rng.stream(seed, RngTag.sound);
  final SoundPackId sound;
  if (!pocket) {
    sound = soundRng.nextChance(1, 3) ? SoundPackId.mechClicky : def.sound;
  } else if (engineVersion >= 3) {
    sound = soundRng.nextChance(1, 3) ? SoundPackId.chiptune : def.sound;
  } else {
    sound = def.sound;
  }
  final name = generateThemeName(
    rng: Rng.stream(seed, RngTag.name),
    accentArgb: equals.face,
    family: ThemeFamily.retro,
    dark: pocket,
  );

  return ThemeSpec(
    seed: seed,
    family: ThemeFamily.retro,
    engineVersion: engineVersion,
    brightness: brightness,
    accessible: accessible,
    palette: palette,
    keyShape: keyShape,
    keyStyle: keyStyle,
    type: type,
    background: background,
    motion: motion,
    sound: sound,
    name: name,
    nonColourOperatorCue: def.nonColourOperatorCue,
  );
}

int _wrap(int tenths) => tenths % 3600;

BackgroundSpec _background(
  Rng b,
  FamilyDefinition def,
  int bodyL,
  int bodyC,
  int bodyHue,
  int body,
) {
  final kind = pickWeightedValue(b, def.backgrounds);
  if (kind != BackgroundKind.linearGradient) {
    return BackgroundSpec(
      kind: BackgroundKind.solid,
      colors: List.unmodifiable([body]),
    );
  }
  // A moulded-plastic sheen: a slightly darker bottom.
  final l2 = bodyL - b.nextIntIn(15, 35);
  final second = oklchToArgb(l2 / 1000, bodyC / 1000, bodyHue / 10);
  return BackgroundSpec(
    kind: BackgroundKind.linearGradient,
    colors: List.unmodifiable([body, second]),
  );
}
