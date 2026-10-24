/// Neo-brutalism generator, guardrails, heroes and fixtures (spec §5.3 #6;
/// motion brief §2.3 "Neo-brutalism").
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_NEO_BRUTALISM_GOLDENS=1 dart test test/themes/engine/neo_brutalism_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/neo_brutalism.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily nb = ThemeFamily.neoBrutalism;

String fixturePath(int version) =>
    'test/engine/fixtures/neo_brutalism_v$version.json';

/// Pinned cases (v2): paper, poster and ink bodies, ink `=`, both locks.
const List<({int seed, bool accessible})> neoBrutalCases = [
  (seed: 0, accessible: false),
  (seed: 3, accessible: false),
  (seed: 9, accessible: false),
  (seed: 21, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

void main() {
  group('10,000 seeds pass the Neo-brutalism guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        var poster = 0;
        var inkEquals = 0;
        var patterned = 0;
        final depths = <int>{};
        final outlines = <int>{};
        final minLabel = accessible ? 7.0 : 4.5;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            nb,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bgs = backgroundSamples(s.background);
          // Labels on their faces.
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
            // One ink for every outline and the hard shadow, ≥ 3:1 on
            // every background sample.
            expect(k.edge, p.shadow, reason: 'seed $seed');
            for (final b in bgs) {
              if (contrastRatio(k.edge, b) < 3) fail('seed $seed outline');
            }
          }
          // Display text on the card and the body.
          for (final b in [p.surface, ...bgs]) {
            if (contrastRatio(p.displayText, b) < minLabel) {
              fail('seed $seed display');
            }
          }
          // Hard shadow: opaque, no blur, offset = press depth 3–5 dp.
          expect(p.shadow >>> 24, 0xFF);
          expect(s.keyStyle.kind, KeyStyleKind.outlined);
          expect(s.keyStyle.shadowBlurCdp, 0);
          expect(s.keyStyle.stateLayerPermille, 0, reason: 'no tint');
          expect(s.keyStyle.shadowOffsetCdp, s.motion.depthCdp);
          depths.add(s.motion.depthCdp);
          outlines.add(s.keyStyle.outlineWidthCdp);
          // Non-colour operator cue: a heavier label, recorded.
          expect(s.nonColourOperatorCue, OperatorCue.weight);
          if (s.type.operatorWeight < s.type.keyWeight + 200) {
            fail('seed $seed weights ${s.type.toJson()}');
          }
          // Saturated operator fills.
          final op = argbToOklch(p.operator.face);
          if (op.c < 0.06) fail('seed $seed operator not saturated $op');
          // Motion per brief.
          expect(s.keyShape.kind, KeyShapeKind.roundedRect);
          expect(s.keyShape.cornerPermille, inInclusiveRange(0, 200));
          expect(s.motion.pressIn, SpringTokens.hardPress);
          expect(s.motion.verb, PressVerb.stamp);
          expect(s.motion.entry, EntryStyle.stamp);
          expect(s.motion.entryScalePermille, 1120);
          expect(s.motion.entrySpring, SpringTokens.hardPress);
          expect(s.motion.impact, ImpactStyle.rigid);
          expect(s.motion.impactPermille, 1000);
          expect(s.sound, SoundPackId.mechLinear);
          if (s.isDark) {
            dark++;
          } else if (argbToOklch(p.background).c > 0.04) {
            poster++;
          }
          if (luminanceArgb(p.equals.face) < 0.02 && !s.isDark) inkEquals++;
          if (s.background.kind == BackgroundKind.pattern) patterned++;
        }
        expect(depths, {300, 400, 500});
        expect(outlines, {200, 250, 300, 350, 400});
        expect(dark, inInclusiveRange(700, 1600), reason: 'dark ≈ 1 in 9');
        expect(poster, inInclusiveRange(2500, 4000), reason: 'poster bodies');
        expect(inkEquals, inInclusiveRange(1500, 2800), reason: 'ink `=`');
        expect(patterned, inInclusiveRange(3000, 4500));
      });
    }
  });

  test('release stays inside the brief (2500/1.0 × {0.9, 1, 1.1})', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, nb, 2).motion;
      seen.add(m.release.stiffness);
      expect(m.release.zetaPermille, 1000);
      expect(m.releaseHaptic, isFalse);
    }
    expect(seen, {2250, 2500, 2750});
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, nb, 2, accessible: accessible);
          final b = other.generate(seed, nb, 2, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, nb, 2);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, nb, 2);
      final a1 = gen.buildCandidate(5, nb, 2, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
    });

    test('accessible and normal differ only where contrast demands', () {
      final n = gen.generate(42, nb, 2);
      final a = gen.generate(42, nb, 2, accessible: true);
      expect(a.keyShape, n.keyShape);
      expect(a.keyStyle, n.keyStyle);
      expect(a.motion, n.motion);
      expect(a.type, n.type);
    });

    test('Neo-brutalism did not exist at engine v1', () {
      expect(() => gen.generate(1, nb, 1), throwsArgumentError);
      expect(familyShippedAt(nb, 2), isTrue);
      expect(nb.enabled, isTrue);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, nb, 2);
      final code = encodeShareCode(nb.id, 2, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, nb.id);
      expect(gen.generate(decoded.seed, nb, decoded.engineVersion), spec);
    });

    for (final version in [2, 3, 4]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            nb,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': nb.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_NEO_BRUTALISM_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in neoBrutalCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(neoBrutalCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = neoBrutalCases[i];
          final spec = gen.generate(
            c.seed,
            nb,
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
      gen.generate(s, nb, 2, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, nb, 2, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('guardrails', () {
    final base = gen.generate(3, nb, 2);

    test('a faint outline fails and repairs to ≥ 3:1', () {
      final bg = base.palette.background;
      KeyColors faint(KeyColors k) => k.copyWith(edge: bg);
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          digit: faint(base.palette.digit),
          operator: faint(base.palette.operator),
        ),
      );
      final v = validateTheme(bad);
      expect(v.map((x) => x.rule), contains(GuardrailRule.brutalOutline));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      for (final b in backgroundSamples(fixed.background)) {
        expect(
          contrastRatio(fixed.palette.digit.edge, b),
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('outline width outside 2–4 dp fails', () {
      for (final w in [150, 450]) {
        final bad = base.copyWith(
          keyStyle: base.keyStyle.copyWith(outlineWidthCdp: w),
        );
        expect(
          validateTheme(bad).map((x) => x.rule),
          contains(GuardrailRule.brutalOutline),
        );
      }
    });

    test('a soft, translucent or detached shadow fails', () {
      final blurred = base.copyWith(
        keyStyle: base.keyStyle.copyWith(shadowBlurCdp: 200),
      );
      final translucent = base.copyWith(
        palette: base.palette.copyWith(
          shadow: base.palette.shadow & 0x80FFFFFF,
        ),
      );
      final detached = base.copyWith(
        keyStyle: base.keyStyle.copyWith(
          shadowOffsetCdp: base.motion.depthCdp == 300 ? 400 : 300,
        ),
      );
      for (final bad in [blurred, translucent, detached]) {
        expect(
          validateTheme(bad).map((x) => x.rule),
          contains(GuardrailRule.brutalShadow),
        );
      }
    });

    test('a dishonest weight cue fails', () {
      final bad = base.copyWith(
        type: base.type.copyWith(operatorWeight: base.type.keyWeight + 100),
      );
      expect(
        validateTheme(bad).map((x) => x.rule),
        contains(GuardrailRule.brutalOperatorCue),
      );
    });

    test('other families are not checked by the outlined rules', () {
      for (final f in [ThemeFamily.neoPop, ThemeFamily.m3Expressive]) {
        final s = gen.generate(3, f, 2);
        expect(
          validateTheme(s).map((x) => x.rule),
          isNot(contains(GuardrailRule.brutalOutline)),
        );
      }
    });
  });

  test('heroes: three Neo-brutalism heroes, paper / poster / dark', () {
    final heroes = heroesFor(nb);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([60, 61, 62]));
    expect(heroes.where((h) => h.isDark), isNotEmpty);
    expect(
      heroes.where(
        (h) => !h.isDark && argbToOklch(h.palette.background).c > 0.08,
      ),
      isNotEmpty,
    );
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      expect(validateTheme(heroForAccessible(h)), isEmpty, reason: h.name);
      expect(h.keyStyle.kind, KeyStyleKind.outlined);
      expect(h.keyStyle.shadowOffsetCdp, h.motion.depthCdp);
      expect(h.nonColourOperatorCue, OperatorCue.weight);
    }
  });

  test('cusp lightness lands where hues are most saturated', () {
    // Yellow peaks light, blue dark; the clamp keeps both inside 0.72–0.90.
    expect(neoBrutalCuspLMilli(105), greaterThan(neoBrutalCuspLMilli(265)));
    expect(neoBrutalCuspLMilli(265), lessThan(600));
  });
}
