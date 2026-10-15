/// Bauhaus generator, guardrails, heroes and fixtures (family id 15,
/// ships additively at engine v3).
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_BAUHAUS_GOLDENS=1 dart test test/themes/engine/bauhaus_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:calsee_themes/engine/bauhaus.dart';
import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
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

const ThemeFamily bh = ThemeFamily.bauhaus;

String fixturePath(int version) =>
    'test/engine/fixtures/bauhaus_v$version.json';

/// Pinned cases (v3): the usual seeds, both locks, plus the first seed of
/// each variant × composition the sweep found (seed: variant/composition).
const List<({int seed, bool accessible})> bauhausCases = [
  (seed: 0, accessible: false), // ochre / triangle `=`
  (seed: 3, accessible: false), // ochre / fan
  (seed: 9, accessible: false), // paper / fan
  (seed: 21, accessible: false), // grid / triangle
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
  (seed: 1, accessible: false), // night / disc `=`
  (seed: 2, accessible: false), // negative / fan
  (seed: 4, accessible: false), // grid / disc `=`
  (seed: 5, accessible: false), // paper / disc `=`
  (seed: 24, accessible: false), // paper / disc digits
  (seed: 50, accessible: false), // night / disc digits
  (seed: 93, accessible: true), // negative / disc digits, accessible
];

/// Lowest relative luminance of the Accessible lock's dead band edges: no
/// neutral face lies at L 0.464–0.669 (no 7:1 label exists there).
bool inDeadBand(int argb) {
  final l = argbToOklch(argb).l;
  return l > 0.464 && l < 0.669;
}

