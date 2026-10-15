/// The Android "Match my wallpaper" M3 Expressive variant (design doc "M3
/// families"; spec §5.3 #1): the wallpaper hue replaces the palette's base
/// hue draw and every guardrail still holds, for every hue tenth, in both
/// brightnesses and under the Accessible lock.
library;

import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator _gen = ThemeGenerator();

/// The first seed whose M3E theme has [brightness].
int _seedFor(ThemeBrightness brightness) {
  for (var seed = 0; ; seed++) {
    if (_gen
            .generate(seed, ThemeFamily.m3Expressive, currentEngineVersion)
            .brightness ==
        brightness) {
      return seed;
    }
  }
}

void main() {
  test('the wallpaper hue replaces only the base hue draw', () {
    final plain = _gen.generate(77, ThemeFamily.m3Expressive, 2);
    final wall = _gen.generate(
      77,
      ThemeFamily.m3Expressive,
      2,
      seedHueTenths: 2400,
    );
    expect(wall.variant, ThemeVariant.wallpaper);
    expect(wall.seedHueTenths, 2400);
    expect(plain.seedHueTenths, isNull);
    // Same seed, same non-palette streams.
    expect(wall.brightness, plain.brightness);
    expect(wall.keyShape, plain.keyShape);
    expect(wall.type, plain.type);
    expect(wall.motion, plain.motion);
    expect(wall.palette, isNot(plain.palette));
    // Deterministic, and the recorded hue round-trips through JSON.
    expect(
      _gen.generate(77, ThemeFamily.m3Expressive, 2, seedHueTenths: 2400),
      wall,
    );
    expect(ThemeSpec.fromJsonString(wall.toJsonString()), wall);
    // Other themes' JSON carries no new key (hashes unchanged).
    expect(plain.toJson().containsKey('seedHueTenths'), isFalse);
    // Hues wrap.
    expect(
      _gen
          .generate(77, ThemeFamily.m3Expressive, 2, seedHueTenths: 6000)
          .seedHueTenths,
      2400,
    );
  });

  test('only Material 3 Expressive has the variant', () {
    expect(
      () => _gen.generate(1, ThemeFamily.neoPop, 2, seedHueTenths: 100),
      throwsArgumentError,
    );
  });

  for (final brightness in ThemeBrightness.values) {
    for (final accessible in [false, true]) {
      test('every hue tenth passes the guardrails '
          '(${brightness.name}${accessible ? ', accessible' : ''})', () {
        final seed = _seedFor(brightness);
        var heroes = 0;
        for (var hue = 0; hue < 3600; hue++) {
          final spec = _gen.generate(
            seed,
            ThemeFamily.m3Expressive,
            currentEngineVersion,
            accessible: accessible,
            seedHueTenths: hue,
          );
          final violations = validateTheme(spec);
          if (violations.isNotEmpty) fail('hue $hue: $violations');
          expect(spec.accessible, accessible);
          if (spec.variant == ThemeVariant.hero) {
            heroes++;
            continue;
          }
          expect(spec.variant, ThemeVariant.wallpaper);
          expect(spec.brightness, brightness);
        }
        // The hero fallback stays rare.
        expect(heroes, lessThan(36), reason: '$heroes hero fallbacks');
      });
    }
  }
}
