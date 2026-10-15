/// Cyberpunk key geometry: the chamfered plate (top-left and bottom-right
/// cut), its edge line, HUD ticks, bloom bands, the lite-tier glow ring and
/// the blurred halo image, built once per key size and kept in small
/// static LRUs ([CyberKeyGeometry.cached], [CyberKeyGeometry.transient],
/// [CyberHalo.forPlate]) so the per-frame painter recreation of a theme
/// transition never rebuilds them.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The device pixel ratio Cyberpunk artwork snaps to: the implicit view's,
/// else the first view's, else 1 (no view attached).
double cyberDevicePixelRatio() {
  final dispatcher = ui.PlatformDispatcher.instance;
  final view =
      dispatcher.implicitView ??
      (dispatcher.views.isEmpty ? null : dispatcher.views.first);
  final dpr = view?.devicePixelRatio ?? 1;
  return dpr > 0 && dpr.isFinite ? dpr : 1;
}

/// The 45° offset factor of a chamfer: insetting every edge of a cut
/// octagon by δ shortens its chamfer legs by `(2 − √2)·δ`.
const double cyberChamferInsetFactor = 0.5857864376269049;

/// Adds the cut octagon of [r] (top-left and bottom-right corners cut by
/// [c], the other two square) to [path] and returns it: (L+c, T) → (R, T)
/// → (R, B−c) → (R−c, B) → (L, B) → (L, T+c).
Path addCutOctagon(Path path, Rect r, double c) {
  final k = math.max(0, math.min(c, r.shortestSide / 2)).toDouble();
  return path
    ..moveTo(r.left + k, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom - k)
    ..lineTo(r.right - k, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + k)
    ..close();
}

/// The cut octagon of [r] offset by [delta] (inward when positive): the
/// rect deflated by [delta] with its chamfer shortened by the 45° factor.
Path addInsetCutOctagon(Path path, Rect r, double c, double delta) =>
    addCutOctagon(
      path,
      r.deflate(delta),
      math.max(0, c - cyberChamferInsetFactor * delta),
    );

