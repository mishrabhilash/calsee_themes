/// An in-house 7-segment glyph painter (docs/m4-design.md §B: "7-segment
/// LCD display drawn with an in-house segment painter, no font download").
///
/// Segments are named the standard way:
///
/// ```text
///    aaa
///   f   b
///   f   b
///    ggg
///   e   c
///   e   c
///    ddd   (dp)
/// ```
///
/// [SevenSegment.glyphs] maps every character the display draws this way
/// (digits, minus, `E`) to its segment mask; `.` and `,` are drawn as the
/// decimal point (a comma gets a tail). [SegmentGlyphPainter] turns a mask
/// into bevelled hexagonal bars inside a glyph rectangle, slanted like a
/// real LCD, with the unlit segments in a ghost colour.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:meta/meta.dart';

/// Segment bits and the character → segment table.
abstract final class SevenSegment {
  /// Top.
  static const int a = 1;

  /// Upper right.
  static const int b = 1 << 1;

  /// Lower right.
  static const int c = 1 << 2;

  /// Bottom.
  static const int d = 1 << 3;

  /// Lower left.
  static const int e = 1 << 4;

  /// Upper left.
  static const int f = 1 << 5;

  /// Middle.
  static const int g = 1 << 6;

  /// Every segment: the ghost "8".
  static const int all = 0x7F;

  /// The seven segment bits in drawing order.
  static const List<int> segments = [a, b, c, d, e, f, g];

  /// Character → lit segments. `−` is U+2212, the display's minus sign.
  static const Map<String, int> glyphs = {
    '0': a | b | c | d | e | f,
    '1': b | c,
    '2': a | b | d | e | g,
    '3': a | b | c | d | g,
    '4': b | c | f | g,
    '5': a | c | d | f | g,
    '6': a | c | d | e | f | g,
    '7': a | b | c,
    '8': a | b | c | d | e | f | g,
    '9': a | b | c | d | f | g,
    '-': g,
    '−': g,
    'E': a | d | e | f | g,
  };

  /// Code unit → mask (a flat table: no map lookup per glyph per frame).
  static final List<int> _byUnit = () {
    final t = List<int>.filled(0x80, 0);
    for (final MapEntry(key: ch, value: mask) in glyphs.entries) {
      final u = ch.codeUnitAt(0);
      if (u < 0x80) t[u] = mask;
    }
    return t;
  }();

  /// The segment mask of [codeUnit], or 0 when it is not a segment glyph.
  static int maskOfUnit(int codeUnit) {
    if (codeUnit == 0x2212) return g;
    return codeUnit < 0x80 ? _byUnit[codeUnit] : 0;
  }

  /// Whether [codeUnit] is drawn as the decimal point (`.`) or comma.
  static bool isPoint(int codeUnit) => codeUnit == 0x2E || codeUnit == 0x2C;

  /// Whether [codeUnit] is drawn by the segment painter at all.
  static bool draws(int codeUnit) =>
      maskOfUnit(codeUnit) != 0 || isPoint(codeUnit);
}

/// Geometry and painting of 7-segment glyphs.
@immutable
final class SegmentGlyphPainter {
  const SegmentGlyphPainter({
    this.thicknessRatio = 0.13,
    this.gapRatio = 0.22,
    this.slant = 0.09,
  });

  /// Segment thickness as a fraction of the glyph height.
  final double thicknessRatio;

  /// Gap between neighbouring segments as a fraction of the thickness.
  final double gapRatio;

  /// Horizontal lean per unit of height (italic LCD digits).
  final double slant;

  @override
  bool operator ==(Object other) =>
      other is SegmentGlyphPainter &&
      other.thicknessRatio == thicknessRatio &&
      other.gapRatio == gapRatio &&
      other.slant == slant;

  @override
  int get hashCode => Object.hash(thicknessRatio, gapRatio, slant);

  /// Segment thickness for a glyph of height [h] (never below 1 px).
  double thicknessFor(double h) => math.max(1, h * thicknessRatio);

