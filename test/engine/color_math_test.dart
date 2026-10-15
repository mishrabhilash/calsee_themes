import 'dart:math' as math;
import 'dart:typed_data';

import 'package:calsee_themes/engine/bitexact_math.dart';
import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart';
import 'package:test/test.dart';

/// Folds the exact bit pattern of [x] into [h] (FNV-style, 32-bit safe).
int foldDouble(int h, double x) {
  final bd = ByteData(8)..setFloat64(0, x == 0 ? 0.0 : x);
  var acc = h;
  for (var i = 0; i < 8; i++) {
    acc = mul32((acc ^ bd.getUint8(i)) & 0xFFFFFFFF, 0x01000193);
  }
  return acc;
}

int foldInt(int h, int v) {
  var acc = h;
  for (var i = 0; i < 4; i++) {
    acc = mul32((acc ^ ((v >>> (8 * i)) & 0xFF)) & 0xFFFFFFFF, 0x01000193);
  }
  return acc;
}

double powEncode(double l) =>
    l <= 0.0031308 ? 12.92 * l : 1.055 * math.pow(l, 1 / 2.4) - 0.055;

String hex(int v) => v.toRadixString(16).padLeft(8, '0');

void main() {
  group('bit-exact maths vs dart:math', () {
    test('detSinCosDeg within 2e-15', () {
      for (var t = -7200; t <= 7200; t++) {
        final deg = t / 10;
        final (s, c) = detSinCosDeg(deg);
        final rad = deg * math.pi / 180;
        expect((s - math.sin(rad)).abs(), lessThan(1e-14), reason: '$deg');
        expect((c - math.cos(rad)).abs(), lessThan(1e-14), reason: '$deg');
      }
      expect(detSinDeg(90), 1);
      expect(detCosDeg(0), 1);
      expect(detSinDeg(0), 0);
    });

    test('detCbrt sign-matched, relative error < 1e-15', () {
      final r = Rng.stream(1, 'cbrt');
      for (var i = 0; i < 20000; i++) {
        final x = (r.nextDouble() - 0.5) * 1e3 * r.nextDouble();
        final want = x < 0 ? -math.pow(-x, 1 / 3) : math.pow(x, 1 / 3);
        if (x == 0) continue;
        expect(((detCbrt(x) - want) / want).abs(), lessThan(1e-15));
      }
      expect(detCbrt(-8), -2);
      expect(detCbrt(27), closeTo(3, 1e-15));
      expect(detCbrt(0), 0);
    });

    test('detSqrt', () {
      final r = Rng.stream(2, 'sqrt');
      for (var i = 0; i < 20000; i++) {
        final x = r.nextDouble() * 10;
        expect((detSqrt(x) - math.sqrt(x)).abs(), lessThan(1e-15));
      }
      expect(detSqrt(-1), 0);
      expect(detSqrt(4), 2);
    });

    test('detAtan2Deg within 1e-12 degrees', () {
      final r = Rng.stream(3, 'atan2');
      for (var i = 0; i < 20000; i++) {
        final y = r.nextDouble() * 2 - 1;
        final x = r.nextDouble() * 2 - 1;
        var want = math.atan2(y, x) * 180 / math.pi;
        if (want < 0) want += 360;
        final got = detAtan2Deg(y, x);
        final d = (got - want).abs();
        expect(math.min(d, 360 - d), lessThan(1e-12), reason: '$y $x');
      }
      expect(detAtan2Deg(0, 0), 0);
      expect(detAtan2Deg(1, 0), closeTo(90, 1e-12));
      expect(detAtan2Deg(0, -1), closeTo(180, 1e-12));
      expect(detAtan2Deg(-1, 0), closeTo(270, 1e-12));
    });

    test('table sRGB: spot values and encode8 == round(255*pow-encode)', () {
      expect(srgbDecode[1], 0.0003035269835488375);
      expect(srgbDecode[128], 0.21586050011389915);
      expect(srgbEncodeThreshold[0], 0.00015176349177441876);
      expect(srgbEncodeThreshold[254], 0.9955452497210775);
      final r = Rng.stream(4, 'encode');
      var mismatches = 0;
      for (var i = 0; i < 200000; i++) {
        final x = r.nextDouble();
        if (encode8(x) != (255 * powEncode(x)).round()) mismatches++;
      }
      expect(mismatches, 0);
      for (var v = 0; v < 256; v++) {
        expect(encode8(decode8(v)), v);
      }
      expect(encode8(-1), 0);
      expect(encode8(2), 255);
    });
  });

  group('OKLab / OKLCH', () {
    test('reference values (research §2.4)', () {
      void check(int argb, double l, double c, double? h) {
        final lch = argbToOklch(argb);
        expect(lch.l, closeTo(l, 0.0006), reason: hex(argb));
        expect(lch.c, closeTo(c, 0.0006), reason: hex(argb));
        if (h != null) expect(lch.h, closeTo(h, 0.06), reason: hex(argb));
      }

      check(0xFFFF0000, 0.627955, 0.257683, 29.2);
      check(0xFFFF8000, 0.732, 0.186, 53);
      check(0xFFFFFF00, 0.968, 0.211, 109.8);
      check(0xFF00FF00, 0.866440, 0.294827, 142.5);
      check(0xFF00FFFF, 0.905, 0.155, 194.8);
      check(0xFF0000FF, 0.452014, 0.313214, 264.1);
      check(0xFF8000FF, 0.530, 0.293, 293.9);
      check(0xFFFF00FF, 0.702, 0.322, 328.4);
      check(0xFF808080, 0.599871, 0, null);
    });

    test('white is exactly L=1, C~0; round trip', () {
      final w = linToOklab((1, 1, 1));
      expect(w.$1, closeTo(1, 1e-15));
      expect(w.$2.abs() + w.$3.abs(), lessThan(1e-12));
      final r = Rng.stream(5, 'roundtrip');
      for (var i = 0; i < 5000; i++) {
        final argb = 0xFF000000 | r.nextInt(0x1000000);
        expect(linToArgb(oklabToLin(argbToOklab(argb))), argb);
      }
    });

    test('gamut mapping known answers (research Appendix A)', () {
      expect(hex(oklchToArgb(0.70, 0.40, 30)), 'ffff6551');
      expect(maxChroma(0.7, 30), closeTo(0.191512, 1e-6));
      expect(oklchToArgb(1.2, 0.1, 0), 0xFFFFFFFF);
      expect(oklchToArgb(-0.1, 0.1, 0), 0xFF000000);
      expect(maxChroma(0, 100), 0);
      expect(maxChroma(1, 100), 0);
    });

    test('maxChroma matches the cusp table (research §3.3)', () {
      const cusp = {
        0: (0.645, 0.261),
        90: (0.860, 0.176),
        180: (0.895, 0.162),
        270: (0.465, 0.305),
        330: (0.695, 0.317),
      };
      cusp.forEach((h, v) {
        expect(maxChroma(v.$1, h.toDouble()), closeTo(v.$2, 0.004));
      });
    });

    test('mapped colours are in gamut and keep L,h when C fits', () {
      final r = Rng.stream(6, 'map');
      for (var i = 0; i < 3000; i++) {
        final l = 0.05 + 0.9 * r.nextDouble();
        final h = r.nextHueTenths() / 10;
        final mc = maxChroma(l, h);
        final c = mc * 0.9;
        final lin = mapOklch(l, c, h);
        expect(inGamut(lin, 0), isTrue);
        final back = linToOklab(lin);
        final lch = oklabToOklch(back);
        expect(lch.l, closeTo(l, 1e-9));
        if (c > 0.01) {
          final dh = (lch.h - h).abs();
          expect(math.min(dh, 360 - dh), lessThan(1e-6));
        }
      }
    });

    test('gamut mapping is monotone: luminance non-decreasing in L', () {
      var violations = 0;
      for (var hi = 0; hi < 36; hi++) {
        final h = hi * 10.0;
        for (final c in [0.0, 0.05, 0.1, 0.2, 0.3, 0.4]) {
          var prevY = -1.0;
          var prevQ = -1.0;
          for (var li = 0; li <= 200; li++) {
            final lin = mapOklch(li / 200, c, h);
            final y = 0.2126 * lin.$1 + 0.7152 * lin.$2 + 0.0722 * lin.$3;
            final q = argbToLin(linToArgb(lin));
            final yq = 0.2126 * q.$1 + 0.7152 * q.$2 + 0.0722 * q.$3;
            if (y < prevY - 1e-12) violations++;
            if (yq < prevQ) violations++;
            prevY = y;
            prevQ = yq;
          }
        }
      }
      expect(violations, 0);
    });

    test('ΔEOK, lerp, alpha helpers', () {
      expect(deltaEOKArgb(0xFF000000, 0xFFFFFFFF), closeTo(1, 1e-12));
      expect(lerpArgbOklab(0xFF102030, 0xFFF0E0D0, 0), 0xFF102030);
      expect(lerpArgbOklab(0xFF102030, 0xFFF0E0D0, 1), 0xFFF0E0D0);
      final mid = lerpArgbOklab(0xFF000000, 0xFFFFFFFF, 0.5);
      expect(argbToOklch(mid).l, closeTo(0.5, 0.005));
      expect(withAlpha(0xFF123456, 0x80), 0x80123456);
      expect(compositeOver(0x00FFFFFF, 0xFF000000), 0xFF000000);
      expect(compositeOver(0xFFFFFFFF, 0xFF000000), 0xFFFFFFFF);
      expect(compositeOver(0x80FFFFFF, 0xFF000000), 0xFF808080);
    });
  });

  group('bit-exactness fixture', () {
    // Pins a hash over a large sample of every output path the generator
    // uses. Any change to constants, tables or algorithms changes it, and
    // the value must be identical on VM, AOT, dart2js and dart2wasm
    // (`dart test -p node`, `--compiler dart2wasm`).
    test('fold hash over 40,000 conversions', () {
      var h = 0x811C9DC5;
      final r = Rng.stream(0xC0FFEE, 'fixture');
      for (var i = 0; i < 10000; i++) {
        final l = r.nextInt(1001) / 1000;
        final c = r.nextInt(401) / 1000;
        final ht = r.nextHueTenths();
        final (s, co) = detSinCosDeg(ht / 10);
        h = foldDouble(h, s);
        h = foldDouble(h, co);
        h = foldDouble(h, detCbrt(l - 0.5));
        h = foldDouble(h, maxChroma(l, ht / 10));
        final argb = oklchTenthsToArgb(l, c, ht);
        h = foldInt(h, argb);
        final lab = argbToOklab(argb);
        h = foldDouble(h, lab.$1);
        h = foldDouble(h, lab.$2);
        h = foldDouble(h, lab.$3);
        h = foldDouble(h, argbToOklch(argb).h);
      }
      expect(hex(h), kColorFixtureHash);
    });
  });
}

/// Update only together with an engineVersion bump.
const String kColorFixtureHash = '649186c8';