/// The plate geometry of one key size.
final class CyberKeyGeometry {
  /// Builds the geometry of a key box of [size].
  new build(
    Size size, {
    required double chamfer,
    required double edgeWidth,
    required double plunge,
  }) {
    final s = size.shortestSide;
    inset = (0.045 * s).clamp(2.0, 3.5);
    depth = math.max(0, math.min(plunge, s / 16)).toDouble();
    face = Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset - depth,
    );
    final short = math.max(0, face.shortestSide).toDouble();
    cut = (chamfer * short).clamp(0.0, 0.30 * short);
    edge = math.max(0, math.min(edgeWidth, s / 24)).toDouble();
    if (face.width <= 0 || face.height <= 0) {
      inner = face;
      return;
    }
    addCutOctagon(facePath, face, cut);
    addInsetCutOctagon(edgePath, face, cut, edge / 2);
    addInsetCutOctagon(insetEdgePath, face, cut, edge / 2 + 1.5);
    inner = face.deflate(edge);
    addInsetCutOctagon(innerPath, face, cut, edge);
    // HUD ticks: L-brackets at the square corners (top-right, bottom-left).
    // Each arm ends above the label zone (26 % of the plate height).
    if (s >= 36) {
      void ticks(Path path, double i) {
        final a = math.min((0.14 * s).clamp(4.0, 9.0), 0.26 * face.height - i);
        if (a < 2) return;
        path
          ..moveTo(face.right - i - a, face.top + i)
          ..lineTo(face.right - i, face.top + i)
          ..lineTo(face.right - i, face.top + i + a)
          ..moveTo(face.left + i, face.bottom - i - a)
          ..lineTo(face.left + i, face.bottom - i)
          ..lineTo(face.left + i + a, face.bottom - i);
      }

      ticks(tickPath, edge + 2);
      ticks(insetTickPath, edge + 3.5);
    }
    // Bloom bands: the top and bottom 16 % of the plate (outside the label
    // zone), each clipped to the octagon analytically; the light hugs the
    // neon line (most of it in the outer 5 %).
    final band = face.height * bloomBand;
    final l = face.left;
    final t = face.top;
    final r = face.right;
    final b = face.bottom;
    final c = cut;
    if (band >= c) {
      bloomPath
        ..moveTo(l + c, t)
        ..lineTo(r, t)
        ..lineTo(r, t + band)
        ..lineTo(l, t + band)
        ..lineTo(l, t + c)
        ..close()
        ..moveTo(l, b - band)
        ..lineTo(r, b - band)
        ..lineTo(r, b - c)
        ..lineTo(r - c, b)
        ..lineTo(l, b)
        ..close();
    } else {
      bloomPath
        ..moveTo(l + c, t)
        ..lineTo(r, t)
        ..lineTo(r, t + band)
        ..lineTo(l + c - band, t + band)
        ..close()
        ..moveTo(l, b - band)
        ..lineTo(r - c + band, b - band)
        ..lineTo(r - c, b)
        ..lineTo(l, b)
        ..close();
    }
    bloomShader = ui.Gradient.linear(
      Offset(0, t),
      Offset(0, b),
      const [
        Color(0x66FFFFFF),
        Color(0x1FFFFFFF),
        Color(0x00FFFFFF),
        Color(0x00FFFFFF),
        Color(0x1FFFFFFF),
        Color(0x66FFFFFF),
      ],
      const [0, 0.05, bloomBand, 1 - bloomBand, 0.95, 1],
    );
    // Lite tier: one un-blurred glow ring, 2 dp wide, centred 1.5 dp
    // outside the plate.
    addInsetCutOctagon(liteRing, face, cut, -1.5);
  }

  /// The cached geometry for a key box of [size] (built on a miss).
  factory cached(
    Size size, {
    required double chamfer,
    required double edgeWidth,
    required double plunge,
  }) {
    final key = (size, chamfer, edgeWidth, plunge);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    builds++;
    final g = _cache[key] = CyberKeyGeometry.build(
      size,
      chamfer: chamfer,
      edgeWidth: edgeWidth,
      plunge: plunge,
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return g;
  }

  /// The geometry of an in-between face of a theme transition (values
  /// already quantised by the caller), from a second LRU so a transition
  /// never evicts the steady-state entries of `cached`.
  factory transient(
    Size size, {
    required double chamfer,
    required double edgeWidth,
    required double plunge,
  }) {
    final key = (size, chamfer, edgeWidth, plunge);
    final hit = _transient.remove(key);
    if (hit != null) return _transient[key] = hit;
    transientBuilds++;
    final g = _transient[key] = CyberKeyGeometry.build(
      size,
      chamfer: chamfer,
      edgeWidth: edgeWidth,
      plunge: plunge,
    );
    while (_transient.length > transientCapacity) {
      _transient.remove(_transient.keys.first);
    }
    return g;
  }

  /// The bloom bands' height (fraction of the plate).
  static const double bloomBand = 0.16;

  /// The face inset inside the key box, dp.
  late final double inset;

  /// The press plunge, dp.
  late final double depth;

  /// The plate at rest.
  late final Rect face;

  /// The chamfer leg, dp.
  late final double cut;

  /// The edge line width, dp.
  late final double edge;

  /// The plate inside its edge line (the hold bar's box).
  late final Rect inner;

  /// The plate outline (fill).
  final Path facePath = Path();

  /// The edge line's centre path (stroke at [edge]).
  final Path edgePath = Path();

  /// The edge line inset 1.5 dp more (Hazard plates: a black rim between
  /// the neon line and the yellow body).
  final Path insetEdgePath = Path();

  /// The plate inside its edge line (the hold bar's clip).
  final Path innerPath = Path();

  /// The two HUD corner ticks (stroke at 1 dp).
  final Path tickPath = Path();

  /// The ticks moved 1.5 dp further in, clear of [insetEdgePath].
  final Path insetTickPath = Path();

  /// The top and bottom bloom bands.
  final Path bloomPath = Path();

  /// White → clear → white α ramp over the plate's height (tinted by a
  /// colour filter at paint time, so it never embeds a role colour).
  late final ui.Shader bloomShader;

  /// The lite-tier glow ring (stroke at 2 dp), centred 1.5 dp outside
  /// the plate.
  final Path liteRing = Path();

  /// Geometries built through `cached` (tests).
  static int builds = 0;

  /// Geometries built through `transient` (tests).
  static int transientBuilds = 0;

  /// Geometries kept by `cached`.
  static const int capacity = 32;

  /// Geometries kept by `transient`.
  static const int transientCapacity = 64;

  static final LinkedHashMap<(Size, double, double, double), CyberKeyGeometry>
  _cache = LinkedHashMap();

  static final LinkedHashMap<(Size, double, double, double), CyberKeyGeometry>
  _transient = LinkedHashMap();

  /// Forgets every cached geometry (tests).
  static void clearCache() {
    _cache.clear();
    _transient.clear();
    builds = 0;
    transientBuilds = 0;
  }
}

