/// Y2K / Frutiger Aero generator, guardrails, heroes and fixtures (spec
/// §5.3 #10; motion brief §2.3 "Y2K / chrome").
///
/// The golden JSON fixture is written only on request:
///
///     UPDATE_Y2K_AERO_GOLDENS=1 dart test test/themes/engine/y2k_aero_test.dart
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
import 'package:calsee_themes/engine/names.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

const ThemeFamily y2k = ThemeFamily.y2kChrome;

String fixturePath(int version) =>
    'test/engine/fixtures/y2k_aero_v$version.json';

/// Pinned cases (v3): a meadow, black and pastel foil, an open sky, deep
/// water, and both locks.
const List<({int seed, bool accessible})> y2kCases = [
  (seed: 0, accessible: false),
  (seed: 1, accessible: false),
  (seed: 3, accessible: false),
  (seed: 5, accessible: false),
  (seed: 10, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

double _min(int fg, List<int> backdrops) {
  var m = double.infinity;
  for (final b in backdrops) {
    final r = contrastRatio(compositeOver(fg, b), b);
    if (r < m) m = r;
  }
  return m;
}

double _minDeltaE(int face, List<int> samples) {
  var m = double.infinity;
  for (final s in samples) {
    final d = deltaEOKArgb(face, s);
    if (d < m) m = d;
  }
  return m;
}

/// Index of the CHROME candy whose hue range holds [hueDeg] (−1: none).
int _candyOf(double hueDeg) {
  final t = (hueDeg * 10).round();
  for (var i = 0; i < y2kChromeCandies.length; i++) {
    final r = y2kChromeCandies[i].hue;
    if ((t >= r.lo && t <= r.hi) || (t + 3600 >= r.lo && t + 3600 <= r.hi)) {
      return i;
    }
  }
  return -1;
}

void main() {
  group('10,000 seeds pass the Y2K / Frutiger Aero guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        final scenes = <Y2kScene, int>{};
        var pills = 0;
        final outlines = <int>{};
        final offsets = <int>{};
        final blurs = <int>{};
        final highlights = <int>{};
        final opBuckets = <int>{};
        var paleEquals = 0;
        final minLabel = accessible ? 7.0 : 4.5;
        final faceFloor = accessible ? 0.755 : 0.735;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            y2k,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          final bg = s.background;
          final chrome = bg.kind == BackgroundKind.chromeHolo;
          final scene = y2kSceneOf(bg, dark: s.isDark);
          scenes.update(scene, (n) => n + 1, ifAbsent: () => 1);
          final accent = y2kAccentHueTenths(p);
          final bgs = backgroundSamples(bg);
          final edges = y2kEdgeSamples(bgs, p.shadow);
          // Labels: dark, on every colour of their label zone.
          for (final (k, metal) in [
            (p.digit, chrome),
            (p.function, chrome),
            (p.operator, false),
            (p.equals, false),
          ]) {
            final zone = y2kLabelZoneSamples(
              k.face,
              accentHueTenths: accent,
              depthPermille: s.keyStyle.edgeShadePermille,
              refractionPermille: s.keyStyle.refractionPermille,
              metal: metal,
              accessible: accessible,
            );
            if (_min(k.label, zone) < minLabel) fail('seed $seed label $k');
            final y = luminanceArgb(k.label);
            expect(y, lessThan(luminanceArgb(k.face)), reason: 'seed $seed');
            expect(
              y,
              lessThan(luminanceArgb(y2kPressedFace(k.face, accent))),
              reason: 'seed $seed',
            );
            expect(k.face >>> 24, 0xFF);
            if (argbToOklab(k.face).$1 < faceFloor) fail('seed $seed face');
            // Accessible: rims ≥ 3:1 on the scene and the keys' shadow.
            if (accessible && _min(k.edge, edges) < 3) {
              fail('seed $seed rim ${k.edge}');
            }
          }
          // The focus ring on the scene and the keys' shadow; display
          // texts on the panel and its gloss.
          if (_min(p.focusRing, edges) < 3) fail('seed $seed ring');
          final panel = y2kPanelSamples(p.surface, chrome: chrome);
          expect(displayBackdrops(s), panel);
          if (_min(p.displayText, panel) < minLabel) fail('seed $seed text');
          if (_min(p.error, panel) < minLabel) fail('seed $seed error');
          if (_min(p.previewText, panel) < (accessible ? 4.5 : 4.5)) {
            fail('seed $seed preview');
          }
          if (_min(p.caret, panel) < (accessible ? 4.5 : 3)) {
            fail('seed $seed caret');
          }
          // Operators and `=` stand apart from digits beyond the weight
          // cue (Bold Text caps the weights).
          for (final k in [p.operator, p.equals]) {
            final apart =
                contrastRatio(k.face, p.digit.face) >= 1.2 ||
                minCvdDeltaE(k.face, p.digit.face) >= 0.06;
            if (!apart) fail('seed $seed accent ≈ digit');
          }
          // AERO light: keys stand apart from the ground behind the keypad;
          // the Material chrome sits on the pale horizon haze (the azure
          // zenith fails text contrast in settings and history).
          if (scene == Y2kScene.sky || scene == Y2kScene.meadow) {
            if (argbToOklab(p.background).$1 < 0.90) {
              fail('seed $seed chrome background ${p.background}');
            }
            expect(p.background, bg.colors[2]);
            final ground = y2kGroundSamples(bg);
            final faces = [
              p.digit.face,
              p.function.face,
              if (scene == Y2kScene.meadow) ...[p.operator.face, p.equals.face],
            ];
            for (final f in faces) {
              if (_minDeltaE(f, ground) < 0.08) fail('seed $seed ground');
            }
          }
          // Sunlit green grass, never jade or mint (the hills draw fully
          // below 165°).
          if (scene == Y2kScene.meadow) {
            final crest = argbToOklch(bg.colors[3]);
            if (crest.h > 155 || crest.h < 110 || crest.l > 0.78) {
              fail('seed $seed grass $crest');
            }
          }
          // Black foil in jewel tones, never amber or olive (they clamp to
          // brown and khaki).
          if (scene == Y2kScene.blackHolo) {
            for (var i = 1; i < 5; i++) {
              final h = argbToOklch(bg.colors[i]).h;
              if (h > 45 && h < 130) fail('seed $seed muddy foil $i: $h');
            }
          }
          // Deep water: blue-lavender moonstone digits, a blue abyss.
          if (scene == Y2kScene.water) {
            final d = argbToOklch(p.digit.face);
            if (d.c < 0.05) fail('seed $seed dishwater digit $d');
            if (argbToOklab(bg.colors[2]).$1 < 0.21) {
              fail('seed $seed black abyss');
            }
            expect(p.background, bg.colors[1]);
          }
          // CHROME never pairs warm pink with cool aqua (Vaporwave's).
          if (chrome) {
            final a = _candyOf(argbToOklch(p.operator.face).h);
            final b = _candyOf(argbToOklch(p.equals.face).h);
            if (a >= 0 && b >= 0 && y2kVaporPair(a, b)) {
              fail('seed $seed vapor pair $a/$b');
            }
          }
          // The renderer contract.
          expect(s.keyStyle.kind, KeyStyleKind.glass);
          expect(s.keyStyle.stateLayerPermille, 0);
          expect(s.keyStyle.opacityPermille, 1000);
          expect(p.highlight, 0xFFFFFFFF);
          expect(bg.colors, hasLength(6));
          expect(() => bg.colors[0] = 0, throwsUnsupportedError);
          expect(bg.pattern, BackgroundPattern.dots);
          expect(bg.driftPeriodMs, chrome ? y2kChromeDriftMs : y2kAeroDriftMs);
          expect(s.type.slashedZero, chrome);
          outlines.add(s.keyStyle.outlineWidthCdp);
          offsets.add(s.keyStyle.shadowOffsetCdp);
          blurs.add(s.keyStyle.shadowBlurCdp);
          highlights.add(s.keyStyle.highlightPermille);
          if (s.keyShape.kind == KeyShapeKind.pill) pills++;
          // Non-colour operator cue: a heavier label, recorded.
          expect(s.nonColourOperatorCue, OperatorCue.weight);
          if (s.type.operatorWeight < s.type.keyWeight + 200) {
            fail('seed $seed weights ${s.type.toJson()}');
          }
          expect(s.type.operatorWeight, lessThanOrEqualTo(800));
          // Saturated gel operators in every hue bucket (blue gels lifted
          // clear of moonstone digits in deep water are paler: sRGB blues
          // lose chroma fast above L 0.8).
          final op = argbToOklch(p.operator.face);
          final minC = scene == Y2kScene.water ? 0.06 : 0.085;
          if (op.c < minC) fail('seed $seed operator not saturated $op');
          opBuckets.add(hueBucket(op.h));
          if (argbToOklch(p.equals.face).c < y2kGelMinChroma) paleEquals++;
          // Motion per brief.
          expect(s.motion.pressIn, SpringTokens.effectsFast);
          expect(s.motion.verb, PressVerb.gloss);
          expect(s.motion.fx, PressFx.sheen);
          expect(s.motion.scalePermille, 960);
          expect(s.motion.entry, EntryStyle.pop);
          expect(s.motion.entryScalePermille, 800);
          expect(s.motion.entrySpring, SpringTokens.expressiveFast);
          expect(s.motion.impact, ImpactStyle.rigid);
          expect(s.motion.impactPermille, 700);
          expect(s.sound, SoundPackId.glass);
        }
        final dark =
            (scenes[Y2kScene.water] ?? 0) + (scenes[Y2kScene.blackHolo] ?? 0);
        final holo =
            (scenes[Y2kScene.pastelHolo] ?? 0) +
            (scenes[Y2kScene.blackHolo] ?? 0);
        expect(dark, inInclusiveRange(1700, 2300), reason: 'dark ≈ 1 in 5');
        expect(holo, inInclusiveRange(3700, 4300), reason: 'CHROME 2 in 5');
        expect(scenes[Y2kScene.meadow], inInclusiveRange(1650, 2200));
        expect(scenes[Y2kScene.water], inInclusiveRange(1000, 1400));
        expect(scenes[Y2kScene.blackHolo], inInclusiveRange(650, 950));
        expect(pills, inInclusiveRange(4300, 4900), reason: '$pills pills');
        expect(outlines, {100, 125, 150, 250, 300, 350});
        expect(offsets, {200, 250, 300});
        expect(blurs, {500, 600, 700, 800});
        expect(highlights.length, greaterThanOrEqualTo(10));
        for (final h in highlights) {
          expect(h, inInclusiveRange(700, 900));
          expect(h % 20, 0);
        }
        expect(opBuckets, hasLength(12));
        expect(paleEquals, lessThan(250), reason: 'pale `=` is a last resort');
      });
    }
  });

  test('release stays inside the brief (439/0.75 × {0.9, 1, 1.1})', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, y2k, 3).motion;
      seen.add(m.release.stiffness);
      expect(m.release.zetaPermille, inInclusiveRange(700, 800));
      expect(m.releaseHaptic, isFalse);
    }
    expect(seen, {395, 439, 482});
  });

  group('determinism', () {
    test('same inputs → identical JSON and hash', () {
      // A distinct, non-canonicalised instance on purpose.
      // ignore: prefer_const_constructors
      final other = ThemeGenerator();
      for (var i = 0; i < 300; i++) {
        final seed = (i * 2654435761) & 0xFFFFFFFF;
        for (final accessible in [false, true]) {
          final a = gen.generate(seed, y2k, 3, accessible: accessible);
          final b = other.generate(seed, y2k, 3, accessible: accessible);
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, y2k, 3);
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts change the palette (and scene colours) only', () {
      for (final seed in [5, 6, 10]) {
        final a0 = gen.buildCandidate(seed, y2k, 3);
        final a1 = gen.buildCandidate(seed, y2k, 3, attempt: 1);
        expect(a1.palette, isNot(a0.palette));
        expect(a1.motion, a0.motion);
        expect(a1.keyShape, a0.keyShape);
        expect(a1.keyStyle, a0.keyStyle);
        expect(a1.type, a0.type);
        // The variant comes from the background stream: a retry keeps it
        // (its brightness, a palette draw, may change sky ↔ water).
        expect(a1.background.kind, a0.background.kind);
        expect(a1.background.angleTenths, a0.background.angleTenths);
      }
    });

    test('accessible and normal differ only where contrast demands', () {
      for (final seed in [42, 43, 44]) {
        final n = gen.generate(seed, y2k, 3);
        final a = gen.generate(seed, y2k, 3, accessible: true);
        expect(a.keyShape, n.keyShape);
        expect(a.keyStyle, n.keyStyle);
        expect(a.motion, n.motion);
        expect(a.type, n.type);
        expect(a.background.kind, n.background.kind);
      }
    });

    test('Y2K / Frutiger Aero shipped at engine v3 only', () {
      expect(() => gen.generate(1, y2k, 1), throwsArgumentError);
      expect(() => gen.generate(1, y2k, 2), throwsArgumentError);
      expect(familyShippedAt(y2k, 2), isFalse);
      expect(familyShippedAt(y2k, 3), isTrue);
      expect(y2k.enabled, isTrue);
      expect(identical(y2k.definition, y2kAeroDefinition), isTrue);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, y2k, 3);
      final code = encodeShareCode(y2k.id, 3, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, y2k.id);
      expect(gen.generate(decoded.seed, y2k, decoded.engineVersion), spec);
    });

    for (final version in [3, 4]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            y2k,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': y2k.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_Y2K_AERO_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in y2kCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(y2kCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = y2kCases[i];
          final spec = gen.generate(
            c.seed,
            y2k,
            version,
            accessible: c.accessible,
          );
          expect(cases[i]['seed'], c.seed);
          expect(cases[i]['family'], y2k.id);
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
      gen.generate(s, y2k, 3, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, y2k, 3, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('guardrails', () {
    // A generated sky theme (AERO light) and a pastel-foil one (CHROME).
    final sky = gen.generate(5, y2k, 3);
    final foil = gen.generate(3, y2k, 3);
    final water = gen.generate(10, y2k, 3);

    Iterable<GuardrailRule> rules(ThemeSpec s) =>
        validateTheme(s).map((v) => v.rule);

    test('the pinned scenes are what the cases say', () {
      expect(y2kSceneOf(sky.background, dark: sky.isDark), Y2kScene.sky);
      expect(
        y2kSceneOf(foil.background, dark: foil.isDark),
        Y2kScene.pastelHolo,
      );
      expect(y2kSceneOf(water.background, dark: water.isDark), Y2kScene.water);
    });

    test('a label on the deep tone under the cap fails and repairs', () {
      // Passes on the flat face, fails on the darker deep tone (zone).
      for (final base in [sky, foil]) {
        final f = base.palette.operator.face;
        final zone = y2kLabelZoneSamples(
          f,
          accentHueTenths: y2kAccentHueTenths(base.palette),
          depthPermille: base.keyStyle.edgeShadePermille,
          refractionPermille: base.keyStyle.refractionPermille,
        );
        int? weak;
        for (var l = 0.60; l > 0.05; l -= 0.005) {
          final c = oklchToArgb(l, 0.02, argbToOklch(f).h);
          if (contrastRatio(c, f) >= 4.5 && _min(c, zone) < 4.5) {
            weak = c;
            break;
          }
        }
        expect(weak, isNotNull);
        final bad = base.copyWith(
          palette: base.palette.copyWith(
            operator: base.palette.operator.copyWith(label: weak),
          ),
        );
        expect(rules(bad), contains(GuardrailRule.y2kLabelZone));
        final fixed = repairTheme(bad)!;
        expect(validateTheme(fixed), isEmpty);
      }
    });

    test('a mid-grey face or a light label fails polarity', () {
      final grey = sky.copyWith(
        palette: sky.palette.copyWith(
          digit: const KeyColors(
            face: 0xFF8A8A8A,
            label: 0xFF000000,
            edge: 0xFF555555,
          ),
        ),
      );
      expect(rules(grey), contains(GuardrailRule.y2kLabelPolarity));
      final light = sky.copyWith(
        palette: sky.palette.copyWith(
          operator: sky.palette.operator.copyWith(label: 0xFFFFFFFF),
        ),
      );
      expect(rules(light), contains(GuardrailRule.y2kLabelPolarity));
      final translucent = sky.copyWith(
        palette: sky.palette.copyWith(
          digit: sky.palette.digit.copyWith(
            face: sky.palette.digit.face & 0xC0FFFFFF,
          ),
        ),
      );
      expect(rules(translucent), contains(GuardrailRule.y2kLabelPolarity));
    });

    test('a face below the gel floor fails and lifts back', () {
      final f = argbToOklch(sky.palette.equals.face);
      final low = oklchToArgb(0.72, f.c, f.h);
      final bad = sky.copyWith(
        palette: sky.palette.copyWith(
          equals: sky.palette.equals.copyWith(face: low),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.y2kLabelPolarity));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        argbToOklab(fixed.palette.equals.face).$1,
        greaterThanOrEqualTo(0.735),
      );
    });

    test('a broken renderer contract fails y2kGloss', () {
      final cases = [
        sky.copyWith(palette: sky.palette.copyWith(highlight: 0x80FFFFFF)),
        sky.copyWith(keyStyle: sky.keyStyle.copyWith(stateLayerPermille: 100)),
        sky.copyWith(keyStyle: sky.keyStyle.copyWith(highlightPermille: 990)),
        sky.copyWith(keyStyle: sky.keyStyle.copyWith(outlineWidthCdp: 300)),
        foil.copyWith(keyStyle: foil.keyStyle.copyWith(outlineWidthCdp: 125)),
        sky.copyWith(keyStyle: sky.keyStyle.copyWith(kind: KeyStyleKind.flat)),
        sky.copyWith(keyStyle: sky.keyStyle.copyWith(opacityPermille: 700)),
      ];
      for (final bad in cases) {
        expect(rules(bad), contains(GuardrailRule.y2kGloss));
      }
    });

    test('a malformed or over-bright scene fails y2kScene', () {
      final c = [...water.background.colors];
      c[5] = c[5] | 0xFF000000;
      final bright = water.copyWith(
        background: water.background.copyWith(colors: List.unmodifiable(c)),
      );
      expect(rules(bright), contains(GuardrailRule.y2kScene));
      final short = sky.copyWith(
        background: sky.background.copyWith(
          colors: List.unmodifiable(sky.background.colors.take(4)),
        ),
      );
      expect(rules(short), contains(GuardrailRule.y2kScene));
      final pattern = sky.copyWith(
        background: sky.background.copyWith(pattern: BackgroundPattern.stripes),
      );
      expect(rules(pattern), contains(GuardrailRule.y2kScene));
      final fast = sky.copyWith(
        background: sky.background.copyWith(driftPeriodMs: 2000),
      );
      expect(rules(fast), contains(GuardrailRule.y2kScene));
    });

    test('a mid-grey or translucent panel fails y2kPanel', () {
      for (final surface in [0xFF7F7F7F, sky.palette.surface & 0x80FFFFFF]) {
        final bad = sky.copyWith(
          palette: sky.palette.copyWith(surface: surface),
        );
        expect(rules(bad), contains(GuardrailRule.y2kPanel));
      }
    });

    test('display text is checked on the panel gloss too', () {
      final gloss = y2kPanelSamples(water.palette.surface)[1];
      // Light text that passes on the dark panel but not on its gloss.
      int? weak;
      for (var l = 0.40; l < 1; l += 0.005) {
        final c = oklchToArgb(l, 0.01, 200);
        if (contrastRatio(c, water.palette.surface) >= 4.5 &&
            contrastRatio(c, gloss) < 4.5) {
          weak = c;
          break;
        }
      }
      expect(weak, isNotNull);
      final bad = water.copyWith(palette: water.palette.copyWith(error: weak));
      expect(
        rules(bad),
        contains(GuardrailRule.errorText),
        reason: 'the error colour is checked on the gloss composite',
      );
    });

    test('a faint focus ring fails y2kRim and repairs to ≥ 3:1', () {
      final bad = sky.copyWith(
        palette: sky.palette.copyWith(
          focusRing: sky.background.colors[0],
          accent: sky.background.colors[0],
        ),
      );
      expect(
        rules(bad),
        anyOf(
          contains(GuardrailRule.y2kRim),
          contains(GuardrailRule.focusRing),
        ),
      );
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      final edges = y2kEdgeSamples(
        backgroundSamples(fixed.background),
        fixed.palette.shadow,
      );
      expect(_min(fixed.palette.focusRing, edges), greaterThanOrEqualTo(3));
    });

    test('an Accessible rim at 2:1 fails y2kRim and repairs', () {
      final a = gen.generate(5, y2k, 3, accessible: true);
      final bgs = backgroundSamples(a.background);
      final edges = y2kEdgeSamples(bgs, a.palette.shadow);
      int? weak;
      for (var l = 0.0; l <= 1; l += 0.01) {
        final c = oklchToArgb(l, 0.05, 240);
        final r = _min(c, edges);
        if (r >= 1.8 && r < 2.4) {
          weak = c;
          break;
        }
      }
      expect(weak, isNotNull);
      final bad = a.copyWith(
        palette: a.palette.copyWith(
          digit: a.palette.digit.copyWith(edge: weak),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.y2kRim));
      final fixed = repairTheme(bad)!;
      expect(validateTheme(fixed), isEmpty);
      expect(_min(fixed.palette.digit.edge, edges), greaterThanOrEqualTo(3));
      // Outside the lock rims are decorative.
      final normal = sky.copyWith(
        palette: sky.palette.copyWith(
          digit: sky.palette.digit.copyWith(edge: weak),
        ),
      );
      expect(rules(normal), isNot(contains(GuardrailRule.y2kRim)));
    });

    test('a dishonest weight cue fails', () {
      final bad = sky.copyWith(
        type: sky.type.copyWith(operatorWeight: sky.type.keyWeight + 100),
      );
      expect(rules(bad), contains(GuardrailRule.y2kOperatorCue));
    });

    test('an operator that looks like a digit fails y2kAccentVsDigit', () {
      final d = argbToOklch(foil.palette.digit.face);
      final twin = oklchToArgb(d.l - 0.01, d.c, d.h);
      final bad = foil.copyWith(
        palette: foil.palette.copyWith(
          operator: foil.palette.operator.copyWith(face: twin),
        ),
      );
      expect(rules(bad), contains(GuardrailRule.y2kAccentVsDigit));
    });

    test('keys melting into the ground fail y2kGround', () {
      final ground = sky.background.colors[3];
      final x = argbToOklch(ground);
      final face = oklchToArgb(x.l.clamp(0.80, 1), x.c, x.h);
      final bad = sky.copyWith(
        palette: sky.palette.copyWith(
          function: sky.palette.function.copyWith(face: face),
        ),
      );
      final measured = _minDeltaE(face, y2kGroundSamples(sky.background));
      expect(measured, lessThan(0.08));
      expect(rules(bad), contains(GuardrailRule.y2kGround));
      // Dark water and the foils have no ground rule.
      expect(rules(water), isNot(contains(GuardrailRule.y2kGround)));
    });

    test('other families are not checked by the Y2K rules', () {
      final y2kRules = {
        GuardrailRule.y2kLabelZone,
        GuardrailRule.y2kLabelPolarity,
        GuardrailRule.y2kGloss,
        GuardrailRule.y2kScene,
        GuardrailRule.y2kPanel,
        GuardrailRule.y2kRim,
        GuardrailRule.y2kOperatorCue,
        GuardrailRule.y2kAccentVsDigit,
        GuardrailRule.y2kGround,
      };
      for (final f in [
        ThemeFamily.neoPop,
        ThemeFamily.m3Expressive,
        ThemeFamily.liquidGlass,
      ]) {
        final s = gen.generate(3, f, 3);
        final bad = s.copyWith(
          palette: s.palette.copyWith(highlight: 0x80FFFFFF),
        );
        expect(rules(bad).toSet().intersection(y2kRules), isEmpty);
      }
    });
  });

  test('heroes: three Y2K heroes, sky / chrome foil / deep water', () {
    final heroes = heroesFor(y2k);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([100, 101, 102]));
    expect(
      heroes.map((h) => h.name),
      containsAll(['Clear Sky Gel', 'Tangerine Chrome', 'Deep Water Orb']),
    );
    expect(heroes.where((h) => h.isDark), isNotEmpty);
    expect(heroes.where((h) => !h.isDark), isNotEmpty);
    expect({
      for (final h in heroes) y2kSceneOf(h.background, dark: h.isDark),
    }, containsAll([Y2kScene.sky, Y2kScene.pastelHolo, Y2kScene.water]));
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      expect(validateTheme(heroForAccessible(h)), isEmpty, reason: h.name);
      expect(h.keyStyle.kind, KeyStyleKind.glass);
      expect(h.sound, SoundPackId.glass);
      expect(h.motion.verb, PressVerb.gloss);
      expect(h.motion.pressIn, SpringTokens.effectsFast);
      expect(h.nonColourOperatorCue, OperatorCue.weight);
      expect(
        h.type.slashedZero,
        h.background.kind == BackgroundKind.chromeHolo,
      );
    }
  });

  test('names: eight Y2K material words', () {
    expect(familyMaterialWords[y2k], [
      'Bubble',
      'Chrome',
      'Gel',
      'Spritz',
      'Foil',
      'Glint',
      'Mirror',
      'Splash',
    ]);
  });
}
