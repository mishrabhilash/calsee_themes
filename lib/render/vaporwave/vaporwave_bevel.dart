/// Vaporwave's hard two-tone Win95 bevel: four tones derived in OKLCH from
/// a face colour at paint time (so per-frame label repair and lerped
/// fills always get matching bevels), memoised in a small static LRU.
library;

import 'dart:collection';
import 'dart:ui' show Color;

import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/vaporwave.dart'
    show vaporwaveBevelHighlight;
import 'package:flutter/foundation.dart';

/// The four bevel tones of one face: two highlights (outer = lighter) for
/// the raised top-left, two shades (outer = darker) for the bottom-right.
@immutable
final class VaporBevelTones {
  const new({
    required this.hiOuter,
    required this.hiInner,
    required this.shadeInner,
    required this.shadeOuter,
  });

  /// Outer highlight band (top-left when raised).
  final Color hiOuter;

  /// Inner highlight band.
  final Color hiInner;

  /// Inner shade band (bottom-right when raised).
  final Color shadeInner;

  /// Outer shade band.
  final Color shadeOuter;
}

final LinkedHashMap<(int, int, int), VaporBevelTones> _memo = LinkedHashMap();

/// Entries kept by [vaporBevelTones].
const int vaporBevelMemoCapacity = 64;

/// The bevel tones of [fill] with the shade depth [shadeDepth] (OKLab
/// lightness, 0.26–0.34) and highlight mix [highlightMix] (toward white,
/// 0.80–0.95). With fill = (L, C, h) and m = highlightMix (× 0.6 on dark
/// faces):
///
/// | tone | L | C |
/// |---|---|---|
/// | hiOuter | L + (1 − L)·m | 0.6·C (`vaporwaveBevelHighlight`, the colour the boundary guardrail counts) |
/// | hiInner | L + (1 − L)·m/2 | 0.8·C |
/// | shadeInner | max(0.02, L − shade/2) | C |
/// | shadeOuter | max(0.01, L − shade) | min(1.1·C, 0.30) |
VaporBevelTones vaporBevelTones(
  Color fill,
  double shadeDepth,
  double highlightMix,
) {
  final key = (
    fill.toARGB32() | 0xFF000000,
    (shadeDepth * 1000).round(),
    (highlightMix * 1000).round(),
  );
  final hit = _memo.remove(key);
  if (hit != null) return _memo[key] = hit;
  final f = argbToOklch(key.$1);
  final shade = key.$2 / 1000;
  final m = key.$3 / 1000 * (f.l < 0.5 ? 0.6 : 1.0);
  Color tone(double l, double c) =>
      Color(oklchToArgb(l.clamp(0.0, 1.0), c, f.h) | 0xFF000000);
  final shadeOuterC = f.c * 1.1;
  final tones = VaporBevelTones(
    hiOuter: Color(vaporwaveBevelHighlight(key.$1, key.$3)),
    hiInner: tone(f.l + (1 - f.l) * m * 0.5, f.c * 0.8),
    shadeInner: tone(f.l - shade * 0.5 < 0.02 ? 0.02 : f.l - shade * 0.5, f.c),
    shadeOuter: tone(
      f.l - shade < 0.01 ? 0.01 : f.l - shade,
      shadeOuterC > 0.30 ? 0.30 : shadeOuterC,
    ),
  );
  _memo[key] = tones;
  while (_memo.length > vaporBevelMemoCapacity) {
    _memo.remove(_memo.keys.first);
  }
  return tones;
}
