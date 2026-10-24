/// Paper & ink generator, guardrails, heroes and fixtures (spec §5.3 #11;
/// motion brief §2.3 "Paper & ink").
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_PAPER_INK_GOLDENS=1 dart test test/themes/engine/paper_ink_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/paper_ink.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily pi = ThemeFamily.paperInk;

String fixturePath(int version) =>
    'test/engine/fixtures/paper_ink_v$version.json';

/// Pinned cases (v3): one per sheet / layout situation, both locks.
const List<({int seed, bool accessible})> paperInkCases = [
  (seed: 4, accessible: false), // cream, ruled (ledger display)
  (seed: 40, accessible: false), // kraft, dot grid (cream card slips)
  (seed: 1, accessible: false), // graph paper, grid (index card)
  (seed: 6, accessible: false), // newsprint, plain
  (seed: 3, accessible: false), // indigo ink paper, plain
  (seed: 73, accessible: false), // slate-green blackboard, chalk grid
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

double _minOn(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

int _alpha(int argb) => (argb >>> 24) & 0xFF;

void main() {
  group('definition', () {
    test('enabled, shipped at v3 only, recipe tokens from the brief', () {
      expect(pi.enabled, isTrue);
      expect(familyShippedAt(pi, 1), isFalse);
      expect(familyShippedAt(pi, 2), isFalse);
      expect(familyShippedAt(pi, 3), isTrue);
      final def = pi.definition;
      expect(identical(def, paperInkDefinition), isTrue);
      expect(def.backgrounds.map((w) => w.value), [BackgroundKind.paperSheet]);
      expect(def.styles.map((w) => w.value), [KeyStyleKind.outlined]);
      expect(def.keyStyle.stateLayerPermille, 0);
      expect(def.sound, SoundPackId.typewriter);
      expect(def.nonColourOperatorCue, OperatorCue.pattern);
      expect(def.bile, BileRule.v2);
      expect(def.operatorWeightBonus.lo, greaterThanOrEqualTo(200));
      expect(def.displayFonts.single.value, FontIds.newsreader);
      expect(def.keyFonts.single.value, FontIds.newsreader);
      final m = def.motion;
      expect(m.verb, PressVerb.ink);
      expect(m.pressIn, SpringTokens.effectsFast);
      expect(m.release, SpringTokens.standardFast);
      expect(m.releaseAlt, SpringTokens.effectsSlow);
      expect(m.depthCdp, 100);
      expect(m.scalePermille, 1000);
      expect(m.entry, EntryStyle.bleed);
      expect(m.fx, PressFx.inkWash);
      expect(m.impact, ImpactStyle.soft);
      expect(m.impactPermille, 600);
      expect(m.releaseHaptic, isFalse);
      // Thinner than Neo-brutalism's 2 dp minimum outline.
      expect(paperInkOutlineWidthCdp.hi, lessThan(200));
      expect(familyMaterialWords[pi], hasLength(8));
    });
  });

  group('10,000 seeds pass the Paper & ink guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var dark = 0;
        var kraft = 0;
        var graph = 0;
        var ruled = 0;
        var grid = 0;
        var dots = 0;
        var plain = 0;
        var fullWash = 0;
        var visibleWash = 0;
        final outlines = <int>{};
        final shades = <int>{};
        final corners = <int>{};
        final displayWeights = <int>{};
        final keyWeights = <int>{};
        final releases = <int>{};
        final buckets = <int>{};
        final lightBuckets = <int>{};
        final lim = accessible
            ? GuardrailLimits.accessible
            : GuardrailLimits.standard;
        final minLabel = lim.labelRatio;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            pi,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bg = s.background;
          final bgs = paperInkSceneSamples(bg)!;
          expect(backgroundSamples(bg), bgs);
          // Labels on their faces; one ink for every outline, ≥ 3:1 on
          // every sheet sample (paper, grain, rules).
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
            if (k.edge != p.shadow) fail('seed $seed edge ${k.edge}');
            if (_minOn(k.edge, bgs) < 3) fail('seed $seed outline');
          }
          expect(_alpha(p.shadow), 0xFF);
          // Display texts on the panel with its grain and (not under the
          // lock) feint-rule composites.
          final panel = paperInkDisplayBackdrops(s, [p.surface], bgs)!;
          expect(panel, displayBackdrops(s));
          if (_minOn(p.displayText, panel) < lim.displayRatio ||
              _minOn(p.error, panel) < lim.displayRatio ||
              _minOn(p.previewText, panel) < lim.previewRatio ||
              _minOn(p.caret, panel) < lim.caretRatio) {
            fail('seed $seed display texts');
          }
          if (_minOn(p.focusRing, bgs) < lim.focusRingRatio) {
            fail('seed $seed focus ring');
          }
          // The stamp reads as solid ink on the slips; labels survive the
          // wash at its peak; the hatch shows on the operator face.
          if (contrastRatio(p.equals.face, p.digit.face) < paperStampRatio) {
            fail('seed $seed stamp');
          }
          if (paperWashLabelContrast(p, p.highlight) < minLabel) {
            fail('seed $seed wash');
          }
          if (_alpha(p.highlight) > paperWashRimMaxAlpha) {
            fail('seed $seed wash alpha');
          }
          final shade = s.keyStyle.edgeShadePermille;
          if (paperHatchContrast(p.operator, shade) < paperHatchRatio) {
            fail('seed $seed hatch');
          }
          // Tokens.
          expect(s.keyStyle.kind, KeyStyleKind.outlined);
          expect(s.keyStyle.stateLayerPermille, 0);
          expect(s.keyStyle.shadowOffsetCdp, 0);
          expect(s.keyShape.kind, KeyShapeKind.roundedRect);
          expect(s.motion.verb, PressVerb.ink);
          expect(s.motion.pressIn, SpringTokens.effectsFast);
          expect(s.motion.releaseAlt, SpringTokens.effectsSlow);
          expect(s.motion.depthCdp, 100);
          expect(s.motion.scalePermille, 1000);
          expect(s.motion.entry, EntryStyle.bleed);
          expect(s.motion.entryScalePermille, 1040);
          expect(s.motion.fx, PressFx.inkWash);
          expect(s.motion.impact, ImpactStyle.soft);
          expect(s.motion.impactPermille, 600);
          expect(s.sound, SoundPackId.typewriter);
          expect(s.nonColourOperatorCue, OperatorCue.pattern);
          expect(s.type.displayFont, FontIds.newsreader);
          expect(s.type.keyFont, FontIds.newsreader);
          if (s.type.operatorWeight < s.type.keyWeight + 200 ||
              s.type.operatorWeight > 800) {
            fail('seed $seed weights ${s.type.toJson()}');
          }
          expect(bg.kind, BackgroundKind.paperSheet);
          expect(bg.colors, hasLength(2));
          expect(bg.patternColor, 0);
          expect(bg.driftPeriodMs, 0);
          expect(bg.angleTenths, inInclusiveRange(200, 800));
          // Exactly one chromatic accent: the stamp; near-neutral ink.
          expect(p.accent, p.equals.face);
          expect(p.seedColor, p.equals.face);
          expect(argbToOklch(p.shadow).c, lessThan(0.06));

          outlines.add(s.keyStyle.outlineWidthCdp);
          shades.add(shade);
          corners.add(s.keyShape.cornerPermille);
          displayWeights.add(s.type.displayWeight);
          keyWeights.add(s.type.keyWeight);
          releases.add(s.motion.release.stiffness);
          final op = argbToOklch(p.operator.face);
          if (op.c > 0.04) buckets.add(hueBucket(op.h));
          final paper = argbToOklch(p.background);
          if (s.isDark) {
            dark++;
            // No olive or chocolate-brown washes on the dark sheets (30°–70°
            // turns wine; a few degrees of slack for gamut repair).
            if (op.c > 0.03 && op.h > 75 && op.h < 130) {
              fail('seed $seed olive wash $op');
            }
            if (op.c > 0.03 && op.h > 33 && op.h < 67) {
              fail('seed $seed brown wash $op');
            }
          } else {
            if (op.c > 0.04) lightBuckets.add(hueBucket(op.h));
            if (paper.c >= 0.045 && paper.l < 0.87) {
              kraft++;
              // Cream card slips on kraft.
              expect(argbToOklch(p.digit.face).l, greaterThan(0.9));
            }
            if (bg.pattern == BackgroundPattern.grid) graph++;
          }
          switch (bg.pattern) {
            case BackgroundPattern.stripes:
              ruled++;
            case BackgroundPattern.grid:
              grid++;
            case BackgroundPattern.dots:
              dots++;
            case BackgroundPattern.none:
              plain++;
              expect(bg.patternScaleCdp, 0);
              expect(bg.patternOpacityPermille, 0);
            case _:
              fail('seed $seed pattern ${bg.pattern}');
          }
          final wash = _alpha(p.highlight);
          if (wash == paperWashRimMaxAlpha) fullWash++;
          if (wash >= 10) visibleWash++;
        }
        expect(dark, inInclusiveRange(2050, 2400), reason: 'dark ≈ 2 in 9');
        expect(kraft, inInclusiveRange(1050, 1350), reason: 'kraft');
        expect(graph, inInclusiveRange(1600, 2000), reason: 'graph paper');
        expect(ruled, inInclusiveRange(2440, 2850), reason: 'ruled');
        expect(grid, inInclusiveRange(1760, 2130), reason: 'grids');
        expect(dots, inInclusiveRange(1520, 1880), reason: 'dot grids');
        expect(plain, inInclusiveRange(3500, 3930), reason: 'plain');
        expect(outlines, {125, 150, 175});
        expect(shades, {600, 650, 700, 750});
        expect(corners, {20, 30, 40, 50, 60});
        expect(displayWeights, {350, 400, 450});
        expect(keyWeights, {400, 450, 500});
        expect(releases, {1260, 1400, 1540});
        expect(buckets, hasLength(12), reason: 'operator washes, all hues');
        // Light sheets keep their peach and apricot washes.
        expect(lightBuckets, containsAll(<int>[1, 2]), reason: 'light washes');
        if (accessible) {
          expect(visibleWash, greaterThanOrEqualTo(9900));
        } else {
          expect(fullWash, greaterThanOrEqualTo(9800));
        }
      });
    }
  });

  test('release stays inside the brief (1400/0.9 × {0.9, 1, 1.1})', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, pi, 3).motion;
      seen.add(m.release.stiffness);
      expect(m.release.zetaPermille, 900);
      expect(m.releaseHaptic, isFalse);
    }
    expect(seen, {1260, 1400, 1540});
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, pi, 3, accessible: accessible);
          final b = other.generate(seed, pi, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, pi, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, pi, 3);
      final a1 = gen.buildCandidate(5, pi, 3, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
      expect(a1.keyStyle, a0.keyStyle);
      expect(a1.type, a0.type);
    });

    test('accessible and normal differ only where contrast demands', () {
      for (final seed in [3, 42, 73]) {
        final n = gen.generate(seed, pi, 3);
        final a = gen.generate(seed, pi, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        // The same sheet: the lock clamps, it never redraws.
        expect(a.background.pattern, n.background.pattern);
        expect(a.isDark, n.isDark);
      }
    });

    test('Paper & ink did not exist before engine v3', () {
      expect(() => gen.generate(1, pi, 1), throwsArgumentError);
      expect(() => gen.generate(1, pi, 2), throwsArgumentError);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, pi, 3);
      final code = encodeShareCode(pi.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, pi.id);
      expect(gen.generate(decoded.seed, pi, decoded.engineVersion), spec);
    });

    for (final version in [3, 4]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            pi,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': pi.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_PAPER_INK_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in paperInkCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(paperInkCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = paperInkCases[i];
          final spec = gen.generate(
            c.seed,
            pi,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], pi.id);
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
      gen.generate(s, pi, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, pi, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('scene samples', () {
    test('grain bases, then each line ink over each base', () {
      const bg = BackgroundSpec(
        kind: BackgroundKind.paperSheet,
        colors: [0xFFF6EEDD, 0xFF7898B1],
        angleTenths: 500,
        pattern: BackgroundPattern.grid,
        patternScaleCdp: 3000,
        patternOpacityPermille: 200,
      );
      final s = paperInkSceneSamples(bg)!;
      expect(s, hasLength(9));
      expect(s.first, 0xFFF6EEDD);
      // The darkest fleck: 20 % of g black.
      expect(s[1], compositeOver(withAlpha(0xFF000000, 26), 0xFFF6EEDD));
      // Grid majors at 1.6 × the minor alpha.
      expect(
        s[6],
        compositeOver(withAlpha(0xFF7898B1, paperAlpha(320)), 0xFFF6EEDD),
      );
      final plain = paperInkSceneSamples(
        bg.copyWith(pattern: BackgroundPattern.none),
      )!;
      expect(plain, hasLength(3));
      // Malformed specs never throw.
      expect(
        paperInkSceneSamples(
          const BackgroundSpec(
            kind: BackgroundKind.paperSheet,
            colors: [0xFF101010],
          ),
        ),
        hasLength(3),
      );
      expect(
        paperInkSceneSamples(
          const BackgroundSpec(kind: BackgroundKind.paperSheet, colors: []),
        ),
        isNull,
      );
    });

    test('the panel drops its feint rules under the Accessible lock', () {
      final hero = heroesFor(pi).first;
      final normal = paperPanelSamples(
        hero.palette.surface,
        hero.background,
        accessible: false,
      );
      final locked = paperPanelSamples(
        hero.palette.surface,
        hero.background,
        accessible: true,
      );
      expect(normal, hasLength(6));
      expect(locked, hasLength(3));
      expect(normal.take(3), locked);
    });
  });

  group('guardrails', () {
    final base = gen.generate(4, pi, 3);
    List<GuardrailRule> rules(ThemeSpec s) => [
      for (final v in validateTheme(s)) v.rule,
    ];

    test('the base theme is clean', () {
      expect(validateTheme(base), isEmpty);
      expect(base.isDark, isFalse);
    });

    test('a faint outline fails paperOutline and repairs to ≥ 3:1', () {
      final paper = base.palette.background;
      KeyColors faint(KeyColors k) => k.copyWith(edge: paper);
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          digit: faint(base.palette.digit),
          operator: faint(base.palette.operator),
          shadow: paper,
        ),
      );
      expect(rules(bad), contains(GuardrailRule.paperOutline));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      final bgs = backgroundSamples(fixed.background);
      for (final k in [fixed.palette.digit, fixed.palette.operator]) {
        expect(k.edge, fixed.palette.shadow);
        expect(_minOn(k.edge, bgs), greaterThanOrEqualTo(3));
      }
    });

    test('a translucent outline fails paperOutline', () {
      final ink = base.palette.shadow;
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          equals: base.palette.equals.copyWith(edge: ink & 0x80FFFFFF),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.paperOutline));
    });

    test('outline widths outside 1.25–1.75 dp fail paperOutline', () {
      for (final w in [100, 200, 225]) {
        final bad = base.copyWith(
          keyStyle: base.keyStyle.copyWith(outlineWidthCdp: w),
        );
        expect(rules(bad), contains(GuardrailRule.paperOutline), reason: '$w');
      }
    });

    test('hatch opacity outside 0.60–0.75 fails paperOperatorCue', () {
      for (final shade in [500, 800]) {
        final bad = base.copyWith(
          keyStyle: base.keyStyle.copyWith(edgeShadePermille: shade),
        );
        expect(rules(bad), contains(GuardrailRule.paperOperatorCue));
      }
    });

    test('a dishonest weight cue or a missing hatch cue fails', () {
      final light = base.copyWith(
        type: base.type.copyWith(operatorWeight: base.type.keyWeight + 100),
      );
      expect(rules(light), contains(GuardrailRule.paperOperatorCue));
      final noCue = base.copyWith(nonColourOperatorCue: OperatorCue.none);
      expect(rules(noCue), contains(GuardrailRule.paperOperatorCue));
      final weightCue = base.copyWith(nonColourOperatorCue: OperatorCue.weight);
      expect(rules(weightCue), contains(GuardrailRule.paperOperatorCue));
    });

    test('a hatch that vanishes on its face fails and repairs', () {
      // Darken the operator wash toward the ink until the hatch drops
      // under 3:1, keeping its label legible.
      final op = base.palette.operator;
      final lch = argbToOklch(op.face);
      final shade = base.keyStyle.edgeShadePermille;
      var l = lch.l;
      var face = op.face;
      while (paperHatchContrast(op.copyWith(face: face), shade) >= 2.8) {
        l -= 0.01;
        face = oklchToArgb(l, lch.c, lch.h);
      }
      final bad = base.copyWith(
        palette: base.palette.copyWith(operator: op.copyWith(face: face)),
      );
      expect(rules(bad), contains(GuardrailRule.paperOperatorCue));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        paperHatchContrast(fixed.palette.operator, shade),
        greaterThanOrEqualTo(paperHatchRatio),
      );
    });

    test('a stamp as pale as the slips fails paperStamp', () {
      final digit = base.palette.digit;
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          equals: base.palette.equals.copyWith(
            face: digit.face,
            label: digit.label,
          ),
          accent: digit.face,
        ),
      );
      expect(rules(bad), contains(GuardrailRule.paperStamp));
    });

    test('a slightly pale stamp repairs darker', () {
      // A stamp at ≈ 2.6:1 against the slips with a legible label.
      final eq = base.palette.equals;
      final lch = argbToOklch(eq.face);
      var l = lch.l;
      var face = eq.face;
      while (contrastRatio(face, base.palette.digit.face) > 2.6) {
        l += 0.01;
        face = oklchToArgb(l, lch.c, lch.h);
      }
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          equals: eq.copyWith(face: face, label: 0xFF000000),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.paperStamp));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        contrastRatio(fixed.palette.equals.face, fixed.palette.digit.face),
        greaterThanOrEqualTo(paperStampRatio),
      );
    });

    test('a heavy wash fails paperWash and repairs to ≤ 58', () {
      final bad = base.copyWith(
        palette: base.palette.copyWith(
          highlight: withAlpha(base.palette.shadow, 80),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.paperWash));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        _alpha(fixed.palette.highlight),
        lessThanOrEqualTo(paperWashRimMaxAlpha),
      );
      expect(
        paperWashLabelContrast(fixed.palette, fixed.palette.highlight),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('a wash that would sink a label is refitted lighter', () {
      final p = base.palette;
      // A digit label at the floor: any ink over the face sinks it.
      final lch = argbToOklch(p.digit.face);
      var l = lch.l;
      var face = p.digit.face;
      while (contrastRatio(p.digit.label, face) > 4.6) {
        l -= 0.005;
        face = oklchToArgb(l, lch.c, lch.h);
      }
      final palette = p.copyWith(digit: p.digit.copyWith(face: face));
      final fitted = fitPaperWash(
        palette,
        withAlpha(p.shadow, paperWashRimMaxAlpha),
        GuardrailLimits.standard,
      );
      expect(_alpha(fitted), lessThan(paperWashRimMaxAlpha));
      expect(
        paperWashLabelContrast(palette, fitted),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('other families never get paper rules; brutal stays brutal', () {
      for (final f in [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.neoBrutalism,
      ]) {
        final s = gen.generate(3, f, 3);
        final bad = s.copyWith(
          keyStyle: s.keyStyle.copyWith(outlineWidthCdp: 50),
          palette: s.palette.copyWith(highlight: 0xFF000000),
        );
        for (final r in rules(bad)) {
          expect(r.name, isNot(startsWith('paper')), reason: '$f');
        }
      }
      final nb = gen.generate(3, ThemeFamily.neoBrutalism, 3);
      expect(
        rules(nb.copyWith(keyStyle: nb.keyStyle.copyWith(outlineWidthCdp: 50))),
        contains(GuardrailRule.brutalOutline),
      );
      final badPaper = base.copyWith(
        keyStyle: base.keyStyle.copyWith(
          outlineWidthCdp: 50,
          shadowOffsetCdp: 0,
          shadowBlurCdp: 200,
        ),
      );
      for (final r in rules(badPaper)) {
        expect(r.name, isNot(startsWith('brutal')));
      }
    });
  });

  test('heroes: 110–112, light and dark, valid in both locks', () {
    final heroes = heroesFor(pi);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([110, 111, 112]));
    expect(heroes.where((h) => h.isDark), isNotEmpty);
    expect(heroes.where((h) => !h.isDark), isNotEmpty);
    expect(
      heroes.map((h) => h.name),
      containsAll(['Vermilion Ledger', 'Ultramarine Folio', 'Indigo Quill']),
    );
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      final locked = heroForAccessible(h);
      expect(validateTheme(locked), isEmpty, reason: h.name);
      expect(h.keyStyle.kind, KeyStyleKind.outlined);
      expect(h.nonColourOperatorCue, OperatorCue.pattern);
      expect(h.sound, SoundPackId.typewriter);
      expect(h.motion.verb, PressVerb.ink);
      expect(h.background.kind, BackgroundKind.paperSheet);
      expect(h.background.patternColor, 0);
      for (final k in [
        h.palette.digit,
        h.palette.operator,
        h.palette.equals,
        h.palette.function,
      ]) {
        expect(k.edge, h.palette.shadow, reason: h.name);
      }
      expect(h.palette.accent, h.palette.equals.face);
    }
  });
}
