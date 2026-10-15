/// Cyberpunk generator, guardrails, heroes and fixtures (new family 13,
/// shipped additively at engine v3).
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_CYBERPUNK_GOLDENS=1 dart test test/themes/engine/cyberpunk_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cyberpunk.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily cyber = ThemeFamily.cyberpunk;

String fixturePath(int version) =>
    'test/engine/fixtures/cyberpunk_v$version.json';

/// Pinned cases (v3): neon noir (magenta / acid), Hazard, netrunner
/// (toxic / magenta), afterhours (amber / cyan), and both locks.
const List<({int seed, bool accessible})> cyberpunkCases = [
  (seed: 0, accessible: false),
  (seed: 3, accessible: false),
  (seed: 4, accessible: false),
  (seed: 2, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

int alphaOf(int argb) => (argb >>> 24) & 0xFF;

double minContrastOver(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

void main() {
  group('definition', () {
    test('enabled, shipped at v3 only, recipe tokens from the design', () {
      expect(cyber.enabled, isTrue);
      expect(familyShippedAt(cyber, 1), isFalse);
      expect(familyShippedAt(cyber, 2), isFalse);
      expect(familyShippedAt(cyber, 3), isTrue);
      final def = cyber.definition;
      expect(identical(def, cyberpunkDefinition), isTrue);
      expect(def.keyStyle.kind, KeyStyleKind.flat);
      expect(def.sound, SoundPackId.mechTactile);
      expect(def.nonColourOperatorCue, OperatorCue.outline);
      expect(def.backgrounds.single.value, BackgroundKind.cyberGrid);
      expect(def.displayFonts.single.value, FontIds.oxanium);
      expect(def.keyFonts.single.value, FontIds.oxanium);
      final m = def.motion;
      expect(m.verb, PressVerb.plunge);
      expect(m.pressIn, SpringTokens.hardPress);
      expect(m.release, const SpringToken(4000, 1000));
      expect(m.depthCdp, 200);
      expect(m.entry, EntryStyle.glyph);
      expect(m.fx, PressFx.afterglow);
      expect(m.impact, ImpactStyle.rigid);
      expect(m.releaseHaptic, isFalse);
      expect(familyMaterialWords[cyber], hasLength(8));
    });
  });

  group('10,000 seeds pass the Cyberpunk guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        var noir = 0;
        var netrunner = 0;
        var afterhours = 0;
        var hazard = 0;
        var cyanOps = 0;
        var magentaOps = 0;
        var amberOps = 0;
        var slashed = 0;
        final buckets = <int>{};
        final corners = <int>{};
        final outlines = <int>{};
        final blurs = <int>{};
        final stiffness = <int>{};
        final minLabel = accessible ? 7.0 : 4.5;
        final minDisplay = accessible ? 7.0 : 4.5;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(seed, cyber, 3, accessible: accessible);
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bgs = backgroundSamples(s.background);
          expect(bgs, hasLength(36), reason: 'scene samples');

          // Labels on their opaque faces.
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            if (alphaOf(k.face) != 255) fail('seed $seed translucent face');
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
          }

          // The fill-versus-outline cue, recomputed: dark plates with
          // lighter labels, neon slabs with darker labels, ≥ 3:1 apart.
          for (final k in [p.digit, p.function]) {
            if (argbToOklch(k.face).l > 0.34 ||
                luminanceArgb(k.label) <= luminanceArgb(k.face)) {
              fail('seed $seed plate $k');
            }
          }
          for (final k in [p.operator, p.equals]) {
            if (argbToOklch(k.face).l < 0.64 ||
                luminanceArgb(k.label) >= luminanceArgb(k.face) ||
                contrastRatio(k.face, p.digit.face) < 3) {
              fail('seed $seed slab $k');
            }
          }
          if (s.type.operatorWeight < s.type.keyWeight + 200 ||
              s.type.operatorWeight > 800) {
            fail('seed $seed weights ${s.type.toJson()}');
          }

          // Plate edges: opaque neon lines ≥ 3:1 on their face; every
          // group reaches 3:1 on every scene sample through its face or
          // its edge.
          for (final k in [p.digit, p.function]) {
            expect(alphaOf(k.edge), 255);
            if (contrastRatio(k.edge, k.face) < 3) fail('seed $seed edge');
          }
          expect(p.function.edge, p.function.label);
          for (final k in [p.digit, p.function, p.operator, p.equals]) {
            if (minContrastOver(k.face, bgs) < 3 &&
                minContrastOver(k.edge, bgs) < 3) {
              fail('seed $seed boundary $k');
            }
          }

          // Display texts on the panel and its scanline composite (dark
          // themes: on every scene sample too; Hazard's yellow text sits
          // only on its black screen). Preview text reaches 4.5:1 in both
          // modes, the caret its limit.
          final panels = [p.surface, compositeOver(p.shadow, p.surface)];
          expect(displayBackdrops(s), [...panels, if (s.isDark) ...bgs]);
          for (final b in [...panels, if (s.isDark) ...bgs]) {
            if (contrastRatio(p.displayText, b) < minDisplay) {
              fail('seed $seed display');
            }
            if (contrastRatio(p.error, b) < minDisplay) {
              fail('seed $seed error');
            }
            if (contrastRatio(p.previewText, b) < 4.5) {
              fail('seed $seed preview');
            }
            if (contrastRatio(p.caret, b) < (accessible ? 4.5 : 3)) {
              fail('seed $seed caret');
            }
          }
          for (final b in bgs) {
            if (contrastRatio(p.focusRing, b) < 3) fail('seed $seed ring');
          }
          // Every screen is black, its scanlines lighter rows.
          final panel = argbToOklch(p.surface);
          expect(panel.l, lessThan(0.18), reason: '$seed panel');
          if (!accessible) {
            expect(
              luminanceArgb(compositeOver(p.shadow, p.surface)),
              greaterThan(luminanceArgb(p.surface)),
              reason: '$seed panel scanlines',
            );
          }

          // Neon colour quality (art review): cyan slabs at the gamut
          // edge (never ice blue), magenta never lavender, magenta
          // function labels and carets a hot pink in normal themes.
          for (final k in [p.operator, p.equals]) {
            final o = argbToOklch(k.face);
            if (o.h > 180 && o.h < 215) {
              expect(o.l, inInclusiveRange(0.795, 0.865), reason: '$seed');
              expect(o.c, greaterThan(0.13), reason: '$seed cyan $k');
            }
            if (o.h > 300) {
              expect(o.h, greaterThan(325.5), reason: '$seed magenta');
            }
          }
          if (!accessible) {
            final fn = argbToOklch(p.function.label);
            if (fn.h > 300) expect(fn.l, lessThan(0.765), reason: '$seed');
            final caret = argbToOklch(p.caret);
            if (caret.h > 300) expect(caret.l, lessThan(0.745));
          }

          // Tokens.
          expect(s.keyShape.kind, KeyShapeKind.cut);
          expect(s.keyShape.cornerPermille % 10, 0);
          expect(s.keyShape.cornerPermille, inInclusiveRange(120, 240));
          corners.add(s.keyShape.cornerPermille);
          expect(s.keyStyle.kind, KeyStyleKind.flat);
          expect(s.keyStyle.stateLayerPermille, 0);
          outlines.add(s.keyStyle.outlineWidthCdp);
          blurs.add(s.keyStyle.shadowBlurCdp);
          expect(s.nonColourOperatorCue, OperatorCue.outline);
          final m = s.motion;
          expect(m.pressIn, SpringTokens.hardPress);
          expect(m.verb, PressVerb.plunge);
          expect(m.entry, EntryStyle.glyph);
          expect(m.entryScalePermille, 1150);
          expect(m.fx, PressFx.afterglow);
          expect(m.impact, ImpactStyle.rigid);
          expect(m.impactPermille, 600);
          expect(m.depthCdp, 200);
          expect(m.release.zetaPermille, 1000);
          stiffness.add(m.release.stiffness);
          expect(s.sound, SoundPackId.mechTactile);
          expect(s.type.keyFont, FontIds.oxanium);
          expect(s.type.displayFont, FontIds.oxanium);
          if (s.type.slashedZero) slashed++;

          // Scene: five colours, opaque stops, static, inks under their
          // ceilings; panel scanlines off under the Accessible lock.
          final bg = s.background;
          expect(bg.kind, BackgroundKind.cyberGrid);
          expect(bg.colors, hasLength(5));
          expect(alphaOf(bg.colors[0]), 255);
          expect(alphaOf(bg.colors[1]), 255);
          expect(bg.driftPeriodMs, 0);
          expect(alphaOf(bg.colors[3]), lessThanOrEqualTo(72));
          expect(alphaOf(bg.colors[4]), lessThanOrEqualTo(56));
          expect(alphaOf(p.shadow), accessible ? 0 : inInclusiveRange(12, 48));
          final angle = bg.angleTenths;
          expect(angle <= 200 || angle >= 3400, isTrue, reason: '$angle');

          final body = argbToOklch(p.background);
          expect(p.background, bg.colors[0]);
          final op = argbToOklch(p.operator.face);
          if (op.c > 0.04) buckets.add(hueBucket(op.h));
          final opBucket = hueBucket(op.h);
          if (opBucket == 6 || opBucket == 7) cyanOps++;
          if (opBucket == 11) magentaOps++;
          if (opBucket == 2) amberOps++;
          if (s.isDark) {
            dark++;
            if (body.h >= 245 && body.h < 310) {
              noir++;
            } else if (body.h >= 180 && body.h < 245) {
              netrunner++;
            } else {
              afterhours++;
            }
            // The street glow: the haze is 0.06–0.10 lighter than the
            // body; a faint grid; slab rims hotter than their faces.
            final lift = argbToOklch(bg.colors[1]).l - body.l;
            expect(lift, inInclusiveRange(0.055, 0.105), reason: '$seed');
            expect(alphaOf(bg.colors[2]), inInclusiveRange(12, 18));
            expect(body.l, lessThan(0.2));
            for (final k in [p.operator, p.equals]) {
              expect(k.edge, cyberHotRim(k.face));
            }
            // The plate edge is always one of the two slab neons (also
            // after the `=` separation moved the `=` to another band).
            final edge = argbToOklch(p.digit.edge).h;
            double gap(double a, double b) {
              final d = (a - b).abs() % 360;
              return d > 180 ? 360 - d : d;
            }

            expect(
              gap(edge, op.h) < 3 ||
                  gap(edge, argbToOklch(p.equals.face).h) < 3,
              isTrue,
              reason: '$seed edge hue $edge',
            );
            // Plates keep a tint (never generic grey buttons).
            expect(argbToOklch(p.digit.face).c, greaterThan(0.022));
          } else {
            hazard++;
            // Hazard: a warm acid-yellow body (never lime), no grid,
            // black slab boundaries, cyan edges, yellow display text on a
            // cyan-tinted black screen, a magenta caret.
            expect(body.l, inInclusiveRange(0.895, 0.93));
            expect(body.h, inInclusiveRange(101.5, 107.5), reason: '$seed');
            expect(alphaOf(bg.colors[2]), 0, reason: 'no grid on Hazard');
            for (final k in [p.operator, p.equals]) {
              expect(argbToOklch(k.edge).l, lessThan(0.2));
            }
            expect(argbToOklch(p.digit.edge).h, inInclusiveRange(185, 207));
            expect(panel.l, inInclusiveRange(0.145, 0.175), reason: '$seed');
            expect(panel.c, inInclusiveRange(0.006, 0.018), reason: '$seed');
            expect(
              argbToOklch(p.displayText).h,
              inInclusiveRange(100, 110),
              reason: '$seed yellow display',
            );
            expect(argbToOklch(p.caret).h, greaterThan(320), reason: '$seed');
          }
        }
        expect(dark, inInclusiveRange(7000, 7900), reason: 'dark ≈ 3 in 4');
        expect(noir, inInclusiveRange(3300, 4200), reason: 'neon noir');
        expect(netrunner, inInclusiveRange(1800, 2600), reason: 'netrunner');
        expect(afterhours, inInclusiveRange(1100, 1850), reason: 'afterhours');
        expect(hazard, inInclusiveRange(2100, 2900), reason: 'Hazard');
        expect(buckets, {2, 3, 4, 5, 6, 7, 11}, reason: 'neon bands only');
        expect(cyanOps, inInclusiveRange(3700, 4900), reason: 'cyan slabs');
        expect(magentaOps, inInclusiveRange(3000, 4100), reason: 'magenta');
        expect(amberOps, inInclusiveRange(200, 500), reason: 'amber');
        expect(corners, hasLength(13));
        expect(outlines, {100, 125, 150});
        expect(blurs, {300, 350, 400, 450, 500});
        expect(stiffness, {3600, 4000, 4400});
        expect(slashed, inInclusiveRange(4600, 5400));
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
          final a = gen.generate(seed, cyber, 3, accessible: accessible);
          final b = other.generate(seed, cyber, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, cyber, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, cyber, 3);
      final a1 = gen.buildCandidate(5, cyber, 3, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
      expect(a1.sound, a0.sound);
      expect(a1.background.angleTenths, a0.background.angleTenths);
    });

    test('accessible and normal differ only where contrast demands', () {
      for (final seed in [0, 3, 42]) {
        final n = gen.generate(seed, cyber, 3);
        final a = gen.generate(seed, cyber, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        expect(a.background, n.background);
        expect(a.brightness, n.brightness);
      }
    });

    test('Cyberpunk did not exist before engine v3', () {
      expect(() => gen.generate(1, cyber, 1), throwsArgumentError);
      expect(() => gen.generate(1, cyber, 2), throwsArgumentError);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, cyber, 3);
      final code = encodeShareCode(cyber.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, cyber.id);
      expect(gen.generate(decoded.seed, cyber, decoded.engineVersion), spec);
    });

    test('generated backgrounds are unmodifiable', () {
      final spec = gen.generate(7, cyber, 3);
      expect(() => spec.background.colors[0] = 0, throwsUnsupportedError);
    });

    for (final version in [3]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            cyber,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': cyber.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_CYBERPUNK_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in cyberpunkCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(cyberpunkCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = cyberpunkCases[i];
          final spec = gen.generate(
            c.seed,
            cyber,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], cyber.id);
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
      gen.generate(s, cyber, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, cyber, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('scene samples', () {
    test('36 opaque samples in paint order; null for a malformed scene', () {
      final spec = gen.generate(0, cyber, 3);
      final samples = cyberpunkSceneSamples(spec.background)!;
      expect(samples, hasLength(36));
      expect(samples.every((c) => alphaOf(c) == 255), isTrue);
      final c = spec.background.colors;
      // The bare stops, a grid line, a major grid line (drawn twice) and
      // a trace over a major line under a scanline are all sampled.
      final gs = compositeOver(c[2], c[0]);
      final ggs = compositeOver(c[2], gs);
      expect(samples, containsAll([c[0], c[1], gs, ggs]));
      expect(samples, contains(compositeOver(c[4], compositeOver(c[3], ggs))));
      expect(
        cyberpunkSceneSamples(
          spec.background.copyWith(colors: List.unmodifiable(c.take(4))),
        ),
        isNull,
      );
    });

    test('display backdrops: panel, its scanline composite, the scene', () {
      final spec = gen.generate(0, cyber, 3);
      final p = spec.palette;
      final bd = displayBackdrops(spec);
      expect(bd.take(2), [p.surface, compositeOver(p.shadow, p.surface)]);
      expect(bd.skip(2), backgroundSamples(spec.background));
      // Hazard's yellow text lives on its black screen only.
      final hazard = gen.generate(3, cyber, 3);
      expect(hazard.isDark, isFalse);
      final h = hazard.palette;
      expect(displayBackdrops(hazard), [
        h.surface,
        compositeOver(h.shadow, h.surface),
      ]);
    });
  });

  group('guardrails', () {
    final dark = gen.generate(0, cyber, 3);
    final hazard = gen.generate(3, cyber, 3);

    List<GuardrailRule> rules(ThemeSpec s) => [
      for (final v in validateTheme(s)) v.rule,
    ];

    setUpAll(() {
      expect(dark.isDark, isTrue);
      expect(hazard.isDark, isFalse);
      expect(validateTheme(dark), isEmpty);
      expect(validateTheme(hazard), isEmpty);
    });

    test('a neon digit plate breaks the operator cue (not repaired)', () {
      final bad = dark.copyWith(
        palette: dark.palette.copyWith(
          digit: dark.palette.digit.copyWith(
            face: dark.palette.operator.face,
            label: dark.palette.operator.label,
          ),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.cyberOperatorCue));
      expect(repairTheme(bad), isNull, reason: 'cue failures force a retry');
    });

    test('a dark slab or a lighter slab label breaks the operator cue', () {
      final dim = dark.copyWith(
        palette: dark.palette.copyWith(
          operator: dark.palette.operator.copyWith(
            face: dark.palette.function.face,
          ),
        ),
      );
      expect(rules(dim), contains(GuardrailRule.cyberOperatorCue));
      final flipped = dark.copyWith(
        palette: dark.palette.copyWith(
          equals: dark.palette.equals.copyWith(label: 0xFFFFFFFF),
        ),
      );
      expect(rules(flipped), contains(GuardrailRule.cyberOperatorCue));
    });

    test('a dishonest weight cue fails', () {
      final bad = dark.copyWith(
        type: dark.type.copyWith(operatorWeight: dark.type.keyWeight + 100),
      );
      expect(rules(bad), contains(GuardrailRule.cyberOperatorCue));
    });

    test('an edge equal to its face fails and repairs to ≥ 3:1', () {
      final p = dark.palette;
      final bad = dark.copyWith(
        palette: p.copyWith(digit: p.digit.copyWith(edge: p.digit.face)),
      );
      expect(rules(bad), contains(GuardrailRule.cyberEdge));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      final d = fixed.palette.digit;
      expect(contrastRatio(d.edge, d.face), greaterThanOrEqualTo(3));
    });

    test('an edge width outside 1–1.5 dp fails', () {
      for (final w in [50, 200]) {
        final bad = dark.copyWith(
          keyStyle: dark.keyStyle.copyWith(outlineWidthCdp: w),
        );
        expect(rules(bad), contains(GuardrailRule.cyberEdge));
      }
    });

    test('a yellow Hazard slab edge breaks the key boundary; repaired', () {
      final p = hazard.palette;
      final bad = hazard.copyWith(
        palette: p.copyWith(operator: p.operator.copyWith(edge: p.background)),
      );
      expect(rules(bad), contains(GuardrailRule.cyberKeyBoundary));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      final bgs = backgroundSamples(fixed.background);
      expect(
        minContrastOver(fixed.palette.operator.edge, bgs),
        greaterThanOrEqualTo(3),
      );
    });

    test('panel scanlines too strong break the scene; repaired', () {
      final bad = dark.copyWith(
        palette: dark.palette.copyWith(
          shadow: withAlpha(dark.palette.shadow, 200),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.cyberScene));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(alphaOf(fixed.palette.shadow), lessThanOrEqualTo(48));
    });

    test('panel scanlines under the Accessible lock fail; repaired', () {
      final a = gen.generate(0, cyber, 3, accessible: true);
      final bad = a.copyWith(
        palette: a.palette.copyWith(shadow: withAlpha(a.palette.shadow, 30)),
      );
      expect(rules(bad), contains(GuardrailRule.cyberScene));
      final fixed = repairTheme(bad)!;
      expect(alphaOf(fixed.palette.shadow), 0);
    });

    test('a malformed scene or key shape fails', () {
      final bg = dark.background;
      final four = dark.copyWith(
        background: bg.copyWith(colors: List.unmodifiable(bg.colors.take(4))),
      );
      final tilted = dark.copyWith(background: bg.copyWith(angleTenths: 900));
      final loud = dark.copyWith(
        background: bg.copyWith(
          colors: List.unmodifiable([
            ...bg.colors.take(2),
            withAlpha(bg.colors[2], 100),
            ...bg.colors.skip(3),
          ]),
        ),
      );
      final drifting = dark.copyWith(
        background: bg.copyWith(driftPeriodMs: 20000),
      );
      final rounded = dark.copyWith(
        keyShape: const KeyShapeSpec(
          kind: KeyShapeKind.roundedRect,
          cornerPermille: 180,
        ),
      );
      final layered = dark.copyWith(
        keyStyle: dark.keyStyle.copyWith(stateLayerPermille: 120),
      );
      for (final bad in [four, tilted, loud, drifting, rounded, layered]) {
        expect(rules(bad), contains(GuardrailRule.cyberScene));
      }
    });

    test('a relit derived edge follows the repaired faces', () {
      // The generic repair moves the function label; the function edge
      // and the slab rims are re-derived from the final colours.
      final p = dark.palette;
      final bad = dark.copyWith(
        palette: p.copyWith(
          function: p.function.copyWith(label: p.function.face),
        ),
      );
      final fixed = repairTheme(bad)!;
      final q = fixed.palette;
      expect(q.function.edge, q.function.label);
      expect(q.operator.edge, cyberHotRim(q.operator.face));
      expect(q.equals.edge, cyberHotRim(q.equals.face));
    });

    test('other families are not checked by the cyber rules', () {
      const cyberRules = {
        GuardrailRule.cyberOperatorCue,
        GuardrailRule.cyberEdge,
        GuardrailRule.cyberKeyBoundary,
        GuardrailRule.cyberScene,
      };
      for (final f in [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.neoBrutalism,
      ]) {
        final s = gen.generate(3, f, 3);
        expect(rules(s).toSet().intersection(cyberRules), isEmpty);
      }
    });
  });

  test('heroes: three Cyberpunk heroes, dark and Hazard', () {
    final heroes = heroesFor(cyber);
    expect(heroes, hasLength(3));
    expect(heroes.map((h) => h.heroId), [130, 131, 132]);
    expect(heroes.map((h) => h.name), [
      'Cipher Rain',
      'Hazard Glitch',
      'Toxic Uplink',
    ]);
    expect(heroes.where((h) => h.isDark), hasLength(2));
    expect(heroes.where((h) => !h.isDark), hasLength(1));
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      final a = heroForAccessible(h);
      expect(validateTheme(a), isEmpty, reason: h.name);
      expect(alphaOf(a.palette.shadow), 0, reason: 'no scanlines');
      expect(h.sound, SoundPackId.mechTactile);
      expect(h.motion, cyberpunkDefinition.motion);
      expect(h.keyStyle.kind, KeyStyleKind.flat);
      expect(h.keyStyle.stateLayerPermille, 0);
      expect(h.nonColourOperatorCue, OperatorCue.outline);
      expect(h.background.kind, BackgroundKind.cyberGrid);
      expect(h.palette.accent, h.palette.focusRing);
      expect(h.palette.seedColor, h.palette.operator.face);
      expect(h.palette.function.edge, h.palette.function.label);
      expect(h.type.operatorWeight, lessThanOrEqualTo(800));
      if (!h.isDark) {
        expect(alphaOf(h.background.colors[2]), 0, reason: 'no grid');
        // The black HUD screen with the body's yellow as display text.
        expect(argbToOklch(h.palette.surface).l, lessThan(0.18));
        expect(h.palette.displayText, h.palette.background);
      } else {
        for (final k in [h.palette.operator, h.palette.equals]) {
          expect(
            argbToOklch(k.edge).l,
            greaterThan(argbToOklch(k.face).l),
            reason: 'slab rims are hotter than their faces',
          );
        }
      }
    }
  });
}
