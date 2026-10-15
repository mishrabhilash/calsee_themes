/// Claymorphism background scene (`BackgroundKind.claySoft`): a soft
/// pastel (or night-clay) wash with two matte clay spheres.
///
/// `BackgroundSpec.colors` (nine opaque colours, claymorphism.dart): `[0]`
/// base, `[1]` top wash, `[2..4]` sphere A lit / body / shade, `[5..7]`
/// sphere B lit / body / shade, `[8]` the spheres' shadow core.
/// `angleTenths` is the size balance β (0–750 → sphere A shrinks 10 %
/// while B grows 10 %; foreign angles above 180° read as 0, so a
/// cross-family lerp never jumps).
///
/// Arrangement, from the display column S (the text-safe area: toolbar
/// plus display):
/// - **portrait:** sphere A is a cap over S's top-right corner (behind
///   the settings button, wrapping round the card's corner — centred just
///   outside S, so no bar of it runs down beside the card); sphere B sits
///   at the keypad's outer bottom-left corner;
/// - **landscape** (S is ≥ 75 % of the height): A at S's top-left corner,
///   B at the keypad's outer bottom-right corner;
/// - **gutter** (side gutters ≥ 120 dp: side-panel and wide windows): both
///   float in the gutters, fully visible (each radius ≤ half the gutter
///   less [claySphereGutterMargin], so neither the sphere nor its shadow
///   is cut by the side panel or the keypad).
///
/// No blur at all: the body is one gradient rect, each sphere a radial
/// gradient circle over an elliptical radial-gradient shadow. The scene is
/// static (`driftPeriodMs` 0) and cached as one picture per (spec, size,
/// text-safe area) in the shared [BackgroundCache].
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:calsee_themes/engine/theme_spec.dart';
import 'package:calsee_themes/render/background_painter.dart';
import 'package:flutter/widgets.dart';

/// One sphere of the scene.
typedef ClaySphere = ({Offset center, double radius});

/// A sphere's shadow sits this many radii below its centre…
const double claySphereShadowDrop = 0.30;

/// …and is this much flatter than wide (its width is the sphere's).
const double claySphereShadowSquash = 0.92;

/// In gutter mode each sphere's radius is at most half its gutter less
/// this margin (dp), so the sphere and its shadow fit inside the gutter.
const double claySphereGutterMargin = 8;

/// How the spheres are arranged for a canvas and display column.
enum ClaySceneMode {
  /// Phones: A at the column's top-right, B at the keypad's bottom-left.
  portrait,

  /// Landscape: A at the column's top-left, B at the keypad's bottom-right.
  landscape,

  /// Wide windows: both spheres in the side gutters.
  gutter,
}

/// The size balance β (0–1) of a claySoft scene from its `angleTenths`.
double claySizeBalance(int angleTenths) {
  final a = angleTenths % 3600;
  return (a > 1800 ? 0 : math.min(a, 750)) / 750;
}

/// The arrangement of the two spheres on a canvas of [size] whose display
/// column is [textSafeArea] (null: the top 36 %).
({ClaySceneMode mode, ClaySphere a, ClaySphere b}) claySceneLayout(
  Size size,
  Rect? textSafeArea,
  int angleTenths,
) {
  final w = size.width;
  final h = size.height;
  final s = textSafeArea ?? Rect.fromLTWH(0, 0, w, 0.36 * h);
  final beta = claySizeBalance(angleTenths);
  final ka = 1.1 - 0.2 * beta;
  final kb = 0.9 + 0.2 * beta;
  final gutter = s.left;
  double sphereB(Rect k) =>
      math.min(0.30 * k.width, 0.33 * k.height).clamp(64.0, 150.0) * kb;
  final rA = (0.24 * s.width).clamp(56.0, 120.0) * ka;
  if (s.height >= 0.75 * h) {
    final k = Rect.fromLTRB(s.right, 0, w, h);
    final rB = sphereB(k);
    return (
      mode: ClaySceneMode.landscape,
      a: (center: Offset(s.left + 0.25 * rA, s.top + 0.35 * rA), radius: rA),
      b: (
        center: Offset(k.right - 0.10 * rB, k.bottom - 0.10 * rB),
        radius: rB,
      ),
    );
  }
  if (gutter >= 120) {
    // Each sphere (and its soft shadow) stays inside its gutter: never
    // cut flat by the side panel or the keypad column.
    final cap = gutter / 2 - claySphereGutterMargin;
    return (
      mode: ClaySceneMode.gutter,
      a: (
        center: Offset(gutter / 2, s.top + 0.30 * h),
        radius: math.min(math.min(0.42 * gutter, 0.14 * h) * ka, cap),
      ),
      b: (
        center: Offset(s.right + gutter / 2, 0.76 * h),
        radius: math.min(math.min(0.48 * gutter, 0.17 * h) * kb, cap),
      ),
    );
  }
  final k = Rect.fromLTRB(s.left, s.bottom, s.right, h);
  final rB = sphereB(k);
  return (
    mode: ClaySceneMode.portrait,
    a: (center: Offset(s.right - 0.10 * rA, s.top - 0.10 * rA), radius: rA),
    b: (center: Offset(k.left + 0.10 * rB, k.bottom - 0.10 * rB), radius: rB),
  );
}

