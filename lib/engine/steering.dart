/// How a [ThemeIntent] narrows one generator attempt (engine v4). Internal:
/// the generator and the family builders call it; hosts use
/// `ThemeIntent`.
///
/// Steering never removes a draw from the palette stream, so the rest of
/// a theme keeps its seeded variety: brightness and the harmony scheme are
/// drawn and then overridden, chroma ranges are narrowed before they are
/// sampled, and steered hues come from their own `palette…/intent`
/// sub-stream. A centred attempt (the first theme of a steered feed)
/// puts each narrowed choice at the middle of its range.
library;

import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/theme_intent.dart';
import 'package:calsee_themes/engine/theme_spec.dart';

/// One attempt's steering.
final class Steering {
  Steering(this.intent, {this.centred = false});

  final ThemeIntent intent;
  final bool centred;

  /// The brightness to use instead of the drawn one, when [def] can draw
  /// it; null keeps the draw.
  ThemeBrightness? brightnessFor(FamilyDefinition def) {
    final want = intent.effectiveBrightness;
    return want != null && brightnessAllowed(def, want) ? want : null;
  }

  /// The harmony scheme to use instead of the drawn one, when [schemes]
  /// offers it; null keeps the draw.
  HarmonyScheme? schemeFor(List<Weighted<HarmonyScheme>> schemes) {
    final want = intent.harmony;
    if (want == null) return null;
    return schemes.any((w) => w.value == want && w.weight > 0) ? want : null;
  }

  /// [def] with every role's chroma range narrowed to the intent's chroma
  /// level (and the base roles quietened for a neutral first colour).
  FamilyDefinition revise(FamilyDefinition def) {
    final level = intent.effectiveChroma;
    final neutral = intent.colors.isNotEmpty && intent.colors.first.neutral;
    if (level == null && !neutral && !centred) return def;
    ChromaRange accent(ChromaRange r) => _narrow(r, level);
    ChromaRange base(ChromaRange r) =>
        neutral ? _neutral(r) : _narrow(r, level);
    RoleRange role(RoleRange r, ChromaRange Function(ChromaRange) f) =>
        RoleRange(r.lMilli, f(r.chroma));
    RoleRanges ranges(RoleRanges r) => RoleRanges(
      background: role(r.background, base),
      surfaceOffsetMilli: r.surfaceOffsetMilli,
      surfaceChroma: base(r.surfaceChroma),
      digit: role(r.digit, base),
      digitDuotoneChroma: base(r.digitDuotoneChroma),
      function: role(r.function, base),
      operator: role(r.operator, accent),
      operatorMonochromeL: r.operatorMonochromeL,
      equals: role(r.equals, accent),
      labelStartLMilli: r.labelStartLMilli,
      labelMaxChromaMilli: r.labelMaxChromaMilli,
      accentChroma: accent(r.accentChroma),
      minDigitAboveBackgroundMilli: r.minDigitAboveBackgroundMilli,
      minDigitBelowBackgroundMilli: r.minDigitBelowBackgroundMilli,
      minFunctionBelowDigitMilli: r.minFunctionBelowDigitMilli,
      accentCuspOffsetMilli: r.accentCuspOffsetMilli,
      accentCuspClampMilli: r.accentCuspClampMilli,
    );
    return def.revise(dark: ranges(def.dark), light: ranges(def.light));
  }

  /// The steered base hue (tenths), drawn from [r]; null when the intent
  /// sets no base hue. Always draws once when steering hues, so the accent
  /// draws keep their place.
  int? baseHue(Rng r) {
    final range = _baseRange();
    final v = r.nextU32();
    return range == null ? null : _pick(range, v);
  }

  /// The steered operator (`index` 0) or `=` (`index` 1) hue (tenths),
  /// drawn from [r]; null when the intent names no accent colour, or names
  /// a harmony (which then places the accents).
  int? accentHue(Rng r, int index) {
    final v = r.nextU32();
    if (intent.harmony != null || intent.colors.length < 2) return null;
    final c = index == 0 || intent.colors.length < 3
        ? intent.colors[1]
        : intent.colors[2];
    if (c.neutral) return null;
    return _pick(_HueRange(c.loTenths, c.hiTenths), v);
  }

