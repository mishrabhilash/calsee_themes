/// Claymorphism generator, guardrails, heroes and fixtures (spec §5.3 #7;
/// motion brief §2.3 "Claymorphism").
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_CLAYMORPHISM_GOLDENS=1 dart test test/themes/engine/claymorphism_test.dart
///
/// Note for fixture readers: `Palette.highlight`'s alpha comes from the
/// **style** stream (drawn first, with the blur and the shade depth), not
/// from the palette stream.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/claymorphism.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

double min(double a, double b) => a < b ? a : b;

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily clay = ThemeFamily.claymorphism;

String fixturePath(int version) =>
    'test/engine/fixtures/claymorphism_v$version.json';

/// Pinned cases (v3): candy, tonal and night themes (one on a butter
/// body), both locks.
const List<({int seed, bool accessible})> clayCases = [
  (seed: 0, accessible: false),
  (seed: 2, accessible: false),
  (seed: 4, accessible: false),
  (seed: 13, accessible: false),
  (seed: 14, accessible: false),
  (seed: 19, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

/// The variant and body anchor of [seed]'s first palette attempt (mirrors
/// the builder's first three palette draws; the sweep checks no seed needs
/// a retry).
(ClayVariant, int) variantOf(int seed) {
  final p = Rng.stream(seed, RngTag.palette);
  final dark = p.pickWeighted(claymorphismDefinition.brightnessWeights) == 0;
  final variant = dark
      ? ClayVariant.night
      : ClayVariant.values[p.pickWeighted(clayLightVariantWeights)];
  final anchors = dark ? clayNightBodyHues : clayLightBodyHues;
  return (variant, p.pickWeighted([for (final a in anchors) a.weight]));
}

double lightness(int argb) => argbToOklch(argb | 0xFF000000).l;

double lift(int face, int highlight) =>
    lightness(clayHighlightComposite(face, highlight)) - lightness(face);

List<KeyColors> keysOf(Palette p) => [
  p.digit,
  p.operator,
  p.equals,
  p.function,
];

/// Whether the hue (degrees) of [argb] lies in [lo, hi] with chroma above
/// 0.05.
bool inHueBand(int argb, double lo, double hi) {
  final c = argbToOklch(argb | 0xFF000000);
  return c.c > 0.05 && c.h >= lo && c.h <= hi;
}

void main() {
  group('10,000 seeds pass the Claymorphism guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        var candy = 0;
        var tonal = 0;
        var butter = 0;
        var retried = 0;
        final angles = <int, int>{};
        final depths = <int>{};
        final blurs = <int>{};
        final shades = <int>{};
        final highlights = <int>{};
        final corners = <int>{};
        // New-rule failures, each required to stay at 0.
        final failures = <String, int>{};
        void count(String what, {required bool when}) {
          if (when) failures[what] = (failures[what] ?? 0) + 1;
        }

        final minLabel = accessible ? 7.0 : 4.5;
        final lim = accessible
            ? GuardrailLimits.accessible
            : GuardrailLimits.standard;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            clay,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          if (validateTheme(
            gen.buildCandidate(seed, clay, 3, accessible: accessible),
          ).isNotEmpty) {
            retried++;
          }
          final p = s.palette;
          final bg = s.background;
          final colors = bg.colors;
          // Labels on their faces.
          for (final k in keysOf(p)) {
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
          }
          // Display text on the panel.
          if (contrastRatio(p.displayText, p.surface) < minLabel) {
            fail('seed $seed display');
          }
          // Renderer contract.
          expect(s.family, clay);
          expect(s.keyStyle.kind, KeyStyleKind.clay);
          expect(s.keyStyle.outlineWidthCdp, 0);
          expect(s.keyStyle.shadowOffsetCdp, s.motion.depthCdp);
          expect(s.keyShape.kind, KeyShapeKind.squircle);
          expect(s.keyShape.cornerPermille % 10, 0);
          expect(s.keyShape.cornerPermille, inInclusiveRange(300, 420));
          expect(s.type.displayFont, FontIds.nunito);
          expect(s.type.keyFont, FontIds.nunito);
          expect(s.type.operatorWeight, lessThanOrEqualTo(900));
          expect(s.type.operatorWeight, greaterThan(s.type.keyWeight));
          expect(bg.kind, BackgroundKind.claySoft);
          expect(colors, hasLength(9));
          for (final c in colors) {
            expect(c >>> 24, 0xFF);
          }
          expect(bg.driftPeriodMs, 0);
          expect(bg.angleTenths % 150, 0);
          expect(bg.angleTenths, inInclusiveRange(0, 750));
          expect(p.background, colors[0]);
          expect(p.surface >>> 24, 0xFF);
          expect(p.highlight & 0xFFFFFF, 0xFFFFFF);
          // Motion, sound and cue per brief.
          final m = s.motion;
          expect(m.verb, PressVerb.squash);
          expect(m.pressIn, SpringTokens.glassPressIn);
          expect(m.scalePermille, 920);
          expect(m.entry, EntryStyle.pop);
          expect(m.entryScalePermille, 860);
          expect(m.impact, ImpactStyle.soft);
          expect(m.impactPermille, 800);
          expect(m.releaseAlt, isNull);
          expect(s.sound, SoundPackId.pop);
          expect(s.nonColourOperatorCue, OperatorCue.none);

          // New rules, measured independently of the validator.
          final baseL = lightness(colors[0]);
          for (final k in keysOf(p)) {
            count('highlight lift', when: lift(k.face, p.highlight) < 0.025);
            if (s.isDark) {
              final e = argbToOklch(k.edge | 0xFF000000);
              count('night shadow chroma', when: e.c < 0.035);
              count(
                'night key vs body',
                when: lightness(k.face) - baseL < 0.15,
              );
            }
          }
          if (!s.isDark) {
            count(
              'light function vs body',
              when:
                  deltaEOKArgb(p.function.face, colors[0]) < 0.045 ||
                  baseL - lightness(p.function.face) < 0.03,
            );
          }
          count(
            'candy band (operator / function)',
            when:
                inHueBand(p.operator.face, 77, 128) ||
                inHueBand(p.function.face, 77, 128),
          );
          // `=`: no moss / olive / mustard (35–150°), no dull teal /
          // petrol (165–245°), a saturated gummy, no red `=` beside a
          // green operator.
          final eq = argbToOklch(p.equals.face);
          final op = argbToOklch(p.operator.face);
          count('candy band (=)', when: inHueBand(p.equals.face, 37, 149.4));
          count('dull band (=)', when: inHueBand(p.equals.face, 166, 244));
          count(
            '= chroma floor',
            when: eq.c < min(0.125, 0.92 * maxChroma(eq.l, eq.h)) - 0.004,
          );
          count(
            'green operator, red =',
            when:
                op.c > 0.05 &&
                op.h >= 120 &&
                op.h <= 170 &&
                (eq.h >= 340 || eq.h <= 30),
          );
          if (s.isDark) {
            // Night spheres: glowing jewels, never brown, green or teal
            // smudges; operators never kelly green.
            for (final i in [3, 6]) {
              final sphere = argbToOklch(colors[i]);
              count('brown night sphere', when: inHueBand(colors[i], 22, 88));
              count(
                'green / teal night sphere',
                when: inHueBand(colors[i], 100, 245),
              );
              count(
                'night sphere lightness',
                when: sphere.l < 0.395 || sphere.l > 0.465,
              );
              count('night sphere chroma', when: sphere.c < 0.06);
            }
            count(
              'kelly night operator',
              when: inHueBand(p.operator.face, 115, 154),
            );
          }
          // The focus ring where it crosses a key's own drop shadow.
          count(
            'focus ring over key shadow',
            when: clayFocusShadowSamples(
              p,
              colors,
            ).any((x) => contrastRatio(p.focusRing, x) < 3),
          );
          final ring = clayLabelRingColor(
            p.function,
            s.keyStyle.edgeShadePermille,
            p.highlight,
          );
          count(
            'function label on its ring',
            when: contrastRatio(p.function.label, ring) < lim.labelRatio,
          );

          // Distribution.
          final (variant, anchor) = variantOf(seed);
          expect(variant == ClayVariant.night, s.isDark, reason: 'seed $seed');
          expect(clayPanelRaised(s), isTrue, reason: 'pillow only ($seed)');
          if (s.isDark) {
            dark++;
          } else {
            if (variant == ClayVariant.candy) candy++;
            if (variant == ClayVariant.tonal) tonal++;
            if (anchor == clayButterAnchor) {
              // Butter: a clean pastel yellow, never khaki or manila.
              butter++;
              final body = argbToOklch(colors[0]);
              count(
                'butter body',
                when:
                    body.l < 0.877 ||
                    body.c < 0.084 ||
                    body.h < 94 ||
                    body.h > 104,
              );
            }
          }
          angles[bg.angleTenths] = (angles[bg.angleTenths] ?? 0) + 1;
          depths.add(m.depthCdp);
          blurs.add(s.keyStyle.shadowBlurCdp);
          shades.add(s.keyStyle.edgeShadePermille);
          highlights.add(p.highlight >>> 24);
          corners.add(s.keyShape.cornerPermille);
          final digitL = lightness(p.digit.face);
          final opL = lightness(p.operator.face);
          final eqL = lightness(p.equals.face);
          if (s.isDark) {
            expect(digitL, inInclusiveRange(0.91, 0.955), reason: '$seed');
          } else {
            expect(digitL, inInclusiveRange(0.92, 0.955), reason: '$seed');
            expect(
              lightness(p.function.face),
              inInclusiveRange(0.70, 0.86),
              reason: '$seed',
            );
          }
          expect(opL, inInclusiveRange(0.60, 0.80), reason: '$seed');
          expect(eqL, inInclusiveRange(0.38, 0.56), reason: '$seed');
          if (accessible) {
            expect(opL, greaterThanOrEqualTo(0.70), reason: '$seed');
            expect(eqL, lessThanOrEqualTo(0.464), reason: '$seed');
            if (s.isDark) {
              expect(baseL, lessThanOrEqualTo(0.225), reason: '$seed');
            }
          }
        }
        expect(failures, isEmpty);
        expect(retried, 0, reason: 'every first candidate passes');
        expect(dark, inInclusiveRange(2200, 2800), reason: 'night ≈ 1 in 4');
        final light = 10000 - dark;
        expect(candy / light, inInclusiveRange(0.55, 0.65));
        expect(tonal / light, inInclusiveRange(0.35, 0.45));
        expect(butter / light, inInclusiveRange(0.06, 0.12));
        expect(angles.keys.toSet(), {0, 150, 300, 450, 600, 750});
        for (final n in angles.values) {
          expect(n, inInclusiveRange(1300, 2000));
        }
        expect(depths, {400, 500, 600});
        expect(blurs, {1000, 1200, 1400});
        expect(shades, {80, 90, 100, 110});
        expect(highlights, {160, 170, 180, 190, 200});
        expect(corners, hasLength(13));
      });
    }
  });

  test('release stays inside the brief (ζ ≥ 0.591, settle ≤ 360 ms)', () {
    final depths = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, clay, 3).motion;
      expect(m.release.zetaPermille, inInclusiveRange(591, 750));
      final k = m.release.stiffness;
      final z = m.release.zetaPermille / 1000;
      // 4 / (ζ √k) ≤ 0.3605 s  ⇔  ζ² k ≥ 123.1.
      expect(z * z * k, greaterThanOrEqualTo(123.0), reason: '$seed');
      expect(m.releaseHaptic, isFalse);
      depths.add(m.depthCdp);
    }
    expect(depths, {400, 500, 600});
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, clay, 3, accessible: accessible);
          final b = other.generate(seed, clay, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, clay, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, clay, 3);
      final a1 = gen.buildCandidate(5, clay, 3, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
      expect(a1.background.angleTenths, a0.background.angleTenths);
    });

    test('accessible and normal differ only in the palette', () {
      for (final seed in [42, 13, 0]) {
        final n = gen.generate(seed, clay, 3);
        final a = gen.generate(seed, clay, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        expect(a.background.angleTenths, n.background.angleTenths);
        expect(a.brightness, n.brightness);
      }
    });

    test('Claymorphism ships at engine v3 only', () {
      expect(() => gen.generate(1, clay, 1), throwsArgumentError);
      expect(() => gen.generate(1, clay, 2), throwsArgumentError);
      expect(familyShippedAt(clay, 2), isFalse);
      expect(familyShippedAt(clay, 3), isTrue);
      expect(clay.enabled, isTrue);
      expect(clay.id, 7);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, clay, 3);
      final code = encodeShareCode(clay.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, clay.id);
      expect(gen.generate(decoded.seed, clay, decoded.engineVersion), spec);
    });

    for (final version in [3, 4, 5]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            clay,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': clay.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_CLAYMORPHISM_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in clayCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(clayCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = clayCases[i];
          final spec = gen.generate(
            c.seed,
            clay,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], clay.id);
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
      gen.generate(s, clay, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, clay, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('helpers', () {
    test('the candy-hue rule empties its band and spreads moved hues', () {
      int key(int h, [int? pivot]) => clayCandyHue(
        h,
        clayCandyKeyBand,
        clayCandyKeyTargets,
        pivot ?? h,
        maxPush: clayCandyKeyPush,
      );
      // Outside the band: unchanged (and wrapped).
      expect(key(700), 700);
      expect(key(1300), 1300);
      expect(key(3700), 100);
      // Inside: pushed past the nearer target by half the depth.
      expect(key(750), 650);
      expect(key(900), 575);
      expect(key(1299), 1400);
      expect(key(1100), 1499);
      // Depth is capped.
      expect(key(1100, 600), 500, reason: 'tonal pivot on the low side');
      for (var h = 0; h < 3600; h += 7) {
        expect(clayCandyKeyBand.contains(key(h)), isFalse, reason: '$h');
        final eq = clayCandyHue(
          h,
          clayEqualsBand,
          clayEqualsTargets,
          h,
          maxPush: clayEqualsPush,
        );
        expect(clayEqualsBand.contains(eq), isFalse, reason: '= $h');
      }
    });

    test('the = rule: no moss, no dull teal, grape beside green', () {
      for (var h = 0; h < 3600; h += 7) {
        for (final op in [0, 600, 1500, 2400, 3000]) {
          for (final night in [null, 2600, 3250]) {
            final eq = clayEqualsHue(h, op, nightBodyHue: night);
            final why = '$h op $op night $night → $eq';
            expect(eq > 350 && eq < 1500, isFalse, reason: why);
            expect(clayEqualsDullBand.contains(eq), isFalse, reason: why);
            if (clayGreenOperatorBand.contains(op)) {
              expect(eq >= 3400 || eq <= 300, isFalse, reason: why);
            }
          }
        }
      }
      // The candy band lands past emerald (156°) or red (25°).
      expect(clayEqualsHue(1400, 2700), 1609);
      expect(clayEqualsHue(400, 2700), 225);
      // The dull band: the nearer target, unless it meets the operator
      // (or, at night, the body).
      expect(clayEqualsDullHue(2000, 3000), 1500);
      expect(clayEqualsDullHue(2000, 1600), 2660);
      expect(clayEqualsDullHue(2400, 0), 2584);
      expect(clayEqualsDullHue(2400, 0, nightBodyHue: 2700), 1500);
      // A red `=` beside a green operator turns grape.
      expect(clayEqualsHue(3500, 1500), 3030);
      expect(clayEqualsHue(3500, 2400), 3500);
      // The candy band lands past emerald (then folds out of the dull
      // band's edge); beside a green operator it takes the red side
      // instead, which then turns grape.
      expect(clayEqualsHue(1300, 2700), 1556);
      expect(clayEqualsHue(1300, 1500), 3075);
    });

    test('night operators: kelly green turns jade', () {
      expect(clayNightOperatorHue(1150), 1550);
      expect(clayNightOperatorHue(1549), 1650);
      expect(clayNightOperatorHue(1400), 1612);
      expect(clayNightOperatorHue(1100), 1100);
      expect(clayNightOperatorHue(1600), 1600);
    });

    test('night spheres: berry or jewels, never brown, green or teal', () {
      for (var h = 0; h < 3600; h += 7) {
        for (final body in [2600, 2800, 3250, 3500]) {
          for (final other in [null, 2600, 3075]) {
            final x = clayNightSphereHue(h, body, other: other);
            final why = '$h body $body other $other → $x';
            expect(clayNightSphereWarmBand.contains(x), isFalse, reason: why);
            expect(clayNightSphereJewelBand.contains(x), isFalse, reason: why);
          }
        }
      }
      // Warm hues turn berry.
      expect(clayNightSphereHue(500, 3250), 3380);
      // Green: violet and berry sit too near a plum body → cobalt.
      expect(clayNightSphereHue(1500, 3250), 2584);
      // On a midnight body: violet; berry when violet meets sphere A.
      expect(clayNightSphereHue(1500, 2600), 3051);
      expect(clayNightSphereHue(1500, 2600, other: 3100), 3351);
    });

    test('highlight alpha steps down on darker faces', () {
      const hi = 0xC8FFFFFF;
      expect(clayHighlightAlphaFor(0xFFF1EBDE, hi), 0xC8);
      expect(clayHighlightAlphaFor(oklchToArgb(0.70, 0.1, 30), hi), 150);
      expect(clayHighlightAlphaFor(oklchToArgb(0.50, 0.1, 30), hi), 110);
      expect(clayHighlightAlphaFor(oklchToArgb(0.20, 0.05, 300), hi), 70);
      expect(clayHighlightAlphaFor(0xFFFFFFFF, 0x00FFFFFF), 0);
    });

    test('drop shadows are coloured, darker and never grey', () {
      for (final face in [0xFFF1EBDE, 0xFF86DCB7, 0xFFF68293, 0xFF7C37BE]) {
        for (final g in KeyGroup.values) {
          final light = clayDropShadow(
            face,
            bodyHueTenths: 3000,
            dark: false,
            group: g,
          );
          expect(argbToOklch(light | 0xFF000000).c, greaterThan(0.035));
          expect(light >>> 24, clayShadowAlpha[g.index]);
          final night = clayDropShadow(
            face,
            bodyHueTenths: 3250,
            dark: true,
            group: g,
            baseL: 0.23,
            baseC: 0.065,
          );
          expect(argbToOklch(night | 0xFF000000).c, greaterThan(0.035));
          expect(night >>> 24, clayNightShadowAlpha[g.index]);
        }
      }
      // A mint face at night borrows the (plum) body hue: mint has no
      // chroma at L 0.14.
      final mint = clayNightShadowHue(0xFF7CE2B8, 3250, 0.14);
      expect(maxChroma(0.14, mint / 10), greaterThanOrEqualTo(0.05));
    });

    test('inner shade is darker and opaque', () {
      final shade = clayInnerShade(0xFF86DCB7, 90);
      expect(shade >>> 24, 0xFF);
      expect(lightness(shade), closeTo(lightness(0xFF86DCB7) - 0.09, 0.01));
    });

    test('scene samples: 22 colours for nine stops, else generic', () {
      final hero = heroesFor(clay).first;
      expect(claymorphismSceneSamples(hero.background), hasLength(22));
      expect(backgroundSamples(hero.background), hasLength(22));
      expect(
        claymorphismSceneSamples(
          const BackgroundSpec(
            kind: BackgroundKind.claySoft,
            colors: [0xFF101010, 0xFF202020],
          ),
        ),
        isNull,
      );
      // Display text only ever sits on the opaque panel.
      expect(displayBackdrops(hero), [hero.palette.surface | 0xFF000000]);
    });
  });

  group('guardrails', () {
    final light = gen.generate(4, clay, 3); // candy
    final night = heroesFor(clay)[2];

    List<GuardrailRule> rulesOf(ThemeSpec s) => [
      for (final v in validateTheme(s)) v.rule,
    ];

    test('the generated base themes pass', () {
      expect(validateTheme(light), isEmpty);
      expect(light.isDark, isFalse);
      expect(validateTheme(night), isEmpty);
    });

    test('a grey or off-hue drop shadow fails (clayShadowTint)', () {
      final grey = light.copyWith(
        palette: light.palette.copyWith(
          digit: light.palette.digit.copyWith(edge: 0x5C555555),
        ),
      );
      expect(rulesOf(grey), contains(GuardrailRule.clayShadowTint));
      final faint = light.copyWith(
        palette: light.palette.copyWith(
          operator: light.palette.operator.copyWith(edge: 0x20000000),
        ),
      );
      expect(rulesOf(faint), contains(GuardrailRule.clayShadowTint));
      // Repair recomputes every shadow from the faces.
      final fixed = repairTheme(grey)!;
      expect(validateTheme(fixed), isEmpty);
      expect(fixed.palette.digit.edge, light.palette.digit.edge);
    });

    test('a digit on the body fails and repair lifts it (clayKeyBody)', () {
      final body = light.palette.background;
      final bad = light.copyWith(
        palette: light.palette.copyWith(
          digit: light.palette.digit.copyWith(face: body),
        ),
      );
      expect(rulesOf(bad), contains(GuardrailRule.clayKeyBody));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        deltaEOKArgb(fixed.palette.digit.face, body),
        greaterThanOrEqualTo(0.045),
      );
      expect(lightness(fixed.palette.digit.face), greaterThan(lightness(body)));
    });

    test('a function key on the body fails and repair darkens it', () {
      final bodyL = lightness(light.palette.background);
      final f = argbToOklch(light.palette.function.face);
      final melted = oklchToArgb(bodyL - 0.01, f.c, f.h);
      final bad = light.copyWith(
        palette: light.palette.copyWith(
          function: light.palette.function.copyWith(face: melted),
        ),
      );
      expect(rulesOf(bad), contains(GuardrailRule.clayKeyBody));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        bodyL - lightness(fixed.palette.function.face),
        greaterThanOrEqualTo(0.03),
      );
    });

    test('a night key too close to the body fails', () {
      final bodyL = lightness(night.palette.background);
      final f = argbToOklch(night.palette.equals.face);
      final bad = night.copyWith(
        palette: night.palette.copyWith(
          equals: night.palette.equals.copyWith(
            face: oklchToArgb(bodyL + 0.10, f.c, f.h),
          ),
        ),
      );
      expect(rulesOf(bad), contains(GuardrailRule.clayKeyBody));
    });

    test('a faint highlight fails and repair raises it (clayHighlight)', () {
      final bad = light.copyWith(
        palette: light.palette.copyWith(highlight: 0x20FFFFFF),
      );
      final rules = rulesOf(bad);
      expect(rules, contains(GuardrailRule.clayHighlight));
      expect(rules, contains(GuardrailRule.clayStyle), reason: 'alpha range');
      // Inside the style range but too faint for the digits: repaired.
      final dim = light.copyWith(
        palette: light.palette.copyWith(highlight: 0xA0FFFFFF),
        background: light.background.copyWith(),
      );
      final digitLift = lift(light.palette.digit.face, 0xA0FFFFFF);
      if (digitLift < 0.025) {
        expect(rulesOf(dim), contains(GuardrailRule.clayHighlight));
        final fixed = repairTheme(dim)!;
        expect(validateTheme(fixed), isEmpty);
        expect(fixed.palette.highlight >>> 24, greaterThan(0xA0));
      }
      // A very light digit leaves no room for the highlight.
      final f = argbToOklch(light.palette.digit.face);
      final glare = light.copyWith(
        palette: light.palette.copyWith(
          digit: light.palette.digit.copyWith(
            face: oklchToArgb(0.99, f.c * 0.3, f.h),
          ),
        ),
      );
      expect(rulesOf(glare), contains(GuardrailRule.clayHighlight));
      final fixed = repairTheme(glare)!;
      expect(validateTheme(fixed), isEmpty);
      expect(lightness(fixed.palette.digit.face), lessThan(0.99));
    });

    test('a function label lost on its shade fails and re-solves', () {
      // A label that passes on the face but not on the darker shade.
      final fn = light.palette.function;
      final shade = clayInnerShade(fn.face, light.keyStyle.edgeShadePermille);
      final f = argbToOklch(fn.label);
      var label = fn.label;
      for (var l = f.l; l < 1; l += 0.005) {
        final c = oklchToArgb(l, f.c, f.h);
        if (contrastRatio(c, fn.face) < 4.6) break;
        label = c;
      }
      expect(contrastRatio(label, fn.face), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(label, shade), lessThan(4.5));
      final bad = light.copyWith(
        palette: light.palette.copyWith(function: fn.copyWith(label: label)),
      );
      final rules = rulesOf(bad);
      expect(rules, contains(GuardrailRule.clayLabelRing));
      expect(rules, isNot(contains(GuardrailRule.functionLabel)));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        contrastRatio(fixed.palette.function.label, shade),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('a focus ring lost on a key shadow fails and re-solves', () {
      // The lightest ring that still clears 3:1 on the bare scene, but
      // not where it crosses the keys' own drop shadows.
      final p = light.palette;
      final colors = light.background.colors;
      final bgs = backgroundSamples(light.background);
      final f = argbToOklch(p.focusRing);
      int? weak;
      for (var l = f.l; l < 0.8; l += 0.004) {
        final c = oklchToArgb(l, f.c, f.h);
        if (bgs.every((x) => contrastRatio(c, x) >= 3)) weak = c;
      }
      expect(weak, isNotNull);
      expect(
        clayFocusShadowSamples(
          p,
          colors,
        ).any((x) => contrastRatio(weak!, x) < 3),
        isTrue,
      );
      final bad = light.copyWith(palette: p.copyWith(focusRing: weak));
      final v = validateTheme(bad);
      expect(v.where((x) => x.rule == GuardrailRule.focusRing), isNotEmpty);
      expect(v.map((x) => x.detail), contains('over key shadow'));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      for (final x in clayFocusShadowSamples(fixed.palette, colors)) {
        expect(
          contrastRatio(fixed.palette.focusRing, x),
          greaterThanOrEqualTo(3),
        );
      }
    });

    test('a tray (surface darker than the body) fails (clayPanel)', () {
      final b = argbToOklch(light.palette.background);
      final tray = light.copyWith(
        palette: light.palette.copyWith(
          surface: oklchToArgb(b.l - 0.05, b.c, b.h),
        ),
      );
      final v = validateTheme(tray);
      expect(
        v.where((x) => x.rule == GuardrailRule.clayPanel).map((x) => x.detail),
        contains(startsWith('raised')),
      );
    });

    test('a translucent or melted panel fails (clayPanel)', () {
      final translucent = light.copyWith(
        palette: light.palette.copyWith(
          surface: light.palette.surface & 0x80FFFFFF,
        ),
      );
      expect(rulesOf(translucent), contains(GuardrailRule.clayPanel));
      final melted = light.copyWith(
        palette: light.palette.copyWith(surface: light.palette.background),
      );
      expect(rulesOf(melted), contains(GuardrailRule.clayPanel));
    });

    test('the renderer contract is checked (clayStyle)', () {
      final detached = light.copyWith(
        keyStyle: light.keyStyle.copyWith(
          shadowOffsetCdp: light.motion.depthCdp == 400 ? 500 : 400,
        ),
      );
      final outlined = light.copyWith(
        keyStyle: light.keyStyle.copyWith(outlineWidthCdp: 100),
      );
      final sharp = light.copyWith(
        keyStyle: light.keyStyle.copyWith(shadowBlurCdp: 200),
      );
      final shallow = light.copyWith(
        keyStyle: light.keyStyle.copyWith(edgeShadePermille: 30),
      );
      final tinted = light.copyWith(
        palette: light.palette.copyWith(highlight: 0xB4FFE0E0),
      );
      final plain = light.copyWith(
        background: const BackgroundSpec(
          kind: BackgroundKind.solid,
          colors: [0xFFD9D1E9],
        ),
      );
      for (final bad in [detached, outlined, sharp, shallow, tinted, plain]) {
        expect(rulesOf(bad), contains(GuardrailRule.clayStyle));
      }
    });

    test('other families never report clay rules', () {
      const clayRules = {
        GuardrailRule.clayShadowTint,
        GuardrailRule.clayKeyBody,
        GuardrailRule.clayHighlight,
        GuardrailRule.clayLabelRing,
        GuardrailRule.clayPanel,
        GuardrailRule.clayStyle,
      };
      for (final f in ThemeFamily.enabledFamilies) {
        if (f == clay) continue;
        for (var seed = 0; seed < 20; seed++) {
          final s = gen.generate(seed, f, 3);
          // Even with a clay-like style, the dispatch is by family.
          final styled = s.copyWith(
            keyStyle: s.keyStyle.copyWith(kind: KeyStyleKind.clay),
          );
          expect(
            rulesOf(styled).where(clayRules.contains),
            isEmpty,
            reason: '$f $seed',
          );
        }
      }
    });
  });

  test('heroes: three Claymorphism heroes, candy / tonal / night', () {
    final heroes = heroesFor(clay);
    expect(heroes, hasLength(3));
    expect(heroes.map((h) => h.heroId), [70, 71, 72]);
    expect(heroes.map((h) => h.name), [
      'Lilac Gumdrop',
      'Apricot Fondant',
      'Plum Taffy',
    ]);
    expect(heroes.where((h) => h.isDark), hasLength(1));
    expect(heroes.map(clayPanelRaised), [true, true, true]);
    // Hero 72's operator is a coral candy (h 25–45°), not Vaporwave pink.
    final op72 = argbToOklch(heroes[2].palette.operator.face);
    expect(op72.h, inInclusiveRange(25, 45));
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      expect(validateTheme(heroForAccessible(h)), isEmpty, reason: h.name);
      expect(h.keyStyle.kind, KeyStyleKind.clay);
      expect(h.keyStyle.shadowOffsetCdp, h.motion.depthCdp);
      expect(h.nonColourOperatorCue, OperatorCue.none);
      expect(h.sound, SoundPackId.pop);
      expect(h.background.kind, BackgroundKind.claySoft);
      expect(h.background.colors, hasLength(9));
      for (final k in keysOf(h.palette)) {
        expect(lift(k.face, h.palette.highlight), greaterThanOrEqualTo(0.025));
      }
    }
  });
}
