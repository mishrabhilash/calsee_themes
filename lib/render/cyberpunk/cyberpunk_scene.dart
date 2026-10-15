/// Cyberpunk background scene (`BackgroundKind.cyberGrid`): a static
/// circuit board at night.
///
/// `BackgroundSpec.colors`: `[0]` body (top stop), `[1]` haze (the street
/// glow, bottom stop), `[2]` grid ink (alpha 0 on Hazard: no grid), `[3]`
/// trace / via ink, `[4]` scanline ink (the three inks translucent);
/// `angleTenths` tilts the gradient. Paint order (the guardrail sample
/// model, `cyberGridSamples`): the body → haze gradient; a 32 dp grid of
/// 1 dp lines, every fourth line drawn twice (a brighter major line);
/// routed traces with via rings coming in from the screen edges; 1 dp
/// scanlines every 3 dp over everything.
///
/// - **Calm text area:** the grid and scanlines are faint textures drawn
///   everywhere (no hard edge at the display); traces are laid out only
///   below `textSafeArea` (the HUD panel covers the display text anyway).
/// - **Static:** no drift, no clock; Reduce Motion and the lite tier
///   change nothing. Trace slots are anchored to the bottom edge with a
///   constant seed, so resizing a window adds or removes whole traces
///   instead of re-rolling the board.
/// - **Crisp:** grid lines and scanlines snap to device pixels (no moiré
///   at 2.625× or 2.75×).
/// - **Cheap:** the whole scene is one `ui.Picture` in the shared
///   `BackgroundCache` (`scene.cache.scenePicture`), keyed by the spec, the
///   size, the trace floor and the device pixel ratio. The geometry (about
///   350 rects) is cached apart from the colours ([CyberSceneGeometry.cached]),
///   so a theme transition, whose colours change every frame, re-records
///   only five draws per frame.
/// - **Same board in every theme:** the trace layout is a renderer
///   constant. A per-theme layout would have to come from the colours,
///   and mid-transition the scene sees only the blended colours: the board
///   would re-roll on every frame of a theme change.
library;

import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/render/background_painter.dart';
import 'package:calsee_themes/render/cyberpunk/cyber_geometry.dart';
import 'package:flutter/widgets.dart';

/// Grid cell, dp (off the 12–28 dp pattern pitches of NeoPOP and
/// Neo-brutalism).
const double cyberGridCell = 32;

/// Every this many grid lines is a major line (drawn twice).
const int cyberGridMajorEvery = 4;

/// Scanline pitch, dp (1 dp rows).
const double cyberScanPitch = 3;

/// Trace lattice, dp.
const double cyberTraceStep = 12;

/// Trace stroke width, dp.
const double cyberTraceWidth = 1.25;

/// Via ring radius, dp.
const double cyberViaRadius = 2.5;

/// Trace slots (anchored to the bottom edge).
const int cyberTraceSlots = 16;

/// The scene geometry of one size (device-pixel snapped at `dpr`).
final class CyberSceneGeometry {
  /// Builds the geometry of a canvas of [size] whose traces stay below
  /// [safeBottom].
  new(Size size, {required double safeBottom, double dpr = 1}) {
    final w = size.width;
    final h = size.height;
    final px = dpr > 0 && dpr.isFinite ? dpr : 1.0;
    double snap(double v) => (v * px).roundToDouble() / px;
    final line = math.max(1, px.round()) / px;
    // Grid: 1 dp lines on a 32 dp lattice centred horizontally, anchored
    // to the top; majors every fourth line.
    final x0 = (w % cyberGridCell) / 2;
    var i = 0;
    for (var x = x0; x < w; x += cyberGridCell, i++) {
      final r = Rect.fromLTWH(snap(x), 0, line, h);
      grid.addRect(r);
      if (i % cyberGridMajorEvery == 0) major.addRect(r);
    }
    i = 0;
    for (var y = 0.0; y < h; y += cyberGridCell, i++) {
      final r = Rect.fromLTWH(0, snap(y), w, line);
      grid.addRect(r);
      if (i % cyberGridMajorEvery == 0) major.addRect(r);
    }
    for (var y = 0.0; y < h; y += cyberScanPitch) {
      scan.addRect(Rect.fromLTWH(0, snap(y), w, line));
    }
    _traces(w, h, safeBottom);
  }

  /// The cached geometry of [size] (built on a miss).
  factory cached(Size size, {required double safeBottom, double dpr = 1}) {
    final key = (size, safeBottom, dpr);
    final hit = _cache.remove(key);
    if (hit != null) return _cache[key] = hit;
    builds++;
    final g = _cache[key] = CyberSceneGeometry(
      size,
      safeBottom: safeBottom,
      dpr: dpr,
    );
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return g;
  }

