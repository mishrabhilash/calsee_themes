/// WCAG 2.2 contrast on 8-bit ARGB and OKLCH-lightness repair
/// (research theme-engine.md §4, Recommendations 3–4).
///
/// Ratios are computed on the final quantised colour and are **never
/// rounded**: 4.499:1 fails 4.5:1.
library;

import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/oklab.dart';

/// WCAG relative luminance of linear sRGB.
double luminanceLin(LinRgb c) => 0.2126 * c.$1 + 0.7152 * c.$2 + 0.0722 * c.$3;

/// WCAG relative luminance of an ARGB colour (alpha ignored; 0.04045
/// threshold via the decode table).
double luminanceArgb(int argb) => luminanceLin(argbToLin(argb));

/// Contrast ratio of two luminances, `(Y_lighter + 0.05) / (Y_darker +
/// 0.05)`, in [1, 21].
double contrastY(double y1, double y2) =>
    y1 > y2 ? (y1 + 0.05) / (y2 + 0.05) : (y2 + 0.05) / (y1 + 0.05);

/// Contrast ratio between two ARGB colours (alpha ignored).
double contrastRatio(int a, int b) =>
    contrastY(luminanceArgb(a), luminanceArgb(b));

/// Contrast of a possibly translucent [fg] composited over opaque [bg],
/// against [bg].
double contrastOver(int fg, int bg) => contrastRatio(compositeOver(fg, bg), bg);

/// Luminance at which black and white give equal contrast:
/// `sqrt(1.05 · 0.05) − 0.05`. Below it, lighter labels win.
const double yEqualContrast = 0.17912878474779200;

/// Upper edge of the mid-tone band where WCAG 2 over-rates dark labels
/// (APCA's neutral polarity crossover, research §4.5).
const double yPolarityBandTop = 0.342;

/// Faces darker than this are "dark faces" (≈ L_ok 0.37).
const double yDarkFace = 0.05;

/// `max(CR(bg, white), CR(bg, black)) ≥ √21` for every background, so any
/// target up to this is always reachable with black or white.
const double alwaysReachableRatio = 4.58257569495584;

/// WCAG AA text.
const double ratioText = 4.5;

/// WCAG AA large text / non-text (1.4.11).
const double ratioLarge = 3;

/// WCAG AAA text (Accessible lock).
const double ratioAccessible = 7;

/// Label-solving policy: floors plus the two WCAG-2 blind-spot heuristics
/// (research §4.5). Immutable; configurable per family or Accessible lock.
final class ContrastPolicy {
  const new({
    this.minRatio = ratioText,
    this.darkFaceRatio = ratioAccessible,
    this.darkFaceY = yDarkFace,
    this.polarityRule = true,
    this.darkFaceBoost = true,
  });

  /// Standard policy: 4.5:1 floor, 7:1 on dark faces, polarity rule on.
  static const ContrastPolicy standard = ContrastPolicy();

  /// Accessible lock: 7:1 floor everywhere.
  static const ContrastPolicy accessible = ContrastPolicy(
    minRatio: ratioAccessible,
  );

  /// The hard floor every label must reach.
  final double minRatio;

  /// Target on faces with luminance below [darkFaceY] (when
  /// [darkFaceBoost]).
  final double darkFaceRatio;

  /// Luminance under which a face counts as dark.
  final double darkFaceY;

  /// Prefer a light label on mid-tone faces (`0.179 < Y < 0.342`) whenever
  /// it reaches the floor.
  final bool polarityRule;

  /// Solve labels on dark faces to [darkFaceRatio].
  final bool darkFaceBoost;

  /// The ratio to aim for on a face of luminance [faceY].
  double targetFor(double faceY) {
    if (darkFaceBoost && faceY < darkFaceY && darkFaceRatio > minRatio) {
      // White on a face with Y < 0.05 is ≥ 10.5:1, so this is reachable.
      return darkFaceRatio;
    }
    return minRatio;
  }

  /// Whether a face of luminance [faceY] is in the mid-tone polarity band.
  bool inPolarityBand(double faceY) =>
      polarityRule && faceY > yEqualContrast && faceY < yPolarityBandTop;
}

/// Bisects the OKLCH lightness of a colour with chroma [c] and hue [hDeg],
/// starting at [l0], until its quantised ARGB reaches [target] against
/// [againstArgb]. Returns null if neither direction can reach it.
///
/// Direction: toward white first when the background is darker than
/// [yEqualContrast] (or [preferLighter] when given), then the other way.
/// [lighterFrom] / [darkerFrom] override the bisection start for that
/// direction. The result always passes, even where quantisation makes
/// Y(L) locally non-monotone, because only verified L values are kept.
int? solveLightness({
  required double l0,
  required double c,
  required double hDeg,
  required int againstArgb,
  required double target,
  bool? preferLighter,
  double? lighterFrom,
  double? darkerFrom,
}) {
  final bgY = luminanceArgb(againstArgb);
  int argbAt(double l) => linToArgb(mapOklch(l, c, hDeg));
  bool ok(double l) => contrastY(luminanceArgb(argbAt(l)), bgY) >= target;
  final lighterFirst = preferLighter ?? bgY < yEqualContrast;
  for (final lighter in [lighterFirst, !lighterFirst]) {
    final start = (lighter ? lighterFrom : darkerFrom) ?? l0;
    if (ok(start)) {
      // Only accept the start if it is on the requested side, or it is l0.
      if (start == l0 || lighter == (luminanceArgb(argbAt(start)) > bgY)) {
        return argbAt(start);
      }
    }
    final end = lighter ? 1.0 : 0.0;
    if (!ok(end)) continue;
    var bad = start;
    var good = end;
    for (var i = 0; i < 30; i++) {
      final mid = (bad + good) * 0.5;
      if (ok(mid)) {
        good = mid;
      } else {
        bad = mid;
      }
    }
    return argbAt(good);
  }
  return null;
}

