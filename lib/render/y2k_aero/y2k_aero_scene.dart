/// Y2K / Frutiger Aero background scenes (`BackgroundKind.aeroSky` /
/// `BackgroundKind.chromeHolo`; registered in `backgroundScenePainters`).
///
/// `BackgroundSpec.colors` (six entries, the same roles for every scene of
/// a kind, so same-kind lerps stay meaningful):
///
/// | idx | aeroSky | chromeHolo |
/// |---|---|---|
/// | 0 | zenith (sky, meadow) / water surface | base: pearl or gunmetal |
/// | 1 | mid sky / mid water | holo A |
/// | 2 | horizon haze / abyss | holo B |
/// | 3 | lake or grass crest (water: = 2) | holo C |
/// | 4 | lake depth or grass shade (water: abyss floor) | holo D |
/// | 5 | light colour, its alpha = the light budget | crease colour, alpha = budget |
///
/// `angleTenths`: AERO sun azimuth; CHROME holo band angle. `pattern dots`:
/// bubbles (AERO) or sparkles (CHROME) in `patternColor` at
/// `patternOpacityPermille`; `patternScaleCdp`: their size, the layout
/// seed and (AERO) the hill mirror. `driftPeriodMs` only says whether the
/// scene drifts: the periods are the constants `y2kAeroDriftMs` /
/// `y2kChromeDriftMs`, and the phase follows the ambient clock, so a
/// transition (which drops `driftPeriodMs`) never jumps.
///
/// The composition is anchored to the keypad's top edge ([Y2kSceneLayout]):
/// on phones the horizon sits in the strip under the display panel
/// (`y2kPanelMargin.bottom`) and the lake or the grass hills show between
/// the keys; on wide layouts the whole scene shows beside the calculator
/// column; side by side (a phone on its side) the horizon lies above the
/// canvas and the keys stand on the ground. Behind the keys only the
/// ground the guardrails validate (`y2kGroundSamples`), smooth light and
/// micro-bubbles are drawn: the lake glint, the flare ghosts and the large
/// bubbles stay beside the calculator. Inside the calm area (the toolbar
/// strip and the display panel) only smooth gradients are drawn.
///
/// Every light overlay is budgeted so the stacked alpha at any pixel stays
/// ≤ the `colors[5]` alpha, a bubble never paints its tint above
/// `y2kBubbleMaxAlpha` × its opacity ([y2kBubbleBodyAlpha] lists the
/// sprite) and a sparkle (one path) never above its opacity: the guardrail
/// samples (`y2kAeroSceneSamples`) cover what is drawn. Deterministic:
/// layouts come from `fmix32` hashes of the spec.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/oklab.dart';
import 'package:calsee_themes/engine/rng.dart' show fmix32;
import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/engine/y2k_aero.dart';
import 'package:calsee_themes/render/background_painter.dart';
import 'package:calsee_themes/render/y2k_aero/y2k_display_face.dart'
    show y2kPanelMargin;
import 'package:flutter/widgets.dart';

/// Paints the Y2K / Frutiger Aero scene for [scene] over the whole canvas.
void paintY2kAeroScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty || size.width < 1 || size.height < 1) return;
  final spec = scene.spec;
  final chrome = spec.kind == BackgroundKind.chromeHolo;
  if (spec.colors.length < 6 ||
      (!chrome && spec.kind != BackgroundKind.aeroSky)) {
    scene.paintFallback(canvas, size);
    return;
  }
  final layout = Y2kSceneLayout.of(size, scene.textSafeArea);
  final t = scene.reduceMotion
      ? 0.0
      : (scene.driftSeconds > 0 ? scene.driftSeconds : scene.clockSeconds);
  // Transitional specs (a same-family lerp drops `driftPeriodMs`) are
  // painted directly: caching a picture per frame would only churn the
  // shared cache.
  final transitional = spec.driftPeriodMs <= 0;
  ui.Picture picture(String layer, void Function(Canvas c) paint) {
    ui.Picture record() {
      final recorder = ui.PictureRecorder();
      paint(Canvas(recorder));
      return recorder.endRecording();
    }

    return scene.cache.scenePicture((
      'y2k',
      layer,
      spec,
      size,
      scene.textSafeArea,
    ), record);
  }

  if (chrome) {
    final holo = _Holo(spec, size);
    final d = (t * 1000 / y2kChromeDriftMs) % 1 * holo.period;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(-holo.dir.dx * d, -holo.dir.dy * d);
    if (transitional) {
      holo.paint(canvas);
    } else {
      canvas.drawPicture(picture('holo', holo.paint));
    }
    canvas.restore();
    void over(Canvas c) =>
        _paintChromeOver(c, size, spec, layout, holo, scene.patternFade);
    if (transitional) {
      over(canvas);
    } else {
      canvas.drawPicture(picture('over', over));
    }
    return;
  }

  void base(Canvas c) => _paintAeroStatic(c, size, spec, layout);
  if (transitional) {
    base(canvas);
  } else {
    canvas.drawPicture(picture('aero', base));
  }
  _paintBubbles(canvas, size, spec, layout, t, scene);
}