  /// The outline of [segment] (one of [SevenSegment.segments]) in [rect].
  Path segmentPath(int segment, Rect rect) {
    final path = Path();
    addSegment(path, segment, rect);
    return path;
  }

  /// Adds every segment of [mask] in [rect] to [path].
  void addMask(Path path, int mask, Rect rect) {
    for (final s in SevenSegment.segments) {
      if (mask & s != 0) addSegment(path, s, rect);
    }
  }

  /// Adds the hexagonal bar of [segment] in [rect] to [path].
  void addSegment(Path path, int segment, Rect rect) {
    if (rect.width <= 0 || rect.height <= 0) return;
    final t = math.min(thicknessFor(rect.height), rect.width / 3);
    final half = t / 2;
    final gap = t * gapRatio;
    final l = rect.left + half;
    final r = rect.right - half;
    final top = rect.top + half;
    final bottom = rect.bottom - half;
    final mid = (top + bottom) / 2;
    final bottomY = rect.bottom;
    Offset pt(double x, double y) => Offset(x + (bottomY - y) * slant, y);

    void horizontal(double y) {
      final x0 = l + gap;
      final x1 = r - gap;
      if (x1 - x0 < t) {
        path.addRect(
          Rect.fromLTRB(
            x0,
            y - half,
            x1,
            y + half,
          ).shift(Offset((bottomY - y) * slant, 0)),
        );
        return;
      }
      path.addPolygon([
        pt(x0, y),
        pt(x0 + half, y - half),
        pt(x1 - half, y - half),
        pt(x1, y),
        pt(x1 - half, y + half),
        pt(x0 + half, y + half),
      ], true);
    }

    void vertical(double x, double y0, double y1) {
      final a = y0 + gap;
      final b = y1 - gap;
      if (b - a < t) {
        path.addPolygon([
          pt(x - half, a),
          pt(x + half, a),
          pt(x + half, b),
          pt(x - half, b),
        ], true);
        return;
      }
      path.addPolygon([
        pt(x, a),
        pt(x + half, a + half),
        pt(x + half, b - half),
        pt(x, b),
        pt(x - half, b - half),
        pt(x - half, a + half),
      ], true);
    }

    switch (segment) {
      case SevenSegment.a:
        horizontal(top);
      case SevenSegment.g:
        horizontal(mid);
      case SevenSegment.d:
        horizontal(bottom);
      case SevenSegment.f:
        vertical(l, top, mid);
      case SevenSegment.b:
        vertical(r, top, mid);
      case SevenSegment.e:
        vertical(l, mid, bottom);
      case SevenSegment.c:
        vertical(r, mid, bottom);
    }
  }

  /// The glyph rectangle for a character cell `[left, right]` whose text
  /// baseline is [baseline], at [fontSize]: 0.70 em tall, at most 0.55 of
  /// its height wide, centred in the cell (lean included).
  Rect glyphRect({
    required double left,
    required double right,
    required double baseline,
    required double fontSize,
  }) {
    final h = fontSize * 0.70;
    final advance = math.max(0, right - left);
    final w = math.min(advance * 0.80, h * 0.55);
    final x = left + (advance - w) / 2 - slant * h / 2;
    return Rect.fromLTWH(x, baseline - h, w, h);
  }

  /// Adds the decimal point (and a comma's tail when [comma]) for a cell
  /// `[left, right]` on [baseline] to [path].
  void addPoint(
    Path path, {
    required double left,
    required double right,
    required double baseline,
    required double fontSize,
    bool comma = false,
  }) {
    final size = thicknessFor(fontSize * 0.70) * 1.15;
    final cx = (left + right) / 2;
    final dot = Rect.fromLTWH(cx - size / 2, baseline - size, size, size);
    path.addRect(dot);
    if (comma) {
      path.addPolygon([
        Offset(dot.right, dot.bottom),
        Offset(dot.right - size * 0.15, dot.bottom + size * 0.9),
        Offset(dot.left - size * 0.35, dot.bottom + size * 0.9),
        Offset(dot.left + size * 0.3, dot.bottom),
      ], true);
    }
  }
}
