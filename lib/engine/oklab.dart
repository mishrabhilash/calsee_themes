/// OKLab / OKLCH ↔ linear sRGB ↔ 8-bit ARGB, and gamut mapping
/// (research theme-engine.md §2–3, Recommendations 1–2).
///
/// Matrices are the CSS Color 4 compositions (white maps to exactly L = 1,
/// C ≈ 0). They are frozen under `engineVersion` 1: changing any constant
/// changes generated themes.
///
/// Colours in the engine are plain `int` ARGB (`0xAARRGGBB`).
library;

import 'package:calsee_themes/engine/bitexact_math.dart';

/// Linear-light sRGB triple (components nominally in [0, 1]).
typedef LinRgb = (double r, double g, double b);

/// OKLab triple.
typedef Lab = (double l, double a, double b);

/// OKLCH: lightness [0, 1], chroma ≥ 0, hue in degrees [0, 360).
typedef Lch = ({double l, double c, double h});

const List<double> _rgb2lms = [
  0.412221469470763, 0.5363325372617348, 0.0514459932675022, //
  0.2119034958178252, 0.6806995506452344, 0.1073969535369406, //
  0.08830245919005643, 0.2817188391361215, 0.6299787016738222,
];
const List<double> _lms2rgb = [
  4.076741636075957, -3.307711539258061, 0.2309699031821043, //
  -1.268437973285032, 2.609757349287689, -0.3413193760026572, //
  -0.004196076138675531, -0.7034186179359363, 1.707614694074612,
];
const List<double> _lms2lab = [
  0.2104542683093140, 0.7936177747023054, -0.0040720430116193, //
  1.9779985324311684, -2.4285922420485799, 0.4505937096174110, //
  0.0259040424655478, 0.7827717124575296, -0.8086757549230774,
];
const List<double> _lab2lms = [
  1, 0.3963377773761749, 0.2158037573099136, //
  1, -0.1055613458156586, -0.0638541728258133, //
  1, -0.0894841775298119, -1.2914855480194092,
];

/// Upper bound of the chroma bisection (sRGB max chroma is ≈ 0.3225).
const double chromaSearchMax = 0.4;

/// Chroma at or below which hue is powerless (CSS Color 4).
const double achromaticChroma = 0.000004;

/// Linear sRGB → OKLab (sign-matched cube root).
Lab linToOklab(LinRgb c) {
  final (r, g, b) = c;
  final l = detCbrt(_rgb2lms[0] * r + _rgb2lms[1] * g + _rgb2lms[2] * b);
  final m = detCbrt(_rgb2lms[3] * r + _rgb2lms[4] * g + _rgb2lms[5] * b);
  final s = detCbrt(_rgb2lms[6] * r + _rgb2lms[7] * g + _rgb2lms[8] * b);
  return (
    _lms2lab[0] * l + _lms2lab[1] * m + _lms2lab[2] * s,
    _lms2lab[3] * l + _lms2lab[4] * m + _lms2lab[5] * s,
    _lms2lab[6] * l + _lms2lab[7] * m + _lms2lab[8] * s,
  );
}

/// OKLab → linear sRGB (may be out of gamut).
LinRgb oklabToLin(Lab c) {
  final (bigL, a, b) = c;
  final l1 = _lab2lms[0] * bigL + _lab2lms[1] * a + _lab2lms[2] * b;
  final m1 = _lab2lms[3] * bigL + _lab2lms[4] * a + _lab2lms[5] * b;
  final s1 = _lab2lms[6] * bigL + _lab2lms[7] * a + _lab2lms[8] * b;
  final l = l1 * l1 * l1;
  final m = m1 * m1 * m1;
  final s = s1 * s1 * s1;
  return (
    _lms2rgb[0] * l + _lms2rgb[1] * m + _lms2rgb[2] * s,
    _lms2rgb[3] * l + _lms2rgb[4] * m + _lms2rgb[5] * s,
    _lms2rgb[6] * l + _lms2rgb[7] * m + _lms2rgb[8] * s,
  );
}

/// OKLCH (hue in degrees) → OKLab.
Lab oklchToOklab(double l, double c, double hDeg) {
  final (s, co) = detSinCosDeg(hDeg);
  return (l, c * co, c * s);
}

/// OKLab → OKLCH. Hue is 0 for achromatic colours.
Lch oklabToOklch(Lab lab) {
  final (l, a, b) = lab;
  final c = detSqrt(a * a + b * b);
  final h = c <= achromaticChroma ? 0.0 : detAtan2Deg(b, a);
  return (l: l, c: c, h: h);
}

/// Whether [c] lies in the sRGB gamut, with tolerance [eps].
bool inGamut(LinRgb c, [double eps = 1e-9]) =>
    c.$1 >= -eps &&
    c.$1 <= 1 + eps &&
    c.$2 >= -eps &&
    c.$2 <= 1 + eps &&
    c.$3 >= -eps &&
    c.$3 <= 1 + eps;

