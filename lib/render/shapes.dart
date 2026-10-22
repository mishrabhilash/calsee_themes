/// Key shapes as `material_new_shapes` polygons, and [FlatMorph] for
/// per-frame morphing (motion brief §6.3; motion-flutter §3.2).
///
/// - Every key shape is a [RoundedPolygon] generated **at the cell aspect**
///   (non-uniform scaling would distort rounded corners) and then
///   `normalized()` into the unit square.
/// - A [FlatMorph] flattens a [Morph]'s matched cubics once; each frame it
///   lerps them into a reused [Path] (≈ 0.3–1.1 µs, no allocation).
/// - [KeyShapeCache] builds morphs ahead of time ([KeyShapeCache.prepare])
///   so a commit frame never constructs a [Morph]; painters only look up.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import 'package:meta/meta.dart';

/// One resolved key outline: a [KeyShapeKind] (plus the Material shape id
/// for [KeyShapeKind.m3eMorph]) and its corner radius as a fraction of the
/// short side (0–0.5).
@immutable
final class KeyGeometry {
  const KeyGeometry(this.kind, {this.m3eShape, this.cornerPermille = 300});

  /// A rounded rectangle with [cornerPermille] / 1000 of the short side.
  const KeyGeometry.roundedRect(int cornerPermille)
    : this(KeyShapeKind.roundedRect, cornerPermille: cornerPermille);

  /// A full-round key: a circle in a square cell, a stadium otherwise.
  static const KeyGeometry fullRound = KeyGeometry(
    KeyShapeKind.pill,
    cornerPermille: 500,
  );

  /// Outline kind.
  final KeyShapeKind kind;

  /// Material shape id ([KeyShapeKind.m3eMorph] only).
  final M3eShape? m3eShape;

  /// Corner radius, fraction of the short side × 1000 (0–500).
  final int cornerPermille;

  /// Corner radius as a fraction of the short side, clamped to 0–0.5.
  double get cornerFraction => (cornerPermille / 1000).clamp(0.0, 0.5);

  /// Whether this outline is a (rounded) rectangle family shape whose
  /// corners scale exactly with the short side (circle, pill, squircle…).
  bool get isRectLike => switch (kind) {
    KeyShapeKind.circle ||
    KeyShapeKind.pill ||
    KeyShapeKind.roundedRect ||
    KeyShapeKind.squircle ||
    KeyShapeKind.keycap ||
    KeyShapeKind.stepped => true,
    KeyShapeKind.m3eMorph => switch (m3eShape) {
      null || M3eShape.circle || M3eShape.pill || M3eShape.square => true,
      _ => false,
    },
    KeyShapeKind.hexagon || KeyShapeKind.cut => false,
  };

  @override
  bool operator ==(Object other) =>
      other is KeyGeometry &&
      other.kind == kind &&
      other.m3eShape == m3eShape &&
      other.cornerPermille == cornerPermille;

  @override
  int get hashCode => Object.hash(kind, m3eShape, cornerPermille);

  @override
  String toString() => 'KeyGeometry(${kind.name}, $m3eShape, $cornerPermille)';
}

/// The polygon for [geometry] at cell [aspect] (width / height),
/// normalized into the unit square (the long side spans 0–1, the short
/// side is centred).
RoundedPolygon keyPolygon(KeyGeometry geometry, double aspect) {
  final a = aspect.isFinite && aspect > 0 ? aspect : 1.0;
  final shortSide = math.min(a, 1);
  RoundedPolygon rect(double radiusFraction, {double smoothing = 0}) =>
      RoundedPolygon.rectangle(
        width: a,
        height: 1,
        rounding: CornerRounding(
          radius: radiusFraction.clamp(0.0, 0.5) * shortSide,
          smoothing: smoothing,
        ),
        centerX: a / 2,
        centerY: 0.5,
      );
  RoundedPolygon stretched(RoundedPolygon unit) =>
      _normalize(unit).transformed((x, y) => (x * a, y));

  final f = geometry.cornerFraction;
  final polygon = switch (geometry.kind) {
    KeyShapeKind.circle || KeyShapeKind.pill => rect(0.5),
    KeyShapeKind.roundedRect ||
    KeyShapeKind.keycap ||
    KeyShapeKind.stepped => rect(f),
    KeyShapeKind.squircle => rect(f, smoothing: 0.6),
    KeyShapeKind.hexagon => stretched(
      RoundedPolygon.fromVerticesNum(
        6,
        radius: 0.5,
        centerX: 0.5,
        centerY: 0.5,
        rounding: CornerRounding(radius: f * 0.5),
      ),
    ),
    KeyShapeKind.cut => _cutRect(a, f * shortSide),
    KeyShapeKind.m3eMorph => switch (geometry.m3eShape) {
      null || M3eShape.circle || M3eShape.pill => rect(0.5),
      M3eShape.square => rect(0.3),
      final shape => stretched(materialShape(shape)),
    },
  };
  return _normalize(polygon);
}