// ---------------------------------------------------------------- layout --

/// The toolbar row above the display (the calculator screen's
/// `ScreenLayout.toolbarHeight`; themes never import the feature layer).
const double y2kToolbarHeight = 48;

/// Where the scene's parts go for a canvas of [size] with the text-safe
/// area `safe` (the toolbar plus the display, over the calculator column).
///
/// Portrait and wide layouts put the keypad under the text-safe area: the
/// horizon sits in the strip under the display panel and the keys stand
/// on the lake or the grass. A side-by-side layout (a phone on its side:
/// the text-safe area spans the height but not the width) has the keypad
/// beside the display from the top edge down, so the horizon goes above
/// the canvas and every key stands on the ground the guardrails validate.
@immutable
final class Y2kSceneLayout {
  /// Lays out a canvas of [size].
  factory of(Size size, Rect? safe) {
    final bounds = Offset.zero & size;
    final s = safe == null || safe.isEmpty ? null : safe.intersect(bounds);
    final valid = s != null && s.width > 0 && s.height > 0;
    final sideBySide =
        valid && s.height >= 0.7 * size.height && s.width <= 0.75 * size.width;
    final double keypadTop;
    final double horizon;
    var waterHorizon = 0.0;
    (double, double)? keys;
    if (!valid) {
      keypadTop = 0.42 * size.height;
      horizon = math.max(0, keypadTop - y2kPanelMargin.bottom / 2);
    } else if (sideBySide) {
      keypadTop = s.top;
      horizon = s.top - 12;
      waterHorizon = math.max(0, s.bottom - y2kPanelMargin.bottom / 2);
      keys = size.width - s.right >= s.left
          ? (s.right, size.width)
          : (0.0, s.left);
    } else {
      keypadTop = s.bottom;
      horizon = math.max(0, keypadTop - y2kPanelMargin.bottom / 2);
      keys = (s.left, s.right);
    }
    Rect? toolbar;
    Rect? panel;
    if (valid) {
      toolbar = Rect.fromLTRB(
        s.left,
        s.top,
        s.right,
        math.min(s.bottom, s.top + y2kToolbarHeight),
      );
      const m = y2kPanelMargin;
      final p = Rect.fromLTRB(
        s.left + m.left,
        toolbar.bottom + m.top,
        s.right - m.right,
        s.bottom - m.bottom,
      );
      panel = p.width > 0 && p.height > 0 ? p : null;
    }
    return Y2kSceneLayout._(
      size: size,
      keypadTop: keypadTop,
      horizon: horizon,
      waterHorizon: sideBySide ? waterHorizon : horizon,
      column: valid ? (s.left, s.right) : null,
      keys: keys,
      sideBySide: sideBySide,
      toolbar: toolbar,
      panel: panel,
    );
  }

  const new _({
    required this.size,
    required this.keypadTop,
    required this.horizon,
    required this.waterHorizon,
    required this.column,
    required this.keys,
    required this.sideBySide,
    required this.toolbar,
    required this.panel,
  });

  /// The canvas size.
  final Size size;

  /// The keypad's top edge (the bottom of the text-safe area, or its top
  /// side by side; 42 % down without one).
  final double keypadTop;

  /// The horizon line: in the middle of the strip under the display
  /// panel, or above the canvas side by side (may be negative).
  final double horizon;

  /// Deep water's horizon (the abyss floor): [horizon], except side by
  /// side, where the water column runs down to the bottom of the text-safe
  /// area as it does above a keypad (deep water has no ground rule).
  final double waterHorizon;

  /// The text-safe column's horizontal extent (null: no text-safe area).
  final (double, double)? column;

  /// The keypad's horizontal extent below [keypadTop] (null: no text-safe
  /// area): the column, or the side beside it.
  final (double, double)? keys;

  /// Whether the keypad stands beside the display (a phone on its side).
  final bool sideBySide;

  /// The toolbar strip (calm: smooth gradients only).
  final Rect? toolbar;

  /// The display panel (calm; covered by the opaque panel anyway).
  final Rect? panel;

  /// Whether [r] touches the calm area (inflated by [margin]).
  bool calm(Rect r, [double margin = 0]) {
    final t = toolbar;
    final p = panel;
    return (t != null && t.inflate(margin).overlaps(r)) ||
        (p != null && p.inflate(margin).overlaps(r));
  }

  /// Whether [r] reaches behind the keys or the text-safe column (where
  /// only the validated ground and smooth light may go).
  bool behindCalculator(Rect r) {
    final c = column;
    final k = keys;
    return (c != null && r.right > c.$1 && r.left < c.$2) ||
        (k != null && r.right > k.$1 && r.left < k.$2 && r.bottom > keypadTop);
  }
}