/// Largest in-gamut chroma at lightness [l] and hue [hDeg]: 24 bisection
/// steps on [0, 0.4] (error < 3e-8). 0 at L ≤ 0 or L ≥ 1.
double maxChroma(double l, double hDeg) {
  if (l <= 0 || l >= 1) return 0;
  final (s, co) = detSinCosDeg(hDeg);
  var lo = 0.0;
  var hi = chromaSearchMax;
  for (var i = 0; i < 24; i++) {
    final mid = (lo + hi) * 0.5;
    if (inGamut(oklabToLin((l, mid * co, mid * s)))) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// Gamut-maps OKLCH to linear sRGB by constant-L, constant-h chroma
/// reduction (exact boundary via [maxChroma]), then clamps float noise.
/// White for L ≥ 1, black for L ≤ 0. Luminance is non-decreasing in L along
/// this map, which the contrast solver relies on.
LinRgb mapOklch(double l, double c, double hDeg) {
  if (l >= 1) return (1, 1, 1);
  if (l <= 0) return (0, 0, 0);
  var rgb = oklabToLin(oklchToOklab(l, c, hDeg));
  if (!inGamut(rgb)) {
    rgb = oklabToLin(oklchToOklab(l, maxChroma(l, hDeg), hDeg));
  }
  return (clamp01(rgb.$1), clamp01(rgb.$2), clamp01(rgb.$3));
}

/// Quantises linear sRGB to opaque 8-bit ARGB.
int linToArgb(LinRgb c) =>
    0xFF000000 | (encode8(c.$1) << 16) | (encode8(c.$2) << 8) | encode8(c.$3);

/// Decodes the RGB channels of [argb] to linear light (alpha ignored).
LinRgb argbToLin(int argb) => (
  srgbDecode[(argb >> 16) & 0xFF],
  srgbDecode[(argb >> 8) & 0xFF],
  srgbDecode[argb & 0xFF],
);

/// OKLCH → gamut-mapped, quantised opaque ARGB.
int oklchToArgb(double l, double c, double hDeg) =>
    linToArgb(mapOklch(l, c, hDeg));

/// OKLCH with hue in integer tenths of a degree → ARGB.
int oklchTenthsToArgb(double l, double c, int hueTenths) =>
    oklchToArgb(l, c, hueTenths / 10);

/// ARGB → OKLab.
Lab argbToOklab(int argb) => linToOklab(argbToLin(argb));

/// ARGB → OKLCH.
Lch argbToOklch(int argb) => oklabToOklch(argbToOklab(argb));

/// Euclidean distance in OKLab (ΔEOK; 0.02 ≈ one JND).
double deltaEOK(Lab x, Lab y) {
  final dl = x.$1 - y.$1;
  final da = x.$2 - y.$2;
  final db = x.$3 - y.$3;
  return detSqrt(dl * dl + da * da + db * db);
}

/// ΔEOK between two ARGB colours.
double deltaEOKArgb(int a, int b) => deltaEOK(argbToOklab(a), argbToOklab(b));

/// Interpolates two ARGB colours in OKLab (t = 0 → [a], 1 → [b]); alpha is
/// interpolated linearly. For theme cross-fades (research §5.4).
int lerpArgbOklab(int a, int b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  final x = argbToOklab(a);
  final y = argbToOklab(b);
  final lab = (
    x.$1 + (y.$1 - x.$1) * t,
    x.$2 + (y.$2 - x.$2) * t,
    x.$3 + (y.$3 - x.$3) * t,
  );
  final rgb = oklabToLin(lab);
  final alphaA = (a >>> 24) & 0xFF;
  final alphaB = (b >>> 24) & 0xFF;
  final alpha = (alphaA + (alphaB - alphaA) * t).round().clamp(0, 255);
  final opaque = linToArgb((clamp01(rgb.$1), clamp01(rgb.$2), clamp01(rgb.$3)));
  return (alpha << 24) | (opaque & 0x00FFFFFF);
}

/// Replaces the alpha channel of [argb] with [alpha] (0–255).
int withAlpha(int argb, int alpha) =>
    ((alpha & 0xFF) << 24) | (argb & 0x00FFFFFF);

/// Source-over composite of [fg] (any alpha) on opaque [bg], per channel in
/// encoded sRGB (what Flutter's `Color.alphaBlend` does). Returns opaque.
int compositeOver(int fg, int bg) {
  final a = (fg >>> 24) & 0xFF;
  if (a == 255) return fg | 0xFF000000;
  if (a == 0) return bg | 0xFF000000;
  int ch(int shift) {
    final f = (fg >> shift) & 0xFF;
    final b = (bg >> shift) & 0xFF;
    return ((f * a + b * (255 - a)) / 255).round();
  }

  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}
