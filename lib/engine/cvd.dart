/// Colour-vision-deficiency simulation and distinctness (research
/// theme-engine.md §6, Recommendation 6).
///
/// Protanopia and deuteranopia: Machado, Oliveira & Fernandes 2009
/// (severity 1.0). Tritanopia: Brettel 1997 as precomputed by libDaltonLens
/// (Machado is not valid for tritans). All matrices apply to **linear**
/// sRGB; results are clamped to [0, 1].
library;

import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/oklab.dart';

/// Simulated dichromacy.
enum Cvd {
  /// Red-blind (Machado 2009, severity 1).
  protan,

  /// Green-blind (Machado 2009, severity 1).
  deutan,

  /// Blue-blind (Brettel 1997).
  tritan,
}

/// Machado 2009 protanopia, severity 1.0 (row-major, linear RGB).
const List<double> machadoProtan = [
  0.152286, 1.052583, -0.204868, //
  0.114503, 0.786281, 0.099216, //
  -0.003882, -0.048116, 1.051998,
];

/// Machado 2009 deuteranopia, severity 1.0 (row-major, linear RGB).
const List<double> machadoDeutan = [
  0.367322, 0.860646, -0.227968, //
  0.280085, 0.672501, 0.047413, //
  -0.011820, 0.042940, 0.968881,
];

/// Brettel 1997 tritanopia, half-plane where `n · rgb ≥ 0`.
const List<double> brettelTritan1 = [
  1.01277, 0.13548, -0.14826, //
  -0.01243, 0.86812, 0.14431, //
  0.07589, 0.80500, 0.11911,
];

/// Brettel 1997 tritanopia, half-plane where `n · rgb < 0`.
const List<double> brettelTritan2 = [
  0.93678, 0.18979, -0.12657, //
  0.06154, 0.81526, 0.12320, //
  -0.37562, 1.12767, 0.24796,
];

/// Separating-plane normal for the Brettel tritan half-planes.
const List<double> brettelTritanNormal = [0.03901, -0.02788, -0.01113];

LinRgb _mul(List<double> m, LinRgb c) => (
  clamp01(m[0] * c.$1 + m[1] * c.$2 + m[2] * c.$3),
  clamp01(m[3] * c.$1 + m[4] * c.$2 + m[5] * c.$3),
  clamp01(m[6] * c.$1 + m[7] * c.$2 + m[8] * c.$3),
);

/// Full-severity simulation of [type] on linear sRGB [c].
LinRgb simulateCvd(LinRgb c, Cvd type) => switch (type) {
  Cvd.protan => _mul(machadoProtan, c),
  Cvd.deutan => _mul(machadoDeutan, c),
  Cvd.tritan => _mul(
    brettelTritanNormal[0] * c.$1 +
                brettelTritanNormal[1] * c.$2 +
                brettelTritanNormal[2] * c.$3 >=
            0
        ? brettelTritan1
        : brettelTritan2,
    c,
  ),
};

/// Simulates [type] on an ARGB colour; returns opaque quantised ARGB.
int simulateCvdArgb(int argb, Cvd type) =>
    linToArgb(simulateCvd(argbToLin(argb), type));

/// ΔEOK between [argbA] and [argbB] as seen under [type] (null = normal
/// vision).
double cvdDeltaE(int argbA, int argbB, [Cvd? type]) {
  final a = argbToLin(argbA);
  final b = argbToLin(argbB);
  if (type == null) return deltaEOK(linToOklab(a), linToOklab(b));
  return deltaEOK(
    linToOklab(simulateCvd(a, type)),
    linToOklab(simulateCvd(b, type)),
  );
}

/// Minimum ΔEOK over normal vision, protanopia, deuteranopia and
/// tritanopia.
double minCvdDeltaE(int argbA, int argbB) {
  var m = cvdDeltaE(argbA, argbB);
  for (final t in Cvd.values) {
    final d = cvdDeltaE(argbA, argbB, t);
    if (d < m) m = d;
  }
  return m;
}

/// The OKLab colours of [argb] under normal vision, protanopia,
/// deuteranopia and tritanopia, in that order: precompute them once per
/// colour when comparing many pairs ([minCvdDeltaELabs]).
List<Lab> cvdLabs(int argb) {
  final c = argbToLin(argb);
  return [
    linToOklab(c),
    for (final t in Cvd.values) linToOklab(simulateCvd(c, t)),
  ];
}

/// [minCvdDeltaE] from two [cvdLabs] lists (bit-identical results).
double minCvdDeltaELabs(List<Lab> a, List<Lab> b) {
  var m = deltaEOK(a[0], b[0]);
  for (var i = 1; i < a.length; i++) {
    final d = deltaEOK(a[i], b[i]);
    if (d < m) m = d;
  }
  return m;
}
