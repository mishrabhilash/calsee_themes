/// Bit-exact maths for theme generation (research theme-engine.md §2.5,
/// Recommendation 10).
///
/// `dart:math` `sin`/`cos`/`atan2` differ in the last bits between the VM
/// (platform libm) and the web (V8's fdlibm port) on 4–20 % of inputs, and
/// other OS libms are untested. Everything here uses only IEEE-754
/// `+ − × ÷` (correctly rounded on every Dart backend, no FMA contraction),
/// so outputs are identical on VM, AOT, dart2js and dart2wasm.
library;

import 'package:calsee_themes/engine/srgb_tables.g.dart';

export 'package:calsee_themes/engine/srgb_tables.g.dart'
    show srgbDecode, srgbEncodeThreshold;

/// π to double precision.
const double detPi = 3.141592653589793;

/// Cube root, sign-matched (`detCbrt(-8) == -2`): range reduction by 8,
/// then 7 Newton steps. Max relative error vs `pow` ≈ 3.2e-16.
double detCbrt(double x) {
  if (x == 0 || x.isNaN || x.isInfinite) return x;
  final neg = x < 0;
  var a = neg ? -x : x;
  var scale = 1.0;
  while (a >= 8.0) {
    a *= 0.125;
    scale *= 2.0;
  }
  while (a < 1.0) {
    a *= 8.0;
    scale *= 0.5;
  }
  var y = 1.0 + (a - 1.0) / 7.0;
  for (var i = 0; i < 7; i++) {
    y = y - (y * y * y - a) / (3.0 * y * y);
  }
  final r = y * scale;
  return neg ? -r : r;
}

/// Square root by Newton iteration (deterministic; 0 for x ≤ 0).
double detSqrt(double x) {
  if (x <= 0 || x.isNaN) return 0;
  if (x.isInfinite) return x;
  var y = x > 1 ? x : 1.0;
  for (var i = 0; i < 80; i++) {
    final n = 0.5 * (y + x / y);
    if (n == y) break;
    y = n;
  }
  return y;
}

double _sinPoly(double x) {
  final x2 = x * x;
  var t = 1.0 / 355687428096000.0;
  t = t * x2 - 1.0 / 1307674368000.0;
  t = t * x2 + 1.0 / 6227020800.0;
  t = t * x2 - 1.0 / 39916800.0;
  t = t * x2 + 1.0 / 362880.0;
  t = t * x2 - 1.0 / 5040.0;
  t = t * x2 + 1.0 / 120.0;
  t = t * x2 - 1.0 / 6.0;
  return x + x * x2 * t;
}

double _cosPoly(double x) {
  final x2 = x * x;
  var t = 1.0 / 6402373705728000.0;
  t = t * x2 - 1.0 / 20922789888000.0;
  t = t * x2 + 1.0 / 87178291200.0;
  t = t * x2 - 1.0 / 479001600.0;
  t = t * x2 + 1.0 / 3628800.0;
  t = t * x2 - 1.0 / 40320.0;
  t = t * x2 + 1.0 / 720.0;
  t = t * x2 - 1.0 / 24.0;
  t = t * x2 + 0.5;
  return 1.0 - x2 * t;
}

/// `(sin, cos)` of an angle in **degrees**: octant reduction in degrees,
/// then Taylor series to x¹⁷ / x¹⁸. Max absolute error ≈ 1.3e-15.
(double, double) detSinCosDeg(double deg) {
  final d = deg % 360.0;
  final q = (d / 90.0).floor();
  var r = d - q * 90.0;
  var swap = false;
  if (r > 45.0) {
    r = 90.0 - r;
    swap = true;
  }
  final rad = r * (detPi / 180.0);
  var s = _sinPoly(rad);
  var c = _cosPoly(rad);
  if (swap) {
    final t = s;
    s = c;
    c = t;
  }
  return switch (q) {
    0 => (s, c),
    1 => (c, -s),
    2 => (-s, -c),
    _ => (-c, s),
  };
}

/// Sine of an angle in degrees (see [detSinCosDeg]).
double detSinDeg(double deg) => detSinCosDeg(deg).$1;

/// Cosine of an angle in degrees (see [detSinCosDeg]).
double detCosDeg(double deg) => detSinCosDeg(deg).$2;

/// Arctangent of `t` for `|t| ≤ 1`, radians: two half-angle reductions to
/// `|t| ≤ tan(π/16)`, then the odd Taylor series to t³¹.
double _atanUnit(double t) {
  var x = t;
  for (var i = 0; i < 2; i++) {
    x = x / (1.0 + detSqrt(1.0 + x * x));
  }
  final x2 = x * x;
  var sum = 0.0;
  for (var k = 31; k >= 3; k -= 2) {
    sum = sum * x2 + ((k ~/ 2).isEven ? 1.0 : -1.0) / k;
  }
  return 4.0 * (x + x * x2 * sum);
}

/// `atan2(y, x)` in **degrees**, in `[0, 360)` (0 when both are 0).
/// Deterministic; used to read a colour's OKLCH hue (e.g. for names).
double detAtan2Deg(double y, double x) {
  if (x == 0 && y == 0) return 0;
  final ax = x < 0 ? -x : x;
  final ay = y < 0 ? -y : y;
  // Angle in the first octant pair, radians.
  final a = ay <= ax ? _atanUnit(ay / ax) : detPi / 2 - _atanUnit(ax / ay);
  var r = a;
  if (x < 0) r = detPi - r;
  if (y < 0) r = -r;
  var deg = r * (180.0 / detPi);
  if (deg < 0) deg += 360.0;
  if (deg >= 360.0) deg -= 360.0;
  return deg;
}

/// sRGB decode of an 8-bit code to linear light (table, correctly rounded).
double decode8(int code) => srgbDecode[code & 0xFF];

/// `round(255 · encode(x))` for linear-light `x`, without `pow`: binary
/// search over the 255 thresholds `t_v = decode((v + 0.5)/255)`. Inputs
/// outside [0, 1] clamp to 0 / 255.
int encode8(double x) {
  var lo = 0;
  var hi = 255;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (x < srgbEncodeThreshold[mid]) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return lo;
}

/// Clamps [v] to `[0, 1]`.
double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
