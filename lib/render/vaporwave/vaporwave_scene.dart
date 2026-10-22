/// Vaporwave background scene (`BackgroundKind.vaporSunset`): a sunset sky,
/// a striped retro sun sinking into the horizon and a neon perspective
/// grid floor whose cross lines drift slowly toward the viewer.
///
/// `BackgroundSpec.colors` (vaporwave.dart): 0 sky top, 1 sky middle,
/// 2 horizon glow, 3–5 sun top / middle / bottom, 6 floor at the horizon,
/// 7 floor at the bottom, 8 grid lines, 9 the horizon line (and the haze
/// over the far floor).
///
/// Layout (anchored to the display's text-safe area S, the toolbar plus
/// the display):
/// - **Portrait and side panel:** the horizon sits just above the keypad
///   (`S.bottom − 6`), so keys only ever cover the floor (what the
///   guardrails check them against). The display window stands in front
///   of a giant sun centred on the calculator column: its striped dome
///   rises [vaporwaveSunCrown] dp above the window's top edge (into the
///   toolbar row, between the history and settings buttons), its striped
///   sides show beside the window and full-width stripes fill the band the
///   window leaves below itself. With room beside the column (≥ 48 dp,
///   desktop) the sun is sized from the column and the margin instead
///   (radius 120–380 dp), unless a tall window would hide its top
///   (tablet portrait): then it crowns the window as on phones, up to
///   1.35× larger.
/// - **Landscape** (the display down the left): the whole scene is floor,
///   the grid vanishing at the top of the keypad column, and no sun: a sky
///   behind the keypad's top rows would put keys over colours the key
///   guardrails do not check.
/// - **No S** (previews): the horizon at `angleTenths` permille.
///
/// Display text never sits on the scene: it is on the window's opaque
/// client panel. Inside S the scene paints the sky, the sun behind and
/// beside the window (and its dome above it), and the horizon. The static
/// layers are one cached picture per (spec, size, S); a drift frame adds
/// at most twenty lines with one reused paint. The drift phase comes from
/// the ambient clock with a constant period ([vaporwaveScenePeriodMs]), so
/// a same-family transition (which drops `driftPeriodMs`) never jumps it;
/// Reduce Motion freezes it at phase 0.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/vaporwave.dart'
    show vaporwaveHazeAlpha, vaporwaveHazeAlphaLight;
import 'package:calsee_themes/render/background_painter.dart';
import 'package:calsee_themes/render/vaporwave/vaporwave_display_face.dart';
import 'package:flutter/widgets.dart';

/// One grid-line cycle of the drift, ms.
const int vaporwaveScenePeriodMs = 48000;

/// Horizon offset above the display's bottom edge (the keypad's top), dp.
const double vaporwaveHorizonLift = 6;

/// The toolbar row between the top of S and the display (mirrors
/// `ScreenLayout.toolbarHeight`, which the render layer cannot import; a
/// test keeps the two equal).
const double vaporwaveToolbarHeight = 48;

/// How far the sun's dome rises above the display window's top edge, dp.
const double vaporwaveSunCrown = 24;

/// A giant sun may be at most this much larger than the wide-layout sun.
const double vaporwaveSunCrownMaxGrowth = 1.35;

/// The fixed stripe gaps of a sun behind the display window, as
/// `(top, height)` fractions of the radius above the horizon (the
/// design's recipe): they show beside the window, where the band recipe
/// ([vaporwaveSunGaps]) does not reach.
const List<(double, double)> vaporwaveSunFixedGaps = [
  (0.60, 0.020),
  (0.47, 0.028),
  (0.35, 0.036),
  (0.24, 0.044),
  (0.14, 0.052),
];

/// Where a Vaporwave scene puts its horizon, sun and grid in a canvas.
@immutable
final class VaporSceneGeometry {
  const VaporSceneGeometry({
    required this.horizon,
    required this.centerX,
    required this.columnWidth,
    required this.sunRadius,
    required this.sunVisibleTop,
    double? bandTop,
  }) : bandTop = bandTop ?? sunVisibleTop;

