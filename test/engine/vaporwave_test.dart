/// Vaporwave generator, guardrails, heroes and fixtures (family 14, engine
/// v3; design: square Win95 buttons over a striped-sun sunset scene).
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_VAPORWAVE_GOLDENS=1 dart test test/themes/engine/vaporwave_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/vaporwave.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily vw = ThemeFamily.vaporwave;

String fixturePath(int version) =>
    'test/engine/fixtures/vaporwave_v$version.json';

/// Pinned cases (v3): every scene variant, both title bars, both locks.
const List<({int seed, bool accessible})> vaporwaveCases = [
  (seed: 0, accessible: false),
  (seed: 1, accessible: false),
  (seed: 3, accessible: false),
  (seed: 7, accessible: false),
  (seed: 10, accessible: false),
  (seed: 41, accessible: false),
  (seed: 42, accessible: false),
  (seed: 1234, accessible: false),
  (seed: 0xA5A5A5A5, accessible: false),
  (seed: 0, accessible: true),
  (seed: 13, accessible: true),
  (seed: 42, accessible: true),
  (seed: 102, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

/// Hue in degrees of [argb].
double hueOf(int argb) => argbToOklch(argb).h;

/// Whether hue [h] lies in [lo, hi] degrees (no wrap needed here).
bool hueIn(double h, double lo, double hi) => h >= lo && h <= hi;

/// The operator hue bucket (30° wide, centred on multiples of 30°).
int bucketOf(int argb) => ((hueOf(argb) + 15) % 360) ~/ 30;

void main() {
  group('10,000 seeds pass the Vaporwave guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        var dusk = 0;
        var aqua = 0;
        var sunsetTitle = 0;
        final depths = <int>{};
        final bevels = <int>{};
        final corners = <int>{};
        final horizons = <int>{};
        final opBuckets = <int>{};
        final shades = <int>{};
        final highlights = <int>{};
        final minLabel = accessible ? 7.0 : 4.5;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            vw,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bg = s.background;
          final bgs = backgroundSamples(bg);
          expect(bgs, hasLength(58), reason: 'seed $seed');
          // Labels on their opaque faces; one ink for every key line.
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
            if (k.face >>> 24 != 0xFF) fail('seed $seed translucent face');
            expect(k.edge, p.shadow, reason: 'seed $seed');
          }
          // Light themes: the ink delimits pastel keys on a pastel floor,
          // and the keys stand a lightness step off the far floor, the
          // grid off the near floor.
          if (!s.isDark) {
            for (final b in bgs) {
              if (contrastRatio(p.shadow, b) < 3) fail('seed $seed ink');
            }
            for (final f in [p.digit.face, p.function.face]) {
              if (contrastRatio(f, bg.colors[6]) <
                  vaporwaveLightKeyFloorContrast) {
                fail('seed $seed keys sink into the floor');
              }
            }
            if (contrastRatio(bg.colors[8], bg.colors[7]) <
                vaporwaveLightGridFloorContrast) {
              fail('seed $seed faint grid');
            }
          } else {
            // Dark themes: every key stands off every grid-over-floor mix
            // (alpha k / 8, and the horizon haze) by its face, its ink or
            // its outer bevel highlight.
            final mixes = vaporwaveKeyMixSamplesOf(bg.colors);
            expect(mixes, hasLength(43));
            for (final k in [p.digit, p.operator, p.equals, p.function]) {
              final hi = vaporwaveBevelHighlight(
                k.face,
                s.keyStyle.highlightPermille,
              );
              for (final m in mixes) {
                final best = [
                  contrastRatio(k.face, m),
                  contrastRatio(p.shadow, m),
                  contrastRatio(hi, m),
                ].reduce((a, b) => a > b ? a : b);
                if (best < 3) {
                  fail('seed $seed key lost on ${m.toRadixString(16)}');
                }
              }
            }
          }
          // Digit faces are periwinkle … baby pink, never peach or mint;
          // peach and pink faces carry the richer pastel chroma.
          final digitHue = hueOf(p.digit.face);
          if (digitHue > 15 && digitHue < 245) {
            fail('seed $seed digit hue $digitHue');
          }
          for (final k in [p.digit, p.function]) {
            final f = argbToOklch(k.face);
            expect(f.c, greaterThanOrEqualTo(0.045), reason: 'seed $seed');
            if (f.h >= 345 || f.h <= 75) {
              expect(f.c, greaterThanOrEqualTo(0.06), reason: 'seed $seed');
            }
          }
          // The Accessible lock lifts the warm accent onto 0.72–0.75.
          if (accessible) {
            final warm =
                luminanceArgb(p.operator.face) < luminanceArgb(p.equals.face)
                ? p.operator.face
                : p.equals.face;
            expect(argbToOklch(warm).l, greaterThan(0.715));
          }
          // Display text on the opaque client panel only.
          expect(p.surface >>> 24, 0xFF);
          expect(displayBackdrops(s), [p.surface]);
          if (contrastRatio(p.displayText, p.surface) < minLabel) {
            fail('seed $seed display');
          }
          // The focus ring (and the toolbar icons) on every scene sample.
          for (final b in bgs) {
            if (contrastRatio(p.focusRing, b) < 3) fail('seed $seed ring');
          }
          // Accents a step apart from the pastel keys, CVD included.
          for (final a in [p.operator.face, p.equals.face]) {
            for (final b in [p.digit.face, p.function.face]) {
              if (minCvdDeltaE(a, b) < 0.06 || contrastRatio(a, b) < 1.2) {
                fail('seed $seed accent vs body');
              }
            }
          }
          // The scene: ten opaque colours inside the luminance band; the
          // lowest sun stripes stand off the night glow behind them.
          expect(bg.kind, BackgroundKind.vaporSunset);
          expect(bg.colors, hasLength(10));
          expect(bg.driftPeriodMs, vaporwaveDriftPeriodMs);
          expect(bg.pattern, BackgroundPattern.none);
          for (final b in bgs) {
            final y = luminanceArgb(b);
            if (s.isDark ? y > 0.26 : y < 0.17) fail('seed $seed band $y');
          }
          if (s.isDark && deltaEOKArgb(bg.colors[5], bg.colors[2]) < 0.09) {
            fail('seed $seed sun stripes vanish into the glow');
          }
          horizons.add(bg.angleTenths);
          // Tokens.
          expect(s.keyStyle.kind, KeyStyleKind.extruded);
          expect(s.keyStyle.outlineWidthCdp, 100);
          expect(s.keyStyle.shadowBlurCdp, 0);
          expect(s.keyStyle.stateLayerPermille, 60);
          expect(s.keyStyle.shadowOffsetCdp, s.motion.depthCdp);
          expect(s.keyShape.kind, KeyShapeKind.roundedRect);
          expect(s.motion.pressIn, SpringTokens.effectsFast);
          expect(s.motion.verb, PressVerb.sink);
          expect(s.motion.scalePermille, 1000);
          expect(s.motion.entry, EntryStyle.rise);
          expect(s.motion.entryOffsetCdp, 600);
          expect(s.motion.entrySpring, SpringTokens.standardNormal);
          expect(s.motion.impact, ImpactStyle.light);
          expect(s.motion.impactPermille, 600);
          expect(s.sound, SoundPackId.softTap);
          expect(s.type.displayFont, FontIds.anybody);
          expect(s.type.keyFont, FontIds.anybody);
          expect(s.nonColourOperatorCue, OperatorCue.weight);
          if (s.type.operatorWeight < s.type.keyWeight + 200) {
            fail('seed $seed weights ${s.type.toJson()}');
          }
          depths.add(s.motion.depthCdp);
          bevels.add(s.keyStyle.extrudeDepthCdp);
          corners.add(s.keyShape.cornerPermille);
          shades.add(s.keyStyle.edgeShadePermille);
          highlights.add(s.keyStyle.highlightPermille);
          opBuckets.add(bucketOf(p.operator.face));
          // Variants, classified from the colours.
          if (s.isDark) {
            dark++;
            if (hueIn(hueOf(bg.colors[8]), 320, 350)) dusk++;
          } else if (hueIn(hueOf(bg.colors[0]), 240, 275)) {
            aqua++;
          }
          if (p.highlight == p.operator.face || p.highlight == p.equals.face) {
            sunsetTitle++;
          }
        }
        expect(depths, {100, 200});
        expect(bevels, {200, 300});
        expect(corners, {0, 10, 20});
        expect(shades, {260, 280, 300, 320, 340});
        expect(highlights, {800, 850, 900, 950});
        expect(horizons, hasLength(9));
        expect(horizons, everyElement(inInclusiveRange(380, 460)));
        // Six neon buckets: hot pink, coral, aqua, cyan, violet, magenta.
        expect(opBuckets, {0, 1, 6, 7, 10, 11});
        expect(dark, inInclusiveRange(5300, 5800), reason: 'dark ≈ 5 in 9');
        expect(dusk / dark, inInclusiveRange(0.55, 0.65), reason: 'dusk 3:2');
        final light = 10000 - dark;
        expect(aqua / light, inInclusiveRange(0.35, 0.45), reason: 'aqua 2:3');
        expect(sunsetTitle, inInclusiveRange(5700, 6300), reason: 'sunset 3:2');
      });
    }
  });

  test('scene variants: night suns, grids and day skies', () {
    var midnight = 0;
    for (var seed = 0; seed < 2000; seed++) {
      final s = gen.generate(seed, vw, 3);
      final c = s.background.colors;
      final grid = hueOf(c[8]);
      if (s.isDark) {
        // Dusk: a neon-magenta grid; midnight: electric violet.
        expect(
          hueIn(grid, 320, 350) || hueIn(grid, 285, 310),
          isTrue,
          reason: 'seed $seed grid $grid',
        );
        expect(argbToOklch(c[8]).c, greaterThan(0.15));
        if (hueIn(grid, 320, 350)) {
          // Dusk: red-orange → hot pink → magenta (never rust or gold).
          expect(hueOf(c[3]), inInclusiveRange(25, 45), reason: 'seed $seed');
          expect(hueOf(c[5]), inInclusiveRange(325, 350), reason: 'seed $seed');
        } else {
          // Midnight: a cooler hot pink → magenta → violet sun.
          midnight++;
          final top = hueOf(c[3]);
          expect(top >= 345 || top <= 10, isTrue, reason: 'seed $seed $top');
          expect(hueOf(c[5]), inInclusiveRange(290, 315), reason: 'seed $seed');
        }
      } else {
        // Pastel sky (pink-lilac) or aqua's periwinkle top, never the Y2K
        // sky blue.
        final top = hueOf(c[0]);
        expect(
          hueIn(top, 310, 335) || hueIn(top, 245, 270),
          isTrue,
          reason: 'seed $seed sky $top',
        );
      }
    }
    expect(midnight, greaterThan(300));
  });

  test(
    'release stays inside the brief (439/0.8 × {0.9, 1, 1.1}, ζ ± 0.05)',
    () {
      final seen = <int>{};
      for (var seed = 0; seed < 500; seed++) {
        final m = gen.generate(seed, vw, 3).motion;
        seen.add(m.release.stiffness);
        expect(m.release.zetaPermille, inInclusiveRange(750, 850));
        expect(m.releaseHaptic, isFalse);
      }
      expect(seen, {395, 439, 482});
    },
  );

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, vw, 3, accessible: accessible);
          final b = other.generate(seed, vw, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, vw, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, vw, 3);
      final a1 = gen.buildCandidate(5, vw, 3, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
      expect(a1.background.angleTenths, a0.background.angleTenths);
    });

    test('accessible and normal differ only where contrast demands', () {
      for (final seed in [0, 3, 42, 1234]) {
        final n = gen.generate(seed, vw, 3);
        final a = gen.generate(seed, vw, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        expect(a.brightness, n.brightness);
        expect(a.background.angleTenths, n.background.angleTenths);
        expect(a.background.colors, n.background.colors);
      }
    });

    test('Vaporwave ships at engine v3 only', () {
      expect(() => gen.generate(1, vw, 1), throwsArgumentError);
      expect(() => gen.generate(1, vw, 2), throwsArgumentError);
      expect(familyShippedAt(vw, 2), isFalse);
      expect(familyShippedAt(vw, 3), isTrue);
      expect(vw.enabled, isTrue);
      expect(vw.id, 14);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, vw, 3);
      final code = encodeShareCode(vw.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, vw.id);
      expect(gen.generate(decoded.seed, vw, decoded.engineVersion), spec);
    });

    for (final version in [3, 4, 5]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            vw,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': vw.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_VAPORWAVE_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in vaporwaveCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(vaporwaveCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = vaporwaveCases[i];
          final spec = gen.generate(
            c.seed,
            vw,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], vw.id);
          expect(cases[i]['accessible'], c.accessible);
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
      gen.generate(s, vw, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, vw, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('scene samples and display backdrops', () {
    final spec = gen.generate(3, vw, 3);

    test('58 opaque samples: stops, gradient and edge mixes, glow, haze', () {
      final samples = vaporwaveSceneSamples(spec.background)!;
      expect(samples, hasLength(58));
      final c = spec.background.colors;
      expect(samples.last, compositeOver(withAlpha(c[9], 71), c[6]));
      expect(samples.take(10), spec.background.colors);
      expect(samples.every((c) => c >>> 24 == 0xFF), isTrue);
      expect(backgroundSamples(spec.background), samples);
    });

    test('a malformed scene falls back to the generic stops', () {
      final short = spec.background.copyWith(
        colors: spec.background.colors.take(9).toList(),
      );
      expect(vaporwaveSceneSamples(short), isNull);
      expect(backgroundSamples(short), short.colors);
      expect(
        vaporwaveSceneSamples(
          spec.background.copyWith(kind: BackgroundKind.solid),
        ),
        isNull,
      );
    });

    test('keys are checked against the floor they cover', () {
      final keys = vaporwaveKeySamplesOf(spec.background.colors);
      final c = spec.background.colors;
      expect(keys, containsAll([c[6], c[7], c[8]]));
      expect(keys, hasLength(6));
      // …and the grid at alpha k / 8 over each floor sample and the haze.
      final mixes = vaporwaveKeyMixSamplesOf(c);
      expect(mixes, hasLength(43));
      expect(mixes.every((m) => m >>> 24 == 0xFF), isTrue);
      final haze = compositeOver(withAlpha(c[9], 71), c[6]);
      expect(mixes, contains(haze));
    });

    test('the bevel highlight the boundary rule counts', () {
      // L + (1 − L)·m toward white at 0.6·C; m × 0.6 on dark faces.
      final face = oklchToArgb(0.80, 0.06, 300);
      final f = argbToOklch(face);
      final hi = argbToOklch(vaporwaveBevelHighlight(face, 300));
      expect(hi.l, closeTo(f.l + (1 - f.l) * 0.3, 0.01));
      expect(hi.c, closeTo(0.6 * f.c, 0.005));
      final darkFace = oklchToArgb(0.4, 0.1, 300);
      final dhi = argbToOklch(vaporwaveBevelHighlight(darkFace, 850));
      expect(dhi.l, closeTo(0.4 + 0.6 * 0.85 * 0.6, 0.01));
    });

    test('display text sits on the client panel only', () {
      expect(vaporwaveDisplayBackdrops(spec, [spec.palette.surface], []), [
        spec.palette.surface,
      ]);
      expect(displayBackdrops(spec), [spec.palette.surface]);
    });
  });

  group('guardrails', () {
    final night = gen.generate(3, vw, 3);
    final day = gen.generate(0, vw, 3);

    test('the test themes are one night and one day theme', () {
      expect(night.isDark, isTrue);
      expect(day.isDark, isFalse);
      expect(validateTheme(night), isEmpty);
      expect(validateTheme(day), isEmpty);
    });

    Iterable<GuardrailRule> rules(ThemeSpec s) =>
        validateTheme(s).map((v) => v.rule);

    test('a dishonest weight cue fails', () {
      final bad = night.copyWith(
        type: night.type.copyWith(operatorWeight: night.type.keyWeight + 150),
      );
      expect(rules(bad), contains(GuardrailRule.vaporOperatorCue));
      final noCue = night.copyWith(nonColourOperatorCue: OperatorCue.none);
      expect(rules(noCue), contains(GuardrailRule.vaporOperatorCue));
    });

    test('an operator face equal to the digit face fails and repairs', () {
      final p = night.palette;
      final bad = night.copyWith(
        palette: p.copyWith(operator: p.operator.copyWith(face: p.digit.face)),
      );
      expect(rules(bad), contains(GuardrailRule.vaporOperatorFace));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      // A sunset title bar and the seed colour follow the moved accent.
      expect(fixed.palette.seedColor, fixed.palette.operator.face);
      expect([
        fixed.palette.highlight,
        fixed.palette.accent,
      ], contains(fixed.palette.operator.face));
    });

    test("an accent at the pastel keys' lightness fails and repairs", () {
      final p = day.palette;
      final d = argbToOklch(p.digit.face);
      // Far enough in hue for normal vision, but the same lightness.
      final face = oklchToArgb(d.l, 0.12, (d.h + 180) % 360);
      final bad = day.copyWith(
        palette: p.copyWith(equals: p.equals.copyWith(face: face)),
      );
      expect(deltaEOKArgb(face, p.digit.face), greaterThanOrEqualTo(0.08));
      expect(rules(bad), contains(GuardrailRule.vaporAccentVsDigit));
      expect(rules(bad), isNot(contains(GuardrailRule.vaporOperatorFace)));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
    });

    test('a malformed or out-of-band scene fails', () {
      final bg = night.background;
      final cases = {
        'horizon': bg.copyWith(angleTenths: 500),
        'drift': bg.copyWith(driftPeriodMs: 20000),
        'nine colours': bg.copyWith(colors: bg.colors.take(9).toList()),
        'translucent': bg.copyWith(
          colors: [bg.colors.first & 0x80FFFFFF, ...bg.colors.skip(1)],
        ),
        'kind': bg.copyWith(kind: BackgroundKind.solid),
        'bright floor': bg.copyWith(
          colors: [...bg.colors.take(7), 0xFFFFFFFF, ...bg.colors.skip(8)],
        ),
      };
      for (final MapEntry(key: name, value: b) in cases.entries) {
        expect(
          rules(night.copyWith(background: b)),
          contains(GuardrailRule.vaporScene),
          reason: name,
        );
      }
      // A static scene (drift 0) is allowed.
      expect(
        rules(night.copyWith(background: bg.copyWith(driftPeriodMs: 0))),
        isNot(contains(GuardrailRule.vaporScene)),
      );
    });

    test('a translucent panel, title bar or ink fails; panel repairs', () {
      final p = night.palette;
      for (final bad in [
        p.copyWith(surface: p.surface & 0xCCFFFFFF),
        p.copyWith(highlight: p.highlight & 0x80FFFFFF),
        p.copyWith(accent: p.accent & 0x80FFFFFF),
      ]) {
        expect(
          rules(night.copyWith(palette: bad)),
          contains(GuardrailRule.vaporPanel),
        );
      }
      final fixed = repairTheme(
        night.copyWith(palette: p.copyWith(surface: p.surface & 0xCCFFFFFF)),
      )!;
      expect(validateTheme(fixed), isEmpty);
      expect(fixed.palette.surface >>> 24, 0xFF);
    });

    test('a key edge that is not the drawn ink fails and repairs', () {
      final p = day.palette;
      final bad = day.copyWith(
        palette: p.copyWith(digit: p.digit.copyWith(edge: 0xFF808080)),
      );
      expect(rules(bad), contains(GuardrailRule.vaporOutline));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(fixed.palette.digit.edge, fixed.palette.shadow);
    });

    test('a faint day ink fails and repairs to ≥ 3:1 on the scene', () {
      final p = day.palette;
      const pastel = 0xFFC8B8E8;
      KeyColors faint(KeyColors k) => k.copyWith(edge: pastel);
      final bad = day.copyWith(
        palette: p.copyWith(
          shadow: pastel,
          digit: faint(p.digit),
          operator: faint(p.operator),
          equals: faint(p.equals),
          function: faint(p.function),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.vaporOutline));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      for (final b in backgroundSamples(fixed.background)) {
        expect(contrastRatio(fixed.palette.shadow, b), greaterThanOrEqualTo(3));
      }
    });

    test('a night key lost against the floor fails and repairs', () {
      final p = night.palette;
      final f = argbToOklch(p.function.face);
      // A mid-dark face with a light ink: neither delimits it from the
      // floor and the grid.
      final face = oklchToArgb(0.50, f.c, f.h);
      final bad = night.copyWith(
        palette: p.copyWith(
          function: KeyColors(face: face, label: 0xFFFFFFFF, edge: p.shadow),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.vaporBoundary));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      final keys = vaporwaveKeySamplesOf(fixed.background.colors);
      final k = fixed.palette.function;
      for (final s in keys) {
        final a = contrastRatio(k.face, s);
        final b = contrastRatio(fixed.palette.shadow, s);
        expect(a > b ? a : b, greaterThanOrEqualTo(3));
      }
    });

    test('a night key lost midway between the floor and the grid fails', () {
      // Endpoints pass (the face against the dark floor, the ink against
      // the bright grid), but a grid-over-floor mix of middling lightness
      // defeats both, and a near-zero highlight cannot rescue it.
      final p = night.palette;
      final c = night.background.colors;
      final f = argbToOklch(p.function.face);
      final ink = p.shadow;
      int? face;
      for (var l = 0.30; l < 0.80; l += 0.01) {
        final x = oklchToArgb(l, 0.05, f.h);
        final endpoints = vaporwaveKeySamplesOf(c).every((s) {
          final a = contrastRatio(x, s);
          final b = contrastRatio(ink, s);
          return (a > b ? a : b) >= 3;
        });
        final mixes = vaporwaveKeyMixSamplesOf(c).every((s) {
          final a = contrastRatio(x, s);
          final b = contrastRatio(ink, s);
          return (a > b ? a : b) >= 3;
        });
        if (endpoints && !mixes) {
          face = x;
          break;
        }
      }
      expect(face, isNotNull);
      final bad = night.copyWith(
        keyStyle: night.keyStyle.copyWith(highlightPermille: 1),
        palette: p.copyWith(
          function: KeyColors(face: face!, label: 0xFF000000, edge: ink),
        ),
      );
      final boundary = validateTheme(
        bad,
      ).where((v) => v.rule == GuardrailRule.vaporBoundary).toList();
      expect(boundary, isNotEmpty);
      expect(
        boundary.every((v) => v.detail.contains('grid over floor')),
        isTrue,
      );
      // With the theme's own highlight the same face is delimited.
      final lit = night.copyWith(palette: bad.palette);
      expect(
        validateTheme(lit).where(
          (v) =>
              v.rule == GuardrailRule.vaporBoundary &&
              v.detail.contains('function'),
        ),
        isEmpty,
      );
    });

    test('other families are not checked by the Vaporwave rules', () {
      const vaporRules = {
        GuardrailRule.vaporOperatorCue,
        GuardrailRule.vaporOperatorFace,
        GuardrailRule.vaporAccentVsDigit,
        GuardrailRule.vaporScene,
        GuardrailRule.vaporPanel,
        GuardrailRule.vaporOutline,
        GuardrailRule.vaporBoundary,
      };
      for (final f in [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.neoBrutalism,
        ThemeFamily.retro,
      ]) {
        for (var seed = 0; seed < 20; seed++) {
          final s = gen.buildCandidate(seed, f, 3);
          expect(
            rules(s).toSet().intersection(vaporRules),
            isEmpty,
            reason: '${f.name} $seed',
          );
        }
      }
    });
  });

  test('heroes: Dusk Plaza, Pastel Atrium, Moonlit Dolphin', () {
    final heroes = heroesFor(vw);
    expect(heroes.map((h) => h.heroId), [140, 141, 142]);
    expect(heroes.map((h) => h.name), [
      'Dusk Plaza',
      'Pastel Atrium',
      'Moonlit Dolphin',
    ]);
    expect(heroes.where((h) => h.isDark), hasLength(2));
    expect(heroes.where((h) => !h.isDark), hasLength(1));
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      final a = heroForAccessible(h);
      expect(validateTheme(a), isEmpty, reason: h.name);
      expect(a.accessible, isTrue);
      expect(h.engineVersion, 3);
      expect(h.keyStyle.kind, KeyStyleKind.extruded);
      expect(h.keyStyle.shadowOffsetCdp, h.motion.depthCdp);
      expect(h.nonColourOperatorCue, OperatorCue.weight);
      expect(h.sound, SoundPackId.softTap);
      expect(h.motion.verb, PressVerb.sink);
      expect(h.motion.pressIn, SpringTokens.effectsFast);
      expect(h.background.kind, BackgroundKind.vaporSunset);
      expect(h.background.driftPeriodMs, vaporwaveDriftPeriodMs);
      // Square Win95 buttons (corners 0–20 ‰ like every generated theme).
      expect(h.keyShape.kind, KeyShapeKind.roundedRect);
      expect(h.keyShape.cornerPermille, isIn([0, 10, 20]));
      expect(h.keyStyle.extrudeDepthCdp, isIn([200, 300]));
      // Pastel keys at face-grey lightness, never plum.
      for (final k in [h.palette.digit, h.palette.function]) {
        expect(argbToOklch(k.face).l, inInclusiveRange(0.78, 0.85));
      }
    }
    // The heroes are generated themes, copied literally.
    for (final (hero, seed) in [
      (heroes[0], 3),
      (heroes[1], 197),
      (heroes[2], 162),
    ]) {
      final s = gen.generate(seed, vw, 3);
      expect(hero.palette, s.palette, reason: hero.name);
      expect(hero.background.colors, s.background.colors, reason: hero.name);
    }
  });
}