double _alphaOf(int argb) => ((argb >>> 24) & 0xFF) / 255;

Color _opaque(int argb) => Color(argb | 0xFF000000);

/// The sun's x for a sun azimuth of [angleTenths] in a canvas [w] wide.
double y2kSunX(int angleTenths, double w) =>
    (0.18 + 0.64 * (angleTenths % 1800) / 1800) * w;

/// How much of a meadow an AERO scene is (0 = lake or water, 1 = grass
/// hills), continuous in the ground colour's hue so a sky ↔ meadow lerp
/// raises the hills smoothly.
double y2kMeadowness(BackgroundSpec spec) {
  if (spec.colors.length < 4) return 0;
  final x = argbToOklch(spec.colors[3] | 0xFF000000);
  if (x.c < 0.03) return 0;
  return ((185 - x.h) / 20).clamp(0.0, 1.0) * (x.h > 80 ? 1 : 0);
}

/// How much of deep water an AERO scene is (0 = a light sky, 1 = deep
/// water), continuous in the zenith's lightness.
double y2kWateriness(BackgroundSpec spec) {
  final l = argbToOklab(spec.colors.first | 0xFF000000).$1;
  return ((0.55 - l) / 0.1).clamp(0.0, 1.0);
}

// ------------------------------------------------------------------ AERO --