/// Like `RoundedPolygon.normalized()`, but with exact (not control-point)
/// bounds, so the drawn outline really spans the unit square.
RoundedPolygon _normalize(RoundedPolygon polygon) {
  final b = polygon.calculateBounds(approximate: false);
  final width = b[2] - b[0];
  final height = b[3] - b[1];
  final side = math.max(width, height);
  if (side <= 0) return polygon;
  final offsetX = (side - width) / 2 - b[0];
  final offsetY = (side - height) / 2 - b[1];
  return polygon.transformed(
    (x, y) => ((x + offsetX) / side, (y + offsetY) / side),
  );
}

RoundedPolygon _cutRect(double a, double cut) {
  final c = cut.clamp(0.0, math.min(a, 1) / 2);
  return RoundedPolygon.fromVertices(
    [
      c, 0, a - c, 0, a, c, a, 1 - c, //
      a - c, 1, c, 1, 0, 1 - c, 0, c,
    ],
    centerX: a / 2,
    centerY: 0.5,
  );
}

/// The `MaterialShapes` polygon for [shape] (unit square).
RoundedPolygon materialShape(M3eShape shape) => switch (shape) {
  M3eShape.circle => MaterialShapes.circle,
  M3eShape.square => MaterialShapes.square,
  M3eShape.slanted => MaterialShapes.slanted,
  M3eShape.arch => MaterialShapes.arch,
  M3eShape.semiCircle => MaterialShapes.semiCircle,
  M3eShape.oval => MaterialShapes.oval,
  M3eShape.pill => MaterialShapes.pill,
  M3eShape.triangle => MaterialShapes.triangle,
  M3eShape.arrow => MaterialShapes.arrow,
  M3eShape.fan => MaterialShapes.fan,
  M3eShape.diamond => MaterialShapes.diamond,
  M3eShape.clamShell => MaterialShapes.clamShell,
  M3eShape.pentagon => MaterialShapes.pentagon,
  M3eShape.gem => MaterialShapes.gem,
  M3eShape.sunny => MaterialShapes.sunny,
  M3eShape.verySunny => MaterialShapes.verySunny,
  M3eShape.cookie4Sided => MaterialShapes.cookie4Sided,
  M3eShape.cookie6Sided => MaterialShapes.cookie6Sided,
  M3eShape.cookie7Sided => MaterialShapes.cookie7Sided,
  M3eShape.cookie9Sided => MaterialShapes.cookie9Sided,
  M3eShape.cookie12Sided => MaterialShapes.cookie12Sided,
  M3eShape.ghostish => MaterialShapes.ghostish,
  M3eShape.clover4Leaf => MaterialShapes.clover4Leaf,
  M3eShape.clover8Leaf => MaterialShapes.clover8Leaf,
  M3eShape.burst => MaterialShapes.burst,
  M3eShape.softBurst => MaterialShapes.softBurst,
  M3eShape.boom => MaterialShapes.boom,
  M3eShape.softBoom => MaterialShapes.softBoom,
  M3eShape.flower => MaterialShapes.flower,
  M3eShape.puffy => MaterialShapes.puffy,
  M3eShape.puffyDiamond => MaterialShapes.puffyDiamond,
  M3eShape.pixelCircle => MaterialShapes.pixelCircle,
  M3eShape.pixelTriangle => MaterialShapes.pixelTriangle,
  M3eShape.bun => MaterialShapes.bun,
  M3eShape.heart => MaterialShapes.heart,
};

