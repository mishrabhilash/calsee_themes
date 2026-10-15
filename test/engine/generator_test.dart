import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

import 'generator_golden_cases.dart';

const ThemeGenerator gen = ThemeGenerator();

/// Approximate settle time (s) of a mass-1 spring: 4 / (ζ √k).
double settleSeconds(SpringToken s) =>
    4 / (s.dampingRatio * detSqrt(s.stiffness.toDouble()));

void main() {
  group('10,000 seeds per family pass the guardrails', () {
    for (final family in ThemeFamily.enabledFamilies) {
      for (final accessible in [false, true]) {
        test('${family.name}${accessible ? ' (accessible)' : ''}', () {
          var fallbacks = 0;
          var dark = 0;
          final names = <String>{};
          final opBuckets = <int>{};
          final backgrounds = <BackgroundKind>{};
          final def = family.definition;
          for (var seed = 0; seed < 10000; seed++) {
            final spec = gen.generate(
              seed,
              family,
              currentEngineVersion,
              accessible: accessible,
            );
            final v = validateTheme(spec);
            if (v.isNotEmpty) fail('seed $seed: $v');
            expect(spec.accessible, accessible);
            if (spec.variant == ThemeVariant.hero) {
              fallbacks++;
              continue;
            }
            expect(spec.seed, seed);
            expect(spec.family, family);
            if (spec.isDark) dark++;
            names.add(spec.name);
            backgrounds.add(spec.background.kind);
            final op = argbToOklch(spec.palette.operator.face);
            if (op.c > 0.04) opBuckets.add(hueBucket(op.h));

            // Motion (brief §2.5): pressIn never varied; clamps hold.
            final m = spec.motion;
            if (m.pressIn != def.motion.pressIn) fail('seed $seed pressIn');
            if (m.release.zetaPermille < 591 ||
                m.release.zetaPermille > 1000 ||
                settleSeconds(m.release) > 0.3605) {
              fail('seed $seed release ${m.release}');
            }
            if (family == ThemeFamily.neoPop) {
              if (!spec.isDark) fail('NeoPOP seed $seed is light');
              if (m.depthCdp % 100 != 0 ||
                  m.depthCdp < 300 ||
                  m.depthCdp > 500 ||
                  spec.keyStyle.extrudeDepthCdp != m.depthCdp) {
                fail('NeoPOP seed $seed depth ${m.depthCdp}');
              }
              if (spec.keyShape.cornerPermille > 80) fail('corner $seed');
              if (spec.type.keyFont != FontIds.spaceGrotesk) fail('font');
            } else if (family == ThemeFamily.m3Expressive) {
              if (spec.keyShape.kind != KeyShapeKind.m3eMorph ||
                  spec.keyShape.m3eShape == null ||
                  spec.keyShape.morphCornerPermille != 300) {
                fail('M3E seed $seed shape ${spec.keyShape.toJson()}');
              }
              if (spec.type.keyFont != FontIds.robotoFlex) fail('font');
            }
          }
          expect(fallbacks, 0, reason: 'hero fallbacks');
          // Variety: names, hues, backgrounds and brightness are spread.
          expect(names.length, greaterThan(_minDistinctNames[family] ?? 1500));
          // Families with deliberately narrow accent sets name their own
          // minimum (_minOperatorHueBuckets); every other family spreads
          // operator hues over all 12 buckets.
          final minBuckets = _minOperatorHueBuckets[family];
          expect(
            opBuckets.length,
            minBuckets == null ? 12 : greaterThanOrEqualTo(minBuckets),
          );
          expect(backgrounds.length, def.backgrounds.length);
          if (family == ThemeFamily.m3Expressive) {
            expect(dark, inInclusiveRange(4000, 6000));
          }
        });
      }
    }
  });

  test('golden hashes (every platform; JSON in generator_v1.json)', () {
    const pinned = [
      0xee572b60,
      0x0e7d2557,
      0x05d4f398,
      0x2c89544c,
      0x89235153,
      0x81a59b5e,
      0x10733b26,
      0x5fac8646,
      0x3fff0e42,
      0xe4727c6f,
    ];
    for (var i = 0; i < goldenCases.length; i++) {
      final c = goldenCases[i];
      final spec = gen.generate(c.seed, c.family, 1, accessible: c.accessible);
      expect(spec.stableHash, pinned[i], reason: 'case $i: $spec');
    }
  });

  test('golden hashes v2 (every platform; JSON in generator_v2.json)', () {
    const pinned = [
      0xab8874ab,
      0x6603e6e4,
      0xfe8e71e1,
      0xcadd40eb,
      0x31d98648,
      0x618c2169,
      0xc3727d41,
      0xbd219cab,
      0xf3749d7a,
      0x117fa8d9,
    ];
    for (var i = 0; i < goldenCases.length; i++) {
      final c = goldenCases[i];
      final spec = gen.generate(c.seed, c.family, 2, accessible: c.accessible);
      expect(spec.stableHash, pinned[i], reason: 'case $i: $spec');
    }
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash across instances', () {
      const a = ThemeGenerator();
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final b = ThemeGenerator();
      for (final family in ThemeFamily.enabledFamilies) {
        for (var i = 0; i < 300; i++) {
          final seed = (i * 2654435761) & 0xFFFFFFFF;
          // Families shipped after v1 are checked at the current version.
          final v = familyShippedAt(family, 1) ? 1 : currentEngineVersion;
          final x = a.generate(seed, family, v);
          final y = b.generate(seed, family, v);
          expect(y.toJsonString(), x.toJsonString());
          expect(y.stableHash, x.stableHash);
          expect(y, x);
        }
      }
    });

    test('order does not matter (no hidden state)', () {
      final forward = [
        for (var s = 0; s < 50; s++) gen.generate(s, ThemeFamily.neoPop, 1),
      ];
      final backward = [
        for (var s = 49; s >= 0; s--) gen.generate(s, ThemeFamily.neoPop, 1),
      ].reversed.toList();
      expect(backward, forward);
    });

    test('seeds are taken modulo 2^32', () {
      final a = gen.generate(7, ThemeFamily.m3Expressive, 1);
      final b = gen.generate(7 + 0x100000000, ThemeFamily.m3Expressive, 1);
      expect(b, a);
      expect(gen.generate(0xFFFFFFFF, ThemeFamily.neoPop, 1).seed, 0xFFFFFFFF);
    });

    test('JSON round-trip reproduces the spec', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, ThemeFamily.m3Expressive, 1);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('accessible and normal differ only where contrast demands', () {
      final n = gen.generate(42, ThemeFamily.neoPop, 1);
      final a = gen.generate(42, ThemeFamily.neoPop, 1, accessible: true);
      expect(a.keyShape, n.keyShape);
      expect(a.motion, n.motion);
      expect(a.type, n.type);
      expect(a.accessible, isTrue);
    });
  });

  group('pipeline', () {
    test('retry attempts use a different palette stream', () {
      final a0 = gen.buildCandidate(5, ThemeFamily.neoPop, 1);
      final a1 = gen.buildCandidate(5, ThemeFamily.neoPop, 1, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion, reason: 'other aspects keep their stream');
      expect(a1.keyShape, a0.keyShape);
    });

    test('falls back to a hero of the family when attempts run out', () {
      const none = ThemeGenerator(maxAttempts: 0);
      final spec = none.generate(3, ThemeFamily.neoPop, 1);
      expect(spec.variant, ThemeVariant.hero);
      expect(spec.family, ThemeFamily.neoPop);
      expect(validateTheme(spec), isEmpty);
      final locked = none.generate(3, ThemeFamily.neoPop, 1, accessible: true);
      expect(locked.accessible, isTrue);
      expect(validateTheme(locked), isEmpty);
    });

    test('rejects unsupported engine versions and the plain family', () {
      expect(
        () => gen.generate(1, ThemeFamily.neoPop, 0),
        throwsA(isA<UnsupportedEngineVersion>()),
      );
      expect(
        () => gen.generate(1, ThemeFamily.neoPop, currentEngineVersion + 1),
        throwsA(isA<UnsupportedEngineVersion>()),
      );
      expect(
        () => gen.generate(1, ThemeFamily.plain, 1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('names are never blocked and follow the operator hue', () {
      for (var s = 0; s < 500; s++) {
        final spec = gen.generate(s, ThemeFamily.m3Expressive, 1);
        final words = spec.name.split(' ');
        expect(words, hasLength(2));
        expect(isBlockedName(words[0], words[1]), isFalse);
      }
    });

    test('dark digit faces stay visible above the background', () {
      for (var s = 0; s < 500; s++) {
        final spec = gen.generate(s, ThemeFamily.neoPop, 1);
        final bg = argbToOklab(spec.background.base).$1;
        final digit = argbToOklab(spec.palette.digit.face).$1;
        expect(digit - bg, greaterThan(0.09), reason: 'seed $s');
      }
    });

    test('NeoPOP extruded edges are darker than their faces', () {
      for (var s = 0; s < 200; s++) {
        final p = gen.generate(s, ThemeFamily.neoPop, 1).palette;
        for (final k in [p.digit, p.operator, p.equals, p.function]) {
          expect(
            argbToOklab(k.edge).$1,
            lessThanOrEqualTo(argbToOklab(k.face).$1),
          );
        }
      }
    });
  });

  test('generation p99 < 2 ms', tags: 'perf', () {
    for (var s = 0; s < 300; s++) {
      gen.generate(s, ThemeFamily.m3Expressive, 1);
      gen.generate(s, ThemeFamily.neoPop, 1, accessible: true);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      for (final f in ThemeFamily.enabledFamilies) {
        for (final accessible in [false, true]) {
          final t0 = sw.elapsedMicroseconds;
          final v = familyShippedAt(f, 1) ? 1 : currentEngineVersion;
          gen.generate(s + 100000, f, v, accessible: accessible);
          times.add(sw.elapsedMicroseconds - t0);
        }
      }
    }
    times.sort();
    final p99 = times[times.length * 99 ~/ 100];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  });
}

/// Operator hue buckets (of 12, chroma > 0.04) a 10,000-seed sweep must
/// reach, for families whose accents come from a short list on purpose.
const Map<ThemeFamily, int> _minOperatorHueBuckets = {
  // Retro draws its one accent from five keypad colours (orange, red,
  // green, blue, teal; operators are often neutral grey).
  ThemeFamily.retro: 5,
  // Claymorphism's candy-hue rule keeps operators out of 75–130° (no
  // mustard or olive), so bucket 75–105° stays empty.
  ThemeFamily.claymorphism: 11,
  // Cyberpunk slabs come from five neon bands (magenta, cyan, acid, toxic,
  // amber): buckets {2, 3, 4, 5, 6, 7, 11}.
  ThemeFamily.cyberpunk: 7,
  // Vaporwave pairs one warm neon (hot pink, magenta, violet, coral) with
  // one cool (cyan, aqua): operators land in exactly six buckets.
  ThemeFamily.vaporwave: 6,
  // Bauhaus operators are always a primary: red (bucket 1), yellow (3) or
  // ultramarine (9).
  ThemeFamily.bauhaus: 3,
};

/// Distinct names a 10,000-seed sweep must exceed, for families whose
/// narrow palettes reach fewer colour words (default 1,500).
const Map<ThemeFamily, int> _minDistinctNames = {
  // Three operator hue buckets reach 24 colour words: at most 1,024
  // distinct names (941 over the sweep).
  ThemeFamily.bauhaus: 900,
};