  /// Geometries built through `cached` (tests).
  static int builds = 0;

  /// Geometries kept.
  static const int capacity = 4;

  static final LinkedHashMap<(Size, double, double), CyberSceneGeometry>
  _cache = LinkedHashMap();

  /// The grid lines (fill).
  final Path grid = Path();

  /// The major grid lines, drawn a second time over [grid] (fill).
  final Path major = Path();

  /// Traces and via rings (stroke).
  final Path traces = Path();

  /// The scanlines (fill).
  final Path scan = Path();

  /// Trace slots drawn.
  int traceCount = 0;

  /// [cyberTraceSlots] fixed trace slots anchored to the bottom edge: slot
  /// k sits 12·(4 + 5k + r) dp above it, alternating screen sides, with a
  /// fixed run in, a 45° jog and a second run ending in a via ring; one in
  /// three is a three-line bus. Only slots between [safeBottom] and the
  /// bottom margin are drawn.
  void _traces(double w, double h, double safeBottom) {
    var x = 0x9E3779B9;
    int next() {
      x ^= (x << 13) & 0xFFFFFFFF;
      x ^= x >>> 17;
      x ^= (x << 5) & 0xFFFFFFFF;
      x &= 0xFFFFFFFF;
      return x;
    }

    const step = cyberTraceStep;
    final top = safeBottom + step;
    for (var k = 0; k < cyberTraceSlots; k++) {
      final r = next() % 3;
      final run1 = 2 + next() % 5;
      final jog = 1 + next() % 3;
      final up = next().isEven;
      final run2 = 1 + next() % 4;
      final bus = next() % 3 == 0;
      final y = h - step * (4 + 5 * k + r);
      if (y < top || y > h - step) continue;
      final left = k.isEven;
      final dir = left ? 1.0 : -1.0;
      final xStart = left ? 0.0 : w;
      final dy = (up ? -1.0 : 1.0) * jog * step;
      var drawn = false;
      for (final o in bus ? const [-4.0, 0.0, 4.0] : const [0.0]) {
        final y0 = y + o;
        final x1 = xStart + dir * run1 * step;
        final x2 = x1 + dir * jog * step;
        final x3 = x2 + dir * run2 * step;
        final yEnd = y0 + dy;
        if (yEnd < top - 4 || yEnd > h - 4) continue;
        drawn = true;
        traces
          ..moveTo(xStart, y0)
          ..lineTo(x1, y0)
          ..lineTo(x2, yEnd)
          ..lineTo(x3 - dir * cyberViaRadius, yEnd)
          ..addOval(
            Rect.fromCircle(center: Offset(x3, yEnd), radius: cyberViaRadius),
          );
      }
      if (drawn) traceCount++;
    }
  }
}

/// Paints the Cyberpunk scene for [scene] over the whole canvas.
void paintCyberpunkScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty || !size.isFinite) return;
  final spec = scene.spec;
  final colors = spec.colors;
  if (colors.length < 5) {
    scene.paintFallback(canvas, size);
    return;
  }
  final safe = scene.textSafeArea;
  final safeBottom = safe == null
      ? 0.0
      : safe.bottom.clamp(0.0, size.height).roundToDouble();
  final fade = scene.patternFade;
  final dpr = cyberDevicePixelRatio();
  final picture = scene.cache.scenePicture((
    spec,
    size,
    safeBottom,
    fade,
    dpr,
  ), () => _record(size, spec.colors, spec.angleTenths, safeBottom, fade, dpr));
  canvas.drawPicture(picture);
}

ui.Picture _record(
  Size size,
  List<int> colors,
  int angleTenths,
  double safeBottom,
  double fade,
  double dpr,
) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final c0 = Color(colors[0] | 0xFF000000);
  final c1 = Color(colors[1] | 0xFF000000);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..shader = linearGradientShader(size, [c0, c1], angleTenths),
  );
  if (fade > 0) {
    final geo = CyberSceneGeometry.cached(
      size,
      safeBottom: safeBottom,
      dpr: dpr,
    );
    Paint ink(int argb) {
      final c = Color(argb);
      return Paint()..color = c.withValues(alpha: c.a * fade);
    }

    if ((colors[2] >>> 24) > 0) {
      final grid = ink(colors[2]);
      canvas
        ..drawPath(geo.grid, grid)
        ..drawPath(geo.major, grid);
    }
    canvas
      ..drawPath(
        geo.traces,
        ink(colors[3])
          ..style = PaintingStyle.stroke
          ..strokeWidth = cyberTraceWidth
          ..strokeJoin = StrokeJoin.miter
          ..strokeCap = StrokeCap.butt,
      )
      ..drawPath(geo.scan, ink(colors[4]));
  }
  return recorder.endRecording();
}
