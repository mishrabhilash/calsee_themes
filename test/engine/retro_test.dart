/// Retro hardware generator, guardrails and fixtures (docs/m4-design.md
/// §B).
///
/// The golden JSON fixture of the current engine version is written only on
/// request (older versions' fixtures are frozen):
///
///     UPDATE_RETRO_GOLDENS=1 dart test test/themes/engine/retro_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/families.dart';
import 'package:calsee_themes/engine/generator.dart';
import 'package:calsee_themes/engine/guardrails.dart';
import 'package:calsee_themes/engine/heroes.dart';
import 'package:calsee_themes/engine/retro.dart';
import 'package:calsee_themes/engine/share_code.dart';
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:test/test.dart';

const ThemeGenerator gen = ThemeGenerator();

String fixturePath(int version) =>
    'test/engine/fixtures/retro_v$version.json';

/// Pinned Retro cases: desk and pocket bodies, LCD and VFD panels, both
/// locks.
const List<({int seed, bool accessible})> retroCases = [
  (seed: 0, accessible: false),
  (seed: 4, accessible: false),
  (seed: 6, accessible: false),
  (seed: 28, accessible: false),
  (seed: 0xDEADBEEF, accessible: false),
  (seed: 12345, accessible: true),
  (seed: 0xFFFFFFFF, accessible: true),
];

bool isVfd(ThemeSpec s) =>
    luminanceArgb(s.palette.surface) < luminanceArgb(s.palette.displayText);