/// Paints the Claymorphism scene for [scene] over the whole canvas.
void paintClaymorphismScene(Canvas canvas, Size size, BackgroundScene scene) {
  if (size.isEmpty) return;
  final spec = scene.spec;
  if (spec.colors.length < 9) {
    scene.paintFallback(canvas, size);
    return;
  }
  final picture = scene.cache.scenePicture((
    spec,
    size,
    scene.textSafeArea,
  ), () => _record(spec, size, scene.textSafeArea));
  canvas.drawPicture(picture);
}

/// Paints only the scene's body (the top wash fading into the base below
/// the display column) — what the spheres are measured against in tests.
@visibleForTesting
void paintClaySceneBody(
  Canvas canvas,
  Size size,
  BackgroundSpec spec,
  Rect? textSafeArea,
) {
  final colors = [for (final c in spec.colors) Color(c | 0xFF000000)];
  final h = size.height;
  final s = textSafeArea ?? Rect.fromLTWH(0, 0, size.width, 0.36 * h);
  final t1 = (math.min(s.bottom, 0.75 * h) / h + 0.10).clamp(0.30, 0.90);
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, h),
        [colors[1], colors[0], colors[0]],
        [0, t1, 1],
      ),
  );
}

ui.Picture _record(BackgroundSpec spec, Size size, Rect? textSafeArea) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final colors = [for (final c in spec.colors) Color(c | 0xFF000000)];

  // 1. The body: the top wash fading into the base below the display.
  paintClaySceneBody(canvas, size, spec, textSafeArea);

  final layout = claySceneLayout(size, textSafeArea, spec.angleTenths);
  final core = colors[8];
  // 2. Soft shadows cast below the spheres, like the keys' drop shadows:
  // an elliptical radial gradient under each sphere whose lower part
  // shows as a soft crescent fading out at the sphere's sides (no blur).
  for (final sphere in [layout.a, layout.b]) {
    final r = sphere.radius;
    if (r <= 0) continue;
    final c = sphere.center + Offset(0.03 * r, claySphereShadowDrop * r);
    const k = claySphereShadowSquash;
    final matrix = Float64List(16)
      ..[0] = 1
      ..[5] = k
      ..[10] = 1
      ..[13] = c.dy * (1 - k)
      ..[15] = 1;
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 2 * r, height: 2 * k * r),
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r,
          [core, core, core.withValues(alpha: 0.45), core.withValues(alpha: 0)],
          const [0, 0.62, 0.82, 1],
          TileMode.clamp,
          matrix,
        ),
    );
  }
  // 3. The spheres: lit from the top-left.
  for (final (sphere, lit, body, shade) in [
    (layout.a, colors[2], colors[3], colors[4]),
    (layout.b, colors[5], colors[6], colors[7]),
  ]) {
    final r = sphere.radius;
    if (r <= 0) continue;
    final c = sphere.center;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c + Offset(-0.38 * r, -0.42 * r),
          1.45 * r,
          [lit, body, shade],
          const [0, 0.45, 1],
        ),
    );
  }
  return recorder.endRecording();
}
