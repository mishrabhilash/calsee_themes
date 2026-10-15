/// Liquid Glass generator, guardrails on composited colours, heroes and
/// fixtures (spec §5.3 #2, §5.4; research theme-engine.md: contrast over
/// translucent surfaces).
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_GLASS_GOLDENS=1 dart test test/themes/engine/liquid_glass_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/liquid_glass.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

String fixturePath(int version) =>
    'test/engine/fixtures/liquid_glass_v$version.json';

/// Pinned Liquid Glass cases (v2): dark and light, circles and rounded
/// rects, both locks.
const List<({int seed, bool accessible})> glassCases = [
  (seed: 0, accessible: false),
  (seed: 3, accessible: false),
  (seed: 5, accessible: false),
  (seed: 7, accessible: false),
  (seed: 10, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

int alphaOf(int argb) => (argb >>> 24) & 0xFF;

/// The darkest and lightest background samples (by luminance).
(int, int) extremes(List<int> bgs) {
  var lo = bgs.first;
  var hi = bgs.first;
  for (final b in bgs) {
    if (luminanceArgb(b) < luminanceArgb(lo)) lo = b;
    if (luminanceArgb(b) > luminanceArgb(hi)) hi = b;
  }
  return (lo, hi);
}

void main() {
  group('10,000 seeds pass the Liquid Glass guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        final shapes = <KeyShapeKind>{};
        final drifts = <int>{};
        final minLabel = accessible ? ratioAccessible : ratioText;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            ThemeFamily.liquidGlass,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bgs = backgroundSamples(s.background);
          // A vivid mesh: base + three blobs, sampled as its colour hull.
          expect(s.background.kind, BackgroundKind.meshGradient);
          expect(s.background.colors, hasLength(4));
          expect(bgs.length, greaterThan(4));
          drifts.add(s.background.driftPeriodMs);
          // Glass: translucent digit / function tints.
          expect(alphaOf(p.digit.face), lessThan(255));
          expect(alphaOf(p.function.face), lessThan(255));
          // Labels on the glass composited over the darkest AND lightest
          // background samples (and every other hull sample).
          final (lo, hi) = extremes(bgs);
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            for (final b in [lo, hi, ...bgs]) {
              final face = compositeOver(k.face, b);
              final r = contrastRatio(k.label, face);
              if (r < minLabel) fail('seed $seed label $k over $b: $r');
            }
          }
          // The display on its solid-enough backing.
          for (final b in bgs) {
            final panel = compositeOver(p.surface, b);
            if (contrastRatio(p.displayText, panel) < minLabel) {
              fail('seed $seed display on ${argbToHex(panel)}');
            }
          }
          // Operators: weight cue and a distinct tint.
          expect(s.nonColourOperatorCue, OperatorCue.weight);
          expect(s.type.operatorWeight - s.type.keyWeight, greaterThan(199));
          // Motion: glass press never varied; inflate, glow, soft haptic.
          expect(s.motion.pressIn, SpringTokens.glassPressIn);
          expect(s.motion.verb, PressVerb.inflate);
          expect(s.motion.fx, PressFx.glow);
          expect(s.motion.releaseAlt, const SpringToken(439, 800));
          expect(s.sound, SoundPackId.glass);
          expect(s.keyStyle.kind, KeyStyleKind.glass);
          if (accessible) {
            for (final k in [p.digit, p.operator, p.equals, p.function]) {
              expect(alphaOf(k.edge), 255);
            }
          }
          if (s.isDark) dark++;
          shapes.add(s.keyShape.kind);
        }
        expect(dark, inInclusiveRange(5000, 7000), reason: 'dark ≈ 3 in 5');
        expect(shapes, {KeyShapeKind.circle, KeyShapeKind.roundedRect});
        expect(drifts.every((d) => d >= 40000 && d <= 60000), isTrue);
      });
    }
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(
            seed,
            ThemeFamily.liquidGlass,
            2,
            accessible: accessible,
          );
          final b = other.generate(
            seed,
            ThemeFamily.liquidGlass,
            2,
            accessible: accessible,
          );
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips (glass style fields included)', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, ThemeFamily.liquidGlass, 2);
        expect(
          spec.toJson()['keyStyle'],
          containsPair('highlightPermille', isA<int>()),
        );
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('other families keep their JSON (glass fields only when set)', () {
      final m3e = gen.generate(3, ThemeFamily.m3Expressive, 2);
      final style = m3e.toJson()['keyStyle']! as Map<String, Object?>;
      expect(style.containsKey('frostPermille'), isFalse);
      expect(style.containsKey('highlightPermille'), isFalse);
      expect(style.containsKey('refractionPermille'), isFalse);
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, ThemeFamily.liquidGlass, 2);
      final a1 = gen.buildCandidate(5, ThemeFamily.liquidGlass, 2, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
    });

    test('Liquid Glass did not exist at engine v1', () {
      expect(
        () => gen.generate(1, ThemeFamily.liquidGlass, 1),
        throwsArgumentError,
      );
      expect(familyShippedAt(ThemeFamily.liquidGlass, 2), isTrue);
      expect(ThemeFamily.liquidGlass.enabled, isTrue);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, ThemeFamily.liquidGlass, 2);
      final code = encodeShareCode(ThemeFamily.liquidGlass.id, 2, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, ThemeFamily.liquidGlass.id);
      expect(
        gen.generate(
          decoded.seed,
          ThemeFamily.liquidGlass,
          decoded.engineVersion,
        ),
        spec,
      );
    });

    for (final version in [2, 3]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            ThemeFamily.liquidGlass,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': ThemeFamily.liquidGlass.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_GLASS_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in glassCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(glassCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = glassCases[i];
          final spec = gen.generate(
            c.seed,
            ThemeFamily.liquidGlass,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(
            spec.toJsonString(),
            jsonEncode(cases[i]['spec']),
            reason: 'case $i (${c.seed})',
          );
          expect(
            spec.stableHash.toRadixString(16).padLeft(8, '0'),
            cases[i]['hash'],
          );
          expect(ThemeSpec.fromJson(cases[i]['spec']), spec);
        }
      });
    }
  });

  test('generation p99 < 2 ms', () {
    for (var s = 0; s < 300; s++) {
      gen.generate(s, ThemeFamily.liquidGlass, 2, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, ThemeFamily.liquidGlass, 2, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('mesh hull samples', () {
    test('stops, pairwise ¼ / ½ / ¾ points and three-way centroids', () {
      const stops = [0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFF000000];
      final s = meshHullSamples(stops);
      expect(s.sublist(0, 4), stops);
      expect(s, hasLength(4 + 6 * 3 + 4));
      // The red–green midpoint is darker than red itself: the reason the
      // stops alone are not the worst case.
      expect(s, contains(0xFF808000));
      expect(luminanceArgb(0xFF808000), lessThan(luminanceArgb(0xFFFF0000)));
    });

    test('a mesh background is sampled as its hull; others are not', () {
      final spec = gen.generate(4, ThemeFamily.liquidGlass, 2);
      expect(
        backgroundSamples(spec.background),
        meshHullSamples([
          for (final c in spec.background.colors) c | 0xFF000000,
        ]),
      );
      final solid = BackgroundSpec(
        kind: BackgroundKind.solid,
        colors: List.unmodifiable([0xFF102030]),
      );
      expect(backgroundSamples(solid), [0xFF102030]);
    });

    test('the diffuse colour is one of the hull samples', () {
      for (var seed = 0; seed < 50; seed++) {
        final bg = gen.generate(seed, ThemeFamily.liquidGlass, 2).background;
        expect(backgroundSamples(bg), contains(glassDiffuseColor(bg)));
      }
    });
  });

  group('guardrails on composited colours', () {
    final base = gen.generate(10, ThemeFamily.liquidGlass, 2);

    test('the display is checked on the backing over every sample only', () {
      final bgs = backgroundSamples(base.background);
      expect(displayBackdrops(base), faceSamples(base.palette.surface, bgs));
    });

    test('a too-clear display backing fails and repairs', () {
      final clear = base.copyWith(
        palette: base.palette.copyWith(
          surface: withAlpha(base.palette.surface, 20),
        ),
      );
      final rules = validateTheme(clear).map((v) => v.rule).toSet();
      expect(
        rules.intersection({
          GuardrailRule.displayText,
          GuardrailRule.previewText,
          GuardrailRule.errorText,
        }),
        isNotEmpty,
      );
      final fixed = repairTheme(clear)!;
      expect(validateTheme(fixed), isEmpty);
    });

    test('a label lost over the lightest sample fails and repairs', () {
      final bgs = backgroundSamples(base.background);
      final (_, hi) = extremes(bgs);
      final p = base.palette;
      // A grey label that passes on the bare tint over the darkest sample
      // only.
      final weak = base.copyWith(
        palette: p.copyWith(digit: p.digit.copyWith(label: 0xFF9A9A9A)),
      );
      final rules = validateTheme(weak).map((v) => v.rule);
      expect(rules, contains(GuardrailRule.digitLabel));
      final fixed = repairTheme(weak)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        contrastRatio(
          fixed.palette.digit.label,
          compositeOver(fixed.palette.digit.face, hi),
        ),
        greaterThanOrEqualTo(ratioText),
      );
    });

    test('a blinding press glow fails and is dimmed by repair', () {
      final hot = base.copyWith(
        palette: base.palette.copyWith(highlight: 0xF0FFFFFF),
      );
      expect(
        validateTheme(hot).map((v) => v.rule),
        contains(GuardrailRule.glassPressedLabel),
      );
      final fixed = repairTheme(hot)!;
      expect(validateTheme(fixed), isEmpty);
      expect(alphaOf(fixed.palette.highlight), lessThan(0xF0));
    });

    test('an operator tint equal to the digit tint fails', () {
      final p = base.palette;
      final same = base.copyWith(
        palette: p.copyWith(operator: p.operator.copyWith(face: p.digit.face)),
      );
      expect(
        validateTheme(same).map((v) => v.rule),
        contains(GuardrailRule.glassOperatorTint),
      );
    });

    test('a dishonest weight cue fails', () {
      final light = base.copyWith(
        type: base.type.copyWith(operatorWeight: base.type.keyWeight + 100),
      );
      expect(
        validateTheme(light).map((v) => v.rule),
        contains(GuardrailRule.glassOperatorCue),
      );
    });

    test('accessible rims must be opaque and ≥ 3:1', () {
      final acc = gen.generate(
        10,
        ThemeFamily.liquidGlass,
        2,
        accessible: true,
      );
      final p = acc.palette;
      final faint = acc.copyWith(
        palette: p.copyWith(digit: p.digit.copyWith(edge: 0x40FFFFFF)),
      );
      expect(
        validateTheme(faint).map((v) => v.rule),
        contains(GuardrailRule.glassRim),
      );
      expect(validateTheme(repairTheme(faint)!), isEmpty);
    });
  });

  test('heroes: three Liquid Glass heroes, dark and light, all valid', () {
    final heroes = heroesFor(ThemeFamily.liquidGlass);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([20, 21, 22]));
    expect(heroes.where((h) => h.isDark), isNotEmpty);
    expect(heroes.where((h) => !h.isDark), isNotEmpty);
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      expect(validateTheme(heroForAccessible(h)), isEmpty, reason: h.name);
      expect(h.background.kind, BackgroundKind.meshGradient);
      expect(h.keyStyle.kind, KeyStyleKind.glass);
    }
  });
}