void _paintAeroStatic(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  Y2kSceneLayout layout,
) {
  final w = size.width;
  final h = size.height;
  final c = [for (var i = 0; i < 5; i++) _opaque(spec.colors[i])];
  final light = _opaque(spec.colors[5]);
  final a5 = _alphaOf(spec.colors[5]);
  final g = y2kMeadowness(spec);
  final water = y2kWateriness(spec);
  // The horizon may lie above the canvas (side by side): the ground's ramp
  // then starts off-canvas and no sky shows.
  final hz = math.min(
    layout.horizon + (layout.waterHorizon - layout.horizon) * water,
    h,
  );
  final yH = hz.clamp(0.0, h);

  // 1. Sky: zenith → mid → haze at the horizon (painted over the whole
  // canvas, so the ground's anti-aliased top edge never shows a seam).
  if (yH > 0) {
    canvas.drawRect(
      Rect.fromLTRB(0, 0, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, yH),
          [c[0], c[1], c[2]],
          [0, (1 - 56 / yH).clamp(0.0, 0.95), 1],
        ),
    );
  }
  // 2. Ground: the haze line, then the lake (or the abyss, or a meadow's
  // far field) deepening. The haze ramp ends at the keypad's top edge, so
  // behind the keys there are only the ground colours the guardrails
  // check (`y2kGroundSamples`: c3, c4 and their midpoint, and blends).
  final ys = layout.keypadTop;
  final crest = math.min(h, math.max(hz + 2, ys));
  final field = Color.lerp(c[3], Color.lerp(c[3], c[4], 0.5), g)!;
  if (yH < h) {
    canvas.drawRect(
      Rect.fromLTRB(0, yH, w, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, hz),
          Offset(0, h),
          [c[2], field, c[4]],
          [0, ((crest - hz) / math.max(1, h - hz)).clamp(0.0, 1.0), 1],
        ),
    );
  }

  final xs = y2kSunX(spec.angleTenths, w);
  // 3. Lake glint under the sun (open sky; fades out with the hills), only
  // where no key stands on it: its light nearly matches a frost gel, which
  // the ground guardrail could not keep apart (on phones the keypad spans
  // the width, so the lake there stays plain).
  final lake = (1 - g) * (1 - water);
  final glintBox = _glintBox(layout, xs, yH, w, h);
  if (lake > 0 && glintBox != null) {
    final depth = h - yH;
    final glint = glintBox;
    canvas.drawOval(
      glint,
      Paint()
        ..shader = _ellipseShader(
          glint,
          [
            light.withValues(alpha: 0.55 * a5 * lake),
            light.withValues(alpha: 0.22 * a5 * lake),
            light.withValues(alpha: 0),
          ],
          const [0, 0.45, 1],
        ),
    );
    // Glints: three soft, flat streaks on the water (≤ 0.40 of the
    // budget; with the glow ≤ 0.95 of it).
    for (var i = 0; i < 3; i++) {
      final streak = Rect.fromCenter(
        center: Offset(
          glint.center.dx + glint.width * (0.08 * (i - 1) + 0.05 * (i % 2)),
          yH + depth * (0.07 + 0.06 * i),
        ),
        width: glint.width * (0.62 - 0.14 * i),
        height: math.min(6, 0.02 * depth + 2),
      );
      canvas.drawOval(
        streak,
        Paint()
          ..shader = _ellipseShader(
            streak,
            [
              light.withValues(alpha: 0.40 * a5 * lake),
              light.withValues(alpha: 0),
            ],
            const [0, 1],
          ),
      );
    }
  }

  // 4. Hills (meadows; raised by `g`, mirrored by the pattern scale): a
  // hazy far ridge on the horizon and a rolling near hill whose sunlit
  // crest (c3) shows between the top keys against the darker far field;
  // on wide layouts the humps rise beside the calculator column, where
  // they are seen. Above the keypad's top edge the ridge and the crest are
  // lighter with haze; below it only ground colours are drawn. Side by
  // side the horizon lies above the canvas: the grass itself is the
  // ground.
  if (g > 0 && yH < h && !layout.sideBySide) {
    final mirror = (spec.patternScaleCdp ~/ 200).isOdd;
    final column = layout.column;
    final List<Offset> far;
    final List<Offset> near;
    if (column != null && column.$1 > 80) {
      final left = column.$1;
      final right = column.$2;
      final hl = g * math.min(64, 0.4 * left) * (mirror ? 0.6 : 1);
      final hr = g * math.min(64, 0.4 * left) * (mirror ? 1 : 0.6);
      far = [
        Offset(0, yH - 0.3 * hl),
        Offset(0.6 * left, yH - 0.55 * hl),
        Offset(left + 60, yH + 2),
        Offset(right + 40, yH - 0.45 * hr),
        Offset(right + 200, yH - 0.2 * hr),
        Offset(w, yH - 0.35 * hr),
      ];
      near = [
        Offset(0, ys + 14),
        Offset(0.42 * left, ys - hl),
        Offset(left + 30, ys + 8),
        Offset(right - 20, ys + 10),
        Offset(right + 90, ys - hr),
        Offset(right + 260, ys + 12),
        Offset(w, ys),
      ];
    } else {
      double x(double f) => mirror ? w * (1 - f) : w * f;
      final a = g * (w / 412).clamp(1.0, 2.4);
      far = [
        Offset(x(0), yH + 2 - 4 * a),
        Offset(x(0.32), yH - 12 * a),
        Offset(x(0.62), yH + 3),
        Offset(x(0.86), yH - 8 * a),
        Offset(x(1), yH - 4 * a),
      ];
      near = [
        Offset(x(0), ys + 10 + 6 * a),
        Offset(x(0.26), ys - 8 * a),
        Offset(x(0.56), ys + 8),
        Offset(x(0.84), ys - 4 * a),
        Offset(x(1), ys + 2),
      ];
    }
    // The far ridge melts into the far field over the 12 dp above the
    // keypad's top edge and is the field itself below it.
    final ridgeTop = ys - 12;
    canvas.drawPath(
      _hill(far, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, ridgeTop),
          Offset(0, h),
          [
            Color.lerp(c[2], c[3], 0.5)!.withValues(alpha: g),
            field.withValues(alpha: g),
            c[4].withValues(alpha: g),
          ],
          [0, (12 / math.max(12, h - ridgeTop)).clamp(0.0, 1.0), 1],
        ),
    );
    final top = math.min(ys - 1, near.map((o) => o.dy).reduce(math.min));
    canvas.drawPath(
      _hill(near, h),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, h),
          [
            Color.lerp(c[3], c[2], 0.3)!.withValues(alpha: g),
            c[3].withValues(alpha: g),
            c[4].withValues(alpha: g),
          ],
          [0, ((ys - top) / math.max(1, h - top)).clamp(0.001, 1.0), 1],
        ),
    );
  }

  // 5. Light: the sun's glow in a sky (it ends just under the horizon:
  // side by side, where the keys reach the top edge, there is none); a
  // shimmer and god rays in water.
  final sky = 1 - water;
  if (sky > 0 && a5 > 0 && !layout.sideBySide) {
    final centre = Offset(xs, -0.06 * h);
    final reach = math.max<double>(
      1,
      math.min(0.70 * math.max(w, 0.6 * h), yH + 0.06 * h),
    );
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          reach,
          [
            light.withValues(alpha: 0.7 * a5 * sky),
            light.withValues(alpha: 0.28 * a5 * sky),
            light.withValues(alpha: 0),
          ],
          const [0, 0.35, 1],
        ),
    );
    _paintGhosts(canvas, size, layout, centre, light, a5 * sky);
  }
  if (water > 0 && a5 > 0) {
    final centre = Offset(xs, -0.10 * h);
    final reach = math.max<double>(1, 0.9 * w);
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          reach,
          [
            light.withValues(alpha: 0.5 * a5 * water),
            light.withValues(alpha: 0),
          ],
          const [0, 1],
        ),
    );
    // God rays: soft, elongated beams from the surface, fanned so they
    // never overlap (each fades across and along its length).
    final lean = spec.angleTenths < 1800 ? 1.0 : -1.0;
    for (var i = 0; i < 4; i++) {
      final width = (0.11 + 0.04 * (i % 2)) * w;
      final length = 1.1 * h;
      final beam = Rect.fromCenter(
        center: Offset.zero,
        width: width,
        height: 2 * length,
      );
      canvas
        ..save()
        ..translate(xs + (i - 1.5) * 0.16 * w, -0.02 * h)
        ..rotate(lean * (12 + 3 * i) * math.pi / 180)
        ..drawOval(
          beam,
          Paint()
            ..shader = _ellipseShader(
              beam,
              [
                light.withValues(alpha: 0.5 * a5 * water),
                light.withValues(alpha: 0.38 * a5 * water),
                light.withValues(alpha: 0),
              ],
              const [0, 0.5, 1],
            ),
        )
        ..restore();
    }
  }
}

