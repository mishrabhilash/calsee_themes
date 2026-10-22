/// Seeded, platform-identical pseudo-random numbers for theme generation
/// (research theme-engine.md §9, Recommendation 9).
///
/// Every operation is 32-bit and masked, and the only multiplications are
/// ×5, ×9 and the 16-bit-limb [mul32], so the VM, AOT, dart2js and dart2wasm
/// produce identical streams. Never use `dart:math` `Random(seed)` for
/// anything that feeds a generated theme: its stream may change between SDK
/// releases.
library;

const int _m32 = 0xFFFFFFFF;
const int _two32 = 0x100000000;

/// Low 32 bits of `a * b` for `0 <= a, b < 2^32`. Exact on every backend
/// (all intermediates stay below 2^53).
int mul32(int a, int b) {
  final aLo = a & 0xFFFF;
  final aHi = (a >>> 16) & 0xFFFF;
  final bLo = b & 0xFFFF;
  final bHi = (b >>> 16) & 0xFFFF;
  final mid = ((aHi * bLo + aLo * bHi) & 0xFFFF) * 65536; // < 2^32
  return (aLo * bLo + mid) & _m32; // < 2^33 before masking
}

/// Rotates the 32-bit value [x] left by [k] (1 ≤ k ≤ 31).
int rotl32(int x, int k) => ((x << k) & _m32) | ((x & _m32) >>> (32 - k));

/// MurmurHash3 `fmix32` finaliser: a bijection on 32-bit values.
int fmix32(int value) {
  var h = value & _m32;
  h = (h ^ (h >>> 16)) & _m32;
  h = mul32(h, 0x85EBCA6B);
  h = (h ^ (h >>> 13)) & _m32;
  h = mul32(h, 0xC2B2AE35);
  return (h ^ (h >>> 16)) & _m32;
}

/// FNV-1a (32-bit) over the low byte of each code unit of an ASCII [tag].
int fnv1a32(String tag) {
  var h = 0x811C9DC5;
  for (final c in tag.codeUnits) {
    h = mul32((h ^ (c & 0xFF)) & _m32, 0x01000193);
  }
  return h;
}

/// SplitMix32 (Weyl sequence + [fmix32]). Only used to expand a 32-bit seed
/// into xoshiro state.
final class SplitMix32 {
  /// Starts the sequence at [seed] (taken modulo 2^32).
  SplitMix32(int seed) : _s = seed & _m32;

  int _s;

  /// The next 32-bit output.
  int next() {
    _s = (_s + 0x9E3779B9) & _m32;
    return fmix32(_s);
  }
}

/// Stream tags (one independent stream per theme aspect, research §9.4).
///
/// Changing how many numbers one aspect consumes never shifts another
/// aspect's draws. For variable-length loops (repair rounds, rerolls) use a
/// sub-tag such as `'palette/repair'` (see [RngTag.sub]).
abstract final class RngTag {
  static const String palette = 'palette';
  static const String shape = 'shape';
  static const String style = 'style';
  static const String type = 'type';
  static const String background = 'background';
  static const String motion = 'motion';
  static const String effects = 'effects';
  static const String sound = 'sound';
  static const String name = 'name';
  static const String hero = 'hero';
  static const String daily = 'daily';
  static const String feed = 'feed';

  /// A sub-tag, e.g. `sub('palette', 'repair', 2)` → `'palette/repair/2'`.
  static String sub(String tag, String child, [int? index]) =>
      index == null ? '$tag/$child' : '$tag/$child/$index';
}

/// xoshiro128** 1.1 (Blackman & Vigna 2018), seeded through [SplitMix32].
///
/// Mutable: each draw advances the state. Create one per aspect with
/// [Rng.stream].
final class Rng {
  /// Raw state constructor (tests and known-answer vectors). The all-zero
  /// state is forbidden and replaced by `(1, 0, 0, 0)`.
  Rng.fromState(int a, int b, int c, int d)
    : _a = ((a | b | c | d) & _m32) == 0 ? 1 : a & _m32,
      _b = b & _m32,
      _c = c & _m32,
      _d = d & _m32;

  /// The independent sub-stream named [tag] of [seed] (seed taken modulo
  /// 2^32).
  factory Rng.stream(int seed, String tag) {
    final sm = SplitMix32((seed & _m32) ^ fnv1a32(tag));
    final a = sm.next();
    final b = sm.next();
    final c = sm.next();
    final d = sm.next();
    return Rng.fromState(a, b, c, d);
  }

  int _a;
  int _b;
  int _c;
  int _d;

  /// The current 128-bit state as four 32-bit words (tests only).
  (int, int, int, int) get state => (_a, _b, _c, _d);

  /// The next uniformly distributed 32-bit unsigned integer.
  int nextU32() {
    final result = (rotl32((_b * 5) & _m32, 7) * 9) & _m32;
    final t = (_b << 9) & _m32;
    _c ^= _a;
    _d ^= _b;
    _b ^= _c;
    _a ^= _d;
    _c ^= t;
    _d = rotl32(_d, 11);
    return result;
  }

  /// Unbiased integer in `[0, n)` for `1 <= n <= 2^32` (rejection sampling:
  /// redraw while the raw value is ≥ `2^32 − (2^32 mod n)`).
  int nextInt(int n) {
    if (n < 1 || n > _two32) {
      throw RangeError.range(n, 1, _two32, 'n');
    }
    final limit = _two32 - (_two32 % n);
    while (true) {
      final x = nextU32();
      if (x < limit) return x % n;
    }
  }

  /// Integer in `[lo, hi]` (inclusive), unbiased.
  int nextIntIn(int lo, int hi) => lo + nextInt(hi - lo + 1);

  /// `true` with probability [numerator] / [denominator].
  bool nextChance(int numerator, int denominator) =>
      nextInt(denominator) < numerator;

  /// Double in `[0, 1)`: `nextU32() / 2^32`, exact on every backend.
  double nextDouble() => nextU32() / 4294967296.0;

  /// Double in `[lo, hi)`: `lo + (hi − lo)·u`, deterministic.
  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  /// A hue as integer tenths of a degree, `[0, 3600)`.
  int nextHueTenths() => nextInt(3600);

  /// A symmetric jitter in tenths of a degree, `[-maxTenths, +maxTenths]`.
  int nextJitterTenths(int maxTenths) => nextInt(2 * maxTenths + 1) - maxTenths;

  /// Index into [weights] (small non-negative integers, sum > 0), chosen
  /// with probability proportional to its weight. Integer weights only, so
  /// no floating-point cumulative sums can round differently.
  int pickWeighted(List<int> weights) {
    var total = 0;
    for (final w in weights) {
      if (w < 0) throw ArgumentError.value(weights, 'weights', 'negative');
      total += w;
    }
    if (total <= 0) {
      throw ArgumentError.value(weights, 'weights', 'sum must be > 0');
    }
    var r = nextInt(total);
    for (var i = 0; i < weights.length; i++) {
      r -= weights[i];
      if (r < 0) return i;
    }
    throw StateError('unreachable');
  }

  /// A uniformly chosen element of the non-empty list [items].
  T pick<T>(List<T> items) => items[nextInt(items.length)];
}