  /// Lays the scene out in [size] around the text-safe area [safe] (null:
  /// the horizon at [horizonPermille] of the height).
  factory VaporSceneGeometry.of(Size size, Rect? safe, int horizonPermille) {
    final w = size.width;
    final h = size.height;
    if (safe == null) {
      final y = h * horizonPermille.clamp(0, 1000) / 1000;
      final r = math.min(math.min(0.40 * w, y - 8), 260).toDouble();
      return VaporSceneGeometry(
        horizon: y,
        centerX: w / 2,
        columnWidth: w,
        sunRadius: r < 32 ? 0 : r,
        sunVisibleTop: y - r,
      );
    }
    if (safe.bottom >= 0.8 * h && safe.right < w - 48) {
      // Landscape: the keypad fills the right; all floor.
      return VaporSceneGeometry(
        horizon: 0,
        centerX: (safe.right + w) / 2,
        columnWidth: w - safe.right,
        sunRadius: 0,
        sunVisibleTop: 0,
      );
    }
    final y = (safe.bottom - vaporwaveHorizonLift).clamp(0.0, h);
    final colW = math.min(safe.width, w);
    final margin = math.max(0, math.min(safe.left, w - safe.right)).toDouble();
    final windowTop =
        safe.top +
        vaporwaveToolbarHeight +
        vaporwaveMarginTop -
        vaporwaveWindowTopInset;
    final windowBottom = safe.bottom - vaporwaveWindowBottomGap;
    final band = y - windowBottom;
    // The sun whose dome crowns the window.
    final crowning = y - windowTop + vaporwaveSunCrown;
    var r = crowning;
    var bandTop = windowBottom;
    if (margin >= 48) {
      final wide = (colW / 2 + 0.75 * margin).clamp(120.0, 380.0);
      if (!(wide < crowning && crowning <= vaporwaveSunCrownMaxGrowth * wide)) {
        r = wide;
        bandTop = y - wide;
      }
    }
    if (band < 8 || r < 32 || y <= 0) r = 0;
    return VaporSceneGeometry(
      horizon: y,
      centerX: safe.center.dx.clamp(0.0, w),
      columnWidth: colW,
      sunRadius: r,
      sunVisibleTop: y - r,
      bandTop: r > 0 ? bandTop : y,
    );
  }

  /// The horizon's y (0 = an all-floor scene).
  final double horizon;

  /// The sun's centre and the grid's vanishing point x.
  final double centerX;

  /// The calculator column's width (ray spacing scales with it).
  final double columnWidth;

  /// The sun's radius (0 = no sun).
  final double sunRadius;

  /// The top of the sun (its gradient spans from here to the horizon).
  final double sunVisibleTop;

  /// Where the band stripes begin ([vaporwaveSunGaps] from here to the
  /// horizon): the display window's bottom edge for a sun behind the
  /// window (with [vaporwaveSunFixedGaps] above it), else the sun's top.
  final double bandTop;

  /// Spacing of the floor rays at the bottom edge.
  double get raySpacing => (0.12 * columnWidth).clamp(28.0, 56.0);

  @override
  bool operator ==(Object other) =>
      other is VaporSceneGeometry &&
      other.horizon == horizon &&
      other.centerX == centerX &&
      other.columnWidth == columnWidth &&
      other.sunRadius == sunRadius &&
      other.sunVisibleTop == sunVisibleTop &&
      other.bandTop == bandTop;

  @override
  int get hashCode => Object.hash(
    horizon,
    centerX,
    columnWidth,
    sunRadius,
    sunVisibleTop,
    bandTop,
  );
}

/// The sun's stripe gaps (y ranges, top to bottom) for a sun of [radius]
/// whose striped band spans [visibleTop]–[horizon]: gaps grow and the
/// solid bands shrink toward the horizon, over the lower 55 % of the sun
/// (or all of a band under the display window).
List<(double, double)> vaporwaveSunGaps(
  double horizon,
  double visibleTop,
  double radius,
) {
  final v = horizon - visibleTop;
  final zone = math.min(v, 0.55 * radius);
  if (zone <= 0) return const [];
  final n = (zone / 9).round().clamp(2, 6);
  final gapUnit = 0.7 * zone / (n + 1);
  final bandUnit = 1.3 * zone / (n + 2);
  final out = <(double, double)>[];
  var y = horizon - zone;
  for (var i = 0; i <= n; i++) {
    y += bandUnit * (n + 1 - i) / (n + 1);
    if (i == n) break;
    final g = gapUnit * (i + 1) / n;
    out.add((y, y + g));
    y += g;
  }
  return out;
}

