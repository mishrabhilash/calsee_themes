import 'package:calsee_themes/engine/rng.dart';
import 'package:test/test.dart';

String hex(int v) => v.toRadixString(16).padLeft(8, '0');

void main() {
  group('primitives (research §9.3 known answers)', () {
    test('fmix32, fnv1a32, mul32', () {
      expect(hex(fmix32(1)), '514e28b7');
      expect(hex(fnv1a32('palette')), 'f4ece2a0');
      expect(mul32(0xFFFFFFFF, 0xFFFFFFFF), 1);
      expect(mul32(0x9E3779B9, 0x85EBCA6B), 3238976083);
    });

    test('rotl32', () {
      expect(rotl32(0x80000000, 1), 1);
      expect(rotl32(0x12345678, 8), 0x34567812);
    });

    test('SplitMix32(0) first 4', () {
      final sm = SplitMix32(0);
      expect(
        [for (var i = 0; i < 4; i++) hex(sm.next())],
        ['92ca2f0e', '3cd6e3f3', '1b147dcc', '4c081dbf'],
      );
    });

    test('xoshiro128** state (1,2,3,4) first 6 (matches Vigna C)', () {
      final r = Rng.fromState(1, 2, 3, 4);
      expect(
        [for (var i = 0; i < 6; i++) r.nextU32()],
        [11520, 0, 5927040, 70819200, 2031721883, 1637235492],
      );
    });

    test('Rng.stream(0xDEADBEEF, "palette") first 6', () {
      final r = Rng.stream(0xDEADBEEF, 'palette');
      expect(
        [for (var i = 0; i < 6; i++) hex(r.nextU32())],
        [
          '6d583834',
          '7a903c6f',
          'f2ac0c74',
          'f0b44e6c',
          'bc0026c9',
          '7dae5fd4',
        ],
      );
    });

    test('pickWeighted([1,2,7]) x 100000 on stream (1, "weights")', () {
      final r = Rng.stream(1, 'weights');
      final counts = [0, 0, 0];
      for (var i = 0; i < 100000; i++) {
        counts[r.pickWeighted([1, 2, 7])]++;
      }
      expect(counts, [10096, 20146, 69758]);
    });
  });

  group('Rng', () {
    test('all-zero state is replaced', () {
      final r = Rng.fromState(0, 0, 0, 0);
      expect(r.state, (1, 0, 0, 0));
      expect(
        [for (var i = 0; i < 4; i++) r.nextU32()].any((v) => v != 0),
        isTrue,
      );
    });

    test('seed is taken modulo 2^32', () {
      final a = Rng.stream(0x1DEADBEEF, 'x');
      final b = Rng.stream(0xDEADBEEF, 'x');
      expect(a.nextU32(), b.nextU32());
    });

    test('streams with different tags are independent', () {
      const n = 4096;
      final a = Rng.stream(42, RngTag.palette);
      final b = Rng.stream(42, RngTag.shape);
      var equal = 0;
      var agreeBits = 0;
      for (var i = 0; i < n; i++) {
        final x = a.nextU32();
        final y = b.nextU32();
        if (x == y) equal++;
        var z = (x ^ y) & 0xFFFFFFFF;
        var diff = 0;
        while (z != 0) {
          diff += z & 1;
          z >>>= 1;
        }
        agreeBits += 32 - diff;
      }
      expect(equal, 0);
      // Uncorrelated streams agree on ~50 % of bits.
      final frac = agreeBits / (32 * n);
      expect(frac, closeTo(0.5, 0.01));
    });

    test('consuming one stream never shifts another', () {
      final ref = Rng.stream(7, RngTag.palette);
      final expected = [for (var i = 0; i < 8; i++) ref.nextU32()];
      final shape = Rng.stream(7, RngTag.shape);
      for (var i = 0; i < 1000; i++) {
        shape.nextU32();
      }
      final again = Rng.stream(7, RngTag.palette);
      expect([for (var i = 0; i < 8; i++) again.nextU32()], expected);
    });

    test('nextInt is in range and roughly uniform', () {
      final r = Rng.stream(3, 'uniform');
      final counts = List.filled(7, 0);
      for (var i = 0; i < 70000; i++) {
        final v = r.nextInt(7);
        expect(v, inInclusiveRange(0, 6));
        counts[v]++;
      }
      for (final c in counts) {
        expect(c, closeTo(10000, 400));
      }
      expect(() => r.nextInt(0), throwsRangeError);
      expect(r.nextInt(1), 0);
      expect(r.nextInt(0x100000000), inInclusiveRange(0, 0xFFFFFFFF));
    });

    test('hues, jitter, ranges, picks', () {
      final r = Rng.stream(9, 'misc');
      for (var i = 0; i < 2000; i++) {
        expect(r.nextHueTenths(), inInclusiveRange(0, 3599));
        expect(r.nextJitterTenths(100), inInclusiveRange(-100, 100));
        expect(r.nextIntIn(3, 5), inInclusiveRange(3, 5));
        final d = r.nextDouble();
        expect(d >= 0 && d < 1, isTrue);
        expect(r.range(2, 4), inInclusiveRange(2, 4));
      }
      expect(r.pick(['only']), 'only');
      expect(() => r.pickWeighted([0, 0]), throwsArgumentError);
      expect(r.pickWeighted([0, 5, 0]), 1);
    });

    test('sub-tags', () {
      expect(RngTag.sub('palette', 'repair'), 'palette/repair');
      expect(RngTag.sub('palette', 'repair', 2), 'palette/repair/2');
    });
  });
}