// ------------------------------------------------------------- FlatMorph --

/// A [Morph] flattened to two coordinate arrays (8 doubles per cubic:
/// anchor0, control0, control1, anchor1) so a frame only lerps numbers
/// into a reused [Path] (motion-flutter §3.2). `asCubics(t)` is a pure
/// per-coordinate lerp of the same matched pairs, so this is exact.
///
/// Progress outside [0, 1] extrapolates like [Morph] does (overshoot).
final class FlatMorph {
  /// Flattens [morph] (calls `asCubics` twice; build it ahead of time).
  factory FlatMorph.fromMorph(Morph morph) =>
      FlatMorph.fromCubics(morph.asCubics(0), morph.asCubics(1));

  /// A morph between two matched cubic lists of equal length.
  FlatMorph.fromCubics(List<Cubic> start, List<Cubic> end)
    : assert(start.length == end.length, 'unmatched cubics'),
      _a = _flatten(start),
      _b = _flatten(end) {
    _bounds = _computeBounds();
  }

  /// A degenerate "morph" that always draws [polygon].
  factory FlatMorph.still(RoundedPolygon polygon) =>
      FlatMorph.fromCubics(polygon.cubics, polygon.cubics);

  final Float64List _a;
  final Float64List _b;
  late final Rect _bounds;

  /// Number of cubics.
  int get cubicCount => _a.length ~/ 8;

  /// Control-point bounds covering both endpoints (unit-square space). The
  /// drawn shape lies inside it for progress in [0, 1].
  Rect get bounds => _bounds;

  static Float64List _flatten(List<Cubic> cubics) {
    final out = Float64List(cubics.length * 8);
    var i = 0;
    for (final c in cubics) {
      out[i++] = c.anchor0X;
      out[i++] = c.anchor0Y;
      out[i++] = c.control0X;
      out[i++] = c.control0Y;
      out[i++] = c.control1X;
      out[i++] = c.control1Y;
      out[i++] = c.anchor1X;
      out[i++] = c.anchor1Y;
    }
    return out;
  }