/// Every stripe gap of the sun in [g], top to bottom: the fixed gaps above
/// the band (a sun behind the display window) and the band's own.
List<(double, double)> vaporwaveSunStripes(VaporSceneGeometry g) {
  final r = g.sunRadius;
  if (r <= 0) return const [];
  final y = g.horizon;
  final out = <(double, double)>[];
  if (g.bandTop > g.sunVisibleTop + 1) {
    for (final (top, height) in vaporwaveSunFixedGaps) {
      final a = y - top * r;
      final b = a + height * r;
      // Clear of the band (its first solid stripe starts at bandTop).
      if (b <= g.bandTop - 3) out.add((a, b));
    }
  }
  out.addAll(vaporwaveSunGaps(y, g.bandTop, r));
  return out;
}

final Paint _gridPaint = Paint();

/// Paints the Vaporwave scene for [scene] over the whole canvas.
void paintVaporwaveScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty) return;
  final spec = scene.spec;
  if (spec.colors.length < 10) {
    scene.paintFallback(canvas, size);
    return;
  }
  final geometry = VaporSceneGeometry.of(
    size,
    scene.textSafeArea,
    spec.angleTenths,
  );
  if (spec.driftPeriodMs == 0) {
    // A same-family transition re-colours the scene every frame: draw it
    // directly instead of evicting the destination's cached picture.
    _paintStatic(canvas, size, spec.colors, geometry, bakeRays: false);
  } else {
    final dpr = _devicePixelRatio();
    canvas.drawPicture(
      scene.cache.scenePicture((spec, size, scene.textSafeArea, dpr), () {
        final recorder = ui.PictureRecorder();
        _paintStatic(
          Canvas(recorder),
          size,
          spec.colors,
          geometry,
          bakeRays: true,
          dpr: dpr,
        );
        return recorder.endRecording();
      }),
    );
  }
  final phase = scene.reduceMotion
      ? 0.0
      : (scene.clockSeconds * 1000 / vaporwaveScenePeriodMs) % 1;
  paintVaporwaveGridLines(canvas, size, Color(spec.colors[8]), geometry, phase);
}

/// The number of drifting cross lines (the far ones fill the floor up to
/// the horizon haze).
const int vaporwaveGridLineCount = 20;

/// The floor's drifting cross lines at [phase] (0–1 of one cycle): twenty
/// lines at `horizon + depth / z` for z = j − phase, fading in over the
/// far end (z 12–20) so the loop is seamless and the crowded far lines
/// begin without an edge, fainter (down to 35 %) beyond z = 6, thicker
/// near the viewer.
void paintVaporwaveGridLines(
  Canvas canvas,
  Size size,
  Color color,
  VaporSceneGeometry geometry,
  double phase,
) {
  final depth = size.height - geometry.horizon;
  if (depth <= 0) return;
  const n = vaporwaveGridLineCount;
  for (var j = 1; j <= n; j++) {
    final z = j - phase;
    if (z < 1) continue;
    final y = geometry.horizon + depth / z;
    final fade = ((n - z) / 8).clamp(0.0, 1.0);
    final far = z <= 6 ? 1.0 : math.max(0.35, 1 - (z - 6) / 14);
    final a = fade * far;
    if (a <= 0) continue;
    final width = 1.0 + 0.5 * ((3 - z) / 2).clamp(0.0, 1.0);
    _gridPaint
      ..color = color.withValues(alpha: color.a * a)
      ..strokeWidth = width;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
  }
}

/// The device pixel ratio the floor rays are baked at: the implicit
/// view's, else the first view's, else 1.
double _devicePixelRatio() {
  // The binding's dispatcher (a test's view overrides apply).
  final dispatcher = WidgetsBinding.instance.platformDispatcher;
  final view =
      dispatcher.implicitView ??
      (dispatcher.views.isEmpty ? null : dispatcher.views.first);
  final dpr = view?.devicePixelRatio ?? 1;
  return dpr > 0 && dpr.isFinite ? dpr : 1;
}