/// [solveLightness] that throws when the target is unreachable.
int solveForContrast(
  double l0,
  double c,
  double hDeg,
  int bgArgb,
  double target,
) =>
    solveLightness(
      l0: l0,
      c: c,
      hDeg: hDeg,
      againstArgb: bgArgb,
      target: target,
    ) ??
    (throw StateError(
      'contrast $target unreachable against '
      '0x${bgArgb.toRadixString(16)}',
    ));

/// Solves a label (start colour [label]) on the opaque face [faceArgb]
/// under [policy]: dark-face boost, then the polarity rule, then the plain
/// floor. Returns null only if even the floor is unreachable at this
/// chroma/hue (possible above 4.583:1).
int? solveLabel(
  int faceArgb,
  Lch label, {
  ContrastPolicy policy = ContrastPolicy.standard,
}) {
  final faceY = luminanceArgb(faceArgb);
  final target = policy.targetFor(faceY);
  if (policy.inPolarityBand(faceY)) {
    final faceL = argbToOklab(faceArgb).$1;
    final light = solveLightness(
      l0: label.l,
      c: label.c,
      hDeg: label.h,
      againstArgb: faceArgb,
      target: policy.minRatio,
      preferLighter: true,
      lighterFrom: label.l > faceL ? label.l : faceL,
    );
    if (light != null && luminanceArgb(light) > faceY) return light;
  }
  final boosted = solveLightness(
    l0: label.l,
    c: label.c,
    hDeg: label.h,
    againstArgb: faceArgb,
    target: target,
  );
  if (boosted != null || target <= policy.minRatio) return boosted;
  return solveLightness(
    l0: label.l,
    c: label.c,
    hDeg: label.h,
    againstArgb: faceArgb,
    target: policy.minRatio,
  );
}

/// A repaired (face, label) pair.
typedef RepairedPair = ({int face, int label, Lch faceLch, int rounds});

/// Repairs a label/face pair to [policy] (research §4.3 repair order):
///
/// 1. move the **label** lightness (keeping hue and chroma);
/// 2. if the label had to go to pure black/white or lost most of its
///    chroma, move the **face** lightness 0.04 away from the label and
///    retry (up to 4 rounds);
/// 3. fall back to a neutral label, then pure `#000` / `#FFF`; if even
///    those fail (targets above 4.583:1 on mid-tone faces), keep moving the
///    face away until they pass.
///
/// The returned pair always meets `policy.minRatio` (and the dark-face
/// target where it applies). Throws only for targets above 21:1.
RepairedPair repairPair(
  Lch face,
  Lch label, {
  ContrastPolicy policy = ContrastPolicy.standard,
}) {
  if (policy.minRatio > 21) {
    throw ArgumentError.value(policy.minRatio, 'minRatio', 'above 21:1');
  }
  RepairedPair pair(int f, int l, double fl, int rounds) => (
    face: f,
    label: l,
    faceLch: (l: fl, c: face.c, h: face.h),
    rounds: rounds,
  );

  // Steps 1–2: chromatic label, moving the face away when needed.
  final labelLighter = label.l >= face.l;
  RepairedPair? fallback;
  var faceL = face.l;
  for (var round = 0; round < 4; round++) {
    final faceArgb = oklchToArgb(faceL, face.c, face.h);
    final solved = solveLabel(faceArgb, label, policy: policy);
    if (solved != null) {
      final got = argbToOklch(solved);
      final extreme = got.l <= 0.0001 || got.l >= 0.9999;
      final stripped = label.c > 0.01 && got.c < label.c * 0.5;
      if (!extreme && !stripped) return pair(faceArgb, solved, faceL, round);
      fallback ??= pair(faceArgb, solved, faceL, round);
    }
    faceL = clamp01(faceL + (labelLighter ? -0.04 : 0.04));
  }
  if (fallback != null) return fallback;

  // Step 3: neutral label (then black/white), moving the original face
  // toward whichever end gives the label room, until the floor is met.
  faceL = face.l;
  for (var round = 4; round < 40; round++) {
    final faceArgb = oklchToArgb(faceL, face.c, face.h);
    final faceY = luminanceArgb(faceArgb);
    for (final t in {policy.targetFor(faceY), policy.minRatio}) {
      final neutral = solveLightness(
        l0: label.l,
        c: 0,
        hDeg: 0,
        againstArgb: faceArgb,
        target: t,
      );
      if (neutral != null) return pair(faceArgb, neutral, faceL, round);
    }
    faceL = clamp01(faceL + (faceY < yEqualContrast ? -0.04 : 0.04));
  }
  throw StateError('repairPair did not converge');
}

/// Pure black or white, whichever contrasts more with [bgArgb].
int blackOrWhite(int bgArgb) =>
    luminanceArgb(bgArgb) < yEqualContrast ? 0xFFFFFFFF : 0xFF000000;