/// The lake glint's oval for a sun at [xs] over a horizon at [yH]: under
/// the sun without a text-safe area; on wide layouts in the open lake
/// beside the calculator column (the side nearer the sun with room for
/// it); null where every place for it is behind the calculator (phones,
/// side by side).
Rect? _glintBox(
  Y2kSceneLayout layout,
  double xs,
  double yH,
  double w,
  double h,
) {
  if (yH >= h) return null;
  final depth = h - yH;
  final cy = yH + 0.16 * depth;
  final height = 0.28 * depth;
  final column = layout.column;
  if (column == null) {
    return Rect.fromCenter(
      center: Offset(xs, cy),
      width: 0.55 * w,
      height: height,
    );
  }
  if (layout.sideBySide) return null;
  final left = (0.0, column.$1 - 12);
  final right = (column.$2 + 12, w);
  final sides = xs < (column.$1 + column.$2) / 2
      ? [left, right]
      : [right, left];
  for (final (a, b) in sides) {
    final room = b - a;
    if (room < 96) continue;
    final width = math.min(0.55 * w, 0.8 * room);
    final x = xs.clamp(a + width / 2, b - width / 2);
    return Rect.fromCenter(center: Offset(x, cy), width: width, height: height);
  }
  return null;
}

/// A filled hill whose crest runs smoothly (Catmull-Rom) through
/// [crest] (sorted by x), closed along the bottom edge at [bottom].
Path _hill(List<Offset> crest, double bottom) {
  final pts = [...crest]..sort((a, b) => a.dx.compareTo(b.dx));
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 0; i + 1 < pts.length; i++) {
    final p0 = pts[i == 0 ? 0 : i - 1];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path
    ..lineTo(pts.last.dx, bottom)
    ..lineTo(pts.first.dx, bottom)
    ..close();
}

/// Lens-flare ghosts along the line from the sun across the scene, only
/// where they never meet the calculator column (wide layouts) or, without
/// a text-safe area, anywhere: discs at ≤ 0.3 of the light budget where
/// the glow is ≤ 0.28 of it, plus a fine ring.
void _paintGhosts(
  Canvas canvas,
  Size size,
  Y2kSceneLayout layout,
  Offset sun,
  Color light,
  double budget,
) {
  final w = size.width;
  final h = size.height;
  final target = Offset(sun.dx < w / 2 ? 0.92 * w : 0.08 * w, 0.62 * h);
  final disc = Paint();
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  for (final (f, rf) in const [(0.45, 0.05), (0.66, 0.03), (0.86, 0.08)]) {
    final centre = Offset.lerp(sun, target, f)!;
    final r = rf * math.min(w, 1.2 * h);
    final box = Rect.fromCircle(center: centre, radius: r + 6);
    if (layout.behindCalculator(box) || layout.calm(box, 12)) continue;
    disc
      ..shader = ui.Gradient.radial(
        centre,
        r,
        [
          light.withValues(alpha: 0.12 * budget),
          light.withValues(alpha: 0.30 * budget),
        ],
        const [0, 1],
      )
      ..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(centre, r, disc);
    ring.color = light.withValues(alpha: 0.25 * budget);
    canvas.drawCircle(centre, r, ring);
  }
}

ui.Gradient _ellipseShader(Rect box, List<Color> colors, List<double> stops) {
  final longest = math.max(box.width, box.height);
  if (longest <= 0) {
    return ui.Gradient.linear(Offset.zero, const Offset(1, 0), [
      colors.first,
      colors.first,
    ]);
  }
  final c = box.center;
  final sx = box.width / longest;
  final sy = box.height / longest;
  final matrix = Float64List(16)
    ..[0] = sx
    ..[5] = sy
    ..[10] = 1
    ..[12] = c.dx * (1 - sx)
    ..[13] = c.dy * (1 - sy)
    ..[15] = 1;
  return ui.Gradient.radial(
    c,
    longest / 2,
    colors,
    stops,
    TileMode.clamp,
    matrix,
  );
}

// --------------------------------------------------------------- bubbles --

/// One bubble of a layout: start position, radius, wobble phase.
typedef _Bubble = ({double x, double y, double r, int i});