void main() {
  group('10,000 seeds pass the Retro guardrails', () {
    for (final accessible in [false, true]) {
      test(accessible ? 'accessible' : 'normal', () {
        var desk = 0;
        var vfd = 0;
        var accentOps = 0;
        var clicky = 0;
        var chiptune = 0;
        var pocket = 0;
        final depths = <int>{};
        final minLabel = accessible ? 7.0 : 4.5;
        for (var seed = 0; seed < 10000; seed++) {
          final s = gen.generate(
            seed,
            ThemeFamily.retro,
            currentEngineVersion,
            accessible: accessible,
          );
          final v = validateTheme(s);
          if (v.isNotEmpty) fail('seed $seed: $v');
          if (s.variant == ThemeVariant.hero) fail('seed $seed fell back');
          final p = s.palette;
          // The 7-segment panel: digits ≥ 4.5:1 (7:1), ghosts ≤ 1.3:1 but
          // still visible.
          expect(s.type.lcd, isTrue);
          final ghost = p.lcdGhost!;
          final digits = contrastRatio(p.displayText, p.surface);
          final ghostRatio = contrastRatio(ghost, p.surface);
          if (digits < minLabel) fail('seed $seed digits $digits');
          if (ghostRatio > lcdGhostMaxRatio || ghostRatio < 1.03) {
            fail('seed $seed ghost $ghostRatio');
          }
          // Key labels.
          for (final k in [p.digit, p.operator, p.equals, p.function]) {
            if (contrastRatio(k.label, k.face) < minLabel) {
              fail('seed $seed label $k');
            }
          }
          // Non-colour operator cue: a heavier label, recorded.
          expect(s.nonColourOperatorCue, OperatorCue.weight);
          if (s.type.operatorWeight < s.type.keyWeight + 200) {
            fail('seed $seed weights ${s.type.toJson()}');
          }
          // `=` always stands apart from the operators.
          // Keycaps, travel 2–3 dp on whole-dp steps, motion per brief.
          expect(s.keyShape.kind, KeyShapeKind.keycap);
          expect(s.keyStyle.kind, KeyStyleKind.extruded);
          expect(s.keyStyle.extrudeDepthCdp, s.motion.depthCdp);
          depths.add(s.motion.depthCdp);
          expect(s.motion.pressIn, SpringTokens.hardPress);
          expect(s.motion.entry, EntryStyle.segments);
          expect(s.motion.impact, ImpactStyle.rigid);
          expect(s.motion.releaseHaptic, isTrue);
          if (!s.isDark) desk++;
          if (isVfd(s)) vfd++;
          if (contrastRatio(p.operator.face, p.digit.face) > 1 &&
              p.operator.face != p.function.face &&
              _chroma(p.operator.face) > 0.04) {
            accentOps++;
          }
          if (s.isDark) pocket++;
          if (s.sound == SoundPackId.mechClicky) {
            clicky++;
            expect(s.isDark, isFalse, reason: 'only desk models click');
          } else if (s.sound == SoundPackId.chiptune) {
            chiptune++;
            expect(s.isDark, isTrue, reason: 'only pocket models play 8-bit');
          } else {
            expect(s.sound, SoundPackId.beep);
          }
        }
        expect(depths, {200, 300});
        expect(desk, inInclusiveRange(4000, 6000));
        expect(vfd, inInclusiveRange(1800, 3200), reason: 'VFD ≈ 1 in 4');
        expect(accentOps, inInclusiveRange(5500, 7800));
        expect(clicky, inInclusiveRange(1200, 2200));
        expect(
          chiptune / pocket,
          inInclusiveRange(0.28, 0.39),
          reason: 'chiptune ≈ 1 in 3 pocket themes',
        );
      });
    }
  });

  test('release motion stays inside the brief (1200/0.7 × {0.9, 1, 1.1})', () {
    final seen = <int>{};
    for (var seed = 0; seed < 500; seed++) {
      final m = gen.generate(seed, ThemeFamily.retro, 2).motion;
      seen.add(m.release.stiffness);
      expect(m.release.zetaPermille, 700);
    }
    expect(seen, {1080, 1200, 1320});
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
            ThemeFamily.retro,
            2,
            accessible: accessible,
          );
          final b = other.generate(
            seed,
            ThemeFamily.retro,
            2,
            accessible: accessible,
          );
          expect(b.toJsonString(), a.toJsonString());
          expect(b.stableHash, a.stableHash);
        }
      }
    });

    test('JSON round-trips (lcdGhost included)', () {
      for (var s = 0; s < 50; s++) {
        final spec = gen.generate(s, ThemeFamily.retro, 2);
        expect(
          spec.toJson()['palette'],
          containsPair('lcdGhost', isA<String>()),
        );
        expect(ThemeSpec.fromJsonString(spec.toJsonString()), spec);
      }
    });

    test('retry attempts use a different palette stream only', () {
      final a0 = gen.buildCandidate(5, ThemeFamily.retro, 2);
      final a1 = gen.buildCandidate(5, ThemeFamily.retro, 2, attempt: 1);
      expect(a1.palette, isNot(a0.palette));
      expect(a1.motion, a0.motion);
      expect(a1.keyShape, a0.keyShape);
    });

    test('Retro did not exist at engine v1', () {
      expect(() => gen.generate(1, ThemeFamily.retro, 1), throwsArgumentError);
      expect(familyShippedAt(ThemeFamily.retro, 2), isTrue);
    });

    test('share codes round-trip', () {
      final spec = gen.generate(0xA5A5A5A5, ThemeFamily.retro, 2);
      final code = encodeShareCode(ThemeFamily.retro.id, 2, 0xA5A5A5A5);
      final decoded = decodeShareCode(code)!;
      expect(decoded.familyId, ThemeFamily.retro.id);
      expect(
        gen.generate(decoded.seed, ThemeFamily.retro, decoded.engineVersion),
        spec,
      );
    });

    for (final version in [2, 3]) {
      test('golden JSON fixture (v$version)', () {
        Map<String, Object?> caseJson(({int seed, bool accessible}) c) {
          final spec = gen.generate(
            c.seed,
            ThemeFamily.retro,
            version,
            accessible: c.accessible,
          );
          return {
            'seed': c.seed,
            'family': ThemeFamily.retro.id,
            'accessible': c.accessible,
            'hash': spec.stableHash.toRadixString(16).padLeft(8, '0'),
            'spec': spec.toJson(),
          };
        }

        final file = File(fixturePath(version));
        if (Platform.environment['UPDATE_RETRO_GOLDENS'] == '1' &&
            version == currentEngineVersion) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(
              '${const JsonEncoder.withIndent('  ').convert({
                'engineVersion': version,
                'cases': [for (final c in retroCases) caseJson(c)],
              })}\n',
            );
        }
        final fixture =
            jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
        expect(fixture['engineVersion'], version);
        final cases = (fixture['cases']! as List).cast<Map<String, Object?>>();
        expect(cases, hasLength(retroCases.length));
        for (var i = 0; i < cases.length; i++) {
          final c = retroCases[i];
          final spec = gen.generate(
            c.seed,
            ThemeFamily.retro,
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

    test('v3 changes only the sound, and only for pocket themes', () {
      for (var seed = 0; seed < 2000; seed++) {
        final v2 = gen.generate(seed, ThemeFamily.retro, 2);
        final v3 = gen.generate(seed, ThemeFamily.retro, 3);
        expect(v3.palette, v2.palette, reason: 'seed $seed');
        expect(v3.keyStyle, v2.keyStyle);
        expect(v3.type, v2.type);
        expect(v3.motion, v2.motion);
        expect(v3.name, v2.name);
        if (v3.sound != v2.sound) {
          expect(v2.sound, SoundPackId.beep);
          expect(v3.sound, SoundPackId.chiptune);
          expect(v3.isDark, isTrue);
        }
      }
    });
  });

  test('generation p99 < 2 ms', () {
    // Warm up the VM.
    for (var s = 0; s < 300; s++) {
      gen.generate(s, ThemeFamily.retro, 2, accessible: s.isOdd);
    }
    final times = <int>[];
    final sw = Stopwatch()..start();
    for (var s = 0; s < 2000; s++) {
      final t0 = sw.elapsedMicroseconds;
      gen.generate(s + 50000, ThemeFamily.retro, 2, accessible: s.isOdd);
      times.add(sw.elapsedMicroseconds - t0);
    }
    times.sort();
    final p99 = times[(times.length * 0.99).floor()];
    expect(p99, lessThan(2000), reason: 'p99 $p99 µs');
  }, tags: 'perf');

  group('guardrails', () {
    final base = gen.generate(6, ThemeFamily.retro, 2);

    test('the display is checked against the LCD panel only', () {
      expect(displayBackdrops(base), [base.palette.surface]);
      // Non-LCD themes keep the background samples.
      final m3e = gen.generate(6, ThemeFamily.m3Expressive, 2);
      expect(displayBackdrops(m3e).length, greaterThan(1));
    });

    test('visible ghost segments fail and repair', () {
      final loud = base.copyWith(
        palette: base.palette.copyWith(lcdGhost: base.palette.displayText),
      );
      final v = validateTheme(loud);
      expect(v.map((x) => x.rule), contains(GuardrailRule.lcdGhost));
      final fixed = repairTheme(loud)!;
      expect(validateTheme(fixed), isEmpty);
      expect(
        contrastRatio(fixed.palette.lcdGhost!, fixed.palette.surface),
        lessThanOrEqualTo(lcdGhostMaxRatio),
      );
    });

    test('lcdGhostColor reaches the requested ratio on LCD and VFD', () {
      for (final (panel, seg) in [
        (0xFFB8BE9A, 0xFF22261A),
        (0xFF031011, 0xFF3BF4F4),
        (0xFFFFFFFF, 0xFF000000),
      ]) {
        final g = lcdGhostColor(panel, seg);
        final r = contrastRatio(g, panel);
        expect(r, lessThanOrEqualTo(1.15));
        expect(r, greaterThan(1.10));
      }
      // A segment already fainter than the ratio is returned unchanged.
      expect(lcdGhostColor(0xFF808080, 0xFF828282), 0xFF828282);
    });

    test('faint LCD digits fail', () {
      final faint = base.copyWith(
        palette: base.palette.copyWith(
          displayText: lcdGhostColor(
            base.palette.surface,
            0xFF000000,
            ratio: 3,
          ),
        ),
      );
      expect(
        validateTheme(faint).map((x) => x.rule),
        contains(GuardrailRule.displayText),
      );
    });
  });

  test('heroes: three Retro heroes, desk / pocket / VFD, all valid', () {
    final heroes = heroesFor(ThemeFamily.retro);
    expect(heroes, hasLength(greaterThanOrEqualTo(3)));
    expect(heroes.map((h) => h.heroId), containsAll([50, 51, 52]));
    expect(heroes.where((h) => !h.isDark), isNotEmpty);
    expect(heroes.where((h) => h.isDark && !isVfd(h)), isNotEmpty);
    expect(heroes.where(isVfd), isNotEmpty);
    for (final h in heroes) {
      expect(validateTheme(h), isEmpty, reason: h.name);
      expect(validateTheme(heroForAccessible(h)), isEmpty, reason: h.name);
      expect(h.type.lcd, isTrue);
    }
  });

  test('tables never offer bile hues for the accent', () {
    for (final w in retroAccentHues) {
      expect(
        BileRule.v2.loTenths <= w.value && w.value <= BileRule.v2.hiTenths,
        isFalse,
      );
    }
  });
}

double _chroma(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255;
  final g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  final max = [r, g, b].reduce((x, y) => x > y ? x : y);
  final min = [r, g, b].reduce((x, y) => x < y ? x : y);
  return max - min;
}
