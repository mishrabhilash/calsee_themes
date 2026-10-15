import 'package:calsee_themes/engine/contrast.dart';
import 'package:calsee_themes/engine/cvd.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:test/test.dart';

void main() {
  group('WCAG 2.2 contrast', () {
    test('known ratios, never rounded', () {
      expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 1e-12));
      expect(contrastRatio(0xFFFFFFFF, 0xFFFFFFFF), 1);
      // #767676 on white is the classic 4.54:1 grey.
      expect(contrastRatio(0xFF767676, 0xFFFFFFFF), closeTo(4.54, 0.005));
      expect(contrastRatio(0xFF777777, 0xFFFFFFFF) < 4.5, isTrue);
      expect(contrastRatio(0xFFFFFFFF, 0xFFFF9F0A), closeTo(2.06, 0.01));
      expect(contrastRatio(0xFF000000, 0xFFFF9F0A), closeTo(10.22, 0.01));
      expect(contrastRatio(0xFFBDBDBD, 0xFF2B2B2B), closeTo(7.54, 0.01));
    });

    test('black/white product is 21; √21 always reachable', () {
      final r = Rng.stream(1, 'bw');
      for (var i = 0; i < 2000; i++) {
        final bg = 0xFF000000 | r.nextInt(0x1000000);
        final w = contrastRatio(bg, 0xFFFFFFFF);
        final b = contrastRatio(bg, 0xFF000000);
        expect(w * b, closeTo(21, 1e-9));
        expect(
          contrastRatio(bg, blackOrWhite(bg)) >= alwaysReachableRatio - 1e-12,
          isTrue,
        );
      }
    });

    test('contrastOver composites translucent foregrounds', () {
      expect(contrastOver(0x00FFFFFF, 0xFF000000), 1);
      expect(contrastOver(0xFFFFFFFF, 0xFF000000), closeTo(21, 1e-12));
    });

    test('policy targets', () {
      const p = ContrastPolicy.standard;
      expect(p.targetFor(0.01), 7);
      expect(p.targetFor(0.5), 4.5);
      expect(p.inPolarityBand(0.25), isTrue);
      expect(p.inPolarityBand(0.1), isFalse);
      expect(ContrastPolicy.accessible.targetFor(0.5), 7);
      const off = ContrastPolicy(darkFaceBoost: false, polarityRule: false);
      expect(off.targetFor(0.01), 4.5);
      expect(off.inPolarityBand(0.25), isFalse);
    });
  });

  group('lightness repair', () {
    test('solveForContrast reaches 3:1 and 4.5:1 in 20,000 random cases', () {
      final r = Rng.stream(2, 'solve');
      for (var i = 0; i < 20000; i++) {
        final bg = oklchTenthsToArgb(
          r.nextDouble(),
          r.nextDouble() * 0.3,
          r.nextHueTenths(),
        );
        final target = r.nextChance(1, 2) ? 3.0 : 4.5;
        final label = solveForContrast(
          r.nextDouble(),
          r.nextDouble() * 0.3,
          r.nextHueTenths() / 10,
          bg,
          target,
        );
        expect(contrastRatio(label, bg) >= target, isTrue);
      }
    });

    test('repairPair always reaches 4.5:1 and 7:1', () {
      final r = Rng.stream(3, 'repair');
      for (final policy in [
        ContrastPolicy.standard,
        ContrastPolicy.accessible,
        const ContrastPolicy(darkFaceBoost: false, polarityRule: false),
      ]) {
        for (var i = 0; i < 3000; i++) {
          final face = (
            l: r.nextDouble(),
            c: r.nextDouble() * 0.3,
            h: r.nextHueTenths() / 10,
          );
          final label = (
            l: r.nextDouble(),
            c: r.nextDouble() * 0.2,
            h: r.nextHueTenths() / 10,
          );
          final p = repairPair(face, label, policy: policy);
          final ratio = contrastRatio(p.label, p.face);
          expect(
            ratio >= policy.minRatio,
            isTrue,
            reason: '$face $label -> $ratio',
          );
          if (luminanceArgb(p.face) < policy.darkFaceY &&
              policy.darkFaceBoost) {
            expect(ratio >= policy.darkFaceRatio, isTrue);
          }
          expect(p.face, oklchToArgb(p.faceLch.l, p.faceLch.c, p.faceLch.h));
        }
      }
    });

    test('mid-tone neutral faces need face movement for 7:1', () {
      final p = repairPair(
        (l: 0.6, c: 0, h: 0),
        (l: 0.95, c: 0, h: 0),
        policy: ContrastPolicy.accessible,
      );
      expect(contrastRatio(p.label, p.face) >= 7, isTrue);
      expect(p.faceLch.l, isNot(0.6));
    });

    test('polarity rule prefers a light label on mid-tone faces', () {
      // #767676 (Y ≈ 0.18): white reaches 4.54:1, so prefer it.
      const face = 0xFF787878;
      final y = luminanceArgb(face);
      expect(y > yEqualContrast && y < yPolarityBandTop, isTrue);
      final label = solveLabel(face, (l: 0.2, c: 0, h: 0));
      // Light label only if it reaches the floor; otherwise dark.
      if (contrastRatio(0xFFFFFFFF, face) >= 4.5) {
        expect(luminanceArgb(label!) > y, isTrue);
      } else {
        expect(contrastRatio(label!, face) >= 4.5, isTrue);
      }
      const brighter = 0xFF8A8A8A; // white fails 4.5 here → dark label
      final dark = solveLabel(brighter, (l: 0.95, c: 0, h: 0))!;
      expect(luminanceArgb(dark) < luminanceArgb(brighter), isTrue);
      expect(contrastRatio(dark, brighter) >= 4.5, isTrue);
    });

    test('dark-face boost solves to 7:1', () {
      const face = 0xFF2B2B2B;
      final label = solveLabel(face, (l: 0.7, c: 0.02, h: 250))!;
      expect(contrastRatio(label, face) >= 7, isTrue);
    });
  });

  group('CVD', () {
    test('matrices match Machado 2009 / Brettel 1997 published values', () {
      expect(machadoProtan, [
        0.152286, 1.052583, -0.204868, //
        0.114503, 0.786281, 0.099216,
        -0.003882, -0.048116, 1.051998,
      ]);
      expect(machadoDeutan, [
        0.367322, 0.860646, -0.227968, //
        0.280085, 0.672501, 0.047413,
        -0.011820, 0.042940, 0.968881,
      ]);
      expect(brettelTritan1[0], 1.01277);
      expect(brettelTritan2[6], -0.37562);
      expect(brettelTritanNormal, [0.03901, -0.02788, -0.01113]);
      // Machado rows sum to ~1: white and greys stay neutral.
      for (final m in [machadoProtan, machadoDeutan]) {
        for (var row = 0; row < 3; row++) {
          expect(
            m[row * 3] + m[row * 3 + 1] + m[row * 3 + 2],
            closeTo(1, 2e-6),
          );
        }
      }
      for (final m in [brettelTritan1, brettelTritan2]) {
        for (var row = 0; row < 3; row++) {
          expect(
            m[row * 3] + m[row * 3 + 1] + m[row * 3 + 2],
            closeTo(1, 2e-5),
          );
        }
      }
    });

    test('greys are invariant; red/green collapse for deutans', () {
      for (final t in Cvd.values) {
        expect(simulateCvdArgb(0xFF808080, t), 0xFF808080);
        expect(simulateCvdArgb(0xFFFFFFFF, t), 0xFFFFFFFF);
      }
      expect(cvdDeltaE(0xFF4C8C4A, 0xFFB5524A, Cvd.deutan), lessThan(0.03));
    });

    test('measured examples (research §6.2)', () {
      expect(minCvdDeltaE(0xFF333333, 0xFFFF9F0A), closeTo(0.4329, 0.0005));
      expect(contrastRatio(0xFF333333, 0xFFFF9F0A), closeTo(6.146, 0.001));
      expect(minCvdDeltaE(0xFF4C8C4A, 0xFFB5524A), closeTo(0.0113, 0.0005));
      expect(contrastRatio(0xFF4C8C4A, 0xFFB5524A), closeTo(1.208, 0.001));
      expect(minCvdDeltaE(0xFF3D5A80, 0xFF6A4C93), closeTo(0.030, 0.002));
    });
  });
}