final Paint _bubbleBody = Paint();
final Paint _bubbleRim = Paint()..style = PaintingStyle.stroke;
final Paint _bubbleGlint = Paint();
final Paint _bubbleArc = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round;

/// The bubble sprite, in units of its radius r (every layer at its share
/// of the pattern opacity o):
///
/// - a body ring rising from 0 (inside 0.40 of the off-centre gradient) to
///   [y2kBubbleBodyAlpha] at the edge;
/// - a 1 dp rim at 0.55, over the body: ≤ 1 − (1 − 0.30 o)(1 − 0.55 o) =
///   0.85 o − 0.165 o² ≤ [y2kBubbleMaxAlpha] o;
/// - on bubbles of r ≥ [y2kBubbleGlintMinRadius] dp only, a glint at 0.80
///   (where the body is clear) and a fine arc at 0.35 (over ≤ 0.24 of
///   body), both kept off the rim even with a device pixel of
///   anti-aliasing.
const double y2kBubbleBodyAlpha = 0.30;

/// The smallest bubble radius (dp) that draws the glint and the arc.
const double y2kBubbleGlintMinRadius = 5.6;

final Rect _glintRect = Rect.fromCenter(
  center: const Offset(-0.32, -0.38),
  width: 0.40,
  height: 0.24,
);
final Rect _arcCircle = Rect.fromCircle(center: Offset.zero, radius: 0.66);

final Map<(int, Size, Rect?, int), (List<_Bubble>, List<_Bubble>)> _layouts =
    {};

/// Bubble layouts for a canvas: large bubbles beside the calculator column
/// (wide layouts; everywhere without a text-safe area; none side by side,
/// where the keypad stands beside the column) and micro-bubbles rising
/// through the keypad's gaps. Each layer is laid out on a torus (its
/// region × its rise span) with no two bubbles closer than 8 dp, so with
/// one common rise they never overlap; the layers keep 6 dp apart.
(List<_Bubble>, List<_Bubble>) _bubbleLayout(
  BackgroundSpec spec,
  Size size,
  Y2kSceneLayout layout,
  Rect? safe,
) {
  final key = (spec.patternScaleCdp, size, safe, layout.keypadTop.round());
  final hit = _layouts[key];
  if (hit != null) return hit;
  final w = size.width;
  final h = size.height;
  final b0 = math.max<double>(4, spec.patternScaleCdp / 100);
  final seed = fmix32(spec.patternScaleCdp * 0x9E3779B1);

  List<_Bubble> place(
    int count,
    double left,
    double right,
    double span,
    double rMin,
    double rMax,
    int salt,
  ) {
    final out = <_Bubble>[];
    if (right - left < 2 * rMax + 4 || span <= 0) return out;
    for (var i = 0; i < count; i++) {
      for (var attempt = 0; attempt < 6; attempt++) {
        final hh = fmix32(seed ^ (salt << 20) ^ (i * 8 + attempt));
        final u = (hh & 0xFFFF) / 65536;
        final v = (hh >>> 16) / 65536;
        final r = rMin + (rMax - rMin) * (fmix32(hh) & 0xFFFF) / 65536;
        final x = left + r + 2 + u * (right - left - 2 * r - 4);
        final y = v * span;
        var ok = true;
        for (final o in out) {
          final dx = x - o.x;
          var dy = (y - o.y).abs();
          if (dy > span / 2) dy = span - dy;
          final min = r + o.r + 8;
          if (dx * dx + dy * dy < min * min) {
            ok = false;
            break;
          }
        }
        if (ok) {
          out.add((x: x, y: y, r: r, i: i));
          break;
        }
      }
    }
    return out;
  }

  final column = layout.column;
  final keys = layout.keys;
  final large = <_Bubble>[];
  final span = h + 2 * 1.35 * b0 + 16;
  if (column == null) {
    final n = (w * h / 26000).round().clamp(8, 24);
    large.addAll(place(n, 0, w, span, 0.45 * b0, 1.35 * b0, 1));
  } else if (!layout.sideBySide) {
    final left = column.$1 - 6;
    final right = column.$2 + 6;
    final nl = (left * h / 26000).round().clamp(0, 12);
    final nr = ((w - right) * h / 26000).round().clamp(0, 12);
    large
      ..addAll(place(nl, 0, left, span, 0.45 * b0, 1.35 * b0, 2))
      ..addAll(place(nr, right, w, span, 0.45 * b0, 1.35 * b0, 3));
  }
  final micro = <_Bubble>[];
  if (keys != null) {
    final region = h - layout.keypadTop + 40;
    final n = ((keys.$2 - keys.$1) * region / 7000).round().clamp(6, 36);
    micro.addAll(place(n, keys.$1, keys.$2, region + 24, 2.5, 4.5, 4));
  }
  if (_layouts.length > 8) _layouts.remove(_layouts.keys.first);
  return _layouts[key] = (large, micro);
}