/// A key's halo: a white cut octagon blurred once into a small nine-slice
/// image (the blur follows the chamfers, which a blurred rounded rect
/// would fill in), drawn per frame with one `drawImageNine` tinted by a
/// colour filter. The corners are fixed-size slices and only the straight
/// edges stretch, so one image serves every key size with the same chamfer
/// leg (quantised to 0.5 dp, invisible under the blur) and blur.
///
/// A plate too small for the fixed corners (each `2·pad + chamfer` dp, so
/// keys under about 40 dp tall at σ 2.5) would squash them and distort the
/// glow: such a plate gets an exact image of its own size instead
/// ([center] null; drawn with `drawImageRect`).
final class CyberHalo {
  new _(this.image, this.center, this.pad);

  /// The halo for [plate] with chamfer leg [cut] blurred by [sigma] dp:
  /// the shared nine-slice image when the plate fits its corners, else an
  /// exact image of the plate's size (quantised to 0.5 dp).
  factory forPlate(Rect plate, double cut, double sigma) {
    final c = (math.max(0, cut) * 2).round() / 2;
    final pad = padFor(sigma);
    final corners = 2 * (2 * pad + c);
    if (plate.width >= corners && plate.height >= corners) {
      return CyberHalo.cached(cut, sigma);
    }
    return CyberHalo._build(
      c,
      sigma,
      Size(
        math.max(1, (plate.width * 2).round() / 2).toDouble(),
        math.max(1, (plate.height * 2).round() / 2).toDouble(),
      ),
    );
  }

  /// The nine-slice halo of a plate with chamfer leg [cut] blurred by
  /// [sigma] dp (built on a miss; evicted images are disposed — pictures
  /// that drew them keep their own reference).
  factory cached(double cut, double sigma) =>
      CyberHalo._build((math.max(0, cut) * 2).round() / 2, sigma, null);

  factory _build(double c, double sigma, Size? exact) {
    final key = (c, sigma, exact);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    builds++;
    final pad = padFor(sigma);
    // Nine-slice: a square plate whose straight edges reach past the
    // corners' blur; exact: the plate itself.
    final side = 2 * (c + pad) + 2;
    final plateSize = exact ?? Size(side, side);
    final plate = Offset(pad, pad) & plateSize;
    final w = plateSize.width + 2 * pad;
    final h = plateSize.height + 2 * pad;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    canvas.drawPath(
      addCutOctagon(Path(), plate, c),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      math.max(1, (w * scale).ceil()),
      math.max(1, (h * scale).ceil()),
    );
    picture.dispose();
    final from = (2 * pad + c) * scale;
    final halo = _cache[key] = CyberHalo._(
      image,
      exact == null ? Rect.fromLTWH(from, from, 2 * scale, 2 * scale) : null,
      pad,
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first)?.image.dispose();
    }
    return halo;
  }

  /// How far a halo of blur [sigma] reaches past its plate, dp.
  static double padFor(double sigma) => (sigma * 3 + 1.5).ceilToDouble();

  /// The blurred plate, white on clear, rasterised at [scale]×.
  final ui.Image image;

  /// The stretchable slice, in image pixels; null for an exact image.
  final Rect? center;

  /// How far the image reaches past the plate on every side, dp.
  final double pad;

  /// Rasterisation scale (the blur hides resampling).
  static const double scale = 2;

  /// Halos built (tests).
  static int builds = 0;

  /// Halos kept.
  static const int capacity = 24;

  static final LinkedHashMap<(double, double, Size?), CyberHalo> _cache =
      LinkedHashMap();

  /// Forgets (and disposes) every cached halo (tests).
  static void clearCache() {
    for (final h in _cache.values) {
      h.image.dispose();
    }
    _cache.clear();
    builds = 0;
  }
}