void main() {
  group('10,000 seeds pass the Bauhaus guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        final variants = <BauhausVariant, int>{};
        final compositions = <BauhausComposition, int>{};
        final operators = <BauhausPrimary, int>{};
        final buckets = <int>{};
        final orientations = <int>{};
        final corners = <int>{};
        var accentOn = 0;
        var minOpDigit = 99.0;
        var minKeyOnGround = 99.0;
        var minYellowKeyCvd = 99.0;
        final ochreHues = <int>{};
        var maxAccessibleRedHue = 0.0;
        var yellowHueMax = 0.0;
        final minLabel = accessible ? 7.0 : 4.5;
        final lim = accessible
            ? GuardrailLimits.accessible
            : GuardrailLimits.standard;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            bh,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bgs = backgroundSamples(s.background);
          // The scene's samples: the ground, plus the grid field.
          expect(bgs.length, inInclusiveRange(1, 2), reason: 'seed $seed');
          expect(bgs.first, p.background | 0xFF000000);
          // Labels on their opaque faces (the pressed core swaps the same
          // pair, so its ratio is identical).
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            expect(k.face >>> 24, 0xFF);
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
          }
          // The sheet is the only display backdrop.
          expect(displayBackdrops(s), [p.surface | 0xFF000000]);
          if (contrastRatio(p.displayText, p.surface) < lim.displayRatio) {
            fail('seed $seed display');
          }
          if (contrastRatio(p.error, p.surface) < lim.displayRatio) {
            fail('seed $seed error');
          }
          if (contrastRatio(p.previewText, p.surface) < ratioText) {
            fail('seed $seed preview');
          }
          // Focus ring (and the toolbar icons, which use it) on the ground
          // and the field.
          for (final b in bgs) {
            if (contrastRatio(p.focusRing, b) < 3) fail('seed $seed ring');
          }
          // The rule on the sheet; the corner disc distinct from it.
          expect(contrastRatio(p.shadow, p.surface), greaterThanOrEqualTo(3));
          expect(
            minCvdDeltaE(p.highlight, p.surface),
            greaterThanOrEqualTo(bauhausDisplayAccentDeltaE),
          );
          // Shape cue, recorded and real.
          expect(s.nonColourOperatorCue, OperatorCue.shape);
          final shape = s.keyShape;
          expect(shape.operatorKind, isNot(shape.kind));
          final comp = bauhausCompositionOf(shape);
          if (comp == null) fail('seed $seed composition $shape');
          compositions[comp] = (compositions[comp] ?? 0) + 1;
          corners.add(shape.cornerPermille);
          // Flat, opaque, no outline, no shadow, no tint layer.
          expect(s.keyStyle.kind, KeyStyleKind.flat);
          expect(s.keyStyle.stateLayerPermille, 0);
          expect(s.keyStyle.outlineWidthCdp, 0);
          expect(s.keyStyle.shadowOffsetCdp, 0);
          expect(s.keyStyle.shadowBlurCdp, 0);
          expect(s.keyStyle.opacityPermille, 1000);
          // Motion, type and sound per the design.
          expect(s.motion.pressIn, SpringTokens.hardPress);
          expect(s.motion.verb, PressVerb.invert);
          expect(s.motion.scalePermille, 960);
          expect(s.motion.depthCdp, 0);
          expect(s.motion.entry, EntryStyle.pop);
          expect(s.motion.entryScalePermille, 900);
          expect(s.motion.entrySpring, SpringTokens.effectsDefault);
          expect(s.motion.impact, ImpactStyle.rigid);
          expect(s.sound, SoundPackId.wood);
          expect(s.type.displayFont, FontIds.jost);
          expect(s.type.keyFont, FontIds.jost);
          expect(s.type.operatorWeight, greaterThan(s.type.keyWeight));
          // The scene: six colours, static, a quarter-turn orientation,
          // every shape colour distinct from the ground.
          final bg = s.background;
          expect(bg.kind, BackgroundKind.bauhausComposition);
          expect(bg.colors, hasLength(6));
          expect(bg.driftPeriodMs, 0);
          expect(bg.pattern, BackgroundPattern.none);
          orientations.add(bg.angleTenths);
          for (var i = 2; i < 6; i++) {
            if (deltaEOKArgb(bg.colors[i], bg.colors[0]) < 0.10) {
              fail('seed $seed scene colour $i');
            }
          }
          // Primaries: operator and `=` two different ones; neutral digits.
          final op = bauhausPrimaryOf(p.operator.face)!;
          final eq = bauhausPrimaryOf(p.equals.face)!;
          expect(op, isNot(eq));
          operators[op] = (operators[op] ?? 0) + 1;
          buckets.add(hueBucket(argbToOklch(p.operator.face).h));
          expect(argbToOklch(p.digit.face).c, lessThan(0.03));
          // The shape cue does the separating; colours stay apart anyway.
          for (final k in [p.operator.face, p.equals.face]) {
            final d = minCvdDeltaE(k, p.digit.face);
            if (d < minOpDigit) minOpDigit = d;
          }
          // Accessible: neutral faces stay out of the dead band.
          if (accessible) {
            for (final k in [p.digit.face, p.function.face]) {
              if (argbToOklch(k).c < 0.04 && inDeadBand(k)) {
                fail('seed $seed dead band ${k.toRadixString(16)}');
              }
            }
          }
          final variant = bauhausVariantOf(s);
          variants[variant] = (variants[variant] ?? 0) + 1;
          // Operator and `=` silhouettes stand off what they sit on by
          // lightness too, not by hue alone (yellow discs on parchment).
          final under = bgs.last;
          for (final (k, primary) in [
            (p.operator.face, op),
            (p.equals.face, eq),
          ]) {
            final cr = contrastRatio(k, under);
            if (cr < minKeyOnGround) minKeyOnGround = cr;
            if (primary == BauhausPrimary.yellow) {
              final h = argbToOklch(k).h;
              if (h > yellowHueMax) yellowHueMax = h;
              if (variant == BauhausVariant.paper) {
                final d = minCvdDeltaE(k, under);
                if (d < minYellowKeyCvd) minYellowKeyCvd = d;
              }
            }
          }
          if (variant == BauhausVariant.ochre) {
            ochreHues.add(argbToOklch(p.background).h.round());
          }
          // Grid: the function blocks' corner is the `=` primary.
          if (variant == BauhausVariant.grid && (p.function.edge >>> 24) != 0) {
            expect(bauhausPrimaryOf(p.function.edge), eq, reason: 'seed $seed');
          }
          // The Accessible lock's darker red is crimson, not brick.
          if (accessible) {
            for (final (k, primary) in [
              (p.operator.face, op),
              (p.equals.face, eq),
            ]) {
              if (primary != BauhausPrimary.red) continue;
              final h = argbToOklch(k).h;
              if (h > maxAccessibleRedHue) maxAccessibleRedHue = h;
            }
          }
          if ((p.function.edge >>> 24) != 0) accentOn++;
        }
        int n(BauhausVariant v) => variants[v] ?? 0;
        int c(BauhausComposition v) => compositions[v] ?? 0;
        int o(BauhausPrimary v) => operators[v] ?? 0;
        // Brightness 1 : 4; light [paper, grid, ochre] 5 : 4 : 2, dark
        // [night, negative] 2 : 3 (±10 % of the expectation).
        expect(
          n(BauhausVariant.night) + n(BauhausVariant.negative),
          inInclusiveRange(1800, 2200),
          reason: 'dark ≈ 1 in 5',
        );
        expect(n(BauhausVariant.paper), inInclusiveRange(3270, 4000));
        expect(n(BauhausVariant.grid), inInclusiveRange(2620, 3200));
        expect(n(BauhausVariant.ochre), inInclusiveRange(1310, 1600));
        expect(n(BauhausVariant.night), inInclusiveRange(720, 880));
        expect(n(BauhausVariant.negative), inInclusiveRange(1080, 1320));
        // Digits: blocks 7 : discs 1; `=` next to blocks disc 4 : fan 2 :
        // triangle 2.
        expect(c(BauhausComposition.blockDisc), inInclusiveRange(3940, 4810));
        expect(c(BauhausComposition.blockFan), inInclusiveRange(1970, 2400));
        expect(
          c(BauhausComposition.blockTriangle),
          inInclusiveRange(1970, 2400),
        );
        expect(c(BauhausComposition.discBlock), inInclusiveRange(1125, 1375));
        // Operators: blue ≈ 5,115, red ≈ 3,127, yellow ≈ 1,758.
        expect(o(BauhausPrimary.blue), inInclusiveRange(4600, 5630));
        expect(o(BauhausPrimary.red), inInclusiveRange(2810, 3440));
        expect(o(BauhausPrimary.yellow), inInclusiveRange(1580, 1930));
        expect(buckets, {1, 3, 9}, reason: 'red, yellow, ultramarine');
        expect(orientations, {0, 900, 1800, 2700});
        expect(corners, {0, 10, 20, 30, 40});
        expect(accentOn, inInclusiveRange(6000, 7330), reason: '2 in 3');
        expect(minOpDigit, greaterThanOrEqualTo(0.040));
        expect(minKeyOnGround, greaterThanOrEqualTo(bauhausKeyVisibility));
        // Yellow discs on parchment: warm (≤ 92° plus repair drift) and
        // visible under every simulated colour-vision deficiency.
        expect(yellowHueMax, lessThan(93));
        expect(minYellowKeyCvd, greaterThanOrEqualTo(0.06));
        // Ochre stock stays the tan between apricot and mustard (72–80°
        // drawn; 8-bit rounding moves it by under a degree).
        expect(ochreHues.reduce(math.min), greaterThanOrEqualTo(71));
        expect(ochreHues.reduce(math.max), lessThanOrEqualTo(81));

        if (accessible) expect(maxAccessibleRedHue, lessThan(29));
      });
    }
  });

  test('release stays inside the design (1600/1.0 × {0.9, 1, 1.1})', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, bh, 3).motion;
      seen.add(m.release.stiffness);
      expect(m.release.zetaPermille, 1000);
      expect(m.releaseHaptic, isFalse);
    }
    expect(seen, {1440, 1600, 1760});
  });

  group('definition', () {
    test('enabled, shipped at v3 only, recipe tokens', () {
      expect(bh.enabled, isTrue);
      expect(familyShippedAt(bh, 1), isFalse);
      expect(familyShippedAt(bh, 2), isFalse);
      expect(familyShippedAt(bh, 3), isTrue);
      final def = bh.definition;
      expect(identical(def, bauhausDefinition), isTrue);
      expect(def.keyStyle.kind, KeyStyleKind.flat);
      expect(def.sound, SoundPackId.wood);
      expect(def.nonColourOperatorCue, OperatorCue.shape);
      expect(def.backgrounds.single.value, BackgroundKind.bauhausComposition);
      expect(def.motion.verb, PressVerb.invert);
      expect(def.motion.release, SpringTokens.effectsDefault);
      // The neutral faces avoid the dead band by construction.
      expect(def.light.digit.lMilli.lo, greaterThanOrEqualTo(669));
      expect(def.dark.digit.lMilli.hi, lessThanOrEqualTo(464));
    });
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, bh, 3, accessible: accessible);
          final b = other.generate(seed, bh, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, bh, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, bh, 3);
      final a1 = gen.buildCandidate(5, bh, 3, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
    });

    test('accessible and normal differ only in colours', () {
      for (var seed = 0; seed < 40; seed++) {
        final n = gen.generate(seed, bh, 3);
        final a = gen.generate(seed, bh, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        expect(a.background.angleTenths, n.background.angleTenths);
        expect(bauhausVariantOf(a), bauhausVariantOf(n));
      }
    });

    test('Bauhaus did not exist before engine v3', () {
      expect(() => gen.generate(1, bh, 1), throwsArgumentError);
      expect(() => gen.generate(1, bh, 2), throwsArgumentError);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, bh, 3);
      final code = encodeShareCode(bh.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, bh.id);
      expect(gen.generate(decoded.seed, bh, decoded.engineVersion), spec);
    });

    for (final version in [3]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            bh,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': bh.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_BAUHAUS_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in bauhausCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(bauhausCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = bauhausCases[i];
          final spec = gen.generate(
            c.seed,
            bh,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], bh.id);
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
      gen.generate(s, bh, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, bh, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('guardrails', () {
    // Seed 9: paper, blue disc operators, a red fan `=`, accent on.
    final base = gen.generate(9, bh, 3);
    Iterable<GuardrailRule> rules(ThemeSpec s) =>
        validateTheme(s).map((v) => v.rule);

    test('the pinned base passes', () {
      expect(validateTheme(base), isEmpty);
      expect(bauhausCompositionOf(base.keyShape), BauhausComposition.blockFan);
    });

    test('a dishonest shape cue fails bauhausOperatorCue', () {
      final shape = base.keyShape;
      for (final bad in [
        base.copyWith(nonColourOperatorCue: OperatorCue.none),
        // Operators the same silhouette as the digits.
        base.copyWith(
          keyShape: shape.copyWith(operatorKind: KeyShapeKind.roundedRect),
        ),
        // A digit silhouette Bauhaus never draws.
        base.copyWith(keyShape: shape.copyWith(kind: KeyShapeKind.squircle)),
        // A disc `=` beside disc digits.
        base.copyWith(
          keyShape: shape.copyWith(
            kind: KeyShapeKind.circle,
            operatorKind: KeyShapeKind.roundedRect,
            operatorM3eShape: M3eShape.circle,
          ),
        ),
        // An `=` figure the renderer has no primitive for.
        base.copyWith(
          keyShape: shape.copyWith(operatorM3eShape: M3eShape.clover4Leaf),
        ),
        // Blocks rounded towards pills.
        base.copyWith(keyShape: shape.copyWith(cornerPermille: 120)),
        // The retired half-disc `=`.
        base.copyWith(
          keyShape: shape.copyWith(operatorM3eShape: M3eShape.semiCircle),
        ),
      ]) {
        expect(rules(bad), contains(GuardrailRule.bauhausOperatorCue));
      }
    });

    test('non-primaries fail bauhausPrimaries', () {
      final p = base.palette;
      final grey = argbToOklch(p.operator.face);
      final greyOp = oklchToArgb(grey.l, 0.02, grey.h) | 0xFF000000;
      final greenEq = oklchToArgb(0.55, 0.15, 145) | 0xFF000000;
      final tintedDigit = oklchToArgb(0.97, 0.06, 90) | 0xFF000000;
      for (final bad in [
        base.copyWith(
          palette: p.copyWith(operator: p.operator.copyWith(face: greyOp)),
        ),
        base.copyWith(
          palette: p.copyWith(equals: p.equals.copyWith(face: greenEq)),
        ),
        // Operator and `=` the same primary.
        base.copyWith(
          palette: p.copyWith(equals: p.equals.copyWith(face: p.operator.face)),
        ),
        base.copyWith(
          palette: p.copyWith(digit: p.digit.copyWith(face: tintedDigit)),
        ),
        // A translucent, or a faint, function accent.
        base.copyWith(
          palette: p.copyWith(function: p.function.copyWith(edge: 0x80FBCB21)),
        ),
        base.copyWith(
          palette: p.copyWith(
            function: p.function.copyWith(edge: p.function.face),
          ),
        ),
      ]) {
        expect(rules(bad), contains(GuardrailRule.bauhausPrimaries));
      }
    });

    test('a broken scene fails bauhausScene', () {
      final bg = base.background;
      final ground = bg.colors[0];
      for (final bad in [
        base.copyWith(background: bg.copyWith(kind: BackgroundKind.solid)),
        base.copyWith(
          background: bg.copyWith(colors: List.unmodifiable(bg.colors.take(5))),
        ),
        base.copyWith(background: bg.copyWith(driftPeriodMs: 40000)),
        base.copyWith(background: bg.copyWith(pattern: BackgroundPattern.dots)),
        base.copyWith(background: bg.copyWith(angleTenths: 450)),
        // A light keypad field.
        base.copyWith(
          background: bg.copyWith(
            colors: List.unmodifiable([
              ground,
              0xFFB0A898,
              ...bg.colors.skip(2),
            ]),
          ),
        ),
        // A scene shape in the ground colour.
        base.copyWith(
          background: bg.copyWith(
            colors: List.unmodifiable([...bg.colors.take(4), ground, ground]),
          ),
        ),
        // Digit blocks that vanish into the ground.
        base.copyWith(
          palette: base.palette.copyWith(
            digit: base.palette.digit.copyWith(face: ground),
          ),
        ),
        // Operator discs only a hue away from the ground (a pale yellow on
        // parchment).
        base.copyWith(
          palette: base.palette.copyWith(
            operator: base.palette.operator.copyWith(
              face:
                  oklchToArgb(argbToOklch(ground).l - 0.01, 0.17, 90) |
                  0xFF000000,
            ),
          ),
        ),
      ]) {
        expect(rules(bad), contains(GuardrailRule.bauhausScene));
      }
    });

    test('a faint rule or corner disc fails bauhausPanel and repairs', () {
      final p = base.palette;
      final bad = base.copyWith(
        palette: p.copyWith(shadow: p.surface, highlight: p.surface),
      );
      expect(rules(bad), contains(GuardrailRule.bauhausPanel));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        contrastRatio(fixed.palette.shadow, fixed.palette.surface),
        greaterThanOrEqualTo(3),
      );
      // The corner disc follows the `=` face again.
      expect(fixed.palette.highlight, fixed.palette.equals.face);
      final translucent = base.copyWith(
        palette: p.copyWith(highlight: p.highlight & 0x80FFFFFF),
      );
      expect(rules(translucent), contains(GuardrailRule.bauhausPanel));
    });

    test('the corner disc falls back when the `=` blends into the sheet', () {
      const sheet = 0xFFFDFBF6;
      // A pale yellow `=` on a white sheet: the operator, else the rule.
      expect(
        bauhausDisplayAccent(0xFFFFF4C0, 0xFF264BA4, 0xFF131311, sheet),
        0xFF264BA4,
      );
      expect(
        bauhausDisplayAccent(0xFFFFF4C0, 0xFFFFF4C0, 0xFF131311, sheet),
        0xFF131311,
      );
    });

    test('other families are not checked by the Bauhaus rules', () {
      const bauhausRules = {
        GuardrailRule.bauhausOperatorCue,
        GuardrailRule.bauhausPrimaries,
        GuardrailRule.bauhausScene,
        GuardrailRule.bauhausPanel,
      };
      for (final f in [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.neoBrutalism,
      ]) {
        final s = gen.generate(3, f, 3);
        expect(rules(s).where(bauhausRules.contains), isEmpty);
      }
    });
  });

  test('heroes: three Bauhaus heroes, paper / grid / night', () {
    final heroes = heroesFor(bh);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([150, 151, 152]));
    expect(heroes.map((h) => h.name), [
      'Weimar Primer',
      'Dessau Grid',
      'Night Workshop',
    ]);
    expect(heroes.where((h) => h.isDark), isNotEmpty);
    expect(heroes.where((h) => !h.isDark), isNotEmpty);
    expect(heroes.map(bauhausVariantOf), [
      BauhausVariant.paper,
      BauhausVariant.grid,
      BauhausVariant.night,
    ]);
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      final a = heroForAccessible(h);
      expect(validateTheme(a), isEmpty, reason: h.name);
      // The Accessible lock keeps the primaries primaries.
      expect(bauhausPrimaryOf(a.palette.operator.face), isNotNull);
      expect(bauhausPrimaryOf(a.palette.equals.face), isNotNull);
      expect(h.keyStyle.kind, KeyStyleKind.flat);
      expect(h.sound, SoundPackId.wood);
      expect(h.nonColourOperatorCue, OperatorCue.shape);
      expect(bauhausCompositionOf(h.keyShape), isNotNull);
      expect(h.motion.verb, PressVerb.invert);
    }
  });

  test('variants and compositions derive back from a spec', () {
    // Disc digits take Kandinsky's set: block operators, a triangle `=`.
    expect(
      bauhausCompositionOf(
        const KeyShapeSpec(
          kind: KeyShapeKind.circle,
          operatorKind: KeyShapeKind.roundedRect,
          operatorM3eShape: M3eShape.triangle,
        ),
      ),
      BauhausComposition.discBlock,
    );
    expect(
      bauhausCompositionOf(
        const KeyShapeSpec(
          kind: KeyShapeKind.circle,
          operatorKind: KeyShapeKind.roundedRect,
          operatorM3eShape: M3eShape.semiCircle,
        ),
      ),
      isNull,
      reason: 'the half-disc is retired',
    );
    expect(
      bauhausCompositionOf(const KeyShapeSpec(kind: KeyShapeKind.squircle)),
      isNull,
    );
  });
}