void _paintBubbles(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  Y2kSceneLayout layout,
  double seconds,
  BackgroundScene scene,
) {
  if (spec.pattern == BackgroundPattern.none ||
      spec.patternOpacityPermille <= 0 ||
      scene.patternFade <= 0) {
    return;
  }
  final o =
      (spec.patternOpacityPermille / 1000).clamp(0.0, 1.0) * scene.patternFade;
  final tint = _opaque(spec.patternColor);
  final shader = scene.cache.shader(
    BackgroundSpec(
      kind: BackgroundKind.aeroSky,
      colors: List.unmodifiable([tint.toARGB32()]),
      patternScaleCdp: 1,
    ),
    Size.zero,
    () => ui.Gradient.radial(
      const Offset(-0.25, -0.30),
      1.30,
      [
        tint.withValues(alpha: 0),
        tint.withValues(alpha: 0),
        tint.withValues(alpha: 0.10),
        tint.withValues(alpha: 0.24),
        tint.withValues(alpha: y2kBubbleBodyAlpha),
      ],
      const [0, 0.40, 0.66, 0.92, 1],
    ),
  );
  _bubbleBody.shader = shader;
  final (large, micro) = _bubbleLayout(spec, size, layout, scene.textSafeArea);
  final phase = seconds * 1000 / y2kAeroDriftMs;
  final w = size.width;
  final h = size.height;
  final b0 = math.max<double>(4, spec.patternScaleCdp / 100);

  void draw(_Bubble b, double y, double fade) {
    final alpha = (o * fade).clamp(0.0, 1.0);
    if (alpha <= 0.004) return;
    final x = b.x + 3 * math.sin(2 * math.pi * 3 * phase + 1.7 * b.i);
    final r = b.r;
    _bubbleBody.color = Color.fromRGBO(0, 0, 0, alpha);
    _bubbleRim
      ..strokeWidth = 1 / r
      ..color = tint.withValues(alpha: 0.55 * alpha);
    canvas
      ..save()
      ..translate(x, y)
      ..scale(r)
      ..drawCircle(Offset.zero, 1, _bubbleBody)
      ..drawCircle(Offset.zero, 1 - 0.5 / r, _bubbleRim);
    if (r >= y2kBubbleGlintMinRadius) {
      _bubbleGlint.color = tint.withValues(alpha: 0.80 * alpha);
      _bubbleArc
        ..strokeWidth = 0.08
        ..color = tint.withValues(alpha: 0.35 * alpha);
      canvas
        ..drawOval(_glintRect, _bubbleGlint)
        ..drawArc(_arcCircle, 0.35, 1.2, false, _bubbleArc);
    }
    canvas.restore();
  }

  final span = h + 2 * 1.35 * b0 + 16;
  final rise = phase * span;
  for (final b in large) {
    final y = ((b.y - rise) % span) - 1.35 * b0 - 8;
    if (y + b.r < 0 || y - b.r > h) continue;
    final box = Rect.fromCircle(center: Offset(b.x, y), radius: b.r + 3);
    if (layout.calm(box)) continue;
    draw(b, y, 1);
  }
  if (micro.isEmpty) return;
  final top = layout.keypadTop;
  final region = h - top + 40;
  final microSpan = region + 24;
  final microRise = phase * microSpan;
  final panelBottom = layout.panel?.bottom ?? top - 28;
  for (final b in micro) {
    final y = top - 20 + ((b.y - microRise) % microSpan);
    if (y - b.r > h || b.x < 0 || b.x > w) continue;
    // Fade out as the bubble nears the display panel above the keypad
    // (side by side the panel is beside it).
    final fade = layout.sideBySide
        ? 1.0
        : ((y - b.r - panelBottom - 4) / 14).clamp(0.0, 1.0);
    draw(b, y, fade);
  }
}

// ---------------------------------------------------------------- CHROME --

/// The holographic foil's repeating band gradient.
final class _Holo {
  new(this.spec, this.size)
    : period = math.max(
        24,
        0.45 * math.sqrt(size.width * size.width + size.height * size.height),
      ),
      dir = Offset(
        math.cos(spec.angleTenths / 10 * math.pi / 180),
        math.sin(spec.angleTenths / 10 * math.pi / 180),
      );

  final BackgroundSpec spec;
  final Size size;

  /// One cycle of bands along [dir], dp.
  final double period;

  /// The band direction (unit).
  final Offset dir;

