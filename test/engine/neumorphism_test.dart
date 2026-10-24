/// Neumorphism (Soft UI) generator, guardrails and fixtures
/// (docs/m4-design.md §C; research theme-engine.md recommendation 7, §7).
///
/// Regenerate the golden JSON (only together with a deliberate change to
/// the family's v2 output, which needs an engineVersion bump instead):
///
///     UPDATE_NEUMORPHISM_GOLDENS=1 dart test test/themes/engine/neumorphism_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/neumorphism.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();
const ThemeFamily soft = ThemeFamily.neumorphism;

typedef SoftCase = ({int seed, bool accessible});

const List<SoftCase> softGoldenCases = [
  (seed: 0, accessible: false),
  (seed: 1, accessible: false),
  (seed: 7, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: false),
  (seed: 424242, accessible: true),
  (seed: 0x80000000, accessible: false),
];

String fixturePath(int version) =>
    'test/engine/fixtures/neumorphism_v$version.json';

double hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return d > 180 ? 360 - d : d;
}

void main() {
  group('definition', () {
    test('enabled, shipped at v2 only, recipe tokens from the brief', () {
      expect(soft.enabled, isTrue);
      expect(familyShippedAt(soft, 1), isFalse);
      expect(familyShippedAt(soft, 2), isTrue);
      final def = soft.definition;
      expect(identical(def, neumorphismDefinition), isTrue);
      expect(def.keyStyle.kind, KeyStyleKind.soft);
      expect(def.sound, SoundPackId.tick);
      expect(def.nonColourOperatorCue, OperatorCue.weight);
      expect(def.operatorWeightBonus.lo, greaterThanOrEqualTo(200));
      final m = def.motion;
      expect(m.verb, PressVerb.sink);
      expect(m.pressIn, SpringTokens.effectsFast);
      expect(m.release, SpringTokens.effectsDefault);
      expect(m.release.zetaPermille, 1000, reason: 'Soft UI never bounces');
      expect(m.scalePermille, 980);
      expect(m.depthCdp, 600);
      expect(m.entry, EntryStyle.rise);
      expect(m.entryOffsetCdp, 400);
      expect(m.impact, ImpactStyle.soft);
      expect(m.impactPermille, 500);
      expect(m.releaseHaptic, isFalse);
      expect(def.motionRanges.bounceJitterPermille, 0);
      // Bases avoid the mid band where 7:1 labels do not exist.
      expect(def.light.background.lMilli.lo, greaterThanOrEqualTo(880));
      expect(def.dark.background.lMilli.hi, lessThanOrEqualTo(280));
      expect(def.light.background.chroma.hi, lessThanOrEqualTo(20));
      expect(def.dark.background.chroma.hi, lessThanOrEqualTo(20));
    });
  });

  group('10,000 seeds pass every guardrail, incl. the rim rule', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        final styles = <SoftOperatorStyle>{};
        final shapes = <KeyShapeKind>{};
        final rims = <int>{};
        final names = <String>{};
        final lim = accessible
            ? GuardrailLimits.accessible
            : GuardrailLimits.standard;
        for (var seed = 0; seed < 10000; seed++) {
          final spec = gen.generate(
            seed,
            soft,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(spec);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (spec.variant == ThemeVariant.hero) fail('seed $seed fell back');
          if (validateTheme(
            gen.buildCandidate(
              seed,
              soft,
              currentEngineVersion,
              accessible: accessible,
            ),
          ).isNotEmpty) {
            fail('seed $seed: the first candidate needed repair');
          }
          final p = spec.palette;
          if (spec.isDark) dark++;
          names.add(spec.name);
          shapes.add(spec.keyShape.kind);
          styles.add(softOperatorStyleOf(spec));
          rims.add(spec.keyStyle.outlineWidthCdp);

          // Monochrome, low-chroma surface; keys are the surface.
          final bg = argbToOklch(p.background);
          if (bg.c > 0.025) fail('seed $seed surface chroma ${bg.c}');
          if (spec.isDark ? bg.l > 0.285 : bg.l < 0.875) {
            fail('seed $seed surface L ${bg.l}');
          }
          if (p.digit.face != p.background || p.function.face != p.background) {
            fail('seed $seed: digit/function faces are not the surface');
          }
          if (spec.background.kind != BackgroundKind.solid) fail('bg $seed');

          // Shadows: same hue family, light above / dark below.
          final hi = luminanceArgb(p.highlight);
          final lo = luminanceArgb(p.shadow);
          final y = luminanceArgb(p.background);
          if (!(hi > y && lo < y)) fail('seed $seed shadows');
          if (((p.highlight >>> 24) & 0xFF) != 255 ||
              ((p.shadow >>> 24) & 0xFF) != 255) {
            fail('seed $seed shadows must be opaque');
          }

          // Rim: ≥ 3:1, but the least change (never a harsh outline), and
          // one colour for every key.
          final rim = contrastRatio(p.digit.edge, p.background);
          if (rim < 3 || rim > 3.6) fail('seed $seed rim $rim');
          for (final k in [p.operator, p.equals, p.function]) {
            if (k.edge != p.digit.edge) fail('seed $seed rim differs');
          }
          final w = spec.keyStyle.outlineWidthCdp;
          if (w < 100 || w > 150) fail('seed $seed rim width $w');
          if (accessible && w != 150) fail('seed $seed accessible rim $w');

          // Labels and the pressed label on surface faces.
          if (contrastRatio(p.accent, p.background) < lim.labelRatio) {
            fail('seed $seed pressed label');
          }
          // Operators: accent label on the surface, or a tinted face at
          // least 0.10 lightness away; always the heavier glyph.
          if (spec.type.operatorWeight - spec.type.keyWeight < 200) {
            fail('seed $seed weight cue');
          }
          if (spec.nonColourOperatorCue != OperatorCue.weight) fail('cue');
          if (softOperatorStyleOf(spec) == SoftOperatorStyle.accentLabel) {
            if (p.operator.label != p.accent) fail('seed $seed op label');
          } else {
            final op = argbToOklch(p.operator.face);
            if ((op.l - bg.l).abs() < 0.095) fail('seed $seed op ΔL');
            if (op.c < 0.04) fail('seed $seed op face not tinted');
          }
          // `=` is an accent face.
          if (argbToOklch(p.equals.face).c < 0.04) fail('seed $seed = face');

          // Display text ≥ 4.5:1 (7:1) on the surface and display well.
          for (final b in [p.background, p.surface]) {
            if (contrastRatio(p.displayText, b) < lim.displayRatio) {
              fail('seed $seed display');
            }
          }

          // Motion: brief tokens, seeded release only, never bounces.
          final m = spec.motion;
          if (m.pressIn != SpringTokens.effectsFast ||
              m.release.zetaPermille != 1000 ||
              m.scalePermille != 980 ||
              m.depthCdp != 600) {
            fail('seed $seed motion $m');
          }
          if (spec.sound != SoundPackId.tick) fail('sound');
        }
        // Variety.
        expect(dark, inInclusiveRange(3000, 5000));
        expect(styles, SoftOperatorStyle.values.toSet());
        expect(shapes, {KeyShapeKind.roundedRect, KeyShapeKind.circle});
        if (!accessible) expect(rims, {100, 125, 150});
        expect(names.length, greaterThan(1000));
      });
    }
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash; round-trips', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, soft, 2, accessible: accessible);
          final b = other.generate(seed, soft, 2, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
          expect(ThemeSpec.fromJsonString(a.toJsonString()), a);
        }
      }
    });

    test('order does not matter (no hidden state)', () {
      final forward = [for (var s = 0; s < 50; s++) gen.generate(s, soft, 2)];
      final backward = [
        for (var s = 49; s >= 0; s--) gen.generate(s, soft, 2),
      ].reversed.toList();
      expect(backward, forward);
    });

    test('refused at engine v1 (the family shipped at v2)', () {
      expect(() => gen.generate(1, soft, 1), throwsArgumentError);
    });

    for (final version in [2, 3, 4]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(SoftCase c) {
          final spec = gen.generate(
            c.seed,
            soft,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_NEUMORPHISM_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'family': soft.id,
                'cases': [for (final c in softGoldenCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(softGoldenCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = softGoldenCases[i];
          final spec = gen.generate(
            c.seed,
            soft,
            version,
            accessible: c.accessible,
          );
          expect(
            spec.toJsonString(),
            jsonEncode(cases[i]['spec']),
            reason: 'case $i',
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

  test('generation p99 < 2 ms', tags: 'perf', () {
    for (var s = 0; s < 300; s++) {
      gen.generate(s, soft, 2);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 3000; s++) {
      for (final accessible in [false, true]) {
        final t0 = sw.elapsedMicroseconds;
        gen.generate(s + 500000, soft, 2, accessible: accessible);
        times.add(sw.elapsedMicroseconds - t0);
      }
    }
    times.sort();
    final p99 = times[times.length * 99 ~/ 100];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  });

  group('guardrails', () {
    final base = gen.generate(3, soft, 2);

    test('a rim below 3:1 fails softRim and is repaired', () {
      final p = base.palette;
      final faint = oklchToArgb(
        argbToOklch(p.background).l + (base.isDark ? 0.05 : -0.05),
        0,
        0,
      );
      final broken = base.copyWith(
        palette: p.copyWith(digit: p.digit.copyWith(edge: faint)),
      );
      final rules = {for (final v in validateTheme(broken)) v.rule};
      expect(rules, contains(GuardrailRule.softRim));
      final fixed = repairTheme(broken);
      expect(fixed, isNotNull);
      expect(validateTheme(fixed!), isEmpty);
      expect(
        contrastRatio(fixed.palette.digit.edge, fixed.palette.background),
        greaterThanOrEqualTo(3),
      );
    });

    test('rim width outside 1–1.5 dp fails', () {
      for (final w in [0, 99, 151, 300]) {
        final s = base.copyWith(
          keyStyle: base.keyStyle.copyWith(outlineWidthCdp: w),
        );
        expect(
          validateTheme(s).map((v) => v.rule),
          contains(GuardrailRule.softRim),
          reason: '$w',
        );
      }
    });

    test('a pressed label (accent) below the floor fails', () {
      final p = base.palette;
      final weak = oklchToArgb(argbToOklch(p.background).l, 0.1, 30);
      final broken = base.copyWith(palette: p.copyWith(accent: weak));
      expect(
        validateTheme(broken).map((v) => v.rule),
        contains(GuardrailRule.softPressedLabel),
      );
      final fixed = repairTheme(broken);
      expect(fixed, isNotNull);
      expect(validateTheme(fixed!), isEmpty);
    });

    test('a weight cue without the weight fails', () {
      final broken = base.copyWith(
        type: base.type.copyWith(operatorWeight: base.type.keyWeight + 100),
      );
      expect(
        validateTheme(broken).map((v) => v.rule),
        contains(GuardrailRule.softOperatorCue),
      );
      expect(repairTheme(broken), isNull);
    });

    test('shadows on the wrong side of the surface fail', () {
      final p = base.palette;
      final broken = base.copyWith(
        palette: p.copyWith(highlight: p.shadow, shadow: p.highlight),
      );
      expect(
        validateTheme(broken).map((v) => v.rule),
        contains(GuardrailRule.softShadow),
      );
    });

    test('soft rules never apply to other styles', () {
      for (final f in [ThemeFamily.m3Expressive, ThemeFamily.neoPop]) {
        final s = gen.generate(5, f, 2);
        final rules = {for (final v in validateTheme(s)) v.rule};
        expect(rules, isEmpty);
        // A faint edge on a non-soft theme is not a violation.
        final faint = s.copyWith(
          palette: s.palette.copyWith(
            digit: s.palette.digit.copyWith(edge: s.palette.background),
          ),
        );
        expect(validateTheme(faint), isEmpty);
      }
    });

    test('softRimFor gives the least change reaching 3:1', () {
      for (final bg in [0xFFE0E0E0, 0xFF2B2B2B, 0xFFEEE9E1, 0xFF1D2229]) {
        final rim = softRimFor(bg);
        final r = contrastRatio(rim, bg);
        expect(r, greaterThanOrEqualTo(3));
        expect(r, lessThan(3.2));
      }
      // Research §7.1: on #E0E0E0 a neutral edge needs L_ok ≈ 0.60.
      expect(argbToOklch(softRimFor(0xFFE0E0E0)).l, closeTo(0.60, 0.03));
    });
  });

  group('heroes', () {
    final heroes = heroesFor(soft);

    test('three or more, all passing, both brightnesses', () {
      expect(heroes.length, greaterThanOrEqualTo(3));
      expect(heroes.map((h) => h.isDark).toSet(), {true, false});
      for (final h in heroes) {
        expect(validateTheme(h), isEmpty, reason: h.name);
        expect(h.engineVersion, 2);
        expect(h.keyStyle.kind, KeyStyleKind.soft);
        expect(h.palette.digit.face, h.palette.background);
        final a = heroForAccessible(h);
        expect(validateTheme(a), isEmpty, reason: '${h.name} accessible');
      }
    });

    test('fallback for the family is one of its heroes', () {
      for (var s = 0; s < 10; s++) {
        expect(heroFallback(s, soft).family, soft);
      }
    });
  });
}