  /// The steered base hue range as (lo tenths, clockwise span tenths), or
  /// null when the intent sets no base hue.
  ({int lo, int span})? get baseRange {
    final r = _baseRange();
    return r == null ? null : (lo: r.lo, span: r.span);
  }

  /// A hue in the clockwise range (lo, span) from the 32-bit draw [u32]
  /// (its middle when [centred]).
  int pickIn(int lo, int span, int u32) => _pick(_HueRange.span(lo, span), u32);

  /// The theme's name: the intent's, else [generated].
  String nameOr(String Function() generated) => intent.name ?? generated();

  _HueRange? _baseRange() {
    final hr = intent.hueRange;
    if (hr != null) return _HueRange(hr.$1 * 10, hr.$2 * 10);
    if (intent.colors.isEmpty) return null;
    final c = intent.colors.first;
    return c.neutral ? null : _HueRange(c.loTenths, c.hiTenths);
  }

  int _pick(_HueRange range, int u32) {
    final span = range.span;
    final offset = centred ? span ~/ 2 : u32 % (span + 1);
    return (range.lo + offset) % 3600;
  }

  ChromaRange _narrow(ChromaRange r, IntentChroma? level) {
    var lo = r.lo;
    var hi = r.hi;
    final third = (hi - lo) ~/ 3;
    switch (level) {
      case null:
        break;
      case IntentChroma.muted:
        lo = lo * 45 ~/ 100;
        hi = hi * 55 ~/ 100;
      case IntentChroma.balanced:
        lo += third;
        hi -= third;
      case IntentChroma.vivid:
        lo = hi - third;
    }
    if (hi < lo) hi = lo;
    if (centred) lo = hi = (lo + hi) ~/ 2;
    return _withBounds(r, lo, hi);
  }

  ChromaRange _neutral(ChromaRange r) {
    final hi = r.hi * 20 ~/ 100;
    final lo = r.lo * 15 ~/ 100 > hi ? hi : r.lo * 15 ~/ 100;
    return centred
        ? _withBounds(r, (lo + hi) ~/ 2, (lo + hi) ~/ 2)
        : _withBounds(r, lo, hi);
  }

  static ChromaRange _withBounds(ChromaRange r, int lo, int hi) => r.relative
      ? ChromaRange.rel(lo, hi, r.capMilli)
      : ChromaRange.abs(lo, hi);

  /// The deterministic last resort for a steered ([seed], [family]) when
  /// every attempt fails: the hero closest to the intent (brightness
  /// first, then base hue), preferring the family's own heroes.
  ThemeSpec closestHero(int seed, ThemeFamily family) {
    var pool = heroesFor(family);
    if (pool.isEmpty) pool = heroThemes;
    final want = intent.effectiveBrightness;
    final range = _baseRange();
    final target = range == null ? null : (range.lo + range.span ~/ 2) % 3600;
    int score(ThemeSpec h) {
      var s = 0;
      if (want != null && h.brightness != want) s += 10000;
      if (target != null) {
        final hue = (argbToOklch(h.palette.seedColor).h * 10).round() % 3600;
        final d = (hue - target).abs();
        s += d > 1800 ? 3600 - d : d;
      }
      return s;
    }

    final start = (seed & 0xFFFFFFFF) % pool.length;
    var best = pool[start];
    var bestScore = score(best);
    for (var i = 1; i < pool.length; i++) {
      final h = pool[(start + i) % pool.length];
      final s = score(h);
      if (s < bestScore) {
        best = h;
        bestScore = s;
      }
    }
    return best;
  }
}

/// A clockwise hue range in tenths of a degree, possibly wrapping past 0.
final class _HueRange {
  const _HueRange(this.lo, int hi) : span = (hi - lo) % 3600;

  const _HueRange.span(this.lo, this.span);

  final int lo;

  /// Tenths from [lo] to the inclusive end, clockwise.
  final int span;
}

/// The palette sub-stream steered hues come from for [paletteTag].
String intentTag(String paletteTag) => RngTag.sub(paletteTag, 'intent');