/// The static layers. [bakeRays]: draw the floor rays into an image at
/// [dpr] once (the cached picture keeps it). Impeller draws anti-aliased
/// strokes with a gradient shader on a slow path: replayed every frame,
/// the ~250 rays of a phone cost ~30 ms of raster on an M-series Mac (2 ms
/// as one image). Source-over strokes composited as one layer give the
/// same pixels. A same-family transition re-colours every frame and
/// draws them directly instead, aliased (Impeller's fast path, 2 ms).
void _paintStatic(
  Canvas canvas,
  Size size,
  List<int> colors,
  VaporSceneGeometry g, {
  required bool bakeRays,
  double dpr = 1,
}) {
  final w = size.width;
  final h = size.height;
  final y = g.horizon;
  Color c(int i) => Color(colors[i] | 0xFF000000);
  final dark = c(0).computeLuminance() < 0.18;
  final paint = Paint();

  // Sky and floor.
  if (y > 0) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, y),
      paint
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, y),
          [c(0), c(1), c(2)],
          const [0, 0.55, 1],
        ),
    );
  }
  canvas.drawRect(
    Rect.fromLTRB(0, y, w, h),
    paint
      ..shader = ui.Gradient.linear(Offset(0, y), Offset(0, h), [c(6), c(7)]),
  );
  paint.shader = null;

  // The sun's upper half, striped, sinking into the horizon.
  final r = g.sunRadius;
  if (r > 0) {
    final top = math.max(g.sunVisibleTop, y - r);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, y - r, w, y))
      ..clipPath(
        Path()
          ..addOval(Rect.fromCircle(center: Offset(g.centerX, y), radius: r)),
      );
    paint.shader = ui.Gradient.linear(
      Offset(0, top),
      Offset(0, y),
      [c(3), c(4), c(5)],
      const [0, 0.5, 1],
    );
    var bandTop = y - r;
    for (final (gapTop, gapBottom) in vaporwaveSunStripes(g)) {
      canvas.drawRect(Rect.fromLTRB(0, bandTop, w, gapTop), paint);
      bandTop = gapBottom;
    }
    canvas
      ..drawRect(Rect.fromLTRB(0, bandTop, w, y), paint)
      ..restore();
    paint.shader = null;
  }

  // Floor rays to the vanishing point, from just below the horizon (depth
  // / 30, where the 1 dp rays already overlap into a solid tint). Their
  // alpha rises linearly from 0 there to 1 at depth / 4, so they begin
  // without an edge and the far floor reads as distance, never a gap.
  final depth = h - y;
  if (depth > 0) {
    final s = g.raySpacing;
    final reach = math.max(g.centerX, w - g.centerX);
    const zStart = 30;
    final kMax = (zStart * reach / s).ceil() + 1;
    final yStart = y + depth / zStart;
    final grid = c(8);
    final rays = Paint()
      ..color = grid
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(
        Offset(0, yStart),
        Offset(0, y + depth / 4),
        [grid.withValues(alpha: 0), grid],
      );
    void drawRays(Canvas canvas) {
      for (var k = -kMax; k <= kMax; k++) {
        canvas.drawLine(
          Offset(g.centerX + k * s / zStart, yStart),
          Offset(g.centerX + k * s, h),
          rays,
        );
      }
    }

    // The rays' box, snapped to the pixel grid so the image draws 1:1.
    final top = ((yStart - 1) * dpr).floorToDouble();
    final pw = (w * dpr).ceil();
    final ph = (h * dpr).ceil() - top.toInt();
    if (bakeRays && pw > 0 && ph > 0) {
      final recorder = ui.PictureRecorder();
      drawRays(
        Canvas(recorder)
          ..translate(0, -top)
          ..scale(dpr),
      );
      final picture = recorder.endRecording();
      final image = picture.toImageSync(pw, ph);
      picture.dispose();
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()),
        Rect.fromLTWH(0, top / dpr, pw / dpr, ph / dpr),
        Paint()..filterQuality = FilterQuality.low,
      );
      image.dispose(); // the picture holds its own reference
    } else {
      // Mid-transition, for ~300 ms: aliased strokes take Impeller's fast
      // path (MSAA still smooths them on device).
      rays.isAntiAlias = false;
      drawRays(canvas);
    }

    // A haze in the horizon line's colour over the far 12 % of the floor.
    if (y > 0) {
      final haze = c(9);
      final alpha = (dark ? vaporwaveHazeAlpha : vaporwaveHazeAlphaLight) / 255;
      final bottom = y + 0.12 * depth;
      canvas.drawRect(
        Rect.fromLTRB(0, y, w, bottom),
        paint
          ..shader = ui.Gradient.linear(Offset(0, y), Offset(0, bottom), [
            haze.withValues(alpha: alpha),
            haze.withValues(alpha: 0),
          ]),
      );
      paint.shader = null;
    }
  }

  // The horizon line (a soft underlay on night scenes).
  if (y > 0 && y < h) {
    if (dark) {
      canvas.drawRect(
        Rect.fromLTRB(0, y - 2, w, y + 2),
        paint..color = c(9).withValues(alpha: 77 / 255),
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(0, y - 0.75, w, y + 0.75),
      paint..color = c(9),
    );
  }
}