  Rect _computeBounds() {
    if (_a.isEmpty) return Rect.zero;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = -double.infinity;
    var maxY = -double.infinity;
    for (final list in [_a, _b]) {
      for (var i = 0; i < list.length; i += 2) {
        minX = math.min(minX, list[i]);
        maxX = math.max(maxX, list[i]);
        minY = math.min(minY, list[i + 1]);
        maxY = math.max(maxY, list[i + 1]);
      }
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Coordinate [index] (0 ≤ index < 8 × [cubicCount]) at progress [t].
  double coordinate(int index, double t) =>
      _a[index] + (_b[index] - _a[index]) * t;

  /// Every coordinate at progress [t] (tests; allocates).
  List<double> coordinatesAt(double t) => [
    for (var i = 0; i < _a.length; i++) coordinate(i, t),
  ];

  /// Resets [path] to the shape at progress [t] and returns it.
  Path toPath(double t, Path path) {
    path.reset();
    if (_a.isEmpty) return path;
    final a = _a;
    final b = _b;
    double l(int i) => a[i] + (b[i] - a[i]) * t;
    path.moveTo(l(0), l(1));
    for (var i = 0; i < a.length; i += 8) {
      path.cubicTo(l(i + 2), l(i + 3), l(i + 4), l(i + 5), l(i + 6), l(i + 7));
    }
    return path..close();
  }
}

// ----------------------------------------------------------- shape cache --

/// A rest → pressed key morph at one cell aspect, ready to paint.
final class KeyMorph {
  KeyMorph({
    required this.rest,
    required this.pressed,
    required this.aspect,
    required this.flat,
  });

  /// Resting outline.
  final KeyGeometry rest;

  /// Pressed outline.
  final KeyGeometry pressed;

  /// Cell aspect (width / height) it was built for (quantised).
  final double aspect;

  /// The flattened morph (unit square).
  final FlatMorph flat;

  /// Resets [path] to the outline at press [t] (0 rest, 1 pressed),
  /// scaled into [size] (the polygon's unit-square box maps onto the
  /// cell, so the shape fills it exactly).
  Path pathFor(double t, Size size, Path path) {
    flat.toPath(t, path);
    final scale = math.max(size.width, size.height);
    final dx = (size.width - scale) / 2;
    final dy = (size.height - scale) / 2;
    final matrix = Float64List(16)
      ..[0] = scale
      ..[5] = scale
      ..[10] = 1
      ..[12] = dx
      ..[13] = dy
      ..[15] = 1;
    return path.transform(matrix);
  }

  /// Applies the unit-square → cell transform for [size] to [canvas]
  /// (prefer this to [pathFor]: no allocation).
  static void applyTransform(Canvas canvas, Size size) {
    final scale = math.max(size.width, size.height);
    canvas
      ..translate((size.width - scale) / 2, (size.height - scale) / 2)
      ..scale(scale);
  }
}

/// Builds and caches [KeyMorph]s by (rest, pressed, aspect).
///
/// Call [prepare] when a theme enters the feed's prefetch queue or when
/// the keypad lays out, so painters only ever hit the cache. A miss in a
/// paint builds synchronously (correct, but slower) and is counted in
/// [misses] so tests can assert the commit frame never builds.
final class KeyShapeCache {
  KeyShapeCache({this.capacity = 256});

  /// The app-wide cache.
  static final KeyShapeCache instance = KeyShapeCache();

  /// Maximum entries kept (least recently used are evicted).
  final int capacity;

  final LinkedHashMap<(KeyGeometry, KeyGeometry, int), KeyMorph> _entries =
      LinkedHashMap();

  /// Lookups that had to build a morph.
  int misses = 0;

  /// Morphs built by [prepare].
  int prepared = 0;

  /// Entries cached.
  int get length => _entries.length;

  /// [aspect] quantised to 1/100 (the cache key).
  static int aspectKey(double aspect) =>
      (aspect.isFinite && aspect > 0 ? aspect * 100 : 100).round().clamp(
        10,
        1000,
      );

  /// Size → aspect, with empty sizes treated as square.
  static double aspectOf(Size size) =>
      size.height > 0 && size.width > 0 ? size.width / size.height : 1;

  /// Builds (if needed) the morph for [rest] → [pressed] at [aspect].
  KeyMorph prepare(KeyGeometry rest, KeyGeometry pressed, double aspect) {
    final key = (rest, pressed, aspectKey(aspect));
    final hit = _entries.remove(key);
    if (hit != null) return _entries[key] = hit;
    prepared++;
    return _insert(key, _build(rest, pressed, key.$3 / 100));
  }

  /// The cached morph, building it on a miss.
  KeyMorph lookup(KeyGeometry rest, KeyGeometry pressed, double aspect) {
    final key = (rest, pressed, aspectKey(aspect));
    final hit = _entries.remove(key);
    if (hit != null) return _entries[key] = hit;
    misses++;
    return _insert(key, _build(rest, pressed, key.$3 / 100));
  }

  /// Whether the morph is cached.
  bool contains(KeyGeometry rest, KeyGeometry pressed, double aspect) =>
      _entries.containsKey((rest, pressed, aspectKey(aspect)));

  /// Drops every entry.
  void clear() {
    _entries.clear();
    misses = 0;
    prepared = 0;
  }

  KeyMorph _insert((KeyGeometry, KeyGeometry, int) key, KeyMorph morph) {
    _entries[key] = morph;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
    return morph;
  }

  static KeyMorph _build(KeyGeometry rest, KeyGeometry pressed, double a) {
    final from = keyPolygon(rest, a);
    final flat = rest == pressed
        ? FlatMorph.still(from)
        : FlatMorph.fromMorph(Morph(from, keyPolygon(pressed, a)));
    return KeyMorph(rest: rest, pressed: pressed, aspect: a, flat: flat);
  }
}