  /// Paints the base and the foil over the canvas, overscanned by one
  /// period so it can pan.
  void paint(Canvas canvas) {
    final c = [for (var i = 0; i < 5; i++) _opaque(spec.colors[i])];
    final rect = (Offset.zero & size).inflate(period + 2);
    canvas.drawRect(rect, Paint()..color = c[0]);
    final origin = size.center(Offset.zero);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          origin,
          origin + dir * period,
          [c[1], c[2], c[3], c[4], c[1]],
          const [0, 0.22, 0.48, 0.74, 1],
          TileMode.repeated,
        ),
    );
    // A finer interference layer across the bands (the foil's shimmer).
    final cross = Offset(-dir.dy, dir.dx) * 0.8 + dir * 0.6;
    final crossDir = cross / cross.distance;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          origin,
          origin + crossDir * (0.42 * period),
          [
            c[3].withValues(alpha: 0.40),
            c[1].withValues(alpha: 0.10),
            c[4].withValues(alpha: 0.40),
            c[2].withValues(alpha: 0.10),
            c[3].withValues(alpha: 0.40),
          ],
          const [0, 0.25, 0.5, 0.75, 1],
          TileMode.repeated,
        ),
    );
  }
}

/// Static layers over the foil: the pearl floor (bottom 15 %), a foil
/// crease band with two fine crease lines, and the sparkles.
void _paintChromeOver(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  Y2kSceneLayout layout,
  _Holo holo,
  double patternFade,
) {
  final w = size.width;
  final h = size.height;
  final base = _opaque(spec.colors[0]);
  final light = _opaque(spec.colors[5]);
  final a5 = _alphaOf(spec.colors[5]);
  final floorTop = 0.85 * h;
  canvas.drawRect(
    Rect.fromLTRB(0, floorTop, w, h),
    Paint()
      ..shader = ui.Gradient.linear(Offset(0, floorTop), Offset(0, h), [
        base.withValues(alpha: 0),
        base.withValues(alpha: y2kChromeFloorAlpha / 255),
      ]),
  );
  if (a5 > 0) {
    final diagonal = math.sqrt(w * w + h * h);
    final centre = Offset(0.62 * w, 0.28 * h);
    final band = 0.32 * diagonal;
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(math.atan2(holo.dir.dy, holo.dir.dx));
    canvas.drawRect(
      Rect.fromLTRB(-band / 2, -diagonal, band / 2, diagonal),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-band / 2, 0),
          Offset(band / 2, 0),
          [
            light.withValues(alpha: 0),
            light.withValues(alpha: 0.6 * a5),
            light.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
    final line = Paint()
      ..color = light.withValues(alpha: 0.4 * a5)
      ..strokeWidth = 1.5;
    for (final f in const [-0.18, 0.11]) {
      final x = f * band;
      canvas.drawLine(Offset(x, -diagonal), Offset(x, diagonal), line);
    }
    canvas.restore();
  }
  _paintSparkles(canvas, size, spec, layout, patternFade);
}

final Path _star = () {
  final p = Path()
    ..moveTo(0, -1)
    ..lineTo(0.18, 0)
    ..lineTo(0, 1)
    ..lineTo(-0.18, 0)
    ..close()
    ..moveTo(-1, 0)
    ..lineTo(0, -0.18)
    ..lineTo(1, 0)
    ..lineTo(0, 0.18)
    ..close()
    ..addOval(Rect.fromCircle(center: Offset.zero, radius: 0.14));
  return p..fillType = PathFillType.nonZero;
}();

/// Static four-point sparkles (one path each, so a sparkle is painted at
/// exactly its alpha), hash-placed without overlaps, away from the calm
/// area.
void _paintSparkles(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  Y2kSceneLayout layout,
  double patternFade,
) {
  if (spec.pattern == BackgroundPattern.none ||
      spec.patternOpacityPermille <= 0 ||
      patternFade <= 0) {
    return;
  }
  final w = size.width;
  final h = size.height;
  final o = (spec.patternOpacityPermille / 1000).clamp(0.0, 1.0) * patternFade;
  final scale = math.max<double>(3, spec.patternScaleCdp / 100);
  final n = (w * h / 40000).round().clamp(6, 16);
  final paint = Paint()
    ..color = _opaque(spec.patternColor).withValues(alpha: o);
  final placed = <Rect>[];
  final seed = fmix32(spec.patternScaleCdp * 0x9E3779B1 ^ 0x5A5A);
  for (var i = 0; i < n; i++) {
    for (var attempt = 0; attempt < 6; attempt++) {
      final hh = fmix32(seed ^ (i * 8 + attempt));
      final s = scale * (0.6 + 0.8 * (fmix32(hh) & 0xFF) / 255);
      final x = (0.04 + 0.92 * (hh & 0xFFFF) / 65536) * w;
      final y = (0.04 + 0.92 * (hh >>> 16) / 65536) * h;
      final box = Rect.fromCircle(center: Offset(x, y), radius: s + 4);
      if (layout.calm(box, 12) || placed.any(box.overlaps)) continue;
      placed.add(box);
      canvas
        ..save()
        ..translate(x, y)
        ..scale(s)
        ..drawPath(_star, paint)
        ..restore();
      break;
    }
  }
}
